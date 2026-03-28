## "Fluffy Productions" studio intro splash screen.
## Auto-advances after 2.5s or on any key press.
class_name StudioIntro
extends Control

signal finished()

var _timer: float = 2.5
var _fade_in: float = 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08)
	add_child(bg)

	var vp := get_viewport().get_visible_rect().size
	var center := vp / 2.0

	# Studio name
	var studio := Label.new()
	studio.text = "Fluffy Productions"
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio.add_theme_font_size_override("font_size", 42)
	studio.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	studio.position = Vector2(center.x - 250, center.y - 40)
	studio.size = Vector2(500, 50)
	add_child(studio)

	# Tagline
	var tagline := Label.new()
	tagline.text = "~ making games with heart ~"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
	tagline.position = Vector2(center.x - 200, center.y + 20)
	tagline.size = Vector2(400, 30)
	add_child(tagline)

	# Sparkle decoration
	var sparkle := Label.new()
	sparkle.text = "✦"
	sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sparkle.add_theme_font_size_override("font_size", 28)
	sparkle.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0, 0.6))
	sparkle.position = Vector2(center.x - 15, center.y - 80)
	add_child(sparkle)

	modulate.a = 0.0


func _process(delta: float) -> void:
	# Fade in
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


func _finish() -> void:
	set_process(false)
	finished.emit()
