## Main game scene — wires MatchFlow, BoardRenderer, HUD, and input together.
## This is the entry point for a playable Crystal Kingdoms match.
extends Node2D

var _match_flow: MatchFlow
var _renderer: BoardRenderer
var _hud: GameHud
var _config: GameConfig


func _ready() -> void:
	_config = GameConfig.new()
	_config.grid_size = 8
	_config.player_count = 2
	_config.time_limit = 180
	_config.capture_threshold = 3
	_config.wrap_around = true
	_config.apply_speed_preset(CKEnums.SpeedPreset.NORMAL)

	_start_match()


func _start_match() -> void:
	# Clear previous match if restarting
	for child in get_children():
		child.queue_free()

	# Create match
	_match_flow = MatchFlow.new(_config)
	_match_flow.start()

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
	if _match_flow == null:
		return
	if _match_flow.state != MatchFlow.State.PLAYING:
		return

	_match_flow.tick(delta)
	_check_input()


func _check_input() -> void:
	if _match_flow.turn_director.state != TurnDirector.State.ACTIVE:
		return

	# Player 1: WASD = swipe, Space = tap
	if Input.is_key_pressed(KEY_W):
		_do_action(0, CKEnums.Direction.UP)
		return
	if Input.is_key_pressed(KEY_S):
		_do_action(0, CKEnums.Direction.DOWN)
		return
	if Input.is_key_pressed(KEY_A):
		_do_action(0, CKEnums.Direction.LEFT)
		return
	if Input.is_key_pressed(KEY_D):
		_do_action(0, CKEnums.Direction.RIGHT)
		return
	if Input.is_key_pressed(KEY_SPACE):
		_do_action(0, -1)
		return

	# Player 2: Arrows = swipe, Enter = tap
	if Input.is_key_pressed(KEY_UP):
		_do_action(1, CKEnums.Direction.UP)
		return
	if Input.is_key_pressed(KEY_DOWN):
		_do_action(1, CKEnums.Direction.DOWN)
		return
	if Input.is_key_pressed(KEY_LEFT):
		_do_action(1, CKEnums.Direction.LEFT)
		return
	if Input.is_key_pressed(KEY_RIGHT):
		_do_action(1, CKEnums.Direction.RIGHT)
		return
	if Input.is_key_pressed(KEY_ENTER):
		_do_action(1, -1)
		return


func _do_action(player: int, direction: int) -> void:
	var events = _match_flow.submit_action(player, direction)
	if events.is_empty():
		return
	_renderer.play_events(events)


func _on_animation_complete() -> void:
	_match_flow.on_animation_complete()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _match_flow.state == MatchFlow.State.COMPLETE:
			_start_match()
