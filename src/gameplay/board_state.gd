## Grid data model for Crystal Kingdoms.
## Holds cell ownership, contagion counters, and cursor state.
## Only RulesEngine and TurnDirector may mutate this. All others read-only.
class_name BoardState
extends RefCounted

var size: int
var wrap_around: bool
var cells_owner: Array[int] = []          ## -1 = empty, 0..N = player index
var cells_contagion: Array[Dictionary] = [] ## [{player_id: int}] per cell
var cursor_index: int = -1
var cursor_active: bool = false


func _init(config: GameConfig = null) -> void:
	if config == null:
		return
	size = config.grid_size
	wrap_around = config.wrap_around
	_allocate_cells()


func _allocate_cells() -> void:
	var count := size * size
	cells_owner.resize(count)
	cells_contagion.resize(count)
	for i in range(count):
		cells_owner[i] = -1
		cells_contagion[i] = {}
	cursor_index = -1
	cursor_active = false


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


## Get all empty cell indices.
func get_empty_cells() -> Array[int]:
	var result: Array[int] = []
	for i in range(size * size):
		if cells_owner[i] == -1:
			result.append(i)
	return result


## Count cells owned by a player.
func count_owned_by(player_id: int) -> int:
	var count := 0
	for i in range(size * size):
		if cells_owner[i] == player_id:
			count += 1
	return count
