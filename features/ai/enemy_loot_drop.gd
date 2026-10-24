class_name EnemyLootDrop
extends StaticBody3D
## Visible low-poly loot cache dropped by dying enemies. Auto-collects when the
## player is within ~2.2 m, or via the player's interact ray (E) using the
## standard "interactable" contract. Awards RunState satchel salvage and may
## grant a generated ItemFactory item.

signal collected(by: Node, payload: Dictionary)

const AUTO_COLLECT_RADIUS := 2.2
const INTERACT_LAYER := 32 | 256  # Interactable (6) + Pickup (9)
const LABEL_RANGE := 8.0

var payload: Dictionary = {}
var _collected: bool = false
var _time: float = 0.0
var _label_timer: float = 0.0
var _player: Node3D = null
var _visual_root: Node3D = null
var _spin_root: Node3D = null
var _beam: MeshInstance3D = null
var _label: Label3D = null
var _rarity_color: Color = Color("a7b4b6")


static func spawn(parent: Node3D, at: Vector3, p_payload: Dictionary) -> EnemyLootDrop:
	if parent == null or not is_instance_valid(parent):
		return null
	var drop := EnemyLootDrop.new()
	drop.name = "LootDrop"
	drop.payload = p_payload.duplicate(true)
	parent.add_child(drop)
	drop.global_position = at
	return drop


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("loot_drop")
	collision_layer = INTERACT_LAYER
	collision_mask = 0

	var rarity := clampi(int(payload.get("rarity", 0)), 0, StatKeys.RARITY_COLORS.size() - 1)
	_rarity_color = StatKeys.RARITY_COLORS[rarity]

	var shape_node := CollisionShape3D.new()
	shape_node.name = "PickupShape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.34
	shape_node.shape = sphere
	shape_node.position = Vector3(0.0, 0.26, 0.0)
	add_child(shape_node)

	_build_visuals(rarity)
	_build_pickup_area()

	set_process(true)


func _build_visuals(rarity: int) -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)

	var base_mat := EnemyVisuals.make_material(Color("1b2a2e"), 0.0, 0.5, 0.4)
	var body_mat := EnemyVisuals.make_material(_rarity_color.darkened(0.55), 0.0, 0.6, 0.35)
	var glow_mat := EnemyVisuals.make_material(_rarity_color, 2.6, 0.0, 0.3, true)
	var beam_mat := EnemyVisuals.make_material(Color(_rarity_color.r, _rarity_color.g, _rarity_color.b, 0.32), 1.4, 0.0, 0.3, true)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var base_disc := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.34
	base_mesh.bottom_radius = 0.38
	base_mesh.height = 0.06
	base_mesh.radial_segments = 8
	base_disc.mesh = base_mesh
	base_disc.material_override = base_mat
	base_disc.position = Vector3(0.0, 0.03, 0.0)
	base_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(base_disc)

	_spin_root = Node3D.new()
	_spin_root.name = "Spin"
	_spin_root.position = Vector3(0.0, 0.24, 0.0)
	_visual_root.add_child(_spin_root)

	var canister := MeshInstance3D.new()
	var can_mesh := CylinderMesh.new()
	can_mesh.top_radius = 0.15
	can_mesh.bottom_radius = 0.18
	can_mesh.height = 0.3
	can_mesh.radial_segments = 6
	canister.mesh = can_mesh
	canister.material_override = body_mat
	_spin_root.add_child(canister)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.19
	ring_mesh.bottom_radius = 0.19
	ring_mesh.height = 0.04
	ring_mesh.radial_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = glow_mat
	ring.position = Vector3(0.0, 0.16, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin_root.add_child(ring)

	var item_payload: Dictionary = payload.get("item", {})
	var has_item := not item_payload.is_empty()
	if has_item:
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.22, 0.34, 0.22)
		crystal.mesh = prism
		crystal.material_override = glow_mat
		crystal.position = Vector3(0.0, 0.32, 0.0)
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin_root.add_child(crystal)
	else:
		var core := MeshInstance3D.new()
		var core_mesh := SphereMesh.new()
		core_mesh.radius = 0.1
		core_mesh.height = 0.2
		core_mesh.radial_segments = 6
		core_mesh.rings = 3
		core.mesh = core_mesh
		core.material_override = glow_mat
		core.position = Vector3(0.0, 0.34, 0.0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin_root.add_child(core)

	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.012
	beam_mesh.bottom_radius = 0.05
	beam_mesh.height = 1.9
	beam_mesh.radial_segments = 5
	beam_mesh.rings = 1
	_beam.mesh = beam_mesh
	_beam.material_override = beam_mat
	_beam.position = Vector3(0.0, 1.05, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(_beam)

	var light := OmniLight3D.new()
	light.light_color = _rarity_color
	light.light_energy = 0.55
	light.omni_range = 2.4
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.5, 0.0)
	_visual_root.add_child(light)

	_label = Label3D.new()
	_label.name = "LootLabel"
	_label.text = String(payload.get("label", "Salvage"))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = _rarity_color
	_label.outline_modulate = Color(0.02, 0.03, 0.04, 0.85)
	_label.position = Vector3(0.0, 1.18, 0.0)
	_label.visible = false
	_visual_root.add_child(_label)


func _build_pickup_area() -> void:
	var area := Area3D.new()
	area.name = "PickupArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Player layer
	area.monitoring = true
	area.monitorable = false
	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = AUTO_COLLECT_RADIUS
	area_shape.shape = sphere
	area_shape.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(area_shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _collected or body == null:
		return
	if body.is_in_group("player"):
		collect(body)


func get_interact_prompt() -> String:
	if _collected:
		return ""
	return String(payload.get("prompt", "Collect salvage  [E]"))


func interact(by: Node) -> void:
	collect(by)


func collect(by: Node) -> void:
	if _collected:
		return
	_collected = true
	set_process(false)

	var run_state := get_node_or_null("/root/RunState")
	var salvage := int(payload.get("salvage", 0))
	var cores := int(payload.get("cores", 0))
	if run_state != null:
		if (salvage > 0 or cores > 0) and run_state.has_method("add_satchel_salvage"):
			run_state.call("add_satchel_salvage", salvage, cores)
		var item: Dictionary = payload.get("item", {})
		if not item.is_empty() and run_state.has_method("add_loot_item"):
			run_state.call("add_loot_item", item)

	collected.emit(by, payload)
	_show_pickup_text(salvage, cores)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("play_3d", &"pickup", global_position, -6.0)

	set_deferred("collision_layer", 0)
	if _beam != null:
		_beam.visible = false
	if _label != null:
		_label.visible = false
	if _visual_root != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual_root, "scale", Vector3(0.05, 0.05, 0.05), 0.18)
		tween.tween_property(_visual_root, "position:y", _visual_root.position.y + 0.5, 0.2)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _show_pickup_text(salvage: int, cores: int) -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var text := ""
	var item: Dictionary = payload.get("item", {})
	if not item.is_empty():
		text = String(payload.get("item_label", "Recovered gear"))
	elif salvage > 0:
		text = "+%d salvage" % salvage
	if cores > 0:
		text += "  +%d core" % cores
	if text.is_empty():
		return
	var floater := Label3D.new()
	floater.text = text
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.no_depth_test = true
	floater.font_size = 34
	floater.outline_size = 9
	floater.modulate = _rarity_color.lightened(0.25)
	floater.outline_modulate = Color(0.02, 0.03, 0.04, 0.9)
	parent.add_child(floater)
	floater.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	var tween := floater.create_tween()
	tween.set_parallel(true)
	tween.tween_property(floater, "global_position", floater.global_position + Vector3(0.0, 1.1, 0.0), 0.8)
	tween.tween_property(floater, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(floater.queue_free)


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	if _spin_root != null:
		_spin_root.rotation.y += delta * 1.5
		_spin_root.position.y = 0.24 + sin(_time * 2.4) * 0.05
	if _beam != null:
		_beam.scale = Vector3(1.0, 1.0 + sin(_time * 3.1) * 0.08, 1.0)
	_label_timer -= delta
	if _label_timer <= 0.0 and _label != null:
		_label_timer = 0.35
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		var near_player := (
			_player != null
			and is_instance_valid(_player)
			and global_position.distance_squared_to(_player.global_position) <= LABEL_RANGE * LABEL_RANGE
		)
		_label.visible = near_player


func get_payload() -> Dictionary:
	return payload


func is_collected() -> bool:
	return _collected


func get_rarity_color() -> Color:
	return _rarity_color
