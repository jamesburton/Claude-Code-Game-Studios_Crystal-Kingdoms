## Records and replays Crystal Kingdoms matches.
## Saves match actions + config as JSON for step-through playback.
class_name ReplayManager
extends RefCounted

const REPLAY_DIR := "user://replays/"


## Save a completed match replay.
static func save_replay(config: GameConfig, turn_history: Array, scores: Array[int],
		duration: float) -> String:
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "replay_%s.json" % timestamp

	var data := {
		"version": 1,
		"timestamp": timestamp,
		"duration": duration,
		"grid_size": config.grid_size,
		"capture_threshold": config.capture_threshold,
		"player_count": config.player_count,
		"wrap_around": config.wrap_around,
		"board_shape": config.board_shape,
		"scores": scores,
		"turns": turn_history,
	}

	var json := JSON.stringify(data, "  ")
	var path := REPLAY_DIR + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	return filename


## List available replays, newest first.
static func list_replays() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(REPLAY_DIR)
	if dir == null:
		return results

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var data := _load_replay_meta(REPLAY_DIR + fname)
			if not data.is_empty():
				data["filename"] = fname
				results.append(data)
		fname = dir.get_next()

	# Sort newest first
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("timestamp", "") > b.get("timestamp", ""))
	return results


## Load a full replay file.
static func load_replay(filename: String) -> Dictionary:
	var path := REPLAY_DIR + filename
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data as Dictionary


static func _load_replay_meta(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"timestamp": data.get("timestamp", ""),
		"grid_size": data.get("grid_size", 0),
		"player_count": data.get("player_count", 0),
		"scores": data.get("scores", []),
		"duration": data.get("duration", 0),
	}
