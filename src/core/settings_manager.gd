## Persists game configuration to user://settings.cfg.
## Saves on match start, loads on application launch.
class_name SettingsManager
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "game"

## Save a GameConfig to disk.
static func save_config(config: GameConfig) -> void:
	var cf := ConfigFile.new()
	cf.set_value(SECTION, "grid_size", config.grid_size)
	cf.set_value(SECTION, "capture_threshold", config.capture_threshold)
	cf.set_value(SECTION, "time_limit", config.time_limit)
	cf.set_value(SECTION, "player_count", config.player_count)
	cf.set_value(SECTION, "wrap_around", config.wrap_around)
	cf.set_value(SECTION, "allow_tap", config.allow_tap)
	cf.set_value(SECTION, "max_castles", config.max_castles)
	cf.set_value(SECTION, "winning_score", config.winning_score)
	cf.set_value(SECTION, "scoring_mode", config.scoring_mode)
	cf.set_value(SECTION, "lone_castle_scores_zero", config.lone_castle_scores_zero)
	cf.set_value(SECTION, "cursor_select_captured", config.cursor_select_captured)
	cf.set_value(SECTION, "cursor_spawn_delay_min", config.cursor_spawn_delay_min)
	cf.set_value(SECTION, "cursor_spawn_delay_max", config.cursor_spawn_delay_max)
	cf.set_value(SECTION, "cursor_expire_time", config.cursor_expire_time)
	cf.set_value(SECTION, "chain_step_delay", config.chain_step_delay)
	cf.save(SETTINGS_PATH)


## Load a GameConfig from disk. Returns null if no saved settings.
static func load_config() -> GameConfig:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return null
	var config := GameConfig.new()
	config.grid_size = cf.get_value(SECTION, "grid_size", config.grid_size)
	config.capture_threshold = cf.get_value(SECTION, "capture_threshold", config.capture_threshold)
	config.time_limit = cf.get_value(SECTION, "time_limit", config.time_limit)
	config.player_count = cf.get_value(SECTION, "player_count", config.player_count)
	config.wrap_around = cf.get_value(SECTION, "wrap_around", config.wrap_around)
	config.allow_tap = cf.get_value(SECTION, "allow_tap", config.allow_tap)
	config.max_castles = cf.get_value(SECTION, "max_castles", config.max_castles)
	config.winning_score = cf.get_value(SECTION, "winning_score", config.winning_score)
	config.scoring_mode = cf.get_value(SECTION, "scoring_mode", config.scoring_mode)
	config.lone_castle_scores_zero = cf.get_value(SECTION, "lone_castle_scores_zero", config.lone_castle_scores_zero)
	config.cursor_select_captured = cf.get_value(SECTION, "cursor_select_captured", config.cursor_select_captured)
	config.cursor_spawn_delay_min = cf.get_value(SECTION, "cursor_spawn_delay_min", config.cursor_spawn_delay_min)
	config.cursor_spawn_delay_max = cf.get_value(SECTION, "cursor_spawn_delay_max", config.cursor_spawn_delay_max)
	config.cursor_expire_time = cf.get_value(SECTION, "cursor_expire_time", config.cursor_expire_time)
	config.chain_step_delay = cf.get_value(SECTION, "chain_step_delay", config.chain_step_delay)
	# Validate ranges
	config.grid_size = clampi(config.grid_size, 6, 12)
	config.capture_threshold = clampi(config.capture_threshold, 1, 10)
	config.time_limit = clampi(config.time_limit, 30, 600)
	config.player_count = clampi(config.player_count, 2, 8)
	return config


## Check if saved settings exist.
static func has_saved_settings() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)
