class_name LootTables
extends RefCounted
## Weighted loot-table roller and POI loot-tier resolver.
##
## Table data is authored in ContentLibrary._loot_tables() and indexed by ContentDB
## (ids: poi_common, poi_rare, vehicle_stash). This class is stateless: pass in a
## seeded RandomNumberGenerator and the result is deterministic, which is what the
## seeded run economy and the headless tests rely on.
##
## Entry kinds:
##   loot   (default) -> ItemFactory.generate_loot_item(), authored rarity/stack
##   gear            -> ItemFactory.generate_gear(), rolled rarity
##   weapon          -> ItemFactory.generate_weapon(), rolled rarity
##
## POISpecs integration is intentionally duck-typed through ResourceLoader.exists()
## so this file parses and runs before features/world/poi_specs.gd (owned by the
## world stream) lands. Missing specs fall back to the authored Codex records and
## finally to poi_common — a POI never rolls nothing because a spec file is absent.

const POI_COMMON: StringName = &"poi_common"
const POI_RARE: StringName = &"poi_rare"
const VEHICLE_STASH: StringName = &"vehicle_stash"
const TABLE_IDS: Array[StringName] = [POI_COMMON, POI_RARE, VEHICLE_STASH]

const POI_SPECS_PATH := "res://features/world/poi_specs.gd"
## Data-catalog scripts probed for rideable specs (preferred: pure data).
const VEHICLE_SPEC_PATHS: Array[String] = [
	"res://features/vehicles/vehicle_specs.gd",
	"res://features/vehicles/vehicle_catalog.gd",
]
## Fallback archetype scripts. get_vehicle_spec() lazily builds a pure dictionary
## (no tree, no mesh, no physics step) so reading one during boot is cheap; the
## instance is freed immediately afterwards.
const VEHICLE_ARCHETYPE_PATHS: Dictionary = {
	&"rig": "res://features/vehicles/ground_car.gd",
	&"hoverbike": "res://features/vehicles/hover_bike.gd",
	&"airplane": "res://features/vehicles/airplane.gd",
	&"spaceship": "res://features/vehicles/spaceship.gd",
	&"horse": "res://features/vehicles/horse.gd",
}


static func table_ids() -> Array[StringName]:
	return TABLE_IDS.duplicate()


static func has_table(table_id: StringName) -> bool:
	return not get_table(table_id).is_empty()


## Returns the authored table dictionary, or {} when ContentDB/table are absent.
static func get_table(table_id: StringName) -> Dictionary:
	var db := _content_db()
	if db == null:
		return {}
	var tables_value: Variant = db.get("loot_tables")
	if not (tables_value is Dictionary):
		return {}
	var table_value: Variant = (tables_value as Dictionary).get(StringName(table_id), null)
	if table_value is Dictionary:
		return table_value as Dictionary
	return {}


# ---------------------------------------------------------------------------
# Rolling
# ---------------------------------------------------------------------------

## Rolls one weighted entry and materialises it into the save-format item dict.
## Returns {} when the table is unknown or empty. `luck` only raises generated
## gear/weapon rarity; authored loot items keep their fixed tier.
static func roll_item(
	rng: RandomNumberGenerator,
	table_id: StringName,
	luck: float = 0.0,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	var table := get_table(table_id)
	if table.is_empty():
		return {}
	var entry := _pick_entry(rng, table)
	if entry.is_empty():
		return {}
	return _materialize(rng, entry, table, luck, level, uid)


## Convenience wrapper: rolls the table that a POI type's loot_tier selects.
static func roll_item_for_poi(
	rng: RandomNumberGenerator,
	poi_type: StringName,
	luck: float = 0.0,
	level: int = 1,
	uid: int = 0
) -> Dictionary:
	return roll_item(rng, table_for_poi(poi_type), luck, level, uid)


## Builds a LootCache-compatible payload (salvage/cores/item/label/prompt) for a
## table id. Deployment keeps owning *when* caches spawn; this owns *what* they
## contain, so the damage/loot scaling curve lives next to the tables.
static func build_cache_payload(
	rng: RandomNumberGenerator,
	table_id: StringName,
	threat: int = 1,
	luck: float = 0.0,
	uid: int = 0
) -> Dictionary:
	var table := get_table(table_id)
	if table.is_empty():
		return _fallback_payload(table_id, threat)
	var level := 1 + maxi(0, threat) * 2
	var item := roll_item(rng, table_id, luck, level, uid)
	var salvage_band: Array = table.get("salvage", [20, 40])
	var salvage_min := 20.0
	var salvage_max := 40.0
	if salvage_band.size() >= 2:
		salvage_min = float(salvage_band[0])
		salvage_max = maxf(salvage_min, float(salvage_band[1]))
	var salvage := int(round(rng.randf_range(salvage_min, salvage_max) * (1.0 + 0.12 * float(maxi(0, threat)))))
	var cores := 0
	if rng.randf() < clampf(float(table.get("cores_chance", 0.1)) + luck, 0.0, 0.9):
		cores = 1
	var rarity := 0
	var label := String(table.get("label", "Salvage"))
	var item_label := ""
	if not item.is_empty():
		var info := ItemFactory.describe(item)
		rarity = int(info.get("rarity", 0))
		item_label = String(info.get("display_name", "Cargo"))
		label = ("%s %s" % [String(info.get("rarity_name", "")), item_label]).strip_edges()
	return {
		"salvage": maxi(1, salvage),
		"cores": cores,
		"item": item,
		"rarity": rarity,
		"label": label,
		"item_label": item_label,
		"prompt": String(table.get("prompt", "Collect %s  [E]" % label)),
		"threat": threat,
		"boss": false,
		"loot_table": String(table_id),
	}


static func build_cache_payload_for_poi(
	rng: RandomNumberGenerator,
	poi_type: StringName,
	threat: int = 1,
	luck: float = 0.0,
	uid: int = 0
) -> Dictionary:
	return build_cache_payload(rng, table_for_poi(poi_type), threat, luck, uid)


static func _pick_entry(rng: RandomNumberGenerator, table: Dictionary) -> Dictionary:
	var entries: Array = table.get("entries", [])
	var total := 0.0
	for entry in entries:
		if entry is Dictionary:
			total += maxf(0.0, float((entry as Dictionary).get("weight", 0.0)))
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var weight := maxf(0.0, float((entry as Dictionary).get("weight", 0.0)))
		roll -= weight
		if roll <= 0.0:
			return entry as Dictionary
	# Float drift can leave a sliver on the last entry.
	for index in range(entries.size() - 1, -1, -1):
		if entries[index] is Dictionary:
			return entries[index] as Dictionary
	return {}


static func _materialize(
	rng: RandomNumberGenerator,
	entry: Dictionary,
	table: Dictionary,
	luck: float,
	level: int,
	uid: int
) -> Dictionary:
	var entry_id := StringName(entry.get("id", &""))
	if entry_id == &"":
		return {}
	var kind := StringName(entry.get("kind", &"loot"))
	if kind == &"weapon":
		return ItemFactory.generate_weapon(rng, entry_id, _roll_rarity(rng, entry, table, luck), level, uid)
	if kind == &"gear":
		return ItemFactory.generate_gear(rng, entry_id, _roll_rarity(rng, entry, table, luck), level, uid)
	return ItemFactory.generate_loot_item(entry_id, uid, _roll_amount(rng, entry))


static func _roll_rarity(
	rng: RandomNumberGenerator,
	entry: Dictionary,
	table: Dictionary,
	luck: float
) -> int:
	var floor_rarity := maxi(
		clampi(int(table.get("rarity_floor", 0)), 0, 4),
		clampi(int(entry.get("rarity", 0)), 0, 4)
	)
	return ItemFactory.roll_rarity(rng, luck, floor_rarity)


static func _roll_amount(rng: RandomNumberGenerator, entry: Dictionary) -> int:
	var band: Variant = entry.get("amount", null)
	if band is Array:
		var values := band as Array
		if values.size() >= 2:
			var low := maxi(1, int(values[0]))
			var high := maxi(low, int(values[1]))
			return rng.randi_range(low, high)
		if values.size() == 1:
			return maxi(1, int(values[0]))
	return 1


static func _fallback_payload(table_id: StringName, threat: int) -> Dictionary:
	return {
		"salvage": 20 + maxi(0, threat) * 8,
		"cores": 0,
		"item": {},
		"rarity": 0,
		"label": "Salvage",
		"item_label": "",
		"prompt": "Collect salvage  [E]",
		"threat": threat,
		"boss": false,
		"loot_table": String(table_id),
	}


# ---------------------------------------------------------------------------
# POI loot_tier -> table resolution
# ---------------------------------------------------------------------------

## Maps an authored loot_tier onto one of the three tables. Accepts both the
## string form ("common"/"rare"/"vehicle") and the numeric 0..4 form used by
## POISpecs ("0 none .. 4 elite loot budget"): 3-4 roll poi_rare, 0-2 poi_common.
## vehicle_stash is only ever selected explicitly (it belongs to rideable stashes,
## not POI interiors), so a POI tier can never accidentally roll vehicle cargo.
static func table_for_loot_tier(tier: Variant) -> StringName:
	if tier is String or tier is StringName:
		match String(tier).strip_edges().to_lower():
			"rare", "rich", "high", "epic", "prototype", "3", "4":
				return POI_RARE
			"vehicle", "vehicle_stash", "stash", "rideable":
				return VEHICLE_STASH
			_:
				return POI_COMMON
	if tier is int or tier is float:
		return POI_RARE if int(tier) >= 3 else POI_COMMON
	return POI_COMMON


## Resolves the table a POI type should roll. Order of authority:
## POISpecs.get_spec(type).loot_tier -> authored Codex loot_tier -> poi_common.
static func table_for_poi(poi_type: StringName) -> StringName:
	if poi_type == &"":
		return POI_COMMON
	var tier: Variant = get_poi_loot_tier(poi_type)
	if tier == null:
		return POI_COMMON
	return table_for_loot_tier(tier)


## Same resolution for a world dictionary. World loot anchors carry `poi_type`
## (WorldBuilder.get_loot_props), world POIs carry `type`; an explicit
## `loot_table`/`loot_tier` on the dictionary always wins.
static func table_for_poi_dict(poi: Dictionary) -> StringName:
	if poi.is_empty():
		return POI_COMMON
	var explicit_table := StringName(poi.get("loot_table", &""))
	if has_table(explicit_table):
		return explicit_table
	if poi.has("loot_tier"):
		return table_for_loot_tier(poi.get("loot_tier"))
	var poi_type := StringName(poi.get("poi_type", poi.get("type", &"")))
	return table_for_poi(poi_type)


static func get_poi_loot_tier(poi_type: StringName) -> Variant:
	var spec := poi_spec(poi_type)
	if not spec.is_empty() and spec.has("loot_tier"):
		return spec.get("loot_tier")
	var db := _content_db()
	if db != null and db.has_method("get_poi_codex"):
		var entry: Variant = db.call("get_poi_codex", poi_type)
		if entry is Dictionary and (entry as Dictionary).has("loot_tier"):
			return (entry as Dictionary).get("loot_tier")
	return null


# ---------------------------------------------------------------------------
# Optional spec probing (guarded so parallel streams can land in any order)
# ---------------------------------------------------------------------------

## Live POI spec for a type, or {} when poi_specs.gd is absent/unreadable.
static func poi_spec(poi_type: StringName) -> Dictionary:
	var source := _instantiate_spec_source(POI_SPECS_PATH)
	if source == null:
		return {}
	return _spec_for_id(source, poi_type)


## Live rideable spec for a vehicle id, or {} when no vehicle catalog is present.
## Order: dedicated data catalog -> the archetype script's get_vehicle_spec().
static func vehicle_spec(vehicle_id: StringName) -> Dictionary:
	for path in VEHICLE_SPEC_PATHS:
		var source := _instantiate_spec_source(path)
		if source == null:
			continue
		var spec := _spec_for_id(source, vehicle_id)
		if not spec.is_empty():
			return spec
	return _spec_from_archetype(vehicle_id)


static func _spec_from_archetype(vehicle_id: StringName) -> Dictionary:
	var path := String(VEHICLE_ARCHETYPE_PATHS.get(vehicle_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return {}
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return {}
	var instance = script.new()
	if instance == null:
		return {}
	var spec: Dictionary = {}
	if instance.has_method("get_vehicle_spec"):
		var raw: Variant = instance.call("get_vehicle_spec")
		if raw is Dictionary:
			spec = raw as Dictionary
	# Rideables are Nodes; release the probe instance so boot leaves no orphans.
	if instance is Node:
		(instance as Node).free()
	return spec


static func _instantiate_spec_source(path: String) -> Object:
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return null
	var instance = script.new()
	if instance == null:
		return null
	# Only accept objects exposing one of the agreed catalog entry points.
	if instance.has_method("get_spec") or instance.has_method("all"):
		return instance
	return null


static func _spec_for_id(source: Object, id: StringName) -> Dictionary:
	if source.has_method("get_spec"):
		var raw: Variant = source.call("get_spec", id)
		if raw is Dictionary and not (raw as Dictionary).is_empty():
			return raw as Dictionary
	if source.has_method("all"):
		var raw_all: Variant = source.call("all")
		if raw_all is Array:
			for item in raw_all:
				if not (item is Dictionary):
					continue
				var entry := item as Dictionary
				var raw_id: Variant = entry.get("id", entry.get("vehicle_id", entry.get("type", &"")))
				if raw_id is String or raw_id is StringName:
					if StringName(raw_id) == id:
						return entry
	return {}


static func _content_db() -> Node:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/ContentDB")
