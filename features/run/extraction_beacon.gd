class_name ExtractionBeacon
extends StaticBody3D
## Exfiltration pad. Interaction starts the hold; the Deployment owns the waves.

var deployment: Node = null
var beacon_name: String = "Exfil Beacon"
var active: bool = false
var _time: float = 0.0
var _beam: MeshInstance3D
var _light: OmniLight3D
var _label: Label3D


func setup(p_deployment: Node, p_position: Vector3, p_name: String) -> void:
	deployment = p_deployment
	beacon_name = p_name
	global_position = p_position
	if is_inside_tree() and _label != null:
		_label.text = beacon_name.to_upper()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("exfil_beacon")
	collision_layer = 32
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 4.0
	shape.height = 3.0
	collision.shape = shape
	collision.position = Vector3(0.0, 1.5, 0.0)
	add_child(collision)
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 4.4
	pad_mesh.bottom_radius = 4.8
	pad_mesh.height = 0.16
	pad_mesh.radial_segments = 40
	pad.mesh = pad_mesh
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color("1a2428")
	pad_mat.metallic = 0.5
	pad_mat.roughness = 0.35
	pad_mat.emission_enabled = true
	pad_mat.emission = Color("62e6c3")
	pad_mat.emission_energy_multiplier = 0.35
	pad.material_override = pad_mat
	pad.position = Vector3(0.0, 0.08, 0.0)
	add_child(pad)
	for i in 4:
		var pylon := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 2.8, 0.14)
		pylon.mesh = box
		pylon.material_override = pad_mat
		var angle := TAU * i / 4.0
		pylon.position = Vector3(cos(angle) * 3.4, 1.4, sin(angle) * 3.4)
		add_child(pylon)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.9
	beam_mesh.bottom_radius = 2.2
	beam_mesh.height = 14.0
	beam_mesh.radial_segments = 20
	_beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.38, 0.9, 0.76, 0.12)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("62e6c3")
	beam_mat.emission_energy_multiplier = 0.9
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	_beam.position = Vector3(0.0, 7.0, 0.0)
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = Color("62e6c3")
	_light.light_energy = 2.0
	_light.omni_range = 24.0
	_light.position = Vector3(0.0, 5.0, 0.0)
	add_child(_light)
	_label = Label3D.new()
	_label.text = beacon_name.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 42
	_label.outline_size = 12
	_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
	_label.modulate = Color("f4efe5")
	_label.position = Vector3(0.0, 3.6, 0.0)
	_label.no_depth_test = true
	add_child(_label)


func _process(delta: float) -> void:
	_time += delta
	if _light != null:
		_light.light_energy = 1.6 + sin(_time * 2.0) * 0.4
	if _beam != null:
		_beam.rotation.y += delta * 0.12


func get_interact_prompt() -> String:
	if RunState.extraction_state == &"holding":
		return "Dropship inbound — hold the pad"
	if not RunState.active:
		return ""
	var interact_key := "E"
	var call_key := "H"
	if App != null:
		interact_key = String(App.get_action_binding_text(&"interact", "E"))
		call_key = String(App.get_action_binding_text(&"call_exfil", "H"))
	return "%s / %s — Call exfiltration" % [interact_key, call_key]


func interact(_player: Node) -> void:
	if deployment != null and deployment.has_method("request_extraction"):
		deployment.call("request_extraction", self)
	AudioDirector.play_sfx(&"exfil", -4.0)


func set_active(value: bool) -> void:
	active = value
	if _label != null:
		_label.modulate = Color("ffb866") if value else Color("f4efe5")
