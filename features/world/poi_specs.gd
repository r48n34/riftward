class_name POISpecs
extends RefCounted
## POI SPECS ??pure-data catalogue for every procedural point of interest.
##
## Static data + static functions only: no scene tree, no nodes, no random
## state. Safe to call from worker threads and from tests. Consumers
## (deployment / loot / vehicles / codex / map UI) read the table instead of
## hard-coding kit names.
##
## Fields per spec:
##   id          StringName  ??kit type id, matches WorldBuilder.POI_LAYOUT.type
##   title       String      ??display name
##   blurb       String      ??one-line codex blurb
##   radius      float       ??POI footprint radius (m); mirrors POI_LAYOUT
##   pad         float       ??flattened combat pad radius (m); mirrors POI_LAYOUT
##   interior    bool        ??exposes enterable interior spawn markers
##   loot_tier   int         ??0 none .. 4 elite loot budget
##   garrison    int         ??authored hostile garrison size
##   hazard      StringName  ??environmental hazard identity (see HAZARDS)
##   biomes      Array[int]  ??preferred biome indices (0 verdant / 1 ashen / 2 glass)
##   vehicle     StringName  ??vehicle that can spawn at the POI (see VEHICLES)
##   map_bias    float       ??0..1 weight when procedural maps pick extra POIs
##   codex_icon  StringName  ??icon key for the codex / tactical map
##
## Layout coverage (every type in WorldBuilder.POI_LAYOUT + EXTRA_POI_KINDS has
## a spec) is asserted by features/world/world_test.gd; this file deliberately
## keeps no dependency on world_builder so it stays cheap and thread-safe.

## Canonical 20 POI type ids. Covers all 14 authored layout types, the 3 exfil
## pads (exfil_pad is authored separately but still a POI type) and the 7
## second-wave kits.
const TYPE_IDS: Array[StringName] = [
	&"faction_camp",
	&"relay_spire",
	&"crash_site",
	&"vault",
	&"warden_outpost",
	&"anomaly",
	&"ruin_field",
	&"ashen_stockade",
	&"bloom_hive",
	&"choir_post",
	&"colony_ruins",
	&"derelict_ship",
	&"exfil_pad",
	&"foundry_hall",
	&"hab_cluster",
	&"comms_array",
	&"fuel_depot",
	&"clinic_shelter",
	&"research_lab",
	&"water_works",
]

## Vehicle kinds a POI may advertise. &"" means "no authored vehicle slot".
const VEHICLES: Array[StringName] = [
	&"",
	&"rig",
	&"hoverbike",
	&"airplane",
	&"spaceship",
	&"horse",
]

const HAZARDS: Array[StringName] = [
	&"none",
	&"hostile",
	&"ember",
	&"electrical",
	&"toxic",
	&"flood",
	&"radiation",
	&"vacuum",
	&"unstable",
]

const _SPECS := [
	{
		"id": &"faction_camp", "title": "Vanguard Camp",
		"blurb": "A prefab command hab, tents and a watchtower holding the pad.",
		"radius": 42.0, "pad": 22.0, "interior": true, "loot_tier": 2, "garrison": 8,
		"hazard": &"hostile", "biomes": [0, 2], "vehicle": &"rig", "map_bias": 0.85,
		"codex_icon": &"camp",
	},
	{
		"id": &"relay_spire", "title": "Relay Spire",
		"blurb": "A 46 m lattice mast still singing into the rift static.",
		"radius": 30.0, "pad": 16.0, "interior": false, "loot_tier": 2, "garrison": 4,
		"hazard": &"electrical", "biomes": [0, 1], "vehicle": &"", "map_bias": 0.70,
		"codex_icon": &"antenna",
	},
	{
		"id": &"crash_site", "title": "Crash Site",
		"blurb": "A torn hull half-buried in glass, its reactor still warm.",
		"radius": 38.0, "pad": 24.0, "interior": true, "loot_tier": 3, "garrison": 6,
		"hazard": &"ember", "biomes": [2], "vehicle": &"airplane", "map_bias": 0.60,
		"codex_icon": &"wreck",
	},
	{
		"id": &"vault", "title": "Vault 07",
		"blurb": "A sealed bunker with a blast door that never quite closed.",
		"radius": 34.0, "pad": 22.0, "interior": true, "loot_tier": 4, "garrison": 10,
		"hazard": &"radiation", "biomes": [1], "vehicle": &"", "map_bias": 0.55,
		"codex_icon": &"vault",
	},
	{
		"id": &"warden_outpost", "title": "Warden Outpost",
		"blurb": "A stepped bastion crowned by the Warden's unblinking eye.",
		"radius": 48.0, "pad": 30.0, "interior": false, "loot_tier": 4, "garrison": 18,
		"hazard": &"hostile", "biomes": [1], "vehicle": &"", "map_bias": 0.90,
		"codex_icon": &"tower",
	},
	{
		"id": &"anomaly", "title": "Rift Anomaly",
		"blurb": "A hovering core ringed by monoliths that lean toward it.",
		"radius": 30.0, "pad": 18.0, "interior": false, "loot_tier": 3, "garrison": 6,
		"hazard": &"unstable", "biomes": [2], "vehicle": &"", "map_bias": 0.50,
		"codex_icon": &"rift",
	},
	{
		"id": &"ruin_field", "title": "The Ruined Archive",
		"blurb": "A ceremonial plaza of broken arches being reclaimed by growth.",
		"radius": 32.0, "pad": 18.0, "interior": false, "loot_tier": 2, "garrison": 5,
		"hazard": &"none", "biomes": [0], "vehicle": &"hoverbike", "map_bias": 0.60,
		"codex_icon": &"ruin",
	},
	{
		"id": &"ashen_stockade", "title": "Ashen Stockade",
		"blurb": "A palisade fort built over an older cage yard.",
		"radius": 44.0, "pad": 24.0, "interior": true, "loot_tier": 3, "garrison": 14,
		"hazard": &"hostile", "biomes": [0], "vehicle": &"horse", "map_bias": 0.70,
		"codex_icon": &"fort",
	},
	{
		"id": &"bloom_hive", "title": "Bloom Hive",
		"blurb": "Leaning organic spires around a breathing membrane nest.",
		"radius": 42.0, "pad": 22.0, "interior": false, "loot_tier": 4, "garrison": 12,
		"hazard": &"toxic", "biomes": [2], "vehicle": &"", "map_bias": 0.50,
		"codex_icon": &"bloom",
	},
	{
		"id": &"choir_post", "title": "Choir Listening Post",
		"blurb": "A dish and signal pylon ring listening for the Choir.",
		"radius": 36.0, "pad": 18.0, "interior": true, "loot_tier": 3, "garrison": 7,
		"hazard": &"electrical", "biomes": [1], "vehicle": &"", "map_bias": 0.55,
		"codex_icon": &"dish",
	},
	{
		"id": &"colony_ruins", "title": "Colony Ruins",
		"blurb": "Collapsed hab blocks along a street nobody walks anymore.",
		"radius": 40.0, "pad": 20.0, "interior": true, "loot_tier": 2, "garrison": 8,
		"hazard": &"none", "biomes": [0], "vehicle": &"hoverbike", "map_bias": 0.75,
		"codex_icon": &"ruins",
	},
	{
		"id": &"derelict_ship", "title": "Derelict Freighter",
		"blurb": "A landed freighter, cargo bay open and engines cold.",
		"radius": 46.0, "pad": 26.0, "interior": true, "loot_tier": 4, "garrison": 10,
		"hazard": &"vacuum", "biomes": [2], "vehicle": &"spaceship", "map_bias": 0.65,
		"codex_icon": &"ship",
	},
	{
		"id": &"exfil_pad", "title": "Exfil Pad",
		"blurb": "A lit landing pad. The only way off the frontier.",
		"radius": 38.0, "pad": 20.0, "interior": false, "loot_tier": 3, "garrison": 0,
		"hazard": &"none", "biomes": [0, 1, 2], "vehicle": &"spaceship", "map_bias": 1.00,
		"codex_icon": &"exfil",
	},
	{
		"id": &"foundry_hall", "title": "Foundry Hall",
		"blurb": "A two-storey smelter: catwalks, crucible and a cold gantry crane.",
		"radius": 46.0, "pad": 26.0, "interior": true, "loot_tier": 4, "garrison": 12,
		"hazard": &"ember", "biomes": [1], "vehicle": &"rig", "map_bias": 0.70,
		"codex_icon": &"factory",
	},
	{
		"id": &"hab_cluster", "title": "Habitation Cluster",
		"blurb": "Three domed hab modules sharing a courtyard and covered walks.",
		"radius": 44.0, "pad": 24.0, "interior": true, "loot_tier": 2, "garrison": 6,
		"hazard": &"none", "biomes": [0], "vehicle": &"hoverbike", "map_bias": 0.80,
		"codex_icon": &"home",
	},
	{
		"id": &"comms_array", "title": "Comms Array",
		"blurb": "A dish farm and equipment shed wired into the old uplink.",
		"radius": 34.0, "pad": 20.0, "interior": true, "loot_tier": 3, "garrison": 5,
		"hazard": &"electrical", "biomes": [1, 2], "vehicle": &"", "map_bias": 0.60,
		"codex_icon": &"antenna",
	},
	{
		"id": &"fuel_depot", "title": "Fuel Depot",
		"blurb": "A tank farm and pump gantry ringed by hazard chevrons.",
		"radius": 44.0, "pad": 26.0, "interior": true, "loot_tier": 3, "garrison": 9,
		"hazard": &"ember", "biomes": [1], "vehicle": &"rig", "map_bias": 0.75,
		"codex_icon": &"fuel",
	},
	{
		"id": &"clinic_shelter", "title": "Field Clinic",
		"blurb": "A field hospital still stocked: beds, lockers and a med screen.",
		"radius": 38.0, "pad": 22.0, "interior": true, "loot_tier": 3, "garrison": 4,
		"hazard": &"none", "biomes": [0], "vehicle": &"hoverbike", "map_bias": 0.65,
		"codex_icon": &"medical",
	},
	{
		"id": &"research_lab", "title": "Research Lab",
		"blurb": "A glass-domed lab wing with live server racks and cold tables.",
		"radius": 40.0, "pad": 24.0, "interior": true, "loot_tier": 4, "garrison": 7,
		"hazard": &"toxic", "biomes": [2], "vehicle": &"", "map_bias": 0.60,
		"codex_icon": &"flask",
	},
	{
		"id": &"water_works", "title": "Water Works",
		"blurb": "Settling basins, elevated tanks and catwalks over dead pumps.",
		"radius": 42.0, "pad": 24.0, "interior": true, "loot_tier": 3, "garrison": 6,
		"hazard": &"flood", "biomes": [0, 1], "vehicle": &"", "map_bias": 0.65,
		"codex_icon": &"water",
	},
]


## Every authored spec, deep-copied so callers cannot mutate the shared table.
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _SPECS:
		out.append((entry as Dictionary).duplicate(true))
	return out


static func has_spec(type: StringName) -> bool:
	for entry in _SPECS:
		if StringName(entry["id"]) == type:
			return true
	return false


## Spec for `type`, or an empty Dictionary when the type is unknown.
static func get_spec(type: StringName) -> Dictionary:
	for entry in _SPECS:
		if StringName(entry["id"]) == type:
			return (entry as Dictionary).duplicate(true)
	return {}


## Returns human-readable problems; an empty array means the table is valid.
## Cheap enough to call in tests / at boot; no side effects.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	if _SPECS.size() != TYPE_IDS.size():
		errors.append("spec count %d != TYPE_IDS count %d" % [_SPECS.size(), TYPE_IDS.size()])
	var seen: Dictionary = {}
	for entry in _SPECS:
		if not (entry is Dictionary):
			errors.append("spec entry is not a Dictionary")
			continue
		var spec: Dictionary = entry
		var id := StringName(spec.get("id", &""))
		if id == &"":
			errors.append("spec with empty id")
			continue
		if seen.has(id):
			errors.append("duplicate spec id '%s'" % String(id))
		seen[id] = true
		if not TYPE_IDS.has(id):
			errors.append("spec '%s' is missing from TYPE_IDS" % String(id))
		for field in ["title", "blurb", "codex_icon"]:
			if String(spec.get(field, "")).is_empty():
				errors.append("spec '%s' has empty %s" % [String(id), field])
		var radius := float(spec.get("radius", 0.0))
		var pad := float(spec.get("pad", 0.0))
		if radius < 12.0:
			errors.append("spec '%s' radius %.1f is too small" % [String(id), radius])
		if pad <= 0.0 or pad > radius:
			errors.append("spec '%s' pad %.1f must be > 0 and <= radius %.1f" % [String(id), pad, radius])
		if not (spec.get("interior", false) is bool):
			errors.append("spec '%s' interior must be a bool" % String(id))
		var loot_tier := int(spec.get("loot_tier", -1))
		if loot_tier < 0 or loot_tier > 4:
			errors.append("spec '%s' loot_tier %d out of range 0..4" % [String(id), loot_tier])
		var garrison := int(spec.get("garrison", -1))
		if garrison < 0 or garrison > 48:
			errors.append("spec '%s' garrison %d out of range 0..48" % [String(id), garrison])
		if not HAZARDS.has(StringName(spec.get("hazard", &""))):
			errors.append("spec '%s' has unknown hazard '%s'" % [String(id), String(spec.get("hazard", &""))])
		var biomes: Array = spec.get("biomes", [])
		if biomes.is_empty():
			errors.append("spec '%s' has no biomes" % String(id))
		for biome in biomes:
			if not (biome is int) or int(biome) < 0 or int(biome) > 2:
				errors.append("spec '%s' has invalid biome %s" % [String(id), str(biome)])
		if not VEHICLES.has(StringName(spec.get("vehicle", &"__missing__"))):
			errors.append("spec '%s' has unsupported vehicle '%s'" % [String(id), String(spec.get("vehicle", &""))])
		var map_bias := float(spec.get("map_bias", -1.0))
		if map_bias < 0.0 or map_bias > 1.0:
			errors.append("spec '%s' map_bias %.2f out of range 0..1" % [String(id), map_bias])
	for type_id in TYPE_IDS:
		if not seen.has(type_id):
			errors.append("TYPE_IDS entry '%s' has no spec" % String(type_id))
	return errors
