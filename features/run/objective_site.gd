class_name ObjectiveSite
extends StaticBody3D
## World-space contract objective marker. StaticBody because player interaction
## rays use bodies; gameplay state is owned by Deployment/RunState.

var site_id: StringName = &"objective"
var title: String = "Objective"
var site_type: StringName = &"cache"
var deployment: Node = null
var completed: bool = false
var activated: bool = false
var accent: Color = Color("62e6c3")

var _visual_root: Node3D
var _core: MeshInstance3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _label: Label3D
var _time: float = 0.0


func setup(p_id: StringName, p_title: String, p_type: StringName, p_position: Vector3, p_deployment: Node, p_accent: Color) -> void:
	site_id = p_id
	title = p_title
	site_type = p_type
	global_position = p_position
	deployment = p_deployment
	accent = p_accent
	if is_inside_tree():
		_refresh_presentation()


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 32
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.8
	shape.height = 4.0
	collision.shape = shape
	collision.position = Vector3(0.0, 2.0, 0.0)
	add_child(collision)
	_build_visual()


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 3.0
	pad_mesh.bottom_radius = 3.2
	pad_mesh.height = 0.18
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.material_override = _mat(Color("1a2428"), accent, 0.6)
	pad.position = Vector3(0.0, 0.09, 0.0)
	_visual_root.add_child(pad)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.05
	torus.outer_radius = 2.3
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _mat(accent, accent, 2.5)
	ring.position = Vector3(0.0, 0.22, 0.0)
	_visual_root.add_child(ring)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.28
	beam_mesh.bottom_radius = 0.55
	beam_mesh.height = 8.0
	beam_mesh.radial_segments = 12
	_beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.18)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = accent
	beam_mat.emission_energy_multiplier = 1.2
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	_beam.position = Vector3(0.0, 4.0, 0.0)
	_visual_root.add_child(_beam)
	_core = MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.45, 0.75, 0.45)
	_core.mesh = core_mesh
	_core.material_override = _mat(accent, accent, 4.0)
	_core.position = Vector3(0.0, 1.7, 0.0)
	_visual_root.add_child(_core)
	_light = OmniLight3D.new()
	_light.light_color = accent
	_light.light_energy = 1.4
	_light.omni_range = 7.0
	_light.position = Vector3(0.0, 2.2, 0.0)
	_visual_root.add_child(_light)
	var label := Label3D.new()
	label.text = title.to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.03, 0.04, 0.85)
	label.modulate = Color("f4efe5")
	label.position = Vector3(0.0, 3.2, 0.0)
	label.no_depth_test = true
	_visual_root.add_child(label)
	_label = label


func _refresh_presentation() -> void:
	if _label != null:
		_label.text = title.to_upper()
	if _light != null:
		_light.light_color = accent


func _mat(base: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = 0.3
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = energy
	return mat


func _process(delta: float) -> void:
	if completed:
		return
	_time += delta
	if _core != null:
		_core.rotation.y += delta * 1.2
		_core.position.y = 1.7 + sin(_time * 2.0) * 0.12
	if _beam != null:
		_beam.rotation.y += delta * 0.2
	if _light != null:
		_light.light_energy = 1.2 + sin(_time * 3.0) * 0.3


func get_interact_prompt() -> String:
	if completed:
		return ""
	if activated:
		return "Objective in progress…"
	match site_type:
		&"relay":
			return "E — Disrupt relay"
		&"survey":
			return "E — Scan anomaly"
		&"rescue":
			return "E — Free the Warden"
		&"hunt":
			return "E — Disturb the target"
		&"vault":
			return "E — Breach the Vault"
		&"shrine":
			return "E — Touch the Rift Shrine"
		&"supply":
			return "E — Secure the supply drop"
		_:
			return "E — Recover cache"


func interact(player: Node) -> void:
	if completed or activated or deployment == null:
		return
	activated = true
	AudioDirector.play_ui(&"ui_confirm")
	if deployment.has_method("on_objective_interacted"):
		deployment.call("on_objective_interacted", self, player)


func mark_complete() -> void:
	completed = true
	activated = true
	collision_layer = 0
	if deployment != null:
		if deployment.has_method("on_objective_site_completed"):
			deployment.call("on_objective_site_completed", self)
	if _beam != null:
		_beam.visible = false
	if _light != null:
		_light.light_energy = 0.5
	if _core != null:
		_core.material_override = _mat(Color("26383d"), Color("26383d"), 0.2)
	CombatVFX.ring(get_parent() as Node3D, global_position, 4.0, accent, 0.8)
