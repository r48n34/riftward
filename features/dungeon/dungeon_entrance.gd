class_name DungeonEntrance
extends StaticBody3D
## Interactable hatch that takes the player into a procedural under-reach
## instance. Purely a gateway: DungeonRuntime owns the dungeon and Deployment
## owns the teleport/state transition.

const INTERACT_LAYER := 32

var deployment: Node = null
var entrance_index := 0
var dungeon_name := "Rift Vault"
var cleared := false
var _time := 0.0
var _light: OmniLight3D = null
var _ring: MeshInstance3D = null
var _label: Label3D = null
var _accent := Color("c79cff")


func setup(p_deployment: Node, index: int, p_name: String, p_position: Vector3, accent: Color = Color("c79cff")) -> void:
	deployment = p_deployment
	entrance_index = index
	dungeon_name = p_name
	_accent = accent
	global_position = p_position
	if is_inside_tree():
		_refresh_presentation()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dungeon_entrance")
	collision_layer = INTERACT_LAYER
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 2.4
	collision.shape = shape
	collision.position = Vector3(0.0, 1.2, 0.0)
	add_child(collision)
	_build_visual()


func _build_visual() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 3.4
	base_mesh.bottom_radius = 3.7
	base_mesh.height = 0.4
	base_mesh.radial_segments = 24
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("1a2428")
	base_mat.metallic = 0.45
	base_mat.roughness = 0.4
	base.material_override = base_mat
	base.position = Vector3(0.0, 0.2, 0.0)
	add_child(base)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.5
	torus.outer_radius = 2.85
	torus.rings = 40
	torus.ring_segments = 8
	_ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = _accent
	ring_mat.emission_enabled = true
	ring_mat.emission = _accent
	ring_mat.emission_energy_multiplier = 2.4
	ring_mat.roughness = 0.3
	_ring.material_override = ring_mat
	_ring.position = Vector3(0.0, 0.45, 0.0)
	add_child(_ring)
	for i in 4:
		var pylon := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 2.2, 0.3)
		pylon.mesh = box
		pylon.material_override = ring_mat
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		pylon.position = Vector3(cos(angle) * 3.0, 1.3, sin(angle) * 3.0)
		add_child(pylon)
	_light = OmniLight3D.new()
	_light.light_color = _accent
	_light.light_energy = 1.6
	_light.omni_range = 12.0
	_light.position = Vector3(0.0, 2.0, 0.0)
	add_child(_light)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 34
	_label.outline_size = 10
	_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
	_label.modulate = Color("f4efe5")
	_label.position = Vector3(0.0, 3.6, 0.0)
	add_child(_label)
	_refresh_presentation()


func _refresh_presentation() -> void:
	if _label != null:
		_label.text = ("RE-ENTER " if cleared else "DESCEND: ") + dungeon_name.to_upper()
		_label.modulate = Color("93a5a8") if cleared else Color("f4efe5")
	if _light != null:
		_light.light_energy = 0.8 if cleared else 1.6


func _process(delta: float) -> void:
	_time += delta
	if _ring != null:
		_ring.rotation.y += delta * 0.35
	if _light != null:
		_light.light_energy = (0.8 if cleared else 1.6) + sin(_time * 2.4) * 0.3


func get_interact_prompt() -> String:
	if RunState != null and RunState.active and RunState.extraction_state == &"holding":
		return ""
	return "E — Descend into %s" % dungeon_name


func interact(_player: Node) -> void:
	if deployment != null and deployment.has_method("enter_dungeon"):
		deployment.call("enter_dungeon", self)
	AudioDirector.play_sfx(&"door", -6.0)


func set_cleared(value: bool) -> void:
	cleared = value
	_refresh_presentation()


func get_dungeon_name() -> String:
	return dungeon_name
