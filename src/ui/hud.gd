## HUD / Score Panel for Crystal Kingdoms.
## Displays scores, timer, player info, and match-end summary.
class_name GameHud
extends CanvasLayer

const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.5, 1.0), Color(1.0, 0.3, 0.2),
	Color(0.2, 0.8, 0.3), Color(1.0, 0.6, 0.1),
	Color(0.9, 0.9, 0.2), Color(0.6, 0.3, 0.8),
	Color(0.2, 0.8, 0.8), Color(0.9, 0.3, 0.7),
]
const PLAYER_NAMES: Array[String] = [
	"Blue", "Red", "Green", "Orange", "Yellow", "Purple", "Cyan", "Magenta"
]

var _match_flow: MatchFlow
var _timer_label: Label
var _score_labels: Array[Label] = []
var _info_label: Label
var _end_panel: Control


func setup(match_flow: MatchFlow) -> void:
	_match_flow = match_flow
	_build_ui()
	_match_flow.scores_updated.connect(_update_scores)
	_match_flow.match_ended.connect(_show_end_screen)


func _build_ui() -> void:
	# Timer (right-aligned)
	_timer_label = Label.new()
	_timer_label.position = Vector2(get_viewport().get_visible_rect().size.x - 180, 10)
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_timer_label)

	# Score labels with color swatches for each player
	for i in range(_match_flow.config.player_count):
		var color: Color = PLAYER_COLORS[i] if i < PLAYER_COLORS.size() else Color.WHITE
		# Color swatch
		var swatch := ColorRect.new()
		swatch.size = Vector2(14, 14)
		swatch.position = Vector2(20, 17 + i * 28)
		swatch.color = color
		add_child(swatch)
		# Score text
		var lbl := Label.new()
		lbl.position = Vector2(40, 10 + i * 28)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", color)
		add_child(lbl)
		_score_labels.append(lbl)

	# Info label
	_info_label = Label.new()
	_info_label.position = Vector2(300, get_viewport().get_visible_rect().size.y - 30)
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_info_label.text = "P1: WASD/Space | P2: Arrows/Enter | Escape: pause"
	add_child(_info_label)


func _process(_delta: float) -> void:
	if _match_flow == null:
		return
	_update_timer()
	_update_scores()


func _update_timer() -> void:
	var remaining := _match_flow.get_remaining_time()
	if _match_flow.config.time_limit > 0:
		var mins := int(remaining) / 60
		var secs := int(remaining) % 60
		_timer_label.text = "%d:%02d" % [mins, secs]
	else:
		var mins := int(remaining) / 60
		var secs := int(remaining) % 60
		_timer_label.text = "Elapsed: %d:%02d" % [mins, secs]


func _update_scores() -> void:
	for i in range(_score_labels.size()):
		var name: String = PLAYER_NAMES[i] if i < PLAYER_NAMES.size() else "P%d" % i
		var castles: int = _match_flow.castles_owned[i]
		_score_labels[i].text = "%s: %d pts | %d castles" % [
			name, _match_flow.scores[i], castles]


func _show_end_screen(summary: Dictionary) -> void:
	_end_panel = Control.new()
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_panel)

	# Dim background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	_end_panel.add_child(bg)

	# Winner text
	var winner_id: int = summary["winner"]
	var winner_text: String
	if winner_id >= 0:
		var name: String = PLAYER_NAMES[winner_id] if winner_id < PLAYER_NAMES.size() else "P%d" % winner_id
		winner_text = "%s wins!" % name
	else:
		winner_text = "Draw!"

	var title := Label.new()
	title.text = "MATCH OVER\n%s" % winner_text
	title.position = Vector2(450, 200)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_panel.add_child(title)

	# Rankings
	var rankings: Array = summary["rankings"]
	var y := 300.0
	for i in range(rankings.size()):
		var r: Dictionary = rankings[i]
		var pid: int = r["player_id"]
		var name: String = PLAYER_NAMES[pid] if pid < PLAYER_NAMES.size() else "P%d" % pid
		var rank_label := Label.new()
		rank_label.text = "%d. %s — %d pts | %d castles | %d captures | chain %d" % [
			i + 1, name, r["score"], r["castles"], r["total_captures"], r["longest_chain"]]
		rank_label.position = Vector2(400, y)
		rank_label.add_theme_font_size_override("font_size", 20)
		var color: Color = PLAYER_COLORS[pid] if pid < PLAYER_COLORS.size() else Color.WHITE
		rank_label.add_theme_color_override("font_color", color)
		_end_panel.add_child(rank_label)
		y += 30

	# Duration + reason
	var dur_label := Label.new()
	dur_label.text = "Duration: %ds | Ended by: %s" % [
		int(summary["duration"]), summary["end_reason"]]
	dur_label.position = Vector2(450, y + 20)
	dur_label.add_theme_font_size_override("font_size", 16)
	dur_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_end_panel.add_child(dur_label)

	# Restart/exit hints
	var hint := Label.new()
	hint.text = "R = Rematch  |  Escape = Main Menu"
	hint.position = Vector2(420, y + 60)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	_end_panel.add_child(hint)
