## Custom board editor — click cells to toggle types, save/load presets.
class_name BoardEditor
extends Control

signal back_pressed()

const CELL_TYPES: Array[String] = ["Empty", "Blocked", "Neutral", "Danger", "Bonus", "Reinforced", "Fortified"]
const CELL_COLORS: Array[Color] = [
	Color(0.25, 0.25, 0.3),   # Empty
	Color(0.1, 0.1, 0.12),    # Blocked
	Color(0.35, 0.35, 0.38),  # Neutral
	Color(0.4, 0.15, 0.15),   # Danger
	Color(0.35, 0.35, 0.1),   # Bonus
	Color(0.45, 0.4, 0.3),    # Reinforced
	Color(0.5, 0.45, 0.2),    # Fortified
]

const PRESETS_PATH := "user://board_presets.json"

var _grid_size: int = 8
var _cell_data: Array[int] = []  # 0=empty, 1=blocked, 2=neutral, 3=danger, 4=bonus, 5=reinforced, 6=fortified
var _cell_rects: Array[ColorRect] = []
var _cell_labels: Array[Label] = []
var _current_tool: int = 1  # Default: blocked
var _grid_origin := Vector2.ZERO
var _cell_px: int = 50
var _tool_buttons: Array[Button] = []
var _name_edit: LineEdit
var _preset_list: VBoxContainer
var _grid_container: Control


func _ready() -> void:
	_cell_data.resize(_grid_size * _grid_size)
	for i in range(_cell_data.size()):
		_cell_data[i] = 0
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	var vp := get_viewport().get_visible_rect().size

	# Title
	var title := Label.new()
	title.text = "Board Editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(vp.x / 2 - 150, 15)
	title.size = Vector2(300, 35)
	add_child(title)

	# Tool palette
	var tools_panel := VBoxContainer.new()
	tools_panel.position = Vector2(20, 60)
	add_child(tools_panel)

	var tools_label := Label.new()
	tools_label.text = "Paint Tool:"
	tools_label.add_theme_font_size_override("font_size", 14)
	tools_panel.add_child(tools_label)

	for i in range(CELL_TYPES.size()):
		var btn := Button.new()
		btn.text = CELL_TYPES[i]
		btn.custom_minimum_size = Vector2(120, 28)
		btn.add_theme_font_size_override("font_size", 12)
		var idx := i
		btn.pressed.connect(func() -> void: _select_tool(idx))
		tools_panel.add_child(btn)
		_tool_buttons.append(btn)
	_select_tool(1)

	# Grid size selector
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	tools_panel.add_child(spacer)

	var size_label := Label.new()
	size_label.text = "Grid Size:"
	size_label.add_theme_font_size_override("font_size", 14)
	tools_panel.add_child(size_label)

	var size_slider := HSlider.new()
	size_slider.min_value = 6
	size_slider.max_value = 12
	size_slider.value = 8
	size_slider.step = 1
	size_slider.custom_minimum_size.x = 120
	size_slider.value_changed.connect(func(v: float) -> void: _resize_grid(int(v)))
	tools_panel.add_child(size_slider)

	# Save/load
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 10
	tools_panel.add_child(spacer2)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Preset name..."
	_name_edit.custom_minimum_size = Vector2(120, 28)
	tools_panel.add_child(_name_edit)

	var save_btn := Button.new()
	save_btn.text = "Save Preset"
	save_btn.custom_minimum_size = Vector2(120, 28)
	save_btn.pressed.connect(_save_preset)
	tools_panel.add_child(save_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(120, 28)
	clear_btn.pressed.connect(_clear_grid)
	tools_panel.add_child(clear_btn)

	# Preset list
	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 10
	tools_panel.add_child(spacer3)

	var presets_label := Label.new()
	presets_label.text = "Saved:"
	presets_label.add_theme_font_size_override("font_size", 14)
	tools_panel.add_child(presets_label)

	_preset_list = VBoxContainer.new()
	tools_panel.add_child(_preset_list)
	_load_preset_list()

	# Grid
	_grid_container = Control.new()
	add_child(_grid_container)
	_build_grid()

	# Back button
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(vp.x - 100, 20)
	back.custom_minimum_size = Vector2(80, 35)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func _build_grid() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	_cell_rects.clear()
	_cell_labels.clear()

	var vp := get_viewport().get_visible_rect().size
	var available := minf(vp.x - 200, vp.y - 80)
	_cell_px = int(available / _grid_size) - 2
	var total := (_cell_px + 2) * _grid_size
	_grid_origin = Vector2((vp.x - total) / 2.0 + 60, 60)

	for i in range(_grid_size * _grid_size):
		var row := i / _grid_size
		var col := i % _grid_size
		var pos := _grid_origin + Vector2(col * (_cell_px + 2), row * (_cell_px + 2))

		var rect := ColorRect.new()
		rect.size = Vector2(_cell_px, _cell_px)
		rect.position = pos
		rect.color = CELL_COLORS[_cell_data[i] if i < _cell_data.size() else 0]
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		rect.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_paint_cell(idx))
		_grid_container.add_child(rect)
		_cell_rects.append(rect)

		var lbl := Label.new()
		lbl.position = pos + Vector2(2, 2)
		lbl.add_theme_font_size_override("font_size", clampi(_cell_px / 4, 6, 12))
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_grid_container.add_child(lbl)
		_cell_labels.append(lbl)

	_update_labels()


func _paint_cell(index: int) -> void:
	if index >= _cell_data.size():
		return
	_cell_data[index] = _current_tool
	_cell_rects[index].color = CELL_COLORS[_current_tool]
	_update_labels()


func _select_tool(tool_idx: int) -> void:
	_current_tool = tool_idx
	for i in range(_tool_buttons.size()):
		if i == tool_idx:
			_tool_buttons[i].add_theme_color_override("font_color", Color(1, 1, 0.3))
		else:
			_tool_buttons[i].remove_theme_color_override("font_color")


func _resize_grid(new_size: int) -> void:
	_grid_size = new_size
	_cell_data.resize(_grid_size * _grid_size)
	for i in range(_cell_data.size()):
		_cell_data[i] = 0
	_build_grid()


func _clear_grid() -> void:
	for i in range(_cell_data.size()):
		_cell_data[i] = 0
	for i in range(_cell_rects.size()):
		_cell_rects[i].color = CELL_COLORS[0]
	_update_labels()


func _update_labels() -> void:
	for i in range(_cell_labels.size()):
		if i >= _cell_data.size():
			break
		var t := _cell_data[i]
		match t:
			0: _cell_labels[i].text = ""
			1: _cell_labels[i].text = "X"
			2: _cell_labels[i].text = "N"
			3: _cell_labels[i].text = "!"
			4: _cell_labels[i].text = "*"
			5: _cell_labels[i].text = "+1"
			6: _cell_labels[i].text = "+2"


func _save_preset() -> void:
	var name_text := _name_edit.text.strip_edges()
	if name_text.is_empty():
		return
	var presets := _load_presets()
	presets[name_text] = {"grid_size": _grid_size, "cells": Array(_cell_data)}
	_save_presets(presets)
	_name_edit.text = ""
	_load_preset_list()


func _load_preset(name_text: String) -> void:
	var presets := _load_presets()
	if name_text not in presets:
		return
	var data: Dictionary = presets[name_text]
	_grid_size = data.get("grid_size", 8)
	var cells: Array = data.get("cells", [])
	_cell_data.resize(_grid_size * _grid_size)
	for i in range(_cell_data.size()):
		_cell_data[i] = cells[i] if i < cells.size() else 0
	_build_grid()


func _load_preset_list() -> void:
	for child in _preset_list.get_children():
		child.queue_free()
	var presets := _load_presets()
	for name_text: String in presets:
		var btn := Button.new()
		btn.text = name_text
		btn.custom_minimum_size = Vector2(120, 24)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_load_preset.bind(name_text))
		_preset_list.add_child(btn)


func _load_presets() -> Dictionary:
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _save_presets(data: Dictionary) -> void:
	var file := FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
