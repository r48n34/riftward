extends Node3D
## COMPANIONS SANDBOX — visual QA scene for the friendly squad + Driftling.
##
## Open/run directly:
##   <godot> --path D:\godotGa\game res://features/companions/companions_sandbox.tscn
##
## Capture a screenshot (for reviews) with:
##   <godot> --path D:\godotGa\game res://features/companions/companions_sandbox.tscn -- --capture
## Writes res://features/companions/preview/squad.png and quits.
##
## The sandbox spawns the real Player (autoloads are live), the CompanionManager
## (2 active Wardens + active Driftling from ProfileState), two inert training
## drones for the squad to shoot at, and a cinematic third-person camera.

const PlayerScriptPath := "res://features/player/player.gd"
const ManagerScriptPath := "res://features/companions/companion_manager.gd"
const PROPS_SEED := 7123

var _player: Node = null
var _manager: Node = null
var _camera: Camera3D = null
var _player_stand_in: Node3D = null
var _rng := RandomNumberGenerator.new()
var _capture_requested := false


func _ready() -> void:
	_rng.seed = PROPS_SEED
	_capture_requested = "--capture" in OS.get_cmdline_user_args()
	_build_lighting()
	_build_ground()
	_build_props()
	_build_drones()
	_spawn_player()
	await get_tree().process_frame
	_spawn_squad()
	await get_tree().create_timer(0.5).timeout
	_setup_camera()
	if _capture_requested:
		_capture_and_quit()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player_stand_in == null:
		return
	if not (_player is Node3D):
		return
	_player_stand_in.global_position = (_player as Node3D).global_position
	if _player.has_method("get_forward"):
		var forward = _player.call("get_forward")
		if forward is Vector3:
			var flat := forward as Vector3
			flat.y = 0.0
			if flat.length_squared() > 0.01:
				_player_stand_in.rotation.y = atan2(-flat.x, -flat.z)


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("1d3d4a")
	sky_material.sky_horizon_color = Color("efd0a2")
	sky_material.sky_curve = 0.22
	sky_material.ground_bottom_color = Color("172327")
	sky_material.ground_horizon_color = Color("b99470")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("dcc4a2")
	env.fog_light_energy = 0.55
	env.fog_density = 0.0045
	env.fog_sun_scatter = 0.32
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38.0, -34.0, 0.0)
	sun.light_color = Color("ffdcaa")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-14.0, 148.0, 0.0)
	fill.light_color = Color("8fd8e6")
	fill.light_energy = 0.5
	add_child(fill)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160.0, 1.0, 160.0)
	shape.shape = box
	ground.add_child(shape)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(160.0, 1.0, 160.0)
	mesh_instance.mesh = mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("86644a")
	ground_material.roughness = 0.95
	mesh_instance.material_override = ground_material
	ground.add_child(mesh_instance)

	# Mint landing pad under the squad — instantly reads as "friendly staging area".
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 6.5
	pad_mesh.bottom_radius = 6.8
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 48
	pad.mesh = pad_mesh
	var pad_material := StandardMaterial3D.new()
	pad_material.albedo_color = Color("1f2d31")
	pad_material.metallic = 0.45
	pad_material.roughness = 0.4
	pad.material_override = pad_material
	pad.position = Vector3(0.0, 0.07, 0.0)
	add_child(pad)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 5.6
	ring_mesh.outer_radius = 5.95
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("62e6c3")
	ring_material.emission_enabled = true
	ring_material.emission = Color("62e6c3")
	ring_material.emission_energy_multiplier = 2.2
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.position = Vector3(0.0, 0.16, 0.0)
	add_child(ring)


func _build_props() -> void:
	var ivory_material := StandardMaterial3D.new()
	ivory_material.albedo_color = Color("e8e0d2")
	ivory_material.roughness = 0.6
	var rust_material := StandardMaterial3D.new()
	rust_material.albedo_color = Color("b56a3f")
	rust_material.roughness = 0.7
	var teal_material := StandardMaterial3D.new()
	teal_material.albedo_color = Color("2e6b63")
	teal_material.roughness = 0.75

	# Crate cluster.
	for i in 5:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(7.0, 11.5)
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		var crate_size := _rng.randf_range(0.9, 1.6)
		crate_mesh.size = Vector3(crate_size, crate_size, crate_size)
		crate.mesh = crate_mesh
		crate.material_override = ivory_material if i % 2 == 0 else rust_material
		crate.position = Vector3(cos(angle) * radius, crate_size * 0.5, sin(angle) * radius)
		crate.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 90.0), 0.0)
		add_child(crate)
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(crate_size * 0.5, 0.06, 0.06)
		strip.mesh = strip_mesh
		var strip_material := StandardMaterial3D.new()
		strip_material.albedo_color = Color("62e6c3")
		strip_material.emission_enabled = true
		strip_material.emission = Color("62e6c3")
		strip_material.emission_energy_multiplier = 1.8
		strip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		strip.material_override = strip_material
		strip.position = Vector3(0.0, crate_size * 0.2, crate_size * 0.5)
		crate.add_child(strip)

	# Mesa silhouettes + teal alien growth to give the scene depth/identity.
	for i in 9:
		var angle := TAU * float(i) / 9.0 + _rng.randf_range(-0.2, 0.2)
		var distance := _rng.randf_range(26.0, 55.0)
		var mesa := MeshInstance3D.new()
		var mesa_mesh := CylinderMesh.new()
		mesa_mesh.top_radius = _rng.randf_range(2.0, 5.0)
		mesa_mesh.bottom_radius = _rng.randf_range(5.0, 8.5)
		mesa_mesh.height = _rng.randf_range(4.5, 11.0)
		mesa_mesh.radial_segments = 7
		mesa.mesh = mesa_mesh
		mesa.material_override = rust_material if i % 3 == 0 else ground_material_for_mesas()
		mesa.position = Vector3(cos(angle) * distance, mesa_mesh.height * 0.5 - 0.2, sin(angle) * distance)
		mesa.rotation_degrees = Vector3(0.0, _rng.randf_range(0.0, 60.0), 0.0)
		add_child(mesa)

	for i in 7:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(14.0, 26.0)
		var growth := MeshInstance3D.new()
		var growth_mesh := CylinderMesh.new()
		growth_mesh.top_radius = 0.0
		growth_mesh.bottom_radius = _rng.randf_range(0.5, 1.1)
		growth_mesh.height = _rng.randf_range(1.4, 3.2)
		growth_mesh.radial_segments = 6
		growth.mesh = growth_mesh
		growth.material_override = teal_material
		growth.position = Vector3(cos(angle) * distance, growth_mesh.height * 0.5, sin(angle) * distance)
		add_child(growth)

	_build_beacon()
	_build_banner(-7.4)
	_build_banner(7.4)


func _build_beacon() -> void:
	var beacon := Node3D.new()
	beacon.name = "RelayBeacon"
	beacon.position = Vector3(-24.0, 0.0, -40.0)
	add_child(beacon)
	var tower := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.35
	tower_mesh.bottom_radius = 1.6
	tower_mesh.height = 19.0
	tower_mesh.radial_segments = 6
	tower.mesh = tower_mesh
	tower.position = Vector3(0.0, 9.5, 0.0)
	var tower_material := StandardMaterial3D.new()
	tower_material.albedo_color = Color("3b4a4e")
	tower_material.metallic = 0.45
	tower_material.roughness = 0.5
	tower.material_override = tower_material
	beacon.add_child(tower)
	var beacon_eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.72
	eye_mesh.height = 1.44
	eye_mesh.radial_segments = 10
	eye_mesh.rings = 6
	beacon_eye.mesh = eye_mesh
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color("62e6c3")
	eye_material.emission_enabled = true
	eye_material.emission = Color("62e6c3")
	eye_material.emission_energy_multiplier = 3.2
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_eye.material_override = eye_material
	beacon_eye.position = Vector3(0.0, 19.6, 0.0)
	beacon.add_child(beacon_eye)
	var beacon_light := OmniLight3D.new()
	beacon_light.light_color = Color("62e6c3")
	beacon_light.light_energy = 4.0
	beacon_light.omni_range = 30.0
	beacon_light.position = Vector3(0.0, 19.6, 0.0)
	beacon.add_child(beacon_light)


func _build_banner(x_offset: float) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 4.4
	pole_mesh.radial_segments = 6
	pole.mesh = pole_mesh
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color("2c3a3e")
	pole_material.metallic = 0.4
	pole_material.roughness = 0.5
	pole.material_override = pole_material
	pole.position = Vector3(x_offset, 2.2, 4.6)
	add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.06, 1.05, 0.95)
	flag.mesh = flag_mesh
	var flag_material := StandardMaterial3D.new()
	flag_material.albedo_color = Color("e8e0d2")
	flag_material.roughness = 0.75
	flag.material_override = flag_material
	var side := 1.0 if x_offset < 0.0 else -1.0
	flag.position = Vector3(x_offset + 0.1 * side, 3.55, 4.6)
	add_child(flag)

	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.02, 0.16, 0.8)
	stripe.mesh = stripe_mesh
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color("62e6c3")
	stripe_material.emission_enabled = true
	stripe_material.emission = Color("62e6c3")
	stripe_material.emission_energy_multiplier = 1.6
	stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe.material_override = stripe_material
	stripe.position = Vector3(x_offset + 0.15 * side, 3.15, 4.6)
	add_child(stripe)


func ground_material_for_mesas() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8a6044")
	material.roughness = 0.92
	return material


# ---------------------------------------------------------------------------
# Actors
# ---------------------------------------------------------------------------

func _spawn_player() -> void:
	var player_script: Script = load(PlayerScriptPath)
	if player_script == null or not player_script.can_instantiate():
		push_warning("[companions-sandbox] Player script unavailable; falling back to a stub marker.")
		var marker := Node3D.new()
		marker.name = "PlayerStub"
		marker.add_to_group("player")
		add_child(marker)
		marker.position = Vector3(0.0, 0.1, 0.0)
		_player = marker
		_build_player_stand_in()
		return
	_player = player_script.new()
	_player.name = "Player"
	add_child(_player)
	(_player as Node3D).position = Vector3(0.0, 0.2, 0.0)
	_build_player_stand_in()


## Third-person body for the player so the squad has a visual anchor (the real
## Player rig is first-person only, and may not compile while in flux).
func _build_player_stand_in() -> void:
	var data := AllyData.new()
	data.id = &"player_warden"
	data.display_name = "RIFTWARDEN"
	data.role = &"engineer"
	data.color = Color("f4efe5")
	data.weapon_id = &"lattice_ar"
	var weapon: WeaponData = ContentDB.get_weapon(&"lattice_ar")
	var kit: Dictionary = CompanionVisuals.build_warden(data, weapon)
	_player_stand_in = kit["root"] as Node3D
	_player_stand_in.name = "PlayerStandIn"
	add_child(_player_stand_in)
	if _player is Node3D:
		_player_stand_in.global_position = (_player as Node3D).global_position
	var nameplate := kit["nameplate"] as Label3D
	if nameplate != null:
		nameplate.visible = false


func _spawn_squad() -> void:
	var manager_script: Script = load(ManagerScriptPath)
	if manager_script == null or not manager_script.can_instantiate():
		push_error("[companions-sandbox] CompanionManager failed to compile.")
		return
	_manager = manager_script.new()
	_manager.name = "CompanionManager"
	add_child(_manager)
	_manager.setup(_player)
	print("[companions-sandbox] squad spawned: %d Wardens + pet=%s" % [
		_manager.get_allies().size(),
		str(_manager.get_pet() != null),
	])


func _build_drones() -> void:
	_build_drone("TrainingDroneA", Vector3(-4.5, 0.05, -14.0))
	_build_drone("TrainingDroneB", Vector3(5.5, 0.05, -17.5))


func _build_drone(drone_name: String, position_value: Vector3) -> void:
	var drone := StaticBody3D.new()
	drone.name = drone_name
	drone.collision_layer = 4
	drone.collision_mask = 0
	drone.position = position_value
	add_child(drone)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.925, 0.0)
	drone.add_child(shape)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.85
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("2a3438")
	body_material.metallic = 0.5
	body_material.roughness = 0.45
	body.material_override = body_material
	body.position = Vector3(0.0, 0.925, 0.0)
	drone.add_child(body)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.1
	eye_mesh.height = 0.2
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	eye.mesh = eye_mesh
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color("ffb866")
	eye_material.emission_enabled = true
	eye_material.emission = Color("ffb866")
	eye_material.emission_energy_multiplier = 3.0
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.material_override = eye_material
	eye.position = Vector3(0.0, 1.55, -0.34)
	drone.add_child(eye)

	var health := HealthComponent.new()
	health.name = "Health"
	drone.add_child(health)
	health.configure(420.0, 0.0, 0.0, StatKeys.TEAM_ENEMY)
	drone.set_meta("health_component", health)
	drone.set_meta("aim_height", 1.15)
	drone.add_to_group("enemy_ai")


# ---------------------------------------------------------------------------
# Camera + capture
# ---------------------------------------------------------------------------

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "SandboxCamera"
	_camera.near = 0.05
	_camera.far = 800.0
	add_child(_camera)
	_apply_shot("hero")
	_camera.current = true


func _apply_shot(shot: String) -> void:
	if _camera == null:
		return
	match shot:
		"portrait":
			_camera.global_position = Vector3(0.35, 1.72, -4.6)
			_camera.fov = 52.0
			_camera.look_at(Vector3(0.0, 1.18, 2.4), Vector3.UP)
		"driftling":
			_camera.global_position = Vector3(1.35, 2.05, -0.7)
			_camera.fov = 40.0
			_camera.look_at(Vector3(1.12, 1.9, 1.6), Vector3.UP)
		_:
			_camera.global_position = Vector3(2.7, 1.95, 7.2)
			_camera.fov = 55.0
			_camera.look_at(Vector3(-0.1, 1.12, -1.0), Vector3.UP)


func _capture_and_quit() -> void:
	await get_tree().create_timer(2.2).timeout
	await _capture_frame("squad_hero.png")
	_apply_shot("portrait")
	await get_tree().create_timer(0.45).timeout
	await _capture_frame("squad_portrait.png")
	_apply_shot("driftling")
	await get_tree().create_timer(0.45).timeout
	await _capture_frame("squad_driftling.png")
	get_tree().quit(0)


func _capture_frame(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var preview_dir := ProjectSettings.globalize_path("res://features/companions/preview")
	DirAccess.make_dir_recursive_absolute(preview_dir)
	var output_path := preview_dir.path_join(file_name)
	var err := image.save_png(output_path)
	print("[companions-sandbox] screenshot saved: %s (err=%d, %dx%d)" % [
		output_path, err, image.get_width(), image.get_height()
	])
