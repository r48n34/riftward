class_name PlayerStats
extends RefCounted
## Pure, shared stat derivation for gameplay and UI previews. No node access.

const BASE_HEALTH := 100.0
const BASE_SHIELD := 50.0
const BASE_ARMOR := 10.0
const BASE_MOVE := 5.4
const BASE_SPRINT := 7.8


static func base_from_attributes(attributes: Dictionary) -> Dictionary:
	var power := float(attributes.get("power", 2))
	var resolve := float(attributes.get("resolve", 3))
	var agility := float(attributes.get("agility", 3))
	var tech := float(attributes.get("tech", 2))
	return {
		StatKeys.HEALTH_MAX: BASE_HEALTH + resolve * 4.0,
		StatKeys.SHIELD_MAX: BASE_SHIELD + resolve * 2.0,
		StatKeys.ARMOR: BASE_ARMOR + resolve * 1.5,
		StatKeys.MOVE_SPEED: BASE_MOVE + agility * 0.03,
		StatKeys.SPRINT_SPEED: BASE_SPRINT + agility * 0.04,
		StatKeys.JUMP_VELOCITY: 5.4,
		StatKeys.RELOAD_SPEED: 1.0 + agility * 0.01,
		StatKeys.HANDLING: 1.0 + agility * 0.008,
		StatKeys.DAMAGE_MULT: 1.0 + power * 0.02,
		StatKeys.ABILITY_POWER: 1.0 + power * 0.015 + tech * 0.01,
		StatKeys.COOLDOWN_MULT: clampf(1.0 - tech * 0.01, 0.7, 1.0),
		StatKeys.CRIT_CHANCE: 0.05 + agility * 0.004,
		StatKeys.CRIT_MULT: 1.75,
		StatKeys.STATUS_POWER: 1.0 + tech * 0.02,
		StatKeys.LUCK: tech * 0.008,
		StatKeys.SHIELD_REGEN_RATE: 12.0,
		StatKeys.SHIELD_REGEN_DELAY: 4.0,
		StatKeys.ABILITY_RANGE: 1.0,
		StatKeys.PET_POWER: 1.0,
	}


static func base_with_profile(profile: Node) -> Dictionary:
	if profile == null:
		return base_from_attributes({})
	var attributes: Dictionary = profile.get_attributes()
	var stats := base_from_attributes(attributes)
	for modifier in profile.get_stat_modifiers():
		var stat: StringName = modifier.get("stat", &"")
		var op: StringName = modifier.get("op", &"add")
		var value := float(modifier.get("value", 0.0))
		if stat == &"":
			continue
		match op:
			&"mult":
				stats[stat] = float(stats.get(stat, 1.0)) * value
			&"override":
				stats[stat] = value
			_:
				stats[stat] = float(stats.get(stat, 0.0)) + value
	return stats


static func preview(profile: Node) -> Dictionary:
	return base_with_profile(profile)
