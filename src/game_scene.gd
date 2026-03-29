## App controller — manages the full game flow:
## Studio Intro → Main Menu → Options/Play → Match → Results → Main Menu
extends Control

var _match_flow: MatchFlow
var _renderer: BoardRenderer
var _hud: GameHud
var _sound: SoundManager
var _music: MusicManager
var _config: GameConfig
var _player_setup: Array[Dictionary] = []
var _human_players: Array[int] = []
var _in_match: bool = false
var _tutorial_shown: bool = false
var _tutorial_panel: Control
var _pause_panel: Control
var _paused: bool = false
var _countdown_active: bool = false
var _transition_rect: ColorRect

# Keyboard binding map: key → {player, direction}
const KEY_BINDINGS: Dictionary = {
	KEY_W: {"player": 0, "dir": 0}, KEY_S: {"player": 0, "dir": 1},
	KEY_A: {"player": 0, "dir": 2}, KEY_D: {"player": 0, "dir": 3},
	KEY_SPACE: {"player": 0, "dir": -1},
	KEY_UP: {"player": 1, "dir": 0}, KEY_DOWN: {"player": 1, "dir": 1},
	KEY_LEFT: {"player": 1, "dir": 2}, KEY_RIGHT: {"player": 1, "dir": 3},
	KEY_ENTER: {"player": 1, "dir": -1},
	KEY_I: {"player": 2, "dir": 0}, KEY_K: {"player": 2, "dir": 1},
	KEY_J: {"player": 2, "dir": 2}, KEY_L: {"player": 2, "dir": 3},
	KEY_H: {"player": 2, "dir": -1},
	KEY_KP_8: {"player": 3, "dir": 0}, KEY_KP_5: {"player": 3, "dir": 1},
	KEY_KP_4: {"player": 3, "dir": 2}, KEY_KP_6: {"player": 3, "dir": 3},
	KEY_KP_0: {"player": 3, "dir": -1},
}

const STICK_DEADZONE := 0.5


func _ready() -> void:
	# Persistent music manager
	_music = MusicManager.new()
	add_child(_music)

	_show_intro()


# === FLOW MANAGEMENT ===

func _fade_to(callback: Callable) -> void:
	if _transition_rect == null:
		_transition_rect = ColorRect.new()
		_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_transition_rect.color = Color(0, 0, 0, 0)
		_transition_rect.z_index = 200
		_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_transition_rect)

	_transition_rect.color.a = 0.0
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_transition_rect, "color:a", 1.0, 0.2)
	tw.tween_callback(func() -> void:
		callback.call()
		if _transition_rect:
			_transition_rect.reparent(self)  # keep on top after scene clear
			var tw2 := create_tween()
			tw2.tween_property(_transition_rect, "color:a", 0.0, 0.2)
			tw2.tween_callback(func() -> void:
				_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE))


func _show_intro() -> void:
	_clear_scene()
	var intro := StudioIntro.new()
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(intro)
	intro.finished.connect(func() -> void: _fade_to(_show_main_menu))


func _show_main_menu() -> void:
	_clear_scene()
	_in_match = false
	_music.play_menu_music()

	var menu := MainMenu.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.play_pressed.connect(func() -> void: _fade_to(_show_play_screen))
	menu.online_pressed.connect(func() -> void: _fade_to(_show_lobby))
	menu.replays_pressed.connect(func() -> void: _fade_to(_show_replays))
	menu.editor_pressed.connect(func() -> void: _fade_to(_show_editor))
	menu.options_pressed.connect(func() -> void: _fade_to(_show_options))
	menu.quit_pressed.connect(func() -> void: get_tree().quit())


func _show_play_screen() -> void:
	_clear_scene()

	var config_screen := ConfigScreen.new()
	config_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	config_screen.size = get_viewport().get_visible_rect().size
	add_child(config_screen)
	config_screen.match_requested.connect(_on_match_requested)
	config_screen.keybindings_requested.connect(func() -> void: _fade_to(_show_keybindings))

	# Back button
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 20)
	back.custom_minimum_size = Vector2(80, 35)
	back.pressed.connect(func() -> void: _fade_to(_show_main_menu))
	add_child(back)


func _show_editor() -> void:
	_clear_scene()
	var editor := BoardEditor.new()
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(editor)
	editor.back_pressed.connect(func() -> void: _fade_to(_show_main_menu))


func _show_keybindings() -> void:
	_clear_scene()
	var kb := KeybindScreen.new()
	kb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(kb)
	kb.back_pressed.connect(func() -> void: _fade_to(_show_play_screen))


func _show_replays() -> void:
	_clear_scene()
	var replay_screen := ReplayScreen.new()
	replay_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(replay_screen)
	replay_screen.back_pressed.connect(func() -> void: _fade_to(_show_main_menu))


var _net_server: GameServer
var _net_client: GameClient
var _is_network_match: bool = false
var _my_net_slot: int = 0


func _show_lobby() -> void:
	_clear_scene()
	var lobby := LobbyScreen.new()
	lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lobby)
	lobby.back_pressed.connect(func() -> void: _fade_to(_show_main_menu))
	lobby.match_ready.connect(func(server: GameServer, config: GameConfig) -> void:
		_net_server = server
		_net_client = null
		_is_network_match = true
		_my_net_slot = 0
		_config = config
		_player_setup.clear()
		for i in range(config.player_count):
			_player_setup.append({"player_id": i, "name": "Player %d" % (i + 1),
				"is_cpu": false, "difficulty": 0})
		_fade_to(_start_network_host_match))
	lobby.client_match_starting.connect(func(client: GameClient, config_data: Dictionary) -> void:
		_net_client = client
		_net_server = null
		_is_network_match = true
		_my_net_slot = client.my_slot
		_fade_to(_start_network_client_match.bind(config_data)))


func _start_network_host_match() -> void:
	_clear_scene()
	_in_match = true
	_is_network_match = true

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.1)
	add_child(bg)

	# Server starts the match — it owns match_flow
	_net_server.start_match(_config)
	_match_flow = _net_server.match_flow
	_human_players = [0]  # Host is player 0

	# Wire server events to renderer
	_match_flow.action_events.connect(_on_action_events)
	_match_flow.match_ended.connect(func(_s: Dictionary) -> void:
		if _sound: _sound.play("match_end"))

	# Renderer
	_renderer = BoardRenderer.new()
	add_child(_renderer)
	_renderer.setup(_match_flow.board, _match_flow.config.chain_step_delay,
		get_viewport().get_visible_rect().size, _match_flow.config.capture_threshold)
	_renderer.animation_complete.connect(_on_animation_complete)

	# Sound
	_sound = SoundManager.new()
	add_child(_sound)
	_match_flow.turn_director.cursor_spawned.connect(func(_i: int) -> void:
		if _sound: _sound.play("cursor_spawn"))

	_music.play_game_music()

	# HUD
	_hud = GameHud.new()
	add_child(_hud)
	_hud.setup(_match_flow)

	_show_countdown()


func _start_network_client_match(config_data: Dictionary) -> void:
	_clear_scene()
	_in_match = true
	_is_network_match = true

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.1)
	add_child(bg)

	# Build config from server data
	_config = GameConfig.new()
	_config.grid_size = config_data.get("grid_size", 8)
	_config.capture_threshold = config_data.get("capture_threshold", 3)
	_config.time_limit = config_data.get("time_limit", 90)
	_config.player_count = config_data.get("player_count", 2)
	_config.wrap_around = config_data.get("wrap_around", true)
	_config.board_shape = config_data.get("board_shape", 0) as CKEnums.BoardShape
	_config.skip_blanks = config_data.get("skip_blanks", true)
	_config.allow_tap = config_data.get("allow_tap", true)
	_config.max_castles = config_data.get("max_castles", 0)

	# Create local board (display only — server is authoritative)
	var board := BoardState.new(_config)
	_human_players = [_my_net_slot]

	# Renderer
	_renderer = BoardRenderer.new()
	add_child(_renderer)
	_renderer.setup(board, _config.chain_step_delay,
		get_viewport().get_visible_rect().size, _config.capture_threshold)

	# Sound
	_sound = SoundManager.new()
	add_child(_sound)

	_music.play_game_music()

	# Wire client events → renderer
	_net_client.cursor_spawned.connect(func(idx: int) -> void:
		board.cursor_index = idx
		board.cursor_active = true
		if _sound: _sound.play("cursor_spawn"))

	_net_client.events_received.connect(func(events: Array) -> void:
		_apply_client_events(board, events))

	_net_client.match_ended.connect(func(summary: Dictionary) -> void:
		if _sound: _sound.play("match_end")
		_in_match = false)

	# Client HUD
	var info := Label.new()
	info.text = "Connected as Player %d | Escape = disconnect" % (_my_net_slot + 1)
	info.position = Vector2(20, 10)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(info)

	# Ping display
	var ping_label := Label.new()
	ping_label.text = "Ping: --"
	ping_label.position = Vector2(20, 35)
	ping_label.add_theme_font_size_override("font_size", 14)
	ping_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	add_child(ping_label)
	_net_client.ping_updated.connect(func(ms: float) -> void:
		var color := Color(0.5, 0.9, 0.5) if ms < 50 else Color(0.9, 0.9, 0.3) if ms < 100 else Color(0.9, 0.4, 0.3)
		ping_label.add_theme_color_override("font_color", color)
		ping_label.text = "Ping: %dms" % int(ms))

	_show_countdown()


func _show_options() -> void:
	# For now, options goes to config screen (same as play but without starting)
	_show_play_screen()


func _on_match_requested(config: GameConfig, setup: Array[Dictionary]) -> void:
	_config = config
	_player_setup = setup
	_start_match()


func _start_match() -> void:
	_clear_scene()
	_in_match = true
	_paused = false

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.1)
	add_child(bg)

	# Human players
	_human_players.clear()
	for p: Dictionary in _player_setup:
		if not p["is_cpu"]:
			_human_players.append(p["player_id"])

	# Match
	_match_flow = MatchFlow.new(_config)
	_match_flow.start()

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

	_match_flow.action_events.connect(_on_action_events)
	_match_flow.match_ended.connect(func(_s: Dictionary) -> void:
		if _sound: _sound.play("match_end"))

	# Renderer
	_renderer = BoardRenderer.new()
	add_child(_renderer)
	_renderer.setup(_match_flow.board, _match_flow.config.chain_step_delay,
		get_viewport().get_visible_rect().size, _match_flow.config.capture_threshold)
	_renderer.animation_complete.connect(_on_animation_complete)

	# Sound
	_sound = SoundManager.new()
	add_child(_sound)
	_match_flow.turn_director.cursor_spawned.connect(func(_i: int) -> void:
		if _sound: _sound.play("cursor_spawn"))

	# Music
	_music.play_game_music()

	# HUD
	_hud = GameHud.new()
	add_child(_hud)
	_hud.setup(_match_flow)

	# Tutorial on first match, otherwise countdown
	if not _tutorial_shown:
		_show_tutorial()
	else:
		_show_countdown()


# === GAME LOOP ===

func _process(delta: float) -> void:
	if _tutorial_panel or _paused or _countdown_active:
		return
	if not _in_match:
		return
	# Client network match: no local match_flow to tick, just check input
	if _is_network_match and _net_client:
		_check_input()
		return
	# Local or host match
	if _match_flow == null or _match_flow.state != MatchFlow.State.PLAYING:
		return
	_match_flow.tick(delta)
	_check_input()


func _check_input() -> void:
	# For client network matches, check if cursor is visible (no local turn director)
	if _is_network_match and _net_client:
		# Client accepts input anytime (server validates)
		pass
	elif _match_flow and _match_flow.turn_director.state != TurnDirector.State.ACTIVE:
		return

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

	_check_gamepad_input()


func _check_gamepad_input() -> void:
	var pads := Input.get_connected_joypads()
	for pad_idx: int in pads:
		if pad_idx >= _human_players.size():
			break
		var player: int = _human_players[pad_idx]

		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_UP) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_Y) < -STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.UP); return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_DOWN) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_Y) > STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.DOWN); return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_LEFT) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_X) < -STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.LEFT); return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_DPAD_RIGHT) \
				or Input.get_joy_axis(pad_idx, JOY_AXIS_LEFT_X) > STICK_DEADZONE:
			_do_action(player, CKEnums.Direction.RIGHT); return
		if Input.is_joy_button_pressed(pad_idx, JOY_BUTTON_A):
			if _match_flow.config.allow_tap:
				_do_action(player, -1); return


func _do_action(player: int, direction: int) -> void:
	if _is_network_match and _net_client:
		# Client: send to server
		_net_client.send_action(direction)
	elif _match_flow:
		# Local or host: submit directly
		_match_flow.submit_action(player, direction)


func _on_action_events(events: Array) -> void:
	if _renderer:
		_renderer.play_events(events)
		_renderer.set_bonus_cells(_match_flow.bonus_stacks)
	if _sound and not events.is_empty():
		_play_event_sfx(events[0].get("type", -1))


func _apply_client_events(board: BoardState, events: Array) -> void:
	for ev: Dictionary in events:
		var ev_type: int = ev.get("type", -1)
		var grid_idx: int = ev.get("grid_index", 0)
		var actor: int = ev.get("actor_id", 0)
		if ev_type == CKEnums.EventType.CAPTURE_EMPTY:
			board.cells_owner[grid_idx] = actor
			board.cells_contagion[grid_idx] = {}
		elif ev_type == CKEnums.EventType.INCREMENT_CONTAGION:
			var level: int = ev.get("contagion_level", 1)
			var cont: Dictionary = board.cells_contagion[grid_idx]
			cont[actor] = level
			board.cells_contagion[grid_idx] = cont
		elif ev_type == CKEnums.EventType.CAPTURE_CONTAGION:
			board.cells_owner[grid_idx] = actor
			board.cells_contagion[grid_idx] = {}
		elif ev_type == CKEnums.EventType.DESTROY_OWN_CASTLE:
			board.cells_owner[grid_idx] = -1
	board.cursor_active = false
	if _renderer:
		_renderer.play_events(events)
	if _sound and events.size() > 0:
		_play_event_sfx(events[0].get("type", -1))


func _play_event_sfx(ev_type: int) -> void:
	if not _sound:
		return
	if ev_type == CKEnums.EventType.CAPTURE_EMPTY:
		_sound.play("capture_empty")
	elif ev_type == CKEnums.EventType.INCREMENT_CONTAGION:
		_sound.play("contagion")
	elif ev_type == CKEnums.EventType.CAPTURE_CONTAGION:
		_sound.play("capture_contagion")
	elif ev_type == CKEnums.EventType.DESTROY_OWN_CASTLE:
		_sound.play("destroy")


func _on_animation_complete() -> void:
	if _match_flow:
		_match_flow.on_animation_complete()


# === OVERLAYS ===

func _show_tutorial() -> void:
	_tutorial_panel = Control.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_panel.z_index = 100
	add_child(_tutorial_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	_tutorial_panel.add_child(bg)

	var vp := get_viewport().get_visible_rect().size
	var text := Label.new()
	text.text = "HOW TO PLAY\n\n" \
		+ "A yellow cursor appears on the board\n" \
		+ "Press a DIRECTION key to sweep in that direction\n" \
		+ "Chains travel through enemy territory\n" \
		+ "Build contagion to capture enemy castles\n" \
		+ "First to act claims the cursor!\n\n" \
		+ "Press any key to start..."
	text.position = Vector2(vp.x / 2 - 200, vp.y / 2 - 100)
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	_tutorial_panel.add_child(text)


func _show_countdown() -> void:
	_countdown_active = true
	var vp := get_viewport().get_visible_rect().size
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.3))
	lbl.position = Vector2(vp.x / 2 - 50, vp.y / 2 - 50)
	lbl.size = Vector2(100, 100)
	lbl.z_index = 100
	add_child(lbl)

	var tw := create_tween()
	lbl.text = "3"
	tw.tween_callback(func() -> void: if _sound: _sound.play("countdown"))
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		lbl.text = "2"
		if _sound: _sound.play("countdown"))
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		lbl.text = "1"
		if _sound: _sound.play("countdown"))
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		lbl.text = "GO!"
		lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		if _sound: _sound.play("countdown_go"))
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		lbl.queue_free()
		_countdown_active = false)


func _pause() -> void:
	_paused = true
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.z_index = 100
	add_child(_pause_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	_pause_panel.add_child(bg)

	var vp := get_viewport().get_visible_rect().size
	var menu := VBoxContainer.new()
	menu.position = Vector2(vp.x / 2 - 120, vp.y / 2 - 80)
	_pause_panel.add_child(menu)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	menu.add_child(spacer)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(240, 40)
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.pressed.connect(_unpause)
	menu.add_child(resume_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 8
	menu.add_child(spacer2)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(240, 40)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func() -> void:
		_unpause()
		_fade_to(_show_main_menu))
	menu.add_child(menu_btn)


func _unpause() -> void:
	_paused = false
	if _pause_panel:
		_pause_panel.queue_free()
		_pause_panel = null


# === CLEANUP ===

func _clear_scene() -> void:
	if _match_flow:
		if _match_flow.action_events.is_connected(_on_action_events):
			_match_flow.action_events.disconnect(_on_action_events)
	if _renderer:
		if _renderer.animation_complete.is_connected(_on_animation_complete):
			_renderer.animation_complete.disconnect(_on_animation_complete)
	# Keep persistent nodes
	for child in get_children():
		if child == _music or child == _transition_rect:
			continue
		child.queue_free()
	_match_flow = null
	_renderer = null
	_hud = null
	_sound = null
	_tutorial_panel = null
	_pause_panel = null
	_paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	if _tutorial_panel:
		_tutorial_panel.queue_free()
		_tutorial_panel = null
		_tutorial_shown = true
		return

	match event.keycode:
		KEY_R:
			if _in_match and _match_flow and _match_flow.state == MatchFlow.State.COMPLETE:
				_fade_to(_start_match)
		KEY_ESCAPE:
			if _paused:
				_unpause()
			elif _in_match and _match_flow and _match_flow.state == MatchFlow.State.COMPLETE:
				_fade_to(_show_main_menu)
			elif _in_match and _match_flow and _match_flow.state == MatchFlow.State.PLAYING:
				_pause()
		KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
