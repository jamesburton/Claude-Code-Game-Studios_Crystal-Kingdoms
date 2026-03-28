## Pre-match configuration screen.
## Lets players set grid size, player count, human/CPU, difficulty, and speed.
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
var _player_rows: Array[Dictionary] = []
var _start_button: Button
var _container: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.12, 0.15)
	add_child(bg)

	_container = VBoxContainer.new()
	_container.position = Vector2(340, 30)
	_container.size = Vector2(600, 660)
	add_child(_container)

	# Title
	var title := Label.new()
	title.text = "Crystal Kingdoms"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)

	_add_spacer(10)

	# Grid size
	var grid_row := _add_slider_row("Grid Size", 6, 12, 8)
	_grid_size_slider = grid_row["slider"]
	_grid_size_label = grid_row["value_label"]
	_grid_size_slider.value_changed.connect(func(v: float) -> void:
		_grid_size_label.text = "%dx%d" % [int(v), int(v)])

	# Capture threshold
	var thresh_row := _add_slider_row("Capture Threshold", 1, 10, 3)
	_threshold_slider = thresh_row["slider"]
	_threshold_label = thresh_row["value_label"]
	_threshold_slider.value_changed.connect(func(v: float) -> void:
		_threshold_label.text = "%d hits" % int(v))

	# Time limit
	var time_row := _add_slider_row("Time Limit", 30, 600, 180)
	_time_slider = time_row["slider"]
	_time_label = time_row["value_label"]
	_time_slider.step = 30
	_time_slider.value_changed.connect(func(v: float) -> void:
		_time_label.text = "%d:%02d" % [int(v) / 60, int(v) % 60])

	# Speed preset
	_add_spacer(5)
	var speed_row := HBoxContainer.new()
	_container.add_child(speed_row)
	var speed_lbl := Label.new()
	speed_lbl.text = "Speed Preset: "
	speed_lbl.add_theme_font_size_override("font_size", 16)
	speed_lbl.custom_minimum_size.x = 200
	speed_row.add_child(speed_lbl)
	_speed_option = OptionButton.new()
	_speed_option.add_item("Relaxed", 0)
	_speed_option.add_item("Normal", 1)
	_speed_option.add_item("Fast", 2)
	_speed_option.add_item("Frantic", 3)
	_speed_option.selected = 1
	_speed_option.custom_minimum_size.x = 200
	speed_row.add_child(_speed_option)

	# Player count
	_add_spacer(10)
	var pcount_row := _add_slider_row("Players", 2, 8, 2)
	_player_count_slider = pcount_row["slider"]
	_player_count_label = pcount_row["value_label"]
	_player_count_slider.value_changed.connect(_on_player_count_changed)

	# Player setup rows
	_add_spacer(5)
	var players_header := Label.new()
	players_header.text = "Player Setup"
	players_header.add_theme_font_size_override("font_size", 18)
	players_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_container.add_child(players_header)

	for i in range(8):
		var row := _add_player_row(i)
		_player_rows.append(row)

	_on_player_count_changed(2)

	# Start button
	_add_spacer(15)
	_start_button = Button.new()
	_start_button.text = "START MATCH"
	_start_button.custom_minimum_size = Vector2(300, 50)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.pressed.connect(_on_start_pressed)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_start_button)
	_container.add_child(btn_center)


func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	_container.add_child(spacer)


func _add_slider_row(label_text: String, min_val: float, max_val: float, default: float) -> Dictionary:
	var row := HBoxContainer.new()
	_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.custom_minimum_size.x = 200
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default
	slider.step = 1
	slider.custom_minimum_size.x = 250
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = str(int(default))
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.custom_minimum_size.x = 80
	row.add_child(val_lbl)

	# Initialize display
	if label_text == "Grid Size":
		val_lbl.text = "%dx%d" % [int(default), int(default)]
	elif label_text == "Capture Threshold":
		val_lbl.text = "%d hits" % int(default)
	elif label_text == "Time Limit":
		val_lbl.text = "%d:%02d" % [int(default) / 60, int(default) % 60]

	return {"slider": slider, "value_label": val_lbl}


func _add_player_row(index: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	_container.add_child(row)

	var color: Color = PLAYER_COLORS[index] if index < PLAYER_COLORS.size() else Color.WHITE
	var name_text: String = PLAYER_NAMES[index] if index < PLAYER_NAMES.size() else "P%d" % (index + 1)

	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(20, 20)
	color_rect.color = color
	row.add_child(color_rect)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 10
	row.add_child(spacer)

	var name_lbl := Label.new()
	name_lbl.text = name_text
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.custom_minimum_size.x = 100
	row.add_child(name_lbl)

	var type_option := OptionButton.new()
	type_option.add_item("Human", 0)
	type_option.add_item("CPU Easy", 1)
	type_option.add_item("CPU Medium", 2)
	type_option.add_item("CPU Hard", 3)
	type_option.selected = 0 if index == 0 else 2  # P1 human, others CPU Medium
	type_option.custom_minimum_size.x = 150
	row.add_child(type_option)

	return {"row": row, "type": type_option, "name": name_text}


func _on_player_count_changed(value: float) -> void:
	var count := int(value)
	_player_count_label.text = "%d" % count
	for i in range(8):
		_player_rows[i]["row"].visible = i < count


func _on_start_pressed() -> void:
	var config := GameConfig.new()
	config.grid_size = int(_grid_size_slider.value)
	config.capture_threshold = int(_threshold_slider.value)
	config.time_limit = int(_time_slider.value)
	config.player_count = int(_player_count_slider.value)
	config.wrap_around = true

	var speed_idx := _speed_option.selected
	config.apply_speed_preset(speed_idx as CKEnums.SpeedPreset)

	var setup: Array[Dictionary] = []
	for i in range(config.player_count):
		var type_sel: int = _player_rows[i]["type"].selected
		setup.append({
			"player_id": i,
			"name": _player_rows[i]["name"],
			"is_cpu": type_sel > 0,
			"difficulty": type_sel,  # 0=human, 1=easy, 2=medium, 3=hard
		})

	match_requested.emit(config, setup)
