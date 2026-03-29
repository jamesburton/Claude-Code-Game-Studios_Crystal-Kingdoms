## "Fluffy Productions" studio intro splash screen.
## Auto-advances after 2.5s or on any key press.
class_name StudioIntro
extends Control

signal finished()

var _timer: float = 2.5
var _fade_in: float = 0.0
var _built: bool = false


func _ready() -> void:
	# Defer build to ensure viewport size is available (web export timing)
	call_deferred("_build_ui")


func _build_ui() -> void:
	if _built:
		return
	_built = true

	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08)
	add_child(bg)

	# Center container for content
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var sparkle := Label.new()
	sparkle.text = "✦"
	sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sparkle.add_theme_font_size_override("font_size", 28)
	sparkle.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0, 0.6))
	vbox.add_child(sparkle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	var studio := Label.new()
	studio.text = "Fluffy Productions"
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio.add_theme_font_size_override("font_size", 42)
	studio.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	vbox.add_child(studio)

	var tagline := Label.new()
	tagline.text = "~ making games with heart ~"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
	vbox.add_child(tagline)

	modulate.a = 0.0


func _process(delta: float) -> void:
	if not _built:
		return
	_fade_in += delta * 2.0
	modulate.a = minf(_fade_in, 1.0)
	_timer -= delta
	if _timer <= 0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_finish()
	elif event is InputEventJoypadButton and event.pressed:
		_finish()
	elif event is InputEventMouseButton and event.pressed:
		_finish()
	elif event is InputEventScreenTouch and event.pressed:
		_finish()


func _finish() -> void:
	set_process(false)
	finished.emit()
