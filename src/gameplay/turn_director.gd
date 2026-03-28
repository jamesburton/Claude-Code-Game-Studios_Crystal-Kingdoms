## Real-time orchestrator for the Crystal Kingdoms turn cycle.
## Manages cursor spawn/claim/resolve/cooldown. Bridges Input and RulesEngine.
class_name TurnDirector
extends RefCounted

signal cursor_spawned(index: int)
signal cursor_claimed(player_id: int, direction: int)
signal cursor_expired()
signal action_resolved(event_log: Array[Dictionary])
signal animation_complete_expected()
signal match_should_end(reason: String)

enum State { IDLE, SPAWNING, ACTIVE, CLAIMED, RESOLVING, COOLDOWN, STOPPED }

var state: State = State.IDLE
var _config: GameConfig
var _board: BoardState
var _rules: RulesEngine
var _rng: RandomNumberGenerator

## History of all actions for replay.
var turn_history: Array = []

var _spawn_timer: float = 0.0
var _cursor_timer: float = 0.0
var _waiting_for_animation: bool = false

## Per-player state tracked for constraint pre-checks.
## Set by MatchFlow after each action.
var player_actions: Array[int] = []
var player_castles: Array[int] = []
var player_bonus_stacks: Array[Array] = []


func _init(config: GameConfig, board: BoardState, rules: RulesEngine, seed_value: int = 0) -> void:
	_config = config
	_board = board
	_rules = rules
	_rng = RandomNumberGenerator.new()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Initialize player tracking arrays. Called by MatchFlow at match start.
func init_players(count: int) -> void:
	player_actions.resize(count)
	player_castles.resize(count)
	player_bonus_stacks.resize(count)
	for i in range(count):
		player_actions[i] = 0
		player_castles[i] = 0
		player_bonus_stacks[i] = []


## Start the turn cycle.
func start() -> void:
	state = State.SPAWNING
	_spawn_timer = _rand_spawn_delay()


## Stop the turn cycle (match ended).
func stop() -> void:
	state = State.STOPPED
	_board.cursor_active = false
	_board.cursor_index = -1


## Advance the turn cycle by delta seconds.
func tick(delta: float) -> void:
	if state == State.STOPPED:
		return

	match state:
		State.IDLE:
			state = State.SPAWNING
			_spawn_timer = _rand_spawn_delay()
		State.SPAWNING:
			_spawn_timer -= delta
			if _spawn_timer <= 0:
				_do_spawn()
		State.ACTIVE:
			_cursor_timer -= delta
			if _cursor_timer <= 0:
				_do_expire()
		State.RESOLVING:
			if not _waiting_for_animation:
				state = State.COOLDOWN
				_spawn_timer = _rand_spawn_delay()
		State.COOLDOWN:
			_spawn_timer -= delta
			if _spawn_timer <= 0:
				state = State.SPAWNING
				_spawn_timer = _rand_spawn_delay()


## Submit a player action. Returns the event log, or empty if invalid.
## direction: -1 for tap, CKEnums.Direction value for swipe.
func submit_action(player_id: int, direction: int) -> Array[Dictionary]:
	if state != State.ACTIVE or _board.cursor_index < 0:
		return []

	# Pre-check constraints
	var bonus_size: int = 0
	if player_id < player_bonus_stacks.size():
		bonus_size = player_bonus_stacks[player_id].size()
	var actions: int = player_actions[player_id] if player_id < player_actions.size() else 0
	var castles: int = player_castles[player_id] if player_id < player_castles.size() else 0

	if not _rules.can_act(player_id, _board.cursor_index, actions, castles, bonus_size):
		return []

	# Claim cursor
	var claimed_index := _board.cursor_index
	_board.cursor_active = false
	state = State.RESOLVING
	_waiting_for_animation = true

	cursor_claimed.emit(player_id, direction)

	# Resolve action
	var events := _rules.resolve_action(player_id, claimed_index, direction)
	action_resolved.emit(events)

	# Record for replay
	turn_history.append({
		"cursor": claimed_index,
		"player": player_id,
		"dir": direction,
	})

	return events


## Signal that animation is complete. Allows turn cycle to proceed.
func on_animation_complete() -> void:
	_waiting_for_animation = false


## Force cursor to a specific position (for testing).
## Force cursor to a specific position (for testing).
func force_cursor(index: int) -> void:
	_board.cursor_index = index
	_board.cursor_active = true
	_cursor_timer = _config.cursor_expire_time
	state = State.ACTIVE


func _do_spawn() -> void:
	var empties := _board.get_empty_cells()

	if _config.cursor_select_captured:
		# Any cell is valid
		var total := _board.size * _board.size
		if total == 0:
			return
		_board.cursor_index = _rng.randi() % total
	else:
		if empties.is_empty():
			match_should_end.emit("no_targets")
			stop()
			return
		_board.cursor_index = empties[_rng.randi() % empties.size()]

	_board.cursor_active = true
	# Randomize expire time: base ±25%
	_cursor_timer = _config.cursor_expire_time * _rng.randf_range(0.75, 1.25)
	state = State.ACTIVE
	cursor_spawned.emit(_board.cursor_index)


func _do_expire() -> void:
	_board.cursor_index = -1
	_board.cursor_active = false
	state = State.COOLDOWN
	_spawn_timer = _rand_spawn_delay()
	cursor_expired.emit()


func _rand_spawn_delay() -> float:
	return _rng.randf_range(_config.cursor_spawn_delay_min, _config.cursor_spawn_delay_max)
