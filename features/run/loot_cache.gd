class_name LootCache
extends StaticBody3D
## One-shot breachable side cache. Interact (E) to crack it open; it grants
## salvage/cores (and usually a generated item) through RunState, plays VFX and
## reports back to the Deployment (on_cache_opened) so mission tracking can
## advance. The payload is authored by the Deployment so difficulty loot luck
## and threat scaling stay in one place.

signal opened(cache: Node, by: Node)

const INTERACT_LAYER: int = 32  # Project layer 6 "Interactable"

var cache_id: StringName = &"cache"
var title: String = "Supply Cache"
var deployment: Node = null
var payload: Dictionary = {}
var is_open: bool = false

var _accent: Color = Color("ffb866")
var _visual_root: Node3D = null
var _crate: MeshInstance3D = null
var _lid: MeshInstance3D = null
var _beam: MeshInstance3D = null
var _light: OmniLight3D = null
var _label: Label3D = null
var _time: float = 0.0


func setup(p_id: StringName, p_position: Vector3, p_deployment: Node, p_payload: Dictionary = {}) -> void:
	cache_id = p_id
	deployment = p_deployment
	payload = p_payload.duplicate(true)
	title = String(payload.get("label", payload.get("title", title)))
	global_position = p_position
	if is_inside_tree():
		_refresh_presentation()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot_cache")
	collision_layer = INTERACT_LAYER
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.5, 1.7)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.75, 0.0)
	add_child(collision)
	_build_visual()


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	var body_mat := _mat(Color("3a2a1c"), Color("ffb866"), 0.25)
	var trim_mat := _mat(Color("ffb866"), Color("ffb866"), 2.2)
	_crate = MeshInstance3D.new()
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.7, 0.95, 1.25)
	_crate.mesh = crate_mesh
	_crate.material_override = body_mat
	_crate.position = Vector3(0.0, 0.52, 0.0)
	_crate.rotation.y = 0.22
	_visual_root.add_child(_crate)
	_lid = MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.78, 0.16, 1.33)
	_lid.mesh = lid_mesh
	_lid.material_override = trim_mat
	_lid.position = Vector3(0.0, 1.06, 0.0)
	_lid.rotation.y = 0.22
	_visual_root.add_child(_lid)
	for i in 2:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.12, 1.02, 1.3)
		strap.mesh = strap_mesh
		strap.material_override = trim_mat
		strap.position = Vector3(-0.45 + float(i) * 0.9, 0.52, 0.0)
		strap.rotation.y = 0.22
		strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_root.add_child(strap)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.3
	beam_mesh.height = 7.0
	beam_mesh.radial_segments = 10
	_beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.22)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = _accent
	beam_mat.emission_energy_multiplier = 1.6
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	_beam.position = Vector3(0.0, 3.5, 0.0)
	_visual_root.add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = _accent
	_light.light_energy = 1.3
	_light.omni_range = 6.5
	_light.position = Vector3(0.0, 1.6, 0.0)
	_visual_root.add_child(_light)
	_label = Label3D.new()
	_label.name = "CacheLabel"
	_label.text = "SUPPLY CACHE"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = Color("ffd9a0")
	_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.85)
	_label.position = Vector3(0.0, 2.15, 0.0)
	_visual_root.add_child(_label)
	_refresh_presentation()


func _refresh_presentation() -> void:
	if _label != null:
		_label.text = (title if not is_open else "BREACHED").to_upper()
		_label.modulate = Color(0.72, 0.76, 0.78, 0.6) if is_open else Color("ffd9a0")
	if _beam != null:
		_beam.visible = not is_open
	if _light != null:
		_light.light_energy = 0.0 if is_open else 1.3


func _mat(base: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.metallic = 0.35
	mat.roughness = 0.5
	mat.emission_enabled = energy > 0.0
	mat.emission = emission_color
	mat.emission_energy_multiplier = energy
	return mat


func _process(delta: float) -> void:
	if is_open:
		return
	_time += delta
	if _crate != null:
		_crate.position.y = 0.52 + sin(_time * 1.6) * 0.03
	if _beam != null:
		_beam.rotation.y += delta * 0.35
		_beam.scale = Vector3(1.0, 1.0 + sin(_time * 2.2) * 0.05, 1.0)
	if _light != null:
		_light.light_energy = 1.1 + sin(_time * 2.6) * 0.35


func get_interact_prompt() -> String:
	if is_open:
		return ""
	return "E — Breach cache"


func interact(by: Node) -> void:
	_open(by)


func _open(by: Node) -> void:
	if is_open:
		return
	is_open = true
	collision_layer = 0
	_grant_payload()
	_play_open_vfx()
	opened.emit(self, by)
	if deployment != null and is_instance_valid(deployment) and deployment.has_method("on_cache_opened"):
		deployment.call("on_cache_opened", self, by)
	_refresh_presentation()
	if _visual_root != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual_root, "scale", Vector3(0.05, 0.05, 0.05), 0.22)
		tween.tween_property(_visual_root, "position:y", _visual_root.position.y + 0.55, 0.22)
		tween.chain().tween_callback(queue_free)


func _grant_payload() -> void:
	if payload.is_empty():
		return
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		return
	var salvage := int(payload.get("salvage", 0))
	var cores := int(payload.get("cores", 0))
	if (salvage > 0 or cores > 0) and run_state.has_method("add_satchel_salvage"):
		run_state.call("add_satchel_salvage", salvage, cores)
	var item: Dictionary = payload.get("item", {})
	if not item.is_empty() and run_state.has_method("add_loot_item"):
		run_state.call("add_loot_item", item)


func _play_open_vfx() -> void:
	var parent := get_parent() as Node3D
	if parent == null or not is_instance_valid(parent):
		return
	CombatVFX.ring(parent, global_position + Vector3.UP * 0.1, 3.4, _accent, 0.7)
	CombatVFX.explosion(parent, global_position + Vector3.UP * 0.7, 2.4, _accent)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null and audio.has_method("play_3d"):
		audio.call("play_3d", &"pickup", global_position, -5.0)


func get_payload() -> Dictionary:
	return payload


func is_opened() -> bool:
	return is_open
