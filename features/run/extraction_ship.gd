class_name ExtractionShip
extends Node3D
## Procedural Kestrel dropship that descends over the calling exfil pad while
## the hold runs. Purely visual: the extraction outcome stays in RunState.

const SPAWN_ALTITUDE := 72.0
const HOVER_ALTITUDE := 13.0
const DESCENT_TIME := 5.5

var accent := Color("62e6c3")
var pad_position := Vector3.ZERO
var target_position := Vector3.ZERO
var arrived := false

var _visual_root: Node3D = null
var _engine_materials: Array[StandardMaterial3D] = []
var _engine_light: OmniLight3D = null
var _time := 0.0
var _tween: Tween = null


func _ready() -> void:
	set_process(false)


func setup(p_pad_position: Vector3, p_accent: Color = Color("62e6c3")) -> void:
	pad_position = p_pad_position
	accent = p_accent
	target_position = pad_position + Vector3(0.0, HOVER_ALTITUDE, 0.0)
	global_position = pad_position + Vector3(0.0, SPAWN_ALTITUDE, 18.0)
	_build_visuals()
	set_process(true)
	_tween = create_tween().bind_node(self)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_position, DESCENT_TIME)
	_tween.finished.connect(func() -> void: arrived = true)


func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	_visual_root.scale = Vector3(1.15, 1.15, 1.15)
	add_child(_visual_root)
	var hull := _material(Color("2b383c"), 0.55, 0.45)
	var hull_dark := _material(Color("11181b"), 0.35, 0.55)
	var trim := _material(Color("93a5a8"), 0.7, 0.35)
	var glow := _emission(accent, 3.2)
	var cockpit := _material(Color(0.20, 0.42, 0.48, 0.55), 0.2, 0.15)
	cockpit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Main fuselage and nose.
	_box(Vector3(3.2, 1.5, 7.4), Vector3(0.0, 0.0, 0.0), hull)
	_prism(Vector3(2.7, 1.15, 2.1), Vector3(0.0, -0.1, -4.55), hull, Vector3(0.0, PI * 0.5, 0.0))
	_box(Vector3(2.35, 1.15, 1.1), Vector3(0.0, 0.01, -3.35), hull_dark)
	_box(Vector3(1.8, 0.42, 0.14), Vector3(0.0, 0.28, -3.92), _emission(Color("bfefff"), 2.4))
	# Swept wings and tail.
	_prism(Vector3(7.6, 0.26, 1.9), Vector3(-3.35, 0.05, 1.0), hull, Vector3(0.0, 0.32, 0.0))
	_prism(Vector3(7.6, 0.26, 1.9), Vector3(3.35, 0.05, 1.0), hull, Vector3(0.0, -0.32, 0.0))
	_box(Vector3(0.5, 1.0, 1.25), Vector3(-4.95, 0.22, 1.45), trim)
	_box(Vector3(0.5, 1.0, 1.25), Vector3(4.95, 0.22, 1.45), trim)
	_box(Vector3(4.9, 0.22, 1.3), Vector3(0.0, 0.55, 3.3), hull_dark)
	_box(Vector3(0.25, 1.8, 1.2), Vector3(0.0, 0.65, 3.6), trim, Vector3(-0.18, 0.0, 0.0))
	# Cockpit canopy.
	_box(Vector3(1.45, 0.62, 1.6), Vector3(0.0, 0.78, -2.55), cockpit)
	# Engine pods and emissive thrusters.
	_engine_materials.clear()
	for side in [-1.0, 1.0]:
		_box(Vector3(0.9, 1.0, 2.2), Vector3(side * 3.15, 0.05, 0.4), hull_dark)
		_cylinder(0.32, 0.38, 0.5, Vector3(side * 3.15, 0.05, 1.55), trim, Vector3(PI * 0.5, 0.0, 0.0), 10)
		var engine := _emission(accent, 4.2)
		_engine_materials.append(engine)
		_cylinder(0.27, 0.27, 0.12, Vector3(side * 3.15, 0.05, 1.82), engine, Vector3(PI * 0.5, 0.0, 0.0), 12)
	# Landing skids.
	_box(Vector3(0.18, 0.8, 2.0), Vector3(-1.05, -1.0, -0.4), trim)
	_box(Vector3(0.18, 0.8, 2.0), Vector3(1.05, -1.0, -0.4), trim)
	_box(Vector3(2.6, 0.16, 0.5), Vector3(0.0, -1.4, -0.4), hull_dark)
	# Hull lights and a strong down-facing search light.
	_engine_light = OmniLight3D.new()
	_engine_light.light_color = accent
	_engine_light.light_energy = 2.4
	_engine_light.omni_range = 30.0
	_engine_light.shadow_enabled = false
	_engine_light.position = Vector3(0.0, -1.5, 0.0)
	_visual_root.add_child(_engine_light)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		var marker := _emission(Color("ffb866"), 2.4)
		_box(Vector3(0.16, 0.16, 0.16), Vector3(cos(angle) * 1.5, -0.75, sin(angle) * 2.6), marker)
	var callsign := Label3D.new()
	callsign.name = "Callsign"
	callsign.text = "KESTREL EXFIL"
	callsign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	callsign.no_depth_test = true
	callsign.font_size = 44
	callsign.outline_size = 12
	callsign.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
	callsign.modulate = Color("62e6c3")
	callsign.position = Vector3(0.0, 3.0, 0.0)
	_visual_root.add_child(callsign)


func _process(delta: float) -> void:
	_time += delta
	if _visual_root != null:
		_visual_root.position.y = sin(_time * 1.7) * 0.16
		_visual_root.rotation.z = sin(_time * 0.8) * 0.012
	if _engine_light != null:
		_engine_light.light_energy = 2.2 + sin(_time * 5.0) * 0.35
	for material in _engine_materials:
		material.emission_energy_multiplier = 3.7 + sin(_time * 7.0) * 0.6


func get_engine_glow_count() -> int:
	return _engine_materials.size()


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emission(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _box(size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, pos, material, rot)


func _prism(size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = 0.5
	return _mesh(mesh, pos, material, rot)


func _cylinder(
	top_radius: float,
	bottom_radius: float,
	height: float,
	pos: Vector3,
	material: Material,
	rot: Vector3 = Vector3.ZERO,
	segments: int = 8
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(mesh, pos, material, rot)


func _mesh(mesh: Mesh, pos: Vector3, material: Material, rot: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(instance)
	return instance
