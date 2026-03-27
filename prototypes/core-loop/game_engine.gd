# PROTOTYPE - NOT FOR PRODUCTION
# Question: Can the core rules engine be tested deterministically with scripted inputs?
# Date: 2026-03-27
#
# Pure game logic — no UI, no nodes, no rendering.
# Instantiate with GameEngine.new(config) and drive with method calls.
class_name GameEngine
extends RefCounted

# --- ENUMS ---
enum Dir { NONE = -1, UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3 }
enum TurnState { SPAWNING, ACTIVE, RESOLVING, COOLDOWN, MATCH_OVER }

const DIR_OFFSETS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

# --- CONFIG ---
var grid_size: int
var capture_threshold: int
var match_time: float
var spawn_delay_min: float
var spawn_delay_max: float
var cursor_expire: float
var chain_step_delay: float
var wrap: bool
var player_count: int

# --- RNG ---
var rng: RandomNumberGenerator

# --- BOARD STATE ---
var cells_owner: Array[int] = []
var cells_contagion: Array[Dictionary] = []

# --- MATCH STATE ---
var scores: Array[int] = []
var actions_taken: Array[int] = []
var match_timer: float
var match_active := false
var end_reason: String = ""

# --- TURN STATE ---
var turn_state: TurnState = TurnState.SPAWNING
var spawn_timer: float = 0.0
var cursor_index: int = -1
var cursor_timer: float = 0.0

# --- CHAIN STATE ---
var chain_queue: Array[Dictionary] = []
var chain_timer: float = 0.0
var chain_actor: int = -1

# --- EVENT LOG (full match history) ---
var event_history: Array[Dictionary] = []
var turn_history: Array[Dictionary] = []  # {cursor_index, player, dir, events}


func _init(config: Dictionary = {}) -> void:
	grid_size = config.get("grid_size", 8)
	capture_threshold = config.get("capture_threshold", 3)
	match_time = config.get("match_time", 180.0)
	spawn_delay_min = config.get("spawn_delay_min", 1.0)
	spawn_delay_max = config.get("spawn_delay_max", 3.0)
	cursor_expire = config.get("cursor_expire", 5.0)
	chain_step_delay = config.get("chain_step_delay", 0.0)  # 0 for instant in tests
	wrap = config.get("wrap", true)
	player_count = config.get("player_count", 2)

	rng = RandomNumberGenerator.new()
	var seed_val = config.get("seed", 0)
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()


func start_match() -> void:
	cells_owner.resize(grid_size * grid_size)
	cells_contagion.resize(grid_size * grid_size)
	for i in range(grid_size * grid_size):
		cells_owner[i] = -1
		cells_contagion[i] = {}

	scores.resize(player_count)
	actions_taken.resize(player_count)
	for i in range(player_count):
		scores[i] = 0
		actions_taken[i] = 0

	match_timer = match_time
	match_active = true
	end_reason = ""
	event_history.clear()
	turn_history.clear()
	turn_state = TurnState.SPAWNING
	spawn_timer = _rand_spawn_delay()


# --- TICK: advance the game by delta seconds ---
# Returns events generated this tick (empty array if none)
func tick(delta: float) -> Array[Dictionary]:
	if not match_active:
		return []

	match_timer -= delta
	if match_timer <= 0:
		match_timer = 0
		if turn_state != TurnState.RESOLVING:
			_end_match("time_limit")
			return []

	match turn_state:
		TurnState.SPAWNING:
			spawn_timer -= delta
			if spawn_timer <= 0:
				_spawn_cursor()
		TurnState.RESOLVING:
			chain_timer -= delta
			if chain_timer <= 0 and chain_queue.size() > 0:
				chain_queue.pop_front()  # consume animation step
				chain_timer = chain_step_delay
			if chain_queue.is_empty():
				turn_state = TurnState.COOLDOWN
				spawn_timer = _rand_spawn_delay()
				if match_timer <= 0:
					_end_match("time_limit")
		TurnState.COOLDOWN:
			spawn_timer -= delta
			if spawn_timer <= 0:
				turn_state = TurnState.SPAWNING
				spawn_timer = _rand_spawn_delay()
		TurnState.ACTIVE:
			cursor_timer -= delta
			if cursor_timer <= 0:
				_expire_cursor()

	return []


# --- SUBMIT ACTION: a player claims the cursor ---
# Returns the event log for this action, or empty if invalid
func submit_action(player: int, dir: Dir) -> Array[Dictionary]:
	if turn_state != TurnState.ACTIVE or cursor_index == -1:
		return []
	if player < 0 or player >= player_count:
		return []

	var claimed_cursor := cursor_index
	turn_state = TurnState.RESOLVING
	chain_actor = player
	actions_taken[player] += 1

	var events := _resolve_action(player, claimed_cursor, dir)
	chain_queue = events.duplicate()
	chain_timer = 0.0

	var turn_record := {
		"cursor_index": claimed_cursor,
		"player": player,
		"dir": dir,
		"events": events
	}
	turn_history.append(turn_record)
	event_history.append_array(events)

	return events


# --- FORCE CURSOR: place cursor at a specific index (for testing) ---
func force_cursor(index: int) -> void:
	if index < 0 or index >= grid_size * grid_size:
		return
	cursor_index = index
	cursor_timer = cursor_expire
	turn_state = TurnState.ACTIVE


# --- FORCE BOARD STATE: set cell ownership/contagion directly (for testing) ---
func set_cell(index: int, owner: int, contagion: Dictionary = {}) -> void:
	if index < 0 or index >= grid_size * grid_size:
		return
	cells_owner[index] = owner
	cells_contagion[index] = contagion.duplicate()


# --- QUERY HELPERS ---
func get_cell_owner(index: int) -> int:
	return cells_owner[index]


func get_cell_contagion(index: int) -> Dictionary:
	return cells_contagion[index].duplicate()


func coords_to_index(row: int, col: int) -> int:
	return row * grid_size + col


func index_to_coords(index: int) -> Vector2i:
	return Vector2i(index % grid_size, index / grid_size)


func count_owned_by(player: int) -> int:
	var count := 0
	for i in range(grid_size * grid_size):
		if cells_owner[i] == player:
			count += 1
	return count


# --- INTERNAL ---
func _spawn_cursor() -> void:
	var empties: Array[int] = []
	for i in range(grid_size * grid_size):
		if cells_owner[i] == -1:
			empties.append(i)
	if empties.is_empty():
		_end_match("no_targets")
		return
	cursor_index = empties[rng.randi() % empties.size()]
	cursor_timer = cursor_expire
	turn_state = TurnState.ACTIVE


func _expire_cursor() -> void:
	cursor_index = -1
	turn_state = TurnState.COOLDOWN
	spawn_timer = _rand_spawn_delay()


func _resolve_action(player: int, start: int, dir: Dir) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var position := 0

	var current := start
	if dir != Dir.NONE:
		var neighbor := get_neighbor(start, dir)
		if neighbor == -1:
			return events
		current = neighbor
	var visited: Dictionary = {start: true}

	while true:
		var ev := _resolve_cell(player, current, position)
		events.append(ev)

		if ev["type"] != "increment_contagion":
			break

		if dir == Dir.NONE:
			break

		var next_cell := get_neighbor(current, dir)
		if next_cell == -1 or next_cell in visited:
			events.append({"type": "chain_ended", "index": current, "player": player, "points": 0, "pos": position})
			break

		visited[next_cell] = true
		current = next_cell
		position += 1

	return events


func _resolve_cell(player: int, index: int, position: int) -> Dictionary:
	var owner: int = cells_owner[index]
	var ev := {"index": index, "player": player, "pos": position, "points": 0, "type": "", "target_points_lost": 0}

	if owner == -1:
		cells_owner[index] = player
		cells_contagion[index] = {}
		var adj := _count_adjacent(index, player)
		ev["points"] = maxi(1, adj)
		ev["type"] = "capture_empty"
		scores[player] += ev["points"]

	elif owner != player:
		var cont: Dictionary = cells_contagion[index]
		var level: int = cont.get(player, 0) + 1
		if level >= capture_threshold:
			var prev_owner := owner
			cells_owner[index] = player
			cells_contagion[index] = {}
			ev["points"] = maxi(1, position + 1)
			ev["type"] = "capture_contagion"
			ev["target_owner"] = prev_owner
			scores[player] += ev["points"]
			var lost := maxi(1, _count_adjacent(index, prev_owner))
			ev["target_points_lost"] = -lost
			scores[prev_owner] -= lost
		else:
			cont[player] = level
			cells_contagion[index] = cont
			ev["points"] = level
			ev["type"] = "increment_contagion"
			scores[player] += ev["points"]

	else:
		cells_owner[index] = -1
		ev["type"] = "destroy_own_castle"

	return ev


func get_neighbor(index: int, dir: Dir) -> int:
	var row := index / grid_size
	var col := index % grid_size
	var offset := DIR_OFFSETS[dir]
	var new_row := row + offset.y
	var new_col := col + offset.x

	if wrap:
		new_row = posmod(new_row, grid_size)
		new_col = posmod(new_col, grid_size)
	else:
		if new_row < 0 or new_row >= grid_size or new_col < 0 or new_col >= grid_size:
			return -1

	return new_row * grid_size + new_col


func _count_adjacent(index: int, player: int) -> int:
	var count := 0
	for dir_i in range(4):
		var n := get_neighbor(index, dir_i as Dir)
		if n != -1 and cells_owner[n] == player:
			count += 1
	return count


func _rand_spawn_delay() -> float:
	return rng.randf_range(spawn_delay_min, spawn_delay_max)


func _end_match(reason: String) -> void:
	match_active = false
	end_reason = reason
	turn_state = TurnState.MATCH_OVER
