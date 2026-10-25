class_name LoadingBrief
extends RefCounted
## Resolves the deployment context shown by the loading cinema: operation,
## planet/map, difficulty, mode and the boss signature the player is dropping in
## on. Pure data (no nodes), so the loading screen and its tests can consume it
## without touching RunState or the deployment scene.
##
## App calls `build()` before RunState.start_run() exists, so map/difficulty
## resolution intentionally mirrors RunState's rules (explicit override ->
## difficulty's featured map -> first authored map).

## Authored threat-dossier copy. The quote is shown on the boss card; the
## counter-intel line tells the player how the fight opens.
const BOSS_INTEL := {
	&"the_warden": {
		"quote": "It was built to guard a door that no longer exists. It has not been told.",
		"counter": "Strip the blue relays first. Its shield folds when the choir goes quiet.",
		"tag": "GATEKEEPER",
	},
	&"bloomheart": {
		"quote": "A heart the size of a habitat, still beating for a garden that died.",
		"counter": "Burn the spore stalks before it closes. Open flame denies its regrowth.",
		"tag": "OVERGROWTH",
	},
	&"rift_colossus": {
		"quote": "The Reach folded it out of three dead things and a bad memory.",
		"counter": "Violet seams run across the shoulders. Break them while it charges.",
		"tag": "FOLD-BORN",
	},
	&"cinder_titan": {
		"quote": "The mine's fire wrote it a body and taught it to walk uphill.",
		"counter": "Cool the furnace core. Frost and water stagger it; heat only feeds it.",
		"tag": "FORGEBORN",
	},
	&"leviathan": {
		"quote": "Something in the drowned shelf learned to sing, and the water listened.",
		"counter": "It hunts by sonar. Hold still between pulses and it loses your line.",
		"tag": "DROWNED",
	},
	&"hollow_sovereign": {
		"quote": "An empty throne that keeps issuing orders to a court of static.",
		"counter": "Silence the choir before the Sovereign takes the field. Alone, it kneels.",
		"tag": "THRONE-EMPTY",
	},
}

const STYLE_CLASS := {
	&"titan": "TITAN-CLASS SIEGE FORM",
	&"beast": "BLOOMBORN APEX",
	&"flyer": "CHOIR AERIAL",
	&"swimmer": "ABYSSAL HUNTER",
	&"heavy": "HEAVY ASSAULT FORM",
	&"humanoid": "WARDEN-BREED INFANTRY",
	&"drone": "AUTONOMOUS PLATFORM",
}

const FALLBACK_INTEL := {
	"quote": "The scope does not have a name for it yet. It has a body count.",
	"counter": "Keep moving, break line of sight, and hit the glowing seams.",
	"tag": "UNCLASSIFIED",
}


## Build the full brief. Every argument is optional; missing content falls back
## to authored defaults so a bare `build()` is still presentable in tests.
static func build(
	contract_id: StringName = &"salvage_sweep",
	seed_value: int = 0,
	threat: int = 1,
	difficulty_id: StringName = &"",
	mode_id: StringName = &"normal",
	map_id: StringName = &""
) -> Dictionary:
	var difficulty := _resolve_difficulty(difficulty_id, threat)
	var threat_level := clampi(maxi(threat, int(difficulty.get("threat", 1))), 1, 4)
	var map_preset := _resolve_map(map_id, difficulty)
	var planet := _resolve_planet(map_preset)
	var mode := _resolve_mode(mode_id)
	var contract := _resolve_contract(contract_id)
	var sky := _resolve_sky(planet, map_preset)

	var boss := _resolve_boss(planet, seed_value, map_id, mode_id)

	return {
		"contract_id": StringName(contract.get("id", &"salvage_sweep")),
		"contract_name": String(contract.get("display_name", "Salvage Sweep")),
		"contract_description": String(contract.get("description", "")),
		"contract_flavor": String(contract.get("flavor", "")),
		"objective_label": String(contract.get("objective_label", "")),
		"contract_color": contract.get("color", Color("ffb866")),
		"contract_icon": StringName(contract.get("icon", &"target")),
		"difficulty_id": StringName(difficulty.get("id", &"patrol")),
		"difficulty_name": String(difficulty.get("display_name", "Patrol")),
		"threat": threat_level,
		"reward_mult": float(difficulty.get("reward", 1.0)),
		"mode_id": StringName(mode.get("id", &"normal")),
		"mode_name": String(mode.get("display_name", "Normal")),
		"mode_tag": String(mode.get("tag", "STANDARD")),
		"mode_clock": String(mode.get("clock", "18:00")),
		"mode_description": String(mode.get("description", "")),
		"map_id": StringName(map_preset.get("id", &"verdant_verge")),
		"map_name": String(map_preset.get("display_name", "Verdant Verge")),
		"map_subtitle": String(map_preset.get("subtitle", "The Reach")),
		"map_color": map_preset.get("color", Color("62e6c3")),
		"planet_id": StringName(planet.get("id", &"meridian_9")),
		"planet_name": String(planet.get("display_name", "Meridian-9")),
		"planet_subtitle": String(planet.get("subtitle", "The Reach")),
		"planet_color": planet.get("color", Color("62e6c3")),
		"planet_hazard": String(planet.get("hazard", "none")),
		"seed": seed_value,
		"sky_top": sky.get("top", Color("101d21")),
		"sky_horizon": sky.get("horizon", Color("d9a173")),
		"sky_ground": sky.get("ground", Color("0d1517")),
		"sun_color": sky.get("sun", Color("ffd9a0")),
		"boss": boss,
		"boss_pool": _boss_pool_size(),
		"radio": _radio_lines(contract, map_preset, planet, boss),
	}


static func _resolve_contract(contract_id: StringName) -> Dictionary:
	if ContentDB != null:
		var contract := ContentDB.get_contract(contract_id)
		if contract != null:
			return {
				"id": contract.id,
				"display_name": contract.display_name,
				"description": contract.description,
				"flavor": contract.flavor,
				"objective_label": contract.objective_label,
				"icon": contract.icon,
				"color": contract.color,
			}
	return {
		"id": contract_id,
		"display_name": String(contract_id).replace("_", " ").capitalize(),
		"description": "Recover what the Reach will give up.",
		"flavor": "",
		"objective_label": "Complete the operation",
		"icon": &"target",
		"color": Color("ffb866"),
	}


static func _resolve_difficulty(difficulty_id: StringName, threat: int) -> Dictionary:
	if ContentDB != null:
		var difficulty := ContentDB.get_difficulty(difficulty_id)
		if difficulty.is_empty():
			difficulty = ContentDB.get_difficulty_for_threat(clampi(threat, 1, 4))
		if not difficulty.is_empty():
			return difficulty
	return {"id": &"patrol", "display_name": "Patrol", "threat": 1, "reward": 1.0}


static func _resolve_map(map_id: StringName, difficulty: Dictionary) -> Dictionary:
	if ContentDB == null:
		return {"id": &"verdant_verge", "display_name": "Verdant Verge", "planet_id": &"meridian_9"}
	var preset := ContentDB.get_map_preset(map_id)
	if preset.is_empty():
		preset = ContentDB.get_map_preset(StringName(difficulty.get("map_preset", &"")))
	if preset.is_empty():
		var presets := ContentDB.get_map_presets()
		if not presets.is_empty():
			preset = presets[0]
	return preset


static func _resolve_planet(map_preset: Dictionary) -> Dictionary:
	if ContentDB == null:
		return {}
	var planet := ContentDB.get_planet(StringName(map_preset.get("planet_id", &"")))
	if planet.is_empty():
		return {"id": &"meridian_9", "display_name": "Meridian-9", "subtitle": "The Reach"}
	return planet


static func _resolve_mode(mode_id: StringName) -> Dictionary:
	if ContentDB != null:
		var mode := ContentDB.get_game_mode(mode_id)
		if not mode.is_empty():
			return mode
		mode = ContentDB.get_game_mode(&"normal")
		if not mode.is_empty():
			return mode
	return {"id": &"normal", "display_name": "Normal", "tag": "STANDARD", "clock": "18:00"}


## The loading cinema is a mood piece, so it picks the nearest authored sky
## keyframe for the map's start time, then lets the map's own environment
## overrides win. No 3D scene exists yet at this point.
static func _resolve_sky(planet: Dictionary, map_preset: Dictionary) -> Dictionary:
	var start_time := float(map_preset.get("start_time", 0.62))
	var key := "day"
	if start_time < 0.18:
		key = "night"
	elif start_time < 0.40:
		key = "dawn"
	elif start_time >= 0.78:
		key = "dusk"
	var skies: Dictionary = planet.get("sky", {})
	var sky: Dictionary = skies.get(key, {}) if skies.get(key, {}) is Dictionary else {}
	var environment: Dictionary = map_preset.get("environment", {})
	var out := {
		"top": sky.get("sky_top", Color("101d21")),
		"horizon": sky.get("sky_horizon", Color("d9a173")),
		"ground": sky.get("sky_ground", Color("0d1517")),
		"sun": sky.get("sun_color", Color("ffd9a0")),
	}
	for entry in [["sky_top", "top"], ["sky_horizon", "horizon"], ["sky_ground", "ground"], ["sun_color", "sun"]]:
		var source_key: String = entry[0]
		var target_key: String = entry[1]
		if environment.has(source_key):
			out[target_key] = environment[source_key]
	return out


## Boss selection: the planet's dungeon roster first (so Cinder-4 always shows a
## fire boss), varied by run seed. Falls back to the full boss roster.
static func _resolve_boss(planet: Dictionary, seed_value: int, map_id: StringName, mode_id: StringName) -> Dictionary:
	var boss_ids: Array[StringName] = []
	if ContentDB != null:
		var themes: Array = planet.get("dungeon_themes", [])
		for theme_id in themes:
			var theme: Dictionary = ContentDB.get_dungeon_theme(StringName(theme_id))
			var boss_id := StringName(theme.get("boss_id", &""))
			if boss_id != &"" and not boss_ids.has(boss_id):
				boss_ids.append(boss_id)
		if boss_ids.is_empty():
			for enemy in ContentDB.get_boss_enemies():
				boss_ids.append(enemy.id)
	var enemy: EnemyData = null
	if ContentDB != null and not boss_ids.is_empty():
		var index := 0
		if mode_id != &"tutorial" and seed_value != 0:
			index = absi(seed_value + int(map_id.hash()) + 17) % boss_ids.size()
		enemy = ContentDB.get_enemy(boss_ids[index])
		if enemy == null:
			var pool := ContentDB.get_boss_enemies()
			enemy = pool[0] if not pool.is_empty() else null
	if enemy == null:
		return _fallback_boss()
	return _boss_dict(enemy)


static func _boss_dict(enemy: EnemyData) -> Dictionary:
	var intel: Dictionary = BOSS_INTEL.get(enemy.id, FALLBACK_INTEL)
	var faction_color := UIPalette.faction_color(enemy.faction) if UIPalette != null else enemy.accent_color
	return {
		"id": enemy.id,
		"name": enemy.display_name,
		"faction": enemy.faction,
		"faction_name": String(enemy.faction).capitalize(),
		"faction_color": faction_color,
		"style": enemy.style,
		"class_label": String(STYLE_CLASS.get(enemy.style, STYLE_CLASS[&"titan"])),
		"phases": maxi(1, enemy.boss_phases),
		"health": enemy.max_health,
		"shield": enemy.max_shield,
		"armor": enemy.armor,
		"damage": enemy.damage,
		"speed": enemy.move_speed,
		"body_color": enemy.body_color,
		"accent_color": enemy.accent_color,
		"eye_color": enemy.eye_color,
		"body_scale": enemy.body_scale,
		"quote": String(intel.get("quote", FALLBACK_INTEL["quote"])),
		"counter": String(intel.get("counter", FALLBACK_INTEL["counter"])),
		"tag": String(intel.get("tag", FALLBACK_INTEL["tag"])),
	}


static func _fallback_boss() -> Dictionary:
	return {
		"id": &"the_warden",
		"name": "The Warden",
		"faction": &"choir",
		"faction_name": "Choir",
		"faction_color": Color("62e6c3"),
		"style": &"titan",
		"class_label": "TITAN-CLASS SIEGE FORM",
		"phases": 3,
		"health": 2800.0,
		"shield": 400.0,
		"armor": 35.0,
		"damage": 30.0,
		"speed": 3.6,
		"body_color": Color("243744"),
		"accent_color": Color("63b8ff"),
		"eye_color": Color("b9f1ff"),
		"body_scale": 2.8,
		"quote": String(FALLBACK_INTEL["quote"]),
		"counter": String(FALLBACK_INTEL["counter"]),
		"tag": String(FALLBACK_INTEL["tag"]),
	}


static func _boss_pool_size() -> int:
	if ContentDB == null:
		return 1
	return maxi(1, ContentDB.get_boss_enemies().size())


## One radio beat per act: threat briefing, breach, descent, touchdown.
static func _radio_lines(contract: Dictionary, map_preset: Dictionary, planet: Dictionary, boss: Dictionary) -> Array:
	var map_name := String(map_preset.get("display_name", "the Reach"))
	var planet_name := String(planet.get("display_name", "Meridian-9"))
	var boss_name := String(boss.get("name", "The Warden")).to_upper()
	var operation := String(contract.get("display_name", "Salvage Sweep"))
	return [
		{
			"speaker": "Waystation Kestrel",
			"line": "New signature on scope: %s. Mark it and stay mobile." % boss_name,
		},
		{
			"speaker": "Waystation Kestrel",
			"line": "Drop window is open. %s is already folding." % map_name,
		},
		{
			"speaker": "Waystation Kestrel",
			"line": "Pod is clear. Guidance is steering you over %s." % planet_name,
		},
		{
			"speaker": "Mara Voss",
			"line": "Touchdown confirmed, Warden. Operation %s is live." % operation,
		},
	]
