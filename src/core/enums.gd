## Core enumerations used across Crystal Kingdoms systems.
class_name CKEnums
extends RefCounted

enum Direction { UP, DOWN, LEFT, RIGHT }

enum CurveType { POWER_OF_TWO, COUNT, FIBONACCI, SQUARE, CUSTOM }

enum ScoringMode { BASIC, ONLY_CASTLES }

enum SpeedPreset { RELAXED, NORMAL, FAST, FRANTIC }

enum PointsLostBase { ADJACENCY, CONTAGION, CAPTURE }

enum BoardShape { RECTANGLE, DIAMOND, HOURGLASS, CROSS, RING }

enum EventType {
	CAPTURE_EMPTY,
	INCREMENT_CONTAGION,
	CAPTURE_CONTAGION,
	DESTROY_OWN_CASTLE,
	CHAIN_ENDED,
}

## Fibonacci lookup table: fib(n+1) for n=1..12, matching the GDD.
const FIBONACCI_LOOKUP: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]

## Direction offsets as (col_delta, row_delta) for grid navigation.
const DIR_OFFSETS: Dictionary = {
	Direction.UP:    Vector2i(0, -1),
	Direction.DOWN:  Vector2i(0, 1),
	Direction.LEFT:  Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
}
