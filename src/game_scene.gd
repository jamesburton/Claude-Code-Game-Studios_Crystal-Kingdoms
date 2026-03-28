## Main game scene — config screen → match → results → loop.
## Wires ConfigScreen, MatchFlow, BoardRenderer, HUD, and input.
extends Control

var _match_flow: MatchFlow
var _renderer: BoardRenderer
var _hud: GameHud
var _sound: SoundManager
var _config_screen: ConfigScreen
var _config: GameConfig
var _player_setup: Array[Dictionary] = []
var _human_players: Array[int] = []
var _in_match: bool = false

# Keyboard binding map: key → {player, direction}
# Direction -1 = tap, 0-3 = CKEnums.Direction
const KEY_BINDINGS: Dictionary = {
	KEY_W: {"player": 0, "dir": 0},       # P1 UP
	KEY_S: {"player": 0, "dir": 1},       # P1 DOWN
	KEY_A: {"player": 0, "dir": 2},       # P1 LEFT
	KEY_D: {"player": 0, "dir": 3},       # P1 RIGHT
	KEY_SPACE: {"player": 0, "dir": -1},  # P1 TAP
	KEY_UP: {"player": 1, "dir": 0},      # P2 UP
	KEY_DOWN: {"player": 1, "dir": 1},    # P2 DOWN
	KEY_LEFT: {"player": 1, "dir": 2},    # P2 LEFT
	KEY_RIGHT: {"player": 1, "dir": 3},   # P2 RIGHT
	KEY_ENTER: {"player": 1, "dir": -1},  # P2 TAP
	KEY_I: {"player": 2, "dir": 0},       # P3 UP
	KEY_K: {"player": 2, "dir": 1},       # P3 DOWN
	KEY_J: {"player": 2, "dir": 2},       # P3 LEFT
	KEY_L: {"player": 2, "dir": 3},       # P3 RIGHT
	KEY_H: {"player": 2, "dir": -1},      # P3 TAP
	KEY_KP_8: {"player": 3, "dir": 0},    # P4 UP
	KEY_KP_5: {"player": 3, "dir": 1},    # P4 DOWN
	KEY_KP_4: {"player": 3, "dir": 2},    # P4 LEFT
	KEY_KP_6: {"player": 3, "dir": 3},    # P4 RIGHT
	KEY_KP_0: {"player": 3, "dir": -1},   # P4 TAP
}


func _ready() -> void:
	_show_config_screen()


func _show_config_screen() -> void:
	_clear_scene()
	_in_match = false
	_config_screen = ConfigScreen.new()
	_config_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_config_screen.size = get_viewport().get_visible_rect().size
	add_child(_config_screen)
	_config_screen.match_requested.connect(_on_match_requested)


func _on_match_requested(config: GameConfig, setup: Array[Dictionary]) -> void:
	_config = config
	_player_setup = setup
	_start_match()


func _start_match() -> void:
	_clear_scene()
	_in_match = true

	# Dark background for contrast
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.1)
	add_child(bg)

	# Determine which players are human
	_human_players.clear()
	for p: Dictionary in _player_setup:
		if not p["is_cpu"]:
			_human_players.append(p["player_id"])

	# Create match
	_match_flow = MatchFlow.new(_config)
	_match_flow.start()

	# Add CPU controllers
	for p: Dictionary in _player_setup:
		if p["is_cpu"]:
			var diff_level: int = p["difficulty"]
			var diff_path: String
			match diff_level:
				1: diff_path = "res://src/data/cpu_difficulty_easy.tres"
				2: diff_path = "res://src/data/cpu_difficulty_medium.tres"
				3: diff_path = "res://src/data/cpu_difficulty_hard.tres"
				_: diff_path = "res://src/data/cpu_difficulty_medium.tres"
			var diff: CpuDifficulty = load(diff_path) as CpuDifficulty
			if diff:
				_match_flow.add_cpu(p["player_id"], diff)

	# Board renderer
	_renderer = BoardRenderer.new()
	add_child(_renderer)
	_renderer.setup(
		_match_flow.board,
		_match_flow.config.chain_step_delay,
		get_viewport().get_visible_rect().size)
	_renderer.animation_complete.connect(_on_animation_complete)

	# Connect signals
	_match_flow.action_events.connect(_on_action_events)
	_match_flow.match_ended.connect(func(_s: Dictionary) -> void:
		if _sound: _sound.play("match_end"))
	_match_flow.turn_director.cursor_spawned.connect(func(_i: int) -> void:
		if _sound: _sound.play("cursor_spawn"))

	# Sound
	_sound = SoundManager.new()
	add_child(_sound)

	# HUD
	_hud = GameHud.new()
	add_child(_hud)
	_hud.setup(_match_flow)


func _process(delta: float) -> void:
	if _match_flow == null or _match_flow.state != MatchFlow.State.PLAYING:
		return
	_match_flow.tick(delta)
	_check_input()


func _check_input() -> void:
	if _match_flow.turn_director.state != TurnDirector.State.ACTIVE:
		return

	# Keyboard input
	for key: int in KEY_BINDINGS:
		if Input.is_key_pressed(key):
			var binding: Dictionary = KEY_BINDINGS[key]
			var player: int = binding["player"]
			var dir: int = binding["dir"]
			if player not in _human_players:
				continue
			if dir == -1 and not _match_flow.config.allow_tap:
				continue
			_do_action(player, dir)
			return

	# Gamepad input — each connected gamepad maps to a human player
	_check_gamepad_input()


const STICK_DEADZONE := 0.5

func _check_gamepad_input() -> void:
	var pads := Input.get_connected_joypads()
	for pad_idx: int in pads:
		# Map gamepad index to the nth human player
		if pad_idx >= _human_players.size():
			break
		var player: int = _human_players[pad_idx]

		# D-pad / left stick directions
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_UP) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_Y) < -STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.UP)
			return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_DOWN) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_Y) > STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.DOWN)
			return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_LEFT) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_X) < -STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.LEFT)
			return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_RIGHT) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_X) > STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.RIGHT)
			return

		# Face button A/Cross = tap
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_A):
			if _match_flow.config.allow_tap:
				_do_action(player, -1)
				return


func _do_action(player: int, direction: int) -> void:
	_match_flow.submit_action(player, direction)
	# Events are rendered via action_events signal (handles human + CPU uniformly)


func _on_action_events(events: Array) -> void:
	if _renderer:
		_renderer.play_events(events)
	if _sound and not events.is_empty():
		# Play SFX for the first significant event
		for ev: Dictionary in events:
			var ev_type: int = ev.get("type", -1)
			match ev_type:
				CKEnums.EventType.CAPTURE_EMPTY:
					_sound.play("capture_empty")
					break
				CKEnums.EventType.INCREMENT_CONTAGION:
					_sound.play("contagion")
					break
				CKEnums.EventType.CAPTURE_CONTAGION:
					_sound.play("capture_contagion")
					break
				CKEnums.EventType.DESTROY_OWN_CASTLE:
					_sound.play("destroy")
					break


func _on_animation_complete() -> void:
	if _match_flow:
		_match_flow.on_animation_complete()


func _clear_scene() -> void:
	# Disconnect signals before clearing to prevent stale callbacks
	if _match_flow:
		if _match_flow.action_events.is_connected(_on_action_events):
			_match_flow.action_events.disconnect(_on_action_events)
	if _renderer:
		if _renderer.animation_complete.is_connected(_on_animation_complete):
			_renderer.animation_complete.disconnect(_on_animation_complete)
	for child in get_children():
		child.queue_free()
	_match_flow = null
	_renderer = null
	_hud = null
	_sound = null
	_config_screen = null


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_R:
			# Rematch with same config
			if _in_match and _match_flow and _match_flow.state == MatchFlow.State.COMPLETE:
				_start_match()
		KEY_ESCAPE:
			# Back to config from match-end or during gameplay
			if _in_match:
				_show_config_screen()
