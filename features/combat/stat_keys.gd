class_name StatKeys
extends RefCounted
## Canonical stat and slot identifiers. Never use raw strings in gameplay hot paths.

const HEALTH_MAX: StringName = &"health_max"
const SHIELD_MAX: StringName = &"shield_max"
const ARMOR: StringName = &"armor"
const MOVE_SPEED: StringName = &"move_speed"
const SPRINT_SPEED: StringName = &"sprint_speed"
const JUMP_VELOCITY: StringName = &"jump_velocity"
const RELOAD_SPEED: StringName = &"reload_speed"
const HANDLING: StringName = &"handling"
const DAMAGE_MULT: StringName = &"damage_mult"
const ABILITY_POWER: StringName = &"ability_power"
const COOLDOWN_MULT: StringName = &"cooldown_mult"
const CRIT_CHANCE: StringName = &"crit_chance"
const CRIT_MULT: StringName = &"crit_mult"
const STATUS_POWER: StringName = &"status_power"
const LUCK: StringName = &"luck"
const SHIELD_REGEN_RATE: StringName = &"shield_regen_rate"
const SHIELD_REGEN_DELAY: StringName = &"shield_regen_delay"
const ABILITY_RANGE: StringName = &"ability_range"
const PET_POWER: StringName = &"pet_power"

const ATTR_POWER: StringName = &"power"
const ATTR_RESOLVE: StringName = &"resolve"
const ATTR_AGILITY: StringName = &"agility"
const ATTR_TECH: StringName = &"tech"

const SLOT_PRIMARY: StringName = &"primary"
const SLOT_PRIMARY_2: StringName = &"primary_2"
const SLOT_SIDEARM: StringName = &"sidearm"
const SLOT_HELMET: StringName = &"helmet"
const SLOT_CHEST: StringName = &"chest"
const SLOT_LEGS: StringName = &"legs"
const SLOT_CLOAK: StringName = &"cloak"
const SLOT_CHARM: StringName = &"charm"

const EQUIP_SLOTS: Array[StringName] = [
	SLOT_PRIMARY, SLOT_PRIMARY_2, SLOT_SIDEARM, SLOT_HELMET, SLOT_CHEST, SLOT_LEGS, SLOT_CLOAK, SLOT_CHARM
]
const ARMOR_SLOTS: Array[StringName] = [SLOT_HELMET, SLOT_CHEST, SLOT_LEGS, SLOT_CLOAK, SLOT_CHARM]

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
const TEAM_FRIENDLY: StringName = &"friendly"
const TEAM_NEUTRAL: StringName = &"neutral"

const DMG_BALLISTIC: StringName = &"ballistic"
const DMG_ENERGY: StringName = &"energy"
const DMG_SHOCK: StringName = &"shock"
const DMG_BURN: StringName = &"burn"
const DMG_CORROSIVE: StringName = &"corrosive"
const DMG_KINETIC: StringName = &"kinetic"

const STATUS_NONE: StringName = &"none"
const STATUS_SHOCK: StringName = &"shock"
const STATUS_BURN: StringName = &"burn"
const STATUS_CORRODE: StringName = &"corrode"
const STATUS_SLOW: StringName = &"slow"

const RARITY_COLORS: Array[Color] = [
	Color("a7b4b6"), Color("63e6c3"), Color("6fa8ff"), Color("c79cff"), Color("ffc16b")
]
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Prototype"]
const RARITY_MULT: Array[float] = [1.0, 1.12, 1.25, 1.42, 1.62]
