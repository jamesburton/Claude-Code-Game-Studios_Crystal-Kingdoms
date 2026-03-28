## AI opponent for Crystal Kingdoms.
## Evaluates board state, selects actions with difficulty-based delay and strategy.
## Submits actions to TurnDirector in the same format as human players.
class_name CpuController
extends RefCounted

var player_id: int
var difficulty: CpuDifficulty
var _config: GameConfig
var _board: BoardState
var _rng: RandomNumberGenerator

var _reaction_timer: float = -1.0
var _pending_cursor_index: int = -1
var _active: bool = false


func _init(p_player_id: int, p_difficulty: CpuDifficulty, config: GameConfig,
		board: BoardState, seed_value: int = 0) -> void:
	player_id = p_player_id
	difficulty = p_difficulty
	_config = config
	_board = board
	_rng = RandomNumberGenerator.new()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Called when cursor becomes active. Starts the reaction delay.
func on_cursor_spawned(cursor_index: int) -> void:
	_pending_cursor_index = cursor_index
	_reaction_timer = _rng.randf_range(difficulty.reaction_min, difficulty.reaction_max)
	_active = true


## Called when cursor is claimed or expires before this CPU acts.
func on_cursor_gone() -> void:
	_active = false
	_reaction_timer = -1.0
	_pending_cursor_index = -1


## Tick the CPU. Returns {player, direction} if ready to act, or empty dict.
func tick(delta: float) -> Dictionary:
	if not _active or _reaction_timer < 0:
		return {}

	_reaction_timer -= delta
	if _reaction_timer > 0:
		return {}

	_active = false

	# Skip chance: CPU sometimes deliberately doesn't act
	# Easy CPUs skip randomly; Hard CPUs skip strategically (evaluated in _decide_action)
	if difficulty.skip_chance > 0 and _rng.randf() < difficulty.skip_chance:
		return {}  # Let cursor pass — maybe another player or next cursor is better

	var action := _decide_action()
	return action


func _decide_action() -> Dictionary:
	if _pending_cursor_index < 0:
		return {}

	# Score all 5 options: tap + 4 directions
	var options: Array[Dictionary] = []

	# Tap
	var tap_score := _score_action(_pending_cursor_index, -1)
	options.append({"dir": -1, "score": tap_score})

	# 4 directions
	for dir_i in range(4):
		var score := _score_action(_pending_cursor_index, dir_i)
		options.append({"dir": dir_i, "score": score})

	# Find best score
	var best_score: int = options[0]["score"]
	for opt: Dictionary in options:
		if opt["score"] > best_score:
			best_score = opt["score"]

	# Hard CPUs with threat_awareness: skip if best option is poor (strategic pass)
	if difficulty.threat_awareness and best_score <= 0:
		return {}  # Nothing worth acting on — let cursor pass

	# Select action based on strategic_bias
	var chosen: Dictionary
	if _rng.randf() < difficulty.strategic_bias:
		# Pick best
		chosen = options[0]
		for opt: Dictionary in options:
			if opt["score"] > chosen["score"]:
				chosen = opt
	else:
		# Pick random (exclude self-destroy unless at max_castles)
		var valid: Array[Dictionary] = []
		for opt: Dictionary in options:
			if opt["score"] >= 0 or (_config.max_castles > 0 and
					_board.count_owned_by(player_id) >= _config.max_castles):
				valid.append(opt)
		if valid.is_empty():
			valid = options
		chosen = valid[_rng.randi() % valid.size()]

	return {"player": player_id, "dir": chosen["dir"]}


func _score_action(cursor_index: int, direction: int) -> int:
	var target: int
	if direction < 0:
		target = cursor_index
	else:
		target = _board.get_neighbor(cursor_index, direction as CKEnums.Direction)
		if target == -1:
			return -100  # off edge

	var score := _score_cell(target)

	# Chain awareness: simulate chain for swipe directions
	if direction >= 0 and difficulty.chain_awareness:
		var chain_cells := _board.get_cells_in_direction(
			cursor_index, direction as CKEnums.Direction)
		for cell_idx: int in chain_cells:
			var cell_owner: int = _board.cells_owner[cell_idx]
			if cell_owner == -1:
				score += 2  # empty capture
				break
			elif cell_owner != player_id:
				var cont: Dictionary = _board.cells_contagion[cell_idx]
				var level: int = cont.get(player_id, 0)
				if level + 1 >= _config.capture_threshold:
					score += difficulty.near_capture_bonus
					break
				else:
					score += 1  # contagion increment, chain continues
			else:
				score += difficulty.own_castle_penalty
				break

	return score


func _score_cell(index: int) -> int:
	var cell_owner: int = _board.cells_owner[index]
	if cell_owner == -1:
		var adj := _board.count_adjacent_owned(index, player_id)
		if adj == 0 and _config.lone_castle_scores_zero:
			return 0
		return adj + 1
	elif cell_owner != player_id:
		var cont: Dictionary = _board.cells_contagion[index]
		var contagion: int = cont.get(player_id, 0)
		var near_capture: int = difficulty.near_capture_bonus if (contagion + 1 >= _config.capture_threshold) else 0
		return contagion + 1 + near_capture
	else:
		return difficulty.own_castle_penalty
