class_name WeaponData
extends Resource
## Designer-facing weapon archetype. Runtime variants add rarity, mods and mastery.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var archetype: StringName = &"rifle"
@export var slot: StringName = StatKeys.SLOT_PRIMARY
@export var damage: float = 20.0
@export var pellets: int = 1
@export var fire_rate: float = 600.0  # rounds per minute
@export var fire_mode: StringName = &"auto"  # auto, semi, burst, charge, projectile
@export var burst_count: int = 1
@export var mag_size: int = 30
@export var reserve_ammo: int = 210
@export var reload_time: float = 2.0
@export var spread_hip: float = 2.5  # degrees
@export var spread_ads: float = 0.35
## Field-of-view multiplier at full ADS. 1.0 = no zoom; 0.5 = 2x; 0.34 is about 2.9x.
@export var ads_zoom: float = 0.82
@export var recoil_pattern: PackedVector2Array = PackedVector2Array()
@export var recoil_kick: float = 1.0
@export var effective_range: float = 120.0
@export var falloff_start: float = 45.0
@export var range_mult: float = 1.0
@export var crit_mult: float = 1.75
@export var projectile_speed: float = 70.0
@export var status_type: StringName = StatKeys.STATUS_NONE
@export var status_chance: float = 0.0
@export var status_power: float = 0.0
@export var style: StringName = &"rifle"
@export var color: Color = Color("f4efe5")
@export var accent: Color = Color("62e6c3")
@export var value: int = 120
@export var tier: int = 1
@export var unique_perk: String = ""
@export var sound_pitch: float = 1.0


func get_rpm() -> float:
	return maxf(30.0, fire_rate)
