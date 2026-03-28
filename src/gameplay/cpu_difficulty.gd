## Configuration resource for CPU AI difficulty profiles.
## Loaded by CPU Controller based on GameConfig's cpu_difficulty enum.
class_name CpuDifficulty
extends Resource

@export var display_name: String = "CPU"  ## Shown in player setup
@export var reaction_min: float = 0.8  ## Fastest possible reaction (seconds)
@export var reaction_max: float = 1.8  ## Slowest reaction (seconds)
@export var strategic_bias: float = 0.6  ## Probability of choosing optimal action vs random
@export var skip_chance: float = 0.0  ## Probability of deliberately not acting on this cursor
@export var chain_awareness: bool = true  ## Whether AI evaluates chain outcomes
@export var threat_awareness: bool = false  ## Whether AI considers enemy threats
@export var near_capture_bonus: int = 5  ## Score boost for cells near capture threshold
@export var own_castle_penalty: int = -1  ## Score penalty for targeting own castles
