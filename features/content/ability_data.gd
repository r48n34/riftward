class_name AbilityData
extends Resource
## Data-driven active skill / ultimate. Effect implementations live in
## features/abilities/ability_effects.gd and are resolved by effect_id.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var discipline: StringName = &"shared"
@export var effect_id: StringName = &""
@export var cooldown: float = 12.0
@export var charges: int = 1
@export var magnitude: float = 1.0
@export var duration: float = 0.0
@export var radius: float = 3.0
@export var range: float = 25.0
@export var projectile_count: int = 0
@export var color: Color = Color("62e6c3")
@export var unlock_level: int = 1
@export var is_ultimate: bool = false
@export var tags: PackedStringArray = PackedStringArray()
@export var icon: StringName = &"bolt"


func cooldown_with(stats: StatsComponent) -> float:
	if stats == null:
		return cooldown
	return maxf(1.5, cooldown * stats.get_stat(StatKeys.COOLDOWN_MULT, 1.0))
