class_name WorldMarker
extends Node3D
## Floating world-space location beacon for POIs, buildings and bounty targets.
## Purely presentational: no collision, no gameplay state. Markers start muted
## (dim label, no beam) until the Deployment marks them discovered, then switch
## to the bright discovered state. They can optionally follow another node and
## print live distance-to-player text, which the tactical HUD/minimap can use
## through the Deployment snapshot.

var marker_title: String = "Point of Interest"
var marker_kind: StringName = &"poi"
var accent: Color = Color("93a5a8")
var discovered: bool = false
var muted: bool = true
var show_distance: bool = true
var follow_target: Node3D = null
var follow_offset: Vector3 = Vector3.ZERO

var _label: Label3D = null
var _beam: MeshInstance3D = null
var _light: OmniLight3D = null
var _disc: MeshInstance3D = null
var _player: Node3D = null
var _time: float = 0.0
var _refresh_timer: float = 0.0


func setup(p_title: String, p_kind: StringName, p_color: Color, p_position: Vector3) -> void:
	marker_title = p_title
	marker_kind = p_kind
	accent = p_color
	global_position = p_position
	if is_inside_tree():
		_refresh_presentation()


func _ready() -> void:
	add_to_group("world_marker")
	_build_visual()
	_refresh_presentation()
	set_process(true)


func _build_visual() -> void:
	_disc = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.1
	disc_mesh.bottom_radius = 1.3
	disc_mesh.height = 0.08
	disc_mesh.radial_segments = 18
	_disc.mesh = disc_mesh
	_disc.material_override = _mat(Color(accent.r, accent.g, accent.b, 0.55), 0.9, true)
	_disc.position = Vector3(0.0, 0.05, 0.0)
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.32
	beam_mesh.height = 9.0
	beam_mesh.radial_segments = 8
	_beam.mesh = beam_mesh
	_beam.material_override = _mat(Color(accent.r, accent.g, accent.b, 0.2), 1.4, true)
	_beam.position = Vector3(0.0, 4.5, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = accent
	_light.light_energy = 0.0
	_light.omni_range = 8.0
	_light.position = Vector3(0.0, 2.4, 0.0)
	_light.shadow_enabled = false
	add_child(_light)
	_label = Label3D.new()
	_label.name = "MarkerLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.85)
	_label.position = Vector3(0.0, 3.1, 0.0)
	add_child(_label)


func _mat(color: Color, energy: float, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = energy > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func set_discovered(value: bool) -> void:
	discovered = value
	muted = not value
	_refresh_presentation()


func set_muted(value: bool) -> void:
	muted = value
	_refresh_presentation()


func set_follow_target(node: Node3D, offset: Vector3 = Vector3.ZERO) -> void:
	follow_target = node
	follow_offset = offset
	if follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position + follow_offset


func _refresh_presentation() -> void:
	if _label != null:
		_label.text = _compose_text()
		_label.modulate = Color("f4efe5") if not muted else Color(0.72, 0.76, 0.78, 0.55)
	if _beam != null:
		_beam.visible = not muted
	if _light != null:
		_light.light_energy = 0.0 if muted else 1.2
	if _disc != null and _disc.material_override is StandardMaterial3D:
		(_disc.material_override as StandardMaterial3D).albedo_color = Color(
			accent.r, accent.g, accent.b, 0.55 if not muted else 0.22
		)


func _compose_text() -> String:
	var text := marker_title.to_upper()
	if show_distance and _player != null and is_instance_valid(_player):
		var distance := int(round(global_position.distance_to(_player.global_position)))
		text += "  %dm" % distance
	return text


func get_label_text() -> String:
	return _label.text if _label != null else ""


func get_marker_kind() -> StringName:
	return marker_kind


func _process(delta: float) -> void:
	_time += delta
	if follow_target != null and is_instance_valid(follow_target):
		global_position = follow_target.global_position + follow_offset
	if _beam != null and not muted:
		_beam.rotation.y += delta * 0.3
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.25
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _label != null:
		_label.text = _compose_text()
