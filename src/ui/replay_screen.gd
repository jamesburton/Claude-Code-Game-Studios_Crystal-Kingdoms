## Replay list and playback viewer.
## Lists saved replays, loads selected, steps through turns on a reconstructed board.
class_name ReplayScreen
extends Control

signal back_pressed()

var _list_panel: Control
var _viewer_panel: Control
var _replay_list: VBoxContainer
var _board: BoardState
var _renderer: BoardRenderer
var _config: GameConfig
var _turns: Array = []
var _turn_index: int = 0
var _playing: bool = false
var _speed: float = 1.0
var _step_timer: float = 0.0
var _status_label: Label
var _speed_label: Label
var _rules: RulesEngine


func _ready() -> void:
	_build_list_ui()


func _build_list_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	_list_panel = Control.new()
	_list_panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_list_panel)

	var vp := get_viewport().get_visible_rect().size

	var title := Label.new()
	title.text = "Replays"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(vp.x / 2 - 100, 30)
	title.size = Vector2(200, 40)
	_list_panel.add_child(title)

	# Scroll container for replay list
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(vp.x / 2 - 250, 90)
	scroll.size = Vector2(500, vp.y - 160)
	_list_panel.add_child(scroll)

	_replay_list = VBoxContainer.new()
	_replay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_replay_list)

	_load_replay_list()

	# Back button
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 20)
	back.custom_minimum_size = Vector2(80, 35)
	back.pressed.connect(func() -> void: back_pressed.emit())
	_list_panel.add_child(back)

	# No replays message
	if _replay_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No replays saved yet.\nPlay a match to record one!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_replay_list.add_child(empty)


func _load_replay_list() -> void:
	var replays := ReplayManager.list_replays()
	for r: Dictionary in replays:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 40

		var info := Label.new()
		var scores: Array = r.get("scores", [])
		var score_text := ""
		for i in range(scores.size()):
			if i > 0: score_text += " vs "
			score_text += str(scores[i])
		info.text = "%s  |  %dx%d  |  %dp  |  %s  |  %ds" % [
			r.get("timestamp", "?"),
			r.get("grid_size", 0), r.get("grid_size", 0),
			r.get("player_count", 0),
			score_text,
			int(r.get("duration", 0))]
		info.add_theme_font_size_override("font_size", 14)
		info.add_theme_color_override("font_color", Color.WHITE)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var play_btn := Button.new()
		play_btn.text = "View"
		play_btn.custom_minimum_size = Vector2(60, 30)
		var fname: String = r.get("filename", "")
		play_btn.pressed.connect(_open_replay.bind(fname))
		row.add_child(play_btn)

		_replay_list.add_child(row)


func _open_replay(filename: String) -> void:
	var data := ReplayManager.load_replay(filename)
	if data.is_empty():
		return

	_turns = data.get("turns", [])
	_turn_index = 0
	_playing = false

	# Reconstruct config
	_config = GameConfig.new()
	_config.grid_size = data.get("grid_size", 8)
	_config.capture_threshold = data.get("capture_threshold", 3)
	_config.player_count = data.get("player_count", 2)
	_config.wrap_around = data.get("wrap_around", true)
	_config.board_shape = data.get("board_shape", 0) as CKEnums.BoardShape

	# Create fresh board
	_board = BoardState.new(_config)
	_rules = RulesEngine.new(_config, _board)

	_list_panel.visible = false
	_build_viewer_ui()


func _build_viewer_ui() -> void:
	if _viewer_panel:
		_viewer_panel.queue_free()

	_viewer_panel = Control.new()
	_viewer_panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_viewer_panel)

	var vp := get_viewport().get_visible_rect().size

	# Board renderer
	_renderer = BoardRenderer.new()
	_viewer_panel.add_child(_renderer)
	_renderer.setup(_board, 0.0, vp, _config.capture_threshold)

	# Controls bar at bottom
	var controls := HBoxContainer.new()
	controls.position = Vector2(vp.x / 2 - 250, vp.y - 60)
	_viewer_panel.add_child(controls)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(70, 35)
	back_btn.pressed.connect(_close_viewer)
	controls.add_child(back_btn)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.x = 20
	controls.add_child(spacer1)

	var step_btn := Button.new()
	step_btn.text = "Step >"
	step_btn.custom_minimum_size = Vector2(80, 35)
	step_btn.pressed.connect(_step_forward)
	controls.add_child(step_btn)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(70, 35)
	play_btn.pressed.connect(func() -> void: _playing = not _playing)
	controls.add_child(play_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.x = 20
	controls.add_child(spacer2)

	# Speed buttons
	for spd in [0.5, 1.0, 2.0, 4.0]:
		var s_btn := Button.new()
		s_btn.text = "%sx" % str(spd)
		s_btn.custom_minimum_size = Vector2(50, 35)
		s_btn.pressed.connect(func() -> void:
			_speed = spd
			_speed_label.text = "%sx" % str(spd))
		controls.add_child(s_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.x = 20
	controls.add_child(spacer3)

	_speed_label = Label.new()
	_speed_label.text = "1.0x"
	_speed_label.add_theme_font_size_override("font_size", 16)
	controls.add_child(_speed_label)

	# Status
	_status_label = Label.new()
	_status_label.position = Vector2(vp.x / 2 - 150, 15)
	_status_label.size = Vector2(300, 30)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_viewer_panel.add_child(_status_label)
	_update_status()


func _process(delta: float) -> void:
	if not _playing or _viewer_panel == null:
		return

	_step_timer -= delta * _speed
	if _step_timer <= 0:
		_step_forward()
		_step_timer = 0.5  # Base interval between steps


func _step_forward() -> void:
	if _turn_index >= _turns.size():
		_playing = false
		_update_status()
		return

	var turn: Dictionary = _turns[_turn_index]
	var cursor: int = turn.get("cursor", 0)
	var player: int = turn.get("player", 0)
	var dir: int = turn.get("dir", -1)

	# Apply action through rules engine
	var events := _rules.resolve_action(player, cursor, dir)

	# Animate on renderer
	if _renderer:
		_renderer.play_events(events)

	_turn_index += 1
	_update_status()


func _update_status() -> void:
	if _status_label:
		if _turn_index >= _turns.size():
			_status_label.text = "Replay complete (%d turns)" % _turns.size()
		else:
			_status_label.text = "Turn %d / %d" % [_turn_index, _turns.size()]


func _close_viewer() -> void:
	if _viewer_panel:
		_viewer_panel.queue_free()
		_viewer_panel = null
	_renderer = null
	_board = null
	_rules = null
	_list_panel.visible = true
