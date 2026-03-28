## Renders the Crystal Kingdoms board as a 2D grid of colored cells.
## Consumes EventLogs to animate state changes. Emits animation_complete when done.
class_name BoardRenderer
extends Node2D

signal animation_complete()

const CELL_GAP := 4
const COLOR_EMPTY := Color(0.25, 0.25, 0.3)
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
var _use_sprites: bool = false

var _board: BoardState
var _grid_size: int
var _cell_px: int
var _grid_origin := Vector2.ZERO

var _cell_rects: Array[ColorRect] = []
var _cell_sprites: Array[Sprite2D] = []
var _cell_labels: Array[Label] = []
var _cursor_rect: ColorRect
var _cursor_sprite: Sprite2D
var _cursor_pulse: float = 0.0

var _anim_queue: Array[Dictionary] = []
var _anim_timer: float = 0.0
var _chain_step_delay: float = 0.2

# Popup container
var _popup_container: Node2D


## Initialize the renderer with board state and viewport dimensions.
func setup(board: BoardState, chain_delay: float, viewport_size: Vector2) -> void:
	_board = board
	_grid_size = board.size
	_chain_step_delay = chain_delay

	# Calculate cell size to fit viewport
	var available := minf(viewport_size.x - 40, viewport_size.y - 120)
	_cell_px = int(available / _grid_size) - CELL_GAP
	var total := _cell_px * _grid_size + CELL_GAP * (_grid_size - 1)
	_grid_origin = Vector2((viewport_size.x - total) / 2.0, 60)

	_load_textures()
	_build_grid()


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


func _build_grid() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	_cell_rects.clear()
	_cell_sprites.clear()
	_cell_labels.clear()

	var sprite_scale := _cell_px / 64.0 if _use_sprites else 1.0

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

	# Cursor
	_cursor_rect = ColorRect.new()
	_cursor_rect.size = Vector2(_cell_px, _cell_px)
	_cursor_rect.color = COLOR_CURSOR
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

	_popup_container = Node2D.new()
	add_child(_popup_container)


func _process(delta: float) -> void:
	if _board == null:
		return

	# Cursor pulse
	if _board.cursor_active and _board.cursor_index >= 0:
		_cursor_pulse += delta * 4.0
		var cursor_pos := _cell_pos(_board.cursor_index)
		if _cursor_sprite:
			_cursor_sprite.visible = true
			_cursor_sprite.position = cursor_pos
			_cursor_sprite.modulate.a = 0.6 + 0.4 * sin(_cursor_pulse)
			_cursor_rect.visible = false
		else:
			_cursor_rect.visible = true
			_cursor_rect.position = cursor_pos
			_cursor_rect.color = COLOR_CURSOR * (0.6 + 0.4 * sin(_cursor_pulse))
			_cursor_rect.color.a = 0.7 + 0.3 * sin(_cursor_pulse)
	else:
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
func play_events(events: Array[Dictionary]) -> void:
	_anim_queue = events.duplicate()
	_anim_timer = 0.0
	if events.is_empty():
		animation_complete.emit()


## Get the cell position for popup positioning (used by HUD).
func cell_position(index: int) -> Vector2:
	return _cell_pos(index)


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
		var owner: int = _board.cells_owner[i]

		# Update sprite texture
		if _use_sprites and i < _cell_sprites.size():
			if owner == -1:
				_cell_sprites[i].texture = _castle_empty_texture
			elif owner < _castle_textures.size():
				_cell_sprites[i].texture = _castle_textures[owner]

		# Update background color (visible when sprites not loaded, also used for flash)
		if not _use_sprites:
			if owner == -1:
				_cell_rects[i].color = COLOR_EMPTY
			elif owner < PLAYER_COLORS.size():
				_cell_rects[i].color = PLAYER_COLORS[owner]

		# Contagion labels
		var cont: Dictionary = _board.cells_contagion[i]
		if cont.is_empty():
			_cell_labels[i].text = ""
		else:
			var parts: PackedStringArray = PackedStringArray()
			for p_id: int in cont:
				parts.append("%d:%d" % [p_id, cont[p_id]])
			_cell_labels[i].text = "/".join(parts)


func _animate_event(ev: Dictionary) -> void:
	var index: int = ev["grid_index"]
	var actor: int = ev["actor_id"]
	var color: Color = PLAYER_COLORS[actor] if actor >= 0 and actor < PLAYER_COLORS.size() else Color.WHITE

	# Flash
	var rect := _cell_rects[index]
	var tween := create_tween()
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
