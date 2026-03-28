## Pre-match configuration screen.
## Lets players set grid size, player count, human/CPU, difficulty, speed, and rules.
class_name ConfigScreen
extends Control

signal match_requested(config: GameConfig, player_setup: Array[Dictionary])

const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.5, 1.0), Color(1.0, 0.3, 0.2),
	Color(0.2, 0.8, 0.3), Color(1.0, 0.6, 0.1),
	Color(0.9, 0.9, 0.2), Color(0.6, 0.3, 0.8),
	Color(0.2, 0.8, 0.8), Color(0.9, 0.3, 0.7),
]
const PLAYER_NAMES: Array[String] = [
	"Blue", "Red", "Green", "Orange", "Yellow", "Purple", "Cyan", "Magenta"
]

var _grid_size_slider: HSlider
var _grid_size_label: Label
var _player_count_slider: HSlider
var _player_count_label: Label
var _speed_option: OptionButton
var _threshold_slider: HSlider
var _threshold_label: Label
var _time_slider: HSlider
var _time_label: Label
var _shape_option: OptionButton
var _max_castles_slider: HSlider
var _max_castles_label: Label
var _winning_score_slider: HSlider
var _winning_score_label: Label
var _allow_tap_check: CheckBox
var _wrap_check: CheckBox
var _scoring_mode_option: OptionButton
var _lone_castle_check: CheckBox
var _cursor_captured_check: CheckBox
var _adj_curve_option: OptionButton
var _con_curve_option: OptionButton
var _cap_curve_option: OptionButton
var _max_actions_slider: HSlider
var _max_actions_label: Label
var _preview_label: Label
var _pre_placed_check: CheckBox
var _skip_blanks_check: CheckBox
var _persistent_check: CheckBox
var _neutral_slider: HSlider
var _neutral_label: Label
var _reinforced_slider: HSlider
var _reinforced_label: Label
var _fortified_slider: HSlider
var _fortified_label: Label
var _danger_slider: HSlider
var _danger_label: Label
var _bonus_slider: HSlider
var _bonus_label: Label
var _preset_name_edit: LineEdit
var _player_rows: Array[Dictionary] = []
var _start_button: Button
var _container: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_build_ui()
	_load_saved_settings()


func _load_saved_settings() -> void:
	var config := SettingsManager.load_config()
	if config == null:
		return
	_grid_size_slider.value = config.grid_size
	_threshold_slider.value = config.capture_threshold
	_time_slider.value = config.time_limit
	_player_count_slider.value = config.player_count
	_wrap_check.button_pressed = config.wrap_around
	_allow_tap_check.button_pressed = config.allow_tap
	_winning_score_slider.value = config.winning_score
	_scoring_mode_option.selected = config.scoring_mode
	_lone_castle_check.button_pressed = config.lone_castle_scores_zero
	_cursor_captured_check.button_pressed = config.cursor_select_captured
	# Max castles loaded after grid/player count so range is correct
	_update_max_castles_default()
	if config.max_castles > 0:
		_max_castles_slider.value = config.max_castles


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.12, 0.15)
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(300, 10)
	_scroll.size = Vector2(680, 700)
	add_child(_scroll)

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_container)

	# Title
	var title := Label.new()
	title.text = "Crystal Kingdoms"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)

	_add_spacer(6)

	# Preset quick-select
	var preset_header := Label.new()
	preset_header.text = "Quick Presets"
	preset_header.add_theme_font_size_override("font_size", 14)
	preset_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_container.add_child(preset_header)

	var preset_flow := HFlowContainer.new()
	_container.add_child(preset_flow)

	for preset: Dictionary in PresetManager.get_builtin_presets():
		var btn := Button.new()
		btn.text = preset["name"]
		btn.tooltip_text = preset.get("description", "")
		btn.custom_minimum_size = Vector2(100, 30)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_apply_preset.bind(preset))
		preset_flow.add_child(btn)

	# User presets
	var user_presets := PresetManager.load_user_presets()
	for preset in user_presets:
		var btn := Button.new()
		btn.text = preset.get("name", "?")
		btn.custom_minimum_size = Vector2(100, 30)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		btn.pressed.connect(_apply_preset.bind(preset))
		preset_flow.add_child(btn)

	# Save preset button
	var save_row := HBoxContainer.new()
	_container.add_child(save_row)
	_preset_name_edit = LineEdit.new()
	_preset_name_edit.placeholder_text = "Preset name..."
	_preset_name_edit.custom_minimum_size = Vector2(200, 30)
	save_row.add_child(_preset_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Save Preset"
	save_btn.custom_minimum_size = Vector2(100, 30)
	save_btn.add_theme_font_size_override("font_size", 13)
	save_btn.pressed.connect(_save_current_preset)
	save_row.add_child(save_btn)

	_add_spacer(6)

	_add_section_header("Match Settings")
	# Grid size
	var grid_row := _add_slider_row("Grid Size", 6, 12, 8)
	_grid_size_slider = grid_row["slider"]
	_grid_size_label = grid_row["value_label"]
	_grid_size_slider.value_changed.connect(func(v: float) -> void:
		_grid_size_label.text = "%dx%d" % [int(v), int(v)]
		_update_max_castles_default())

	# Board shape
	_add_spacer(2)
	var shape_row := HBoxContainer.new()
	_container.add_child(shape_row)
	var shape_lbl := Label.new()
	shape_lbl.text = "Board Shape: "
	shape_lbl.add_theme_font_size_override("font_size", 15)
	shape_lbl.custom_minimum_size.x = 180
	shape_row.add_child(shape_lbl)
	_shape_option = OptionButton.new()
	_shape_option.add_item("Rectangle", 0)
	_shape_option.add_item("Diamond", 1)
	_shape_option.add_item("Hourglass", 2)
	_shape_option.add_item("Cross", 3)
	_shape_option.add_item("Ring", 4)
	_shape_option.selected = 0
	_shape_option.custom_minimum_size.x = 180
	shape_row.add_child(_shape_option)

	# Capture threshold
	var thresh_row := _add_slider_row("Capture Threshold", 1, 10, 3)
	_threshold_slider = thresh_row["slider"]
	_threshold_label = thresh_row["value_label"]
	_threshold_slider.value_changed.connect(func(v: float) -> void:
		_threshold_label.text = "%d hits" % int(v))

	# Time limit
	var time_row := _add_slider_row("Time Limit", 30, 600, 90)
	_time_slider = time_row["slider"]
	_time_label = time_row["value_label"]
	_time_slider.step = 15
	_time_slider.value_changed.connect(func(v: float) -> void:
		_time_label.text = "%d:%02d" % [int(v) / 60, int(v) % 60])
	_time_label.text = "1:30"

	# Speed preset
	_add_spacer(4)
	var speed_row := HBoxContainer.new()
	_container.add_child(speed_row)
	var speed_lbl := Label.new()
	speed_lbl.text = "Speed: "
	speed_lbl.add_theme_font_size_override("font_size", 15)
	speed_lbl.custom_minimum_size.x = 180
	speed_row.add_child(speed_lbl)
	_speed_option = OptionButton.new()
	_speed_option.add_item("Relaxed", 0)
	_speed_option.add_item("Normal", 1)
	_speed_option.add_item("Fast", 2)
	_speed_option.add_item("Frantic", 3)
	_speed_option.selected = 1
	_speed_option.custom_minimum_size.x = 180
	speed_row.add_child(_speed_option)

	# Allow tap toggle
	_add_spacer(4)
	var tap_row := HBoxContainer.new()
	_container.add_child(tap_row)
	var tap_lbl := Label.new()
	tap_lbl.text = "Allow Tap (fire): "
	tap_lbl.add_theme_font_size_override("font_size", 15)
	tap_lbl.custom_minimum_size.x = 180
	tap_row.add_child(tap_lbl)
	_allow_tap_check = CheckBox.new()
	_allow_tap_check.button_pressed = true
	_allow_tap_check.text = "Yes (directional-only when off)"
	tap_row.add_child(_allow_tap_check)

	# Max castles slider
	_add_spacer(4)
	var mc_row := _add_slider_row("Max Castles", 0, 144, 0)
	_max_castles_slider = mc_row["slider"]
	_max_castles_label = mc_row["value_label"]
	_max_castles_slider.value_changed.connect(func(v: float) -> void:
		if int(v) == 0:
			_max_castles_label.text = "Unlimited"
		else:
			var grid := int(_grid_size_slider.value)
			_max_castles_label.text = "%d (of %d)" % [int(v), grid * grid])

	# Winning score
	var ws_row := _add_slider_row("Win Score", 0, 500, 0)
	_winning_score_slider = ws_row["slider"]
	_winning_score_label = ws_row["value_label"]
	_winning_score_slider.step = 10
	_winning_score_slider.value_changed.connect(func(v: float) -> void:
		_winning_score_label.text = "Off" if int(v) == 0 else "First to %d" % int(v))
	_winning_score_label.text = "Off"

	_add_section_header("Rules")
	_wrap_check = _add_check_row("Wrap Around", true)

	# Scoring mode
	_add_spacer(4)
	var sm_row := HBoxContainer.new()
	_container.add_child(sm_row)
	var sm_lbl := Label.new()
	sm_lbl.text = "Scoring Mode: "
	sm_lbl.add_theme_font_size_override("font_size", 15)
	sm_lbl.custom_minimum_size.x = 180
	sm_row.add_child(sm_lbl)
	_scoring_mode_option = OptionButton.new()
	_scoring_mode_option.add_item("Basic (all points)", 0)
	_scoring_mode_option.add_item("Only Castles (no contagion pts)", 1)
	_scoring_mode_option.selected = 0
	_scoring_mode_option.custom_minimum_size.x = 250
	sm_row.add_child(_scoring_mode_option)

	# Advanced toggles
	_lone_castle_check = _add_check_row("Lone Castle = 0 pts", false)
	_cursor_captured_check = _add_check_row("Cursor on Owned Cells", false)

	_add_section_header("Scoring Curves")

	_adj_curve_option = _add_curve_row("Adjacency", 0)  # POW2 default
	_con_curve_option = _add_curve_row("Contagion", 1)   # COUNT default
	_cap_curve_option = _add_curve_row("Capture", 3)     # SQUARE default

	# Max actions
	var ma_row := _add_slider_row("Max Actions", 0, 200, 0)
	_max_actions_slider = ma_row["slider"]
	_max_actions_label = ma_row["value_label"]
	_max_actions_slider.step = 5
	_max_actions_slider.value_changed.connect(func(v: float) -> void:
		_max_actions_label.text = "Unlimited" if int(v) == 0 else "%d" % int(v))
	_max_actions_label.text = "Unlimited"

	# Score preview (updates when curves change)
	_preview_label = Label.new()
	_preview_label.add_theme_font_size_override("font_size", 11)
	_preview_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	_container.add_child(_preview_label)
	_update_score_preview()

	# Volume
	var vol_row := _add_slider_row("Volume", 0, 100, 80)
	var _vol_slider: HSlider = vol_row["slider"]
	var _vol_label: Label = vol_row["value_label"]
	_vol_slider.value_changed.connect(func(v: float) -> void:
		_vol_label.text = "%d%%" % int(v)
		var db := linear_to_db(v / 100.0)
		AudioServer.set_bus_volume_db(0, db))
	_vol_label.text = "80%"

	# Fullscreen
	_add_spacer(2)
	var fs_row := HBoxContainer.new()
	_container.add_child(fs_row)
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen (F11): "
	fs_lbl.add_theme_font_size_override("font_size", 15)
	fs_lbl.custom_minimum_size.x = 180
	fs_row.add_child(fs_lbl)
	var fs_check := CheckBox.new()
	fs_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.toggled.connect(func(on: bool) -> void:
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED))
	fs_row.add_child(fs_check)

	_add_section_header("Special Cells")

	_pre_placed_check = _add_check_row("Pre-placed Castles", false)
	_skip_blanks_check = _add_check_row("Skip Blanks in Chains", true)
	_persistent_check = _add_check_row("Persistent Special Cells", false)

	var danger_row := _add_slider_row("Danger Cells (50%)", 0, 20, 0)
	_danger_slider = danger_row["slider"]
	_danger_label = danger_row["value_label"]
	_danger_slider.value_changed.connect(func(v: float) -> void:
		_danger_label.text = str(int(v)))
	_danger_label.text = "0"

	var bonus_row := _add_slider_row("Bonus Cells (200%)", 0, 20, 0)
	_bonus_slider = bonus_row["slider"]
	_bonus_label = bonus_row["value_label"]
	_bonus_slider.value_changed.connect(func(v: float) -> void:
		_bonus_label.text = str(int(v)))
	_bonus_label.text = "0"

	var neut_row := _add_slider_row("Neutral Castles", 0, 20, 0)
	_neutral_slider = neut_row["slider"]
	_neutral_label = neut_row["value_label"]
	_neutral_slider.value_changed.connect(func(v: float) -> void:
		_neutral_label.text = str(int(v)))
	_neutral_label.text = "0"

	var reinf_row := _add_slider_row("Reinforced (+1)", 0, 10, 0)
	_reinforced_slider = reinf_row["slider"]
	_reinforced_label = reinf_row["value_label"]
	_reinforced_slider.value_changed.connect(func(v: float) -> void:
		_reinforced_label.text = str(int(v)))
	_reinforced_label.text = "0"

	var fort_row := _add_slider_row("Fortified (+2)", 0, 5, 0)
	_fortified_slider = fort_row["slider"]
	_fortified_label = fort_row["value_label"]
	_fortified_slider.value_changed.connect(func(v: float) -> void:
		_fortified_label.text = str(int(v)))
	_fortified_label.text = "0"

	# Coming Soon
	_add_spacer(4)
	var cs_label := Label.new()
	cs_label.text = "Coming Soon: Boosts, Online Multiplayer"
	cs_label.add_theme_font_size_override("font_size", 12)
	cs_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_container.add_child(cs_label)

	_add_section_header("Players")

	var pcount_row := _add_slider_row("Players", 2, 8, 2)
	_player_count_slider = pcount_row["slider"]
	_player_count_label = pcount_row["value_label"]
	_player_count_slider.value_changed.connect(_on_player_count_changed)

	# Player setup rows
	_add_spacer(4)
	var players_header := Label.new()
	players_header.text = "Player Setup"
	players_header.add_theme_font_size_override("font_size", 16)
	players_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_container.add_child(players_header)

	for i in range(8):
		var row := _add_player_row(i)
		_player_rows.append(row)

	_on_player_count_changed(2)
	_update_max_castles_default()

	# Start button
	_add_spacer(10)
	_start_button = Button.new()
	_start_button.text = "START MATCH"
	_start_button.custom_minimum_size = Vector2(280, 45)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.pressed.connect(_on_start_pressed)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_start_button)
	_container.add_child(btn_center)

	_add_spacer(5)
	var controls_lbl := Label.new()
	controls_lbl.text = "P1: WASD/Space | P2: Arrows/Enter | P3: IJKL/H | P4: Numpad"
	controls_lbl.add_theme_font_size_override("font_size", 12)
	controls_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(controls_lbl)


func _add_section_header(text: String) -> void:
	_add_spacer(8)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.2, 0.6)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	_container.add_child(panel)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.4))
	panel.add_child(lbl)
	_add_spacer(2)


func _add_check_row(label_text: String, default_val: bool) -> CheckBox:
	_add_spacer(2)
	var row := HBoxContainer.new()
	_container.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.custom_minimum_size.x = 180
	row.add_child(lbl)
	var cb := CheckBox.new()
	cb.button_pressed = default_val
	row.add_child(cb)
	return cb


func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	_container.add_child(spacer)


func _add_slider_row(label_text: String, min_val: float, max_val: float, default_val: float) -> Dictionary:
	var row := HBoxContainer.new()
	_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.custom_minimum_size.x = 180
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = 1
	slider.custom_minimum_size.x = 230
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.custom_minimum_size.x = 80
	row.add_child(val_lbl)

	# Initialize display text
	if label_text == "Grid Size":
		val_lbl.text = "%dx%d" % [int(default_val), int(default_val)]
	elif label_text == "Capture Threshold":
		val_lbl.text = "%d hits" % int(default_val)
	elif label_text == "Time Limit":
		val_lbl.text = "%d:%02d" % [int(default_val) / 60, int(default_val) % 60]
	else:
		val_lbl.text = str(int(default_val))

	return {"slider": slider, "value_label": val_lbl}


func _add_player_row(index: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 26
	_container.add_child(row)

	var color: Color = PLAYER_COLORS[index] if index < PLAYER_COLORS.size() else Color.WHITE
	var name_text: String = PLAYER_NAMES[index] if index < PLAYER_NAMES.size() else "P%d" % (index + 1)

	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(18, 18)
	color_rect.color = color
	row.add_child(color_rect)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	row.add_child(spacer)

	var name_lbl := Label.new()
	name_lbl.text = name_text
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.custom_minimum_size.x = 80
	row.add_child(name_lbl)

	var type_option := OptionButton.new()
	type_option.add_item("Human", 0)
	type_option.add_item("CPU Easy", 1)
	type_option.add_item("CPU Medium", 2)
	type_option.add_item("CPU Hard", 3)
	type_option.selected = 0 if index == 0 else 2
	type_option.custom_minimum_size.x = 140
	row.add_child(type_option)

	return {"row": row, "type": type_option, "name": name_text}


func _on_player_count_changed(value: float) -> void:
	var count := int(value)
	_player_count_label.text = "%d" % count
	for i in range(8):
		_player_rows[i]["row"].visible = i < count
	_update_max_castles_default()


func _update_max_castles_default() -> void:
	var grid := int(_grid_size_slider.value)
	var players := int(_player_count_slider.value)
	_max_castles_slider.max_value = grid * grid
	var mc := GameConfig.calc_default_max_castles(grid, players)
	_max_castles_slider.value = mc
	_max_castles_label.text = "%d (of %d)" % [mc, grid * grid]


func _add_curve_row(label_text: String, default_idx: int) -> OptionButton:
	var row := HBoxContainer.new()
	_container.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.custom_minimum_size.x = 180
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.add_item("Power of Two (1,2,4,8..)", 0)
	opt.add_item("Count (1,2,3,4..)", 1)
	opt.add_item("Fibonacci (1,2,3,5..)", 2)
	opt.add_item("Square (1,4,9,16..)", 3)
	opt.selected = default_idx
	opt.custom_minimum_size.x = 230
	opt.item_selected.connect(func(_i: int) -> void: _update_score_preview())
	row.add_child(opt)
	return opt


func _update_score_preview() -> void:
	if _preview_label == null:
		return
	var adj := ScorerConfig.new()
	adj.curve = _adj_curve_option.selected as CKEnums.CurveType
	var con := ScorerConfig.new()
	con.curve = _con_curve_option.selected as CKEnums.CurveType
	var cap := ScorerConfig.new()
	cap.curve = _cap_curve_option.selected as CKEnums.CurveType
	cap.multiplier = 1.2
	_preview_label.text = "Preview n=1..5:  Adj: %s  Con: %s  Cap: %s" % [
		str(adj.preview(5)), str(con.preview(5)), str(cap.preview(5))]


func _get_score_preview() -> String:
	var c := GameConfig.new()
	var adj := c.adjacency_scorer.preview(5)
	var con := c.contagion_scorer.preview(5)
	var cap := c.capture_scorer.preview(5)
	return "Score preview (n=1..5):  Adjacency: %s  |  Contagion: %s  |  Capture: %s" % [
		str(adj), str(con), str(cap)]


func _apply_preset(preset: Dictionary) -> void:
	_grid_size_slider.value = preset.get("grid_size", 8)
	_threshold_slider.value = preset.get("capture_threshold", 3)
	_time_slider.value = preset.get("time_limit", 90)
	_player_count_slider.value = preset.get("player_count", 2)
	_allow_tap_check.button_pressed = preset.get("allow_tap", true)
	_wrap_check.button_pressed = preset.get("wrap_around", true)
	if _shape_option:
		_shape_option.selected = preset.get("board_shape", 0)
	if _danger_slider:
		_danger_slider.value = preset.get("danger_cell_count", 0)
	if _bonus_slider:
		_bonus_slider.value = preset.get("bonus_cell_count", 0)
	_update_max_castles_default()
	var mc: int = preset.get("max_castles", 0)
	if mc > 0:
		_max_castles_slider.value = mc


func _save_current_preset() -> void:
	var name_text := _preset_name_edit.text.strip_edges()
	if name_text.is_empty():
		return
	var config := GameConfig.new()
	config.grid_size = int(_grid_size_slider.value)
	config.capture_threshold = int(_threshold_slider.value)
	config.time_limit = int(_time_slider.value)
	config.player_count = int(_player_count_slider.value)
	config.max_castles = int(_max_castles_slider.value)
	config.allow_tap = _allow_tap_check.button_pressed
	config.board_shape = _shape_option.selected as CKEnums.BoardShape
	config.danger_cell_count = int(_danger_slider.value)
	config.bonus_cell_count = int(_bonus_slider.value)
	var preset := PresetManager.config_to_preset(config, name_text)
	PresetManager.save_user_preset(name_text, preset)
	_preset_name_edit.text = ""


func _on_start_pressed() -> void:
	var config := GameConfig.new()
	config.grid_size = int(_grid_size_slider.value)
	config.capture_threshold = int(_threshold_slider.value)
	config.time_limit = int(_time_slider.value)
	config.player_count = int(_player_count_slider.value)
	config.wrap_around = _wrap_check.button_pressed
	config.allow_tap = _allow_tap_check.button_pressed
	config.max_castles = int(_max_castles_slider.value)
	config.winning_score = int(_winning_score_slider.value)
	config.scoring_mode = _scoring_mode_option.selected as CKEnums.ScoringMode
	config.lone_castle_scores_zero = _lone_castle_check.button_pressed
	config.cursor_select_captured = _cursor_captured_check.button_pressed

	config.board_shape = _shape_option.selected as CKEnums.BoardShape
	config.pre_placed_castles = _pre_placed_check.button_pressed
	config.skip_blanks = _skip_blanks_check.button_pressed
	config.persistent_specials = _persistent_check.button_pressed
	config.danger_cell_count = int(_danger_slider.value)
	config.bonus_cell_count = int(_bonus_slider.value)
	config.neutral_count = int(_neutral_slider.value)
	config.reinforced_count = int(_reinforced_slider.value)
	config.fortified_count = int(_fortified_slider.value)
	config.max_actions = int(_max_actions_slider.value)
	config.adjacency_scorer.curve = _adj_curve_option.selected as CKEnums.CurveType
	config.contagion_scorer.curve = _con_curve_option.selected as CKEnums.CurveType
	config.capture_scorer.curve = _cap_curve_option.selected as CKEnums.CurveType

	var speed_idx := _speed_option.selected
	config.apply_speed_preset(speed_idx as CKEnums.SpeedPreset)

	# Save settings for next session
	SettingsManager.save_config(config)

	var setup: Array[Dictionary] = []
	for i in range(config.player_count):
		var type_sel: int = _player_rows[i]["type"].selected
		setup.append({
			"player_id": i,
			"name": _player_rows[i]["name"],
			"is_cpu": type_sel > 0,
			"difficulty": type_sel,
		})

	match_requested.emit(config, setup)
