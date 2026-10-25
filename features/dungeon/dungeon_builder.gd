extends Node3D
## DUNGEON BUILDER — deterministic procedural under-reach instance.
##
## A 3x3 slot grid grows a connected room graph from the centre slot. Rooms are
## hollow (floor/ceiling/four walls with 4.5m doorways), corridors join adjacent
## slots, and the whole instance is merged into a handful of surfaces with one
## trimesh collider. A private NavigationRegion3D is baked synchronously before
## the player is allowed inside.
##
## The builder is placed far from the frontier (Deployment owns the origin) so it
## never intersects the surface world. Theme data is injected by the caller; this
## file has no ContentDB dependency.

const MeshKit := preload("res://features/world/mesh_kit.gd")

const ROOM_HEIGHT := 4.2
const CORRIDOR_HEIGHT := 4.0
const CORRIDOR_WIDTH := 5.0
const SLOT_SPACING := 34.0
const DOOR_WIDTH := 4.5
const DOOR_HEIGHT := 3.4
const WALL_THICKNESS := 0.5

var theme: Dictionary = {}
var threat := 1
var theme_id: StringName = &""
var display_name := "Under-Reach"

var _rooms: Array[Dictionary] = []
var _corridors: Array[Dictionary] = []
var _materials: Dictionary = {}
var _kit: MeshKit = null
var _nav_region: NavigationRegion3D = null
var _root: Node3D = null
var _start_position := Vector3.ZERO
var _exit_position := Vector3.ZERO
var _boss_position := Vector3.ZERO
var _loot_positions: Array[Vector3] = []
var _room_centers: Array[Vector3] = []
var _bounds := AABB()
var _origin := Vector3.ZERO


func generate(seed_value: int, p_theme: Dictionary, p_threat: int, origin: Vector3) -> bool:
	theme = p_theme.duplicate(true) if p_theme is Dictionary else {}
	threat = maxi(1, p_threat)
	theme_id = StringName(theme.get("id", &"rift_vault"))
	display_name = String(theme.get("display_name", "Rift Vault"))
	name = "Dungeon_%s" % String(theme_id)
	# Bake in local space: the crash-prevention check rejects huge absolute
	# coordinates. The instance is moved to its remote origin after baking.
	_origin = origin
	global_position = Vector3.ZERO
	_build_materials()
	_layout(seed_value)
	if _rooms.is_empty():
		return false
	_build_geometry()
	_build_navigation()
	global_position = _origin
	return true


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
func _layout(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 23
	var room_min := clampi(int(theme.get("room_min", 5)), 4, 9)
	var room_max := clampi(int(theme.get("room_max", 8)), room_min, 9)
	var target_rooms := rng.randi_range(room_min, room_max)
	var occupied: Dictionary = {}
	var queue: Array[Vector2i] = []
	var start_slot := Vector2i(1, 1)
	occupied[start_slot] = 0
	queue.append(start_slot)
	var slots: Array[Vector2i] = [start_slot]
	var parents: Array[Vector2i] = [start_slot]
	while slots.size() < target_rooms and not queue.is_empty():
		var parent: Vector2i = queue.pop_front()
		var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for i in range(directions.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := directions[i]
			directions[i] = directions[j]
			directions[j] = swap
		for direction in directions:
			if slots.size() >= target_rooms:
				break
			var slot := parent + direction
			if slot.x < 0 or slot.x > 2 or slot.y < 0 or slot.y > 2:
				continue
			if occupied.has(slot):
				continue
			occupied[slot] = slots.size()
			slots.append(slot)
			parents.append(parent)
			queue.append(slot)
	if slots.size() < 4:
		# Guaranteed minimum: a straight four-room line.
		slots = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]
		parents = [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	_rooms.clear()
	_corridors.clear()
	for i in slots.size():
		var slot: Vector2i = slots[i]
		var size := rng.randf_range(14.0, 18.0)
		var is_boss := i == slots.size() - 1
		if is_boss:
			size += 4.0
		var center := Vector3(float(slot.x - 1) * SLOT_SPACING, 0.0, float(slot.y - 1) * SLOT_SPACING)
		_rooms.append({
			"index": i,
			"slot": slot,
			"center": center,
			"size": Vector3(size, 0.0, size),
			"boss": is_boss,
			"doors": [false, false, false, false],
		})
	for i in range(1, slots.size()):
		var parent_slot: Vector2i = parents[i]
		var parent_index := int(occupied.get(parent_slot, 0))
		if parent_index >= _rooms.size():
			continue
		var child_index := i
		var parent_room: Dictionary = _rooms[parent_index]
		var child_room: Dictionary = _rooms[child_index]
		var parent_center: Vector3 = parent_room["center"]
		var child_center: Vector3 = child_room["center"]
		var axis := "x" if absf(child_center.x - parent_center.x) > 0.1 else "z"
		_corridors.append({
			"from": parent_index,
			"to": child_index,
			"axis": axis,
			"from_center": parent_center,
			"to_center": child_center,
		})
		var direction := _side_between(parent_center, child_center)
		var parent_doors: Array = parent_room["doors"]
		parent_doors[direction] = true
		var child_doors: Array = child_room["doors"]
		child_doors[_opposite_side(direction)] = true
	_start_position = (_rooms[0]["center"] as Vector3) + Vector3(0.0, 0.1, 0.0)
	_exit_position = _start_position
	_boss_position = (_rooms[_rooms.size() - 1]["center"] as Vector3) + Vector3(0.0, 0.1, 0.0)
	_room_centers.clear()
	_loot_positions.clear()
	for i in _rooms.size():
		var room: Dictionary = _rooms[i]
		var center: Vector3 = room["center"]
		_room_centers.append(center)
		if i > 0 and not bool(room["boss"]):
			var size: Vector3 = room["size"]
			_loot_positions.append(center + Vector3(size.x * 0.28, 0.2, size.z * 0.24))
			_loot_positions.append(center + Vector3(-size.x * 0.26, 0.2, -size.z * 0.22))
	_bounds = _compute_bounds()


func _side_between(a: Vector3, b: Vector3) -> int:
	var delta := b - a
	if absf(delta.x) > absf(delta.z):
		return 2 if delta.x > 0.0 else 3
	return 0 if delta.z > 0.0 else 1


func _opposite_side(side: int) -> int:
	match side:
		0:
			return 1
		1:
			return 0
		2:
			return 3
		_:
			return 2


func _compute_bounds() -> AABB:
	var min_point := Vector3(1.0e20, 0.0, 1.0e20)
	var max_point := Vector3(-1.0e20, ROOM_HEIGHT + 1.0, -1.0e20)
	for room in _rooms:
		var center: Vector3 = room["center"]
		var size: Vector3 = room["size"]
		min_point.x = minf(min_point.x, center.x - size.x * 0.5 - 1.0)
		min_point.z = minf(min_point.z, center.z - size.z * 0.5 - 1.0)
		max_point.x = maxf(max_point.x, center.x + size.x * 0.5 + 1.0)
		max_point.z = maxf(max_point.z, center.z + size.z * 0.5 + 1.0)
	return AABB(min_point, max_point - min_point)


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------
func _build_materials() -> void:
	var wall_color: Color = theme.get("wall_color", Color("243744"))
	var floor_color: Color = theme.get("floor_color", Color("1a2428"))
	var accent: Color = theme.get("accent", Color("c79cff"))
	var wall := StandardMaterial3D.new()
	wall.albedo_color = wall_color
	wall.roughness = 0.88
	wall.metallic = 0.10
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = floor_color
	floor_mat.roughness = 0.92
	floor_mat.metallic = 0.08
	var trim := StandardMaterial3D.new()
	trim.albedo_color = wall_color.lightened(0.18)
	trim.roughness = 0.45
	trim.metallic = 0.55
	var glow := StandardMaterial3D.new()
	glow.albedo_color = accent
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 2.6
	glow.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = floor_color.darkened(0.45)
	dark.roughness = 0.95
	_materials = {&"wall": wall, &"floor": floor_mat, &"trim": trim, &"glow": glow, &"dark": dark}


func _build_geometry() -> void:
	_root = Node3D.new()
	_root.name = "Geometry"
	add_child(_root)
	_kit = MeshKit.new()
	_kit.set_materials(_materials)
	for room in _rooms:
		_build_room(room)
	for corridor in _corridors:
		_build_corridor(corridor)
	_finalize_geometry()


func _build_room(room: Dictionary) -> void:
	var center: Vector3 = room["center"]
	var size: Vector3 = room["size"]
	var doors: Array = room["doors"]
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	# Floor, ceiling, ceiling ribs.
	_kit.box(Vector3(size.x + 1.2, 0.4, size.z + 1.2), center + Vector3(0.0, -0.2, 0.0), &"floor")
	_kit.box(Vector3(size.x + 1.2, 0.4, size.z + 1.2), center + Vector3(0.0, ROOM_HEIGHT + 0.2, 0.0), &"wall")
	for rib in 3:
		var rx := center.x - size.x * 0.3 + float(rib) * size.x * 0.3
		_kit.box(Vector3(0.28, 0.2, size.z), Vector3(rx, ROOM_HEIGHT - 0.12, center.z), &"trim", Vector3.ZERO, false)
	# Four walls with optional 4.5m doorways.
	for side in 4:
		_build_wall(center, size, side, bool(doors[side]), ROOM_HEIGHT, &"wall")
	# Corner pillars for readable silhouettes.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_kit.box(Vector3(0.7, ROOM_HEIGHT, 0.7), center + Vector3(sx * (half_x - 0.2), ROOM_HEIGHT * 0.5, sz * (half_z - 0.2)), &"trim")
	# Emissive floor strips.
	for strip in 2:
		var offset := -half_z * 0.45 + float(strip) * half_z * 0.9
		_kit.box(Vector3(size.x * 0.55, 0.06, 0.16), center + Vector3(0.0, 0.02, offset), &"glow", Vector3.ZERO, false)
	# Boss room: raised dais + cover.
	if bool(room["boss"]):
		_kit.cylinder(size.x * 0.28, size.x * 0.32, 0.5, 12, center + Vector3(0.0, 0.25, 0.0), &"trim")
		_kit.box(Vector3(3.0, 1.2, 3.0), center + Vector3(size.x * 0.3, 0.6, -size.z * 0.3), &"dark")
		_kit.box(Vector3(3.0, 1.2, 3.0), center + Vector3(-size.x * 0.3, 0.6, size.z * 0.3), &"dark")
	else:
		_kit.box(Vector3(2.0, 1.1, 2.0), center + Vector3(half_x * 0.55, 0.55, -half_z * 0.55), &"dark", Vector3(0.0, 0.4, 0.0))
	# Lights.
	var light_color: Color = theme.get("light_color", Color("63b8ff"))
	_add_light(center + Vector3(0.0, ROOM_HEIGHT - 0.6, 0.0), light_color, 1.6, maxf(size.x, size.z) * 0.85)
	# Room marker.
	var marker := Marker3D.new()
	marker.name = "DungeonRoom_%02d" % int(room["index"])
	marker.position = center + Vector3(0.0, 0.1, 0.0)
	add_child(marker)
	if int(room["index"]) == 0:
		var start_marker := Marker3D.new()
		start_marker.name = "DungeonStart"
		start_marker.position = _start_position
		add_child(start_marker)
		var exit_marker := Marker3D.new()
		exit_marker.name = "DungeonExit"
		exit_marker.position = _exit_position + Vector3(0.0, 0.1, 2.0)
		add_child(exit_marker)
	if bool(room["boss"]):
		var boss_marker := Marker3D.new()
		boss_marker.name = "DungeonBoss"
		boss_marker.position = _boss_position
		add_child(boss_marker)
		_add_light(center + Vector3(0.0, 3.0, 0.0), theme.get("accent", Color("c79cff")), 2.4, maxf(size.x, size.z))


func _build_corridor(corridor: Dictionary) -> void:
	var from_center: Vector3 = corridor["from_center"]
	var to_center: Vector3 = corridor["to_center"]
	var axis := String(corridor["axis"])
	var center := (from_center + to_center) * 0.5
	var length := absf(to_center.x - from_center.x) if axis == "x" else absf(to_center.z - from_center.z)
	length = maxf(length, CORRIDOR_WIDTH)
	var size := Vector3(length + 2.0, 0.4, CORRIDOR_WIDTH) if axis == "x" else Vector3(CORRIDOR_WIDTH, 0.4, length + 2.0)
	_kit.box(size, center + Vector3(0.0, -0.2, 0.0), &"floor")
	_kit.box(size, center + Vector3(0.0, CORRIDOR_HEIGHT + 0.2, 0.0), &"wall")
	if axis == "x":
		for side in [-1.0, 1.0]:
			_kit.box(Vector3(length + 2.0, CORRIDOR_HEIGHT, WALL_THICKNESS), center + Vector3(0.0, CORRIDOR_HEIGHT * 0.5, side * CORRIDOR_WIDTH * 0.5), &"wall")
	else:
		for side in [-1.0, 1.0]:
			_kit.box(Vector3(WALL_THICKNESS, CORRIDOR_HEIGHT, length + 2.0), center + Vector3(side * CORRIDOR_WIDTH * 0.5, CORRIDOR_HEIGHT * 0.5, 0.0), &"wall")
	# Ceiling light every ~10m.
	var steps := maxi(1, int(length / 10.0))
	var light_color: Color = theme.get("light_color", Color("63b8ff"))
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var point := from_center.lerp(to_center, t)
		_kit.box(Vector3(0.8, 0.08, 0.8), point + Vector3(0.0, CORRIDOR_HEIGHT - 0.12, 0.0), &"glow", Vector3.ZERO, false)
		if i % 2 == 0:
			_add_light(point + Vector3(0.0, CORRIDOR_HEIGHT - 0.7, 0.0), light_color, 1.0, 9.0)


func _build_wall(center: Vector3, size: Vector3, side: int, has_door: bool, height: float, material: StringName) -> void:
	var wall_len := 0.0
	var pos := Vector3.ZERO
	var wall_size := Vector3.ZERO
	var axis_x := side == 0 or side == 1
	if axis_x:
		wall_len = size.x + WALL_THICKNESS * 2.0
		var z := center.z + (size.z * 0.5 + WALL_THICKNESS * 0.5) if side == 0 else center.z - (size.z * 0.5 + WALL_THICKNESS * 0.5)
		pos = Vector3(center.x, height * 0.5, z)
		wall_size = Vector3(wall_len, height, WALL_THICKNESS)
	else:
		wall_len = size.z + WALL_THICKNESS * 2.0
		var x := center.x + (size.x * 0.5 + WALL_THICKNESS * 0.5) if side == 2 else center.x - (size.x * 0.5 + WALL_THICKNESS * 0.5)
		pos = Vector3(x, height * 0.5, center.z)
		wall_size = Vector3(WALL_THICKNESS, height, wall_len)
	if not has_door:
		_kit.box(wall_size, pos, material)
		return
	var door_w := minf(DOOR_WIDTH, wall_len * 0.62)
	var seg_len := (wall_len - door_w) * 0.5
	for side_sign in [-1.0, 1.0]:
		var offset: float = float(side_sign) * (door_w * 0.5 + seg_len * 0.5)
		var seg_pos := pos
		var seg_size := wall_size
		if axis_x:
			seg_pos.x += offset
			seg_size.x = seg_len
		else:
			seg_pos.z += offset
			seg_size.z = seg_len
		_kit.box(seg_size, seg_pos, material)
	var lintel_h := maxf(0.2, height - DOOR_HEIGHT)
	var lintel_pos := pos
	var lintel_size := wall_size
	lintel_pos.y = DOOR_HEIGHT + lintel_h * 0.5
	if axis_x:
		lintel_size.x = door_w
	else:
		lintel_size.z = door_w
	lintel_size.y = lintel_h
	_kit.box(lintel_size, lintel_pos, material)


func _add_light(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.name = "DungeonLight"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	add_child(light)


func _finalize_geometry() -> void:
	var mesh := _kit.build_mesh()
	if mesh == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DungeonMesh"
	mesh_instance.mesh = mesh
	_root.add_child(mesh_instance)
	var shape := _kit.build_collision_shape()
	if shape != null:
		var body := StaticBody3D.new()
		body.name = "DungeonCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("nav_source")
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = shape
		body.add_child(collision)
		_root.add_child(body)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------
func _build_navigation() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "DungeonNavigation"
	add_child(_nav_region)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 1.0
	nav_mesh.cell_height = 0.5
	nav_mesh.agent_height = 1.9
	nav_mesh.agent_radius = 0.8
	nav_mesh.agent_max_climb = 0.6
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.region_min_size = 4.0
	nav_mesh.edge_max_error = 1.0
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"nav_source"
	nav_mesh.geometry_collision_mask = 1
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	_nav_region.navigation_mesh = nav_mesh


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func get_start_position() -> Vector3:
	return _start_position


func get_exit_position() -> Vector3:
	return _exit_position


func get_boss_position() -> Vector3:
	return _boss_position


func get_room_centers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(_room_centers)
	return out


func get_loot_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(_loot_positions)
	return out


func get_nav_region() -> NavigationRegion3D:
	return _nav_region


func get_bounds() -> AABB:
	return _bounds


func get_theme_id() -> StringName:
	return theme_id


func get_display_name() -> String:
	return display_name


func get_room_count() -> int:
	return _rooms.size()
