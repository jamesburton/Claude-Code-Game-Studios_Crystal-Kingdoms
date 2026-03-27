## Configuration resource for CPU AI difficulty profiles.
## Loaded by CPU Controller based on GameConfig's cpu_difficulty enum.
class_name CpuDifficulty
extends Resource

@export var reaction_min: float = 0.6
@export var reaction_max: float = 1.5
@export var strategic_bias: float = 0.6
@export var chain_awareness: bool = true
@export var threat_awareness: bool = false
@export var near_capture_bonus: int = 5
@export var own_castle_penalty: int = -1
