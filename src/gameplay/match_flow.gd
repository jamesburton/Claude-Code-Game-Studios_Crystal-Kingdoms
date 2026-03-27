## Top-level match orchestrator for Crystal Kingdoms.
## Manages the full lifecycle: SETUP → PLAYING → ENDING → COMPLETE.
## Owns per-player state, score accumulation, and end conditions.
class_name MatchFlow
extends RefCounted

signal match_started()
signal scores_updated()
signal match_ended(summary: Dictionary)

enum State { SETUP, PLAYING, ENDING, COMPLETE }

var state: State = State.SETUP
var config: GameConfig
var board: BoardState
var rules: RulesEngine
var turn_director: TurnDirector
var cpu_controllers: Array[CpuController] = []

# Per-player state
var scores: Array[int] = []
var actions_taken: Array[int] = []
var castles_owned: Array[int] = []
var total_captures: Array[int] = []
var max_castles_held: Array[int] = []
var longest_chain: Array[int] = []
var bonus_stacks: Array[Array] = []

var match_timer: float = 0.0
var end_reason: String = ""
var _rng_seed: int = 0


func _init(p_config: GameConfig, seed_value: int = 0) -> void:
	_rng_seed = seed_value
	config = p_config.lock()


## Initialize and start a match.
func start() -> void:
	board = BoardState.new(config)
	rules = RulesEngine.new(config, board)
	turn_director = TurnDirector.new(config, board, rules, _rng_seed)

	var count := config.player_count
	scores.resize(count)
	actions_taken.resize(count)
	castles_owned.resize(count)
	total_captures.resize(count)
	max_castles_held.resize(count)
	longest_chain.resize(count)
	bonus_stacks.resize(count)
	for i in range(count):
		scores[i] = 0
		actions_taken[i] = 0
		castles_owned[i] = 0
		total_captures[i] = 0
		max_castles_held[i] = 0
		longest_chain[i] = 0
		bonus_stacks[i] = []

	turn_director.init_players(count)
	turn_director.match_should_end.connect(_on_match_should_end)
	turn_director.action_resolved.connect(_on_action_resolved)

	match_timer = 0.0
	end_reason = ""
	state = State.PLAYING
	turn_director.start()
	match_started.emit()


## Tick the match forward by delta seconds.
func tick(delta: float) -> void:
	if state != State.PLAYING:
		return

	match_timer += delta

	# Time limit check
	if config.time_limit > 0 and match_timer >= config.time_limit:
		if turn_director.state != TurnDirector.State.RESOLVING:
			_end_match("time_limit")
			return

	# Tick CPU controllers
	for cpu: CpuController in cpu_controllers:
		var action := cpu.tick(delta)
		if not action.is_empty():
			submit_action(action["player"], action["dir"])

	# Tick turn director
	turn_director.tick(delta)


## Submit a player action (from input system or CPU).
func submit_action(player_id: int, direction: int) -> Array[Dictionary]:
	if state != State.PLAYING:
		return []

	var events := turn_director.submit_action(player_id, direction)
	if events.is_empty():
		return []

	_process_events(player_id, events)
	return events


## Force cursor for testing.
func force_cursor(index: int) -> void:
	turn_director.force_cursor(index)
	# Notify CPUs
	for cpu: CpuController in cpu_controllers:
		cpu.on_cursor_spawned(index)


## Signal animation complete to allow turn cycle to proceed.
func on_animation_complete() -> void:
	turn_director.on_animation_complete()


## Add a CPU controller for a player.
func add_cpu(player_id: int, difficulty: CpuDifficulty, seed_value: int = 0) -> void:
	var cpu := CpuController.new(player_id, difficulty, config, board, seed_value)
	cpu_controllers.append(cpu)

	# Connect cursor signals
	turn_director.cursor_spawned.connect(func(idx: int) -> void: cpu.on_cursor_spawned(idx))
	turn_director.cursor_expired.connect(func() -> void: cpu.on_cursor_gone())
	turn_director.cursor_claimed.connect(func(_p: int, _d: int) -> void: cpu.on_cursor_gone())


## Get remaining time (or elapsed if no limit).
func get_remaining_time() -> float:
	if config.time_limit > 0:
		return maxf(0.0, config.time_limit - match_timer)
	return match_timer


## Get match summary.
func get_summary() -> Dictionary:
	var rankings: Array[Dictionary] = []
	for i in range(config.player_count):
		rankings.append({
			"player_id": i,
			"score": scores[i],
			"castles": castles_owned[i],
			"total_captures": total_captures[i],
			"actions": actions_taken[i],
			"max_castles": max_castles_held[i],
			"longest_chain": longest_chain[i],
		})

	# Sort: score desc, castles desc, captures desc, actions asc
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["castles"] != b["castles"]:
			return a["castles"] > b["castles"]
		if a["total_captures"] != b["total_captures"]:
			return a["total_captures"] > b["total_captures"]
		return a["actions"] < b["actions"]
	)

	var winner_id: int = -1
	if rankings.size() > 0:
		if rankings.size() == 1 or rankings[0]["score"] != rankings[1]["score"]:
			winner_id = rankings[0]["player_id"]

	return {
		"winner": winner_id,
		"rankings": rankings,
		"duration": match_timer,
		"end_reason": end_reason,
	}


func _process_events(actor_id: int, events: Array[Dictionary]) -> void:
	actions_taken[actor_id] += 1

	for ev: Dictionary in events:
		var ev_type: int = ev["type"]
		match ev_type:
			CKEnums.EventType.CAPTURE_EMPTY:
				scores[actor_id] += ev["points_delta"]
				castles_owned[actor_id] += 1
				total_captures[actor_id] += 1
			CKEnums.EventType.INCREMENT_CONTAGION:
				scores[actor_id] += ev["points_delta"]
			CKEnums.EventType.CAPTURE_CONTAGION:
				scores[actor_id] += ev["points_delta"]
				castles_owned[actor_id] += 1
				total_captures[actor_id] += 1
				var target: int = ev["target_owner"]
				if target >= 0:
					scores[target] += ev["target_points_lost"]
					castles_owned[target] -= 1
			CKEnums.EventType.DESTROY_OWN_CASTLE:
				castles_owned[actor_id] -= 1

	# Update high watermarks
	max_castles_held[actor_id] = maxi(max_castles_held[actor_id], castles_owned[actor_id])

	# Chain length = events excluding chain_ended
	var chain_len := 0
	for ev: Dictionary in events:
		if ev["type"] != CKEnums.EventType.CHAIN_ENDED:
			chain_len += 1
	longest_chain[actor_id] = maxi(longest_chain[actor_id], chain_len)

	# Sync turn director's player state for constraint pre-checks
	turn_director.player_actions = actions_taken.duplicate()
	turn_director.player_castles = castles_owned.duplicate()
	turn_director.player_bonus_stacks = bonus_stacks.duplicate(true)

	# Check winning score
	if config.winning_score > 0:
		for i in range(config.player_count):
			if scores[i] >= config.winning_score:
				_end_match("winning_score")
				return

	# Check dominant victory
	for i in range(config.player_count):
		if castles_owned[i] == board.size * board.size:
			_end_match("dominant_victory")
			return

	scores_updated.emit()


func _on_match_should_end(reason: String) -> void:
	_end_match(reason)


func _on_action_resolved(_events: Array[Dictionary]) -> void:
	pass  # Events already processed via submit_action return


func _end_match(reason: String) -> void:
	if state == State.COMPLETE:
		return
	end_reason = reason
	state = State.COMPLETE
	turn_director.stop()
	match_ended.emit(get_summary())
