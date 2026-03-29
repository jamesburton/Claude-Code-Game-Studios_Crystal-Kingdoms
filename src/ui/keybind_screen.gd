## Keyboard rebinding UI.
## Click an action to enter rebind mode, press a key to bind it.
class_name KeybindScreen
extends Control

signal back_pressed()

const ACTIONS: Array[String] = ["Up", "Down", "Left", "Right", "Fire"]
const DEFAULT_BINDINGS: Array[Array] = [
	[KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE],           # P1
	[KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER], # P2
	[KEY_I, KEY_K, KEY_J, KEY_L, KEY_H],                # P3
	[KEY_KP_8, KEY_KP_5, KEY_KP_4, KEY_KP_6, KEY_KP_0], # P4
]

var _bindings: Array[Array] = []  # [[key, key, key, key, key], ...]
var _rebinding_player: int = -1
var _rebinding_action: int = -1
var _bind_buttons: Array[Array] = []  # [[Button, ...], ...]
var _status_label: Label


func _ready() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate(true)
	_load_bindings()
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	var vp := get_viewport().get_visible_rect().size

	var title := Label.new()
	title.text = "Keyboard Bindings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(vp.x / 2 - 200, 30)
	title.size = Vector2(400, 40)
	add_child(title)

	var grid := GridContainer.new()
	grid.columns = 6  # Label + 5 actions
	grid.position = Vector2(vp.x / 2 - 280, 90)
	add_child(grid)

	# Header row
	var corner := Label.new()
	corner.text = ""
	corner.custom_minimum_size.x = 80
	grid.add_child(corner)
	for action: String in ACTIONS:
		var h := Label.new()
		h.text = action
		h.add_theme_font_size_override("font_size", 16)
		h.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		h.custom_minimum_size = Vector2(90, 30)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)

	# Player rows
	_bind_buttons.clear()
	for p in range(4):
		var row_btns: Array[Button] = []

		var lbl := Label.new()
		lbl.text = "Player %d" % (p + 1)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.custom_minimum_size.x = 80
		grid.add_child(lbl)

		for a in range(5):
			var btn := Button.new()
			btn.text = OS.get_keycode_string(_bindings[p][a])
			btn.custom_minimum_size = Vector2(90, 32)
			btn.add_theme_font_size_override("font_size", 13)
			var bp := p
			var ba := a
			btn.pressed.connect(func() -> void: _start_rebind(bp, ba))
			grid.add_child(btn)
			row_btns.append(btn)

		_bind_buttons.append(row_btns)

	# Status
	_status_label = Label.new()
	_status_label.text = "Click a binding to change it"
	_status_label.position = Vector2(vp.x / 2 - 150, vp.y - 120)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_status_label)

	# Reset button
	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.custom_minimum_size = Vector2(180, 35)
	reset.position = Vector2(vp.x / 2 - 90, vp.y - 80)
	reset.pressed.connect(_reset_defaults)
	add_child(reset)

	# Back button
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 20)
	back.custom_minimum_size = Vector2(80, 35)
	back.pressed.connect(func() -> void:
		_save_bindings()
		back_pressed.emit())
	add_child(back)


func _start_rebind(player: int, action: int) -> void:
	_rebinding_player = player
	_rebinding_action = action
	_bind_buttons[player][action].text = "Press key..."
	_bind_buttons[player][action].add_theme_color_override("font_color", Color(1, 1, 0.3))
	_status_label.text = "Press a key for Player %d %s (Escape to cancel)" % [player + 1, ACTIONS[action]]


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_player < 0:
		return
	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_ESCAPE:
		# Cancel rebind
		_bind_buttons[_rebinding_player][_rebinding_action].text = \
			OS.get_keycode_string(_bindings[_rebinding_player][_rebinding_action])
		_bind_buttons[_rebinding_player][_rebinding_action].remove_theme_color_override("font_color")
		_rebinding_player = -1
		_rebinding_action = -1
		_status_label.text = "Rebind cancelled"
		return

	# Apply new binding
	_bindings[_rebinding_player][_rebinding_action] = event.keycode
	_bind_buttons[_rebinding_player][_rebinding_action].text = OS.get_keycode_string(event.keycode)
	_bind_buttons[_rebinding_player][_rebinding_action].remove_theme_color_override("font_color")

	# Check for conflicts
	_check_conflicts()

	_rebinding_player = -1
	_rebinding_action = -1
	_status_label.text = "Binding updated"
	get_viewport().set_input_as_handled()


func _check_conflicts() -> void:
	var all_keys: Dictionary = {}  # {keycode: "P1 Up"}
	for p in range(4):
		for a in range(5):
			var key: int = _bindings[p][a]
			var label := "P%d %s" % [p + 1, ACTIONS[a]]
			if key in all_keys:
				_status_label.text = "Conflict: %s and %s share %s" % [
					all_keys[key], label, OS.get_keycode_string(key)]
				_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
				return
			all_keys[key] = label
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _reset_defaults() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate(true)
	for p in range(4):
		for a in range(5):
			_bind_buttons[p][a].text = OS.get_keycode_string(_bindings[p][a])
	_status_label.text = "Reset to defaults"


func _save_bindings() -> void:
	var cf := ConfigFile.new()
	for p in range(4):
		for a in range(5):
			cf.set_value("bindings", "p%d_%s" % [p, ACTIONS[a].to_lower()], _bindings[p][a])
	cf.save("user://keybindings.cfg")


func _load_bindings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://keybindings.cfg") != OK:
		return
	for p in range(4):
		for a in range(5):
			var key: int = cf.get_value("bindings", "p%d_%s" % [p, ACTIONS[a].to_lower()], _bindings[p][a])
			_bindings[p][a] = key


## Get the current bindings as a dictionary for GameScene to use.
func get_bindings_dict() -> Dictionary:
	var result: Dictionary = {}
	var dirs: Array[int] = [0, 1, 2, 3, -1]  # UP, DOWN, LEFT, RIGHT, TAP
	for p in range(4):
		for a in range(5):
			result[_bindings[p][a]] = {"player": p, "dir": dirs[a]}
	return result
