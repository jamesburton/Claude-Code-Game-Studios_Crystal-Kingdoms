# PROTOTYPE - NOT FOR PRODUCTION
# Question: Can we verify game rules deterministically with scripted inputs?
# Date: 2026-03-27
#
# Headless test runner — no rendering, instant resolution, fixed seeds.
# Run from Godot scene or via command line: godot --headless -s test_runner.gd
extends SceneTree

const GE = preload("res://game_engine.gd")

var pass_count := 0
var fail_count := 0
var test_names: Array[String] = []


func _init() -> void:
	print("\n=== Crystal Kingdoms — Core Loop Tests ===\n")

	# Board & Navigation
	_test_board_creation()
	_test_coords_conversion()
	_test_neighbor_wrap()
	_test_neighbor_no_wrap()
	_test_adjacency_count()

	# Single-cell resolution
	_test_capture_empty()
	_test_capture_empty_with_adjacency()
	_test_contagion_increment()
	_test_contagion_capture()
	_test_destroy_own_castle()
	_test_destroy_preserves_contagion()

	# Chain resolution
	_test_tap_acts_on_cursor_cell()
	_test_swipe_starts_on_adjacent()
	_test_chain_through_enemy_territory()
	_test_chain_stops_on_empty_capture()
	_test_chain_stops_on_contagion_capture()
	_test_chain_stops_on_self_destroy()
	_test_chain_wraps_around()
	_test_chain_no_wrap_stops_at_edge()

	# Scoring
	_test_scores_accumulate()
	_test_contagion_capture_deducts_from_target()

	# Match flow
	_test_match_ends_on_time()
	_test_cursor_spawn_deterministic_seed()
	_test_no_targets_ends_match()

	# Scripted full match
	_test_scripted_match()

	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	if fail_count > 0:
		print("FAILURES:")
		for name in test_names:
			print("  - %s" % name)
	print("")
	quit(fail_count)


# --- HELPERS ---

func _make_engine(overrides: Dictionary = {}) -> RefCounted:
	var config := {
		"grid_size": 8,
		"capture_threshold": 3,
		"match_time": 999.0,
		"spawn_delay_min": 0.0,
		"spawn_delay_max": 0.0,
		"cursor_expire": 999.0,
		"chain_step_delay": 0.0,
		"wrap": true,
		"player_count": 2,
		"seed": 12345
	}
	config.merge(overrides, true)
	var engine := GE.new(config)
	engine.start_match()
	return engine


func _assert(condition: bool, message: String) -> void:
	if condition:
		pass_count += 1
	else:
		fail_count += 1
		test_names.append(message)
		print("  FAIL: %s" % message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		pass_count += 1
	else:
		fail_count += 1
		test_names.append(message)
		print("  FAIL: %s — expected %s, got %s" % [message, str(expected), str(actual)])


# --- BOARD & NAVIGATION TESTS ---

func _test_board_creation() -> void:
	print("Board Creation...")
	var engine = _make_engine()
	_assert_eq(engine.cells_owner.size(), 64, "8x8 board has 64 cells")
	var all_empty := true
	for i in range(64):
		if engine.cells_owner[i] != -1:
			all_empty = false
			break
	_assert(all_empty, "all cells start empty")


func _test_coords_conversion() -> void:
	print("Coords Conversion...")
	var engine = _make_engine()
	_assert_eq(engine.coords_to_index(0, 0), 0, "top-left is index 0")
	_assert_eq(engine.coords_to_index(0, 7), 7, "top-right is index 7")
	_assert_eq(engine.coords_to_index(7, 0), 56, "bottom-left is index 56")
	_assert_eq(engine.coords_to_index(7, 7), 63, "bottom-right is index 63")
	_assert_eq(engine.coords_to_index(3, 4), 28, "row 3, col 4 = 28")
	_assert_eq(engine.index_to_coords(28), Vector2i(4, 3), "index 28 = col 4, row 3")


func _test_neighbor_wrap() -> void:
	print("Neighbor (wrap=true)...")
	var engine = _make_engine({"wrap": true})
	# Top-left corner wraps
	_assert_eq(engine.get_neighbor(0, GE.Dir.UP), 56, "0 UP wraps to 56")
	_assert_eq(engine.get_neighbor(0, GE.Dir.LEFT), 7, "0 LEFT wraps to 7")
	# Bottom-right corner wraps
	_assert_eq(engine.get_neighbor(63, GE.Dir.DOWN), 7, "63 DOWN wraps to 7")
	_assert_eq(engine.get_neighbor(63, GE.Dir.RIGHT), 56, "63 RIGHT wraps to 56")
	# Interior cell
	_assert_eq(engine.get_neighbor(28, GE.Dir.UP), 20, "28 UP = 20")
	_assert_eq(engine.get_neighbor(28, GE.Dir.DOWN), 36, "28 DOWN = 36")
	_assert_eq(engine.get_neighbor(28, GE.Dir.LEFT), 27, "28 LEFT = 27")
	_assert_eq(engine.get_neighbor(28, GE.Dir.RIGHT), 29, "28 RIGHT = 29")


func _test_neighbor_no_wrap() -> void:
	print("Neighbor (wrap=false)...")
	var engine = _make_engine({"wrap": false})
	_assert_eq(engine.get_neighbor(0, GE.Dir.UP), -1, "0 UP off edge = -1")
	_assert_eq(engine.get_neighbor(0, GE.Dir.LEFT), -1, "0 LEFT off edge = -1")
	_assert_eq(engine.get_neighbor(63, GE.Dir.DOWN), -1, "63 DOWN off edge = -1")
	_assert_eq(engine.get_neighbor(63, GE.Dir.RIGHT), -1, "63 RIGHT off edge = -1")


func _test_adjacency_count() -> void:
	print("Adjacency Count...")
	var engine = _make_engine()
	engine.set_cell(27, 0)  # left of 28
	engine.set_cell(29, 0)  # right of 28
	engine.set_cell(20, 0)  # above 28
	engine.set_cell(36, 1)  # below 28 (enemy)
	engine.force_cursor(28)
	# Player 0 has 3 adjacent to cell 28
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events.size(), 1, "tap produces 1 event")
	_assert_eq(events[0]["type"], "capture_empty", "captures empty cell")
	_assert_eq(events[0]["points"], 3, "3 adjacent = 3 points")


# --- SINGLE-CELL RESOLUTION TESTS ---

func _test_capture_empty() -> void:
	print("Capture Empty...")
	var engine = _make_engine()
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events.size(), 1, "tap on empty = 1 event")
	_assert_eq(events[0]["type"], "capture_empty", "event type is capture_empty")
	_assert_eq(engine.get_cell_owner(28), 0, "cell now owned by player 0")
	_assert_eq(events[0]["points"], 1, "no adjacency = min 1 point")
	_assert_eq(engine.scores[0], 1, "score updated")


func _test_capture_empty_with_adjacency() -> void:
	print("Capture Empty (adjacency)...")
	var engine = _make_engine()
	engine.set_cell(27, 0)
	engine.set_cell(20, 0)
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["points"], 2, "2 adjacent = 2 points")


func _test_contagion_increment() -> void:
	print("Contagion Increment...")
	var engine = _make_engine()
	engine.set_cell(28, 1)  # owned by P2
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["type"], "increment_contagion", "contagion incremented")
	_assert_eq(events[0]["points"], 1, "first contagion = 1 point")
	var cont = engine.get_cell_contagion(28)
	_assert_eq(cont.get(0, 0), 1, "contagion level = 1")
	_assert_eq(engine.get_cell_owner(28), 1, "still owned by P2")


func _test_contagion_capture() -> void:
	print("Contagion Capture...")
	var engine = _make_engine({"capture_threshold": 3})
	engine.set_cell(28, 1)  # owned by P2
	engine.cells_contagion[28] = {0: 2}  # P1 has 2 contagion already
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["type"], "capture_contagion", "capture via contagion")
	_assert_eq(engine.get_cell_owner(28), 0, "now owned by P1")
	_assert(engine.get_cell_contagion(28).is_empty(), "contagion reset on capture")
	_assert(events[0]["target_points_lost"] < 0, "target lost points")


func _test_destroy_own_castle() -> void:
	print("Destroy Own Castle...")
	var engine = _make_engine()
	engine.set_cell(28, 0)
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["type"], "destroy_own_castle", "self-destroy")
	_assert_eq(engine.get_cell_owner(28), -1, "cell now empty")
	_assert_eq(events[0]["points"], 0, "no points for self-destroy")


func _test_destroy_preserves_contagion() -> void:
	print("Destroy Preserves Contagion...")
	var engine = _make_engine()
	engine.set_cell(28, 0)
	engine.cells_contagion[28] = {1: 2}  # P2 had contagion here
	engine.force_cursor(28)
	engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(engine.get_cell_owner(28), -1, "cell empty after destroy")
	var cont = engine.get_cell_contagion(28)
	_assert_eq(cont.get(1, 0), 2, "P2 contagion preserved")


# --- CHAIN TESTS ---

func _test_tap_acts_on_cursor_cell() -> void:
	print("Tap Acts On Cursor Cell...")
	var engine = _make_engine()
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["index"], 28, "tap resolves on cursor cell")


func _test_swipe_starts_on_adjacent() -> void:
	print("Swipe Starts On Adjacent...")
	var engine = _make_engine()
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	_assert_eq(events[0]["index"], 29, "swipe RIGHT from 28 acts on 29")


func _test_chain_through_enemy_territory() -> void:
	print("Chain Through Enemy Territory...")
	var engine = _make_engine()
	# Set up a row of enemy cells to the right of cursor
	engine.set_cell(29, 1)  # enemy
	engine.set_cell(30, 1)  # enemy
	engine.set_cell(31, 1)  # enemy
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	# Should chain through all 3 enemy cells (contagion increment on each)
	_assert(events.size() >= 3, "chain produces at least 3 events")
	_assert_eq(events[0]["type"], "increment_contagion", "first cell: contagion")
	_assert_eq(events[0]["index"], 29, "first cell is 29")
	_assert_eq(events[1]["type"], "increment_contagion", "second cell: contagion")
	_assert_eq(events[1]["index"], 30, "second cell is 30")
	_assert_eq(events[2]["type"], "increment_contagion", "third cell: contagion")
	_assert_eq(events[2]["index"], 31, "third cell is 31")


func _test_chain_stops_on_empty_capture() -> void:
	print("Chain Stops On Empty Capture...")
	var engine = _make_engine()
	engine.set_cell(29, 1)  # enemy
	# cell 30 is empty
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	_assert_eq(events.size(), 2, "chain: contagion on 29, capture on 30, stops")
	_assert_eq(events[0]["type"], "increment_contagion", "29 = contagion")
	_assert_eq(events[1]["type"], "capture_empty", "30 = capture empty, chain stops")


func _test_chain_stops_on_contagion_capture() -> void:
	print("Chain Stops On Contagion Capture...")
	var engine = _make_engine({"capture_threshold": 2})
	engine.set_cell(29, 1)  # enemy, no contagion
	engine.set_cell(30, 1)  # enemy, 1 contagion from P1
	engine.cells_contagion[30] = {0: 1}
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	# 29: increment contagion (continues), 30: capture via contagion (stops)
	_assert_eq(events[0]["type"], "increment_contagion", "29 = increment")
	_assert_eq(events[1]["type"], "capture_contagion", "30 = capture, chain stops")
	_assert_eq(events.size(), 2, "chain stopped after capture")


func _test_chain_stops_on_self_destroy() -> void:
	print("Chain Stops On Self-Destroy...")
	var engine = _make_engine()
	engine.set_cell(29, 1)  # enemy
	engine.set_cell(30, 0)  # own castle
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	_assert_eq(events[0]["type"], "increment_contagion", "29 = contagion")
	_assert_eq(events[1]["type"], "destroy_own_castle", "30 = self-destroy, chain stops")
	_assert_eq(events.size(), 2, "chain stopped after self-destroy")


func _test_chain_wraps_around() -> void:
	print("Chain Wraps Around...")
	var engine = _make_engine({"wrap": true, "grid_size": 4})
	# Fill row 0 with enemy cells: cols 1, 2, 3
	engine.set_cell(engine.coords_to_index(0, 1), 1)
	engine.set_cell(engine.coords_to_index(0, 2), 1)
	engine.set_cell(engine.coords_to_index(0, 3), 1)
	# Cursor at (0, 0), swipe RIGHT
	engine.force_cursor(engine.coords_to_index(0, 0))
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	# Should chain through cols 1, 2, 3 then wrap hits col 0 (cursor/start) → stop
	_assert(events.size() >= 3, "chain wraps through 3 enemy cells")
	_assert_eq(events[0]["index"], engine.coords_to_index(0, 1), "first = col 1")
	_assert_eq(events[1]["index"], engine.coords_to_index(0, 2), "second = col 2")
	_assert_eq(events[2]["index"], engine.coords_to_index(0, 3), "third = col 3")


func _test_chain_no_wrap_stops_at_edge() -> void:
	print("Chain No-Wrap Stops At Edge...")
	var engine = _make_engine({"wrap": false, "grid_size": 4})
	engine.set_cell(engine.coords_to_index(0, 2), 1)  # enemy
	engine.set_cell(engine.coords_to_index(0, 3), 1)  # enemy at edge
	engine.force_cursor(engine.coords_to_index(0, 1))
	var events = engine.submit_action(0, GE.Dir.RIGHT)
	# Chain: 2 = contagion, 3 = contagion, then off edge → chain_ended
	_assert_eq(events[0]["index"], engine.coords_to_index(0, 2), "first = col 2")
	_assert_eq(events[1]["index"], engine.coords_to_index(0, 3), "second = col 3")
	# Last event should be chain_ended
	var last = events[events.size() - 1]
	_assert_eq(last["type"], "chain_ended", "chain ends at edge")


# --- SCORING TESTS ---

func _test_scores_accumulate() -> void:
	print("Scores Accumulate...")
	var engine = _make_engine()
	engine.force_cursor(10)
	engine.submit_action(0, GE.Dir.NONE)  # capture empty: +1
	engine.force_cursor(20)
	engine.submit_action(1, GE.Dir.NONE)  # capture empty: +1
	_assert_eq(engine.scores[0], 1, "P1 score = 1")
	_assert_eq(engine.scores[1], 1, "P2 score = 1")

	engine.force_cursor(11)
	engine.submit_action(0, GE.Dir.NONE)  # capture empty, 1 adj: +1
	_assert_eq(engine.scores[0], 2, "P1 score = 2 after second capture")


func _test_contagion_capture_deducts_from_target() -> void:
	print("Contagion Capture Deducts From Target...")
	var engine = _make_engine({"capture_threshold": 1})
	engine.set_cell(28, 1)  # P2 owns
	engine.scores[1] = 10
	engine.force_cursor(28)
	var events = engine.submit_action(0, GE.Dir.NONE)
	_assert_eq(events[0]["type"], "capture_contagion", "captured via threshold=1")
	_assert(engine.scores[1] < 10, "P2 lost points")
	_assert(events[0]["target_points_lost"] < 0, "target_points_lost is negative")


# --- MATCH FLOW TESTS ---

func _test_match_ends_on_time() -> void:
	print("Match Ends On Time...")
	var engine = _make_engine({"match_time": 1.0})
	# Tick past match time
	engine.tick(2.0)
	_assert(!engine.match_active, "match ended")
	_assert_eq(engine.end_reason, "time_limit", "ended by time limit")


func _test_cursor_spawn_deterministic_seed() -> void:
	print("Cursor Spawn Deterministic (same seed)...")
	var engine1 = _make_engine({"seed": 99999})
	var engine2 = _make_engine({"seed": 99999})
	# Tick both to spawn cursor
	engine1.tick(0.1)
	engine2.tick(0.1)
	_assert_eq(engine1.cursor_index, engine2.cursor_index, "same seed → same cursor position")
	_assert(engine1.cursor_index >= 0, "cursor spawned")


func _test_no_targets_ends_match() -> void:
	print("No Targets Ends Match...")
	var engine = _make_engine({"grid_size": 2})  # 4 cells
	for i in range(4):
		engine.set_cell(i, 0)  # all owned
	# Try to spawn — should end match
	engine.turn_state = GE.TurnState.SPAWNING
	engine.spawn_timer = 0.0
	engine.tick(0.1)
	_assert(!engine.match_active, "match ended — no empty cells")
	_assert_eq(engine.end_reason, "no_targets", "ended by no targets")


# --- SCRIPTED FULL MATCH ---

func _test_scripted_match() -> void:
	print("Scripted Full Match...")
	var engine = _make_engine({
		"grid_size": 4,
		"capture_threshold": 2,
		"match_time": 60.0,
		"seed": 42
	})

	# Script: a sequence of (cursor_position, player, direction) actions
	var script: Array[Dictionary] = [
		{"cursor": 5,  "player": 0, "dir": GE.Dir.NONE},   # P1 tap: capture empty
		{"cursor": 10, "player": 1, "dir": GE.Dir.NONE},   # P2 tap: capture empty
		{"cursor": 6,  "player": 0, "dir": GE.Dir.NONE},   # P1 tap: capture (adj to 5)
		{"cursor": 9,  "player": 1, "dir": GE.Dir.NONE},   # P2 tap: capture (adj to 10)
		{"cursor": 10, "player": 0, "dir": GE.Dir.NONE},   # P1 tap on P2's cell: contagion
		{"cursor": 10, "player": 0, "dir": GE.Dir.NONE},   # P1 tap again: capture (threshold=2)
	]

	for step: Dictionary in script:
		# Fast-forward to get past any resolving/cooldown state
		for i in range(10):
			engine.tick(1.0)
			if engine.turn_state == GE.TurnState.ACTIVE or engine.turn_state == GE.TurnState.SPAWNING:
				break

		engine.force_cursor(step["cursor"])
		engine.submit_action(step["player"], step["dir"] as GE.Dir)

		# Drain the chain queue
		for i in range(50):
			engine.tick(0.1)
			if engine.chain_queue.is_empty() and engine.turn_state != GE.TurnState.RESOLVING:
				break

	_assert(engine.match_active, "match still active after script")
	_assert(engine.scores[0] > 0, "P1 has score > 0: %d" % engine.scores[0])
	_assert(engine.scores[1] > 0, "P2 has score > 0: %d" % engine.scores[1])
	_assert_eq(engine.get_cell_owner(5), 0, "P1 owns cell 5")
	_assert_eq(engine.get_cell_owner(6), 0, "P1 owns cell 6")
	_assert_eq(engine.get_cell_owner(10), 0, "P1 captured cell 10 from P2")
	_assert_eq(engine.get_cell_owner(9), 1, "P2 still owns cell 9")
	_assert_eq(engine.count_owned_by(0), 3, "P1 owns 3 cells total")
	_assert_eq(engine.count_owned_by(1), 1, "P2 owns 1 cell")
	print("  Scripted match final: P1=%d P2=%d" % [engine.scores[0], engine.scores[1]])
	print("  Turn history: %d actions" % engine.turn_history.size())
