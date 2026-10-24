extends RefCounted
## MESH KIT — merges primitive meshes into one ArrayMesh per material group.
##
## Structures are built from Godot primitives (BoxMesh, CylinderMesh, ...) but
## emitted as a handful of merged surfaces, so a whole POI costs a few draw
## calls instead of dozens. Collision is optionally accumulated into a single
## concave trimesh (cheap enough for static cover, and directly parsed by the
## navmesh baker).

## mat_key: StringName -> { "verts": PackedVector3Array, "norms": PackedVector3Array, "idx": PackedInt32Array }
var _groups: Dictionary = {}
var _collision_faces := PackedVector3Array()
var _materials: Dictionary = {}

var primitive_count := 0
var collision_triangle_count := 0

## When true, primitives are emitted as flat-shaded triangle soups (faceted
## low-poly rock look) instead of smooth indexed surfaces.
var flat_shading := false


func set_materials(materials: Dictionary) -> void:
	_materials = materials


func box(size: Vector3, pos: Vector3, mat: StringName, rot := Vector3.ZERO, collide := true) -> void:
	var m := BoxMesh.new()
	m.size = size
	_add_mesh(m, Transform3D(Basis.from_euler(rot), pos), mat, collide)


func cylinder(top_radius: float, bottom_radius: float, height: float, sides: int, pos: Vector3, mat: StringName, rot := Vector3.ZERO, collide := true) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = maxi(3, sides)
	m.rings = 1
	_add_mesh(m, Transform3D(Basis.from_euler(rot), pos), mat, collide)


func sphere(radius: float, pos: Vector3, mat: StringName, rot := Vector3.ZERO, collide := false, segments := 8, rings := 4) -> void:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = maxi(4, segments)
	m.rings = maxi(2, rings)
	_add_mesh(m, Transform3D(Basis.from_euler(rot), pos), mat, collide)


func torus(inner_radius: float, outer_radius: float, pos: Vector3, mat: StringName, rot := Vector3.ZERO, collide := false) -> void:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = 16
	m.ring_segments = 6
	_add_mesh(m, Transform3D(Basis.from_euler(rot), pos), mat, collide)


func prism(size: Vector3, pos: Vector3, mat: StringName, rot := Vector3.ZERO, collide := false) -> void:
	var m := PrismMesh.new()
	m.size = size
	_add_mesh(m, Transform3D(Basis.from_euler(rot), pos), mat, collide)


## Adds an arbitrary primitive/mesh surface transformed into the group.
func add_mesh_instance(mesh: PrimitiveMesh, xform: Transform3D, mat: StringName, collide := true) -> void:
	_add_mesh(mesh, xform, mat, collide)


func _add_mesh(mesh: Mesh, xform: Transform3D, mat: StringName, collide: bool) -> void:
	if mesh == null or mesh.get_surface_count() <= 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var group: Dictionary = _groups.get(mat, {})
	if group.is_empty():
		group = {
			"verts": PackedVector3Array(),
			"norms": PackedVector3Array(),
			"idx": PackedInt32Array(),
		}
		_groups[mat] = group
	var g_verts: PackedVector3Array = group["verts"]
	var g_norms: PackedVector3Array = group["norms"]
	var g_idx: PackedInt32Array = group["idx"]
	var base := g_verts.size()
	var basis := xform.basis
	var origin := xform.origin
	if flat_shading:
		# Triangle soup with per-face normals from the source normal direction.
		var tri_verts: PackedInt32Array = indices if not indices.is_empty() else _sequential_indices(verts.size())
		var tri_count := tri_verts.size() / 3
		g_verts.resize(base + tri_count * 3)
		g_norms.resize(base + tri_count * 3)
		for t in tri_count:
			var ia := tri_verts[t * 3]
			var ib := tri_verts[t * 3 + 1]
			var ic := tri_verts[t * 3 + 2]
			var pa := basis * verts[ia] + origin
			var pb := basis * verts[ib] + origin
			var pc := basis * verts[ic] + origin
			var nrm := Vector3.ZERO
			if ia < norms.size():
				nrm += basis * norms[ia]
			if ib < norms.size():
				nrm += basis * norms[ib]
			if ic < norms.size():
				nrm += basis * norms[ic]
			nrm = nrm.normalized() if nrm.length_squared() > 0.000001 else (pb - pa).cross(pc - pa).normalized()
			var out := base + t * 3
			g_verts[out] = pa
			g_verts[out + 1] = pb
			g_verts[out + 2] = pc
			g_norms[out] = nrm
			g_norms[out + 1] = nrm
			g_norms[out + 2] = nrm
			g_idx.append(out)
			g_idx.append(out + 1)
			g_idx.append(out + 2)
			if collide:
				_collision_faces.append(pa)
				_collision_faces.append(pb)
				_collision_faces.append(pc)
		if collide:
			collision_triangle_count += tri_count
		group["verts"] = g_verts
		group["norms"] = g_norms
		group["idx"] = g_idx
		primitive_count += 1
		return
	g_verts.resize(base + verts.size())
	g_norms.resize(base + verts.size())
	for i in verts.size():
		g_verts[base + i] = basis * verts[i] + origin
		if i < norms.size():
			g_norms[base + i] = (basis * norms[i]).normalized()
		else:
			g_norms[base + i] = Vector3.UP
	var old_idx_size := g_idx.size()
	if indices.is_empty():
		g_idx.resize(old_idx_size + verts.size())
		for i in verts.size():
			g_idx[old_idx_size + i] = base + i
	else:
		g_idx.resize(old_idx_size + indices.size())
		for i in indices.size():
			g_idx[old_idx_size + i] = base + indices[i]
	# Packed arrays can be copy-on-write: write the result back to the group.
	group["verts"] = g_verts
	group["norms"] = g_norms
	group["idx"] = g_idx
	# Collision: accumulate transformed triangles (indexed or fan).
	if collide:
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
		collision_triangle_count += (verts.size() if indices.is_empty() else indices.size()) / 3
	primitive_count += 1


## Builds one ArrayMesh with one surface per material key (insertion order).
func build_mesh() -> ArrayMesh:
	if _groups.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for mat_key in _groups.keys():
		var group: Dictionary = _groups[mat_key]
		var verts: PackedVector3Array = group["verts"]
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = group["norms"]
		arrays[Mesh.ARRAY_INDEX] = group["idx"]
		var surf := mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = _materials.get(mat_key, null)
		if material != null:
			mesh.surface_set_material(surf, material)
	return mesh


## Builds the accumulated trimesh collision, or null when nothing was flagged.
func build_collision_shape() -> ConcavePolygonShape3D:
	if _collision_faces.size() < 9:
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_collision_faces)
	return shape


func get_material_keys() -> Array:
	return _groups.keys()


func get_collision_faces() -> PackedVector3Array:
	return _collision_faces


func _sequential_indices(count: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	idx.resize(count)
	for i in count:
		idx[i] = i
	return idx
