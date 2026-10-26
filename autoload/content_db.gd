extends Node
## Central, read-only content catalog. All gameplay/UI resolves authored data
## through this service by StringName id.

## Bundled glyph directory. Codex icon ids are adopted from world/vehicle specs
## only when the referenced glyph exists here (see _resolve_icon).
const ICON_DIR := "res://assets/icons/"

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
var items: Dictionary = {}
var loot_tables: Dictionary = {}
var poi_codex: Dictionary = {}
var rideable_codex: Dictionary = {}
var cosmetics: Dictionary = {}
var affixes: Dictionary = {}
var perks: Dictionary = {}
var difficulties: Dictionary = {}
var game_modes: Dictionary = {}
var world_events: Dictionary = {}
var map_presets: Dictionary = {}
var planets: Dictionary = {}
var weather: Dictionary = {}
var dungeon_themes: Dictionary = {}

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
	items = _index(data.items, "items")
	loot_tables = _index(data.loot_tables, "loot_tables")
	poi_codex = _index(data.poi_codex, "poi_codex")
	rideable_codex = _index(data.rideable_codex, "rideable_codex")
	cosmetics = _index(data.cosmetics, "cosmetics")
	perks = _index(data.perks, "perks")
	difficulties = _index(data.difficulties, "difficulties")
	game_modes = _index(data.game_modes, "game_modes")
	world_events = _index(data.world_events, "world_events")
	map_presets = _index(data.map_presets, "map_presets")
	planets = _index(data.planets, "planets")
	weather = _index(data.weather, "weather")
	dungeon_themes = _index(data.dungeon_themes, "dungeon_themes")
	for affix in data.affixes:
		var affix_id: StringName = affix.id
		if affixes.has(affix_id):
			content_errors.append("Duplicate affix id: %s" % affix_id)
		affixes[affix_id] = affix
	_enrich_codex_from_specs()
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


## Overlays live world/vehicle specs onto the authored Codex fallbacks. Both
## feature files belong to other streams and may be absent or mid-landing, so the
## probes are ResourceLoader.exists()-guarded (through LootTables) and a missing
## spec is a silent no-op. Counts never change here: specs only enrich the seven
## POI and five rideable records authored in ContentLibrary.
func _enrich_codex_from_specs() -> void:
	for poi_id in poi_codex.keys():
		var poi_entry: Dictionary = poi_codex[poi_id]
		var poi_spec := LootTables.poi_spec(StringName(poi_id))
		if not poi_spec.is_empty():
			_merge_poi_spec(poi_entry, poi_spec)
		var poi_table := LootTables.table_for_loot_tier(poi_entry.get("loot_tier", 1))
		poi_entry["loot_table"] = String(poi_table)
		poi_entry["loot_tier_label"] = _loot_table_label(poi_table)
	for ride_id in rideable_codex.keys():
		var ride_entry: Dictionary = rideable_codex[ride_id]
		var vehicle_spec := LootTables.vehicle_spec(StringName(ride_id))
		if not vehicle_spec.is_empty():
			_merge_vehicle_spec(ride_entry, vehicle_spec)
		ride_entry["stash_table"] = String(LootTables.VEHICLE_STASH)


func _merge_poi_spec(entry: Dictionary, spec: Dictionary) -> void:
	entry["source"] = "poi_specs"
	var title := _spec_text(spec, ["title", "display_name"])
	if not title.is_empty():
		entry["display_name"] = title
	var blurb := _spec_text(spec, ["blurb", "description"])
	if not blurb.is_empty():
		entry["blurb"] = blurb
	# Specs author their own icon vocabulary; keep the authored fallback when the
	# referenced glyph is not bundled so the Codex never renders a blank card.
	var icon := _spec_text(spec, ["codex_icon", "icon"])
	if not icon.is_empty():
		entry["icon"] = _resolve_icon(icon, entry.get("icon", &"cache"))
	for key in ["loot_tier", "radius", "pad", "interior", "garrison", "hazard", "biomes", "vehicle", "map_bias"]:
		if spec.has(key):
			entry[key] = spec[key]


func _merge_vehicle_spec(entry: Dictionary, spec: Dictionary) -> void:
	entry["source"] = "vehicle_specs"
	var title := _spec_text(spec, ["name", "display_name"])
	if not title.is_empty():
		entry["display_name"] = title
	var icon := _spec_text(spec, ["icon"])
	if not icon.is_empty():
		entry["icon"] = _resolve_icon(icon, entry.get("icon", &"cache"))
	for key in ["kind", "seats", "max_speed", "accel", "turn_rate", "health", "mass", "hud_color"]:
		if spec.has(key):
			entry[key] = spec[key]
	if spec.has("hud_color"):
		entry["color"] = spec["hud_color"]


## Uses a candidate icon id only when the bundled glyph exists, otherwise keeps
## the authored fallback. Keeps Codex data resilient against spec-first icon ids.
func _resolve_icon(candidate: String, fallback: Variant) -> StringName:
	var text := candidate.strip_edges()
	if not text.is_empty() and ResourceLoader.exists(ICON_DIR + text + ".svg"):
		return StringName(text)
	if fallback is String or fallback is StringName:
		var fallback_text := String(fallback).strip_edges()
		if not fallback_text.is_empty():
			return StringName(fallback_text)
	return &"cache"


func _spec_text(spec: Dictionary, keys: Array) -> String:
	for key in keys:
		var value: Variant = spec.get(key, "")
		if value is String or value is StringName:
			var text := String(value).strip_edges()
			if not text.is_empty():
				return text
	return ""


func _loot_table_label(table_id: StringName) -> String:
	match table_id:
		&"poi_rare":
			return "Rare"
		&"vehicle_stash":
			return "Vehicle"
		_:
			return "Common"


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
		"items": items.size(),
		"loot_tables": loot_tables.size(),
		"poi_codex": poi_codex.size(),
		"rideable_codex": rideable_codex.size(),
		"cosmetics": cosmetics.size(),
		"perks": perks.size(),
		"difficulties": difficulties.size(),
		"game_modes": game_modes.size(),
		"world_events": world_events.size(),
		"map_presets": map_presets.size(),
		"planets": planets.size(),
		"weather": weather.size(),
		"dungeon_themes": dungeon_themes.size(),
	}
	if expected["weapons"] != 16:
		content_errors.append("Expected 16 weapons, got %d" % expected["weapons"])
	if expected["abilities"] != 24:
		content_errors.append("Expected 24 abilities (20 active + 4 ultimates), got %d" % expected["abilities"])
	if expected["enemies"] != 37:
		content_errors.append("Expected 37 enemy entries (20 base + 11 elites + 6 bosses), got %d" % expected["enemies"])
	if expected["allies"] != 4:
		content_errors.append("Expected 4 allies, got %d" % expected["allies"])
	if expected["pets"] != 3:
		content_errors.append("Expected 3 pets, got %d" % expected["pets"])
	if expected["base_modules"] != 8:
		content_errors.append("Expected 8 base modules, got %d" % expected["base_modules"])
	if expected["contracts"] != 13:
		content_errors.append("Expected 13 contracts, got %d" % expected["contracts"])
	if expected["rift_mods"] != 12:
		content_errors.append("Expected 12 rift mods, got %d" % expected["rift_mods"])
	if expected["mutators"] != 8:
		content_errors.append("Expected 8 mutators, got %d" % expected["mutators"])
	if expected["grenades"] != 3:
		content_errors.append("Expected 3 grenades, got %d" % expected["grenades"])
	if expected["items"] != 10:
		content_errors.append("Expected 10 authored loot items, got %d" % expected["items"])
	if expected["loot_tables"] != 3:
		content_errors.append("Expected 3 loot tables, got %d" % expected["loot_tables"])
	if expected["poi_codex"] != 7:
		content_errors.append("Expected 7 POI codex entries, got %d" % expected["poi_codex"])
	if expected["rideable_codex"] != 5:
		content_errors.append("Expected 5 rideable codex entries, got %d" % expected["rideable_codex"])
	if expected["perks"] != 24:
		content_errors.append("Expected 24 passive perks, got %d" % expected["perks"])
	if expected["difficulties"] != 4:
		content_errors.append("Expected 4 run difficulties, got %d" % expected["difficulties"])
	if expected["game_modes"] != 5:
		content_errors.append("Expected 5 game modes, got %d" % expected["game_modes"])
	if expected["world_events"] != 20:
		content_errors.append("Expected 20 world events, got %d" % expected["world_events"])
	if expected["map_presets"] != 12:
		content_errors.append("Expected 12 map presets, got %d" % expected["map_presets"])
	if expected["planets"] != 5:
		content_errors.append("Expected 5 planets, got %d" % expected["planets"])
	if expected["weather"] != 18:
		content_errors.append("Expected 18 weather states, got %d" % expected["weather"])
	if expected["dungeon_themes"] != 3:
		content_errors.append("Expected 3 dungeon themes, got %d" % expected["dungeon_themes"])
	var base_enemies := 0
	var elite_enemies := 0
	var boss_enemies := 0
	for enemy in enemies.values():
		if enemy.boss:
			boss_enemies += 1
		elif enemy.elite:
			elite_enemies += 1
		else:
			base_enemies += 1
	if base_enemies != 20 or elite_enemies != 11 or boss_enemies != 6:
		content_errors.append(
			"Expected enemy mix 20 base / 11 elite / 6 boss, got %d / %d / %d" % [base_enemies, elite_enemies, boss_enemies]
		)
	for difficulty in difficulties.values():
		if not (difficulty is Dictionary):
			continue
		var preset_id := StringName(difficulty.get("map_preset", &""))
		if preset_id == &"" or not map_presets.has(preset_id):
			content_errors.append("Difficulty %s references unknown map preset '%s'" % [difficulty.get("id", "?"), preset_id])
	for preset_id in map_presets.keys():
		var preset: Dictionary = map_presets[preset_id]
		var planet_id := StringName(preset.get("planet_id", &""))
		if planet_id == &"" or not planets.has(planet_id):
			content_errors.append("Map preset %s references unknown planet '%s'" % [preset_id, planet_id])
		if int(preset.get("biome_index", 0)) < 0 or int(preset.get("biome_index", 0)) > 2:
			content_errors.append("Map preset %s has biome_index outside 0..2" % preset_id)
		for weather_id in preset.get("weather_pool", []):
			if not weather.has(StringName(weather_id)):
				content_errors.append("Map preset %s references unknown weather '%s'" % [preset_id, weather_id])
	for planet_id in planets.keys():
		var planet: Dictionary = planets[planet_id]
		for weather_id in planet.get("weather_pool", []):
			if not weather.has(StringName(weather_id)):
				content_errors.append("Planet %s references unknown weather '%s'" % [planet_id, weather_id])
		for theme_id in planet.get("dungeon_themes", []):
			if not dungeon_themes.has(StringName(theme_id)):
				content_errors.append("Planet %s references unknown dungeon theme '%s'" % [planet_id, theme_id])
		if (planet.get("biome_names", []) as Array).size() != 3:
			content_errors.append("Planet %s must author exactly 3 biome names" % planet_id)
	for theme_id in dungeon_themes.keys():
		var theme: Dictionary = dungeon_themes[theme_id]
		var boss_id := StringName(theme.get("boss_id", &""))
		if boss_id == &"" or not enemies.has(boss_id):
			content_errors.append("Dungeon theme %s references unknown boss '%s'" % [theme_id, boss_id])
		for pool_key in ["enemy_pool", "elite_pool"]:
			for enemy_id in theme.get(pool_key, []):
				if not enemies.has(StringName(enemy_id)):
					content_errors.append("Dungeon theme %s references unknown enemy '%s'" % [theme_id, enemy_id])
	var valid_stage_types: Array[StringName] = [
		&"cache", &"relay", &"hunt", &"survey", &"rescue", &"vault", &"dungeon", &"dungeon_boss"
	]
	for contract in contracts.values():
		if not (contract is ContractData):
			continue
		if String(contract.icon).is_empty():
			content_errors.append("Contract %s is missing an icon" % contract.id)
		if contract.stages.is_empty():
			continue
		for stage in contract.stages:
			if not (stage is Dictionary):
				content_errors.append("Contract %s has a non-dictionary stage" % contract.id)
				continue
			var stage_type := StringName(stage.get("type", &""))
			if not (stage_type in valid_stage_types):
				content_errors.append("Contract %s has unknown stage type '%s'" % [contract.id, stage_type])
			if int(stage.get("count", 0)) < 1:
				content_errors.append("Contract %s stage '%s' has count < 1" % [contract.id, stage_type])
	var selectable_modes := 0
	for mode_id in game_modes.keys():
		var mode: Dictionary = game_modes[mode_id]
		for field in [
			"display_name", "clock", "tag", "description", "icon", "color",
			"run_duration", "time_scale", "density_mult", "elite_bonus", "reward_mult",
			"max_hostiles_delta", "loot_bonus",
		]:
			if not mode.has(field):
				content_errors.append("Game mode %s is missing field '%s'" % [mode_id, field])
		if float(mode.get("run_duration", 0.0)) <= 0.0:
			content_errors.append("Game mode %s must author a positive run_duration" % mode_id)
		if float(mode.get("time_scale", 0.0)) <= 0.0:
			content_errors.append("Game mode %s must author a positive time_scale" % mode_id)
		if mode.has("start_time"):
			var start_time := float(mode.get("start_time", 0.0))
			if start_time < 0.0 or start_time > 0.999:
				content_errors.append("Game mode %s has start_time outside 0..0.999" % mode_id)
		if mode.has("storm_fraction"):
			var storm_fraction := float(mode.get("storm_fraction", 0.0))
			if storm_fraction <= 0.0 or storm_fraction > 1.0:
				content_errors.append("Game mode %s has storm_fraction outside 0..1" % mode_id)
		if bool(mode.get("selectable", false)):
			selectable_modes += 1
	if selectable_modes != 5:
		content_errors.append("Expected 5 selectable game modes, got %d" % selectable_modes)
	for event_id in world_events.keys():
		var event: Dictionary = world_events[event_id]
		for field in ["title", "text", "icon", "color", "weight"]:
			if not event.has(field):
				content_errors.append("World event %s is missing field '%s'" % [event_id, field])
		if String(event.get("title", "")).strip_edges().is_empty():
			content_errors.append("World event %s has an empty title" % event_id)
		if String(event.get("text", "")).strip_edges().is_empty():
			content_errors.append("World event %s has an empty text" % event_id)
		if StringName(event.get("icon", &"")) == &"":
			content_errors.append("World event %s has an empty icon" % event_id)
		if float(event.get("weight", 0.0)) <= 0.0:
			content_errors.append("World event %s must author a positive weight" % event_id)
	_validate_loot_items()
	_validate_loot_tables()
	_validate_codex()
	for error in content_errors:
		push_error("[ContentDB] " + error)


## Authored loot cargo must be fully described and reachable from at least one
## table; an orphaned item would be invisible content.
func _validate_loot_items() -> void:
	var referenced: Dictionary = {}
	for table_value in loot_tables.values():
		if not (table_value is Dictionary):
			continue
		for entry in (table_value as Dictionary).get("entries", []):
			if not (entry is Dictionary):
				continue
			var kind := StringName((entry as Dictionary).get("kind", &"loot"))
			if kind == &"loot":
				referenced[StringName((entry as Dictionary).get("id", &""))] = true
	for item_id in items.keys():
		var item_value: Variant = items[item_id]
		if not (item_value is LootItemData):
			content_errors.append("Loot item %s is not a LootItemData resource" % item_id)
			continue
		var loot := item_value as LootItemData
		if loot.display_name.strip_edges().is_empty():
			content_errors.append("Loot item %s is missing a display name" % item_id)
		if loot.description.strip_edges().is_empty():
			content_errors.append("Loot item %s is missing a tooltip blurb" % item_id)
		if String(loot.icon).strip_edges().is_empty():
			content_errors.append("Loot item %s is missing an icon" % item_id)
		if loot.rarity < 0 or loot.rarity > 4:
			content_errors.append("Loot item %s has rarity outside 0..4" % item_id)
		if loot.value <= 0:
			content_errors.append("Loot item %s must author a positive value" % item_id)
		if loot.stack_max < 1:
			content_errors.append("Loot item %s must author a stack_max >= 1" % item_id)
		if loot.get_rarity_mult() <= 0.0:
			content_errors.append("Loot item %s has a non-positive rarity multiplier" % item_id)
		if not referenced.has(item_id):
			content_errors.append("Loot item %s is not referenced by any loot table" % item_id)


## Every weighted entry must resolve to a real catalog id, so a rolled cache can
## never hand back an empty item.
func _validate_loot_tables() -> void:
	for table_id in loot_tables.keys():
		var table_value: Variant = loot_tables[table_id]
		if not (table_value is Dictionary):
			content_errors.append("Loot table %s is not a dictionary" % table_id)
			continue
		var table := table_value as Dictionary
		for field in ["display_name", "label", "prompt", "entries", "salvage", "rarity_floor"]:
			if not table.has(field):
				content_errors.append("Loot table %s is missing field '%s'" % [table_id, field])
		if String(table.get("display_name", "")).strip_edges().is_empty():
			content_errors.append("Loot table %s is missing a display name" % table_id)
		var entries: Array = table.get("entries", [])
		if entries.size() < 3:
			content_errors.append("Loot table %s needs at least 3 weighted entries" % table_id)
		var total_weight := 0.0
		for entry_value in entries:
			if not (entry_value is Dictionary):
				content_errors.append("Loot table %s has a non-dictionary entry" % table_id)
				continue
			var entry := entry_value as Dictionary
			var entry_id := StringName(entry.get("id", &""))
			if entry_id == &"":
				content_errors.append("Loot table %s has an entry without an id" % table_id)
				continue
			var weight := float(entry.get("weight", 0.0))
			if weight <= 0.0:
				content_errors.append("Loot table %s entry %s must author a positive weight" % [table_id, entry_id])
				continue
			total_weight += weight
			match StringName(entry.get("kind", &"loot")):
				&"loot":
					if not items.has(entry_id):
						content_errors.append("Loot table %s references unknown loot item '%s'" % [table_id, entry_id])
				&"gear":
					if not item_templates.has(entry_id):
						content_errors.append("Loot table %s references unknown gear template '%s'" % [table_id, entry_id])
				&"weapon":
					if not weapons.has(entry_id):
						content_errors.append("Loot table %s references unknown weapon '%s'" % [table_id, entry_id])
				_:
					content_errors.append("Loot table %s entry %s has an unknown kind" % [table_id, entry_id])
		if total_weight <= 0.0:
			content_errors.append("Loot table %s has no positive entry weights" % table_id)
		var salvage_band: Array = table.get("salvage", [])
		if salvage_band.size() != 2 or int(salvage_band[0]) <= 0 or int(salvage_band[1]) < int(salvage_band[0]):
			content_errors.append("Loot table %s must author a valid [min, max] salvage band" % table_id)
		var rarity_floor := int(table.get("rarity_floor", 0))
		if rarity_floor < 0 or rarity_floor > 4:
			content_errors.append("Loot table %s has rarity_floor outside 0..4" % table_id)
		var cores_chance := float(table.get("cores_chance", 0.0))
		if cores_chance < 0.0 or cores_chance > 1.0:
			content_errors.append("Loot table %s has cores_chance outside 0..1" % table_id)


## Codex records are presentation data, but they must stay resolvable: an entry
## with a missing blurb/icon/loot table would render a broken card in-game.
func _validate_codex() -> void:
	for poi_id in poi_codex.keys():
		var poi_value: Variant = poi_codex[poi_id]
		if not (poi_value is Dictionary):
			content_errors.append("POI codex entry %s is not a dictionary" % poi_id)
			continue
		var poi_entry := poi_value as Dictionary
		if String(poi_entry.get("display_name", "")).strip_edges().is_empty():
			content_errors.append("POI codex entry %s is missing a display name" % poi_id)
		if String(poi_entry.get("blurb", "")).strip_edges().is_empty():
			content_errors.append("POI codex entry %s is missing a blurb" % poi_id)
		if String(poi_entry.get("icon", "")).strip_edges().is_empty():
			content_errors.append("POI codex entry %s is missing an icon" % poi_id)
		var poi_table := StringName(poi_entry.get("loot_table", &""))
		if poi_table == &"" or not loot_tables.has(poi_table):
			content_errors.append("POI codex entry %s references unknown loot table '%s'" % [poi_id, poi_table])
	for ride_id in rideable_codex.keys():
		var ride_value: Variant = rideable_codex[ride_id]
		if not (ride_value is Dictionary):
			content_errors.append("Rideable codex entry %s is not a dictionary" % ride_id)
			continue
		var ride_entry := ride_value as Dictionary
		if String(ride_entry.get("display_name", "")).strip_edges().is_empty():
			content_errors.append("Rideable codex entry %s is missing a display name" % ride_id)
		if String(ride_entry.get("blurb", "")).strip_edges().is_empty():
			content_errors.append("Rideable codex entry %s is missing a blurb" % ride_id)
		if String(ride_entry.get("icon", "")).strip_edges().is_empty():
			content_errors.append("Rideable codex entry %s is missing an icon" % ride_id)
		if String(ride_entry.get("kind", "")).strip_edges().is_empty():
			content_errors.append("Rideable codex entry %s is missing a kind" % ride_id)
		var stash_table := StringName(ride_entry.get("stash_table", &""))
		if stash_table == &"" or not loot_tables.has(stash_table):
			content_errors.append("Rideable codex entry %s references unknown stash table '%s'" % [ride_id, stash_table])


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


## Authored loot cargo (never equippable). Returns null for unknown ids so callers
## can fail soft; ItemFactory.describe() also accepts the raw item dictionaries.
func get_item(id: StringName) -> LootItemData:
	return items.get(id) as LootItemData


func get_items() -> Array[LootItemData]:
	var out: Array[LootItemData] = []
	for item_value in items.values():
		if item_value is LootItemData:
			out.append(item_value as LootItemData)
	out.sort_custom(func(a: LootItemData, b: LootItemData) -> bool:
		if a.rarity == b.rarity:
			return a.display_name < b.display_name
		return a.rarity < b.rarity
	)
	return out


## Authored loot table by id ({} when absent). The returned dictionary is a copy:
## callers may mutate their payload but never the catalog.
func get_loot_table(id: StringName) -> Dictionary:
	var table_value: Variant = loot_tables.get(id, null)
	if table_value is Dictionary:
		return (table_value as Dictionary).duplicate(true)
	return {}


func get_loot_table_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for table_id in loot_tables.keys():
		out.append(StringName(table_id))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func get_loot_tables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for table_id in get_loot_table_ids():
		var table := get_loot_table(table_id)
		if not table.is_empty():
			out.append(table)
	return out


## Rolls one weighted entry from a table id into an item dictionary. Deterministic
## for a given RNG state; returns {} when the table is unknown.
func roll_loot_table(
	rng: RandomNumberGenerator,
	table_id: StringName,
	luck: float = 0.0,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	return LootTables.roll_item(rng, table_id, luck, level, uid)


## Resolves the loot table a POI type should roll (POISpecs loot_tier first,
## authored Codex tier second, poi_common fallback).
func get_loot_table_for_poi(poi_type: StringName) -> StringName:
	return LootTables.table_for_poi(poi_type)


func get_loot_table_for_poi_dict(poi: Dictionary) -> StringName:
	return LootTables.table_for_poi_dict(poi)


## Builds a LootCache-compatible payload for a table id. Deployment owns spawn
## placement; this owns the payload so the loot curve stays next to the tables.
func build_loot_cache_payload(
	rng: RandomNumberGenerator,
	table_id: StringName,
	threat: int = 1,
	luck: float = 0.0,
	uid: int = 0
) -> Dictionary:
	return LootTables.build_cache_payload(rng, table_id, threat, luck, uid)


## Codex record for a POI type. Spec-enriched at boot when poi_specs.gd exists.
func get_poi_codex(id: StringName) -> Dictionary:
	var entry: Variant = poi_codex.get(id, null)
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func get_poi_codex_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for poi_id in poi_codex.keys():
		var entry := get_poi_codex(StringName(poi_id))
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	return out


## Codex record for a rideable archetype, enriched with the live vehicle spec.
func get_rideable_codex(id: StringName) -> Dictionary:
	var entry: Variant = rideable_codex.get(id, null)
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func get_rideable_codex_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ride_id in rideable_codex.keys():
		var entry := get_rideable_codex(StringName(ride_id))
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	return out


## Loot item ids that a given table can roll (loot entries only, not gear/weapons).
func get_loot_table_item_ids(table_id: StringName) -> Array[StringName]:
	var table := get_loot_table(table_id)
	var out: Array[StringName] = []
	for entry in table.get("entries", []):
		if not (entry is Dictionary):
			continue
		if StringName((entry as Dictionary).get("kind", &"loot")) != &"loot":
			continue
		out.append(StringName((entry as Dictionary).get("id", &"")))
	return out


func get_cosmetic(id: StringName) -> CosmeticData:
	return cosmetics.get(id) as CosmeticData


func get_affix(id: StringName) -> Dictionary:
	return affixes.get(id, {})


func get_difficulty(id: StringName) -> Dictionary:
	return difficulties.get(id, {})


## Returns the authored map preset enriched with its planet, weather definitions
## and merged fluid configuration. WorldBuilder consumes this dictionary directly
## (it must stay autoload-free), so the world receives all of its data in one call.
## `weather_defs` always carries every authored weather definition so a forced
## weather event can resolve on any map; the map/planet pool stays in
## `weather_pool`.
func get_map_preset(id: StringName) -> Dictionary:
	var preset: Dictionary = map_presets.get(id, {})
	if preset.is_empty():
		return {}
	var out: Dictionary = preset.duplicate(true)
	var planet_id := StringName(out.get("planet_id", &""))
	var planet := get_planet(planet_id)
	if not planet.is_empty():
		out["planet"] = planet.duplicate(true)
	var pool: Array = out.get("weather_pool", [])
	if pool.is_empty() and not planet.is_empty():
		pool = (planet.get("weather_pool", []) as Array).duplicate()
	out["weather_pool"] = pool.duplicate()
	out["weather_defs"] = get_all_weather_defs()
	var fluid: Dictionary = {}
	if not planet.is_empty() and planet.get("fluid", {}) is Dictionary:
		fluid = (planet.get("fluid", {}) as Dictionary).duplicate(true)
	var fluid_override = out.get("fluid", {})
	if fluid_override is Dictionary:
		for key in (fluid_override as Dictionary).keys():
			fluid[key] = (fluid_override as Dictionary)[key]
	out["fluid"] = fluid
	return out


func get_map_presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for preset in map_presets.values():
		if preset is Dictionary:
			out.append(preset)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("world_seed_salt", 0)) < int(b.get("world_seed_salt", 0))
	)
	return out


func get_map_presets_for_planet(planet_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for preset in get_map_presets():
		if StringName(preset.get("planet_id", &"")) == planet_id:
			out.append(preset)
	return out


func get_default_map_for_difficulty(difficulty_id: StringName) -> StringName:
	var difficulty := get_difficulty(difficulty_id)
	var preset_id := StringName(difficulty.get("map_preset", &""))
	if preset_id != &"" and map_presets.has(preset_id):
		return preset_id
	var presets := get_map_presets()
	return StringName(presets[0].get("id", &"verdant_verge")) if not presets.is_empty() else &"verdant_verge"


func get_planet(id: StringName) -> Dictionary:
	return planets.get(id, {})


func get_planets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for planet in planets.values():
		if planet is Dictionary:
			out.append(planet)
	return out


func get_planet_for_map(map_id: StringName) -> Dictionary:
	var preset := get_map_preset(map_id)
	return get_planet(StringName(preset.get("planet_id", &"")))


func get_weather_def(id: StringName) -> Dictionary:
	return weather.get(id, {})


func get_all_weather_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for weather_def in weather.values():
		if weather_def is Dictionary:
			out.append((weather_def as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	return out


func get_world_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in world_events.values():
		if event is Dictionary:
			out.append((event as Dictionary).duplicate(true))
	return out


func get_world_event(id: StringName) -> Dictionary:
	return world_events.get(id, {})


func get_game_modes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mode in game_modes.values():
		if mode is Dictionary:
			out.append(mode)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	return out


func get_game_mode(id: StringName) -> Dictionary:
	return game_modes.get(id, {})


func get_mode_clock(id: StringName) -> String:
	var mode := get_game_mode(id)
	return String(mode.get("clock", ""))


func get_selectable_game_mode_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for mode in get_game_modes():
		if bool(mode.get("selectable", false)):
			out.append(StringName(mode.get("id", &"")))
	return out


func get_weather_defs_for_pool(pool: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for weather_id in pool:
		var data: Dictionary = weather.get(StringName(weather_id), {})
		if not data.is_empty():
			out.append(data.duplicate(true))
	return out


func get_dungeon_theme(id: StringName) -> Dictionary:
	return dungeon_themes.get(id, {})


func get_dungeon_themes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for theme in dungeon_themes.values():
		if theme is Dictionary:
			out.append(theme)
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


func get_elite_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for enemy in enemies.values():
		if enemy.elite and not enemy.boss:
			out.append(enemy)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.display_name < b.display_name)
	return out


func get_boss_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for enemy in enemies.values():
		if enemy.boss:
			out.append(enemy)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.display_name < b.display_name)
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
