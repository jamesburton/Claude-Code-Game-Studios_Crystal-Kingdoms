## Accessibility settings manager.
## Stores high-contrast mode and text scaling preferences.
class_name Accessibility
extends RefCounted

const SETTINGS_PATH := "user://accessibility.cfg"

static var high_contrast: bool = false
static var text_scale: float = 1.0

## High-contrast color overrides for player colors.
const HC_PLAYER_COLORS: Array[Color] = [
	Color(0.0, 0.4, 1.0),   # Bright blue
	Color(1.0, 0.0, 0.0),   # Pure red
	Color(0.0, 0.8, 0.0),   # Bright green
	Color(1.0, 0.5, 0.0),   # Orange
	Color(1.0, 1.0, 0.0),   # Yellow
	Color(0.7, 0.0, 1.0),   # Purple
	Color(0.0, 1.0, 1.0),   # Cyan
	Color(1.0, 0.0, 0.7),   # Magenta
]

const HC_EMPTY := Color(0.15, 0.15, 0.15)
const HC_BLOCKED := Color(0.05, 0.05, 0.05)
const HC_CURSOR := Color(1.0, 1.0, 0.0)
const HC_BORDER_WIDTH := 3.0


static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	high_contrast = cf.get_value("accessibility", "high_contrast", false)
	text_scale = cf.get_value("accessibility", "text_scale", 1.0)


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("accessibility", "high_contrast", high_contrast)
	cf.set_value("accessibility", "text_scale", text_scale)
	cf.save(SETTINGS_PATH)


static func toggle_high_contrast() -> void:
	high_contrast = not high_contrast
	save_settings()
