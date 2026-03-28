## Main game scene — config screen → match → results → loop.
## Wires ConfigScreen, MatchFlow, BoardRenderer, HUD, and input.
extends Node2D

var _match_flow: MatchFlow
var _renderer: BoardRenderer
var _hud: GameHud
var _config_screen: ConfigScreen
var _config: GameConfig
var _player_setup: Array[Dictionary] = []
var _human_players: Array[int] = []

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
	_config_screen = ConfigScreen.new()
	_config_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_config_screen)
	_config_screen.match_requested.connect(_on_match_requested)


func _on_match_requested(config: GameConfig, setup: Array[Dictionary]) -> void:
	_config = config
	_player_setup = setup
	_start_match()


func _start_match() -> void:
	_clear_scene()

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
		Vector2(1280, 720))
	_renderer.animation_complete.connect(_on_animation_complete)

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

	for key: int in KEY_BINDINGS:
		if Input.is_key_pressed(key):
			var binding: Dictionary = KEY_BINDINGS[key]
			var player: int = binding["player"]
			# Only accept input from human players
			if player in _human_players:
				_do_action(player, binding["dir"])
				return


func _do_action(player: int, direction: int) -> void:
	var events = _match_flow.submit_action(player, direction)
	if events.is_empty():
		return
	_renderer.play_events(events)


func _on_animation_complete() -> void:
	if _match_flow:
		_match_flow.on_animation_complete()


func _clear_scene() -> void:
	for child in get_children():
		child.queue_free()
	_match_flow = null
	_renderer = null
	_hud = null
	_config_screen = null


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_R:
			if _match_flow and _match_flow.state == MatchFlow.State.COMPLETE:
				_start_match()  # Rematch with same config
		KEY_ESCAPE:
			if _match_flow and _match_flow.state == MatchFlow.State.COMPLETE:
				_show_config_screen()  # Back to config
			elif _config_screen == null and _match_flow:
				_show_config_screen()  # Quit match to config
