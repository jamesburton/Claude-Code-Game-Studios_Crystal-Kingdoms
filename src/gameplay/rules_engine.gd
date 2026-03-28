## Deterministic rules engine for Crystal Kingdoms.
## Pure logic: given (BoardState, GameConfig, Action) → (mutated BoardState, EventLog).
## Never initiates actions — only resolves them when called by TurnDirector.
class_name RulesEngine
extends RefCounted

var _config: GameConfig
var _board: BoardState


func _init(config: GameConfig, board: BoardState) -> void:
	_config = config
	_board = board


## Resolve an action. Returns an ordered event log.
## direction = -1 for tap (no chain). Use CKEnums.Direction for swipe.
func resolve_action(actor_id: int, cursor_index: int, direction: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	# Determine starting cell (skip blanks if enabled)
	var current := cursor_index
	if direction >= 0:
		current = _next_playable(cursor_index, direction)
		if current == -1:
			return events

	# Cycle detection only when: wrap + unlimited castles + cursor_select_captured
	var needs_cycle_check := _board.wrap_around \
		and _config.max_castles == 0 \
		and _config.cursor_select_captured
	var visited: Dictionary = {}
	if needs_cycle_check:
		visited[cursor_index] = true

	var position := 0

	while true:
		if needs_cycle_check:
			if current in visited:
				events.append(_make_event(
					CKEnums.EventType.CHAIN_ENDED, current, actor_id, 0, position))
				break
			visited[current] = true

		# Blocked cell handling
		if _board.is_blocked(current):
			if _config.skip_blanks and direction >= 0:
				current = _next_playable(current, direction)
				if current == -1:
					events.append(_make_event(
						CKEnums.EventType.CHAIN_ENDED, current, actor_id, 0, position))
					break
				continue  # Re-evaluate the new cell
			else:
				events.append(_make_event(
					CKEnums.EventType.CHAIN_ENDED, current, actor_id, 0, position))
				break

		var ev := _resolve_cell(actor_id, current, position)
		events.append(ev)

		# Chain continues through contagion (increment or capture).
		# Chain stops on: capture_empty, destroy_own_castle, chain_ended.
		var ev_type: int = ev["type"]
		if ev_type != CKEnums.EventType.INCREMENT_CONTAGION \
				and ev_type != CKEnums.EventType.CAPTURE_CONTAGION:
			break

		# Tap = no chain
		if direction < 0:
			break

		var next_cell: int
		if _config.skip_blanks:
			next_cell = _next_playable(current, direction)
		else:
			next_cell = _board.get_neighbor(current, direction as CKEnums.Direction)

		if next_cell == -1 or next_cell == cursor_index:
			events.append(_make_event(
				CKEnums.EventType.CHAIN_ENDED, current, actor_id, 0, position))
			break

		current = next_cell
		position += 1

	return events


## Check if a player can perform an action (pre-check for TurnDirector).
func can_act(actor_id: int, cursor_index: int, actions_taken: int, castles_owned: int, bonus_stack_size: int) -> bool:
	# max_actions check
	if _config.max_actions > 0 and actions_taken >= _config.max_actions:
		return false

	# max_castles check: if at/above limit with bonus castles, can only self-destroy
	if _config.max_castles > 0 and castles_owned >= _config.max_castles and bonus_stack_size > 0:
		return _board.cells_owner[cursor_index] == actor_id

	if _config.max_castles > 0 and castles_owned >= _config.max_castles:
		return _board.cells_owner[cursor_index] == actor_id

	return true


## Find the next non-blocked cell in a direction, skipping blanks.
## Returns -1 if none found (edge or cycle).
func _next_playable(from: int, direction: int) -> int:
	var current := from
	var max_steps := _board.size * 2  # Safety limit
	for _i in range(max_steps):
		var next := _board.get_neighbor(current, direction as CKEnums.Direction)
		if next == -1:
			return -1
		if not _board.is_blocked(next):
			return next
		current = next
	return -1  # Safety: no playable cell found


func _resolve_cell(actor_id: int, index: int, position: int) -> Dictionary:
	var owner: int = _board.cells_owner[index]
	var ev := _make_event(CKEnums.EventType.CAPTURE_EMPTY, index, actor_id, 0, position)

	var cell_mult: float = _board.cells_score_mult[index] if index < _board.cells_score_mult.size() else 1.0

	if owner == -1:
		# Empty castle — capture
		_board.cells_owner[index] = actor_id
		_board.cells_contagion[index] = {}
		var adj := _board.count_adjacent_owned(index, actor_id)
		if adj == 0 and _config.lone_castle_scores_zero:
			ev["points_delta"] = 0
		else:
			ev["points_delta"] = maxi(1, int(_config.adjacency_scorer.effective(maxi(1, adj)) * cell_mult))
		ev["type"] = CKEnums.EventType.CAPTURE_EMPTY

	elif owner != actor_id:
		# Enemy or neutral castle — contagion
		var cont: Dictionary = _board.cells_contagion[index]
		var level: int = cont.get(actor_id, 0) + 1

		# Reinforcement adds extra contagion needed
		var extra_threshold: int = _board.cells_reinforcement[index] if index < _board.cells_reinforcement.size() else 0
		var effective_threshold := _config.capture_threshold + extra_threshold

		if level >= effective_threshold:
			# Capture via contagion threshold
			var prev_owner := owner
			var prev_adj := 0
			if prev_owner >= 0:
				prev_adj = _board.count_adjacent_owned(index, prev_owner)
			_board.cells_owner[index] = actor_id
			_board.cells_contagion[index] = {}

			# Revert special status unless persistent
			if not _config.persistent_specials:
				_board.cells_reinforcement[index] = 0
				if _board.cells_score_mult[index] != 1.0:
					_board.cells_score_mult[index] = 1.0

			# Capture score
			var actor_count := _board.count_owned_by(actor_id)
			var capture_n := actor_count
			if _config.capture_threshold < 4:
				capture_n = mini(capture_n, _config.capture_threshold)
			ev["points_delta"] = maxi(1, int(_config.capture_scorer.effective(maxi(1, capture_n)) * cell_mult))
			ev["type"] = CKEnums.EventType.CAPTURE_CONTAGION
			ev["target_owner"] = prev_owner
			if prev_owner >= 0:
				ev["target_points_lost"] = _config.calc_points_lost(prev_adj)
		else:
			# Increment contagion
			cont[actor_id] = level
			_board.cells_contagion[index] = cont
			if _config.scoring_mode == CKEnums.ScoringMode.ONLY_CASTLES:
				ev["points_delta"] = 0
			else:
				ev["points_delta"] = maxi(1, int(_config.contagion_scorer.effective(level) * cell_mult))
			ev["type"] = CKEnums.EventType.INCREMENT_CONTAGION
			ev["contagion_level"] = level

	else:
		# Own castle — destroy
		_board.cells_owner[index] = -1
		ev["type"] = CKEnums.EventType.DESTROY_OWN_CASTLE
		ev["points_delta"] = 0

	return ev


func _make_event(type: CKEnums.EventType, index: int, actor_id: int,
		points_delta: int, chain_position: int) -> Dictionary:
	return {
		"type": type,
		"grid_index": index,
		"actor_id": actor_id,
		"points_delta": points_delta,
		"target_owner": -1,
		"target_points_lost": 0,
		"contagion_level": 0,
		"chain_position": chain_position,
	}
