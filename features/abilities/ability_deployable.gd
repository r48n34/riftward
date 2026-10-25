class_name AbilityDeployable
extends StaticBody3D
## Deployable wall or sentry turret. Scene-generated, owns no progression state.

var mode: StringName = &"wall"
var owner_player: Node = null
var lifetime: float = 12.0
var damage: float = 18.0
var color: Color = Color("62e6c3")
var _age: float = 0.0
var _shoot_timer: float = 0.0
var _muzzle: Marker3D
var _turret_head: Node3D


func setup(p_mode: StringName, p_owner: Node, pos: Vector3, face_dir: Vector3, p_lifetime: float, p_damage: float, p_color: Color) -> void:
	mode = p_mode
	owner_player = p_owner
	lifetime = p_lifetime
	damage = p_damage
	color = p_color
	global_position = pos
	if face_dir.length_squared() > 0.01:
		look_at(global_position + face_dir, Vector3.UP)


func _ready() -> void:
	collision_layer = 1 | 128
	collision_mask = 0
	if mode == &"wall":
		_build_wall()
	elif mode == &"mine":
		_build_mine()
	else:
		_build_turret()


func _build_wall() -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.2, 2.6, 0.22)
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(0.0, 1.3, 0.0)
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 2.6, 0.22)
	collision.shape = shape
	collision.position = Vector3(0.0, 1.3, 0.0)
	add_child(collision)
	var frame := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(4.25, 0.08, 0.24)
	frame.mesh = frame_box
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = color
	frame_mat.emission_enabled = true
	frame_mat.emission = color
	frame_mat.emission_energy_multiplier = 2.0
	frame.material_override = frame_mat
	frame.position = Vector3(0.0, 2.55, 0.0)
	add_child(frame)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = 4.0
	add_child(light)


func _build_turret() -> void:
	var root := Node3D.new()
	add_child(root)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.26
	base_mesh.bottom_radius = 0.38
	base_mesh.height = 0.25
	base_mesh.radial_segments = 8
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.13, 0.0)
	base.material_override = _turret_mat(Color("26383d"), 0.4)
	root.add_child(base)
	_turret_head = Node3D.new()
	_turret_head.name = "Head"
	_turret_head.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(_turret_head)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.34, 0.24, 0.4)
	body.mesh = body_mesh
	body.material_override = _turret_mat(Color("f4efe5"), 0.3)
	_turret_head.add_child(body)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.045
	barrel_mesh.bottom_radius = 0.06
	barrel_mesh.height = 0.55
	barrel_mesh.radial_segments = 8
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0.0, 0.04, -0.32)
	barrel.material_override = _turret_mat(Color("151d20"), 0.3)
	_turret_head.add_child(barrel)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.055
	eye_mesh.height = 0.11
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.06, -0.15)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = color
	eye_mat.emission_enabled = true
	eye_mat.emission = color
	eye_mat.emission_energy_multiplier = 3.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.material_override = eye_mat
	_turret_head.add_child(eye)
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0.0, 0.04, -0.62)
	_turret_head.add_child(_muzzle)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 5.0
	root.add_child(light)


func _turret_mat(tint: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.4
	mat.roughness = 0.4
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if mode == &"turret":
		_update_turret(delta)
	elif mode == &"mine":
		_update_mine(delta)


func _build_mine() -> void:
	collision_layer = 128
	collision_mask = 0
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.34
	disc.height = 0.12
	disc.radial_segments = 10
	base.mesh = disc
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("26383d")
	body_mat.metallic = 0.4
	body_mat.roughness = 0.45
	base.material_override = body_mat
	base.position = Vector3(0.0, 0.06, 0.0)
	add_child(base)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.12
	core_mesh.height = 0.24
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = color
	core_mat.emission_enabled = true
	core_mat.emission = color
	core_mat.emission_energy_multiplier = 3.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_mat
	core.position = Vector3(0.0, 0.2, 0.0)
	add_child(core)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.position = Vector3(0.0, 0.4, 0.0)
	add_child(light)


func _update_mine(delta: float) -> void:
	if _age < 0.5:
		return
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if global_position.distance_to((node as Node3D).global_position) <= 2.8:
			_detonate_mine()
			return


func _detonate_mine() -> void:
	if not is_inside_tree():
		return
	CombatUtils.aoe_damage(global_position, 4.0, damage, StatKeys.TEAM_PLAYER, owner_player, StatKeys.DMG_KINETIC, get_world_3d())
	CombatVFX.explosion(_effect_parent(), global_position, 4.0, color)
	AudioDirector.play_3d(&"explosion", global_position, -6.0)
	queue_free()


func _update_turret(delta: float) -> void:
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	if _shoot_timer > 0.0 or _turret_head == null:
		return
	var target := _find_target()
	if target == null:
		return
	var target_pos: Vector3 = target.global_position + Vector3.UP
	_turret_head.look_at(target_pos, Vector3.UP)
	_turret_head.rotation.x = 0.0
	var to_target := (_muzzle.global_position - target_pos).normalized()
	if _muzzle != null:
		var fx_parent := _effect_parent()
		CombatVFX.spawn_tracer(fx_parent, _muzzle.global_position, target_pos, color)
		CombatVFX.impact(fx_parent, target_pos, -to_target, color)
		var data := DamageData.make(damage, StatKeys.TEAM_PLAYER, StatKeys.DMG_SHOCK, self)
		data.hit_position = target_pos
		CombatUtils.apply_hit(target, data)
	AudioDirector.play_3d(&"shot_arc", _muzzle.global_position if _muzzle != null else global_position, -16.0)
	_shoot_timer = 0.45


func _effect_parent() -> Node3D:
	if owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("get_effect_parent"):
		var parent = owner_player.call("get_effect_parent")
		if parent is Node3D:
			return parent
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return get_tree().current_scene as Node3D


func _find_target() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := 30.0
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		var dist := global_position.distance_to((node as Node3D).global_position)
		if dist < nearest_dist:
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, (node as Node3D).global_position + Vector3.UP, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider == node:
				nearest = node as Node3D
				nearest_dist = dist
	return nearest


func _exit_tree() -> void:
	if owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("notify_deployable_removed"):
		owner_player.call("notify_deployable_removed", self)
