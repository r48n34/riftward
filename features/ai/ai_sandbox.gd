extends Node3D
## RIFTWARD AI sandbox — visual/behaviour test for enemy agents and loot.
## Run windowed:
##   Godot_v4.7.2-stable_win64_console.exe --path D:\godotGa\game \
##       res://features/ai/ai_sandbox.tscn
## Run headless smoke (autoloads + real Player + agents + navmesh bake):
##   ... --headless --path D:\godotGa\game res://features/ai/ai_sandbox.tscn --quit-after 400
##
## Controls: WASD/mouse = player movement (real Player), LMB fire, E collect,
## R = respawn wave, B = spawn boss, Tab = toggle debug overlay, Esc = mouse mode.
## If the Player script is unavailable the sandbox spawns a stub target instead.

const PLAYER_SCRIPT := "res://features/player/player.gd"
const ARENA_SIZE := 86.0
const PLAYER_SPAWN := Vector3(0.0, 0.25, 20.0)
const ENEMY_ORIGIN := Vector3(0.0, 0.0, -8.0)

@export var enemy_count: int = 6
@export var spawn_boss_on_start: bool = false
@export var bake_navigation: bool = true
## Headless smoke: step physics for this many frames, log diagnostics, then
## quit(0). Set 0 to keep running (e.g. for automated screenshot harnesses).
@export var headless_smoke_frames: int = 600

var _player: Node3D = null
var _using_real_player: bool = false
var _spawner: EnemySpawner = null
var _nav_region: NavigationRegion3D = null
var _arena: Node3D = null

var _overlay: CanvasLayer = null
var _stats_label: Label = null
var _debug_label: Label = null
var _debug_visible: bool = true
var _hud_timer: float = 0.0
var _headless: bool = false
var _kills: int = 0
var _boss_active: EnemyAgent = null
var _headless_physics: int = 0


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_build_environment()
	_build_arena()
	_spawn_player()
	_build_spawner()
	if bake_navigation:
		call_deferred("_bake_navigation")
	_spawn_wave(ENEMY_ORIGIN, enemy_count)
	if spawn_boss_on_start:
		_spawn_boss()
	_build_overlay()
	print("[AI SANDBOX] ready: real_player=%s enemies=%d headless=%s" % [
		str(_using_real_player), _spawner.get_alive_count(), str(_headless)
	])


func _physics_process(_delta: float) -> void:
	if not _headless:
		return
	_headless_physics += 1
	if _headless_physics % 120 == 0:
		_print_diagnostics()
	if headless_smoke_frames > 0 and _headless_physics >= headless_smoke_frames:
		_print_diagnostics()
		_print_smoke_summary()
		get_tree().quit(0)


func _process(delta: float) -> void:
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		_refresh_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			_spawn_wave(ENEMY_ORIGIN, enemy_count)
		KEY_B:
			_spawn_boss()
		KEY_TAB:
			_debug_visible = not _debug_visible
			if _debug_label != null:
				_debug_label.visible = _debug_visible
		KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ---------------------------------------------------------------------------
# World
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2a4a5c")
	sky_mat.sky_horizon_color = Color("e6cda4")
	sky_mat.ground_bottom_color = Color("1a2225")
	sky_mat.ground_horizon_color = Color("8a7f6a")
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("c3ae8e")
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.3
	var world_env := WorldEnvironment.new()
	world_env.name = "SandboxEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color("ffe4c2")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-18.0, -132.0, 0.0)
	fill.light_color = Color("9fd8ff")
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	add_child(fill)


func _build_arena() -> void:
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var floor_mesh_box := BoxMesh.new()
	floor_mesh_box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	floor_mesh.mesh = floor_mesh_box
	floor_mesh.material_override = _material(Color("2b393d"), 0.0, 0.05, 0.92)
	floor_mesh.position = Vector3(0.0, -0.5, 0.0)
	_arena.add_child(floor_mesh)

	# Lane stripes for spatial readability while moving.
	for i in 5:
		var stripe := MeshInstance3D.new()
		var stripe_box := BoxMesh.new()
		stripe_box.size = Vector3(0.35, 0.02, ARENA_SIZE - 6.0)
		stripe.mesh = stripe_box
		stripe.material_override = _material(Color("33484a"), 0.0, 0.0, 0.88)
		stripe.position = Vector3(-12.0 + float(i) * 6.0, 0.012, 0.0)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arena.add_child(stripe)

	# Player spawn pad.
	_spawn_pad(PLAYER_SPAWN, Color("62e6c3"), 2.2)
	_spawn_pad(ENEMY_ORIGIN, Color("ffb866"), 3.0)

	# Cover layout: mixed crates, barriers and pillars.
	var covers := [
		{"p": Vector3(-10.0, 1.0, 6.0), "s": Vector3(4.0, 2.0, 1.2), "c": "7d4a33"},
		{"p": Vector3(9.0, 1.3, 4.0), "s": Vector3(3.0, 2.6, 1.6), "c": "313f43"},
		{"p": Vector3(-5.0, 0.6, -2.0), "s": Vector3(2.4, 1.2, 2.4), "c": "d8cfc0"},
		{"p": Vector3(6.0, 0.7, -3.0), "s": Vector3(2.8, 1.4, 2.0), "c": "2f5f5a"},
		{"p": Vector3(-16.0, 1.6, -6.0), "s": Vector3(2.0, 3.2, 2.0), "c": "7d4a33"},
		{"p": Vector3(15.0, 1.6, -7.0), "s": Vector3(2.0, 3.2, 2.0), "c": "7d4a33"},
		{"p": Vector3(0.0, 0.55, -14.0), "s": Vector3(5.0, 1.1, 1.4), "c": "313f43"},
		{"p": Vector3(-12.0, 0.9, 15.0), "s": Vector3(3.2, 1.8, 1.2), "c": "2f5f5a"},
		{"p": Vector3(13.0, 0.9, 13.0), "s": Vector3(3.2, 1.8, 1.2), "c": "d8cfc0"},
		{"p": Vector3(-20.0, 1.0, 2.0), "s": Vector3(1.2, 2.0, 6.0), "c": "26383d"},
		{"p": Vector3(20.0, 1.0, -2.0), "s": Vector3(1.2, 2.0, 6.0), "c": "26383d"},
		{"p": Vector3(-8.0, 0.5, -10.0), "s": Vector3(1.6, 1.0, 1.6), "c": "d8cfc0"},
	]
	for entry in covers:
		var position: Vector3 = entry["p"]
		var size: Vector3 = entry["s"]
		var color: Color = Color(String(entry["c"]))
		_add_cover_block(position, size, color)

	# Perimeter markers so the arena edge reads clearly.
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var marker := MeshInstance3D.new()
		var marker_box := BoxMesh.new()
		marker_box.size = Vector3(0.6, 2.4, 0.6)
		marker.mesh = marker_box
		marker.material_override = _material(Color("62e6c3"), 1.2, 0.0, 0.4, true)
		marker.position = Vector3(cos(angle) * 40.0, 1.2, sin(angle) * 40.0)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arena.add_child(marker)


func _add_cover_block(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_arena.add_child(body)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(color, 0.0, 0.18, 0.62)
	body.add_child(mesh)

	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(size.x * 1.02, 0.06, size.z * 1.02)
	trim.mesh = trim_mesh
	trim.material_override = _material(Color("ffb866"), 1.1, 0.0, 0.4, true)
	trim.position = Vector3(0.0, size.y * 0.5 - 0.04, 0.0)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(trim)


func _spawn_pad(center: Vector3, color: Color, radius: float) -> void:
	var pad := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.04
	cylinder.radial_segments = 16
	pad.mesh = cylinder
	var pad_material := _material(Color(color.r, color.g, color.b, 0.5), 0.8, 0.0, 0.4, true)
	pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad.material_override = pad_material
	pad.position = Vector3(center.x, 0.03, center.z)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arena.add_child(pad)


func _material(
	color: Color,
	emission: float = 0.0,
	metallic: float = 0.0,
	roughness: float = 0.7,
	unshaded: bool = false
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


# ---------------------------------------------------------------------------
# Actors
# ---------------------------------------------------------------------------

func _spawn_player() -> void:
	if ResourceLoader.exists(PLAYER_SCRIPT):
		var player_script: Script = load(PLAYER_SCRIPT)
		if player_script != null and player_script.can_instantiate():
			var instance = player_script.new()
			if instance is Node3D:
				_player = instance as Node3D
				add_child(_player)
				_player.global_position = PLAYER_SPAWN
				_using_real_player = true
				print("[AI SANDBOX] spawned real Player from ", PLAYER_SCRIPT)
				return
	push_warning("[AI SANDBOX] Player script unavailable; using stub target.")
	_spawn_stub_player()


func _spawn_stub_player() -> void:
	var stub := CharacterBody3D.new()
	stub.name = "StubPlayer"
	stub.collision_layer = 2
	stub.collision_mask = 1
	stub.add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	stub.add_child(shape)
	var health := HealthComponent.new()
	health.name = "Health"
	health.team = StatKeys.TEAM_PLAYER
	stub.add_child(health)
	health.configure(400.0, 100.0, 0.0, StatKeys.TEAM_PLAYER)
	stub.set_meta("health_component", health)
	add_child(stub)
	stub.global_position = PLAYER_SPAWN
	_player = stub
	var camera := Camera3D.new()
	camera.name = "StubCamera"
	camera.position = Vector3(0.0, 2.2, 24.0)
	camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	camera.current = true
	add_child(camera)


func _build_spawner() -> void:
	_spawner = EnemySpawner.new()
	_spawner.name = "EnemySpawner"
	_spawner.threat = 2
	add_child(_spawner)
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_spawner.enemy_defeated.connect(_on_enemy_defeated)


func _spawn_wave(origin: Vector3, count: int) -> void:
	if _spawner == null:
		return
	var roster := _roster()
	_spawner.spawn_wave(roster, origin, count, 2)


func _roster() -> Array[EnemyData]:
	var cdb := get_node_or_null("/root/ContentDB")
	var out: Array[EnemyData] = []
	if cdb == null:
		return out
	var wanted: Array[StringName] = [
		&"ashen_scrapper",
		&"ashen_marksman",
		&"ashen_bulwark",
		&"bloom_stalker",
		&"bloom_spitter",
		&"choir_sentinel",
	]
	for id in wanted:
		var data = cdb.call("get_enemy", id)
		if data is EnemyData:
			out.append(data as EnemyData)
	return out


func _spawn_boss() -> void:
	if _spawner == null:
		return
	if _boss_active != null and is_instance_valid(_boss_active) and _boss_active.is_alive():
		return
	_boss_active = _spawner.spawn_boss(Vector3(0.0, 0.0, -18.0), &"the_warden")
	if _boss_active != null:
		print("[AI SANDBOX] boss spawned: ", _boss_active.get_display_name())
		EventBus.notify("Boss Signal", "%s has entered the arena." % _boss_active.get_display_name(), &"danger")


func _on_enemy_spawned(agent: EnemyAgent) -> void:
	agent.defeated.connect(_on_agent_defeated)


func _on_agent_defeated(_agent: EnemyAgent) -> void:
	_kills += 1


func _on_enemy_defeated(_agent: EnemyAgent) -> void:
	pass


func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, self)
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavigationRegion"
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	print("[AI SANDBOX] navmesh baked: vertices=%d polygons=%d" % [
		nav_mesh.get_vertices().size(), nav_mesh.get_polygon_count()
	])


# ---------------------------------------------------------------------------
# Overlay / diagnostics
# ---------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "SandboxOverlay"
	_overlay.layer = 5
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(430.0, 0.0)
	_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := Label.new()
	title.text = "RIFTWARD  ·  AI SANDBOX"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f4efe5"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "enemywright — enemy agents, combat AI, loot drops"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("93a5a8"))
	box.add_child(subtitle)
	var hints := Label.new()
	hints.text = "WASD / Mouse — move · LMB — fire · E — collect\nR — new wave · B — spawn boss · Tab — debug · Esc — mouse"
	hints.add_theme_font_size_override("font_size", 12)
	hints.add_theme_color_override("font_color", Color("62e6c3"))
	box.add_child(hints)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 15)
	_stats_label.add_theme_color_override("font_color", Color("ffb866"))
	box.add_child(_stats_label)

	_debug_label = Label.new()
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug_label.position = Vector2(-420.0, 18.0)
	_debug_label.custom_minimum_size = Vector2(400.0, 0.0)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color("d8e6e4"))
	_overlay.add_child(_debug_label)

	var crosshair := ColorRect.new()
	crosshair.color = Color("62e6c3")
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2.0
	crosshair.offset_top = -2.0
	crosshair.offset_right = 2.0
	crosshair.offset_bottom = 2.0
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(crosshair)


func _refresh_overlay() -> void:
	if _stats_label == null:
		return
	var alive := _spawner.get_alive_count() if _spawner != null else 0
	var satchel := 0
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		satchel = int(run_state.get("satchel_salvage"))
	var boss_text := "none"
	if _boss_active != null and is_instance_valid(_boss_active) and _boss_active.is_alive():
		boss_text = "%s  phase %d" % [_boss_active.get_display_name(), _boss_active.get_boss_phase()]
	_stats_label.text = "Alive %d   ·   Kills %d   ·   Satchel %d   ·   Boss %s   ·   Nav %s" % [
		alive, _kills, satchel, boss_text,
		("baked" if _nav_region != null else "fallback"),
	]
	if _debug_label != null and _debug_visible and _spawner != null:
		var lines: Array[String] = ["ENEMY STATE"]
		var agents := _spawner.get_alive_agents()
		for i in mini(agents.size(), 8):
			var agent := agents[i]
			var info := agent.get_debug_info()
			lines.append("%-18s %-7s hp %5.1f  atk %.2f  %s" % [
				agent.get_display_name(),
				String(info["state"]),
				float(info["hp"]),
				float(info["attack_timer"]),
				String(info["pending"]),
			])
		if agents.size() > 8:
			lines.append("... %d more" % (agents.size() - 8))
		_debug_label.text = "\n".join(lines)


func _print_diagnostics() -> void:
	if _spawner == null:
		return
	var states: Array[String] = []
	var navigating := 0
	for agent in _spawner.get_alive_agents():
		var info := agent.get_debug_info()
		var uses_nav: bool = info["nav"]
		if uses_nav:
			navigating += 1
		states.append("%s:%s(hp %.0f,shots %d,attacks %d,nav %s)" % [
			agent.get_display_name(),
			String(info["state"]),
			float(info["hp"]),
			int(info["shots"]),
			agent.get_shot_count() + agent.get_melee_count(),
			str(info["nav"]),
		])
	print("[AI SANDBOX] alive=%d nav=%d/%d kills=%d player=%s states=%s" % [
		_spawner.get_alive_count(),
		navigating,
		_spawner.get_alive_count(),
		_kills,
		_player_status(),
		", ".join(states),
	])


func _player_status() -> String:
	if _player == null or not is_instance_valid(_player):
		return "missing"
	var health := CombatUtils.find_health(_player)
	var downed := false
	if "is_downed" in _player:
		downed = _player.get("is_downed")
	if health == null:
		return "no-health"
	return "hp %.0f/%.0f shield %.0f/%0.f downed=%s" % [
		health.health, health.max_health, health.shield, health.max_shield, str(downed)
	]


func _print_smoke_summary() -> void:
	if _spawner == null:
		return
	var loot := 0
	for child in _spawner.get_children():
		if child is EnemyLootDrop:
			loot += 1
	var satchel := 0
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		satchel = int(run_state.get("satchel_salvage"))
	print("[AI SANDBOX] SMOKE OK frames=%d alive=%d kills=%d loot_on_ground=%d satchel=%d nav_baked=%s player=%s" % [
		_headless_physics,
		_spawner.get_alive_count(),
		_kills,
		loot,
		satchel,
		str(_nav_region != null),
		_player_status(),
	])
