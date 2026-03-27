## Production test suite for Crystal Kingdoms core logic.
## Run: godot --headless -s tests/test_all.gd
extends SceneTree

var _pass := 0
var _fail := 0
var _failures: Array[String] = []


func _init() -> void:
	print("\n=== Crystal Kingdoms — Production Test Suite ===\n")

	# S1-07: ScorerConfig
	_test_power_of_two_curve()
	_test_count_curve()
	_test_fibonacci_curve()
	_test_square_curve()
	_test_custom_curve()
	_test_custom_curve_overflow()
	_test_round_half_up()
	_test_multiplier_and_adjustment()
	_test_effective_minimum_one()
	_test_preview()

	# S1-08: BoardState
	_test_board_creation()
	_test_coords_conversion()
	_test_neighbor_wrap()
	_test_neighbor_no_wrap()
	_test_adjacency_count()
	_test_get_cells_in_direction()
	_test_get_cells_in_direction_no_wrap()
	_test_empty_cells()

	# S1-09: RulesEngine
	_test_capture_empty()
	_test_capture_empty_adjacency()
	_test_capture_empty_lone_zero()
	_test_contagion_increment()
	_test_contagion_increment_only_castles_mode()
	_test_contagion_capture()
	_test_contagion_capture_points_lost()
	_test_capture_score_cap()
	_test_destroy_own_castle()
	_test_destroy_preserves_contagion()
	_test_tap_on_cursor_cell()
	_test_swipe_starts_adjacent()
	_test_chain_through_enemies()
	_test_chain_stops_on_capture_empty()
	_test_chain_stops_on_capture_contagion()
	_test_chain_stops_on_self_destroy()
	_test_chain_wraps()
	_test_chain_no_wrap_edge()
	_test_can_act_max_actions()
	_test_can_act_max_castles()

	# S1-10: Integration — TurnDirector + scripted match
	_test_turn_director_spawn()
	_test_turn_director_claim()
	_test_turn_director_expire()
	_test_scripted_match()

	# CPU Controller
	_test_cpu_reacts_after_delay()
	_test_cpu_does_nothing_if_cursor_gone()
	_test_cpu_scores_cells_correctly()

	# Match Flow
	_test_match_flow_lifecycle()
	_test_match_flow_scores_accumulate()
	_test_match_flow_time_limit()
	_test_match_flow_cpu_match()

	# GameConfig
	_test_speed_presets()
	_test_config_lock()
	_test_points_lost_calculation()

	print("\n=== Results: %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("FAILURES:")
		for f in _failures:
			print("  - %s" % f)
	print("")
	quit(_fail)


# --- Assertion helpers ---

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_failures.append(msg)
		print("  FAIL: %s" % msg)

func _assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_pass += 1
	else:
		_fail += 1
		_failures.append(msg)
		print("  FAIL: %s — expected %s, got %s" % [msg, str(expected), str(actual)])


# --- Helpers ---

func _make_config(overrides: Dictionary = {}):
	var c = GameConfig.new()
	for key: String in overrides:
		c.set(key, overrides[key])
	return c

func _make_board(config):
	return BoardState.new(config)

func _make_rules(config, board):
	return RulesEngine.new(config, board)


# ============================================================
# S1-07: SCORER CONFIG TESTS
# ============================================================

func _test_power_of_two_curve() -> void:
	print("ScorerConfig: POWER_OF_TWO...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.POWER_OF_TWO
	var expected: Array[int] = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
	for i in range(expected.size()):
		_assert_eq(s.effective(i + 1), expected[i], "POW2 n=%d" % (i + 1))

func _test_count_curve() -> void:
	print("ScorerConfig: COUNT...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.COUNT
	for i in range(1, 13):
		_assert_eq(s.effective(i), i, "COUNT n=%d" % i)

func _test_fibonacci_curve() -> void:
	print("ScorerConfig: FIBONACCI...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.FIBONACCI
	var expected: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
	for i in range(expected.size()):
		_assert_eq(s.effective(i + 1), expected[i], "FIB n=%d" % (i + 1))

func _test_square_curve() -> void:
	print("ScorerConfig: SQUARE...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.SQUARE
	var expected: Array[int] = [1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144]
	for i in range(expected.size()):
		_assert_eq(s.effective(i + 1), expected[i], "SQ n=%d" % (i + 1))

func _test_custom_curve() -> void:
	print("ScorerConfig: CUSTOM...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.CUSTOM
	s.custom_values.assign([10, 20, 30])
	_assert_eq(s.effective(1), 10, "custom n=1")
	_assert_eq(s.effective(2), 20, "custom n=2")
	_assert_eq(s.effective(3), 30, "custom n=3")

func _test_custom_curve_overflow() -> void:
	print("ScorerConfig: CUSTOM overflow...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.CUSTOM
	s.custom_values.assign([5, 10])
	_assert_eq(s.effective(3), 10, "custom overflow repeats last")
	_assert_eq(s.effective(99), 10, "custom far overflow repeats last")

func _test_round_half_up() -> void:
	print("ScorerConfig: round_half_up...")
	_assert_eq(ScorerConfig._round_half_up(0.5), 1, "0.5 → 1")
	_assert_eq(ScorerConfig._round_half_up(1.5), 2, "1.5 → 2")
	_assert_eq(ScorerConfig._round_half_up(2.5), 3, "2.5 → 3")
	_assert_eq(ScorerConfig._round_half_up(3.4), 3, "3.4 → 3")
	_assert_eq(ScorerConfig._round_half_up(3.6), 4, "3.6 → 4")

func _test_multiplier_and_adjustment() -> void:
	print("ScorerConfig: multiplier + adjustment...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.COUNT
	s.multiplier = 2.0
	s.adjustment = 1.0
	_assert_eq(s.effective(1), 3, "COUNT(1)*2+1 = 3")
	_assert_eq(s.effective(3), 7, "COUNT(3)*2+1 = 7")

func _test_effective_minimum_one() -> void:
	print("ScorerConfig: minimum 1...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.COUNT
	s.multiplier = 0.1
	s.adjustment = -5.0
	_assert_eq(s.effective(1), 1, "negative result clamped to 1")

func _test_preview() -> void:
	print("ScorerConfig: preview...")
	var s = ScorerConfig.new()
	s.curve = CKEnums.CurveType.COUNT
	var p = s.preview(5)
	_assert_eq(p, [1, 2, 3, 4, 5] as Array[int], "preview matches effective for n=1..5")


# ============================================================
# S1-08: BOARD STATE TESTS
# ============================================================

func _test_board_creation() -> void:
	print("BoardState: creation...")
	var c = _make_config()
	var b = _make_board(c)
	_assert_eq(b.cells_owner.size(), 64, "8x8 = 64 cells")
	_assert_eq(b.cells_owner[0], -1, "cell 0 empty")
	_assert_eq(b.cursor_index, -1, "no cursor")

func _test_coords_conversion() -> void:
	print("BoardState: coords...")
	var b = _make_board(_make_config())
	_assert_eq(b.coords_to_index(0, 0), 0, "(0,0)=0")
	_assert_eq(b.coords_to_index(7, 7), 63, "(7,7)=63")
	_assert_eq(b.coords_to_index(3, 4), 28, "(3,4)=28")
	_assert_eq(b.index_to_coords(28), Vector2i(4, 3), "28=(col4,row3)")

func _test_neighbor_wrap() -> void:
	print("BoardState: neighbor wrap...")
	var c = _make_config()
	c.wrap_around = true
	var b = _make_board(c)
	_assert_eq(b.get_neighbor(0, CKEnums.Direction.UP), 56, "0 UP → 56")
	_assert_eq(b.get_neighbor(0, CKEnums.Direction.LEFT), 7, "0 LEFT → 7")
	_assert_eq(b.get_neighbor(63, CKEnums.Direction.DOWN), 7, "63 DOWN → 7")
	_assert_eq(b.get_neighbor(63, CKEnums.Direction.RIGHT), 56, "63 RIGHT → 56")
	_assert_eq(b.get_neighbor(28, CKEnums.Direction.UP), 20, "28 UP → 20")
	_assert_eq(b.get_neighbor(28, CKEnums.Direction.RIGHT), 29, "28 RIGHT → 29")

func _test_neighbor_no_wrap() -> void:
	print("BoardState: neighbor no-wrap...")
	var c = _make_config()
	c.wrap_around = false
	var b = _make_board(c)
	_assert_eq(b.get_neighbor(0, CKEnums.Direction.UP), -1, "0 UP off edge")
	_assert_eq(b.get_neighbor(0, CKEnums.Direction.LEFT), -1, "0 LEFT off edge")
	_assert_eq(b.get_neighbor(63, CKEnums.Direction.DOWN), -1, "63 DOWN off edge")

func _test_adjacency_count() -> void:
	print("BoardState: adjacency count...")
	var b = _make_board(_make_config())
	b.cells_owner[27] = 0
	b.cells_owner[29] = 0
	b.cells_owner[20] = 0
	b.cells_owner[36] = 1
	_assert_eq(b.count_adjacent_owned(28, 0), 3, "P0 has 3 adj to 28")
	_assert_eq(b.count_adjacent_owned(28, 1), 1, "P1 has 1 adj to 28")

func _test_get_cells_in_direction() -> void:
	print("BoardState: get_cells_in_direction (wrap)...")
	var c = _make_config()
	c.grid_size = 4
	c.wrap_around = true
	var b = _make_board(c)
	var cells = b.get_cells_in_direction(0, CKEnums.Direction.RIGHT)
	_assert_eq(cells.size(), 3, "4-grid wrap RIGHT from 0: 3 cells (1,2,3)")
	_assert_eq(cells[0], 1, "first = 1")
	_assert_eq(cells[2], 3, "last = 3")

func _test_get_cells_in_direction_no_wrap() -> void:
	print("BoardState: get_cells_in_direction (no wrap)...")
	var c = _make_config()
	c.grid_size = 4
	c.wrap_around = false
	var b = _make_board(c)
	var cells = b.get_cells_in_direction(2, CKEnums.Direction.RIGHT)
	_assert_eq(cells.size(), 1, "from col2 RIGHT no-wrap: 1 cell (col3)")
	_assert_eq(cells[0], 3, "cell = 3")

func _test_empty_cells() -> void:
	print("BoardState: empty cells...")
	var c = _make_config()
	c.grid_size = 2
	var b = _make_board(c)
	_assert_eq(b.get_empty_cells().size(), 4, "2x2 all empty = 4")
	b.cells_owner[0] = 0
	b.cells_owner[1] = 1
	_assert_eq(b.get_empty_cells().size(), 2, "2 owned = 2 empty")


# ============================================================
# S1-09: RULES ENGINE TESTS
# ============================================================

func _test_capture_empty() -> void:
	print("RulesEngine: capture empty...")
	var c = _make_config()
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)  # tap
	_assert_eq(events.size(), 1, "1 event")
	_assert_eq(events[0]["type"], CKEnums.EventType.CAPTURE_EMPTY, "capture_empty")
	_assert_eq(b.cells_owner[28], 0, "owned by P0")
	_assert_eq(events[0]["points_delta"], 1, "min 1 point (0 adj)")

func _test_capture_empty_adjacency() -> void:
	print("RulesEngine: capture empty adjacency...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[27] = 0
	b.cells_owner[20] = 0
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["points_delta"], 2, "POW2(2) = 2")

func _test_capture_empty_lone_zero() -> void:
	print("RulesEngine: lone castle scores zero...")
	var c = _make_config()
	c.lone_castle_scores_zero = true
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["points_delta"], 0, "lone castle = 0 points")

func _test_contagion_increment() -> void:
	print("RulesEngine: contagion increment...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[28] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["type"], CKEnums.EventType.INCREMENT_CONTAGION, "increment")
	_assert_eq(events[0]["contagion_level"], 1, "level = 1")
	_assert_eq(b.cells_contagion[28].get(0, 0), 1, "stored contagion = 1")
	_assert_eq(b.cells_owner[28], 1, "still owned by P1")

func _test_contagion_increment_only_castles_mode() -> void:
	print("RulesEngine: contagion in ONLY_CASTLES mode...")
	var c = _make_config()
	c.scoring_mode = CKEnums.ScoringMode.ONLY_CASTLES
	var b = _make_board(c)
	b.cells_owner[28] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["points_delta"], 0, "0 points in ONLY_CASTLES")

func _test_contagion_capture() -> void:
	print("RulesEngine: contagion capture...")
	var c = _make_config()
	c.capture_threshold = 3
	var b = _make_board(c)
	b.cells_owner[28] = 1
	b.cells_contagion[28] = {0: 2}
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["type"], CKEnums.EventType.CAPTURE_CONTAGION, "capture")
	_assert_eq(b.cells_owner[28], 0, "now owned by P0")
	_assert(b.cells_contagion[28].is_empty(), "contagion reset")

func _test_contagion_capture_points_lost() -> void:
	print("RulesEngine: capture points lost...")
	var c = _make_config()
	c.capture_threshold = 1
	var b = _make_board(c)
	b.cells_owner[28] = 1
	b.cells_owner[27] = 1  # P1 has an adjacent castle
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert(events[0]["target_points_lost"] < 0, "target lost points")
	_assert_eq(events[0]["target_owner"], 1, "target = P1")

func _test_capture_score_cap() -> void:
	print("RulesEngine: capture score cap at threshold < 4...")
	var c = _make_config()
	c.capture_threshold = 2
	var b = _make_board(c)
	# Give P0 5 castles
	for i in [0, 1, 2, 3, 4]:
		b.cells_owner[i] = 0
	# P1 owns cell 10 with P0 contagion at 1
	b.cells_owner[10] = 1
	b.cells_contagion[10] = {0: 1}
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 10, -1)
	# Post-capture P0 owns 6 castles, but cap = min(6, 2) = 2
	# SQUARE(2) * 1.2 = 4.8 → 5
	_assert_eq(events[0]["points_delta"], 5, "capped at threshold=2: SQUARE(2)*1.2=5")

func _test_destroy_own_castle() -> void:
	print("RulesEngine: destroy own...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[28] = 0
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["type"], CKEnums.EventType.DESTROY_OWN_CASTLE, "destroy")
	_assert_eq(b.cells_owner[28], -1, "now empty")
	_assert_eq(events[0]["points_delta"], 0, "0 points")

func _test_destroy_preserves_contagion() -> void:
	print("RulesEngine: destroy preserves contagion...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[28] = 0
	b.cells_contagion[28] = {1: 2}
	var r = _make_rules(c, b)
	r.resolve_action(0, 28, -1)
	_assert_eq(b.cells_contagion[28].get(1, 0), 2, "contagion preserved")

func _test_tap_on_cursor_cell() -> void:
	print("RulesEngine: tap acts on cursor cell...")
	var c = _make_config()
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, -1)
	_assert_eq(events[0]["grid_index"], 28, "tap = cursor cell")

func _test_swipe_starts_adjacent() -> void:
	print("RulesEngine: swipe starts on adjacent...")
	var c = _make_config()
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, CKEnums.Direction.RIGHT)
	_assert_eq(events[0]["grid_index"], 29, "swipe RIGHT from 28 → 29")

func _test_chain_through_enemies() -> void:
	print("RulesEngine: chain through enemies...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[29] = 1
	b.cells_owner[30] = 1
	b.cells_owner[31] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, CKEnums.Direction.RIGHT)
	_assert(events.size() >= 3, "at least 3 events")
	_assert_eq(events[0]["grid_index"], 29, "first = 29")
	_assert_eq(events[1]["grid_index"], 30, "second = 30")
	_assert_eq(events[2]["grid_index"], 31, "third = 31")
	for i in range(3):
		_assert_eq(events[i]["type"], CKEnums.EventType.INCREMENT_CONTAGION, "all increment")

func _test_chain_stops_on_capture_empty() -> void:
	print("RulesEngine: chain stops on capture empty...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[29] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, CKEnums.Direction.RIGHT)
	_assert_eq(events[0]["type"], CKEnums.EventType.INCREMENT_CONTAGION, "29 = contagion")
	_assert_eq(events[1]["type"], CKEnums.EventType.CAPTURE_EMPTY, "30 = capture, stops")
	_assert_eq(events.size(), 2, "2 events total")

func _test_chain_stops_on_capture_contagion() -> void:
	print("RulesEngine: chain stops on contagion capture...")
	var c = _make_config()
	c.capture_threshold = 2
	var b = _make_board(c)
	b.cells_owner[29] = 1
	b.cells_owner[30] = 1
	b.cells_contagion[30] = {0: 1}
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, CKEnums.Direction.RIGHT)
	_assert_eq(events[0]["type"], CKEnums.EventType.INCREMENT_CONTAGION, "29 = increment")
	_assert_eq(events[1]["type"], CKEnums.EventType.CAPTURE_CONTAGION, "30 = capture")
	_assert_eq(events.size(), 2, "chain stopped")

func _test_chain_stops_on_self_destroy() -> void:
	print("RulesEngine: chain stops on self-destroy...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[29] = 1
	b.cells_owner[30] = 0
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 28, CKEnums.Direction.RIGHT)
	_assert_eq(events[0]["type"], CKEnums.EventType.INCREMENT_CONTAGION, "29 = contagion")
	_assert_eq(events[1]["type"], CKEnums.EventType.DESTROY_OWN_CASTLE, "30 = destroy")
	_assert_eq(events.size(), 2, "chain stopped")

func _test_chain_wraps() -> void:
	print("RulesEngine: chain wraps around...")
	var c = _make_config()
	c.grid_size = 4
	c.wrap_around = true
	var b = _make_board(c)
	b.cells_owner[1] = 1
	b.cells_owner[2] = 1
	b.cells_owner[3] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 0, CKEnums.Direction.RIGHT)
	_assert(events.size() >= 3, "chain wraps through 3 enemies")
	_assert_eq(events[0]["grid_index"], 1, "first = 1")
	_assert_eq(events[1]["grid_index"], 2, "second = 2")
	_assert_eq(events[2]["grid_index"], 3, "third = 3")

func _test_chain_no_wrap_edge() -> void:
	print("RulesEngine: chain no-wrap stops at edge...")
	var c = _make_config()
	c.grid_size = 4
	c.wrap_around = false
	var b = _make_board(c)
	b.cells_owner[2] = 1
	b.cells_owner[3] = 1
	var r = _make_rules(c, b)
	var events = r.resolve_action(0, 1, CKEnums.Direction.RIGHT)
	_assert_eq(events[0]["grid_index"], 2, "first = 2")
	_assert_eq(events[1]["grid_index"], 3, "second = 3")
	var last = events[events.size() - 1]
	_assert_eq(last["type"], CKEnums.EventType.CHAIN_ENDED, "chain ended at edge")

func _test_can_act_max_actions() -> void:
	print("RulesEngine: max_actions constraint...")
	var c = _make_config()
	c.max_actions = 5
	var b = _make_board(c)
	var r = _make_rules(c, b)
	_assert(r.can_act(0, 28, 4, 0, 0), "4/5 actions: can act")
	_assert(!r.can_act(0, 28, 5, 0, 0), "5/5 actions: blocked")

func _test_can_act_max_castles() -> void:
	print("RulesEngine: max_castles constraint...")
	var c = _make_config()
	c.max_castles = 3
	var b = _make_board(c)
	b.cells_owner[28] = 0  # own castle at cursor
	b.cells_owner[29] = 1  # enemy at cursor
	var r = _make_rules(c, b)
	_assert(r.can_act(0, 28, 0, 3, 0), "at limit, cursor on own: can act (destroy)")
	_assert(!r.can_act(0, 29, 0, 3, 0), "at limit, cursor on enemy: blocked")


# ============================================================
# S1-10: TURN DIRECTOR + INTEGRATION TESTS
# ============================================================

func _test_turn_director_spawn() -> void:
	print("TurnDirector: cursor spawn...")
	var c = _make_config()
	c.cursor_spawn_delay_min = 0.0
	c.cursor_spawn_delay_max = 0.0
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var td = TurnDirector.new(c, b, r, 12345)
	td.init_players(2)
	td.start()
	td.tick(0.1)
	_assert_eq(td.state, TurnDirector.State.ACTIVE, "cursor is active")
	_assert(b.cursor_index >= 0, "cursor placed")
	_assert(b.cursor_active, "cursor active flag")

func _test_turn_director_claim() -> void:
	print("TurnDirector: cursor claim...")
	var c = _make_config()
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var td = TurnDirector.new(c, b, r, 12345)
	td.init_players(2)
	td.force_cursor(28)
	var events = td.submit_action(0, -1)  # tap
	_assert(events.size() > 0, "events returned")
	_assert_eq(td.state, TurnDirector.State.RESOLVING, "state = resolving")
	_assert(!b.cursor_active, "cursor no longer active")

func _test_turn_director_expire() -> void:
	print("TurnDirector: cursor expire...")
	var c = _make_config()
	c.cursor_expire_time = 0.1
	c.cursor_spawn_delay_min = 0.0
	c.cursor_spawn_delay_max = 0.0
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var td = TurnDirector.new(c, b, r, 12345)
	td.init_players(2)
	td.force_cursor(28)
	td.tick(0.2)  # expire
	_assert_eq(td.state, TurnDirector.State.COOLDOWN, "state = cooldown")
	_assert(!b.cursor_active, "cursor expired")

func _test_scripted_match() -> void:
	print("Integration: scripted match...")
	var c = _make_config()
	c.grid_size = 4
	c.capture_threshold = 2
	c.cursor_spawn_delay_min = 0.0
	c.cursor_spawn_delay_max = 0.0
	c.cursor_expire_time = 999.0
	var b = _make_board(c)
	var r = _make_rules(c, b)
	var td = TurnDirector.new(c, b, r, 42)
	td.init_players(2)
	td.start()

	var scores: Array[int] = [0, 0]

	# Script actions
	var script: Array[Dictionary] = [
		{"cursor": 5,  "player": 0, "dir": -1},   # P0 tap: capture
		{"cursor": 10, "player": 1, "dir": -1},   # P1 tap: capture
		{"cursor": 6,  "player": 0, "dir": -1},   # P0 tap: capture (adj to 5)
		{"cursor": 9,  "player": 1, "dir": -1},   # P1 tap: capture (adj to 10)
		{"cursor": 10, "player": 0, "dir": -1},   # P0 tap on P1's cell: contagion
		{"cursor": 10, "player": 0, "dir": -1},   # P0 tap again: capture (threshold=2)
	]

	for step: Dictionary in script:
		# Advance past any resolving/cooldown
		for i in range(10):
			td.on_animation_complete()
			td.tick(1.0)
			if td.state == TurnDirector.State.ACTIVE or td.state == TurnDirector.State.SPAWNING:
				break

		td.force_cursor(step["cursor"])
		var events = td.submit_action(step["player"], step["dir"])
		for ev: Dictionary in events:
			scores[ev["actor_id"]] += ev["points_delta"]
			if ev["target_owner"] >= 0:
				scores[ev["target_owner"]] += ev["target_points_lost"]
		td.on_animation_complete()

	_assert(scores[0] > 0, "P0 scored: %d" % scores[0])
	# P1 captured 2 cells (+2) but lost cell 10 to P0 (negative points), may be 0 or negative
	_assert(scores[1] <= scores[0], "P0 leads after capturing P1's cell")
	_assert_eq(b.cells_owner[5], 0, "P0 owns cell 5")
	_assert_eq(b.cells_owner[6], 0, "P0 owns cell 6")
	_assert_eq(b.cells_owner[10], 0, "P0 captured cell 10")
	_assert_eq(b.cells_owner[9], 1, "P1 still owns cell 9")
	_assert_eq(b.count_owned_by(0), 3, "P0 owns 3")
	_assert_eq(b.count_owned_by(1), 1, "P1 owns 1")
	print("  Final scores: P0=%d P1=%d" % [scores[0], scores[1]])


# ============================================================
# CPU CONTROLLER TESTS
# ============================================================

func _test_cpu_reacts_after_delay() -> void:
	print("CpuController: reacts after delay...")
	var c = _make_config()
	var b = _make_board(c)
	var diff = CpuDifficulty.new()
	diff.reaction_min = 0.5
	diff.reaction_max = 0.5
	var cpu = CpuController.new(0, diff, c, b, 12345)
	cpu.on_cursor_spawned(28)

	# Before delay: no action
	var action = cpu.tick(0.1)
	_assert(action.is_empty(), "no action before delay")

	# After delay: action produced
	action = cpu.tick(0.5)
	_assert(not action.is_empty(), "action after delay")
	_assert_eq(action["player"], 0, "correct player id")


func _test_cpu_does_nothing_if_cursor_gone() -> void:
	print("CpuController: no action if cursor gone...")
	var c = _make_config()
	var b = _make_board(c)
	var diff = CpuDifficulty.new()
	diff.reaction_min = 1.0
	diff.reaction_max = 1.0
	var cpu = CpuController.new(0, diff, c, b, 12345)
	cpu.on_cursor_spawned(28)
	cpu.on_cursor_gone()
	var action = cpu.tick(2.0)
	_assert(action.is_empty(), "no action after cursor gone")


func _test_cpu_scores_cells_correctly() -> void:
	print("CpuController: cell scoring...")
	var c = _make_config()
	var b = _make_board(c)
	b.cells_owner[27] = 0  # own adjacent
	b.cells_owner[29] = 1  # enemy
	var diff = CpuDifficulty.new()
	diff.reaction_min = 0.0
	diff.reaction_max = 0.0
	diff.strategic_bias = 1.0  # always pick best
	var cpu = CpuController.new(0, diff, c, b, 12345)
	cpu.on_cursor_spawned(28)
	var action = cpu.tick(0.1)
	# CPU should prefer tap on empty cell 28 (adj=1, score=2) over other options
	_assert(not action.is_empty(), "CPU acts")
	_assert(action["dir"] >= -1, "valid direction")


# ============================================================
# MATCH FLOW TESTS
# ============================================================

func _test_match_flow_lifecycle() -> void:
	print("MatchFlow: lifecycle...")
	var c = _make_config()
	var mf = MatchFlow.new(c, 42)
	_assert_eq(mf.state, MatchFlow.State.SETUP, "starts in SETUP")
	mf.start()
	_assert_eq(mf.state, MatchFlow.State.PLAYING, "PLAYING after start")


func _test_match_flow_scores_accumulate() -> void:
	print("MatchFlow: scores accumulate...")
	var c = _make_config()
	c.cursor_spawn_delay_min = 0.0
	c.cursor_spawn_delay_max = 0.0
	c.cursor_expire_time = 999.0
	var mf = MatchFlow.new(c, 42)
	mf.start()

	mf.force_cursor(10)
	mf.submit_action(0, -1)  # P0 tap: capture
	mf.on_animation_complete()
	_assert(mf.scores[0] > 0, "P0 scored after capture")
	_assert_eq(mf.castles_owned[0], 1, "P0 owns 1 castle")
	_assert_eq(mf.total_captures[0], 1, "P0 has 1 capture")


func _test_match_flow_time_limit() -> void:
	print("MatchFlow: time limit...")
	var c = _make_config()
	c.time_limit = 1
	c.cursor_spawn_delay_min = 5.0
	c.cursor_spawn_delay_max = 5.0
	var mf = MatchFlow.new(c, 42)
	mf.start()
	mf.tick(2.0)
	_assert_eq(mf.state, MatchFlow.State.COMPLETE, "match ended by time")
	_assert_eq(mf.end_reason, "time_limit", "reason = time_limit")


func _test_match_flow_cpu_match() -> void:
	print("MatchFlow: CPU vs CPU match...")
	var c = _make_config()
	c.grid_size = 4
	c.time_limit = 10
	c.cursor_spawn_delay_min = 0.1
	c.cursor_spawn_delay_max = 0.2
	c.cursor_expire_time = 2.0
	c.player_count = 2
	var mf = MatchFlow.new(c, 99)
	mf.start()

	var easy = CpuDifficulty.new()
	easy.reaction_min = 0.3
	easy.reaction_max = 0.5
	easy.strategic_bias = 0.5
	mf.add_cpu(0, easy, 111)
	mf.add_cpu(1, easy, 222)

	# Run 10 seconds of match at 60fps
	for i in range(600):
		mf.tick(1.0 / 60.0)
		mf.on_animation_complete()
		if mf.state == MatchFlow.State.COMPLETE:
			break

	_assert_eq(mf.state, MatchFlow.State.COMPLETE, "CPU match completed")
	var summary = mf.get_summary()
	_assert(summary["rankings"].size() == 2, "2 players in rankings")
	var total_actions: int = mf.actions_taken[0] + mf.actions_taken[1]
	_assert(total_actions > 0, "CPUs took actions: %d" % total_actions)
	print("  CPU match: P0=%d P1=%d, %d actions in %.1fs" % [
		mf.scores[0], mf.scores[1], total_actions, mf.match_timer])


# ============================================================
# GAME CONFIG TESTS
# ============================================================

func _test_speed_presets() -> void:
	print("GameConfig: speed presets...")
	var c = _make_config()
	c.apply_speed_preset(CKEnums.SpeedPreset.FRANTIC)
	_assert_eq(c.cursor_spawn_delay_min, 0.5, "FRANTIC min=0.5")
	_assert_eq(c.cursor_expire_time, 2.0, "FRANTIC expire=2.0")
	_assert_eq(c.chain_step_delay, 0.05, "FRANTIC chain=0.05")
	c.apply_speed_preset(CKEnums.SpeedPreset.RELAXED)
	_assert_eq(c.cursor_spawn_delay_min, 2.0, "RELAXED min=2.0")

func _test_config_lock() -> void:
	print("GameConfig: lock (immutable copy)...")
	var c = _make_config()
	c.grid_size = 10
	var locked = c.lock()
	locked.grid_size = 6
	_assert_eq(c.grid_size, 10, "original unchanged after lock mutation")
	_assert_eq(locked.grid_size, 6, "locked copy is independent")

func _test_points_lost_calculation() -> void:
	print("GameConfig: points_lost calc...")
	var c = _make_config()
	# Default: CAPTURE base, SQUARE * 1.2, lost_multiplier = 1.5
	# adj=1: SQUARE(1)*1.2 = 1.2 → round = 1. lost = -(1 * 1.5) = -1.5 → round = -2
	var lost = c.calc_points_lost(1)
	_assert(lost < 0, "points lost is negative")
	# adj=2: SQUARE(2)*1.2 = 4.8 → 5. lost = -(5 * 1.5) = -7.5 → round = -8
	_assert_eq(c.calc_points_lost(2), -8, "adj=2: lost=-8")
