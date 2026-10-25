class_name TrainingTarget
extends StaticBody3D
## Tutorial target dummy. Uses the real HealthComponent + hitscan pipeline so the
## player learns the actual weapon contract (no special-case damage code).

signal hit_target

var health_component: HealthComponent = null
var max_health_value := 5000.0
var _time := 0.0
var _board: MeshInstance3D = null
var _glow: MeshInstance3D = null


func _ready() -> void:
	add_to_group("training_target")
	collision_layer = 4
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.0, 0.5)
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	add_child(collision)
	health_component = HealthComponent.new()
	health_component.name = "Health"
	add_child(health_component)
	health_component.configure(max_health_value, 0.0, 0.0, StatKeys.TEAM_ENEMY)
	health_component.damaged.connect(_on_damaged)
	set_meta("health_component", health_component)
	_build_visual()


func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.6
	base_mesh.bottom_radius = 0.75
	base_mesh.height = 0.2
	base_mesh.radial_segments = 12
	base.mesh = base_mesh
	base.material_override = _mat(Color("1a2428"), Color("62e6c3"), 0.4)
	base.position = Vector3(0.0, 0.1, 0.0)
	add_child(base)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.1
	post_mesh.height = 1.2
	post_mesh.radial_segments = 8
	post.mesh = post_mesh
	post.material_override = _mat(Color("26383d"), Color("26383d"), 0.0)
	post.position = Vector3(0.0, 0.7, 0.0)
	add_child(post)
	_board = MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.3, 1.7, 0.16)
	_board.mesh = board_mesh
	_board.material_override = _mat(Color("f4efe5"), Color("62e6c3"), 0.0)
	_board.position = Vector3(0.0, 1.35, 0.0)
	add_child(_board)
	# Concentric target rings.
	for ring in 3:
		var torus := MeshInstance3D.new()
		var torus_mesh := TorusMesh.new()
		torus_mesh.inner_radius = 0.18 + float(ring) * 0.2
		torus_mesh.outer_radius = 0.22 + float(ring) * 0.2
		torus_mesh.rings = 24
		torus_mesh.ring_segments = 6
		torus.mesh = torus_mesh
		torus.material_override = _mat(Color("62e6c3"), Color("62e6c3"), 1.6)
		torus.position = Vector3(0.0, 1.35, -0.1)
		torus.rotation_degrees = Vector3(90, 0, 0)
		add_child(torus)
	_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.12
	glow_mesh.height = 0.24
	_glow.mesh = glow_mesh
	_glow.material_override = _mat(Color("62e6c3"), Color("62e6c3"), 3.0)
	_glow.position = Vector3(0.0, 2.35, 0.0)
	add_child(_glow)


func _mat(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.metallic = 0.25
	material.roughness = 0.5
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _process(delta: float) -> void:
	_time += delta
	if _glow != null:
		_glow.position.y = 2.35 + sin(_time * 2.2) * 0.08


func _on_damaged(_info: Dictionary) -> void:
	hit_target.emit()
	CombatVFX.ring(get_parent() as Node3D, global_position + Vector3.UP, 1.2, Color("62e6c3"), 0.3)
	AudioDirector.play_3d(&"hit", global_position + Vector3.UP, -10.0)
	# Keep the dummy standing for the whole tutorial; it never dies.
	if health_component != null and health_component.health < max_health_value * 0.2:
		health_component.reset_full()


func get_health_component() -> HealthComponent:
	return health_component
