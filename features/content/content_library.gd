class_name ContentLibrary
extends RefCounted
## Static content catalog. Keeping authored data close to code makes it easy to
## validate counts and avoids fragile directory scanning in exported builds.

const RARITY_LABELS := ["Common", "Uncommon", "Rare", "Epic", "Prototype"]


static func build() -> Dictionary:
	return {
		"weapons": _weapons(),
		"abilities": _abilities(),
		"enemies": _enemies(),
		"difficulties": _difficulties(),
		"map_presets": _map_presets(),
		"allies": _allies(),
		"pets": _pets(),
		"base_modules": _base_modules(),
		"contracts": _contracts(),
		"rift_mods": _rift_mods(),
		"mutators": _mutators(),
		"grenades": _grenades(),
		"item_templates": _item_templates(),
		"cosmetics": _cosmetics(),
		"affixes": _affixes(),
		"perks": _perks(),
	}


static func _apply(res: Resource, def: Dictionary) -> Resource:
	for key in def.keys():
		res.set(key, def[key])
	return res


# ---------------------------------------------------------------------------
# Run difficulties
# ---------------------------------------------------------------------------

## Named deployment difficulties. Plain dictionaries because they are read-only
## presets consumed by RunState/UI; no per-run instance state is stored.
static func _difficulties() -> Array:
	return [
		{
			"id": &"patrol", "display_name": "Patrol", "threat": 1,
			"density": 1.35, "elite_bonus": 0.04, "reward": 1.00,
			"map_preset": &"verdant_verge",
			"mission_sites": 3, "side_caches": 4, "bounties": 1, "objective_guards": 3,
			"max_hostiles": 56, "enemy_health_mult": 1.08, "enemy_damage_mult": 1.08,
			"loot_luck": 0.0, "storm_fraction": 0.667, "director_interval_scale": 1.0,
			"extraction_scale": 1.0,
			"description": "Light patrols, one bounty. A clean first run.",
			"icon": &"shield", "color": Color("62e6c3"),
		},
		{
			"id": &"contact", "display_name": "Contact", "threat": 2,
			"density": 1.65, "elite_bonus": 0.09, "reward": 1.20,
			"map_preset": &"ashen_shelf",
			"mission_sites": 4, "side_caches": 6, "bounties": 2, "objective_guards": 4,
			"max_hostiles": 64, "enemy_health_mult": 1.16, "enemy_damage_mult": 1.14,
			"loot_luck": 0.05, "storm_fraction": 0.62, "director_interval_scale": 0.9,
			"extraction_scale": 1.1,
			"description": "Reinforced patrols and elite signatures.",
			"icon": &"target", "color": Color("6fa8ff"),
		},
		{
			"id": &"breach", "display_name": "Breach", "threat": 3,
			"density": 2.00, "elite_bonus": 0.15, "reward": 1.45,
			"map_preset": &"glass_expanse",
			"mission_sites": 5, "side_caches": 8, "bounties": 3, "objective_guards": 5,
			"max_hostiles": 72, "enemy_health_mult": 1.24, "enemy_damage_mult": 1.20,
			"loot_luck": 0.10, "storm_fraction": 0.58, "director_interval_scale": 0.8,
			"extraction_scale": 1.2,
			"description": "Heavy elites, dense packs, better salvage.",
			"icon": &"warning", "color": Color("ffb866"),
		},
		{
			"id": &"collapse", "display_name": "Collapse", "threat": 4,
			"density": 2.40, "elite_bonus": 0.22, "reward": 1.75,
			"map_preset": &"rift_scar",
			"mission_sites": 6, "side_caches": 10, "bounties": 4, "objective_guards": 6,
			"max_hostiles": 80, "enemy_health_mult": 1.32, "enemy_damage_mult": 1.28,
			"loot_luck": 0.15, "storm_fraction": 0.54, "director_interval_scale": 0.7,
			"extraction_scale": 1.3,
			"description": "Maximum hostility. The Reach is already folding.",
			"icon": &"skull", "color": Color("ff6e6e"),
		},
	]


# ---------------------------------------------------------------------------
# Map presets
# ---------------------------------------------------------------------------

## Named map identities mapped one-to-one to difficulties. A preset changes the
## world's biome emphasis, environment mood, POI/roadside/scatter budget and the
## seed salt that flavours the procedural layout. Layouts stay seeded per drop.
static func _map_presets() -> Array:
	return [
		{
			"id": &"verdant_verge", "display_name": "Verdant Verge",
			"subtitle": "Verdant Basin", "icon": &"map", "color": Color("62e6c3"),
			"biome_index": 0, "world_seed_salt": 917, "scatter_density": 1.15,
			"extra_pois": 2, "extra_poi_names": ["Survey Camp", "Overgrown Relay"],
			"roadside_target": 16, "biome_rotation": 0.0,
			"environment": {},
		},
		{
			"id": &"ashen_shelf", "display_name": "Ashen Shelf",
			"subtitle": "Ashen Canyons", "icon": &"map", "color": Color("ffb866"),
			"biome_index": 1, "world_seed_salt": 2221, "scatter_density": 1.25,
			"extra_pois": 3, "extra_poi_names": ["Cinder Camp", "Ashen Relay", "Scorched Ruin"],
			"roadside_target": 18, "biome_rotation": 2.0944,
			"environment": {
				"sky_top": Color(0.09, 0.08, 0.13), "sky_horizon": Color(0.78, 0.36, 0.18),
				"sky_ground": Color(0.18, 0.10, 0.08), "sun_color": Color(1.0, 0.62, 0.32),
				"fog_color": Color(0.42, 0.24, 0.17), "fog_density": 0.00042,
				"volumetric_fog_density": 0.0045, "sun_dir": Vector3(-0.78, 0.18, -0.58),
				"sun_energy": 1.30, "fill_color": Color(0.30, 0.34, 0.52),
			},
		},
		{
			"id": &"glass_expanse", "display_name": "Glass Expanse",
			"subtitle": "Glass Flats", "icon": &"map", "color": Color("8fd6e6"),
			"biome_index": 2, "world_seed_salt": 3331, "scatter_density": 1.35,
			"extra_pois": 4, "extra_poi_names": ["Glass Camp", "Cracked Relay", "Pale Ruin", "Shard Field"],
			"roadside_target": 20, "biome_rotation": 4.1888,
			"environment": {
				"sky_top": Color(0.42, 0.55, 0.63), "sky_horizon": Color(0.90, 0.88, 0.78),
				"sky_ground": Color(0.45, 0.43, 0.36), "sun_color": Color(1.0, 0.96, 0.82),
				"fog_color": Color(0.78, 0.80, 0.74), "fog_density": 0.00018,
				"volumetric_fog_density": 0.002, "sun_dir": Vector3(0.25, 0.72, 0.30),
				"sun_energy": 1.80, "fill_color": Color(0.55, 0.66, 0.74),
			},
		},
		{
			"id": &"rift_scar", "display_name": "Rift Scar",
			"subtitle": "Folded Reach", "icon": &"bolt", "color": Color("c79cff"),
			"biome_index": 0, "world_seed_salt": 4441, "scatter_density": 1.50,
			"extra_pois": 4, "extra_poi_names": ["Rift Camp", "Fold Relay", "Scar Ruin", "Null Field"],
			"roadside_target": 22, "biome_rotation": 1.0472,
			"environment": {
				"sky_top": Color(0.12, 0.06, 0.20), "sky_horizon": Color(0.62, 0.20, 0.44),
				"sky_ground": Color(0.10, 0.05, 0.13), "sun_color": Color(0.82, 0.55, 1.0),
				"fog_color": Color(0.26, 0.14, 0.32), "fog_density": 0.00055,
				"volumetric_fog_density": 0.006, "sun_dir": Vector3(-0.25, 0.16, 0.83),
				"sun_energy": 1.05, "fill_color": Color(0.40, 0.28, 0.60),
			},
		},
	]


# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

static func _weapons() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{
			"id": &"lattice_ar", "display_name": "Lattice AR", "archetype": &"rifle",
			"description": "The Reach standard. Predictable recoil, honest damage, no excuses.",
			"damage": 24.0, "pellets": 1, "fire_rate": 600.0, "fire_mode": &"auto",
			"mag_size": 30, "reserve_ammo": 210, "reload_time": 2.0,
			"spread_hip": 2.2, "spread_ads": 0.3, "recoil_kick": 1.0,
			"effective_range": 160.0, "falloff_start": 55.0, "range_mult": 0.55,
			"crit_mult": 1.75, "style": &"rifle", "color": Color("f4efe5"),
			"accent": Color("62e6c3"), "value": 140, "tier": 1,
			"unique_perk": "No-nonsense mid-range workhorse.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 1.0), Vector2(-0.08, 1.1), Vector2(0.12, 1.2), Vector2(-0.18, 1.35), Vector2(0.22, 1.5), Vector2(-0.3, 1.6), Vector2(0.4, 1.8), Vector2(-0.5, 2.0), Vector2(0.62, 2.2)]),
		},
		{
			"id": &"wisp_smg", "display_name": "Wisp SMG", "archetype": &"smg",
			"description": "Close, loud and hungry. The Wisp rewards commitment.",
			"damage": 13.0, "pellets": 1, "fire_rate": 900.0, "fire_mode": &"auto",
			"mag_size": 36, "reserve_ammo": 252, "reload_time": 1.6,
			"spread_hip": 3.8, "spread_ads": 0.9, "recoil_kick": 0.75,
			"effective_range": 70.0, "falloff_start": 26.0, "range_mult": 0.4,
			"crit_mult": 1.6, "style": &"smg", "color": Color("26383d"),
			"accent": Color("ffb866"), "value": 130, "tier": 1,
			"unique_perk": "Fast handling and tight hipfire.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.16, 1.0), Vector2(-0.2, 1.1), Vector2(0.28, 1.2), Vector2(-0.34, 1.35), Vector2(0.4, 1.4), Vector2(-0.48, 1.6)]),
		},
		{
			"id": &"breakline_sg", "display_name": "Breakline", "archetype": &"shotgun",
			"description": "A door opener. Eight pellets, zero subtlety.",
			"damage": 16.0, "pellets": 8, "fire_rate": 75.0, "fire_mode": &"semi",
			"mag_size": 6, "reserve_ammo": 42, "reload_time": 2.8,
			"spread_hip": 7.0, "spread_ads": 4.0, "recoil_kick": 2.0,
			"effective_range": 60.0, "falloff_start": 10.0, "range_mult": 0.25,
			"crit_mult": 1.5, "style": &"shotgun", "color": Color("d28b58"),
			"accent": Color("f4efe5"), "value": 145, "tier": 1,
			"unique_perk": "Devastating inside 8 m.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 3.0), Vector2(0.1, 3.4)]),
		},
		{
			"id": &"longview_dmr", "display_name": "Longview DMR", "archetype": &"dmr",
			"description": "One breath, one shot, one less problem.",
			"damage": 55.0, "pellets": 1, "fire_rate": 180.0, "fire_mode": &"semi",
			"mag_size": 12, "reserve_ammo": 96, "reload_time": 2.2,
			"spread_hip": 1.6, "spread_ads": 0.06, "recoil_kick": 1.4,
			"effective_range": 250.0, "falloff_start": 120.0, "range_mult": 0.8,
			"crit_mult": 2.1, "style": &"dmr", "color": Color("e7e2d5"),
			"accent": Color("6fa8ff"), "value": 175, "tier": 2,
			"unique_perk": "Improved headshot multiplier.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 1.5), Vector2(0.12, 1.8), Vector2(-0.1, 2.0)]),
		},
		{
			"id": &"sable_rail", "display_name": "Sable Rail", "archetype": &"sniper",
			"description": "A magnetic whisper that punches through a column of bad intentions.",
			"damage": 160.0, "pellets": 1, "fire_rate": 45.0, "fire_mode": &"charge",
			"mag_size": 5, "reserve_ammo": 30, "reload_time": 3.0,
			"spread_hip": 2.0, "spread_ads": 0.0, "recoil_kick": 2.5,
			"effective_range": 350.0, "falloff_start": 250.0, "range_mult": 1.0,
			"crit_mult": 2.35, "style": &"sniper", "color": Color("121a1d"),
			"accent": Color("c79cff"), "value": 220, "tier": 3,
			"unique_perk": "Fully charged shots pierce one target.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 3.2), Vector2(0.0, 3.8)]),
		},
		{
			"id": &"cantor_lmg", "display_name": "Cantor LMG", "archetype": &"lmg",
			"description": "Continuous fire is a language. Speak clearly.",
			"damage": 22.0, "pellets": 1, "fire_rate": 450.0, "fire_mode": &"auto",
			"mag_size": 80, "reserve_ammo": 320, "reload_time": 4.3,
			"spread_hip": 4.0, "spread_ads": 0.6, "recoil_kick": 1.35,
			"effective_range": 180.0, "falloff_start": 70.0, "range_mult": 0.6,
			"crit_mult": 1.7, "style": &"lmg", "color": Color("3a474b"),
			"accent": Color("ffb866"), "value": 185, "tier": 2,
			"unique_perk": "Movement penalty while firing; huge belt.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 1.2), Vector2(0.16, 1.3), Vector2(-0.2, 1.4), Vector2(0.24, 1.5), Vector2(-0.28, 1.65)]),
		},
		{
			"id": &"sidewinder", "display_name": "Sidewinder", "archetype": &"pistol",
			"description": "Three-round burst. Always there when the universe gets close.",
			"slot": &"sidearm", "damage": 18.0, "pellets": 1, "fire_rate": 500.0,
			"fire_mode": &"burst", "burst_count": 3, "mag_size": 21, "reserve_ammo": 126,
			"reload_time": 1.5, "spread_hip": 1.8, "spread_ads": 0.4,
			"recoil_kick": 0.9, "effective_range": 80.0, "falloff_start": 35.0,
			"range_mult": 0.5, "crit_mult": 1.8, "style": &"pistol",
			"color": Color("f4efe5"), "accent": Color("62e6c3"), "value": 90, "tier": 1,
			"unique_perk": "Fast swap; burst headshots are exceptional.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 0.7), Vector2(0.1, 0.9), Vector2(-0.08, 1.0)]),
		},
		{
			"id": &"havoc_gl", "display_name": "Havoc GL", "archetype": &"launcher",
			"description": "When cover is a suggestion.",
			"damage": 110.0, "pellets": 1, "fire_rate": 60.0, "fire_mode": &"projectile",
			"mag_size": 4, "reserve_ammo": 20, "reload_time": 3.2,
			"spread_hip": 2.0, "spread_ads": 0.8, "recoil_kick": 2.2,
			"effective_range": 100.0, "falloff_start": 100.0, "range_mult": 1.0,
			"crit_mult": 1.5, "projectile_speed": 45.0, "style": &"launcher",
			"color": Color("55635f"), "accent": Color("ffb866"), "value": 210, "tier": 2,
			"unique_perk": "Arcing rocket with blast radius.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 2.5)]),
		},
		{
			"id": &"tesla_arc", "display_name": "Tesla Arc", "archetype": &"arc",
			"description": "The Choir's favourite argument, reversed.",
			"damage": 30.0, "pellets": 1, "fire_rate": 220.0, "fire_mode": &"semi",
			"mag_size": 14, "reserve_ammo": 84, "reload_time": 2.3,
			"spread_hip": 2.2, "spread_ads": 0.2, "recoil_kick": 1.1,
			"effective_range": 90.0, "falloff_start": 35.0, "range_mult": 0.7,
			"crit_mult": 1.65, "status_type": &"shock", "status_chance": 0.45,
			"status_power": 1.0, "style": &"arc", "color": Color("26383d"),
			"accent": Color("62e6c3"), "value": 200, "tier": 3,
			"unique_perk": "Arcs to nearby targets; excels against shields.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.1, 1.2)]),
		},
		{
			"id": &"bloom_carbine", "display_name": "Bloom Carbine", "archetype": &"rifle",
			"description": "A captured Bloom stinger rebuilt into a rifle. It remembers.",
			"damage": 26.0, "pellets": 1, "fire_rate": 400.0, "fire_mode": &"burst",
			"burst_count": 3, "mag_size": 24, "reserve_ammo": 144, "reload_time": 2.1,
			"spread_hip": 2.6, "spread_ads": 0.5, "recoil_kick": 1.1,
			"effective_range": 130.0, "falloff_start": 55.0, "range_mult": 0.6,
			"crit_mult": 1.8, "status_type": &"corrode", "status_chance": 0.5,
			"status_power": 1.0, "style": &"carbine", "color": Color("3a2b3d"),
			"accent": Color("c79cff"), "value": 195, "tier": 3,
			"unique_perk": "Corrodes armor on hit.",
			"recoil_pattern": PackedVector2Array([Vector2(0.0, 1.1), Vector2(0.12, 1.25), Vector2(-0.08, 1.4)]),
		},
	]
	var zoom_by_style := {
		"rifle": 0.82, "smg": 0.90, "shotgun": 0.92, "dmr": 0.50,
		"sniper": 0.34, "lmg": 0.84, "pistol": 0.88, "launcher": 0.94,
		"arc": 0.82, "carbine": 0.75,
	}
	for def in defs:
		if not def.has("ads_zoom"):
			def["ads_zoom"] = float(zoom_by_style.get(String(def.get("style", "rifle")), 0.82))
		list.append(_apply(WeaponData.new(), def))
	return list


# ---------------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------------

static func _abilities() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"blink_step", "display_name": "Blink Step", "effect_id": &"blink",
			"description": "Shift forward through local space. Breaks weak grips.", "discipline": &"shared",
			"cooldown": 8.0, "magnitude": 9.0, "color": Color("62e6c3"), "unlock_level": 1, "icon": &"arrow"},
		{"id": &"aegis_wall", "display_name": "Aegis Wall", "effect_id": &"deploy_wall",
			"description": "Deploy a temporary hardlight barrier.", "discipline": &"vanguard",
			"cooldown": 22.0, "magnitude": 320.0, "duration": 12.0, "radius": 2.5,
			"color": Color("62e6c3"), "unlock_level": 1, "icon": &"shield"},
		{"id": &"phase_cloak", "display_name": "Phase Cloak", "effect_id": &"cloak",
			"description": "Bend light around your suit and move faster.", "discipline": &"infiltrator",
			"cooldown": 24.0, "magnitude": 1.25, "duration": 4.0,
			"color": Color("6fa8ff"), "unlock_level": 1, "icon": &"eye"},
		{"id": &"overclock", "display_name": "Overclock", "effect_id": &"overclock",
			"description": "Push the suit: faster fire and reload for 6 seconds.", "discipline": &"engineer",
			"cooldown": 26.0, "magnitude": 1.3, "duration": 6.0,
			"color": Color("ffb866"), "unlock_level": 4, "icon": &"bolt"},
		{"id": &"arc_chain", "display_name": "Arc Chain", "effect_id": &"chain_lightning",
			"description": "Release a shock chain through up to 3 nearby enemies.", "discipline": &"shared",
			"cooldown": 14.0, "magnitude": 40.0, "range": 18.0, "projectile_count": 3,
			"color": Color("62e6c3"), "unlock_level": 6, "icon": &"lightning"},
		{"id": &"graviton_well", "display_name": "Graviton Well", "effect_id": &"gravity_well",
			"description": "Collapse a pocket of gravity, pulling enemies into a cluster.", "discipline": &"pathfinder",
			"cooldown": 22.0, "magnitude": 7.0, "duration": 2.5, "radius": 6.0, "range": 22.0,
			"color": Color("c79cff"), "unlock_level": 8, "icon": &"vortex"},
		{"id": &"seismic_slam", "display_name": "Seismic Slam", "effect_id": &"cone_slam",
			"description": "Hit the ground and send a shockwave forward.", "discipline": &"vanguard",
			"cooldown": 16.0, "magnitude": 70.0, "radius": 5.0, "range": 9.0,
			"color": Color("ffb866"), "unlock_level": 5, "icon": &"impact"},
		{"id": &"deploy_turret", "display_name": "Deploy Turret", "effect_id": &"deploy_turret",
			"description": "Print a sentry that fights for 18 seconds.", "discipline": &"engineer",
			"cooldown": 30.0, "magnitude": 18.0, "duration": 18.0, "radius": 2.0,
			"color": Color("62e6c3"), "unlock_level": 3, "icon": &"turret"},
		{"id": &"pulse_scan", "display_name": "Pulse Scan", "effect_id": &"scan",
			"description": "Reveal nearby threats and mark enemy weak points.", "discipline": &"pathfinder",
			"cooldown": 18.0, "duration": 6.0, "radius": 55.0,
			"color": Color("6fa8ff"), "unlock_level": 2, "icon": &"radar"},
		{"id": &"mender_field", "display_name": "Mender Field", "effect_id": &"mender_field",
			"description": "Deploy a healing field for you, allies and your pet.", "discipline": &"shared",
			"cooldown": 28.0, "duration": 5.0, "radius": 6.0, "magnitude": 18.0,
			"color": Color("62e6c3"), "unlock_level": 7, "icon": &"cross"},
		{"id": &"havoc_barrage", "display_name": "Havoc Barrage", "effect_id": &"barrage",
			"description": "Paint a target and call five micro-rockets onto it.", "discipline": &"shared",
			"cooldown": 25.0, "magnitude": 45.0, "radius": 7.0, "range": 60.0,
			"projectile_count": 5, "color": Color("ffb866"), "unlock_level": 9, "icon": &"rocket"},
		{"id": &"temporal_fold", "display_name": "Temporal Fold", "effect_id": &"rewind",
			"description": "Fold back to where you stood three seconds ago; recover some health.", "discipline": &"shared",
			"cooldown": 35.0, "magnitude": 0.3, "duration": 3.0,
			"color": Color("c79cff"), "unlock_level": 10, "icon": &"clock"},
		{"id": &"iron_tide", "display_name": "Iron Tide", "effect_id": &"ultimate_iron_tide",
			"description": "Ultimate. Become an unstoppable anchor: overshield, pull, then detonate.",
			"discipline": &"vanguard", "cooldown": 120.0, "duration": 8.0, "radius": 8.0,
			"magnitude": 120.0, "is_ultimate": true, "color": Color("ffb866"), "unlock_level": 1, "icon": &"tide"},
		{"id": &"ghost_protocol", "display_name": "Ghost Protocol", "effect_id": &"ultimate_ghost",
			"description": "Ultimate. Cloak the squad; the next shots from stealth are critical hits.",
			"discipline": &"infiltrator", "cooldown": 120.0, "duration": 8.0,
			"magnitude": 1.0, "is_ultimate": true, "color": Color("6fa8ff"), "unlock_level": 1, "icon": &"ghost"},
		{"id": &"siegeworks", "display_name": "Siegeworks", "effect_id": &"ultimate_siege",
			"description": "Ultimate. Deploy a heavy turret and a pair of attack drones.",
			"discipline": &"engineer", "cooldown": 120.0, "duration": 16.0, "radius": 3.0,
			"magnitude": 26.0, "is_ultimate": true, "color": Color("62e6c3"), "unlock_level": 1, "icon": &"fort"},
		{"id": &"hyperfocus", "display_name": "Hyperfocus", "effect_id": &"ultimate_hyperfocus",
			"description": "Ultimate. Time dilates; your shots chain critical hits at weak points.",
			"discipline": &"pathfinder", "cooldown": 120.0, "duration": 6.0,
			"magnitude": 0.35, "is_ultimate": true, "color": Color("c79cff"), "unlock_level": 1, "icon": &"focus"},
	]
	for def in defs:
		list.append(_apply(AbilityData.new(), def))
	return list


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------

static func _enemies() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"ashen_scrapper", "display_name": "Ashen Scrapper", "faction": &"ashen", "role": &"rusher",
			"max_health": 80.0, "damage": 12.0, "move_speed": 5.5, "attack_range": 2.2,
			"preferred_range": 1.5, "attack_interval": 1.1, "ranged": false, "xp": 20, "salvage": 7,
			"body_color": Color("9a5236"), "accent_color": Color("ffb866"), "style": &"humanoid", "body_scale": 0.95},
		{"id": &"ashen_marksman", "display_name": "Ashen Marksman", "faction": &"ashen", "role": &"marksman",
			"max_health": 70.0, "damage": 9.0, "move_speed": 4.0, "attack_range": 42.0,
			"preferred_range": 26.0, "attack_interval": 1.7, "ranged": true, "xp": 28, "salvage": 9,
			"body_color": Color("d28b58"), "accent_color": Color("ffb866"), "style": &"humanoid"},
		{"id": &"ashen_bulwark", "display_name": "Ashen Bulwark", "faction": &"ashen", "role": &"tank",
			"max_health": 220.0, "max_shield": 60.0, "armor": 30.0, "damage": 16.0, "move_speed": 3.2,
			"attack_range": 2.6, "preferred_range": 2.0, "attack_interval": 1.8, "ranged": false,
			"xp": 55, "salvage": 18, "body_color": Color("6e4c3a"), "accent_color": Color("ffb866"),
			"style": &"heavy", "body_scale": 1.25},
		{"id": &"bloom_stalker", "display_name": "Bloom Stalker", "faction": &"bloom", "role": &"rusher",
			"max_health": 65.0, "damage": 14.0, "move_speed": 6.4, "attack_range": 2.2,
			"preferred_range": 1.5, "attack_interval": 0.9, "ranged": false, "xp": 24, "salvage": 8,
			"body_color": Color("7b3d70"), "accent_color": Color("c79cff"), "style": &"beast",
			"eye_color": Color("ff8ad8")},
		{"id": &"bloom_spitter", "display_name": "Bloom Spitter", "faction": &"bloom", "role": &"support",
			"max_health": 90.0, "damage": 11.0, "move_speed": 3.8, "attack_range": 32.0,
			"preferred_range": 20.0, "attack_interval": 2.2, "ranged": true, "xp": 32, "salvage": 10,
			"body_color": Color("4d2f52"), "accent_color": Color("c79cff"), "style": &"beast",
			"eye_color": Color("ff8ad8")},
		{"id": &"bloom_burrower", "display_name": "Bloom Burrower", "faction": &"bloom", "role": &"ambusher",
			"max_health": 110.0, "damage": 18.0, "move_speed": 4.6, "attack_range": 2.4,
			"preferred_range": 1.6, "attack_interval": 1.3, "ranged": false, "xp": 36, "salvage": 12,
			"body_color": Color("5c3f4b"), "accent_color": Color("ff8ad8"), "style": &"beast",
			"weakpoint_mult": 2.2},
		{"id": &"choir_sentinel", "display_name": "Choir Sentinel", "faction": &"choir", "role": &"flyer",
			"max_health": 60.0, "damage": 8.0, "move_speed": 5.2, "attack_range": 28.0,
			"preferred_range": 16.0, "attack_interval": 1.2, "ranged": true, "xp": 30, "salvage": 11,
			"body_color": Color("2c4e63"), "accent_color": Color("63b8ff"), "style": &"flyer",
			"eye_color": Color("b9f1ff")},
		{"id": &"choir_nullifier", "display_name": "Choir Nullifier", "faction": &"choir", "role": &"support",
			"max_health": 140.0, "max_shield": 120.0, "armor": 10.0, "damage": 6.0, "move_speed": 3.8,
			"attack_range": 34.0, "preferred_range": 22.0, "attack_interval": 2.0, "ranged": true,
			"xp": 45, "salvage": 16, "body_color": Color("30434f"), "accent_color": Color("63b8ff"),
			"style": &"humanoid", "body_scale": 1.1},
		{"id": &"ash_reaver", "display_name": "Ash Reaver", "faction": &"ashen", "role": &"elite",
			"max_health": 520.0, "max_shield": 80.0, "armor": 25.0, "damage": 24.0, "move_speed": 5.5,
			"attack_range": 3.0, "preferred_range": 3.0, "attack_interval": 0.8, "ranged": false,
			"xp": 180, "salvage": 60, "elite": true, "style": &"heavy", "body_scale": 1.5,
			"body_color": Color("7d3826"), "accent_color": Color("ff7a4a"), "loot_bonus": 2.0},
		{"id": &"bloom_matriarch", "display_name": "Bloom Matriarch", "faction": &"bloom", "role": &"elite",
			"max_health": 600.0, "damage": 18.0, "move_speed": 3.4, "attack_range": 40.0,
			"preferred_range": 24.0, "attack_interval": 1.6, "ranged": true, "xp": 200, "salvage": 65,
			"elite": true, "style": &"beast", "body_scale": 1.55, "body_color": Color("64355e"),
			"accent_color": Color("ff8ad8"), "loot_bonus": 2.0},
		{"id": &"choir_prime", "display_name": "Choir Prime", "faction": &"choir", "role": &"elite",
			"max_health": 460.0, "max_shield": 220.0, "armor": 15.0, "damage": 20.0, "move_speed": 4.8,
			"attack_range": 36.0, "preferred_range": 20.0, "attack_interval": 1.0, "ranged": true,
			"xp": 210, "salvage": 70, "elite": true, "style": &"flyer", "body_scale": 1.35,
			"body_color": Color("1e3a52"), "accent_color": Color("63b8ff"), "loot_bonus": 2.0},
		{"id": &"the_warden", "display_name": "The Warden", "faction": &"choir", "role": &"boss",
			"max_health": 2800.0, "max_shield": 400.0, "armor": 35.0, "damage": 30.0,
			"move_speed": 3.6, "attack_range": 48.0, "preferred_range": 22.0,
			"attack_interval": 1.2, "ranged": true, "xp": 800, "salvage": 300, "elite": true,
			"boss": true, "boss_phases": 3, "style": &"titan", "body_scale": 2.8,
			"body_color": Color("243744"), "accent_color": Color("63b8ff"), "loot_bonus": 5.0},
		{"id": &"bloomheart", "display_name": "Bloomheart", "faction": &"bloom", "role": &"boss",
			"max_health": 3200.0, "damage": 28.0, "move_speed": 3.2, "attack_range": 42.0,
			"preferred_range": 18.0, "attack_interval": 1.4, "ranged": true, "xp": 850,
			"salvage": 320, "elite": true, "boss": true, "boss_phases": 3, "style": &"beast",
			"body_scale": 2.6, "body_color": Color("512f5c"), "accent_color": Color("ff8ad8"),
			"eye_color": Color("ffb4ec"), "loot_bonus": 5.0},
		# --- Expansion roster: more monsters and elites ---------------------
		{"id": &"ashen_sapper", "display_name": "Ashen Sapper", "faction": &"ashen", "role": &"rusher",
			"max_health": 60.0, "damage": 28.0, "move_speed": 5.8, "attack_range": 2.2,
			"preferred_range": 1.5, "attack_interval": 1.2, "ranged": false, "xp": 30, "salvage": 9,
			"body_color": Color("8c4a2e"), "accent_color": Color("ff7a4a"), "style": &"humanoid",
			"body_scale": 0.92, "behavior_flags": PackedStringArray(["volatile_death"]),
			"loot_bonus": 1.1},
		{"id": &"ashen_hound", "display_name": "Ash Hound", "faction": &"ashen", "role": &"rusher",
			"max_health": 55.0, "damage": 13.0, "move_speed": 6.8, "attack_range": 2.0,
			"preferred_range": 1.4, "attack_interval": 0.85, "ranged": false, "xp": 22, "salvage": 7,
			"body_color": Color("5e3b2e"), "accent_color": Color("ffb866"), "style": &"beast",
			"body_scale": 0.85},
		{"id": &"bloom_lasher", "display_name": "Bloom Lasher", "faction": &"bloom", "role": &"ambusher",
			"max_health": 95.0, "damage": 18.0, "move_speed": 5.6, "attack_range": 2.6,
			"preferred_range": 1.6, "attack_interval": 1.25, "ranged": false, "xp": 34, "salvage": 11,
			"body_color": Color("5c3f4b"), "accent_color": Color("ff8ad8"), "style": &"beast",
			"weakpoint_mult": 2.4},
		{"id": &"bloom_seeder", "display_name": "Bloom Seeder", "faction": &"bloom", "role": &"support",
			"max_health": 100.0, "damage": 8.0, "move_speed": 3.4, "attack_range": 36.0,
			"preferred_range": 24.0, "attack_interval": 2.6, "ranged": true, "xp": 36, "salvage": 12,
			"body_color": Color("4d2f52"), "accent_color": Color("c79cff"), "style": &"beast",
			"eye_color": Color("ffb4ec")},
		{"id": &"choir_wisp", "display_name": "Choir Wisp", "faction": &"choir", "role": &"rusher",
			"max_health": 45.0, "max_shield": 40.0, "damage": 7.0, "move_speed": 6.0,
			"attack_range": 30.0, "preferred_range": 16.0, "attack_interval": 1.0, "ranged": true,
			"xp": 26, "salvage": 9, "body_color": Color("24455a"), "accent_color": Color("63b8ff"),
			"style": &"flyer", "body_scale": 0.8, "eye_color": Color("b9f1ff")},
		{"id": &"choir_weaver", "display_name": "Choir Weaver", "faction": &"choir", "role": &"support",
			"max_health": 120.0, "max_shield": 80.0, "damage": 5.0, "move_speed": 3.6,
			"attack_range": 34.0, "preferred_range": 22.0, "attack_interval": 1.8, "ranged": true,
			"xp": 40, "salvage": 14, "body_color": Color("30434f"), "accent_color": Color("63b8ff"),
			"style": &"humanoid", "body_scale": 1.05},
		{"id": &"ashen_warlord", "display_name": "Ashen Warlord", "faction": &"ashen", "role": &"elite",
			"max_health": 700.0, "max_shield": 100.0, "armor": 25.0, "damage": 28.0,
			"move_speed": 4.8, "attack_range": 3.0, "preferred_range": 2.6, "attack_interval": 0.9,
			"ranged": false, "xp": 220, "salvage": 70, "elite": true, "style": &"heavy",
			"body_scale": 1.55, "body_color": Color("6b3022"), "accent_color": Color("ff6e6e"),
			"loot_bonus": 2.2},
		{"id": &"bloom_hydra", "display_name": "Bloom Hydra", "faction": &"bloom", "role": &"elite",
			"max_health": 650.0, "damage": 22.0, "move_speed": 4.6, "attack_range": 38.0,
			"preferred_range": 20.0, "attack_interval": 1.3, "ranged": true, "xp": 230, "salvage": 75,
			"elite": true, "style": &"beast", "body_scale": 1.6, "body_color": Color("5c2f5e"),
			"accent_color": Color("ff8ad8"), "eye_color": Color("ffb4ec"), "loot_bonus": 2.2},
		{"id": &"choir_herald", "display_name": "Choir Herald", "faction": &"choir", "role": &"elite",
			"max_health": 500.0, "max_shield": 260.0, "armor": 15.0, "damage": 20.0,
			"move_speed": 5.4, "attack_range": 36.0, "preferred_range": 18.0, "attack_interval": 1.0,
			"ranged": true, "xp": 240, "salvage": 80, "elite": true, "style": &"flyer",
			"body_scale": 1.3, "body_color": Color("1a3347"), "accent_color": Color("63b8ff"),
			"loot_bonus": 2.2},
		{"id": &"rift_colossus", "display_name": "Rift Colossus", "faction": &"choir", "role": &"boss",
			"max_health": 3600.0, "max_shield": 500.0, "armor": 35.0, "damage": 34.0,
			"move_speed": 3.6, "attack_range": 46.0, "preferred_range": 22.0,
			"attack_interval": 1.2, "ranged": true, "xp": 900, "salvage": 350, "elite": true,
			"boss": true, "boss_phases": 3, "style": &"titan", "body_scale": 2.9,
			"body_color": Color("2b2745"), "accent_color": Color("c79cff"),
			"eye_color": Color("e8d4ff"), "loot_bonus": 5.0},
	]
	for def in defs:
		list.append(_apply(EnemyData.new(), def))
	return list


# ---------------------------------------------------------------------------
# Allies, pets, base
# ---------------------------------------------------------------------------

static func _allies() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"mara_voss", "display_name": "Mara Voss", "role": &"medic",
			"description": "A field medic with a dry laugh and an unreasonable attachment to keeping people breathing.",
			"weapon_id": &"wisp_smg", "ability_effect": &"mender_field",
			"passive_text": "Periodically restores squad shields.", "color": Color("62e6c3"),
			"unlock_text": "Found at the Waystation infirmary."},
		{"id": &"rook", "display_name": "Rook", "role": &"heavy",
			"description": "Ex-Ashen enforcer. Speaks little, carries a great deal.",
			"weapon_id": &"cantor_lmg", "ability_effect": &"aegis_wall",
			"passive_text": "Draws enemy fire and reduces incoming squad damage.", "color": Color("ffb866"),
			"unlock_text": "Recruited after the Relay job."},
		{"id": &"irie_sol", "display_name": "Irie Sol", "role": &"scout",
			"description": "A pathfinder who treats the Reach like a puzzle worth solving.",
			"weapon_id": &"longview_dmr", "ability_effect": &"pulse_scan",
			"passive_text": "Marks weak points and spots caches at range.", "color": Color("6fa8ff"),
			"unlock_text": "Found in the Glass Flats."},
		{"id": &"toma_nix", "display_name": "Toma Nix", "role": &"engineer",
			"description": "Keeps the Waystation alive with tape, spite and a worrying amount of voltage.",
			"weapon_id": &"breakline_sg", "ability_effect": &"deploy_turret",
			"passive_text": "Deploys a shock turret in combat.", "color": Color("c79cff"),
			"unlock_text": "Unlocked with the Foundry."},
	]
	for def in defs:
		list.append(_apply(AllyData.new(), def))
	return list


static func _pets() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"mote", "display_name": "Mote", "role": &"support",
			"description": "A floating lantern that insists on keeping you alive.",
			"effect": &"mote_shield", "cooldown": 14.0, "magnitude": 30.0,
			"color": Color("62e6c3"), "shell_color": Color("f4efe5")},
		{"id": &"cinder", "display_name": "Cinder", "role": &"combat",
			"description": "A tiny furnace with a big opinion about your enemies.",
			"effect": &"cinder_bolt", "cooldown": 3.0, "magnitude": 24.0,
			"color": Color("ffb866"), "shell_color": Color("d28b58")},
		{"id": &"pip", "display_name": "Pip", "role": &"utility",
			"description": "A curious scout that finds what you would have missed.",
			"effect": &"pip_scan", "cooldown": 12.0, "magnitude": 30.0,
			"color": Color("6fa8ff"), "shell_color": Color("f4efe5")},
	]
	for def in defs:
		list.append(_apply(PetData.new(), def))
	return list


static func _base_modules() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"command_nexus", "display_name": "Command Nexus", "footprint": Vector2i(3, 3),
			"description": "The heart of Waystation Kestrel. Unlocks outpost tiers and improves contract XP.",
			"costs": PackedInt32Array([0, 250, 700]), "core_costs": PackedInt32Array([0, 2, 5]),
			"power": 0, "effects": PackedStringArray(["+10% contract XP per tier"])},
		{"id": &"foundry", "display_name": "Foundry", "footprint": Vector2i(2, 2),
			"description": "Craft and upgrade weapons. Unlocks mod rerolls at higher tiers.",
			"costs": PackedInt32Array([120, 320, 820]), "core_costs": PackedInt32Array([0, 1, 4]),
			"power": 1, "effects": PackedStringArray(["Weapon crafting", "Mod reroll at Tier 2"])},
		{"id": &"armory", "display_name": "Armory", "footprint": Vector2i(2, 2),
			"description": "Expand the gear stash and re-roll one affix per visit.",
			"costs": PackedInt32Array([100, 280, 700]), "core_costs": PackedInt32Array([0, 1, 3]),
			"power": 1, "effects": PackedStringArray(["+16 stash slots", "Affix reroll at Tier 2"])},
		{"id": &"infirmary", "display_name": "Infirmary", "footprint": Vector2i(2, 2),
			"description": "Squad recovery. Reduces the cost of a failed deployment.",
			"costs": PackedInt32Array([90, 240, 600]), "core_costs": PackedInt32Array([0, 1, 3]),
			"power": 1, "effects": PackedStringArray(["Restore squad HP", "Keep 10/20% satchel value on death"])},
		{"id": &"barracks", "display_name": "Barracks", "footprint": Vector2i(3, 2),
			"description": "Houses Wardens. Allows two active squadmates and ranks them up.",
			"costs": PackedInt32Array([110, 300, 750]), "core_costs": PackedInt32Array([0, 1, 4]),
			"power": 1, "effects": PackedStringArray(["Two active Wardens", "Ally rank cap +1"])},
		{"id": &"drift_den", "display_name": "Drift Den", "footprint": Vector2i(2, 2),
			"description": "A warm little workshop for Driftlings. Unlocks pet upgrades and shells.",
			"costs": PackedInt32Array([80, 220, 540]), "core_costs": PackedInt32Array([0, 1, 2]),
			"power": 1, "effects": PackedStringArray(["Pet rank cap +1", "Driftling shells"])},
		{"id": &"reactor", "display_name": "Reactor", "footprint": Vector2i(2, 3),
			"description": "Powers the outpost and shaves a little time off ability cooldowns.",
			"costs": PackedInt32Array([150, 380, 900]), "core_costs": PackedInt32Array([1, 2, 5]),
			"power": 3, "effects": PackedStringArray(["+8% ability cooldown recovery per tier"])},
		{"id": &"signal_array", "display_name": "Signal Array", "footprint": Vector2i(2, 2),
			"description": "Cuts through rift noise. Better contracts and more map intel.",
			"costs": PackedInt32Array([130, 340, 800]), "core_costs": PackedInt32Array([0, 1, 4]),
			"power": 2, "effects": PackedStringArray(["Contract quality", "Exfil and POI intel"])},
	]
	for def in defs:
		list.append(_apply(BaseModuleData.new(), def))
	return list


# ---------------------------------------------------------------------------
# Contracts, mutators, rift mods
# ---------------------------------------------------------------------------

static func _contracts() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"salvage_sweep", "display_name": "Salvage Sweep", "required_threat": 1,
			"description": "Recover three memory caches from the Reach before it folds.",
			"objective_types": PackedStringArray(["cache"]), "base_reward": 160, "core_reward": 1,
			"xp_reward": 130, "gear_rolls": 1, "objective_label": "Recover caches",
			"flavor": "The colony's ledger is scattered out there. Bring back what still matters."},
		{"id": &"relay_sabotage", "display_name": "Relay Sabotage", "required_threat": 1,
			"description": "Hack two Ashen relay spires and break their grip on the valley.",
			"objective_types": PackedStringArray(["relay"]), "base_reward": 180, "core_reward": 1,
			"xp_reward": 145, "gear_rolls": 1, "objective_label": "Disrupt relays",
			"flavor": "If the Ashen can talk across the valley, they can hunt across it."},
		{"id": &"headhunt", "display_name": "Headhunt", "required_threat": 2,
			"description": "Track and eliminate an elite command signature.",
			"objective_types": PackedStringArray(["hunt"]), "base_reward": 240, "core_reward": 2,
			"xp_reward": 200, "gear_rolls": 2, "objective_label": "Eliminate the target",
			"flavor": "Someone out there has been giving orders. Stop the voice."},
		{"id": &"rescue", "display_name": "Rescue Signal", "required_threat": 2,
			"description": "Find a lost Warden, free them, and get them to exfil.",
			"objective_types": PackedStringArray(["rescue"]), "base_reward": 220, "core_reward": 2,
			"xp_reward": 190, "gear_rolls": 1, "objective_label": "Rescue the Warden",
			"flavor": "No one gets left in the fold. Not while Kestrel still answers."},
		{"id": &"survey", "display_name": "Anomaly Survey", "required_threat": 1,
			"description": "Scan three rift anomalies to give the Waystation warning.",
			"objective_types": PackedStringArray(["survey"]), "base_reward": 200, "core_reward": 2,
			"xp_reward": 170, "gear_rolls": 1, "objective_label": "Scan anomalies",
			"flavor": "The Reach is changing. We need to know how fast."},
		{"id": &"vault_breach", "display_name": "Vault Breach", "required_threat": 3,
			"description": "Breach a sealed Vault and destroy whatever is waking inside.",
			"objective_types": PackedStringArray(["vault"]), "base_reward": 380, "core_reward": 4,
			"xp_reward": 320, "gear_rolls": 3, "objective_label": "Breach the Vault",
			"flavor": "Some doors were sealed for a reason. We are going to need the reason."},
	]
	for def in defs:
		list.append(_apply(ContractData.new(), def))
	return list


static func _rift_mods() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"volatile_rounds", "display_name": "Volatile Rounds", "stat": &"damage_mult",
			"value": 1.15, "description": "Kills cause a small volatile burst.", "color": Color("ffb866")},
		{"id": &"conductor", "display_name": "Conductor", "stat": &"status_power",
			"value": 1.3, "description": "Shock effects chain to one extra target.", "color": Color("62e6c3")},
		{"id": &"siphon", "display_name": "Siphon", "stat": &"ability_power",
			"value": 1.1, "description": "Critical hits restore a little health.", "color": Color("ff6e6e")},
		{"id": &"tailwind", "display_name": "Tailwind", "stat": &"move_speed",
			"value": 1.1, "description": "Reloading grants a short burst of speed.", "color": Color("6fa8ff")},
		{"id": &"drone_commander", "display_name": "Drone Commander", "stat": &"pet_power",
			"value": 1.35, "description": "Pets and deployables deal more damage.", "color": Color("62e6c3")},
		{"id": &"ricochet", "display_name": "Ricochet", "stat": &"damage_mult",
			"value": 1.08, "description": "Projectiles that miss can bounce once.", "color": Color("ffb866")},
		{"id": &"executioner", "display_name": "Executioner", "stat": &"crit_chance",
			"value": 0.08, "description": "Headshots on staggered enemies deal bonus damage.", "color": Color("c79cff")},
		{"id": &"overload_core", "display_name": "Overload Core", "stat": &"reload_speed",
			"value": 1.18, "description": "Reloads are faster but generate heat.", "color": Color("ffb866")},
		{"id": &"scavenger", "display_name": "Scavenger", "stat": &"luck",
			"value": 0.15, "description": "More salvage from destroyed enemies.", "color": Color("63b8ff")},
		{"id": &"phase_shift", "display_name": "Phase Shift", "stat": &"cooldown_mult",
			"value": 0.85, "description": "Abilities recharge faster after a kill.", "color": Color("c79cff")},
		{"id": &"hardlight", "display_name": "Hardlight", "stat": &"shield_max",
			"value": 25.0, "op": &"add", "description": "Gain a permanent overshield.", "color": Color("62e6c3")},
		{"id": &"last_stand", "display_name": "Last Stand", "stat": &"armor",
			"value": 25.0, "op": &"add", "description": "Gain armor when below 35% health.", "color": Color("ff6e6e")},
	]
	for def in defs:
		list.append(_apply(RiftModData.new(), def))
	return list


static func _mutators() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"overcharged", "display_name": "Overcharged", "description": "Enemies deal more damage.",
			"enemy_damage_mult": 1.2, "threat_bonus": 1, "reward_bonus": 0.25, "color": Color("ffb866")},
		{"id": &"ironhide", "display_name": "Ironhide", "description": "Enemies have reinforced hides.",
			"enemy_health_mult": 1.25, "threat_bonus": 1, "reward_bonus": 0.2, "color": Color("c79cff")},
		{"id": &"hunter_season", "display_name": "Hunter Season", "description": "More elites stalk the Reach.",
			"elite_chance_bonus": 0.2, "threat_bonus": 1, "reward_bonus": 0.25, "color": Color("ff6e6e")},
		{"id": &"no_second_chances", "display_name": "No Second Chances",
			"description": "Self-revive is disabled. Extract or die.", "threat_bonus": 2, "reward_bonus": 0.4,
			"color": Color("ff6e6e")},
		{"id": &"rich_reach", "display_name": "Rich Reach", "description": "More salvage, more danger.",
			"threat_bonus": 1, "reward_bonus": 0.35, "color": Color("ffc16b")},
		{"id": &"low_gravity", "display_name": "Low Gravity", "description": "Jump higher; land softer.",
			"threat_bonus": 0, "reward_bonus": 0.1, "color": Color("6fa8ff")},
		{"id": &"early_storm", "display_name": "Early Storm", "description": "The Collapse begins sooner.",
			"threat_bonus": 1, "reward_bonus": 0.25, "color": Color("c79cff")},
		{"id": &"swarm", "display_name": "Swarm", "description": "More enemies, less breathing room.",
			"threat_bonus": 1, "reward_bonus": 0.2, "color": Color("62e6c3")},
	]
	for def in defs:
		list.append(_apply(MutatorData.new(), def))
	return list


# ---------------------------------------------------------------------------
# Grenades, gear, cosmetics, affixes
# ---------------------------------------------------------------------------

static func _grenades() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"frag", "display_name": "Frag", "effect_id": &"frag", "damage": 90.0,
			"radius": 5.0, "cooldown": 18.0, "description": "Bouncing fragmentation charge.",
			"color": Color("ffb866")},
		{"id": &"shock", "display_name": "Shock", "effect_id": &"shock", "damage": 35.0,
			"radius": 4.0, "duration": 2.0, "cooldown": 20.0,
			"description": "Stuns and chains between targets.", "color": Color("62e6c3")},
		{"id": &"smoke", "display_name": "Veil", "effect_id": &"smoke", "damage": 0.0,
			"radius": 6.0, "duration": 8.0, "cooldown": 22.0,
			"description": "Blocks enemy sightlines and marks the area for exfil.", "color": Color("93a5a8")},
	]
	for def in defs:
		list.append(_apply(GrenadeData.new(), def))
	return list


static func _item_templates() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"vanguard_helm", "display_name": "Vanguard Helm", "slot": &"helmet", "set_id": &"vanguard",
			"armor": 8.0, "base_stats": {&"health_max": 12.0}, "value": 60, "color": Color("f4efe5")},
		{"id": &"pathfinder_visor", "display_name": "Pathfinder Visor", "slot": &"helmet", "set_id": &"pathfinder",
			"armor": 5.0, "base_stats": {&"crit_chance": 0.02, &"handling": 0.05}, "value": 60,
			"color": Color("6fa8ff")},
		{"id": &"aegis_chest", "display_name": "Aegis Chest", "slot": &"chest", "set_id": &"vanguard",
			"armor": 14.0, "base_stats": {&"shield_max": 12.0}, "value": 80, "color": Color("f4efe5")},
		{"id": &"ghost_chest", "display_name": "Ghost Weave", "slot": &"chest", "set_id": &"ghost",
			"armor": 7.0, "base_stats": {&"move_speed": 0.25, &"reload_speed": 0.06}, "value": 80,
			"color": Color("26383d")},
		{"id": &"engineer_legs", "display_name": "Engineer Greaves", "slot": &"legs", "set_id": &"engineer",
			"armor": 9.0, "base_stats": {&"cooldown_mult": -0.03}, "value": 70, "color": Color("62e6c3")},
		{"id": &"striders", "display_name": "Striders", "slot": &"legs", "set_id": &"pathfinder",
			"armor": 6.0, "base_stats": {&"sprint_speed": 0.3}, "value": 70, "color": Color("ffb866")},
		{"id": &"storm_cloak", "display_name": "Storm Cloak", "slot": &"cloak", "set_id": &"ghost",
			"armor": 4.0, "base_stats": {&"status_power": 0.08}, "value": 65, "color": Color("30434f")},
		{"id": &"reactive_cloak", "display_name": "Reactive Cloak", "slot": &"cloak", "set_id": &"engineer",
			"armor": 6.0, "base_stats": {&"ability_power": 0.06}, "value": 65, "color": Color("3a474b")},
		{"id": &"core_charm", "display_name": "Core Charm", "slot": &"charm", "set_id": &"vanguard",
			"armor": 2.0, "base_stats": {&"armor": 8.0, &"luck": 0.05}, "value": 55, "color": Color("ffc16b")},
		{"id": &"scavenger_tag", "display_name": "Scavenger Tag", "slot": &"charm", "set_id": &"pathfinder",
			"armor": 0.0, "base_stats": {&"luck": 0.15, &"damage_mult": 0.02}, "value": 55,
			"color": Color("d28b58")},
	]
	for def in defs:
		list.append(_apply(ItemTemplate.new(), def))
	return list


static func _cosmetics() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		{"id": &"suit_wayfinder", "display_name": "Wayfinder", "slot": &"suit", "color": Color("f4efe5"), "accent": Color("62e6c3")},
		{"id": &"suit_dust", "display_name": "Dust Runner", "slot": &"suit", "color": Color("d28b58"), "accent": Color("ffb866")},
		{"id": &"suit_choir", "display_name": "Choir Salvage", "slot": &"suit", "color": Color("30434f"), "accent": Color("63b8ff")},
		{"id": &"suit_bloom", "display_name": "Bloomweave", "slot": &"suit", "color": Color("51315c"), "accent": Color("c79cff")},
		{"id": &"suit_glass", "display_name": "Glasslight", "slot": &"suit", "color": Color("e7e2d5"), "accent": Color("6fa8ff")},
		{"id": &"suit_ash", "display_name": "Ashen Coat", "slot": &"suit", "color": Color("3a2b2b"), "accent": Color("ff6e6e")},
		{"id": &"dye_mint", "display_name": "Signal Mint", "slot": &"dye", "color": Color("62e6c3")},
		{"id": &"dye_amber", "display_name": "Waystation Amber", "slot": &"dye", "color": Color("ffb866")},
		{"id": &"dye_blue", "display_name": "Choir Blue", "slot": &"dye", "color": Color("63b8ff")},
		{"id": &"dye_violet", "display_name": "Rift Violet", "slot": &"dye", "color": Color("c79cff")},
		{"id": &"dye_ink", "display_name": "Ink", "slot": &"dye", "color": Color("121a1d")},
		{"id": &"dye_ivory", "display_name": "Ivory", "slot": &"dye", "color": Color("f4efe5")},
		{"id": &"dye_rust", "display_name": "Rust", "slot": &"dye", "color": Color("d28b58")},
		{"id": &"dye_coral", "display_name": "Coral", "slot": &"dye", "color": Color("ff6e6e")},
		{"id": &"skin_lattice", "display_name": "Lattice Standard", "slot": &"weapon_skin", "color": Color("f4efe5"), "accent": Color("62e6c3")},
		{"id": &"skin_blackout", "display_name": "Blackout", "slot": &"weapon_skin", "color": Color("121a1d"), "accent": Color("93a5a8")},
		{"id": &"skin_ember", "display_name": "Ember Worn", "slot": &"weapon_skin", "color": Color("d28b58"), "accent": Color("ff6e6e")},
		{"id": &"skin_bloom", "display_name": "Bloom-touched", "slot": &"weapon_skin", "color": Color("51315c"), "accent": Color("c79cff")},
		{"id": &"skin_ice", "display_name": "Glass Ice", "slot": &"weapon_skin", "color": Color("e7e2d5"), "accent": Color("6fa8ff")},
		{"id": &"shell_default", "display_name": "Kestrel Shell", "slot": &"pet_shell", "color": Color("f4efe5"), "accent": Color("62e6c3")},
		{"id": &"shell_ember", "display_name": "Ember Shell", "slot": &"pet_shell", "color": Color("d28b58"), "accent": Color("ffb866")},
		{"id": &"shell_night", "display_name": "Night Shell", "slot": &"pet_shell", "color": Color("26383d"), "accent": Color("6fa8ff")},
	]
	for def in defs:
		list.append(_apply(CosmeticData.new(), def))
	return list


static func _affixes() -> Array:
	return [
		{"id": &"reinforced", "display_name": "Reinforced", "stat": &"armor", "op": &"add", "values": PackedFloat32Array([4.0, 7.0, 10.0, 14.0, 18.0]), "slots": PackedStringArray(["helmet", "chest", "legs", "cloak"])},
		{"id": &"vital", "display_name": "Vital", "stat": &"health_max", "op": &"add", "values": PackedFloat32Array([8.0, 12.0, 18.0, 25.0, 34.0]), "slots": PackedStringArray(["helmet", "chest", "legs", "charm"])},
		{"id": &"capacitor", "display_name": "Capacitor", "stat": &"shield_max", "op": &"add", "values": PackedFloat32Array([6.0, 10.0, 15.0, 22.0, 30.0]), "slots": PackedStringArray(["chest", "cloak", "charm"])},
		{"id": &"steady", "display_name": "Steady", "stat": &"handling", "op": &"add", "values": PackedFloat32Array([0.02, 0.04, 0.06, 0.09, 0.12]), "slots": PackedStringArray(["primary", "sidearm", "helmet"])},
		{"id": &"quick", "display_name": "Quick", "stat": &"reload_speed", "op": &"mult", "values": PackedFloat32Array([1.04, 1.07, 1.1, 1.14, 1.18]), "slots": PackedStringArray(["primary", "sidearm", "chest"])},
		{"id": &"sharp", "display_name": "Sharp", "stat": &"crit_chance", "op": &"add", "values": PackedFloat32Array([0.01, 0.02, 0.03, 0.045, 0.06]), "slots": PackedStringArray(["primary", "sidearm", "helmet", "charm"])},
		{"id": &"lucky", "display_name": "Lucky", "stat": &"luck", "op": &"add", "values": PackedFloat32Array([0.03, 0.05, 0.08, 0.12, 0.16]), "slots": PackedStringArray(["charm", "helmet", "cloak"])},
		{"id": &"fleet", "display_name": "Fleet", "stat": &"move_speed", "op": &"add", "values": PackedFloat32Array([0.1, 0.18, 0.26, 0.36, 0.48]), "slots": PackedStringArray(["legs", "cloak"])},
	]


static func _perks() -> Array:
	var list: Array = []
	var defs: Array[Dictionary] = [
		# Vanguard
		{"id": &"perk_bulwark", "display_name": "Bulwark", "discipline": &"vanguard", "tier": 1,
			"description": "Reinforced plating. +12 armor.", "stat": &"armor", "value": 12.0,
			"color": Color("ffb866"), "icon": &"shield"},
		{"id": &"perk_adrenaline", "display_name": "Adrenaline", "discipline": &"vanguard", "tier": 2,
			"description": "Move 12% faster when below half health.", "stat": &"move_speed", "value": 0.6,
			"requires": &"perk_bulwark", "color": Color("ffb866"), "icon": &"heart"},
		{"id": &"perk_unyielding", "display_name": "Unyielding", "discipline": &"vanguard", "tier": 3,
			"description": "+20 maximum health.", "stat": &"health_max", "value": 20.0,
			"requires": &"perk_adrenaline", "color": Color("ffb866"), "icon": &"tide"},
		{"id": &"perk_impact", "display_name": "Impact", "discipline": &"vanguard", "tier": 4,
			"description": "Seismic and kinetic hits deal +15% damage.", "stat": &"ability_power", "value": 0.15,
			"requires": &"perk_unyielding", "color": Color("ffb866"), "icon": &"impact"},
		# Infiltrator
		{"id": &"perk_ghost_step", "display_name": "Ghost Step", "discipline": &"infiltrator", "tier": 1,
			"description": "+7% movement speed.", "stat": &"move_speed", "value": 0.35,
			"color": Color("6fa8ff"), "icon": &"boot"},
		{"id": &"perk_predator", "display_name": "Predator", "discipline": &"infiltrator", "tier": 2,
			"description": "+6% critical chance.", "stat": &"crit_chance", "value": 0.06,
			"requires": &"perk_ghost_step", "color": Color("6fa8ff"), "icon": &"eye"},
		{"id": &"perk_slipstream", "display_name": "Slipstream", "discipline": &"infiltrator", "tier": 3,
			"description": "Reload 12% faster.", "stat": &"reload_speed", "value": 1.12,
			"requires": &"perk_predator", "color": Color("6fa8ff"), "icon": &"wind"},
		{"id": &"perk_opportunist", "display_name": "Opportunist", "discipline": &"infiltrator", "tier": 4,
			"description": "+25% critical damage.", "stat": &"crit_mult", "value": 0.25,
			"requires": &"perk_slipstream", "color": Color("6fa8ff"), "icon": &"target"},
		# Engineer
		{"id": &"perk_drone_link", "display_name": "Drone Link", "discipline": &"engineer", "tier": 1,
			"description": "+20% pet and deployable power.", "stat": &"pet_power", "value": 0.2,
			"color": Color("62e6c3"), "icon": &"turret"},
		{"id": &"perk_overclocked", "display_name": "Overclocked", "discipline": &"engineer", "tier": 2,
			"description": "Abilities recharge 8% faster.", "stat": &"cooldown_mult", "value": 0.92,
			"requires": &"perk_drone_link", "color": Color("62e6c3"), "icon": &"bolt"},
		{"id": &"perk_fortified", "display_name": "Fortified", "discipline": &"engineer", "tier": 3,
			"description": "+20 shield and faster shield recovery.", "stat": &"shield_max", "value": 20.0,
			"requires": &"perk_overclocked", "color": Color("62e6c3"), "icon": &"wall"},
		{"id": &"perk_salvage", "display_name": "Salvage Protocols", "discipline": &"engineer", "tier": 4,
			"description": "+18% loot fortune.", "stat": &"luck", "value": 0.18,
			"requires": &"perk_fortified", "color": Color("62e6c3"), "icon": &"crate"},
		# Pathfinder
		{"id": &"perk_focus", "display_name": "Focus", "discipline": &"pathfinder", "tier": 1,
			"description": "+12% weapon handling.", "stat": &"handling", "value": 0.12,
			"color": Color("c79cff"), "icon": &"crosshair"},
		{"id": &"perk_longshot", "display_name": "Longshot", "discipline": &"pathfinder", "tier": 2,
			"description": "+8% weapon damage at range.", "stat": &"damage_mult", "value": 0.08,
			"requires": &"perk_focus", "color": Color("c79cff"), "icon": &"arrow"},
		{"id": &"perk_surveyor", "display_name": "Surveyor", "discipline": &"pathfinder", "tier": 3,
			"description": "+10% ability range and radar radius.", "stat": &"ability_range", "value": 0.1,
			"requires": &"perk_longshot", "color": Color("c79cff"), "icon": &"radar"},
		{"id": &"perk_executioner", "display_name": "Executioner", "discipline": &"pathfinder", "tier": 4,
			"description": "+8% critical chance against weak points.", "stat": &"crit_chance", "value": 0.08,
			"requires": &"perk_surveyor", "color": Color("c79cff"), "icon": &"skull"},
	]
	var tier_levels := [1, 4, 7, 10]
	for def in defs:
		if not def.has("unlock_level"):
			def["unlock_level"] = int(tier_levels[clampi(int(def.get("tier", 1)) - 1, 0, tier_levels.size() - 1)])
		list.append(_apply(PerkData.new(), def))
	return list
