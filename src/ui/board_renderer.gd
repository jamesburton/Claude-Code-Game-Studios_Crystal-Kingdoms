## Renders the Crystal Kingdoms board as a 2D grid of colored cells.
## Consumes EventLogs to animate state changes. Emits animation_complete when done.
class_name BoardRenderer
extends Node2D

signal animation_complete()

const CELL_GAP := 4
const COLOR_EMPTY := Color(0.25, 0.25, 0.3)
const COLOR_BLOCKED := Color(0.1, 0.1, 0.12)
const COLOR_CURSOR := Color(1.0, 1.0, 0.2, 0.8)
const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.5, 1.0),   # Blue
	Color(1.0, 0.3, 0.2),   # Red
	Color(0.2, 0.8, 0.3),   # Green
	Color(1.0, 0.6, 0.1),   # Orange
	Color(0.9, 0.9, 0.2),   # Yellow
	Color(0.6, 0.3, 0.8),   # Purple
	Color(0.2, 0.8, 0.8),   # Cyan
	Color(0.9, 0.3, 0.7),   # Magenta
]

const CASTLE_SPRITE_NAMES: Array[String] = [
	"Blue", "Red", "Green", "Orange", "Yellow", "Purple", "Cyan", "Magenta"
]

var _castle_textures: Array[Texture2D] = []
var _castle_empty_texture: Texture2D
var _cursor_texture: Texture2D
var _gem_textures: Array[Texture2D] = []
var _use_sprites: bool = false

var _board: BoardState
var _capture_threshold: int = 3
var _grid_size: int
var _cell_px: int
var _grid_origin := Vector2.ZERO

var _cell_rects: Array[ColorRect] = []
var _cell_sprites: Array[Sprite2D] = []
var _cell_labels: Array[Label] = []
var _cell_gem_containers: Array[Node2D] = []
var _cursor_rect: ColorRect
var _cursor_border: ReferenceRect
var _cursor_sprite: Sprite2D
var _cursor_pulse: float = 0.0
var _cursor_spawn_scale: float = 1.0  # For spawn scale-in animation
var _cursor_prev_index: int = -1  # Track cursor changes

# Screen shake
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

var _bonus_cells: Dictionary = {}  # {cell_index: player_id} for bonus castle markers
var _anim_queue: Array = []  # Untyped to avoid Array[Dictionary] assignment issues
var _anim_timer: float = 0.0
var _chain_step_delay: float = 0.2

# Chain trail
var _chain_line: Line2D

# Popup container
var _popup_container: Node2D


const SPRITE_BASE_SIZE := 256  ## Base texture size for castle sprites
const HUD_TOP_MARGIN := 50  ## Space reserved for top HUD bar
const HUD_BOTTOM_MARGIN := 30  ## Space reserved for bottom info
const HUD_SIDE_MARGIN := 20  ## Minimum side padding


## Initialize the renderer with board state.
func setup(board: BoardState, chain_delay: float, _viewport_size: Vector2, threshold: int = 3) -> void:
	_board = board
	_grid_size = board.size
	_chain_step_delay = chain_delay
	_capture_threshold = threshold

	_load_textures()
	_recalculate_layout()
	_build_grid()

	# Listen for window resize
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_recalculate_layout()
	_rebuild_positions()


func _recalculate_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var available_w := vp_size.x - HUD_SIDE_MARGIN * 2
	var available_h := vp_size.y - HUD_TOP_MARGIN - HUD_BOTTOM_MARGIN
	var available := minf(available_w, available_h)
	_cell_px = int(available / _grid_size) - CELL_GAP
	_cell_px = maxi(_cell_px, 16)  # absolute minimum cell size
	var total := _cell_px * _grid_size + CELL_GAP * (_grid_size - 1)
	_grid_origin = Vector2(
		(vp_size.x - total) / 2.0,
		HUD_TOP_MARGIN + (available_h - total) / 2.0)


func _rebuild_positions() -> void:
	if _cell_rects.is_empty():
		return
	var sprite_scale := float(_cell_px) / SPRITE_BASE_SIZE
	for i in range(_grid_size * _grid_size):
		var pos := _cell_pos(i)
		_cell_rects[i].size = Vector2(_cell_px, _cell_px)
		_cell_rects[i].position = pos
		if i < _cell_sprites.size():
			_cell_sprites[i].position = pos
			_cell_sprites[i].scale = Vector2(sprite_scale, sprite_scale)
		if i < _cell_labels.size():
			_cell_labels[i].position = pos + Vector2(4, _cell_px - 18)
			_cell_labels[i].size = Vector2(_cell_px - 8, 18)
	_cursor_rect.size = Vector2(_cell_px, _cell_px)
	if _cursor_sprite:
		_cursor_sprite.scale = Vector2(sprite_scale, sprite_scale)


func _load_textures() -> void:
	_castle_textures.clear()
	# Try loading castle sprites
	var empty_path := "res://images/Basic Castle Start.png"
	if ResourceLoader.exists(empty_path):
		_castle_empty_texture = load(empty_path)
		_use_sprites = true
		for color_name: String in CASTLE_SPRITE_NAMES:
			var path := "res://images/Basic Castle Start %s.png" % color_name
			if ResourceLoader.exists(path):
				_castle_textures.append(load(path))
			else:
				_castle_textures.append(_castle_empty_texture)
		var cursor_path := "res://images/Cursor 64x64.png"
		if ResourceLoader.exists(cursor_path):
			_cursor_texture = load(cursor_path)

		# Load gem sprites for contagion display
		_gem_textures.clear()
		for color_name: String in CASTLE_SPRITE_NAMES:
			var gem_path := "res://images/6x6 Gem %s.png" % color_name
			if ResourceLoader.exists(gem_path):
				_gem_textures.append(load(gem_path))
			else:
				_gem_textures.append(null)


func _build_grid() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	_cell_rects.clear()
	_cell_sprites.clear()
	_cell_labels.clear()
	_cell_gem_containers.clear()

	var sprite_scale := float(_cell_px) / SPRITE_BASE_SIZE if _use_sprites else 1.0

	for i in range(_grid_size * _grid_size):
		var row := i / _grid_size
		var col := i % _grid_size
		var pos := _grid_origin + Vector2(
			col * (_cell_px + CELL_GAP), row * (_cell_px + CELL_GAP))

		# Background rect (used for flash animation and fallback)
		var rect := ColorRect.new()
		rect.size = Vector2(_cell_px, _cell_px)
		rect.position = pos
		rect.color = COLOR_EMPTY
		add_child(rect)
		_cell_rects.append(rect)

		# Castle sprite overlay
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = pos
		spr.scale = Vector2(sprite_scale, sprite_scale)
		if _use_sprites and _castle_empty_texture:
			spr.texture = _castle_empty_texture
		spr.visible = _use_sprites
		add_child(spr)
		_cell_sprites.append(spr)

		# Contagion label
		var lbl := Label.new()
		lbl.position = pos + Vector2(4, _cell_px - 18)
		lbl.size = Vector2(_cell_px - 8, 18)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", clampi(_cell_px / 6, 8, 14))
		lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(lbl)
		_cell_labels.append(lbl)

		# Gem container for contagion display
		var gem_node := Node2D.new()
		gem_node.position = pos
		add_child(gem_node)
		_cell_gem_containers.append(gem_node)

	# Cursor — bright border that extends beyond cell + overlay
	var border_pad := maxi(4, _cell_px / 8)
	_cursor_border = ReferenceRect.new()
	_cursor_border.size = Vector2(_cell_px + border_pad * 2, _cell_px + border_pad * 2)
	_cursor_border.border_color = Color(1.0, 1.0, 0.0)
	_cursor_border.border_width = maxf(3.0, _cell_px / 12.0)
	_cursor_border.editor_only = false
	_cursor_border.visible = false
	_cursor_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_border)

	_cursor_rect = ColorRect.new()
	_cursor_rect.size = Vector2(_cell_px, _cell_px)
	_cursor_rect.color = Color(1.0, 1.0, 0.3, 0.5)
	_cursor_rect.visible = false
	_cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_rect)

	if _use_sprites and _cursor_texture:
		_cursor_sprite = Sprite2D.new()
		_cursor_sprite.centered = false
		_cursor_sprite.texture = _cursor_texture
		_cursor_sprite.scale = Vector2(sprite_scale, sprite_scale)
		_cursor_sprite.visible = false
		add_child(_cursor_sprite)
	else:
		_cursor_sprite = null

	# Chain trail line
	_chain_line = Line2D.new()
	_chain_line.width = maxf(2.0, _cell_px / 10.0)
	_chain_line.default_color = Color(1.0, 1.0, 0.3, 0.6)
	_chain_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_chain_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_chain_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_chain_line)

	_popup_container = Node2D.new()
	add_child(_popup_container)


func _process(delta: float) -> void:
	if _board == null:
		return

	# Screen shake
	if _shake_timer > 0:
		_shake_timer -= delta
		var shake_amount := _shake_intensity * (_shake_timer / 0.2)
		position = Vector2(randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount))
		if _shake_timer <= 0:
			position = Vector2.ZERO

	# Detect new cursor spawn for scale-in
	if _board.cursor_active and _board.cursor_index >= 0 and _board.cursor_index != _cursor_prev_index:
		_cursor_spawn_scale = 0.0
		_cursor_pulse = 0.0
		_cursor_prev_index = _board.cursor_index
	elif not _board.cursor_active:
		_cursor_prev_index = -1

	# Cursor rendering
	if _board.cursor_active and _board.cursor_index >= 0:
		_cursor_pulse += delta * 6.0
		# Scale-in animation
		_cursor_spawn_scale = minf(_cursor_spawn_scale + delta * 8.0, 1.0)
		var scale_ease := _cursor_spawn_scale * _cursor_spawn_scale * (3.0 - 2.0 * _cursor_spawn_scale)  # smoothstep

		var cursor_pos := _cell_pos(_board.cursor_index)
		var pulse_val := 0.7 + 0.3 * sin(_cursor_pulse)
		var border_pad := maxi(4, _cell_px / 8)
		var scaled_pad := int(border_pad * scale_ease)
		var scaled_size := int(_cell_px * scale_ease)
		var offset := (_cell_px - scaled_size) / 2.0

		# Bright pulsing border — scales in
		_cursor_border.visible = true
		_cursor_border.position = cursor_pos + Vector2(offset - scaled_pad, offset - scaled_pad)
		_cursor_border.size = Vector2(scaled_size + scaled_pad * 2, scaled_size + scaled_pad * 2)
		_cursor_border.border_color = Color(1.0, 1.0, 0.0, pulse_val * scale_ease)

		# Yellow overlay
		_cursor_rect.visible = true
		_cursor_rect.position = cursor_pos + Vector2(offset, offset)
		_cursor_rect.size = Vector2(scaled_size, scaled_size)
		_cursor_rect.color = Color(1.0, 1.0, 0.2, (0.3 + 0.2 * sin(_cursor_pulse)) * scale_ease)

		# Sprite if available
		if _cursor_sprite:
			var sprite_scale := float(_cell_px) / SPRITE_BASE_SIZE * scale_ease
			_cursor_sprite.visible = scale_ease > 0.1
			_cursor_sprite.position = cursor_pos + Vector2(offset, offset)
			_cursor_sprite.scale = Vector2(sprite_scale, sprite_scale)
			_cursor_sprite.modulate = Color(1.0, 1.0, 1.0, pulse_val * scale_ease)
	else:
		_cursor_border.visible = false
		_cursor_rect.visible = false
		if _cursor_sprite:
			_cursor_sprite.visible = false

	# Animation queue
	if _anim_queue.size() > 0:
		_anim_timer -= delta
		if _anim_timer <= 0:
			var ev: Dictionary = _anim_queue.pop_front()
			_animate_event(ev)
			_anim_timer = _chain_step_delay
			if _anim_queue.is_empty():
				animation_complete.emit()

	_update_cells()


## Queue events for animation.
func play_events(events: Array) -> void:
	_anim_queue.clear()
	_chain_line.clear_points()
	for ev in events:
		_anim_queue.append(ev)
	_anim_timer = 0.0
	if _anim_queue.is_empty():
		animation_complete.emit()


## Get the cell position for popup positioning (used by HUD).
func cell_position(index: int) -> Vector2:
	return _cell_pos(index)


## Update which cells have bonus castle markers.
func set_bonus_cells(bonus_stacks: Array) -> void:
	_bonus_cells.clear()
	for player_id in range(bonus_stacks.size()):
		var stack: Array = bonus_stacks[player_id]
		for cell_idx: int in stack:
			_bonus_cells[cell_idx] = player_id


## Get cell pixel size.
func get_cell_size() -> int:
	return _cell_px


func _cell_pos(index: int) -> Vector2:
	var row := index / _grid_size
	var col := index % _grid_size
	return _grid_origin + Vector2(
		col * (_cell_px + CELL_GAP), row * (_cell_px + CELL_GAP))


func _update_cells() -> void:
	for i in range(_grid_size * _grid_size):
		var is_blocked: bool = _board.is_blocked(i)
		var owner: int = _board.cells_owner[i]

		if is_blocked:
			# Blocked cell — dark, no sprite, no labels
			_cell_rects[i].color = COLOR_BLOCKED
			if _use_sprites and i < _cell_sprites.size():
				_cell_sprites[i].visible = false
			_cell_labels[i].text = ""
			continue

		# Update sprite texture
		if _use_sprites and i < _cell_sprites.size():
			_cell_sprites[i].visible = true
			if owner == -1:
				_cell_sprites[i].texture = _castle_empty_texture
			elif owner < _castle_textures.size():
				_cell_sprites[i].texture = _castle_textures[owner]

		# Update background color
		if not _use_sprites:
			if owner == -1:
				_cell_rects[i].color = COLOR_EMPTY
			elif owner < PLAYER_COLORS.size():
				_cell_rects[i].color = PLAYER_COLORS[owner]

		# Contagion display
		var cont: Dictionary = _board.cells_contagion[i]
		_update_cell_contagion(i, cont)

		# Bonus castle marker
		if i in _bonus_cells and owner != -1:
			_cell_labels[i].text = _cell_labels[i].text + " *" if _cell_labels[i].text != "" else "*"


## Gem positions around the cell edges (offsets from cell top-left, up to 8 players).
func _get_gem_positions() -> Array[Vector2]:
	var s := _cell_px
	var g := maxi(8, _cell_px / 6)  # gem display size
	var margin := 2
	return [
		Vector2(margin, margin),                      # top-left
		Vector2(s - g - margin, margin),              # top-right
		Vector2(margin, s - g - margin),              # bottom-left
		Vector2(s - g - margin, s - g - margin),      # bottom-right
		Vector2(s / 2 - g / 2, margin),               # top-center
		Vector2(s / 2 - g / 2, s - g - margin),       # bottom-center
		Vector2(margin, s / 2 - g / 2),               # left-center
		Vector2(s - g - margin, s / 2 - g / 2),       # right-center
	]


func _update_cell_contagion(cell_idx: int, cont: Dictionary) -> void:
	var gem_container: Node2D = _cell_gem_containers[cell_idx]

	# Clear existing gem sprites
	for child in gem_container.get_children():
		child.queue_free()

	if cont.is_empty():
		_cell_labels[cell_idx].text = ""
		return

	var gem_size := maxi(8, _cell_px / 6)
	var positions := _get_gem_positions()
	var pos_idx := 0

	# Show gems + count for each player with contagion
	var label_parts: PackedStringArray = PackedStringArray()
	for p_id: int in cont:
		var level: int = cont[p_id]
		if level <= 0:
			continue

		# Place gem sprite if we have the texture
		if _use_sprites and p_id < _gem_textures.size() and _gem_textures[p_id] != null and pos_idx < positions.size():
			var gem_spr := Sprite2D.new()
			gem_spr.texture = _gem_textures[p_id]
			gem_spr.centered = false
			gem_spr.position = positions[pos_idx]
			gem_spr.scale = Vector2(float(gem_size) / 24.0, float(gem_size) / 24.0)
			gem_container.add_child(gem_spr)

			# Level/threshold label next to gem (e.g. "2/3")
			var lvl_lbl := Label.new()
			lvl_lbl.text = "%d/%d" % [level, _capture_threshold]
			lvl_lbl.position = positions[pos_idx] + Vector2(gem_size + 1, -2)
			lvl_lbl.add_theme_font_size_override("font_size", clampi(gem_size - 2, 6, 12))
			var lbl_color: Color = PLAYER_COLORS[p_id] if p_id < PLAYER_COLORS.size() else Color.WHITE
			if level >= _capture_threshold - 1:
				lbl_color = Color(1.0, 0.3, 0.3)  # Red warning when close to capture
			lvl_lbl.add_theme_color_override("font_color", lbl_color)
			gem_container.add_child(lvl_lbl)

			pos_idx += 1
		else:
			label_parts.append("%d:%d" % [p_id, level])

	# Fallback text for overflow or missing gems
	_cell_labels[cell_idx].text = "/".join(label_parts)


func _animate_event(ev: Dictionary) -> void:
	var index: int = ev["grid_index"]
	var actor: int = ev["actor_id"]
	var ev_type: int = ev.get("type", -1)
	var color: Color = PLAYER_COLORS[actor] if actor >= 0 and actor < PLAYER_COLORS.size() else Color.WHITE
	var cell_center := _cell_pos(index) + Vector2(_cell_px / 2.0, _cell_px / 2.0)

	# Chain trail — add point for each cell in the chain
	if ev_type == CKEnums.EventType.CHAIN_ENDED:
		# Fade out the chain line
		if _chain_line.get_point_count() > 0:
			var tw := create_tween()
			tw.tween_property(_chain_line, "modulate:a", 0.0, 0.3)
			tw.tween_callback(_chain_line.clear_points)
			tw.tween_property(_chain_line, "modulate:a", 1.0, 0.0)
		return
	else:
		_chain_line.add_point(cell_center)
		_chain_line.default_color = Color(color, 0.6)

	# Flash — enhanced for captures
	var rect := _cell_rects[index]
	var tween := create_tween()
	if ev_type == CKEnums.EventType.CAPTURE_CONTAGION:
		# Big capture: bright white flash + screen shake + particles
		tween.tween_property(rect, "color", Color(1.0, 1.0, 0.8), 0.08)
		tween.tween_property(rect, "color", color, 0.2)
		_shake_timer = 0.2
		_shake_intensity = maxf(3.0, _cell_px / 15.0)
		_spawn_particles(cell_center, color, 12)
	elif ev_type == CKEnums.EventType.CAPTURE_EMPTY:
		# Regular capture: quick white flash + small particles
		tween.tween_property(rect, "color", Color(1.0, 1.0, 0.9), 0.06)
		tween.tween_property(rect, "color", color, 0.12)
		_spawn_particles(cell_center, color, 6)
	else:
		# Contagion/destroy: subtle flash
		tween.tween_property(rect, "color", Color.WHITE, 0.05)
		tween.tween_property(rect, "color",
			color if _board.cells_owner[index] != -1 else COLOR_EMPTY, 0.15)

	# Point popup
	var points: int = ev["points_delta"]
	if points != 0:
		_spawn_popup(index, "+%d" % points if points > 0 else "%d" % points, color)

	# Target points lost popup
	var target_lost: int = ev.get("target_points_lost", 0)
	if target_lost < 0:
		var target_owner: int = ev.get("target_owner", -1)
		if target_owner >= 0 and target_owner < PLAYER_COLORS.size():
			_spawn_popup(index, "%d" % target_lost, PLAYER_COLORS[target_owner])


func _spawn_particles(center: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var p := ColorRect.new()
		var size := randf_range(3, 6)
		p.size = Vector2(size, size)
		p.color = color
		p.position = center - Vector2(size / 2, size / 2)
		_popup_container.add_child(p)

		var angle := randf() * TAU
		var dist := randf_range(20, 60)
		var target := center + Vector2(cos(angle) * dist, sin(angle) * dist)
		var tw := create_tween()
		tw.tween_property(p, "position", target, randf_range(0.3, 0.6))
		tw.parallel().tween_property(p, "modulate:a", 0.0, randf_range(0.3, 0.6))
		tw.parallel().tween_property(p, "size", Vector2.ZERO, randf_range(0.3, 0.6))
		tw.tween_callback(p.queue_free)


func _spawn_popup(index: int, text: String, color: Color) -> void:
	var pos := _cell_pos(index) + Vector2(_cell_px / 2.0, -5)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_container.add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "position:y", pos.y - 40, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)
