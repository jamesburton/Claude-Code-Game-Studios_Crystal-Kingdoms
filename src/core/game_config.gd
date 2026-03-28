## Central configuration resource for a Crystal Kingdoms match.
## Read by all gameplay systems. Immutable during gameplay (locked via duplicate(true) at match start).
class_name GameConfig
extends Resource

# --- Board Settings ---
@export var grid_size: int = 8
@export var wrap_around: bool = true
@export var cursor_select_captured: bool = false

# --- Scoring Settings ---
@export var scoring_mode: CKEnums.ScoringMode = CKEnums.ScoringMode.BASIC
@export var lone_castle_scores_zero: bool = false
@export var adjacency_scorer: ScorerConfig
@export var contagion_scorer: ScorerConfig
@export var capture_scorer: ScorerConfig

# --- Points Lost ---
@export var points_lost_base: CKEnums.PointsLostBase = CKEnums.PointsLostBase.CAPTURE
@export var points_lost_multiplier: float = 1.5
@export var points_lost_adjustment: float = 0.0

# --- Contagion ---
@export var capture_threshold: int = 3

# --- Timing ---
@export var cursor_spawn_delay_min: float = 0.5
@export var cursor_spawn_delay_max: float = 2.4
@export var cursor_expire_time: float = 5.0
@export var chain_step_delay: float = 0.2

# --- Match End ---
@export var time_limit: int = 90
@export var winning_score: int = 0

# --- Constraints ---
@export var max_actions: int = 0
@export var max_castles: int = 0

# --- Board Shape ---
@export var board_shape: CKEnums.BoardShape = CKEnums.BoardShape.RECTANGLE
@export var skip_blanks: bool = true  ## Chains skip over blocked cells to next playable cell
@export var pre_placed_castles: bool = false  ## Start with 1-2 castles per player
@export var persistent_specials: bool = false  ## Special cells retain type after capture
@export var danger_cell_count: int = 0  ## Cells with 50% scoring
@export var bonus_cell_count: int = 0  ## Cells with 200% scoring
@export var neutral_count: int = 0  ## Grey castles needing contagion to capture
@export var reinforced_count: int = 0  ## +1 extra contagion, 150% score
@export var fortified_count: int = 0  ## +2 extra contagion, 200% score

# --- Input ---
@export var allow_tap: bool = true  ## When false, only directional swipes work (no fire/tap)

# --- Player Count ---
@export var player_count: int = 2


func _init() -> void:
	if adjacency_scorer == null:
		adjacency_scorer = ScorerConfig.new()
		adjacency_scorer.curve = CKEnums.CurveType.POWER_OF_TWO
		adjacency_scorer.multiplier = 1.0
	if contagion_scorer == null:
		contagion_scorer = ScorerConfig.new()
		contagion_scorer.curve = CKEnums.CurveType.COUNT
		contagion_scorer.multiplier = 1.0
	if capture_scorer == null:
		capture_scorer = ScorerConfig.new()
		capture_scorer.curve = CKEnums.CurveType.SQUARE
		capture_scorer.multiplier = 1.2


## Get the scorer resource for the points_lost_base selection.
func get_lost_base_scorer() -> ScorerConfig:
	match points_lost_base:
		CKEnums.PointsLostBase.ADJACENCY:
			return adjacency_scorer
		CKEnums.PointsLostBase.CONTAGION:
			return contagion_scorer
		CKEnums.PointsLostBase.CAPTURE:
			return capture_scorer
	return capture_scorer


## Calculate points lost for a captured player given their adjacent count.
func calc_points_lost(adjacent_count: int) -> int:
	var base_scorer := get_lost_base_scorer()
	var base_value := base_scorer.effective(maxi(1, adjacent_count))
	var scaled := base_value * points_lost_multiplier + points_lost_adjustment
	return -maxi(1, ScorerConfig._round_half_up(scaled))


## Apply a speed preset, overwriting timing values.
func apply_speed_preset(preset: CKEnums.SpeedPreset) -> void:
	match preset:
		CKEnums.SpeedPreset.RELAXED:
			cursor_spawn_delay_min = 2.0
			cursor_spawn_delay_max = 4.0
			cursor_expire_time = 8.0
			chain_step_delay = 0.4
		CKEnums.SpeedPreset.NORMAL:
			cursor_spawn_delay_min = 0.5
			cursor_spawn_delay_max = 2.4
			cursor_expire_time = 5.0
			chain_step_delay = 0.2
		CKEnums.SpeedPreset.FAST:
			cursor_spawn_delay_min = 0.5
			cursor_spawn_delay_max = 1.5
			cursor_expire_time = 3.0
			chain_step_delay = 0.1
		CKEnums.SpeedPreset.FRANTIC:
			cursor_spawn_delay_min = 0.5
			cursor_spawn_delay_max = 1.0
			cursor_expire_time = 2.0
			chain_step_delay = 0.05


## Calculate a sensible default max_castles: grid² / players * 1.15, rounded up.
## Gives ~15% headroom before lock-out.
static func calc_default_max_castles(grid: int, players: int) -> int:
	if players <= 0:
		return 0
	return ceili(float(grid * grid) / float(players) * 1.15)


## Create an immutable snapshot for use during a match.
func lock() -> GameConfig:
	return duplicate(true) as GameConfig
