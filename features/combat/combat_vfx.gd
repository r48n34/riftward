class_name CombatVFX
extends RefCounted
## Lightweight, code-generated combat feedback. Effects are short-lived and
## intentionally cheap; high-frequency visuals use pool-friendly meshes.

static func _mat(color: Color, emission: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = emission > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = emission
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func spawn_tracer(parent: Node3D, from: Vector3, to: Vector3, color: Color = Color("ffe9b8")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, length)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color, 3.0)
	parent.add_child(instance)
	instance.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.01:
		var dir := (to - from).normalized()
		instance.look_at(instance.global_position + dir, Vector3.UP)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.create_tween().tween_property(instance, "scale", Vector3(1.0, 1.0, 0.2), 0.06)
	instance.get_tree().create_timer(0.065).timeout.connect(instance.queue_free)


static func impact(parent: Node3D, position: Vector3, normal: Vector3, color: Color = Color("ffcf8a")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position + normal * 0.02
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	flash.mesh = sphere
	flash.material_override = _mat(color, 3.5)
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 1.6
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(2.4, 2.4, 2.4), 0.12)
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.chain().tween_callback(root.queue_free)


static func muzzle_flash(parent: Node3D, position: Vector3, color: Color = Color("ffd89a")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.18
	sphere.radial_segments = 6
	sphere.rings = 3
	flash.mesh = sphere
	flash.material_override = _mat(color, 4.0)
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.0
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(0.2, 0.2, 3.5), 0.05)
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.chain().tween_callback(root.queue_free)


static func damage_number(parent: Node3D, position: Vector3, amount: float, crit: bool = false, weakpoint: bool = false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48 if crit else 32
	label.outline_size = 8
	label.modulate = Color("ffb866") if crit else (Color("ff6e6e") if weakpoint else Color("f4efe5"))
	label.outline_modulate = Color(0.02, 0.03, 0.04, 0.8)
	parent.add_child(label)
	label.global_position = position + Vector3(0.0, 0.4, 0.0)
	var drift := Vector3(randf_range(-0.2, 0.2), 0.9, randf_range(-0.2, 0.2))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + drift, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


static func explosion(parent: Node3D, position: Vector3, radius: float, color: Color = Color("ffb866")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 5
	var flash := MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.material_override = _mat(color, 3.0)
	root.add_child(flash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.2, radius * 0.75)
	torus.outer_radius = maxf(0.3, radius)
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat(color, 2.5)
	root.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = radius * 2.0
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(radius * 2.0, radius * 2.0, radius * 2.0), 0.25)
	tween.tween_property(flash, "transparency", 1.0, 0.3)
	tween.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.35)
	tween.tween_property(ring, "transparency", 1.0, 0.35)
	tween.tween_property(light, "light_energy", 0.0, 0.25)
	tween.chain().tween_callback(root.queue_free)


static func ring(parent: Node3D, position: Vector3, radius: float, color: Color = Color("62e6c3"), duration: float = 0.7) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position + Vector3.UP * 0.05
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55
	torus.rings = 24
	torus.ring_segments = 8
	mesh.mesh = torus
	mesh.material_override = _mat(color, 2.0)
	root.add_child(mesh)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(radius, 0.6, radius), duration * 0.7)
	tween.tween_property(mesh, "transparency", 1.0, duration)
	tween.chain().tween_callback(root.queue_free)


static func beam_burst(parent: Node3D, from: Vector3, to: Vector3, color: Color = Color("62e6c3")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	spawn_tracer(parent, from, to, color)
	var mid := (from + to) * 0.5
	impact(parent, mid, (to - from).normalized(), color)


static func hit_direction_arc(source: Vector3, player_position: Vector3) -> Vector3:
	return (source - player_position).normalized()
