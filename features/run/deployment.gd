class_name Deployment
extends Node3D
## Orchestrates one seeded deployment: procedural world, player, squad, enemies,
## objectives, exfiltration, collapse storm, and results.

signal progress_changed(value: float, label: String)
signal ready_to_play(player: Node)
signal finished(result: Dictionary)

const ENEMY_SCRIPT_PATH := "res://features/ai/enemy_agent.gd"
const ALLY_SCRIPT_PATH := "res://features/companions/ally_agent.gd"
const PET_SCRIPT_PATH := "res://features/companions/pet_agent.gd"
## Optional subsystems (features/vehicles, features/cutscene): loaded by path so
## a stripped build or an in-progress branch degrades to "not available" instead
## of failing to compile the whole deployment.
const VEHICLE_SITES_PATH := "res://features/vehicles/vehicle_sites.gd"

var contract_id: StringName = &"salvage_sweep"
var seed_value: int = 0
var threat: int = 1
var mutators: Array = []
var difficulty_id: StringName = &""
var game_mode: StringName = &"normal"
var map_id: StringName = &""
var player: Player = null
var world = null
var started: bool = false
var ending: bool = false

var _rng := RandomNumberGenerator.new()
var _actors_root: Node3D
var _site_root: Node3D
var _world_script: Script = null
var _enemy_script: Script = null
var _objective_sites: Array[ObjectiveSite] = []
var _exfil_sites: Array[ExtractionBeacon] = []
var _hostiles: Array[Node] = []
var _storm_notified: bool = false
var _storm_damage_timer: float = 0.0
var _extraction_wave_timer: float = 0.0
var _extraction_ship: Node3D = null
var _objective_targets: Dictionary = {}
var _objectives_completed: int = 0
var _looted: int = 0
var companion_manager: Node = null
var _active_boss: Node = null
## Rideables spawned for this run (features/vehicles), and the throttles for the
## vehicle HUD and the music state machine.
var _rideables: Array = []
var _rideable_timer := 0.0
var _vehicle_hud_open := false
## Breachable loot props placed at POI clutter anchors (0.3.0 content streams).
var _loot_props: Array = []
var _music_timer := 1.0
var _music_track: StringName = &""
var _ambience_id: StringName = &""
## One boss confrontation shot per boss instance; exfil plays exactly once.
var _boss_cinematics: Dictionary = {}
var _exfil_cinematic_done := false
var _exfil_cinematic_playing := false
var _compass_timer: float = 0.0
var _scheduled_events: Array[Dictionary] = []
var _event_cursor: int = 0
var _event_timer: float = 0.0
var _director_timer: float = 60.0
var _endgame_cursor: int = 0
var _late_notice_stage: int = -1
var _discovered_pois: Dictionary = {}
var _poi_cache: Array[Dictionary] = []
var _poi_markers: Array[Node] = []
var _garrisoned_pois: Dictionary = {}
var _loot_caches: Array[Node] = []
var _bounty_targets: Array[Node] = []
var _shrine_site: ObjectiveSite = null
var _contract_label: String = "Contract"
var _mission_trackers: Array = []
var _staging_timer: float = 1.0
var _prune_timer: float = 5.0
var _map_preset: Dictionary = {}
var _dungeon_entries: Array[Dictionary] = []
var _dungeon_root: Node3D = null
var _in_dungeon: bool = false
var _active_dungeon: Node = null
var _dungeon_return_position := Vector3.ZERO
var _dungeon_cleared: int = 0
var _tutorial_director: Node = null
var _staged_contract: bool = false
var _stage_index: int = 0
var _stage_sites: Array = []
var _stage_sites_completed: int = 0
var _used_poi_indices: Dictionary = {}

const LOOT_CACHE_SCRIPT: Script = preload("res://features/run/loot_cache.gd")
const WORLD_MARKER_SCRIPT: Script = preload("res://features/run/world_marker.gd")
const EXTRACTION_SHIP_SCRIPT: Script = preload("res://features/run/extraction_ship.gd")
const DUNGEON_RUNTIME_SCRIPT: Script = preload("res://features/dungeon/dungeon_runtime.gd")
const DUNGEON_ENTRANCE_SCRIPT: Script = preload("res://features/dungeon/dungeon_entrance.gd")
const TRAINING_TARGET_SCRIPT: Script = preload("res://features/tutorial/training_target.gd")
const TUTORIAL_DIRECTOR_SCRIPT: Script = preload("res://features/tutorial/tutorial_director.gd")

const MAX_ACTIVE_HOSTILES: int = 48
const DIRECTOR_GRACE: float = 40.0
const POI_DISCOVERY_RADIUS: float = 180.0
const GARRISON_STAGE_RADIUS: float = 140.0
const HOSTILE_PRUNE_RADIUS: float = 300.0
const MAX_LOOT_CACHES: int = 24
## Clutter-anchored breachable props per run (POI detail + loot spread).
const MAX_LOOT_PROPS: int = 10
const CACHE_SITE_CLEARANCE: float = 22.0
const ENDGAME_EVENTS: Array[Dictionary] = [
	{"fraction": 0.58, "id": &"hunter_pack", "title": "Hunter Pack", "icon": &"paw", "color": Color("ffb866"),
		"text": "A pack of hunters just caught your scent. They are moving fast."},
	{"fraction": 0.72, "id": &"rift_incursion", "title": "Rift Incursion", "icon": &"bolt", "color": Color("c79cff"),
		"text": "Reality tears open nearby. Something ancient steps through."},
	{"fraction": 0.86, "id": &"collapse_surge", "title": "Collapse Surge", "icon": &"warning", "color": Color("ff6e6e"),
		"text": "The Collapse is accelerating. Heavy signatures converge on your position."},
	{"fraction": 0.94, "id": &"final_stand", "title": "Final Stand", "icon": &"skull", "color": Color("ff6e6e"),
		"text": "This is the last pressure wave. Survive it and leave."},
]

## Run-relative windows (fraction of RunState.get_run_duration()) used to
## schedule the three weighted world events.
const WORLD_EVENT_WINDOWS: Array[Vector2] = [
	Vector2(0.14, 0.26),
	Vector2(0.38, 0.55),
	Vector2(0.64, 0.82),
]


func setup(
	p_contract_id: StringName,
	p_seed: int,
	p_threat: int = 1,
	p_mutators: Array = [],
	p_difficulty_id: StringName = &"",
	p_mode_id: StringName = &"normal",
	p_map_id: StringName = &""
) -> void:
	contract_id = p_contract_id
	seed_value = p_seed
	threat = clampi(p_threat, 1, 4)
	mutators = p_mutators.duplicate()
	difficulty_id = p_difficulty_id
	game_mode = p_mode_id
	map_id = p_map_id
	call_deferred("_start_deployment")


func _start_deployment() -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()
	RunState.start_run(contract_id, seed_value, threat, mutators, difficulty_id, game_mode, map_id)
	game_mode = RunState.mode_id
	threat = RunState.threat
	_rng.seed = RunState.run_seed
	_map_preset = ContentDB.get_map_preset(RunState.map_preset_id)
	_actors_root = Node3D.new()
	_actors_root.name = "Actors"
	add_child(_actors_root)
	_site_root = Node3D.new()
	_site_root.name = "Sites"
	add_child(_site_root)
	progress_changed.emit(0.02, "Opening the Reach")
	var ok := await _generate_world()
	if ok:
		progress_changed.emit(0.72, "Terrain stable")
	else:
		progress_changed.emit(0.55, "Rift interference — deploying fallback terrain")
		_build_fallback_world()
	_cache_world_data()
	_apply_mode_environment()
	_spawn_rideables()
	_spawn_loot_props()
	_spawn_poi_markers()
	progress_changed.emit(0.76, "Opening the under-reach")
	await _prepare_dungeons()
	progress_changed.emit(0.78, "Printing drop pod")
	_spawn_player()
	if not is_instance_valid(player):
		push_error("[Deployment] Player spawn failed.")
		return
	progress_changed.emit(0.84, "Waking Wardens")
	if not RunState.is_tutorial():
		_spawn_squad()
	progress_changed.emit(0.9, "Mapping hostiles")
	_prepare_scripts()
	if RunState.is_tutorial():
		_setup_tutorial()
	else:
		_setup_contract()
		_spawn_world_enemies()
		progress_changed.emit(0.96, "Calibrating exfil")
		_setup_extraction()
		_setup_shrine()
		_setup_side_objectives()
		_schedule_world_events()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player != null:
		player.global_position = _spawn_position + Vector3.UP * 0.6
	started = true
	progress_changed.emit(1.0, "Deployment live")
	ready_to_play.emit(player)
	_set_music_track(&"deploy")
	_set_ambience(&"wind_ambient")
	_play_insertion_cinematic()
	EventBus.radio_message.emit("Waystation Kestrel", "Operation live. The Reach is already folding.")
	EventBus.notify(
		"OPERATION LIVE · " + RunState.get_difficulty_name().to_upper(),
		"Reach the objectives, loot the dead, and call exfil before the Collapse.",
		&"success"
	)


## Applies mode-authored environment overrides after world generation: the
## Blackout night insertion start time and any forced starting weather.
func _apply_mode_environment() -> void:
	if world == null or not is_instance_valid(world):
		return
	var start_time := RunState.get_mode_start_time()
	if start_time >= 0.0 and world.has_method("get_day_night_cycle"):
		var cycle = world.call("get_day_night_cycle")
		if cycle != null and is_instance_valid(cycle) and cycle.has_method("set_time_of_day"):
			cycle.call("set_time_of_day", start_time)
	var start_weather := RunState.get_mode_start_weather()
	if start_weather != &"":
		_force_world_weather(start_weather)


func _cache_world_data() -> void:
	_poi_cache.clear()
	_discovered_pois.clear()
	_garrisoned_pois.clear()
	if world != null and world.has_method("get_pois"):
		for poi in world.call("get_pois"):
			if poi is Dictionary:
				_poi_cache.append(poi.duplicate(true))
	if _poi_cache.is_empty():
		var fallback_index := 0
		for pos in _fallback_pois:
			_poi_cache.append({
				"position": pos,
				"type": "camp",
				"name": "Fallback POI %d" % fallback_index,
				"radius": 20.0,
			})
			fallback_index += 1


# ---------------------------------------------------------------------------
# Field training
# ---------------------------------------------------------------------------

func _setup_tutorial() -> void:
	progress_changed.emit(0.92, "Field training")
	var forward: Vector3 = player.call("get_forward")
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.01:
		flat = -player.global_transform.basis.z
		flat.y = 0.0
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var targets: Array[Node] = []
	for i in 2:
		var target = TRAINING_TARGET_SCRIPT.new()
		if not (target is Node3D):
			continue
		_actors_root.add_child(target)
		var side := 3.0 if i == 0 else -3.5
		var point := _spawn_position + flat * (10.0 + float(i) * 3.0) + right * side
		point.y = _ground_position(point).y
		(target as Node3D).global_position = point
		(target as Node3D).rotation.y = atan2(flat.x, flat.z)
		targets.append(target)
	var cache = LOOT_CACHE_SCRIPT.new()
	if cache is Node3D:
		_site_root.add_child(cache)
		var cache_position := _ground_position(_spawn_position + right * 7.0 + flat * 4.0)
		cache.call("setup", &"tutorial_cache", cache_position, null, _build_cache_payload())
	var beacon := ExtractionBeacon.new()
	beacon.name = "TrainingExfil"
	_site_root.add_child(beacon)
	var beacon_position := _ground_position(_spawn_position + flat * 55.0)
	beacon.setup(self, beacon_position, "Training Exfil")
	_exfil_sites.append(beacon)
	_tutorial_director = TUTORIAL_DIRECTOR_SCRIPT.new()
	_tutorial_director.name = "TutorialDirector"
	add_child(_tutorial_director)
	_tutorial_director.call("setup", self, player, targets, cache, beacon)
	EventBus.radio_message.emit("Mara Voss", "Field training. Move, shoot, cast, loot, then call exfil.")
	EventBus.notification_requested.emit("FIELD TRAINING", "Complete five stages to finish onboarding. Pause to skip.", &"info")


func get_tutorial_director() -> Node:
	return _tutorial_director


# ---------------------------------------------------------------------------
# Under-reach dungeons
# ---------------------------------------------------------------------------

## Pre-generates 2-3 themed dungeons during the loading screen so entering one is
## instant. Entrances are placed at the POI dungeon anchors produced by the world
## builder; the instances themselves live far below/away from the surface world.
func _prepare_dungeons() -> void:
	_dungeon_entries.clear()
	if world == null or not world.has_method("get_pois"):
		return
	var planet := ContentDB.get_planet(RunState.planet_id)
	var theme_ids: Array = planet.get("dungeon_themes", [])
	var candidates: Array = []
	for i in _poi_cache.size():
		var poi: Dictionary = _poi_cache[i]
		var anchor = poi.get("dungeon_anchor", null)
		if anchor is Vector3:
			candidates.append({"index": i, "poi": poi, "anchor": anchor})
	if candidates.is_empty():
		return
	# Deterministic shuffle so a seed always yields the same entrance set.
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Dictionary = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	_dungeon_root = Node3D.new()
	_dungeon_root.name = "Dungeons"
	add_child(_dungeon_root)
	var count := mini(3, candidates.size())
	for k in count:
		var candidate: Dictionary = candidates[k]
		var theme_id: StringName = &"rift_vault"
		if not theme_ids.is_empty():
			theme_id = StringName(theme_ids[k % theme_ids.size()])
		var theme: Dictionary = ContentDB.get_dungeon_theme(theme_id)
		if theme.is_empty():
			continue
		var runtime = DUNGEON_RUNTIME_SCRIPT.new()
		if not (runtime is Node):
			continue
		runtime.name = "DungeonRuntime_%d" % k
		_dungeon_root.add_child(runtime)
		runtime.call("setup", self, theme, threat, k)
		var origin := Vector3(4200.0 + float(k) * 340.0, -620.0, 0.0)
		var built: bool = runtime.call("build", RunState.run_seed + k * 7919, origin)
		if not built:
			runtime.queue_free()
			continue
		var anchor: Vector3 = candidate["anchor"]
		var entrance = DUNGEON_ENTRANCE_SCRIPT.new()
		if not (entrance is Node3D):
			runtime.queue_free()
			continue
		entrance.name = "DungeonEntrance_%d" % k
		_site_root.add_child(entrance)
		entrance.call(
			"setup", self, k,
			String(theme.get("display_name", "Rift Vault")),
			anchor + Vector3(0.0, 0.2, 0.0),
			theme.get("accent", Color("c79cff"))
		)
		_dungeon_entries.append({
			"index": k,
			"entrance": entrance,
			"runtime": runtime,
			"position": entrance.global_position,
			"name": String(theme.get("display_name", "Rift Vault")),
			"theme": theme,
		})
		await get_tree().process_frame
	progress_changed.emit(0.77, "Under-reach mapped")


func enter_dungeon(entrance: Node) -> void:
	if _in_dungeon or ending or not is_instance_valid(player):
		return
	if player.has_method("is_riding") and bool(player.call("is_riding")):
		EventBus.notification_requested.emit("Dismount first", "Leave your ride on the surface before entering the under-reach.", &"warning")
		return
	if entrance == null or not is_instance_valid(entrance):
		return
	var entry: Dictionary = {}
	for candidate in _dungeon_entries:
		if candidate.get("entrance") == entrance:
			entry = candidate
			break
	if entry.is_empty():
		return
	_active_dungeon = entry["runtime"]
	_dungeon_return_position = (entrance as Node3D).global_position + Vector3.UP * 0.8
	_in_dungeon = true
	RunState.record_dungeon_entered()
	if companion_manager != null and companion_manager.has_method("set_suspended"):
		companion_manager.call("set_suspended", true, _dungeon_return_position)
	_set_indoor(true)
	var start: Vector3 = _active_dungeon.call("enter", player)
	player.call("teleport_to", start + Vector3.UP * 0.25)
	EventBus.dungeon_state_changed.emit(true, String(entry.get("name", "Under-Reach")))
	EventBus.notification_requested.emit("UNDER-REACH", "%s. Find the guardian." % String(entry.get("name", "Rift Vault")), &"rift")
	EventBus.radio_message.emit("Waystation Kestrel", "Signal lost. You are under the Reach now.")
	AudioDirector.play_sfx(&"door", -4.0)
	_complete_dungeon_stage(&"dungeon")


func exit_dungeon() -> void:
	if not _in_dungeon:
		return
	if _active_dungeon != null and is_instance_valid(_active_dungeon):
		_active_dungeon.call("leave")
	_in_dungeon = false
	_active_dungeon = null
	_set_indoor(false)
	if is_instance_valid(player):
		player.call("teleport_to", _dungeon_return_position)
	if companion_manager != null and companion_manager.has_method("set_suspended"):
		companion_manager.call("set_suspended", false)
	EventBus.dungeon_state_changed.emit(false, "")
	EventBus.notification_requested.emit("SURFACE", "Back in the Reach. The clock is still running.", &"success")


func _set_indoor(value: bool) -> void:
	if world != null and world.has_method("get_environment_director"):
		var director = world.call("get_environment_director")
		if director != null and is_instance_valid(director):
			director.call("set_indoor", value)


func register_boss(enemy: Node) -> void:
	_register_boss(enemy)


func build_dungeon_cache_payload() -> Dictionary:
	return _build_cache_payload()


func on_dungeon_boss_defeated(runtime: Node) -> void:
	_dungeon_cleared += 1
	RunState.record_dungeon_cleared()
	for entry in _dungeon_entries:
		if entry.get("runtime") == runtime:
			var entrance = entry.get("entrance")
			if entrance != null and is_instance_valid(entrance) and entrance.has_method("set_cleared"):
				entrance.call("set_cleared", true)
	EventBus.notification_requested.emit("UNDER-REACH CLEARED", "The guardian is down. Loot the chamber and return to the surface.", &"success")
	EventBus.radio_message.emit("Waystation Kestrel", "Guardian down. That is a payday if you walk out with it.")
	_complete_dungeon_stage(&"dungeon_boss")


func is_in_dungeon() -> bool:
	return _in_dungeon


func get_active_dungeon() -> Node:
	return _active_dungeon


func get_dungeon_name() -> String:
	if _active_dungeon != null and is_instance_valid(_active_dungeon):
		return String(_active_dungeon.call("get_display_name"))
	return ""


func get_dungeon_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_dungeon_entries)
	return out


func get_dungeon_entrances() -> Array[Node]:
	var out: Array[Node] = []
	for entry in _dungeon_entries:
		var entrance = entry.get("entrance")
		if entrance != null and is_instance_valid(entrance):
			out.append(entrance)
	return out


func _prepare_scripts() -> void:
	if ResourceLoader.exists(ENEMY_SCRIPT_PATH):
		_enemy_script = load(ENEMY_SCRIPT_PATH)


func _generate_world() -> bool:
	if not ResourceLoader.exists("res://features/world/world_builder.gd"):
		return false
	_world_script = load("res://features/world/world_builder.gd")
	if _world_script == null:
		return false
	var instance = _world_script.new()
	if not (instance is Node3D):
		return false
	world = instance
	world.name = "World"
	add_child(world)
	# Map presets tune the biome/scatter budget and salt the layout seed. The
	# salted seed stays local to the world so RunState.run_seed (and therefore
	# the result payload + replays) keeps its authored value.
	var world_seed := RunState.run_seed
	if not _map_preset.is_empty():
		if world.has_method("apply_preset"):
			world.call("apply_preset", _map_preset)
		var salt := int(_map_preset.get("world_seed_salt", 0))
		if salt != 0:
			world_seed = RunState.run_seed ^ salt
	if world_seed == 0:
		world_seed = 1
	if world.has_signal("generation_progress"):
		world.generation_progress.connect(func(value: float, label: String) -> void:
			progress_changed.emit(lerpf(0.04, 0.7, clampf(value, 0.0, 1.0)), label)
		)
	var generation_ok := false
	if world.has_method("generate"):
		world.generate(world_seed)
		if world.has_signal("generation_finished"):
			generation_ok = bool(await world.generation_finished)
		else:
			await get_tree().create_timer(8.0).timeout
			generation_ok = world.has_method("is_generated") and bool(world.call("is_generated"))
	else:
		generation_ok = false
	return generation_ok and world != null


func _build_fallback_world() -> void:
	world = Node3D.new()
	world.name = "FallbackWorld"
	add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("354b6b")
	sky_mat.sky_horizon_color = Color("f2b07a")
	sky_mat.ground_bottom_color = Color("3b2d25")
	sky_mat.ground_horizon_color = Color("e6a76b")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color("eab98b")
	environment.fog_density = 0.0015
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -42, 0)
	sun.light_color = Color("ffd7a4")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	world.add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 1
	var ground_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(700.0, 2.0, 700.0)
	ground_mesh.mesh = box
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("b98256")
	ground_mat.roughness = 0.95
	ground_mesh.material_override = ground_mat
	ground_mesh.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(ground_mesh)
	var cover_root := Node3D.new()
	ground.add_child(cover_root)
	for i in 18:
		var angle := TAU * i / 18.0
		var radius := 18.0 + (i % 4) * 14.0
		var cover := StaticBody3D.new()
		cover.collision_layer = 1
		var cover_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.0, 2.4, 1.2)
		cover_shape.shape = shape
		cover.add_child(cover_shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 2.4, 1.2)
		mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("d7c8ae") if i % 2 == 0 else Color("a86446")
		mesh.material_override = mat
		cover.add_child(mesh)
		cover.position = Vector3(cos(angle) * radius, 1.2, sin(angle) * radius)
		cover.rotation.y = angle
		cover_root.add_child(cover)
	_build_fallback_points()


var _spawn_position := Vector3.ZERO
var _fallback_pois: Array[Vector3] = []
var _fallback_exfils: Array[Vector3] = []


func _build_fallback_points() -> void:
	_spawn_position = Vector3(0.0, 0.1, 0.0)
	_fallback_pois = [
		Vector3(96.0, 0.0, -72.0), Vector3(-118.0, 0.0, -36.0),
		Vector3(74.0, 0.0, 128.0), Vector3(-82.0, 0.0, 112.0),
	]
	_fallback_exfils = [
		Vector3(0.0, 0.0, -160.0), Vector3(170.0, 0.0, 40.0), Vector3(-150.0, 0.0, -120.0),
	]


func _spawn_player() -> void:
	_spawn_position = _pick_spawn_position()
	player = Player.new()
	player.name = "Player"
	_actors_root.add_child(player)
	player.global_position = _spawn_position + Vector3.UP * 0.3
	player.died.connect(_on_player_died)
	player.hitmarker.connect(func(_killed: bool, _crit: bool) -> void: pass)
	CombatVFX.ring(_actors_root, _spawn_position, 4.0, Color("62e6c3"), 1.2)
	EventBus.player_spawned.emit(player)


func _pick_spawn_position() -> Vector3:
	if world != null and world.has_method("get_spawn_points"):
		var points: Array = world.get_spawn_points()
		if not points.is_empty():
			return points[0] as Vector3
	return _spawn_position


func _spawn_squad() -> void:
	var manager_script_path := "res://features/companions/companion_manager.gd"
	if ResourceLoader.exists(manager_script_path):
		var manager_script: Script = load(manager_script_path)
		if manager_script != null:
			var manager = manager_script.new()
			if manager is Node:
				companion_manager = manager
				_actors_root.add_child(manager)
				if manager.has_method("setup"):
					manager.call("setup", player)
				return
	if not ResourceLoader.exists(ALLY_SCRIPT_PATH):
		return
	var ally_script: Script = load(ALLY_SCRIPT_PATH)
	if ally_script == null:
		return
	var active_allies := ProfileState.get_active_allies()
	var offset_index := 0
	for ally_id in active_allies:
		var data := ContentDB.get_ally(ally_id)
		if data == null:
			continue
		var ally = ally_script.new()
		if not (ally is Node3D):
			continue
		_actors_root.add_child(ally)
		var pos := _spawn_position + Vector3(cos(offset_index * 2.2) * 3.0, 0.1, sin(offset_index * 2.2) * 3.0)
		ally.global_position = pos
		if ally.has_method("setup"):
			ally.call("setup", data, player, ProfileState.get_ally_rank(ally_id))
		offset_index += 1
	if ResourceLoader.exists(PET_SCRIPT_PATH):
		var pet_script: Script = load(PET_SCRIPT_PATH)
		if pet_script != null:
			var pet_data := ContentDB.get_pet(ProfileState.get_active_pet())
			var pet = pet_script.new()
			if pet is Node3D and pet_data != null:
				_actors_root.add_child(pet)
				pet.global_position = _spawn_position + Vector3(1.6, 1.3, 1.6)
				if pet.has_method("setup"):
					pet.call("setup", pet_data, player, ProfileState.get_pet_rank(pet_data.id))


func _setup_contract() -> void:
	var contract := ContentDB.get_contract(contract_id)
	if contract == null:
		contract = ContentDB.get_contract(&"salvage_sweep")
	if contract == null:
		return
	var site_type: StringName = StringName(contract.objective_types[0]) if not contract.objective_types.is_empty() else &"cache"
	_contract_label = contract.objective_label
	_staged_contract = false
	if contract.is_staged():
		_setup_staged_contract(contract)
		return
	var candidates := _objective_candidates()
	var wanted := RunState.get_difficulty_mission_sites()
	var mission_count := mini(wanted, candidates.size())
	RunState.add_objective(&"contract", contract.objective_label, maxi(1, mission_count))
	var guard_count := RunState.get_difficulty_objective_guards()
	for i in mission_count:
		var poi: Dictionary = candidates[i]
		var pos: Vector3 = poi.get("position", _spawn_position) + Vector3(0.0, 0.1, 0.0)
		var site := ObjectiveSite.new()
		site.name = "ObjectiveSite%d" % i
		_site_root.add_child(site)
		site.setup(&"objective_%d" % i, contract.objective_label, site_type, pos, self, Color("62e6c3"))
		_objective_sites.append(site)
		_spawn_guards_around(pos, guard_count, i % 2)
	EventBus.radio_message.emit("Contract", contract.flavor)


func _setup_staged_contract(contract: ContractData) -> void:
	_staged_contract = true
	_stage_index = 0
	_stage_sites.clear()
	_stage_sites_completed = 0
	_used_poi_indices.clear()
	RunState.add_objective(&"contract", contract.objective_label, contract.stages.size())
	RunState.set_stage(0, contract.stages.size(), String(contract.stages[0].get("title", contract.objective_label)))
	EventBus.radio_message.emit("Contract", contract.flavor)
	_spawn_stage_sites(contract.stages[0])


func _spawn_stage_sites(stage: Dictionary) -> void:
	_stage_sites.clear()
	_stage_sites_completed = 0
	var stage_type := StringName(stage.get("type", &"cache"))
	var count := maxi(1, int(stage.get("count", 1)))
	_contract_label = String(stage.get("title", stage.get("label", "Objective")))
	RunState.set_stage(_stage_index, RunState.stage_total, _contract_label)
	if stage_type == &"dungeon" or stage_type == &"dungeon_boss":
		EventBus.notify(
			"STAGE %d/%d" % [_stage_index + 1, RunState.stage_total],
			"Find an under-reach hatch and descend.",
			&"rift"
		)
		return
	var candidates := _objective_candidates()
	var guard_count := RunState.get_difficulty_objective_guards()
	var spawned := 0
	for poi in candidates:
		if spawned >= count:
			break
		var index := int(poi.get("_index", -1))
		if _used_poi_indices.has(index):
			continue
		_used_poi_indices[index] = true
		var pos: Vector3 = poi.get("position", _spawn_position) + Vector3(0.0, 0.1, 0.0)
		var site := ObjectiveSite.new()
		site.name = "StageSite_%d_%d" % [_stage_index, spawned]
		_site_root.add_child(site)
		site.setup(&"stage_%d_%d" % [_stage_index, spawned], _contract_label, stage_type, pos, self, Color("62e6c3"))
		_objective_sites.append(site)
		_stage_sites.append(site)
		_spawn_guards_around(pos, guard_count, spawned % 2)
		spawned += 1
	EventBus.notify(
		"STAGE %d/%d" % [_stage_index + 1, RunState.stage_total],
		_contract_label,
		&"success"
	)


func _advance_contract_stage() -> void:
	var contract := ContentDB.get_contract(contract_id)
	if contract == null:
		return
	_stage_index += 1
	if _stage_index >= contract.stages.size():
		_contract_label = contract.objective_label
		EventBus.notify("CONTRACT COMPLETE", "Every stage is secured. Call exfil when ready.", &"success")
		EventBus.radio_message.emit("Waystation Kestrel", "Operation complete. Bring it home.")
		return
	var stage: Dictionary = contract.stages[_stage_index]
	_spawn_stage_sites(stage)


func _complete_dungeon_stage(kind: StringName) -> void:
	if not _staged_contract:
		return
	var contract := ContentDB.get_contract(contract_id)
	if contract == null or _stage_index >= contract.stages.size():
		return
	var stage: Dictionary = contract.stages[_stage_index]
	if StringName(stage.get("type", &"")) != kind:
		return
	RunState.progress_objective(&"contract", 1)
	_objectives_completed += 1
	_advance_contract_stage()


func _objective_candidates() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in _poi_cache.size():
		var poi: Dictionary = _poi_cache[i].duplicate(true)
		poi["_index"] = i
		list.append(poi)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _spawn_position.distance_squared_to(a.get("position", Vector3.ZERO)) < _spawn_position.distance_squared_to(b.get("position", Vector3.ZERO))
	)
	return list


func _setup_extraction() -> void:
	var exfils: Array = []
	if world != null and world.has_method("get_exfil_points"):
		exfils = world.get_exfil_points()
	if exfils.is_empty():
		for i in _fallback_exfils.size():
			exfils.append({"position": _fallback_exfils[i], "name": "Exfil %s" % String.chr(65 + i)})
	for i in mini(3, exfils.size()):
		var entry: Dictionary = exfils[i]
		var beacon := ExtractionBeacon.new()
		beacon.name = "Exfil%d" % i
		var pos: Vector3 = entry.get("position", Vector3.ZERO)
		_site_root.add_child(beacon)
		beacon.setup(self, pos + Vector3(0.0, 0.1, 0.0), String(entry.get("name", "Exfil " + String.chr(65 + i))))
		_exfil_sites.append(beacon)


func _setup_shrine() -> void:
	var candidates := _objective_candidates()
	if candidates.is_empty():
		return
	var poi: Dictionary = candidates[candidates.size() - 1]
	var shrine := ObjectiveSite.new()
	shrine.name = "RiftShrine"
	_site_root.add_child(shrine)
	shrine.setup(&"shrine", "Rift Shrine", &"shrine", poi.get("position", _spawn_position) + Vector3(8.0, 0.2, 8.0), self, Color("c79cff"))
	_objective_sites.append(shrine)
	_shrine_site = shrine
	RunState.add_objective(&"shrine", "Touch the Rift Shrine", 1)


# ---------------------------------------------------------------------------
# Side objectives: physical loot caches, marked elite bounties, shrine
# ---------------------------------------------------------------------------

func _setup_side_objectives() -> void:
	_setup_side_caches()
	_setup_bounties()


func _setup_side_caches() -> void:
	var wanted := mini(MAX_LOOT_CACHES, RunState.get_difficulty_side_caches())
	if wanted <= 0:
		return
	var positions := _cache_positions(wanted)
	var spawned := 0
	for i in positions.size():
		if _spawn_loot_cache(i, positions[i]) == null:
			continue
		spawned += 1
	if spawned <= 0:
		return
	RunState.add_objective(&"side_caches", "Breach side caches", spawned)
	EventBus.radio_message.emit("Mara Voss", "Side caches are tagged on your map. Free salvage if you can carry it.")


func _cache_positions(wanted: int) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	if world != null and world.has_method("get_roadside_points"):
		for entry in world.call("get_roadside_points"):
			if entry is Dictionary and entry.has("position"):
				var roadside := _ground_position(entry["position"] as Vector3)
				if _cache_position_is_clear(roadside):
					candidates.append(roadside)
	for poi in _poi_cache:
		var poi_position := _ground_position(poi.get("position", Vector3.ZERO))
		if _cache_position_is_clear(poi_position):
			candidates.append(poi_position)
	# Deterministic Fisher-Yates so a given seed always places the same caches.
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var positions: Array[Vector3] = []
	for position in candidates:
		if positions.size() >= wanted:
			break
		var spaced := true
		for chosen in positions:
			if chosen.distance_squared_to(position) < 32.0 * 32.0:
				spaced = false
				break
		if spaced:
			positions.append(position)
	var attempts := 0
	while positions.size() < wanted and attempts < wanted * 8:
		attempts += 1
		var fallback := _ground_position(_offset_point(_spawn_position, _rng.randf_range(45.0, 190.0)))
		if _cache_position_is_clear(fallback):
			positions.append(fallback)
	return positions


## Caches must not sit on objective/exfil interaction volumes, otherwise the
## player's interaction ray could resolve to a cache instead of the site.
func _cache_position_is_clear(point: Vector3) -> bool:
	var minimum := CACHE_SITE_CLEARANCE * CACHE_SITE_CLEARANCE
	for site in _objective_sites:
		if site == null or not is_instance_valid(site) or site.completed:
			continue
		if site.global_position.distance_squared_to(point) < minimum:
			return false
	for beacon in _exfil_sites:
		if beacon == null or not is_instance_valid(beacon):
			continue
		if beacon.global_position.distance_squared_to(point) < minimum:
			return false
	return true


func _spawn_loot_cache(index: int, position: Vector3) -> Node:
	var cache = LOOT_CACHE_SCRIPT.new()
	if not (cache is StaticBody3D):
		return null
	cache.name = "LootCache%d" % index
	_site_root.add_child(cache)
	cache.call("setup", &"cache_%d" % index, position, self, _build_cache_payload())
	_loot_caches.append(cache)
	return cache


func _setup_bounties() -> void:
	var wanted := RunState.get_difficulty_bounties()
	if wanted <= 0:
		return
	var elites := _elite_pool()
	if elites.is_empty() or _poi_cache.is_empty():
		return
	var order: Array[int] = []
	for i in _poi_cache.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	var spawned := 0
	for poi_index in order:
		if spawned >= wanted:
			break
		if _hostiles.size() >= _max_active_hostiles():
			break
		var poi: Dictionary = _poi_cache[poi_index]
		var data: EnemyData = elites[_rng.randi_range(0, elites.size() - 1)]
		var offset := Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-12.0, 12.0))
		var enemy := _spawn_enemy_at(data, (poi.get("position", _spawn_position) as Vector3) + offset)
		if enemy == null:
			continue
		if enemy.has_method("set_marked"):
			enemy.call("set_marked", 240.0)
		_bounty_targets.append(enemy)
		spawned += 1
	if spawned <= 0:
		return
	RunState.add_objective(&"bounties", "Eliminate marked bounties", spawned)
	EventBus.notify("Bounty posted", "%d elite signatures are marked on your map." % spawned, &"danger")


func on_cache_opened(cache: Node, _player: Node) -> void:
	if cache == null:
		return
	_loot_caches.erase(cache)
	_looted += 1
	var completed_now := RunState.progress_objective(&"side_caches", 1)
	if completed_now:
		EventBus.notify("SIDE CACHES CLEARED", "Every cache in this sector has been breached.", &"success")
		EventBus.radio_message.emit("Mara Voss", "That was the last cache. Good hunting.")
	else:
		var progress := RunState.get_objective_progress(&"side_caches")
		var total := RunState.get_objective_total(&"side_caches")
		if total > 0:
			EventBus.notify("Cache breached", "Salvage recovered. %d/%d caches." % [progress, total], &"loot")


func _schedule_world_events() -> void:
	var events: Array = ContentDB.get_world_events()
	if events.is_empty():
		return
	var duration := maxf(60.0, RunState.get_run_duration())
	_scheduled_events.clear()
	_event_cursor = 0
	var used: Dictionary = {}
	for window in WORLD_EVENT_WINDOWS:
		var event := _pick_weighted_world_event(events, used)
		if event.is_empty():
			break
		var fraction := _rng.randf_range(window.x, window.y)
		_scheduled_events.append({
			"event": event,
			"time": clampf(fraction * duration, 1.0, maxf(1.0, duration - 30.0)),
		})
	_scheduled_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	_event_timer = float(_scheduled_events[0].get("time", 0.0)) if not _scheduled_events.is_empty() else 0.0
	EventBus.notification_requested.emit(
		"The Reach is moving",
		"%d anomalous signatures detected on long-range telemetry." % _scheduled_events.size(),
		&"info"
	)


## Picks a distinct, weight-biased world event. `used` maps event indexes that
## have already been scheduled this run.
func _pick_weighted_world_event(events: Array, used: Dictionary) -> Dictionary:
	var total := 0.0
	for i in events.size():
		if used.has(i) or not (events[i] is Dictionary):
			continue
		total += maxf(0.05, float((events[i] as Dictionary).get("weight", 1)))
	if total <= 0.0:
		return {}
	var roll := _rng.randf_range(0.0, total)
	var last_index := -1
	for i in events.size():
		if used.has(i) or not (events[i] is Dictionary):
			continue
		last_index = i
		var event: Dictionary = events[i]
		roll -= maxf(0.05, float(event.get("weight", 1)))
		if roll <= 0.0:
			used[i] = true
			return event
	if last_index >= 0:
		used[last_index] = true
		return events[last_index]
	return {}


func _has_player() -> bool:
	return player != null and is_instance_valid(player)


func _trigger_world_event(entry: Dictionary) -> void:
	var event: Dictionary = entry.get("event", {})
	var event_id: StringName = event.get("id", &"")
	var title := String(event.get("title", "World Event"))
	var text := String(event.get("text", ""))
	var icon := StringName(event.get("icon", &"target"))
	var color: Color = event.get("color", Color("62e6c3"))
	EventBus.world_event.emit(title, text, icon, color)
	EventBus.notification_requested.emit(title, text, &"info")
	EventBus.radio_message.emit("Waystation Kestrel", text)
	match event_id:
		&"supply_drop", &"cache_beacon", &"lost_caravan":
			_spawn_supply_site(title)
			if event_id == &"lost_caravan":
				_spawn_event_wave(&"ashen_scrapper", 2, 45.0)
		&"wandering_elite":
			var elites := _elite_pool()
			if not elites.is_empty() and _has_player():
				var elite: EnemyData = elites[_rng.randi_range(0, elites.size() - 1)]
				_spawn_enemy_at(elite, _offset_point(player.global_position, 65.0))
		&"faction_skirmish":
			_spawn_event_wave(&"ashen_marksman", 2, 55.0)
			_spawn_event_wave(&"bloom_stalker", 2, 62.0)
		&"rift_surge":
			_grant_rift_mod()
			_spawn_event_wave(&"choir_sentinel", 1, 40.0)
		&"black_market":
			RunState.add_satchel_salvage(90 + threat * 30, 1)
			EventBus.notification_requested.emit("Courier payment", "Salvage added to your satchel.", &"success")
		&"jammer_field":
			_spawn_event_wave(&"choir_nullifier", 2, 48.0)
		&"sudden_fog":
			_spawn_event_wave(&"bloom_stalker", 3, 35.0)
			EventBus.notification_requested.emit("Dust front", "Visibility is dropping. Keep close.", &"danger")
		&"bloom_bloom":
			_spawn_event_wave(&"bloom_stalker", 3, 42.0)
			_spawn_event_wave(&"bloom_spitter", 1, 55.0)
		&"supply_convoy":
			_spawn_supply_site(title)
			_spawn_event_wave(&"ashen_scrapper", 2, 50.0)
		&"rift_echo":
			_grant_rift_mod()
			_spawn_event_wave(&"choir_wisp", 2, 58.0)
		&"meteor_strike":
			_force_world_weather(&"meteor_shower")
			_spawn_event_wave(&"ashen_sapper", 2, 48.0)
			_spawn_event_wave(&"ashen_hound", 2, 60.0)
		&"rift_cyclone":
			_force_world_weather(&"rift_cyclone")
			_grant_rift_mod()
		&"toxic_drift":
			_force_world_weather(&"toxic_squall")
			_spawn_event_wave(&"bloom_spitter", 2, 50.0)
			_spawn_event_wave(&"bloom_lasher", 2, 62.0)
		&"whiteout":
			_force_world_weather(&"void_whiteout")
			_spawn_event_wave(&"choir_wisp", 2, 48.0)
			_spawn_event_wave(&"choir_sentinel", 1, 60.0)
		&"scavenger_convoy":
			_spawn_supply_site(title)
			_spawn_event_wave(&"ashen_scrapper", 2, 46.0)
			_spawn_event_wave(&"ashen_marksman", 1, 58.0)
		&"bounty_broker":
			_spawn_broker_bounty()
		&"distress_beacon":
			_spawn_supply_site(title)
			EventBus.radio_message.emit("Mara Voss", "Distress signal logged. Kestrel says we are close enough.")
		&"collapse_tremor":
			_pull_collapse_forward()


## Force a weather state on the generated world. Safe before/without a player
## and when the fallback world has no weather system.
func _force_world_weather(weather_id: StringName) -> bool:
	if world == null or not is_instance_valid(world) or not world.has_method("get_weather_system"):
		return false
	var weather_node = world.call("get_weather_system")
	if weather_node == null or not is_instance_valid(weather_node) or not weather_node.has_method("force_weather"):
		return false
	return bool(weather_node.call("force_weather", weather_id))


func _spawn_broker_bounty() -> void:
	if not _has_player():
		return
	var elite := _random_elite_data()
	if elite == null:
		return
	var enemy := _spawn_at_player_distance(elite, 55.0)
	if enemy == null:
		return
	if enemy.has_method("set_marked"):
		enemy.call("set_marked", 240.0)
	_bounty_targets.append(enemy)
	EventBus.notification_requested.emit("Broker contract", "A marked elite is close. Kill it for the bounty.", &"danger")


## Pulls the Collapse start forward by one minute without ever delaying it.
func _pull_collapse_forward() -> void:
	var storm_start := RunState.get_storm_start_time()
	var pulled := maxf(RunState.elapsed + 30.0, storm_start - 60.0)
	RunState.storm_start_time = minf(storm_start, pulled)
	EventBus.notification_requested.emit("Collapse tremor", "The Collapse is closing in early. Get moving.", &"danger")


func _spawn_event_wave(enemy_id: StringName, count: int, distance: float) -> void:
	if not _has_player():
		return
	var data := ContentDB.get_enemy(enemy_id)
	if data == null:
		return
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var offset := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		_spawn_enemy_at(data, _offset_point(player.global_position, distance) + offset * 0.12)


func _offset_point(origin: Vector3, distance: float) -> Vector3:
	var angle := _rng.randf_range(0.0, TAU)
	var point := origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	if world != null and world.has_method("sample_height"):
		point.y = float(world.call("sample_height", Vector2(point.x, point.z))) + 0.1
	return point


func _spawn_supply_site(title: String) -> void:
	if not _has_player():
		return
	var point := _offset_point(player.global_position, _rng.randf_range(28.0, 38.0))
	var site := ObjectiveSite.new()
	site.name = "SupplyDrop"
	_site_root.add_child(site)
	site.setup(&"supply", title, &"supply", point, self, Color("ffb866"))
	_objective_sites.append(site)


func _spawn_world_enemies() -> void:
	if not ResourceLoader.exists(ENEMY_SCRIPT_PATH):
		return
	_enemy_script = load(ENEMY_SCRIPT_PATH)
	if _enemy_script == null:
		return
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	# Immediate threat near the drop: a small patrol that follows the player in.
	var patrol_count := _rng.randi_range(3, 6)
	for p in patrol_count:
		_spawn_enemy_at(_random_enemy_data(roster), _spawn_position + Vector3(20.0 + float(p) * 4.0, 0.0, -14.0 - float(p) * 3.0))
	# The closest POIs are garrisoned up-front; the rest stage in when the
	# player gets within GARRISON_STAGE_RADIUS so garrisons feel reactive but
	# never flood the whole map at t=0.
	var spawn_pois := _objective_candidates()
	var immediate := mini(4, spawn_pois.size())
	for i in immediate:
		_garrison_poi(int(spawn_pois[i].get("_index", i)), roster)


func _garrison_poi(poi_index: int, roster: Array = []) -> void:
	if poi_index < 0 or poi_index >= _poi_cache.size():
		return
	if bool(_garrisoned_pois.get(poi_index, false)):
		return
	_garrisoned_pois[poi_index] = true
	if roster.is_empty():
		roster = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	var poi: Dictionary = _poi_cache[poi_index]
	var center: Vector3 = poi.get("position", _spawn_position)
	var density := RunState.get_difficulty_density()
	var count := clampi(int(round(float(1 + threat / 2) * density)), 2, 6)
	for i in count:
		if _hostiles.size() >= _max_active_hostiles():
			return
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(7.0, 16.0)
		var position := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_spawn_enemy_at(_random_enemy_data(roster), position)


func _update_staged_garrisons() -> void:
	if ending or player == null or not is_instance_valid(player):
		return
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	var staged := 0
	for i in _poi_cache.size():
		if staged >= 2:
			break
		if bool(_garrisoned_pois.get(i, false)):
			continue
		var position: Vector3 = _poi_cache[i].get("position", Vector3.ZERO)
		if player.global_position.distance_squared_to(position) <= GARRISON_STAGE_RADIUS * GARRISON_STAGE_RADIUS:
			_garrison_poi(i, roster)
			staged += 1


func _random_enemy_data(roster: Array) -> EnemyData:
	if roster.is_empty():
		return null
	# Threat- and difficulty-scaled elite chance.
	var elite_chance := 0.08 + 0.04 * float(threat) + RunState.get_difficulty_elite_bonus()
	if threat >= 2 and _rng.randf() < elite_chance:
		var elites: Array[EnemyData] = []
		for enemy in ContentDB.enemies.values():
			if enemy.elite and not enemy.boss:
				elites.append(enemy)
		if not elites.is_empty():
			return elites[_rng.randi_range(0, elites.size() - 1)]
	return roster[_rng.randi_range(0, roster.size() - 1)]


func _spawn_enemy_at(data: EnemyData, position: Vector3, boss: bool = false) -> Node:
	if _enemy_script == null or data == null or ending:
		return null
	if _hostiles.size() >= _max_active_hostiles() and not data.boss:
		return null
	var enemy = _enemy_script.new()
	if not (enemy is Node3D):
		return null
	_actors_root.add_child(enemy)
	var y := 0.2
	if world != null and world.has_method("sample_height"):
		y = float(world.call("sample_height", Vector2(position.x, position.z))) + 0.1
	enemy.global_position = Vector3(position.x, y, position.z)
	if enemy.has_method("setup"):
		enemy.call("setup", data, threat)
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated)
	if enemy.has_method("is_boss") and bool(enemy.call("is_boss")):
		_register_boss(enemy)
	_hostiles.append(enemy)
	return enemy


func _register_boss(enemy: Node) -> void:
	_active_boss = enemy
	var health := CombatUtils.find_health(enemy)
	if health == null:
		return
	var display := String(enemy.get_meta("enemy_name", "The Warden"))
	var hud = _get_hud()
	if hud != null and hud.has_method("show_boss"):
		hud.call("show_boss", display, health.health + health.shield, health.max_health + health.max_shield)
	health.damaged.connect(func(_info: Dictionary) -> void:
		var active_hud = _get_hud()
		if active_hud != null and active_hud.has_method("update_boss"):
			active_hud.call("update_boss", health.health + health.shield, health.max_health + health.max_shield)
	)
	enemy.defeated.connect(func(_dead: Node) -> void:
		var active_hud = _get_hud()
		if active_hud != null and active_hud.has_method("hide_boss"):
			active_hud.call("hide_boss")
		_active_boss = null
	)
	EventBus.radio_message.emit("Waystation Kestrel", display + " is awake. Keep moving.")
	_play_boss_cinematic(enemy)


# ---------------------------------------------------------------------------
# Rideables, cinematics and music
# ---------------------------------------------------------------------------

func _spawn_rideables() -> void:
	_rideables.clear()
	if not ResourceLoader.exists(VEHICLE_SITES_PATH):
		return
	var site_script: Script = load(VEHICLE_SITES_PATH)
	if site_script == null:
		return
	var sites = site_script.new()
	if sites == null or not sites.has_method("build"):
		return
	var spawned: Array = []
	var result: Variant = sites.call("build", _site_root, world, RunState.run_seed, _map_preset)
	if result is Array:
		spawned = result
	if RunState.is_tutorial() and spawned.size() > 1:
		# Training gets one ground vehicle at the drop zone: enough to teach
		# mounting without turning the tutorial into a driving lesson.
		for i in range(1, spawned.size()):
			var extra = spawned[i]
			if extra is Node and is_instance_valid(extra):
				(extra as Node).queue_free()
		spawned = [spawned[0]]
	for entry in spawned:
		if entry != null and is_instance_valid(entry):
			_rideables.append(entry)


func get_rideables() -> Array:
	return _rideables.duplicate()


## Breachable caches at the POI clutter anchors the world builder exposes. Table
## choice comes from POISpecs.loot_tier via ContentDB, so rare POIs pay better.
## Capped and kept out of _loot_caches so tactical-map markers stay unchanged.
func _spawn_loot_props() -> void:
	_loot_props.clear()
	if world == null or not is_instance_valid(world) or not world.has_method("get_loot_props"):
		return
	if RunState.is_tutorial():
		return
	var props: Array = world.call("get_loot_props")
	if props.is_empty():
		return
	var luck := RunState.get_difficulty_loot_luck()
	var spawned := 0
	for prop in props:
		if spawned >= MAX_LOOT_PROPS:
			break
		if not (prop is Dictionary):
			continue
		var entry: Dictionary = prop
		var point: Vector3 = entry.get("position", Vector3.ZERO)
		var table_id: StringName = &"poi_common"
		if ContentDB.has_method("get_loot_table_for_poi_dict"):
			table_id = StringName(ContentDB.call("get_loot_table_for_poi_dict", entry))
		var payload: Dictionary = {}
		if ContentDB.has_method("build_loot_cache_payload"):
			var built: Variant = ContentDB.call("build_loot_cache_payload", _rng, table_id, threat, luck)
			if built is Dictionary:
				payload = built
		if payload.is_empty():
			payload = _build_cache_payload()
		payload["loot_table"] = table_id
		var cache: Node = LOOT_CACHE_SCRIPT.new()
		cache.name = "LootProp_%02d" % spawned
		_site_root.add_child(cache)
		cache.call("setup", StringName("loot_prop_%d" % spawned), _ground_position(point), self, payload)
		_loot_props.append(cache)
		spawned += 1


func get_loot_prop_caches() -> Array:
	return _loot_props.duplicate()


## Throttled vehicle HUD feed. The HUD panel is optional, so this is a no-op on
## builds without features/vehicles.
func _update_rideable_hud(delta: float) -> void:
	_rideable_timer -= delta
	if _rideable_timer > 0.0:
		return
	_rideable_timer = 0.1
	var hud = _get_hud()
	if hud == null:
		return
	var riding := false
	var snapshot: Dictionary = {}
	if player != null and is_instance_valid(player) and player.has_method("is_riding"):
		riding = bool(player.call("is_riding"))
		if riding:
			var vehicle = player.call("get_rideable")
			if vehicle != null and is_instance_valid(vehicle) and vehicle.has_method("get_hud_snapshot"):
				var raw: Variant = vehicle.call("get_hud_snapshot")
				if raw is Dictionary:
					snapshot = raw
			if snapshot.is_empty():
				riding = false
	if not riding:
		if _vehicle_hud_open:
			_vehicle_hud_open = false
			if hud.has_method("hide_vehicle"):
				hud.call("hide_vehicle")
		return
	if _vehicle_hud_open:
		if hud.has_method("update_vehicle"):
			hud.call("update_vehicle", snapshot)
	else:
		_vehicle_hud_open = true
		if hud.has_method("show_vehicle"):
			hud.call("show_vehicle", snapshot)


## One music state machine for the whole run: exfil > boss > storm > combat >
## the drop bed. set_music_track() is a no-op when the audio stream is missing.
func _update_music_state(delta: float) -> void:
	_music_timer -= delta
	if _music_timer > 0.0:
		return
	_music_timer = 1.0
	var track: StringName = &"deploy"
	if RunState.extraction_state == &"holding":
		track = &"exfil"
	elif _has_live_boss():
		track = &"boss"
	elif RunState.storm_active:
		track = &"storm"
	elif _hostile_within(48.0):
		track = &"combat"
	_set_music_track(track)


func _set_music_track(track: StringName) -> void:
	if track == _music_track:
		return
	_music_track = track
	if AudioDirector != null and AudioDirector.has_method("set_music_track"):
		AudioDirector.call("set_music_track", track)


## Weather/time ambience bed; guarded because the audio stream may be a synth
## fallback or absent entirely in stripped builds.
func _set_ambience(ambience_id: StringName) -> void:
	if ambience_id == _ambience_id:
		return
	_ambience_id = ambience_id
	if AudioDirector != null and AudioDirector.has_method("set_ambience"):
		AudioDirector.call("set_ambience", ambience_id)


func _hostile_within(radius: float) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var limit := radius * radius
	for hostile in _hostiles:
		if hostile == null or not is_instance_valid(hostile):
			continue
		if hostile is Node3D and (hostile as Node3D).global_position.distance_squared_to(player.global_position) <= limit:
			return true
	return false


## In-world insertion beat at the drop pod, played the moment the run goes live.
func _play_insertion_cinematic() -> void:
	if App == null or not App.has_method("play_cinematic"):
		return
	App.play_cinematic(&"insertion", {
		"world": get_world(),
		"player": player,
		"origin": _spawn_position,
	})


## One confrontation shot per boss instance, never in training.
func _play_boss_cinematic(boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if RunState.is_tutorial():
		return
	var key := boss.get_instance_id()
	if _boss_cinematics.has(key):
		return
	_boss_cinematics[key] = true
	if App == null or not App.has_method("play_cinematic"):
		return
	var display := String(boss.get_meta("enemy_name", "The Warden"))
	var faction := ""
	var phase := 1
	var data = boss.get("enemy_data")
	if data is Object and data != null:
		var raw_faction: Variant = (data as Object).get("faction")
		if raw_faction != null:
			faction = String(raw_faction)
	if boss.has_method("get_boss_phase"):
		phase = int(boss.call("get_boss_phase"))
	App.play_cinematic(&"boss", {
		"world": get_world(),
		"player": player,
		"boss": boss,
		"boss_name": display,
		"boss_faction": faction,
		"boss_phase": phase,
	})


## Escape. Runs while the world is still valid, then hands the ending back to
## RunState so the results screen arrives after the shot.
func _begin_exfil_cutscene() -> void:
	if _exfil_cinematic_playing or _exfil_cinematic_done:
		return
	_exfil_cinematic_done = true
	_exfil_cinematic_playing = true
	ending = true
	# Step off the ride so the escape shot frames the Warden, not a seat.
	if player != null and is_instance_valid(player) and player.has_method("is_riding") and bool(player.call("is_riding")):
		if player.has_method("exit_vehicle"):
			player.call("exit_vehicle")
	var played := false
	if App != null and App.has_method("play_cinematic"):
		played = bool(App.play_cinematic(&"exfil", {
			"world": get_world(),
			"player": player,
			"ship": get_extraction_ship(),
		}))
	if played and App != null and App.has_method("is_cinematic"):
		while is_instance_valid(self) and is_inside_tree() and bool(App.is_cinematic()):
			await get_tree().process_frame
		if not is_instance_valid(self) or not is_inside_tree():
			return
	_exfil_cinematic_playing = false
	RunState.tick_extraction(0.0)


func _get_hud() -> Node:
	var ui = App.get_ui()
	if ui == null or not is_instance_valid(ui) or not ui.has_method("get_hud"):
		return null
	var hud = ui.call("get_hud")
	if hud is Node and is_instance_valid(hud):
		return hud
	return null


func _spawn_guards_around(position: Vector3, count: int, variant: int) -> void:
	if _enemy_script == null:
		return
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	for i in count:
		var angle := TAU * i / maxf(1, count) + variant * 0.7
		var pos := position + Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0)
		_spawn_enemy_at(_random_enemy_data(roster), pos)


func _on_enemy_defeated(enemy: Node) -> void:
	if enemy == null:
		return
	_hostiles.erase(enemy)
	if enemy == _active_boss:
		var hud = _get_hud()
		if hud != null and hud.has_method("hide_boss"):
			hud.call("hide_boss")
		_active_boss = null
	if enemy in _bounty_targets:
		_bounty_targets.erase(enemy)
		if enemy is Node3D and is_instance_valid(enemy):
			var death_position: Vector3 = (enemy as Node3D).global_position
			_award_loot_drop(death_position, 2)
		var bounty_done := RunState.progress_objective(&"bounties", 1)
		if bounty_done:
			EventBus.notify("BOUNTIES CLEARED", "Every marked elite is down.", &"success")
			EventBus.radio_message.emit("Mara Voss", "All bounty signatures are dark. That pays well.")
		else:
			EventBus.notify("Bounty eliminated", "Marked target down. Recover the dropped cache.", &"success")
	if _objective_targets.has(enemy):
		var site: ObjectiveSite = _objective_targets[enemy]
		_objective_targets.erase(enemy)
		if site != null:
			_complete_objective_site(site)


func on_objective_interacted(site: ObjectiveSite, _player: Node) -> void:
	if site == null or site.completed:
		return
	if site.site_type == &"shrine":
		_grant_rift_mod()
		site.mark_complete()
		RunState.progress_objective(&"shrine", 1)
		EventBus.notify("Rift Shrine", "The Reach answers your touch. A rift mod settles into your suit.", &"rift")
		return
	if site.site_type == &"supply":
		_award_loot_drop(site.global_position + Vector3(0.0, 1.0, 0.0), 2 + threat / 2)
		RunState.add_satchel_salvage(70 + threat * 20, 1)
		site.mark_complete()
		EventBus.notification_requested.emit("Supply secured", "Cargo transferred to your satchel.", &"success")
		return
	if site.site_type in [&"hunt", &"vault"]:
		var target := _spawn_objective_target(site)
		if target != null:
			_objective_targets[target] = site
			EventBus.notify("Target revealed", "Eliminate the target to secure the objective.", &"danger")
			return
	# Fallback (or standard cache/relay/survey/rescue)
	_complete_objective_site(site)


func _spawn_objective_target(site: ObjectiveSite) -> Node:
	if _enemy_script == null:
		return null
	var target_data: EnemyData
	if site.site_type == &"vault":
		var bosses := ContentDB.get_boss_enemies()
		if not bosses.is_empty():
			target_data = bosses[_rng.randi_range(0, bosses.size() - 1)]
		else:
			target_data = ContentDB.get_enemy(&"the_warden")
	else:
		var elites := _elite_pool()
		target_data = elites[_rng.randi_range(0, elites.size() - 1)] if not elites.is_empty() else null
	if target_data == null:
		return null
	var enemy = _spawn_enemy_at(target_data, site.global_position + Vector3(8.0, 0.0, 0.0), true)
	return enemy


func _complete_objective_site(site: ObjectiveSite) -> void:
	if site == null or site.completed:
		return
	site.mark_complete()
	_objectives_completed += 1
	RunState.add_satchel_salvage(35 + threat * 15, 1 if threat >= 3 else 0)
	_award_loot_drop(site.global_position + Vector3(0.0, 1.0, 0.0), 1 + threat / 2)
	if _staged_contract:
		_stage_sites_completed += 1
		if _stage_sites_completed >= maxi(1, _stage_sites.size()):
			RunState.progress_objective(&"contract", 1)
			_advance_contract_stage()
		else:
			EventBus.notify(
				"Stage progress",
				"%d/%d secured — %s" % [_stage_sites_completed, _stage_sites.size(), _contract_label],
				&"success"
			)
		return
	RunState.progress_objective(&"contract", 1)
	if RunState.is_objective_complete(&"contract"):
		EventBus.notify("Objective secured", "Contract complete. Call exfil when you are ready to leave.", &"success")
		EventBus.radio_message.emit("Waystation Kestrel", "Contract secured. That's a clean payday if you make it back.")
		EventBus.notify("CONTRACT COMPLETE", "You have fulfilled the contract. Exfil when ready.", &"success")
	else:
		EventBus.notify("Objective secured", "Contract objective complete. Keep pushing.", &"success")
		EventBus.radio_message.emit("Waystation Kestrel", "Objective down. %d of %d contract sites secured." % [
			RunState.get_objective_progress(&"contract"),
			RunState.get_objective_total(&"contract"),
		])


func on_objective_site_completed(_site: ObjectiveSite) -> void:
	AudioDirector.play_ui(&"ui_confirm")


func _grant_rift_mod() -> void:
	var ids: Array = ContentDB.rift_mods.keys()
	ids.shuffle()
	for id in ids:
		if id not in RunState.rift_mods:
			RunState.add_rift_mod(id)
			return
	RunState.add_satchel_salvage(50, 1)


func _award_loot_drop(position: Vector3, count: int) -> void:
	if count <= 0:
		return
	var ground := _ground_position(position)
	var luck := RunState.get_difficulty_loot_luck() if RunState.active else 0.0
	var dropped := 0
	for i in mini(count, 6):
		if _spawn_loot_drop(ground, _roll_loot_payload(luck)) != null:
			dropped += 1
	if dropped > 0:
		CombatVFX.ring(_actors_root, ground, 2.0, Color("62e6c3"), 0.6)
	else:
		# EnemyLootDrop should always exist; keep the reward if it does not.
		RunState.add_satchel_salvage(20 + threat * 8, 0)


func _spawn_loot_drop(position: Vector3, payload: Dictionary) -> Node:
	if _actors_root == null or payload.is_empty():
		return null
	return EnemyLootDrop.spawn(_actors_root, position, payload)


func _roll_loot_payload(luck: float = 0.0) -> Dictionary:
	var slot := _random_loot_slot()
	var level := 1 + threat * 2
	var rarity_floor := 1 if luck >= 0.10 else 0
	var rarity := ItemFactory.roll_rarity(_rng, luck, rarity_floor)
	var item := ItemFactory.generate_random_for_slot(_rng, slot, rarity, level, 0)
	var salvage := int(round((20.0 + _rng.randf_range(0.0, 24.0)) * (1.0 + 0.12 * float(threat))))
	var cores := 1 if _rng.randf() < 0.12 + luck else 0
	var label := "Salvage"
	var item_label := ""
	if not item.is_empty():
		var info := ItemFactory.describe(item)
		item_label = String(info.get("display_name", "Gear"))
		label = "%s %s" % [String(info.get("rarity_name", "")), item_label]
	return {
		"salvage": maxi(1, salvage),
		"cores": cores,
		"item": item,
		"rarity": rarity,
		"label": label,
		"item_label": item_label,
		"prompt": "Collect %s  [E]" % label,
		"threat": threat,
		"boss": false,
	}


func _random_loot_slot() -> StringName:
	var slots: Array[StringName] = [&"primary", &"helmet", &"chest", &"legs", &"cloak", &"charm"]
	return slots[_rng.randi_range(0, slots.size() - 1)]


func _build_cache_payload() -> Dictionary:
	var luck := RunState.get_difficulty_loot_luck() if RunState.active else 0.0
	var slot := _random_loot_slot()
	var rarity := maxi(1, ItemFactory.roll_rarity(_rng, maxf(luck, 0.05), 1 if luck >= 0.10 else 0))
	var item := ItemFactory.generate_random_for_slot(_rng, slot, rarity, 2 + threat * 2, 0)
	var salvage := int(round((45.0 + _rng.randf_range(0.0, 40.0)) * (1.0 + 0.15 * float(threat))))
	var cores := 1 if _rng.randf() < 0.3 + luck else 0
	var label := "Supply Cache"
	var item_label := ""
	if not item.is_empty():
		var info := ItemFactory.describe(item)
		item_label = String(info.get("display_name", "Gear"))
		label = "%s %s" % [String(info.get("rarity_name", "")), item_label]
	return {
		"salvage": maxi(1, salvage),
		"cores": cores,
		"item": item,
		"rarity": rarity,
		"label": label,
		"item_label": item_label,
		"prompt": "E — Breach cache",
		"threat": threat,
		"boss": false,
	}


func _ground_position(point: Vector3) -> Vector3:
	var y := point.y
	if world != null and world.has_method("sample_height"):
		y = float(world.call("sample_height", Vector2(point.x, point.z))) + 0.1
	return Vector3(point.x, y, point.z)


# ---------------------------------------------------------------------------
# Exfiltration, collapse, results
# ---------------------------------------------------------------------------

func request_extraction(_beacon: ExtractionBeacon) -> void:
	if _in_dungeon:
		EventBus.notification_requested.emit("No exfil underground", "Return to the surface before calling the dropship.", &"warning")
		return
	if RunState.extraction_state == &"holding" or not RunState.active:
		return
	var pad := _resolve_exfil_pad(_beacon)
	RunState.begin_extraction()
	for beacon in _exfil_sites:
		beacon.set_active(true)
	_extraction_wave_timer = 2.0
	_spawn_extraction_ship(pad)
	EventBus.radio_message.emit("Waystation Kestrel", "Dropship inbound. Hold the pad.")
	EventBus.notify("EXFIL CALLED", "The dropship is on approach. Hold the landing zone.", &"danger")


func _resolve_exfil_pad(candidate: ExtractionBeacon) -> Node3D:
	if candidate != null and is_instance_valid(candidate):
		return candidate
	var nearest: Node3D = null
	var best := INF
	for beacon in _exfil_sites:
		if beacon == null or not is_instance_valid(beacon):
			continue
		if player != null and is_instance_valid(player):
			var distance := player.global_position.distance_squared_to(beacon.global_position)
			if distance < best:
				best = distance
				nearest = beacon
		elif nearest == null:
			nearest = beacon
	if nearest != null:
		return nearest
	return null


func _spawn_extraction_ship(pad: Node3D) -> void:
	if pad == null or _extraction_ship != null:
		return
	_extraction_ship = EXTRACTION_SHIP_SCRIPT.new()
	_extraction_ship.name = "ExtractionShip"
	_site_root.add_child(_extraction_ship)
	_extraction_ship.call("setup", pad.global_position, Color("62e6c3"))
	AudioDirector.play_3d(&"exfil", pad.global_position, -4.0)


func get_extraction_ship() -> Node3D:
	return _extraction_ship


func _spawn_extraction_wave() -> void:
	if _enemy_script == null or player == null:
		return
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	var pressure := RunState.get_pressure()
	var extraction_scale := RunState.get_difficulty_extraction_scale()
	var count := clampi(int(round((2.0 + float(threat)) * RunState.get_difficulty_density() * (1.0 + pressure) * extraction_scale)), 2, 10)
	for i in count:
		if _hostiles.size() >= _max_active_hostiles():
			break
		var angle := TAU * float(i) / float(maxi(1, count)) + _rng.randf_range(-0.25, 0.25)
		var radius := _rng.randf_range(16.0, 24.0)
		var pos := player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_spawn_enemy_at(_random_enemy_data(roster), pos)
	EventBus.radio_message.emit("Mara Voss", "Contacts inbound. Keep them off the pad.")


# ---------------------------------------------------------------------------
# Escalation director and endgame pressure
# ---------------------------------------------------------------------------

func _update_escalation(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.is_dead or player.is_downed:
		return
	_update_endgame_events()
	if RunState.elapsed < DIRECTOR_GRACE:
		return
	_director_timer -= delta * RunState.get_time_scale()
	if _director_timer > 0.0:
		return
	_director_timer = maxf(4.0, lerpf(26.0, 10.0, RunState.get_pressure()) * RunState.get_difficulty_director_scale())
	if _hostiles.size() >= _max_active_hostiles():
		return
	_spawn_director_wave()
	var stage := RunState.get_late_stage()
	if stage != _late_notice_stage and stage >= 1:
		_late_notice_stage = stage
		_announce_late_stage(stage)


func _spawn_director_wave() -> void:
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	var pressure := RunState.get_pressure()
	var count := clampi(2 + int(pressure * 4.0) + threat / 2, 2, 10)
	count = mini(count, _max_active_hostiles() - _hostiles.size())
	for i in count:
		var data := _random_enemy_data(roster)
		_spawn_at_player_distance(data, _rng.randf_range(55.0, 90.0))


func _update_endgame_events() -> void:
	var fraction := RunState.get_run_fraction()
	while _endgame_cursor < ENDGAME_EVENTS.size():
		var event: Dictionary = ENDGAME_EVENTS[_endgame_cursor]
		if fraction < float(event.get("fraction", 1.0)):
			break
		_endgame_cursor += 1
		_trigger_endgame_event(event)


func _trigger_endgame_event(event: Dictionary) -> void:
	var title := String(event.get("title", "Reach Event"))
	var text := String(event.get("text", ""))
	var icon := StringName(event.get("icon", &"warning"))
	var color: Color = event.get("color", Color("ff6e6e"))
	EventBus.world_event.emit(title, text, icon, color)
	EventBus.notification_requested.emit(title, text, &"danger")
	EventBus.radio_message.emit("Mara Voss", text)
	AudioDirector.play_sfx(&"storm", -10.0)
	match StringName(event.get("id", &"")):
		&"hunter_pack":
			_spawn_pack_at(&"ashen_hound", 3, 58.0)
			_spawn_pack_at(&"bloom_stalker", 3, 66.0)
		&"rift_incursion":
			_spawn_pack_at(&"ashen_sapper", 2, 52.0)
			_spawn_pack_at(&"choir_wisp", 2, 64.0)
			var elite := _random_elite_data()
			if elite != null:
				_spawn_at_player_distance(elite, 70.0)
		&"collapse_surge":
			for i in 2:
				var elite := _random_elite_data()
				if elite != null:
					_spawn_at_player_distance(elite, _rng.randf_range(48.0, 72.0))
			var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
			for i in 4:
				if not roster.is_empty():
					_spawn_at_player_distance(_random_enemy_data(roster), _rng.randf_range(40.0, 70.0))
		&"final_stand":
			if threat >= 3 and not _has_live_boss():
				var colossus := ContentDB.get_enemy(&"rift_colossus")
				if colossus != null:
					_spawn_at_player_distance(colossus, 72.0)
			else:
				for i in 2:
					var elite := _random_elite_data()
					if elite != null:
						_spawn_at_player_distance(elite, _rng.randf_range(45.0, 65.0))
				var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
				for i in 3:
					if not roster.is_empty():
						_spawn_at_player_distance(_random_enemy_data(roster), _rng.randf_range(35.0, 60.0))
	# Every endgame beat also pushes one extra pack so the pressure curve holds
	# even for the event that rolls the fewest authored spawns.
	_spawn_extra_endgame_pack()


func _spawn_extra_endgame_pack() -> void:
	if _enemy_script == null or player == null or not is_instance_valid(player):
		return
	var roster: Array = ContentDB.get_enemy_roster_for_threat(threat)
	if roster.is_empty():
		return
	var count := clampi(2 + threat / 2, 2, 4)
	for i in count:
		if _hostiles.size() >= _max_active_hostiles():
			return
		_spawn_at_player_distance(_random_enemy_data(roster), _rng.randf_range(45.0, 75.0))


func _announce_late_stage(stage: int) -> void:
	match stage:
		1:
			EventBus.notification_requested.emit("REACH PRESSURE", "Reinforcement waves are hitting every approach. Keep moving.", &"warning")
		2:
			EventBus.notification_requested.emit("COLLAPSE SURGE", "The Reach is tearing itself open. Heavy signatures inbound.", &"danger")
		_:
			EventBus.notification_requested.emit("FINAL STAND", "One last wave before the Collapse. Survive it and extract.", &"danger")


func _spawn_pack_at(enemy_id: StringName, count: int, distance: float) -> void:
	var data := ContentDB.get_enemy(enemy_id)
	if data == null:
		return
	for i in count:
		if _hostiles.size() >= _max_active_hostiles():
			return
		_spawn_at_player_distance(data, distance + _rng.randf_range(-6.0, 6.0))


func _spawn_at_player_distance(data: EnemyData, distance: float) -> Node:
	if data == null or player == null:
		return null
	var point := _offset_point(player.global_position, maxf(25.0, distance))
	return _spawn_enemy_at(data, point)


func _elite_pool() -> Array[EnemyData]:
	var elites: Array[EnemyData] = []
	for enemy in ContentDB.enemies.values():
		if enemy.elite and not enemy.boss:
			elites.append(enemy)
	return elites


func _random_elite_data() -> EnemyData:
	var elites := _elite_pool()
	if elites.is_empty():
		return null
	return elites[_rng.randi_range(0, elites.size() - 1)]


func _has_live_boss() -> bool:
	if _active_boss == null or not is_instance_valid(_active_boss):
		return false
	var health := CombatUtils.find_health(_active_boss)
	return health != null and not health.dead


func _process(delta: float) -> void:
	if not started or ending:
		return
	RunState.tick(delta)
	_update_rideable_hud(delta)
	_update_music_state(delta)
	if _in_dungeon:
		# The under-reach is a sealed encounter space: the run clock keeps
		# ticking, but the surface director, storm and garrison staging pause.
		_compass_timer -= delta
		if _compass_timer <= 0.0:
			_compass_timer = 0.5
			_update_compass_markers()
		return
	if RunState.is_tutorial():
		# Training has no storm, director, world events or hostile population.
		_compass_timer -= delta
		if _compass_timer <= 0.0:
			_compass_timer = 0.5
			_update_compass_markers()
		if RunState.extraction_state == &"holding":
			if not _exfil_cinematic_done and RunState.extraction_timer <= 0.0:
				_begin_exfil_cutscene()
				return
			if not _exfil_cinematic_playing:
				RunState.tick_extraction(delta)
		return
	_compass_timer -= delta
	if _compass_timer <= 0.0:
		_compass_timer = 0.5
		_update_compass_markers()
	if _event_cursor < _scheduled_events.size() and RunState.elapsed >= float(_scheduled_events[_event_cursor].get("time", 9999.0)) and RunState.extraction_state != &"holding":
		_trigger_world_event(_scheduled_events[_event_cursor])
		_event_cursor += 1
	_update_escalation(delta)
	_staging_timer -= delta
	if _staging_timer <= 0.0:
		_staging_timer = 1.0
		_update_staged_garrisons()
	_prune_timer -= delta
	if _prune_timer <= 0.0:
		_prune_timer = 5.0
		_prune_distant_hostiles()
	if RunState.extraction_state == &"holding":
		# The last tick of the hold is the escape: hand the view to the exfil
		# cut-scene first, then let RunState end the run behind it.
		if not _exfil_cinematic_done and RunState.extraction_timer <= 0.0:
			_begin_exfil_cutscene()
			return
		if _exfil_cinematic_playing:
			return
		var ended := RunState.tick_extraction(delta)
		if ended:
			return
		_extraction_wave_timer -= delta * RunState.get_time_scale()
		if _extraction_wave_timer <= 0.0:
			_extraction_wave_timer = lerpf(10.0, 6.0, RunState.get_pressure())
			_spawn_extraction_wave()
	if RunState.storm_active:
		if not _storm_notified:
			_storm_notified = true
			EventBus.radio_message.emit("Waystation Kestrel", "Collapse is here. Get inside the storm eye or get out.")
			AudioDirector.play_sfx(&"storm", -8.0)
		_storm_damage_timer -= delta * RunState.get_time_scale()
		if _storm_damage_timer <= 0.0 and player != null and is_instance_valid(player) and not player.is_dead and not player.is_downed:
			_storm_damage_timer = 0.5
			var radius := RunState.get_safe_radius()
			if player.global_position.length() > radius:
				player.take_fall_or_hazard_damage(14.0 + threat * 3.0, self)
				EventBus.notification_requested.emit("STORM DAMAGE", "Move toward the eye of the Collapse!", &"danger")


func _on_player_died() -> void:
	if ending:
		return
	ending = true
	if App != null and App.has_method("abort_cinematic"):
		App.call("abort_cinematic")
	await get_tree().create_timer(1.6).timeout
	RunState.end_run(false, "You fell in the Reach.")
	finished.emit(RunState.get_result_preview())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if RunState.active and not ending:
			pass


func get_world() -> Node3D:
	return world


func get_objective_sites() -> Array[ObjectiveSite]:
	return _objective_sites.duplicate()


func get_exfil_sites() -> Array[ExtractionBeacon]:
	return _exfil_sites.duplicate()


func get_world_map_texture() -> Texture2D:
	if world != null and world.has_method("get_map_texture"):
		return world.call("get_map_texture") as Texture2D
	return null


func get_companion_manager() -> Node:
	return companion_manager


## Snapshot consumed by the HUD minimap and tactical map. World positions only;
## the UI projects them onto the authored map texture.
func get_tactical_data() -> Dictionary:
	var map_texture: Texture2D = get_world_map_texture()
	var map_size := 1800.0
	if world != null:
		var configured_size = world.get("map_size")
		if configured_size is float or configured_size is int:
			map_size = maxf(200.0, float(configured_size))
	var markers: Array = []
	for site in _objective_sites:
		if site == null or not is_instance_valid(site) or site.completed:
			continue
		var site_color := Color("62e6c3")
		var site_kind: StringName = &"objective"
		if site.site_type == &"shrine":
			site_color = Color("c79cff")
			site_kind = &"shrine"
		elif site.site_type == &"supply":
			site_color = Color("ffb866")
			site_kind = &"supply"
		markers.append({
			"position": site.global_position,
			"kind": site_kind,
			"label": site.title,
			"color": site_color,
		})
	for beacon in _exfil_sites:
		if beacon != null and is_instance_valid(beacon):
			markers.append({
				"position": beacon.global_position,
				"kind": &"exfil",
				"label": String(beacon.get("beacon_name")) if beacon.get("beacon_name") != null else "Exfil",
				"color": Color("ffb866"),
			})
	for i in _poi_cache.size():
		var poi: Dictionary = _poi_cache[i]
		var discovered := bool(_discovered_pois.get(i, false))
		markers.append({
			"position": poi.get("position", Vector3.ZERO),
			"kind": &"poi" if discovered else &"building",
			"label": String(poi.get("name", "Point of Interest")),
			"color": Color("93a5a8") if discovered else Color("5d6f72"),
			"discovered": discovered,
		})
	for cache in _loot_caches:
		if cache == null or not is_instance_valid(cache) or not (cache is Node3D):
			continue
		markers.append({
			"position": (cache as Node3D).global_position,
			"kind": &"cache",
			"label": "Supply Cache",
			"color": Color("ffb866"),
		})
	for bounty in _bounty_targets:
		if bounty == null or not is_instance_valid(bounty) or not (bounty is Node3D):
			continue
		markers.append({
			"position": (bounty as Node3D).global_position,
			"kind": &"bounty",
			"label": "Bounty Target",
			"color": Color("ff6e6e"),
		})
	for entry in _dungeon_entries:
		if entry.get("position") is Vector3:
			markers.append({
				"position": entry["position"],
				"kind": &"dungeon",
				"label": String(entry.get("name", "Under-Reach")),
				"color": Color("c79cff"),
			})
	var weather: Dictionary = {}
	var clock_text := ""
	var time_of_day := RunState.time_of_day
	var is_night := false
	if world != null:
		if world.has_method("get_weather_system"):
			var weather_node = world.call("get_weather_system")
			if weather_node != null and is_instance_valid(weather_node):
				weather = weather_node.call("get_state")
		if world.has_method("get_day_night_cycle"):
			var cycle = world.call("get_day_night_cycle")
			if cycle != null and is_instance_valid(cycle):
				clock_text = String(cycle.call("get_clock_text"))
				time_of_day = float(cycle.call("get_time_of_day"))
				is_night = bool(cycle.call("is_night"))
	RunState.set_environment_snapshot(StringName(weather.get("id", &"")), String(weather.get("display_name", "")), time_of_day)
	var hostiles: Array = []
	for hostile in _hostiles:
		if hostile == null or not is_instance_valid(hostile) or not (hostile is Node3D):
			continue
		if hostile.has_method("is_alive") and not bool(hostile.call("is_alive")):
			continue
		hostiles.append((hostile as Node3D).global_position)
		if hostiles.size() >= 48:
			break
	var allies: Array = []
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally is Node3D and is_instance_valid(ally):
			allies.append((ally as Node3D).global_position)
	for pet in get_tree().get_nodes_in_group("pets"):
		if pet is Node3D and is_instance_valid(pet):
			allies.append((pet as Node3D).global_position)
	var boss_position: Variant = null
	if _active_boss != null and is_instance_valid(_active_boss) and _active_boss is Node3D:
		boss_position = (_active_boss as Node3D).global_position
	var player_position := Vector3.ZERO
	var player_yaw := 0.0
	if player != null and is_instance_valid(player):
		player_position = player.global_position
		player_yaw = player.yaw
	return {
		"map_texture": map_texture,
		"map_size": map_size,
		"player_position": player_position,
		"player_yaw": player_yaw,
		"markers": markers,
		"hostiles": hostiles,
		"allies": allies,
		"boss_position": boss_position,
		"safe_radius": RunState.get_safe_radius(),
		"storm_active": RunState.storm_active,
		"extraction_state": String(RunState.extraction_state),
		"time_left": RunState.get_time_left(),
		"difficulty_name": RunState.get_difficulty_name(),
		"mode_name": RunState.get_mode_name(),
		"planet_id": String(RunState.planet_id),
		"planet_name": RunState.get_planet_name(),
		"weather": weather,
		"weather_name": String(weather.get("display_name", "")),
		"weather_icon": String(weather.get("icon", &"weather-sun")),
		"weather_color": weather.get("color", Color("ffc16b")),
		"clock_text": clock_text,
		"time_of_day": time_of_day,
		"is_night": is_night,
		"hazard": String(weather.get("hazard", &"none")),
		"in_dungeon": _in_dungeon,
		"dungeon_name": get_dungeon_name(),
		"dungeons_cleared": RunState.dungeons_cleared,
		"stage_index": RunState.stage_index,
		"stage_total": RunState.stage_total,
		"stage_title": RunState.stage_title,
		"mode_id": String(RunState.get_mode_id()),
		"map_name": RunState.get_map_preset_name(),
		"map_preset_id": String(RunState.get_map_preset_id()),
		"objective_progress": RunState.get_objective_progress(&"contract"),
		"objective_total": RunState.get_objective_total(&"contract"),
		"loot_caches": get_loot_caches().size(),
		"mission_count": RunState.get_objective_total(&"contract"),
	}


func _update_discovery() -> void:
	if player == null or not is_instance_valid(player):
		return
	for i in _poi_cache.size():
		if bool(_discovered_pois.get(i, false)):
			continue
		var poi: Dictionary = _poi_cache[i]
		var position: Vector3 = poi.get("position", Vector3.ZERO)
		if player.global_position.distance_squared_to(position) > POI_DISCOVERY_RADIUS * POI_DISCOVERY_RADIUS:
			continue
		_discovered_pois[i] = true
		_on_poi_discovered(i, poi)


func _on_poi_discovered(index: int, poi: Dictionary) -> void:
	if index >= 0 and index < _poi_markers.size():
		var marker = _poi_markers[index]
		if marker != null and is_instance_valid(marker) and marker.has_method("set_discovered"):
			marker.call("set_discovered", true)
	var poi_name := String(poi.get("name", "Location"))
	RunState.add_satchel_salvage(15 + threat * 5, 0)
	EventBus.notify("Location discovered", "%s mapped. Survey salvage cached in your satchel." % poi_name, &"success")
	EventBus.radio_message.emit("Waystation Kestrel", poi_name + " is on your map now.")


func _update_dungeon_compass() -> void:
	if _active_dungeon == null or not is_instance_valid(_active_dungeon):
		return
	var entries: Array = []
	var exit_position: Vector3 = _active_dungeon.call("get_exit_global_position")
	entries.append({"degrees": _bearing_to(exit_position), "color": Color("62e6c3"), "kind": &"exfil"})
	if not bool(_active_dungeon.call("is_cleared")):
		var boss_position: Vector3 = _active_dungeon.call("get_boss_global_position")
		entries.append({"degrees": _bearing_to(boss_position), "color": Color("ff6e6e"), "kind": &"bounty"})
	var hud = _get_hud()
	if hud != null and hud.has_method("set_compass_markers"):
		hud.call("set_compass_markers", entries)
	_mission_trackers = _build_mission_trackers()
	if hud != null and hud.has_method("set_mission_trackers"):
		hud.call("set_mission_trackers", _mission_trackers.duplicate(true))


func _update_compass_markers() -> void:
	if player == null or not is_instance_valid(player):
		return
	if _in_dungeon:
		_update_dungeon_compass()
		return
	_update_discovery()
	_mission_trackers = _build_mission_trackers()
	var hud = _get_hud()
	if hud == null:
		return
	var entries: Array = []
	for site in _objective_sites:
		if site == null or not is_instance_valid(site) or site.completed:
			continue
		var site_color := Color("62e6c3")
		var site_kind: StringName = &"objective"
		if site.site_type == &"shrine":
			site_color = Color("c79cff")
			site_kind = &"shrine"
		elif site.site_type == &"supply":
			site_color = Color("ffb866")
			site_kind = &"supply"
		entries.append({"degrees": _bearing_to(site.global_position), "color": site_color, "kind": site_kind})
	for beacon in _exfil_sites:
		if beacon != null and is_instance_valid(beacon):
			entries.append({"degrees": _bearing_to(beacon.global_position), "color": Color("ffb866"), "kind": &"exfil"})
	for cache in _loot_caches:
		if cache == null or not is_instance_valid(cache) or not (cache is Node3D):
			continue
		entries.append({"degrees": _bearing_to((cache as Node3D).global_position), "color": Color("ffb866"), "kind": &"cache"})
	for bounty in _bounty_targets:
		if bounty == null or not is_instance_valid(bounty) or not (bounty is Node3D):
			continue
		entries.append({"degrees": _bearing_to((bounty as Node3D).global_position), "color": Color("ff6e6e"), "kind": &"bounty"})
	for i in _poi_cache.size():
		if not bool(_discovered_pois.get(i, false)):
			continue
		entries.append({
			"degrees": _bearing_to(_poi_cache[i].get("position", Vector3.ZERO)),
			"color": Color("93a5a8"),
			"kind": &"poi",
		})
	if hud.has_method("set_compass_markers"):
		hud.call("set_compass_markers", entries)
	if hud.has_method("set_mission_trackers"):
		hud.call("set_mission_trackers", _mission_trackers.duplicate(true))


func _bearing_to(target: Vector3) -> float:
	var to := target - player.global_position
	return fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)


# ---------------------------------------------------------------------------
# Mission tracking, caches, markers and hostile population control
# ---------------------------------------------------------------------------

func get_loot_caches() -> Array:
	var caches: Array = []
	for cache in _loot_caches:
		if cache == null or not is_instance_valid(cache):
			continue
		if bool(cache.get("is_open")):
			continue
		caches.append(cache)
	return caches


func get_mission_trackers() -> Array:
	_mission_trackers = _build_mission_trackers()
	return _mission_trackers.duplicate(true)


func _build_mission_trackers() -> Array:
	var trackers: Array = []
	var contract_total := RunState.get_objective_total(&"contract")
	if contract_total > 0:
		trackers.append({
			"id": &"contract",
			"kind": &"contract",
			"title": _contract_label,
			"icon": &"target",
			"color": Color("62e6c3"),
			"world_position": _nearest_objective_position(),
			"progress": RunState.get_objective_progress(&"contract"),
			"total": contract_total,
			"stage_number": RunState.stage_index + 1,
			"stage_total": RunState.stage_total,
			"stage_title": RunState.stage_title,
		})
	var cache_total := RunState.get_objective_total(&"side_caches")
	if cache_total > 0:
		trackers.append({
			"id": &"side_caches",
			"kind": &"cache",
			"title": "Side caches",
			"icon": &"cache",
			"color": Color("ffb866"),
			"world_position": _nearest_cache_position(),
			"progress": RunState.get_objective_progress(&"side_caches"),
			"total": cache_total,
		})
	var bounty_total := RunState.get_objective_total(&"bounties")
	if bounty_total > 0:
		trackers.append({
			"id": &"bounties",
			"kind": &"bounty",
			"title": "Marked bounties",
			"icon": &"skull",
			"color": Color("ff6e6e"),
			"world_position": _nearest_bounty_position(),
			"progress": RunState.get_objective_progress(&"bounties"),
			"total": bounty_total,
		})
	var shrine_total := RunState.get_objective_total(&"shrine")
	if shrine_total > 0:
		trackers.append({
			"id": &"shrine",
			"kind": &"shrine",
			"title": "Rift Shrine",
			"icon": &"bolt",
			"color": Color("c79cff"),
			"world_position": _shrine_position(),
			"progress": RunState.get_objective_progress(&"shrine"),
			"total": shrine_total,
		})
	return trackers


func _nearest_objective_position() -> Vector3:
	if player == null or not is_instance_valid(player):
		return _spawn_position
	var best := _spawn_position
	var best_distance := 1.0e20
	for site in _objective_sites:
		if site == null or not is_instance_valid(site) or site.completed:
			continue
		var distance := player.global_position.distance_squared_to(site.global_position)
		if distance < best_distance:
			best_distance = distance
			best = site.global_position
	return best


func _nearest_cache_position() -> Vector3:
	if player == null or not is_instance_valid(player):
		return _spawn_position
	var best := _spawn_position
	var best_distance := 1.0e20
	for cache in _loot_caches:
		if cache == null or not is_instance_valid(cache) or not (cache is Node3D):
			continue
		if bool(cache.get("is_open")):
			continue
		var distance := player.global_position.distance_squared_to((cache as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = (cache as Node3D).global_position
	return best


func _nearest_bounty_position() -> Vector3:
	if player == null or not is_instance_valid(player):
		return _spawn_position
	var best := _spawn_position
	var best_distance := 1.0e20
	for bounty in _bounty_targets:
		if bounty == null or not is_instance_valid(bounty) or not (bounty is Node3D):
			continue
		var distance := player.global_position.distance_squared_to((bounty as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = (bounty as Node3D).global_position
	return best


func _shrine_position() -> Vector3:
	if _shrine_site != null and is_instance_valid(_shrine_site):
		return _shrine_site.global_position
	return _spawn_position


func _spawn_poi_markers() -> void:
	for marker in _poi_markers:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_poi_markers.clear()
	# Keep the marker list index-aligned with _poi_cache so discovery updates can
	# address a POI by index. Exfil pads already have ExtractionBeacon visuals,
	# so they keep a null slot instead of a duplicate beacon.
	_poi_markers.resize(_poi_cache.size())
	for i in _poi_cache.size():
		var poi: Dictionary = _poi_cache[i]
		if String(poi.get("type", "")) == "exfil_pad":
			continue
		var marker = WORLD_MARKER_SCRIPT.new()
		if not (marker is Node3D):
			continue
		marker.name = "POIMarker%d" % i
		_site_root.add_child(marker)
		marker.call(
			"setup",
			String(poi.get("name", "Point of Interest")),
			&"poi",
			Color("93a5a8"),
			_ground_position(poi.get("position", Vector3.ZERO))
		)
		marker.call("set_discovered", bool(_discovered_pois.get(i, false)))
		_poi_markers[i] = marker


func _max_active_hostiles() -> int:
	# Difficulty owns the live cap; MAX_ACTIVE_HOSTILES stays the fallback used
	# by sandbox scenes that never start a run.
	if RunState.active:
		return maxi(24, RunState.get_difficulty_max_hostiles())
	return MAX_ACTIVE_HOSTILES


func _prune_distant_hostiles() -> void:
	if ending or player == null or not is_instance_valid(player):
		return
	if player.is_dead or player.is_downed:
		return
	var limit_squared := HOSTILE_PRUNE_RADIUS * HOSTILE_PRUNE_RADIUS
	var stale: Array = []
	for hostile in _hostiles:
		if hostile == null or not is_instance_valid(hostile):
			stale.append(hostile)
			continue
		if hostile == _active_boss:
			continue
		if _objective_targets.has(hostile) or hostile in _bounty_targets:
			continue
		if not (hostile is Node3D):
			continue
		if hostile.has_method("is_boss") and bool(hostile.call("is_boss")):
			continue
		if (hostile as Node3D).global_position.distance_squared_to(player.global_position) > limit_squared:
			stale.append(hostile)
	for hostile in stale:
		_hostiles.erase(hostile)
		if is_instance_valid(hostile):
			hostile.queue_free()
