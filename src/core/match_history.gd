## Persists match statistics across sessions.
class_name MatchHistory
extends RefCounted

const HISTORY_PATH := "user://stats.json"


static func record_match(summary: Dictionary, config: GameConfig) -> void:
	var history := _load()
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"grid_size": config.grid_size,
		"player_count": config.player_count,
		"duration": summary.get("duration", 0),
		"winner": summary.get("winner", -1),
		"end_reason": summary.get("end_reason", ""),
		"scores": [],
	}
	var rankings: Array = summary.get("rankings", [])
	for r: Dictionary in rankings:
		entry["scores"].append(r.get("score", 0))
	history["matches"].append(entry)
	history["total_matches"] = history.get("total_matches", 0) + 1
	_save(history)


static func get_stats() -> Dictionary:
	var history := _load()
	var matches: Array = history.get("matches", [])
	var total: int = matches.size()
	if total == 0:
		return {"total": 0, "wins": 0, "losses": 0, "draws": 0,
			"avg_score": 0, "best_score": 0, "avg_duration": 0}

	var wins := 0
	var draws := 0
	var total_score := 0
	var best_score := 0
	var total_duration := 0.0

	for m: Dictionary in matches:
		var winner: int = m.get("winner", -1)
		var scores: Array = m.get("scores", [])
		if winner == 0:
			wins += 1
		elif winner < 0:
			draws += 1
		if scores.size() > 0:
			var s: int = scores[0]  # Player 0's score
			total_score += s
			best_score = maxi(best_score, s)
		total_duration += m.get("duration", 0)

	return {
		"total": total,
		"wins": wins,
		"losses": total - wins - draws,
		"draws": draws,
		"avg_score": total_score / total,
		"best_score": best_score,
		"avg_duration": int(total_duration / total),
	}


static func _load() -> Dictionary:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file == null:
		return {"matches": [], "total_matches": 0}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"matches": [], "total_matches": 0}
	if json.data is Dictionary:
		return json.data
	return {"matches": [], "total_matches": 0}


static func _save(data: Dictionary) -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
