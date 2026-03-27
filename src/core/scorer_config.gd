## Configuration for a single scoring parameter with curve, multiplier, and adjustment.
## Used as a sub-resource of GameConfig for adjacency, contagion, and capture scoring.
class_name ScorerConfig
extends Resource

@export var curve: CKEnums.CurveType = CKEnums.CurveType.COUNT
@export var multiplier: float = 1.0
@export var adjustment: float = 0.0
@export var custom_values: Array[int] = []


## Evaluate the scoring curve for a given input n (1-based).
## Returns max(1, round_half_up(curve(n) * multiplier + adjustment)).
func effective(n: int) -> int:
	if n < 1:
		return 1
	var raw := _curve_value(n)
	var scaled := raw * multiplier + adjustment
	return maxi(1, _round_half_up(scaled))


## Preview effective values for n=1..count. Used by Menu System UI.
func preview(count: int = 5) -> Array[int]:
	var result: Array[int] = []
	for i in range(1, count + 1):
		result.append(effective(i))
	return result


func _curve_value(n: int) -> int:
	match curve:
		CKEnums.CurveType.POWER_OF_TWO:
			return int(pow(2, n - 1))
		CKEnums.CurveType.COUNT:
			return n
		CKEnums.CurveType.FIBONACCI:
			if n <= CKEnums.FIBONACCI_LOOKUP.size():
				return CKEnums.FIBONACCI_LOOKUP[n - 1]
			return CKEnums.FIBONACCI_LOOKUP[CKEnums.FIBONACCI_LOOKUP.size() - 1]
		CKEnums.CurveType.SQUARE:
			return n * n
		CKEnums.CurveType.CUSTOM:
			if custom_values.is_empty():
				return 1
			var idx := mini(n - 1, custom_values.size() - 1)
			return maxi(1, custom_values[idx])
	return 1


static func _round_half_up(value: float) -> int:
	return int(floor(value + 0.5))
