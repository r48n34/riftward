extends RefCounted
## WORLD SCATTER ??dense MultiMesh props, landmark silhouettes, road furniture.
##
## Ecologically motivated placement: ochre rocks + spires in the canyons, teal
## coral groves in the basin, glass shards on the flats, glowing pylon lights
## that make the road network readable. Everything is instanced via MultiMesh
## (a few draw calls for thousands of props); collidable scatter merges into one
## static trimesh body so the navmesh baker sees real obstacles.

const MeshKit := preload("res://features/world/mesh_kit.gd")
const Palette := preload("res://features/world/world_palette.gd")

const ROCK_ASHEN := Color(0.58, 0.41, 0.26)
const ROCK_VERDANT := Color(0.34, 0.46, 0.40)
const ROCK_GLASS := Color(0.72, 0.74, 0.72)

var _builder: Node
var _materials: Dictionary
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _world_seed := 0
var _stats := {}
var _collision_faces := PackedVector3Array()
var _flora_groves: Array[Vector2] = []


func build(scatter_root: Node3D, builder: Node, materials: Dictionary, world_seed: int, density: float) -> Dictionary:
	_root = scatter_root
	_builder = builder
	_materials = materials
	_world_seed = world_seed
	_rng.seed = world_seed * 7919 + 13
	_stats = {"instances": 0, "types": 0}

	_scatter_rocks(density)
	_scatter_boulders(density)
	_scatter_crystals(density)
	_scatter_flora(density)
	_scatter_grass(density)
	_scatter_spores(density)
	_scatter_shards(density)
	_scatter_spires(density)
	_scatter_arches(density)
	_scatter_path_pylons()

	# One merged collision body for every collidable scatter prop.
	if _collision_faces.size() >= 9:
		var body := StaticBody3D.new()
		body.name = "ScatterCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("nav_source")
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_collision_faces)
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = shape
		body.add_child(cs)
		_root.add_child(body)
	return _stats


# =============================================================================
# Rocks & boulders
# =============================================================================
func _scatter_rocks(density: float) -> void:
	# Faceted low-poly rock chunks read as geology instead of smooth blobs.
	var kit_a := MeshKit.new()
	kit_a.set_materials(_materials)
	kit_a.flat_shading = true
	kit_a.cylinder(0.55, 0.95, 1.4, 6, Vector3(0.0, 0.1, 0.0), &"rock_solid", Vector3(0.12, 0.0, 0.2), false)
	kit_a.cylinder(0.28, 0.52, 0.9, 5, Vector3(0.55, 0.3, -0.2), &"rock_solid", Vector3(-0.1, 0.6, 0.3), false)
	kit_a.prism(Vector3(1.3, 0.8, 1.0), Vector3(-0.5, 0.15, 0.35), &"rock_solid", Vector3(0.0, 0.4, 0.0), false)
	var mesh_a := kit_a.build_mesh()
	var kit_b := MeshKit.new()
	kit_b.set_materials(_materials)
	kit_b.flat_shading = true
	kit_b.sphere(0.95, Vector3(0.0, 0.0, 0.0), &"rock_solid", Vector3.ZERO, false, 6, 3)
	kit_b.cylinder(0.35, 0.7, 1.1, 5, Vector3(0.45, 0.25, 0.3), &"rock_solid", Vector3(0.2, 0.5, -0.2), false)
	var mesh_b := kit_b.build_mesh()
	var count := int(1100.0 * density)
	var xforms_a: Array[Transform3D] = []
	var colors_a: Array[Color] = []
	var xforms_b: Array[Transform3D] = []
	var colors_b: Array[Color] = []
	for i in count:
		var sample := _pick_point(3.0, 8, 0.82)
		if sample.is_empty():
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var scale := _rng.randf_range(0.28, 1.35)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		basis = basis.scaled(Vector3(scale * _rng.randf_range(0.8, 1.5), scale * _rng.randf_range(0.5, 1.0), scale * _rng.randf_range(0.8, 1.5)))
		var xf := Transform3D(basis, Vector3(pos.x, h - scale * 0.18, pos.y))
		var col := _rock_color(sample["weights"], 0.80, 1.15)
		if i % 2 == 0:
			xforms_a.append(xf)
			colors_a.append(col)
		else:
			xforms_b.append(xf)
			colors_b.append(col)
	_commit(mesh_a, xforms_a, colors_a, "Rocks_A", true)
	_commit(mesh_b, xforms_b, colors_b, "Rocks_B", true)


func _scatter_boulders(density: float) -> void:
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	kit.flat_shading = true
	kit.sphere(1.0, Vector3(0.0, 0.0, 0.0), &"rock_solid", Vector3.ZERO, true, 7, 4)
	kit.cylinder(0.55, 1.1, 1.4, 6, Vector3(0.7, 0.2, 0.4), &"rock_solid", Vector3(0.1, 0.4, -0.2), true)
	kit.prism(Vector3(1.4, 0.9, 1.2), Vector3(-0.7, 0.1, -0.3), &"rock_solid", Vector3(0.0, 0.3, 0.1), true)
	var mesh := kit.build_mesh()
	var local_faces := kit.get_collision_faces()
	var count := int(340.0 * density)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var sample := _pick_point(5.0, 12, 0.80)
		if sample.is_empty():
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var scale := _rng.randf_range(1.5, 4.8)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		basis = basis.scaled(Vector3(scale * _rng.randf_range(0.9, 1.4), scale * _rng.randf_range(0.55, 1.0), scale * _rng.randf_range(0.9, 1.4)))
		var xf := Transform3D(basis, Vector3(pos.x, h - scale * 0.35, pos.y))
		xforms.append(xf)
		colors.append(_rock_color(sample["weights"], 0.72, 1.08))
		_append_faces_transformed(local_faces, xf)
	_commit(mesh, xforms, colors, "Boulders", true)


# =============================================================================
# Alien growth
# =============================================================================
func _scatter_crystals(density: float) -> void:
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	for c in 4:
		var ang := TAU * float(c) / 4.0 + 0.3
		kit.cylinder(0.02, _rng.randf_range(0.28, 0.46), _rng.randf_range(1.4, 2.9), 4, Vector3(cos(ang) * 0.5, 0.9, sin(ang) * 0.5), &"crystal", Vector3(cos(ang) * 0.35, ang, sin(ang) * 0.35), false)
	kit.cylinder(0.02, 0.60, 3.4, 4, Vector3(0.0, 1.7, 0.0), &"crystal", Vector3.ZERO, false)
	var mesh := kit.build_mesh()
	var count := int(480.0 * density)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var sample := _pick_point(4.0, 8, 0.82)
		if sample.is_empty():
			continue
		var weights: Vector3 = sample["weights"]
		if weights.z < 0.30 and weights.x < 0.35:
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var s := _rng.randf_range(0.5, 1.4)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.5), s))
		xforms.append(Transform3D(basis, Vector3(pos.x, h - 0.25, pos.y)))
		colors.append(Color(0.72, 0.88, 0.93).lerp(Color(0.52, 0.78, 0.80), _rng.randf()))
	_commit(mesh, xforms, colors, "Crystals", false)


func _scatter_flora(density: float) -> void:
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	_build_coral_tree(kit)
	var mesh := kit.build_mesh()
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# Groves: clustered alien coral forests read far better than uniform noise.
	var groves := int(115.0 * density)
	for g in groves:
		var center_sample := _pick_point(10.0, 8, 0.80)
		if center_sample.is_empty():
			continue
		var weights: Vector3 = center_sample["weights"]
		if weights.x < 0.40:
			continue
		var center: Vector2 = center_sample["pos"]
		_flora_groves.append(center)
		var plants := _rng.randi_range(8, 18)
		for k in plants:
			var sample := _pick_near(center, _rng.randf_range(9.0, 26.0), 3.0)
			if sample.is_empty():
				continue
			_add_tree_instance(xforms, colors, sample)
	# Sparse stragglers between groves.
	for i in int(420.0 * density):
		var sample := _pick_point(4.0, 8, 0.80)
		if sample.is_empty():
			continue
		if (sample["weights"] as Vector3).x < 0.44:
			continue
		_add_tree_instance(xforms, colors, sample)
	_commit(mesh, xforms, colors, "AlienFlora", true)


func _add_tree_instance(xforms: Array[Transform3D], colors: Array[Color], sample: Dictionary) -> void:
	var pos: Vector2 = sample["pos"]
	var h: float = sample["height"]
	var s := _rng.randf_range(0.9, 2.1)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s))
	xforms.append(Transform3D(basis, Vector3(pos.x, h - 0.15, pos.y)))
	var tint := _rng.randf_range(0.72, 1.12)
	colors.append(Color(tint * 0.82, tint, tint * 0.88))


func _build_coral_tree(kit: MeshKit) -> void:
	# Low-poly alien coral: rooted dark trunk, five drooping fronds, round pads.
	kit.cylinder(0.38, 0.95, 0.7, 6, Vector3(0.0, 0.35, 0.0), &"flora_trunk", Vector3.ZERO, false)
	kit.cylinder(0.14, 0.36, 2.6, 6, Vector3(0.0, 1.3, 0.0), &"flora_trunk", Vector3.ZERO, false)
	var pad := SphereMesh.new()
	pad.radius = 0.55
	pad.height = 1.1
	pad.radial_segments = 5
	pad.rings = 3
	var pad_big := SphereMesh.new()
	pad_big.radius = 0.8
	pad_big.height = 1.6
	pad_big.radial_segments = 6
	pad_big.rings = 3
	for f in 5:
		var ang := TAU * float(f) / 5.0 + 0.5
		var dir := Vector3(cos(ang) * 1.25, 1.4, sin(ang) * 1.25).normalized()
		var start := Vector3(0.0, 2.2, 0.0)
		var mid := start + dir * 1.3
		kit.cylinder(0.05, 0.18, 2.6, 4, mid, &"flora_trunk", _rot_from_up(dir), false)
		var tip := start + dir * 2.6
		var frond_dir := (dir + Vector3.UP * 0.8).normalized()
		var pad_xf := Transform3D(Basis.from_euler(_rot_from_up(frond_dir)).scaled(Vector3(1.5, 0.85, 1.5)), tip + frond_dir * 1.0)
		kit.add_mesh_instance(pad, pad_xf, &"flora_canopy", false)
		var droop_dir := (dir * 1.3 - Vector3.UP * 0.4).normalized()
		kit.cylinder(0.0, 0.22, 1.1, 4, tip + droop_dir * 0.5, &"flora_canopy", _rot_from_up(droop_dir), false)
	kit.add_mesh_instance(pad_big, Transform3D(Basis.IDENTITY.scaled(Vector3(1.3, 0.9, 1.3)), Vector3(0.0, 3.9, 0.0)), &"flora_canopy", false)


func _scatter_grass(density: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.18
	mesh.height = 0.9
	mesh.radial_segments = 3
	mesh.rings = 1
	mesh.material = _materials[&"grass"]
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# Tufts hug the flora groves and wet lowland patches.
	var clumps := int(150.0 * density)
	for c in clumps:
		var center := Vector2.ZERO
		if not _flora_groves.is_empty() and _rng.randf() < 0.6:
			center = _flora_groves[_rng.randi_range(0, _flora_groves.size() - 1)]
		else:
			var center_sample := _pick_point(8.0, 6, 0.80)
			if center_sample.is_empty():
				continue
			if (center_sample["weights"] as Vector3).x < 0.30:
				continue
			center = center_sample["pos"]
		var tufts := _rng.randi_range(5, 12)
		for k in tufts:
			var sample := _pick_near(center, _rng.randf_range(6.0, 20.0), 2.0)
			if sample.is_empty():
				continue
			_add_grass_instance(xforms, colors, sample)
	for i in int(1200.0 * density):
		var sample := _pick_point(2.5, 6, 0.82)
		if sample.is_empty():
			continue
		var weights: Vector3 = sample["weights"]
		if weights.x < 0.30 and weights.z < 0.45:
			continue
		_add_grass_instance(xforms, colors, sample)
	_commit(mesh, xforms, colors, "GrassTufts", false)


func _add_grass_instance(xforms: Array[Transform3D], colors: Array[Color], sample: Dictionary) -> void:
	var pos: Vector2 = sample["pos"]
	var h: float = sample["height"]
	var s := _rng.randf_range(0.5, 1.7)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.8), s))
	xforms.append(Transform3D(basis, Vector3(pos.x, h - 0.05, pos.y)))
	var c := Color(0.52, 0.88, 0.72).lerp(Color(0.86, 0.92, 0.70), _rng.randf() * 0.45)
	colors.append(c.darkened(_rng.randf() * 0.22))


func _scatter_spores(density: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _materials[&"spore"]
	var count := int(340.0 * density)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var sample := _pick_point(2.0, 6, 0.80)
		if sample.is_empty():
			continue
		if (sample["weights"] as Vector3).x < 0.42:
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var s := _rng.randf_range(0.7, 2.4)
		xforms.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(pos.x, h + 0.5 + _rng.randf_range(0.0, 1.6), pos.y)))
		colors.append(Color.WHITE)
	_commit(mesh, xforms, colors, "Spores", false)


func _scatter_shards(density: float) -> void:
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	for s in 3:
		var ang := TAU * float(s) / 3.0
		kit.cylinder(0.02, 0.36, _rng.randf_range(0.9, 1.9), 4, Vector3(cos(ang) * 0.42, 0.45, sin(ang) * 0.42), &"glass_shard", Vector3(cos(ang) * 0.55, ang, sin(ang) * 0.55), false)
	var mesh := kit.build_mesh()
	var count := int(650.0 * density)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var sample := _pick_point(2.5, 6, 0.84)
		if sample.is_empty():
			continue
		if (sample["weights"] as Vector3).z < 0.38:
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var s := _rng.randf_range(0.5, 2.4)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(1.0, 2.4), s))
		xforms.append(Transform3D(basis, Vector3(pos.x, h - 0.12, pos.y)))
		colors.append(Color(0.84, 0.94, 1.0).lerp(Color(0.62, 0.84, 0.88), _rng.randf()))
	_commit(mesh, xforms, colors, "GlassShards", true)


# =============================================================================
# Landmark silhouettes
# =============================================================================
func _scatter_spires(density: float) -> void:
	# Jagged rock spires: horizon-scale landmarks visible across the frontier.
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	kit.flat_shading = true
	# Stacked, offset, tapering segments create a broken natural silhouette.
	kit.cylinder(2.8, 8.6, 16.0, 7, Vector3(0.0, 7.5, 0.0), &"rock_solid", Vector3(0.03, 0.0, 0.05), true)
	kit.cylinder(1.5, 3.6, 17.0, 6, Vector3(2.0, 21.0, -1.4), &"rock_solid", Vector3(0.07, 0.9, -0.09), true)
	kit.cylinder(0.7, 2.1, 15.0, 5, Vector3(-1.8, 34.0, 1.6), &"rock_solid", Vector3(-0.07, 0.3, 0.12), true)
	kit.cylinder(0.08, 0.85, 11.0, 5, Vector3(0.5, 45.0, -0.8), &"rock_solid", Vector3(0.1, 0.7, -0.05), true)
	# Secondary outcroppings at the base.
	kit.cylinder(0.9, 3.1, 10.0, 5, Vector3(-3.6, 9.0, 2.0), &"rock_solid", Vector3(0.0, 0.4, -0.55), true)
	kit.cylinder(0.4, 1.4, 7.0, 4, Vector3(3.4, 4.0, 2.6), &"rock_solid", Vector3(0.2, 1.2, 0.3), true)
	kit.prism(Vector3(2.0, 1.6, 3.0), Vector3(-4.2, 6.0, -1.0), &"rock_solid", Vector3(0.0, 0.7, 0.3), true)
	var mesh := kit.build_mesh()
	var local_faces := kit.get_collision_faces()
	var count := int(52.0 * density)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in count:
		var sample := _pick_point(8.0, 14, 0.88)
		if sample.is_empty():
			continue
		var weights: Vector3 = sample["weights"]
		if weights.y < 0.22 and weights.z < 0.18:
			continue
		if not _builder.is_landmark_clear(sample["pos"]):
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var s := _rng.randf_range(0.45, 2.1)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.7), s))
		var xf := Transform3D(basis, Vector3(pos.x, h - 1.8, pos.y))
		xforms.append(xf)
		colors.append(_spire_color(weights, 0.62, 0.98))
		_append_faces_transformed(local_faces, xf)
	_commit(mesh, xforms, colors, "Spires", true)


func _scatter_arches(density: float) -> void:
	# Giant natural arches ??navigational landmarks in the canyons.
	var count := int(14.0 * density)
	var arches_root := Node3D.new()
	arches_root.name = "NaturalArches"
	_root.add_child(arches_root)
	var built := 0
	for i in count:
		var sample := _pick_point(10.0, 14, 0.88)
		if sample.is_empty():
			continue
		if (sample["weights"] as Vector3).y < 0.30:
			continue
		if not _builder.is_landmark_clear(sample["pos"]):
			continue
		var pos: Vector2 = sample["pos"]
		var h: float = sample["height"]
		var kit := MeshKit.new()
		kit.set_materials(_materials)
		kit.flat_shading = true
		var span := _rng.randf_range(10.0, 20.0)
		var leg_h := _rng.randf_range(15.0, 32.0)
		kit.cylinder(_rng.randf_range(1.3, 2.2), _rng.randf_range(2.6, 4.0), leg_h, 7, Vector3(-span * 0.5, leg_h * 0.5, 0.0), &"rock_solid", Vector3(0.0, 0.0, 0.07), true)
		kit.cylinder(_rng.randf_range(1.0, 1.9), _rng.randf_range(2.3, 3.6), leg_h * _rng.randf_range(0.7, 1.0), 7, Vector3(span * 0.5, leg_h * 0.4, 0.0), &"rock_solid", Vector3(0.0, 0.0, -0.06), true)
		kit.box(Vector3(span + 3.0, _rng.randf_range(2.2, 3.8), _rng.randf_range(3.2, 5.4)), Vector3(0.0, leg_h * 0.92, 0.0), &"rock_solid", Vector3(0.0, _rng.randf_range(-0.2, 0.2), 0.0), true)
		var mesh := kit.build_mesh()
		var mi := MeshInstance3D.new()
		mi.name = "Arch_%02d" % i
		mi.mesh = mesh
		mi.position = Vector3(pos.x, h - 0.8, pos.y)
		mi.rotation.y = _rng.randf() * TAU
		arches_root.add_child(mi)
		_append_faces_transformed(kit.get_collision_faces(), Transform3D(Basis(Vector3.UP, mi.rotation.y), mi.position))
		built += 1
	_stats["arches"] = built


# =============================================================================
# Road furniture
# =============================================================================
func _scatter_path_pylons() -> void:
	var kit := MeshKit.new()
	kit.set_materials(_materials)
	kit.cylinder(0.10, 0.16, 2.6, 5, Vector3(0.0, 1.3, 0.0), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(0.5, 0.28, 0.5), Vector3(0.0, 2.7, 0.0), &"lamp", Vector3.ZERO, false)
	var mesh := kit.build_mesh()
	var segments: Array = _builder.get_path_segments()
	var spacing := 42.0
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for seg_index in segments.size():
		var poly: PackedVector2Array = segments[seg_index]
		var carry := 0.0
		for i in range(poly.size() - 1):
			var a := poly[i]
			var b := poly[i + 1]
			var seg_len := a.distance_to(b)
			var travelled := carry
			while travelled < seg_len:
				var t := travelled / maxf(seg_len, 0.001)
				var p := a.lerp(b, t)
				var h: float = _builder.sample_height(p)
				xforms.append(Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.y - a.y)), Vector3(p.x, h, p.y)))
				colors.append(Color(0.7, 1.0, 0.95))
				travelled += spacing
			carry = travelled - seg_len
	_commit(mesh, xforms, colors, "PathPylons", false)


# =============================================================================
# Placement helpers
# =============================================================================
func _pick_point(clear_pad: float, max_tries: int, edge_limit: float) -> Dictionary:
	var half: float = float(_builder.map_size) * 0.5
	for attempt in max_tries:
		var x := _rng.randf_range(-half * edge_limit, half * edge_limit)
		var z := _rng.randf_range(-half * edge_limit, half * edge_limit)
		var pos := Vector2(x, z)
		if not _builder.is_scatter_clear(pos, clear_pad):
			continue
		var h: float = _builder.sample_height(pos)
		# Skip steep ground for props that would float or clip badly.
		var hx: float = _builder.sample_height(pos + Vector2(3.0, 0.0)) - _builder.sample_height(pos - Vector2(3.0, 0.0))
		var hz: float = _builder.sample_height(pos + Vector2(0.0, 3.0)) - _builder.sample_height(pos - Vector2(0.0, 3.0))
		if absf(hx) + absf(hz) > 3.4:
			continue
		return {"pos": pos, "height": h, "weights": _builder.get_biome_weights_at(pos)}
	return {}


func _pick_near(center: Vector2, radius: float, clear_pad: float) -> Dictionary:
	var half: float = float(_builder.map_size) * 0.5 * 0.92
	for attempt in 6:
		var ang := _rng.randf() * TAU
		var dist := sqrt(_rng.randf()) * radius
		var pos := center + Vector2(cos(ang), sin(ang)) * dist
		if absf(pos.x) > half or absf(pos.y) > half:
			continue
		if not _builder.is_scatter_clear(pos, clear_pad):
			continue
		var h: float = _builder.sample_height(pos)
		return {"pos": pos, "height": h, "weights": _builder.get_biome_weights_at(pos)}
	return {}


func _rock_color(weights: Vector3, low: float, high: float) -> Color:
	var col := ROCK_ASHEN * weights.y + ROCK_VERDANT * weights.x + ROCK_GLASS * weights.z
	var v := _rng.randf_range(low, high)
	var warm := _rng.randf_range(-0.05, 0.05)
	return Color(
		clampf(col.r * v + warm, 0.0, 1.0),
		clampf(col.g * v, 0.0, 1.0),
		clampf(col.b * v - warm * 0.5, 0.0, 1.0)
	)


func _spire_color(weights: Vector3, low: float, high: float) -> Color:
	var col := ROCK_ASHEN * weights.y + ROCK_VERDANT * weights.x + ROCK_GLASS * weights.z
	return col * _rng.randf_range(low, high)


func _rot_from_up(dir: Vector3) -> Vector3:
	var up := Vector3.UP
	var axis := up.cross(dir)
	var angle := up.angle_to(dir)
	if axis.length_squared() < 0.0001:
		return Vector3.ZERO
	return Basis(axis.normalized(), angle).get_euler()


# =============================================================================
# MultiMesh helpers
# =============================================================================
func _commit(mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], node_name: String, shadows: bool) -> void:
	if mesh == null or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mmi)
	_stats["instances"] = int(_stats["instances"]) + xforms.size()
	_stats["types"] = int(_stats["types"]) + 1


func _append_primitive_faces(mesh: Mesh, xform: Transform3D) -> void:
	if mesh == null or mesh.get_surface_count() <= 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var basis := xform.basis
	var origin := xform.origin
	if indices.is_empty():
		for i in range(0, verts.size() - 2, 3):
			_collision_faces.append(basis * verts[i] + origin)
			_collision_faces.append(basis * verts[i + 1] + origin)
			_collision_faces.append(basis * verts[i + 2] + origin)
	else:
		for i in range(0, indices.size() - 2, 3):
			_collision_faces.append(basis * verts[indices[i]] + origin)
			_collision_faces.append(basis * verts[indices[i + 1]] + origin)
			_collision_faces.append(basis * verts[indices[i + 2]] + origin)


func _append_faces_transformed(faces: PackedVector3Array, xform: Transform3D) -> void:
	var basis := xform.basis
	var origin := xform.origin
	for i in range(0, faces.size() - 2, 3):
		_collision_faces.append(basis * faces[i] + origin)
		_collision_faces.append(basis * faces[i + 1] + origin)
		_collision_faces.append(basis * faces[i + 2] + origin)



