class_name DamageData
extends RefCounted
## Typed damage payload shared by weapons, abilities, hazards, enemies and summons.

var amount: float = 0.0
var damage_type: StringName = StatKeys.DMG_BALLISTIC
var team: StringName = StatKeys.TEAM_ENEMY
var source: Node = null
var crit: bool = false
var weakpoint_mult: float = 1.0
var status_type: StringName = StatKeys.STATUS_NONE
var status_power: float = 0.0
var status_duration: float = 0.0
var impulse: Vector3 = Vector3.ZERO
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.UP
var is_melee: bool = false
var can_hit_player: bool = true


static func make(
	p_amount: float,
	p_team: StringName,
	p_type: StringName = StatKeys.DMG_BALLISTIC,
	p_source: Node = null
) -> DamageData:
	var data := DamageData.new()
	data.amount = p_amount
	data.team = p_team
	data.damage_type = p_type
	data.source = p_source
	return data
