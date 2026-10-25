class_name EnemyData
extends Resource
## Enemy archetype. Enemy scenes/visuals are assembled procedurally by EnemyAgent.

@export var id: StringName = &""
@export var display_name: String = ""
@export var faction: StringName = &"ashen"
@export var role: StringName = &"rusher"  # rusher, marksman, tank, support, flyer, ambusher, elite, boss
@export var max_health: float = 80.0
@export var max_shield: float = 0.0
@export var armor: float = 0.0
@export var damage: float = 10.0
@export var move_speed: float = 4.2
@export var attack_range: float = 32.0
@export var preferred_range: float = 18.0
@export var attack_interval: float = 1.5
@export var projectile_speed: float = 28.0
@export var ranged: bool = true
@export var xp: int = 25
@export var salvage: int = 8
@export var elite: bool = false
@export var boss: bool = false
@export var body_color: Color = Color("d28b58")
@export var accent_color: Color = Color("ffb866")
@export var eye_color: Color = Color("ff6e6e")
@export var body_scale: float = 1.0
@export var style: StringName = &"humanoid"  # humanoid, beast, flyer, heavy, titan, swimmer, drone
## Preferred environment. Spawners avoid putting land-bound enemies in lava and
## water-bound enemies on dry ground where possible.
@export var habitat: StringName = &"land"  # land, water, lava, any
@export var weakpoint_mult: float = 1.8
@export var behavior_flags: PackedStringArray = PackedStringArray()
@export var boss_phases: int = 1
@export var loot_bonus: float = 1.0
