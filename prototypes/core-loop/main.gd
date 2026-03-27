# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does cursor-claim-racing + contagion + chain feel fun and competitive?
# Date: 2026-03-27
#
# Visual front-end driving GameEngine for playable prototype.
extends Node2D

# --- DISPLAY CONFIG ---
const CELL_PX := 72
const CELL_GAP := 4
const PLAYER_COLORS: Array[Color] = [Color(0.2, 0.5, 1.0), Color(1.0, 0.3, 0.2)]
const PLAYER_NAMES: Array[String] = ["Blue", "Red"]
const COLOR_EMPTY := Color(0.25, 0.25, 0.3)
const COLOR_CURSOR := Color(1.0, 1.0, 0.2, 0.8)

# --- ENGINE ---
var engine: GameEngine
var grid_size: int

# --- UI NODES ---
var cell_rects: Array[ColorRect] = []
var cell_labels: Array[Label] = []
var cursor_rect: ColorRect
var score_label: Label
var timer_label: Label
var info_label: Label
var popup_container: Node2D

# --- ANIMATION ---
var anim_queue: Array[Dictionary] = []
var anim_timer: float = 0.0
const CHAIN_ANIM_DELAY := 0.2
var cursor_pulse: float = 0.0

# --- GRID ORIGIN ---
var grid_origin := Vector2.ZERO


func _ready() -> void:
	grid_size = 8
	var total := CELL_PX * grid_size + CELL_GAP * (grid_size - 1)
	grid_origin = Vector2((1280 - total) / 2.0, (720 - total) / 2.0 + 30)

	engine = GameEngine.new({
		"grid_size": grid_size,
		"capture_threshold": 3,
		"match_time": 180.0,
		"spawn_delay_min": 1.0,
		"spawn_delay_max": 3.0,
		"cursor_expire": 5.0,
		"chain_step_delay": 0.0,
		"wrap": true,
		"player_count": 2,
		"seed": 0  # random
	})
	engine.start_match()
	_build_ui()


func _build_ui() -> void:
	for i in range(grid_size * grid_size):
		var row := i / grid_size
		var col := i % grid_size
		var pos := grid_origin + Vector2(col * (CELL_PX + CELL_GAP), row * (CELL_PX + CELL_GAP))

		var rect := ColorRect.new()
		rect.size = Vector2(CELL_PX, CELL_PX)
		rect.position = pos
		rect.color = COLOR_EMPTY
		add_child(rect)
		cell_rects.append(rect)

		var lbl := Label.new()
		lbl.position = pos + Vector2(4, CELL_PX - 20)
		lbl.size = Vector2(CELL_PX - 8, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(lbl)
		cell_labels.append(lbl)

	cursor_rect = ColorRect.new()
	cursor_rect.size = Vector2(CELL_PX, CELL_PX)
	cursor_rect.color = COLOR_CURSOR
	cursor_rect.visible = false
	cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cursor_rect)

	score_label = Label.new()
	score_label.position = Vector2(20, 10)
	score_label.add_theme_font_size_override("font_size", 22)
	add_child(score_label)

	timer_label = Label.new()
	timer_label.position = Vector2(1100, 10)
	timer_label.add_theme_font_size_override("font_size", 22)
	add_child(timer_label)

	info_label = Label.new()
	info_label.position = Vector2(350, 690)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(info_label)
	info_label.text = "P1: WASD (swipe) / Space (tap) | P2: Arrows (swipe) / Enter (tap) | R = restart"

	popup_container = Node2D.new()
	add_child(popup_container)


func _process(delta: float) -> void:
	if not engine.match_active:
		return

	# Tick the engine
	engine.tick(delta)

	# Handle animation queue
	if anim_queue.size() > 0:
		anim_timer -= delta
		if anim_timer <= 0:
			var ev: Dictionary = anim_queue.pop_front()
			_animate_event(ev)
			anim_timer = CHAIN_ANIM_DELAY

	# Cursor pulse
	if engine.turn_state == GameEngine.TurnState.ACTIVE and engine.cursor_index >= 0:
		cursor_pulse += delta * 4.0
		cursor_rect.visible = true
		cursor_rect.position = _cell_pos(engine.cursor_index)
		cursor_rect.color = COLOR_CURSOR * (0.6 + 0.4 * sin(cursor_pulse))
		cursor_rect.color.a = 0.7 + 0.3 * sin(cursor_pulse)
	else:
		cursor_rect.visible = false

	# Check input when cursor is active and not animating
	if engine.turn_state == GameEngine.TurnState.ACTIVE and anim_queue.is_empty():
		_check_input()

	# Check for match end
	if not engine.match_active:
		_show_end_screen()

	_update_visuals()


func _check_input() -> void:
	# Player 1: WASD = directional swipe, Space = tap
	if Input.is_key_pressed(KEY_W):
		_do_action(0, GameEngine.Dir.UP)
		return
	if Input.is_key_pressed(KEY_S):
		_do_action(0, GameEngine.Dir.DOWN)
		return
	if Input.is_key_pressed(KEY_A):
		_do_action(0, GameEngine.Dir.LEFT)
		return
	if Input.is_key_pressed(KEY_D):
		_do_action(0, GameEngine.Dir.RIGHT)
		return
	if Input.is_key_pressed(KEY_SPACE):
		_do_action(0, GameEngine.Dir.NONE)
		return

	# Player 2: Arrows = directional swipe, Enter = tap
	if Input.is_key_pressed(KEY_UP):
		_do_action(1, GameEngine.Dir.UP)
		return
	if Input.is_key_pressed(KEY_DOWN):
		_do_action(1, GameEngine.Dir.DOWN)
		return
	if Input.is_key_pressed(KEY_LEFT):
		_do_action(1, GameEngine.Dir.LEFT)
		return
	if Input.is_key_pressed(KEY_RIGHT):
		_do_action(1, GameEngine.Dir.RIGHT)
		return
	if Input.is_key_pressed(KEY_ENTER):
		_do_action(1, GameEngine.Dir.NONE)
		return


func _do_action(player: int, dir: GameEngine.Dir) -> void:
	var events := engine.submit_action(player, dir)
	if events.is_empty():
		return
	cursor_rect.visible = false
	anim_queue = events.duplicate()
	anim_timer = 0.0  # first event immediate


func _animate_event(ev: Dictionary) -> void:
	var index: int = ev["index"]
	var player: int = ev["player"]
	var color: Color = PLAYER_COLORS[player] if player >= 0 and player < PLAYER_COLORS.size() else Color.WHITE

	_flash_cell(index, color)

	if ev["points"] != 0:
		var sign_str := "+%d" % ev["points"] if ev["points"] > 0 else "%d" % ev["points"]
		_spawn_popup(index, sign_str, color)

	if ev.has("target_points_lost") and ev["target_points_lost"] < 0:
		var target_owner: int = ev.get("target_owner", -1)
		if target_owner >= 0 and target_owner < PLAYER_COLORS.size():
			_spawn_popup(index, "%d" % ev["target_points_lost"], PLAYER_COLORS[target_owner])


func _cell_pos(index: int) -> Vector2:
	var row := index / grid_size
	var col := index % grid_size
	return grid_origin + Vector2(col * (CELL_PX + CELL_GAP), row * (CELL_PX + CELL_GAP))


func _update_visuals() -> void:
	for i in range(grid_size * grid_size):
		var owner: int = engine.cells_owner[i]
		if owner == -1:
			cell_rects[i].color = COLOR_EMPTY
		else:
			cell_rects[i].color = PLAYER_COLORS[owner]

		var cont: Dictionary = engine.cells_contagion[i]
		if cont.is_empty():
			cell_labels[i].text = ""
		else:
			var parts: Array[String] = []
			for p_id: int in cont:
				parts.append("%s:%d" % [PLAYER_NAMES[p_id][0], cont[p_id]])
			cell_labels[i].text = "/".join(PackedStringArray(parts))

	score_label.text = "%s: %d  |  %s: %d" % [PLAYER_NAMES[0], engine.scores[0], PLAYER_NAMES[1], engine.scores[1]]

	var mins := int(engine.match_timer) / 60
	var secs := int(engine.match_timer) % 60
	timer_label.text = "%d:%02d" % [mins, secs]


func _flash_cell(index: int, color: Color) -> void:
	var rect := cell_rects[index]
	var tween := create_tween()
	tween.tween_property(rect, "color", Color.WHITE, 0.05)
	tween.tween_property(rect, "color", color if engine.cells_owner[index] != -1 else COLOR_EMPTY, 0.15)


func _spawn_popup(index: int, text: String, color: Color) -> void:
	var pos := _cell_pos(index) + Vector2(CELL_PX / 2.0, -5)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_container.add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", pos.y - 40, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)


func _show_end_screen() -> void:
	var winner_text: String
	if engine.scores[0] > engine.scores[1]:
		winner_text = "%s wins!" % PLAYER_NAMES[0]
	elif engine.scores[1] > engine.scores[0]:
		winner_text = "%s wins!" % PLAYER_NAMES[1]
	else:
		winner_text = "Draw!"

	var end_label := Label.new()
	end_label.text = "MATCH OVER\n%s\n\n%s: %d pts  |  %s: %d pts\n\nPress R to restart" % [
		winner_text, PLAYER_NAMES[0], engine.scores[0], PLAYER_NAMES[1], engine.scores[1]
	]
	end_label.position = Vector2(400, 250)
	end_label.add_theme_font_size_override("font_size", 28)
	end_label.add_theme_color_override("font_color", Color.WHITE)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(end_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and not engine.match_active:
		get_tree().reload_current_scene()
