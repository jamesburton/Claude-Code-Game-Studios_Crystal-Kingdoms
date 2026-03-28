## Manages named game configuration presets — built-in and user-saved.
class_name PresetManager
extends RefCounted

const USER_PRESETS_PATH := "user://presets.json"


## Built-in preset definitions.
static func get_builtin_presets() -> Array[Dictionary]:
	return [
		{
			"name": "Classic",
			"description": "Standard 8x8, balanced settings",
			"grid_size": 8, "capture_threshold": 3, "time_limit": 90,
			"player_count": 2, "speed": 1, "max_castles": 0,
			"allow_tap": true, "board_shape": 0,
		},
		{
			"name": "Quick Match",
			"description": "Small grid, fast pace, 60s",
			"grid_size": 6, "capture_threshold": 2, "time_limit": 60,
			"player_count": 2, "speed": 2, "max_castles": 0,
			"allow_tap": true, "board_shape": 0,
		},
		{
			"name": "Strategic",
			"description": "Large grid, no tap, castle limits",
			"grid_size": 10, "capture_threshold": 4, "time_limit": 120,
			"player_count": 2, "speed": 1, "max_castles": 15,
			"allow_tap": false, "board_shape": 0,
		},
		{
			"name": "Party",
			"description": "8 players, frantic, diamond board",
			"grid_size": 10, "capture_threshold": 2, "time_limit": 90,
			"player_count": 8, "speed": 3, "max_castles": 0,
			"allow_tap": true, "board_shape": 1,
		},
		{
			"name": "Diamond War",
			"description": "Diamond board, bonus cells, strategic",
			"grid_size": 10, "capture_threshold": 3, "time_limit": 120,
			"player_count": 4, "speed": 1, "max_castles": 10,
			"allow_tap": false, "board_shape": 1,
			"bonus_cell_count": 4, "danger_cell_count": 4,
		},
	]


## Apply a preset dictionary to a GameConfig.
static func apply_preset(config: GameConfig, preset: Dictionary) -> void:
	config.grid_size = preset.get("grid_size", 8)
	config.capture_threshold = preset.get("capture_threshold", 3)
	config.time_limit = preset.get("time_limit", 90)
	config.player_count = preset.get("player_count", 2)
	config.max_castles = preset.get("max_castles", 0)
	config.allow_tap = preset.get("allow_tap", true)
	config.board_shape = preset.get("board_shape", 0) as CKEnums.BoardShape
	config.danger_cell_count = preset.get("danger_cell_count", 0)
	config.bonus_cell_count = preset.get("bonus_cell_count", 0)
	var speed: int = preset.get("speed", 1)
	config.apply_speed_preset(speed as CKEnums.SpeedPreset)


## Save a user preset.
static func save_user_preset(name: String, preset: Dictionary) -> void:
	var presets := load_user_presets()
	# Remove existing with same name
	presets = presets.filter(func(p: Dictionary) -> bool: return p.get("name", "") != name)
	preset["name"] = name
	presets.append(preset)
	_save_presets(presets)


## Load all user presets.
static func load_user_presets() -> Array:
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	if json.data is Array:
		return json.data
	return []


## Delete a user preset by name.
static func delete_user_preset(name: String) -> void:
	var presets := load_user_presets()
	presets = presets.filter(func(p: Dictionary) -> bool: return p.get("name", "") != name)
	_save_presets(presets)


## Extract current config as a preset dictionary.
static func config_to_preset(config: GameConfig, name: String) -> Dictionary:
	return {
		"name": name,
		"grid_size": config.grid_size,
		"capture_threshold": config.capture_threshold,
		"time_limit": config.time_limit,
		"player_count": config.player_count,
		"speed": 1,
		"max_castles": config.max_castles,
		"allow_tap": config.allow_tap,
		"board_shape": config.board_shape,
		"danger_cell_count": config.danger_cell_count,
		"bonus_cell_count": config.bonus_cell_count,
	}


static func _save_presets(presets: Array) -> void:
	var json := JSON.stringify(presets, "  ")
	var file := FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
