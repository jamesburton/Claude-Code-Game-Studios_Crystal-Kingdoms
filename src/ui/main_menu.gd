## Main menu screen with Play, Options, Quit.
## Starts attract mode after idle timeout.
class_name MainMenu
extends Control

signal play_pressed()
signal online_pressed()
signal replays_pressed()
signal editor_pressed()
signal options_pressed()
signal quit_pressed()

const ATTRACT_TIMEOUT := 30.0
var _idle_timer: float = ATTRACT_TIMEOUT
var _attract_active: bool = false
var _attract_match: MatchFlow
var _attract_renderer: BoardRenderer
var _attract_overlay: Control
var _menu_container: Control
var _bg: ColorRect
var _title_pulse: float = 0.0
var _title_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.color = Color(0.06, 0.06, 0.1)
	add_child(_bg)

	# Animated background particles
	_add_bg_particles()

	var vp := get_viewport().get_visible_rect().size

	_menu_container = Control.new()
	_menu_container.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_menu_container)

	# Title
	_title_label = Label.new()
	_title_label.text = "Crystal Kingdoms"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	_title_label.position = Vector2(vp.x / 2 - 300, 100)
	_title_label.size = Vector2(600, 60)
	_menu_container.add_child(_title_label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "A strategic contagion battle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.position = Vector2(vp.x / 2 - 200, 165)
	subtitle.size = Vector2(400, 30)
	_menu_container.add_child(subtitle)

	# Buttons
	var btn_container := VBoxContainer.new()
	btn_container.position = Vector2(vp.x / 2 - 140, vp.y / 2 - 40)
	_menu_container.add_child(btn_container)

	var play_btn := _make_button("Play", 24)
	play_btn.pressed.connect(func() -> void: play_pressed.emit())
	btn_container.add_child(play_btn)

	_add_btn_spacer(btn_container)

	var online_btn := _make_button("Online (LAN)", 24)
	online_btn.pressed.connect(func() -> void: online_pressed.emit())
	btn_container.add_child(online_btn)

	_add_btn_spacer(btn_container)

	var replays_btn := _make_button("Replays", 24)
	replays_btn.pressed.connect(func() -> void: replays_pressed.emit())
	btn_container.add_child(replays_btn)

	_add_btn_spacer(btn_container)

	var editor_btn := _make_button("Board Editor", 24)
	editor_btn.pressed.connect(func() -> void: editor_pressed.emit())
	btn_container.add_child(editor_btn)

	_add_btn_spacer(btn_container)

	var options_btn := _make_button("Options", 24)
	options_btn.pressed.connect(func() -> void: options_pressed.emit())
	btn_container.add_child(options_btn)

	_add_btn_spacer(btn_container)

	var quit_btn := _make_button("Quit", 24)
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	btn_container.add_child(quit_btn)

	# Version
	var version := Label.new()
	version.text = "v1.5.0 — Fluffy Productions"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	version.position = Vector2(20, vp.y - 30)
	_menu_container.add_child(version)


func _process(delta: float) -> void:
	# Title glow
	_title_pulse += delta * 2.0
	if _title_label:
		var glow := 0.8 + 0.2 * sin(_title_pulse)
		_title_label.add_theme_color_override("font_color",
			Color(0.9 * glow, 0.85 * glow, 0.3))

	# Attract mode timer
	if not _attract_active:
		_idle_timer -= delta
		if _idle_timer <= 0:
			_start_attract()

	# Tick attract match
	if _attract_active and _attract_match:
		_attract_match.tick(delta)
		_attract_match.on_animation_complete()
		if _attract_match.state == MatchFlow.State.COMPLETE:
			_restart_attract()


func _unhandled_input(event: InputEvent) -> void:
	_idle_timer = ATTRACT_TIMEOUT
	if _attract_active:
		if (event is InputEventKey and event.pressed) or \
				(event is InputEventJoypadButton and event.pressed):
			_stop_attract()


func _start_attract() -> void:
	_attract_active = true
	_menu_container.visible = false

	# Set up a demo match
	var config := GameConfig.new()
	config.grid_size = 8
	config.player_count = 4
	config.time_limit = 60
	config.capture_threshold = 3
	config.board_shape = [
		CKEnums.BoardShape.RECTANGLE,
		CKEnums.BoardShape.DIAMOND,
		CKEnums.BoardShape.CROSS,
	].pick_random()
	config.apply_speed_preset(CKEnums.SpeedPreset.FAST)

	_attract_match = MatchFlow.new(config)
	_attract_match.start()

	var easy := load("res://src/data/cpu_difficulty_easy.tres") as CpuDifficulty
	var med := load("res://src/data/cpu_difficulty_medium.tres") as CpuDifficulty
	for i in range(config.player_count):
		_attract_match.add_cpu(i, easy if i % 2 == 0 else med)

	_attract_renderer = BoardRenderer.new()
	add_child(_attract_renderer)
	_attract_renderer.setup(_attract_match.board,
		_attract_match.config.chain_step_delay,
		get_viewport().get_visible_rect().size,
		config.capture_threshold)
	_attract_match.action_events.connect(func(events: Array) -> void:
		if _attract_renderer:
			_attract_renderer.play_events(events))

	# Overlay
	_attract_overlay = Control.new()
	_attract_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_attract_overlay.z_index = 50
	add_child(_attract_overlay)

	var overlay_label := Label.new()
	overlay_label.text = "Press any key to return to menu"
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.add_theme_font_size_override("font_size", 20)
	overlay_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2, 0.7))
	var vp := get_viewport().get_visible_rect().size
	overlay_label.position = Vector2(vp.x / 2 - 200, vp.y - 40)
	overlay_label.size = Vector2(400, 30)
	_attract_overlay.add_child(overlay_label)


func _restart_attract() -> void:
	_stop_attract_visuals()
	_idle_timer = 0.0  # Immediately start new attract


func _stop_attract() -> void:
	_stop_attract_visuals()
	_idle_timer = ATTRACT_TIMEOUT
	_menu_container.visible = true


func _stop_attract_visuals() -> void:
	_attract_active = false
	if _attract_renderer:
		_attract_renderer.queue_free()
		_attract_renderer = null
	if _attract_overlay:
		_attract_overlay.queue_free()
		_attract_overlay = null
	_attract_match = null


func _add_bg_particles() -> void:
	# Simple floating dots as background decoration
	for i in range(20):
		var dot := ColorRect.new()
		var s := randf_range(2, 5)
		dot.size = Vector2(s, s)
		dot.color = Color(0.3, 0.3, 0.5, randf_range(0.1, 0.3))
		var vp := get_viewport().get_visible_rect().size
		dot.position = Vector2(randf() * vp.x, randf() * vp.y)
		add_child(dot)
		var tw := create_tween().set_loops()
		tw.tween_property(dot, "position:y", dot.position.y - randf_range(50, 150), randf_range(4, 8))
		tw.tween_property(dot, "position:y", dot.position.y, randf_range(4, 8))


func _make_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.mouse_entered.connect(func() -> void: _play_ui_sound("ui_hover"))
	btn.pressed.connect(func() -> void: _play_ui_sound("ui_click"))
	return btn

static var _ui_sound_player: AudioStreamPlayer

func _play_ui_sound(sfx_name: String) -> void:
	# Lightweight UI sound — shared player
	if _ui_sound_player == null:
		_ui_sound_player = AudioStreamPlayer.new()
		add_child(_ui_sound_player)
	var freq := 600.0 if sfx_name == "ui_hover" else 800.0
	var dur := 0.03 if sfx_name == "ui_hover" else 0.05
	var vol := 0.15 if sfx_name == "ui_hover" else 0.25
	var samples := int(22050 * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050
		var env := 1.0 - float(i) / samples
		var s := sin(TAU * freq * t) * vol * env
		var s16 := clampi(int(s * 32767), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	_ui_sound_player.stream = stream
	_ui_sound_player.play()


func _add_btn_spacer(container: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	container.add_child(spacer)
