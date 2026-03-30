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
var _score_cards: Array[Control] = []  # Card containers (bg + bar + label)
var _info_label: Label
var _end_panel: Control


func setup(match_flow: MatchFlow) -> void:
	_match_flow = match_flow
	_build_ui()
	_match_flow.scores_updated.connect(_update_scores)
	_match_flow.match_ended.connect(_show_end_screen)


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10:
		vp = Vector2(1600, 900)

	# Timer — centered at top
	var timer_bg := ColorRect.new()
	timer_bg.size = Vector2(120, 34)
	timer_bg.color = Color(0.1, 0.1, 0.15, 0.85)
	timer_bg.position = Vector2(vp.x / 2 - 60, 6)
	add_child(timer_bg)

	_timer_label = Label.new()
	_timer_label.position = Vector2(vp.x / 2 - 55, 10)
	_timer_label.size = Vector2(110, 30)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	add_child(_timer_label)

	# Score panel — right side with header
	var panel_x := vp.x - 240
	var panel_w := 230
	var card_height := 28 if _match_flow.config.player_count <= 4 else 22
	var font_size := 15 if _match_flow.config.player_count <= 4 else 12
	var panel_h := 40 + _match_flow.config.player_count * (card_height + 3)

	# Panel background
	var panel_bg := ColorRect.new()
	panel_bg.size = Vector2(panel_w, panel_h)
	panel_bg.position = Vector2(panel_x, 6)
	panel_bg.color = Color(0.08, 0.08, 0.12, 0.9)
	add_child(panel_bg)

	# Panel header
	var header := Label.new()
	header.text = "SCORES"
	header.position = Vector2(panel_x + 8, 10)
	header.size = Vector2(panel_w - 16, 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	add_child(header)

	# Player cards inside the panel
	for i in range(_match_flow.config.player_count):
		var color: Color = PLAYER_COLORS[i] if i < PLAYER_COLORS.size() else Color.WHITE
		var y_off := 32 + i * (card_height + 3)

		var card := Control.new()
		card.size = Vector2(panel_w - 12, card_height)
		card.position = Vector2(panel_x + 6, 6 + y_off)
		add_child(card)
		_score_cards.append(card)

		# Card background
		var card_bg := ColorRect.new()
		card_bg.size = Vector2(panel_w - 12, card_height)
		card_bg.color = Color(0.15, 0.15, 0.2, 0.7)
		card.add_child(card_bg)

		# Color bar
		var bar := ColorRect.new()
		bar.size = Vector2(4, card_height)
		bar.color = color
		card.add_child(bar)

		# Score text
		var lbl := Label.new()
		lbl.position = Vector2(8, 2)
		lbl.size = Vector2(panel_w - 28, card_height - 4)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.clip_text = true
		card.add_child(lbl)
		_score_labels.append(lbl)

	# Info label — bottom center
	_info_label = Label.new()
	_info_label.position = Vector2(vp.x / 2 - 200, vp.y - 28)
	_info_label.size = Vector2(400, 20)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_info_label.text = "P1: WASD/Space | P2: Arrows/Enter | Escape: pause"
	add_child(_info_label)


func _process(_delta: float) -> void:
	if _match_flow == null:
		return
	_update_timer()
	_update_scores()
	_update_layout()


func _update_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10:
		return

	# Timer stays centered
	_timer_label.position = Vector2(vp.x / 2 - 55, 10)

	# Info at bottom
	_info_label.position = Vector2(vp.x / 2 - 200, vp.y - 28)


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
	# Sort players by score for ranking
	var ranked: Array[Dictionary] = []
	for i in range(_match_flow.config.player_count):
		ranked.append({"id": i, "score": _match_flow.scores[i]})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"])

	for i in range(_score_labels.size()):
		var name: String = PLAYER_NAMES[i] if i < PLAYER_NAMES.size() else "P%d" % i
		var castles: int = _match_flow.castles_owned[i]
		var score: int = _match_flow.scores[i]
		# Find rank
		var rank := 1
		for r: Dictionary in ranked:
			if r["id"] == i:
				break
			rank += 1
		var rank_badge: String = ["", "#1 ", "#2 ", "#3 ", "#4 ", "#5 ", "#6 ", "#7 ", "#8 "][rank]
		_score_labels[i].text = "%s%s %d | %d" % [rank_badge, name, score, castles]


func _show_end_screen(summary: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 10:
		vp = Vector2(1600, 900)

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

	# Victory particles
	if winner_id >= 0:
		var win_color: Color = PLAYER_COLORS[winner_id] if winner_id < PLAYER_COLORS.size() else Color.WHITE
		for i in range(30):
			var p := ColorRect.new()
			var sz := randf_range(4, 10)
			p.size = Vector2(sz, sz)
			p.color = win_color if i % 2 == 0 else Color(1, 1, 0.5)
			p.position = Vector2(vp.x / 2, vp.y / 2)
			_end_panel.add_child(p)
			var angle := randf() * TAU
			var dist := randf_range(80, 250)
			var target := Vector2(vp.x / 2 + cos(angle) * dist, vp.y / 2 + sin(angle) * dist - 50)
			var tw := create_tween()
			tw.tween_property(p, "position", target, randf_range(0.5, 1.2))
			tw.parallel().tween_property(p, "modulate:a", 0.0, randf_range(0.8, 1.5))
			tw.tween_callback(p.queue_free)
