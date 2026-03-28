## Grid data model for Crystal Kingdoms.
## Holds cell ownership, contagion counters, and cursor state.
## Only RulesEngine and TurnDirector may mutate this. All others read-only.
class_name BoardState
extends RefCounted

var size: int
var wrap_around: bool
var cells_owner: Array[int] = []          ## -1 = empty, 0..N = player index
var cells_contagion: Array[Dictionary] = [] ## [{player_id: int}] per cell
var cells_blocked: Array[bool] = []       ## true = impassable, no cursor/capture/contagion
var cursor_index: int = -1
var cursor_active: bool = false


func _init(config: GameConfig = null) -> void:
	if config == null:
		return
	size = config.grid_size
	wrap_around = config.wrap_around
	_allocate_cells()
	_apply_board_shape(config.board_shape)


func _allocate_cells() -> void:
	var count := size * size
	cells_owner.resize(count)
	cells_contagion.resize(count)
	cells_blocked.resize(count)
	for i in range(count):
		cells_owner[i] = -1
		cells_contagion[i] = {}
		cells_blocked[i] = false
	cursor_index = -1
	cursor_active = false


func _apply_board_shape(shape: CKEnums.BoardShape) -> void:
	if shape == CKEnums.BoardShape.RECTANGLE:
		return  # No blocked cells
	var center := (size - 1) / 2.0
	for i in range(size * size):
		var row := i / size
		var col := i % size
		var dr := absf(row - center)
		var dc := absf(col - center)
		match shape:
			CKEnums.BoardShape.DIAMOND:
				# Block corners: manhattan distance > half grid
				if dr + dc > center + 0.5:
					cells_blocked[i] = true
			CKEnums.BoardShape.HOURGLASS:
				# Block sides in the middle rows
				var row_ratio := dr / center if center > 0 else 0.0
				var max_width := lerpf(center * 0.4, center, row_ratio)
				if dc > max_width + 0.5:
					cells_blocked[i] = true
			CKEnums.BoardShape.CROSS:
				# Block cells not in center cross arms
				var arm_width := maxi(1, size / 4)
				var in_h_arm := absf(row - center) <= arm_width
				var in_v_arm := absf(col - center) <= arm_width
				if not in_h_arm and not in_v_arm:
					cells_blocked[i] = true
			CKEnums.BoardShape.RING:
				# Block center and outermost ring
				var dist := sqrt(dr * dr + dc * dc)
				if dist < center * 0.3 or dist > center + 0.5:
					cells_blocked[i] = true


## Convert flat index to (row, col).
func index_to_coords(index: int) -> Vector2i:
	return Vector2i(index % size, index / size)


## Convert (row, col) to flat index.
func coords_to_index(row: int, col: int) -> int:
	return row * size + col


## Get the neighbor cell index in a direction. Returns -1 if off-edge and no wrap.
func get_neighbor(index: int, direction: CKEnums.Direction) -> int:
	var row := index / size
	var col := index % size
	var offset: Vector2i = CKEnums.DIR_OFFSETS[direction]
	var new_row := row + offset.y
	var new_col := col + offset.x

	if wrap_around:
		new_row = posmod(new_row, size)
		new_col = posmod(new_col, size)
	else:
		if new_row < 0 or new_row >= size or new_col < 0 or new_col >= size:
			return -1

	return new_row * size + new_col


## Get all orthogonal neighbor indices (up to 4).
func get_adjacent_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	for dir in [CKEnums.Direction.UP, CKEnums.Direction.DOWN,
				CKEnums.Direction.LEFT, CKEnums.Direction.RIGHT]:
		var n := get_neighbor(index, dir)
		if n != -1:
			result.append(n)
	return result


## Count orthogonal neighbors owned by a specific player.
func count_adjacent_owned(index: int, player_id: int) -> int:
	var count := 0
	for dir in [CKEnums.Direction.UP, CKEnums.Direction.DOWN,
				CKEnums.Direction.LEFT, CKEnums.Direction.RIGHT]:
		var n := get_neighbor(index, dir)
		if n != -1 and cells_owner[n] == player_id:
			count += 1
	return count


## Get ordered list of cell indices from start (exclusive) along a direction.
## Stops at board edge (no wrap) or when returning to start (wrap).
## Used by CPU Controller for chain lookahead.
func get_cells_in_direction(start: int, direction: CKEnums.Direction) -> Array[int]:
	var result: Array[int] = []
	var current := start
	while true:
		var next := get_neighbor(current, direction)
		if next == -1 or next == start:
			break
		result.append(next)
		current = next
	return result


## Check if a cell is blocked (impassable).
func is_blocked(index: int) -> bool:
	return index >= 0 and index < cells_blocked.size() and cells_blocked[index]


## Get all empty non-blocked cell indices.
func get_empty_cells() -> Array[int]:
	var result: Array[int] = []
	for i in range(size * size):
		if cells_owner[i] == -1 and not cells_blocked[i]:
			result.append(i)
	return result


## Get total playable (non-blocked) cell count.
func get_playable_count() -> int:
	var count := 0
	for i in range(size * size):
		if not cells_blocked[i]:
			count += 1
	return count


## Count cells owned by a player.
func count_owned_by(player_id: int) -> int:
	var count := 0
	for i in range(size * size):
		if cells_owner[i] == player_id:
			count += 1
	return count
