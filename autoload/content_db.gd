extends Node
## Central, read-only content catalog. All gameplay/UI resolves authored data
## through this service by StringName id.

var weapons: Dictionary = {}
var abilities: Dictionary = {}
var enemies: Dictionary = {}
var allies: Dictionary = {}
var pets: Dictionary = {}
var base_modules: Dictionary = {}
var contracts: Dictionary = {}
var rift_mods: Dictionary = {}
var mutators: Dictionary = {}
var grenades: Dictionary = {}
var item_templates: Dictionary = {}
var cosmetics: Dictionary = {}
var affixes: Dictionary = {}
var perks: Dictionary = {}
var difficulties: Dictionary = {}
var map_presets: Dictionary = {}

var content_errors: Array[String] = []
var initialized: bool = false


func _ready() -> void:
	load_content()


func load_content() -> void:
	var data := ContentLibrary.build()
	weapons = _index(data.weapons, "weapons")
	abilities = _index(data.abilities, "abilities")
	enemies = _index(data.enemies, "enemies")
	allies = _index(data.allies, "allies")
	pets = _index(data.pets, "pets")
	base_modules = _index(data.base_modules, "base_modules")
	contracts = _index(data.contracts, "contracts")
	rift_mods = _index(data.rift_mods, "rift_mods")
	mutators = _index(data.mutators, "mutators")
	grenades = _index(data.grenades, "grenades")
	item_templates = _index(data.item_templates, "item_templates")
	cosmetics = _index(data.cosmetics, "cosmetics")
	perks = _index(data.perks, "perks")
	difficulties = _index(data.difficulties, "difficulties")
	map_presets = _index(data.map_presets, "map_presets")
	for affix in data.affixes:
		var affix_id: StringName = affix.id
		if affixes.has(affix_id):
			content_errors.append("Duplicate affix id: %s" % affix_id)
		affixes[affix_id] = affix
	_validate_expected_counts()
	initialized = true


func _index(items: Array, label: String) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		var id: StringName = item.get("id")
		if id == &"":
			content_errors.append("%s entry missing id" % label)
			continue
		if result.has(id):
			content_errors.append("Duplicate %s id: %s" % [label, id])
			continue
		result[id] = item
	return result


func _validate_expected_counts() -> void:
	var expected := {
		"weapons": weapons.size(),
		"abilities": abilities.size(),
		"enemies": enemies.size(),
		"allies": allies.size(),
		"pets": pets.size(),
		"base_modules": base_modules.size(),
		"contracts": contracts.size(),
		"rift_mods": rift_mods.size(),
		"mutators": mutators.size(),
		"grenades": grenades.size(),
		"item_templates": item_templates.size(),
		"cosmetics": cosmetics.size(),
		"perks": perks.size(),
		"difficulties": difficulties.size(),
		"map_presets": map_presets.size(),
	}
	if expected["weapons"] != 10:
		content_errors.append("Expected 10 weapons, got %d" % expected["weapons"])
	if expected["abilities"] != 16:
		content_errors.append("Expected 16 abilities (12 active + 4 ultimates), got %d" % expected["abilities"])
	if expected["enemies"] != 23:
		content_errors.append("Expected 23 enemy entries (14 base + 6 elite + 3 boss), got %d" % expected["enemies"])
	if expected["allies"] != 4:
		content_errors.append("Expected 4 allies, got %d" % expected["allies"])
	if expected["pets"] != 3:
		content_errors.append("Expected 3 pets, got %d" % expected["pets"])
	if expected["base_modules"] != 8:
		content_errors.append("Expected 8 base modules, got %d" % expected["base_modules"])
	if expected["contracts"] != 6:
		content_errors.append("Expected 6 contracts, got %d" % expected["contracts"])
	if expected["rift_mods"] != 12:
		content_errors.append("Expected 12 rift mods, got %d" % expected["rift_mods"])
	if expected["mutators"] != 8:
		content_errors.append("Expected 8 mutators, got %d" % expected["mutators"])
	if expected["grenades"] != 3:
		content_errors.append("Expected 3 grenades, got %d" % expected["grenades"])
	if expected["perks"] != 16:
		content_errors.append("Expected 16 passive perks, got %d" % expected["perks"])
	if expected["difficulties"] != 4:
		content_errors.append("Expected 4 run difficulties, got %d" % expected["difficulties"])
	if expected["map_presets"] != 4:
		content_errors.append("Expected 4 map presets, got %d" % expected["map_presets"])
	for difficulty in difficulties.values():
		if not (difficulty is Dictionary):
			continue
		var preset_id := StringName(difficulty.get("map_preset", &""))
		if preset_id == &"" or not map_presets.has(preset_id):
			content_errors.append("Difficulty %s references unknown map preset '%s'" % [difficulty.get("id", "?"), preset_id])
	for error in content_errors:
		push_error("[ContentDB] " + error)


func get_weapon(id: StringName) -> WeaponData:
	return weapons.get(id) as WeaponData


func get_ability(id: StringName) -> AbilityData:
	return abilities.get(id) as AbilityData


func get_enemy(id: StringName) -> EnemyData:
	return enemies.get(id) as EnemyData


func get_ally(id: StringName) -> AllyData:
	return allies.get(id) as AllyData


func get_pet(id: StringName) -> PetData:
	return pets.get(id) as PetData


func get_base_module(id: StringName) -> BaseModuleData:
	return base_modules.get(id) as BaseModuleData


func get_contract(id: StringName) -> ContractData:
	return contracts.get(id) as ContractData


func get_rift_mod(id: StringName) -> RiftModData:
	return rift_mods.get(id) as RiftModData


func get_mutator(id: StringName) -> MutatorData:
	return mutators.get(id) as MutatorData


func get_grenade(id: StringName) -> GrenadeData:
	return grenades.get(id) as GrenadeData


func get_perk(id: StringName) -> PerkData:
	return perks.get(id) as PerkData


func get_item_template(id: StringName) -> ItemTemplate:
	return item_templates.get(id) as ItemTemplate


func get_cosmetic(id: StringName) -> CosmeticData:
	return cosmetics.get(id) as CosmeticData


func get_affix(id: StringName) -> Dictionary:
	return affixes.get(id, {})


func get_difficulty(id: StringName) -> Dictionary:
	return difficulties.get(id, {})


func get_map_preset(id: StringName) -> Dictionary:
	return map_presets.get(id, {})


func get_map_presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for preset in map_presets.values():
		if preset is Dictionary:
			out.append(preset)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("world_seed_salt", 0)) < int(b.get("world_seed_salt", 0))
	)
	return out


func get_difficulties() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for difficulty in difficulties.values():
		if difficulty is Dictionary:
			out.append(difficulty)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("threat", 1)) < int(b.get("threat", 1))
	)
	return out


func get_difficulty_for_threat(threat: int) -> Dictionary:
	var best: Dictionary = {}
	for difficulty in difficulties.values():
		if not (difficulty is Dictionary):
			continue
		if int(difficulty.get("threat", 1)) == clampi(threat, 1, 4):
			return difficulty
		if best.is_empty() or int(difficulty.get("threat", 1)) < int(best.get("threat", 1)):
			best = difficulty
	return best


func get_weapons_for_slot(slot: StringName) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for weapon in weapons.values():
		if weapon.slot == slot:
			out.append(weapon)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.display_name < b.display_name)
	return out


func get_contracts_for_threat(threat: int) -> Array[ContractData]:
	var out: Array[ContractData] = []
	for contract in contracts.values():
		if contract.required_threat <= threat:
			out.append(contract)
	out.sort_custom(func(a: ContractData, b: ContractData) -> bool: return a.required_threat < b.required_threat)
	return out


func get_starting_weapon_ids() -> Array[StringName]:
	## Primary 1 is the default sniper, primary 2 the reach workhorse and the
	## third entry backs the sidearm. Slot 4 (knife) is built into the player.
	return [&"sable_rail", &"lattice_ar", &"sidewinder"]


func get_starting_gear_ids() -> Array[StringName]:
	return [&"vanguard_helm", &"aegis_chest", &"engineer_legs", &"storm_cloak", &"core_charm"]


func get_affixes_for_slot(slot: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for affix in affixes.values():
		var slots: PackedStringArray = affix.get("slots", PackedStringArray())
		if String(slot) in slots:
			out.append(affix)
	return out


func get_all_enemies_of_faction(faction: StringName) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for enemy in enemies.values():
		if enemy.faction == faction and not enemy.elite:
			out.append(enemy)
	return out


func get_rarity_name(rarity: int) -> String:
	return StatKeys.RARITY_NAMES[clampi(rarity, 0, StatKeys.RARITY_NAMES.size() - 1)]


func get_rarity_color(rarity: int) -> Color:
	return StatKeys.RARITY_COLORS[clampi(rarity, 0, StatKeys.RARITY_COLORS.size() - 1)]


func get_rarity_mult(rarity: int) -> float:
	return StatKeys.RARITY_MULT[clampi(rarity, 0, StatKeys.RARITY_MULT.size() - 1)]


func get_disciplines() -> Array[StringName]:
	return [&"vanguard", &"infiltrator", &"engineer", &"pathfinder"]


func get_abilities_for_discipline(discipline: StringName, include_ultimates: bool = true) -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	for ability in abilities.values():
		if ability.is_ultimate and not include_ultimates:
			continue
		if ability.discipline == discipline or ability.discipline == &"shared":
			out.append(ability)
	out.sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.unlock_level < b.unlock_level)
	return out


func get_ultimate_for_discipline(discipline: StringName) -> AbilityData:
	for ability in abilities.values():
		if ability.is_ultimate and ability.discipline == discipline:
			return ability
	return null


func get_shared_abilities() -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	for ability in abilities.values():
		if ability.discipline == &"shared" and not ability.is_ultimate:
			out.append(ability)
	out.sort_custom(func(a: AbilityData, b: AbilityData) -> bool: return a.unlock_level < b.unlock_level)
	return out


func get_perks_for_discipline(discipline: StringName) -> Array[PerkData]:
	var out: Array[PerkData] = []
	for perk in perks.values():
		if perk.discipline == discipline:
			out.append(perk)
	out.sort_custom(func(a: PerkData, b: PerkData) -> bool: return a.tier < b.tier)
	return out


func get_enemy_roster_for_threat(threat: int) -> Array[EnemyData]:
	var roster: Array[EnemyData] = []
	for enemy in enemies.values():
		if enemy.boss:
			continue
		if enemy.elite and threat < 2:
			continue
		roster.append(enemy)
	return roster
