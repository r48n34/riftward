class_name EnemyVisuals
extends RefCounted
## Procedural low-poly enemy construction from EnemyData.
## Primitive meshes only (Box/Capsule/Sphere/Cylinder/Prism) at runtime.
## Visual front is -Z so agents can yaw toward their target with look-at math.
## Faction identity: body/cloth colour from EnemyData, emissive accent trim and
## bright emissive eyes/weakpoint cores keep silhouettes readable at range.

## Unscaled (body_scale = 1.0) proportions per EnemyData.style.
## height    : total visual height above the origin (feet / hover plane)
## capsule_h : torso collision capsule height (excludes the weakpoint volume)
## radius    : collision capsule radius
## eye_y     : eye / ray origin height used for line of sight
## weak_y/z/r: weakpoint sphere offset and radius (protrudes outside the capsule)
const STYLE_SPECS := {
	&"humanoid": {
		"height": 1.8, "capsule_h": 1.34, "radius": 0.34,
		"eye_y": 1.52, "weak_y": 1.52, "weak_z": 0.0, "weak_r": 0.2, "hover": 0.0,
	},
	&"heavy": {
		"height": 2.05, "capsule_h": 1.58, "radius": 0.5,
		"eye_y": 1.76, "weak_y": 1.78, "weak_z": -0.02, "weak_r": 0.23, "hover": 0.0,
	},
	&"beast": {
		"height": 1.5, "capsule_h": 0.85, "radius": 0.48,
		"eye_y": 0.6, "weak_y": 0.72, "weak_z": 0.52, "weak_r": 0.24, "hover": 0.0,
	},
	&"flyer": {
		"height": 3.65, "capsule_h": 0.95, "radius": 0.42,
		"eye_y": 2.12, "weak_y": 2.05, "weak_z": -0.45, "weak_r": 0.22, "hover": 2.05,
	},
	&"titan": {
		"height": 2.6, "capsule_h": 1.95, "radius": 0.85,
		"eye_y": 2.12, "weak_y": 2.12, "weak_z": -0.28, "weak_r": 0.3, "hover": 0.0,
	},
}

const FLYER_HOVER := 2.05


static func spec_for(style: StringName) -> Dictionary:
	var spec: Dictionary = STYLE_SPECS.get(style, STYLE_SPECS[&"humanoid"])
	return spec.duplicate()


static func make_material(
	color: Color,
	emission_energy: float = 0.0,
	metallic: float = 0.0,
	roughness: float = 0.7,
	unshaded: bool = false
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _add_mesh(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	mesh: Mesh,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	mesh_scale: Vector3 = Vector3.ONE,
	shadows: bool = true
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	instance.scale = mesh_scale
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	meshes.append(instance)
	return instance


static func _box(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	size: Vector3,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	shadows: bool = true
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(root, meshes, mesh, position, material, rotation, Vector3.ONE, shadows)


static func _sphere(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	mesh_scale: Vector3 = Vector3.ONE,
	shadows: bool = true,
	segments: int = 10
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = maxi(3, segments / 2)
	return _add_mesh(root, meshes, mesh, position, material, Vector3.ZERO, mesh_scale, shadows)


static func _cylinder(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	top_radius: float,
	bottom_radius: float,
	height: float,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	segments: int = 8,
	shadows: bool = true
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add_mesh(root, meshes, mesh, position, material, rotation, Vector3.ONE, shadows)


static func _prism(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	size: Vector3,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	shadows: bool = true
) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = 0.5
	return _add_mesh(root, meshes, mesh, position, material, rotation, Vector3.ONE, shadows)


## Builds the whole visual body and collision proportions for one agent.
## Returns a dictionary consumed by EnemyAgent:
##   root (Node3D visuals container), meshes, flash material, muzzle Marker3D,
##   body_scale, height, capsule_h, radius, eye_y, hover, weak_local, weak_radius.
static func build(data: EnemyData, agent: Node3D) -> Dictionary:
	var body_scale := maxf(0.35, data.body_scale)
	var style: StringName = data.style
	var spec := spec_for(style)

	var body_mat := make_material(data.body_color.darkened(0.16), 0.0, 0.15, 0.68)
	var limb_mat := make_material(data.body_color.darkened(0.34), 0.0, 0.1, 0.78)
	var trim_mat := make_material(data.body_color.lightened(0.1), 0.0, 0.55, 0.38)
	var accent_mat := make_material(data.accent_color, 1.15, 0.35, 0.4)
	var eye_mat := make_material(data.eye_color, 3.8, 0.0, 0.3, true)
	var glow_mat := make_material(data.accent_color.lightened(0.15), 2.4, 0.0, 0.3, true)
	var flash_mat := make_material(Color(1.0, 0.93, 0.82, 0.0), 0.0, 0.0, 1.0, true)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var root := Node3D.new()
	root.name = "Visuals"
	agent.add_child(root)
	root.scale = Vector3.ONE * body_scale

	var meshes: Array[MeshInstance3D] = []
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	root.add_child(muzzle)
	muzzle.position = Vector3(0.0, 1.0, -0.7)

	match style:
		&"heavy":
			_build_heavy(root, meshes, muzzle, data, body_mat, limb_mat, trim_mat, accent_mat, eye_mat, glow_mat)
		&"beast":
			_build_beast(root, meshes, muzzle, data, body_mat, limb_mat, trim_mat, accent_mat, eye_mat, glow_mat)
		&"flyer":
			_build_flyer(root, meshes, muzzle, data, body_mat, limb_mat, trim_mat, accent_mat, eye_mat, glow_mat)
		&"titan":
			_build_titan(root, meshes, muzzle, data, body_mat, trim_mat, accent_mat, eye_mat, glow_mat)
		_:
			_build_humanoid(root, meshes, muzzle, data, body_mat, limb_mat, trim_mat, accent_mat, eye_mat, glow_mat)

	for mesh_instance in meshes:
		mesh_instance.material_overlay = flash_mat

	return {
		"root": root,
		"meshes": meshes,
		"flash": flash_mat,
		"eye_material": eye_mat,
		"accent_material": accent_mat,
		"glow_material": glow_mat,
		"muzzle": muzzle,
		"body_scale": body_scale,
		"height": float(spec.height) * body_scale,
		"capsule_h": float(spec.capsule_h) * body_scale,
		"radius": float(spec.radius) * body_scale,
		"eye_y": float(spec.eye_y) * body_scale,
		"hover": float(spec.hover) * body_scale,
		"weak_local": Vector3(0.0, float(spec.weak_y), float(spec.weak_z)) * body_scale,
		"weak_radius": float(spec.weak_r) * body_scale,
	}


# ---------------------------------------------------------------------------
# Style builders (all coordinates unscaled; root.scale applies body_scale)
# ---------------------------------------------------------------------------

static func _build_humanoid(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	muzzle: Marker3D,
	data: EnemyData,
	body_mat: Material,
	limb_mat: Material,
	trim_mat: Material,
	accent_mat: Material,
	eye_mat: Material,
	glow_mat: Material
) -> void:
	# Legs and boots.
	_box(root, meshes, Vector3(0.17, 0.62, 0.2), Vector3(-0.14, 0.35, 0.0), limb_mat)
	_box(root, meshes, Vector3(0.17, 0.62, 0.2), Vector3(0.14, 0.35, 0.0), limb_mat)
	_box(root, meshes, Vector3(0.19, 0.12, 0.27), Vector3(-0.14, 0.07, -0.04), trim_mat)
	_box(root, meshes, Vector3(0.19, 0.12, 0.27), Vector3(0.14, 0.07, -0.04), trim_mat)
	# Hips and torso.
	_box(root, meshes, Vector3(0.44, 0.2, 0.3), Vector3(0.0, 0.74, 0.0), body_mat)
	_box(root, meshes, Vector3(0.6, 0.62, 0.34), Vector3(0.0, 1.08, 0.0), body_mat)
	# Chest plate + emissive trim.
	_box(root, meshes, Vector3(0.52, 0.26, 0.1), Vector3(0.0, 1.2, -0.2), trim_mat)
	_box(root, meshes, Vector3(0.08, 0.2, 0.02), Vector3(0.0, 1.2, -0.26), accent_mat, Vector3.ZERO, false)
	# Shoulder pads.
	_box(root, meshes, Vector3(0.24, 0.13, 0.27), Vector3(-0.37, 1.34, 0.0), trim_mat)
	_box(root, meshes, Vector3(0.24, 0.13, 0.27), Vector3(0.37, 1.34, 0.0), trim_mat)
	# Arms.
	_box(root, meshes, Vector3(0.13, 0.52, 0.16), Vector3(-0.38, 1.05, 0.0), limb_mat, Vector3(0.0, 0.0, 0.08))
	_box(root, meshes, Vector3(0.13, 0.52, 0.16), Vector3(0.38, 1.05, 0.0), limb_mat, Vector3(0.0, 0.0, -0.08))
	# Neck and head.
	_cylinder(root, meshes, 0.07, 0.08, 0.12, Vector3(0.0, 1.42, 0.0), limb_mat, Vector3.ZERO, 6)
	_box(root, meshes, Vector3(0.25, 0.25, 0.25), Vector3(0.0, 1.54, 0.0), body_mat)
	# Visor: the humanoid weakpoint is the head, so it glows brightly.
	_box(root, meshes, Vector3(0.2, 0.06, 0.03), Vector3(0.0, 1.55, -0.13), eye_mat, Vector3.ZERO, false)
	# Backpack with vents.
	_box(root, meshes, Vector3(0.32, 0.34, 0.14), Vector3(0.0, 1.1, 0.24), trim_mat)
	_box(root, meshes, Vector3(0.06, 0.22, 0.03), Vector3(-0.08, 1.12, 0.315), glow_mat, Vector3.ZERO, false)
	_box(root, meshes, Vector3(0.06, 0.22, 0.03), Vector3(0.08, 1.12, 0.315), glow_mat, Vector3.ZERO, false)
	# Weapon depends on role.
	var muzzle_pos := Vector3(0.33, 1.02, -0.66)
	var barrel_len := 0.62
	if data.role == &"marksman":
		barrel_len = 0.95
		muzzle_pos = Vector3(0.33, 1.02, -0.98)
	elif data.role == &"support":
		barrel_len = 0.5
		muzzle_pos = Vector3(0.33, 1.05, -0.5)
	_box(root, meshes, Vector3(0.07, 0.11, 0.3), Vector3(0.33, 1.0, -0.18), trim_mat)
	_box(root, meshes, Vector3(0.05, 0.05, barrel_len), Vector3(0.33, 1.03, -0.32 - barrel_len * 0.5), limb_mat)
	_cylinder(root, meshes, 0.04, 0.04, 0.12, Vector3(0.33, 1.03, -0.32 - barrel_len - 0.04), accent_mat, Vector3(1.57, 0.0, 0.0), 6, false)
	if data.role == &"tank":
		_box(root, meshes, Vector3(0.1, 0.72, 0.46), Vector3(-0.5, 1.0, -0.06), trim_mat, Vector3(0.0, 0.0, 0.06))
		_box(root, meshes, Vector3(0.03, 0.52, 0.34), Vector3(-0.56, 1.0, -0.06), accent_mat, Vector3(0.0, 0.0, 0.06), false)
	elif data.role == &"support":
		_box(root, meshes, Vector3(0.26, 0.4, 0.12), Vector3(-0.3, 1.16, 0.3), glow_mat, Vector3.ZERO, false)
	muzzle.position = muzzle_pos


static func _build_heavy(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	muzzle: Marker3D,
	data: EnemyData,
	body_mat: Material,
	limb_mat: Material,
	trim_mat: Material,
	accent_mat: Material,
	eye_mat: Material,
	glow_mat: Material
) -> void:
	# Wide legs and slab boots.
	_box(root, meshes, Vector3(0.26, 0.78, 0.28), Vector3(-0.22, 0.44, 0.0), limb_mat)
	_box(root, meshes, Vector3(0.26, 0.78, 0.28), Vector3(0.22, 0.44, 0.0), limb_mat)
	_box(root, meshes, Vector3(0.3, 0.14, 0.38), Vector3(-0.22, 0.08, -0.05), trim_mat)
	_box(root, meshes, Vector3(0.3, 0.14, 0.38), Vector3(0.22, 0.08, -0.05), trim_mat)
	# Hips and broad chest.
	_box(root, meshes, Vector3(0.62, 0.26, 0.4), Vector3(0.0, 0.9, 0.0), trim_mat)
	_box(root, meshes, Vector3(0.86, 0.68, 0.52), Vector3(0.0, 1.3, 0.0), body_mat)
	_box(root, meshes, Vector3(0.7, 0.32, 0.12), Vector3(0.0, 1.42, -0.31), trim_mat)
	_box(root, meshes, Vector3(0.12, 0.24, 0.03), Vector3(0.0, 1.42, -0.38), accent_mat, Vector3.ZERO, false)
	# Shoulder towers.
	_box(root, meshes, Vector3(0.34, 0.3, 0.42), Vector3(-0.58, 1.62, 0.0), trim_mat, Vector3(0.0, 0.0, 0.18))
	_box(root, meshes, Vector3(0.34, 0.3, 0.42), Vector3(0.58, 1.62, 0.0), trim_mat, Vector3(0.0, 0.0, -0.18))
	_prism(root, meshes, Vector3(0.22, 0.3, 0.34), Vector3(-0.62, 1.85, 0.02), accent_mat, Vector3(0.0, 0.0, 0.3), false)
	_prism(root, meshes, Vector3(0.22, 0.3, 0.34), Vector3(0.62, 1.85, 0.02), accent_mat, Vector3(0.0, 0.0, -0.3), false)
	# Arms and gauntlets.
	_box(root, meshes, Vector3(0.24, 0.72, 0.26), Vector3(-0.62, 1.12, 0.0), limb_mat, Vector3(0.0, 0.0, 0.06))
	_box(root, meshes, Vector3(0.24, 0.72, 0.26), Vector3(0.62, 1.12, 0.0), limb_mat, Vector3(0.0, 0.0, -0.06))
	_box(root, meshes, Vector3(0.3, 0.28, 0.34), Vector3(0.62, 0.78, -0.06), trim_mat)
	# Sunken head and wide eye bar.
	_box(root, meshes, Vector3(0.34, 0.3, 0.32), Vector3(0.0, 1.78, -0.02), body_mat)
	_box(root, meshes, Vector3(0.3, 0.06, 0.04), Vector3(0.0, 1.8, -0.19), eye_mat, Vector3.ZERO, false)
	# Reactor hump.
	_box(root, meshes, Vector3(0.44, 0.4, 0.2), Vector3(0.0, 1.42, 0.36), trim_mat)
	_box(root, meshes, Vector3(0.28, 0.12, 0.04), Vector3(0.0, 1.44, 0.47), glow_mat, Vector3.ZERO, false)
	# Cannon arm.
	_box(root, meshes, Vector3(0.16, 0.16, 0.5), Vector3(0.62, 0.92, -0.32), trim_mat)
	_box(root, meshes, Vector3(0.1, 0.1, 0.42), Vector3(0.62, 0.92, -0.76), limb_mat)
	muzzle.position = Vector3(0.62, 0.92, -1.0)
	if data.role == &"elite" or data.elite:
		_box(root, meshes, Vector3(0.06, 0.5, 0.5), Vector3(-0.78, 1.32, -0.03), accent_mat, Vector3.ZERO, false)


static func _build_beast(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	muzzle: Marker3D,
	data: EnemyData,
	body_mat: Material,
	limb_mat: Material,
	trim_mat: Material,
	accent_mat: Material,
	eye_mat: Material,
	glow_mat: Material
) -> void:
	# Ellipsoid body.
	_sphere(root, meshes, 0.5, 1.0, Vector3(0.0, 0.55, 0.05), body_mat, Vector3(1.0, 0.72, 1.42))
	# Carapace plates.
	_prism(root, meshes, Vector3(0.74, 0.42, 0.62), Vector3(0.0, 0.82, 0.16), trim_mat, Vector3(0.5, 0.0, 0.0))
	_prism(root, meshes, Vector3(0.5, 0.28, 0.44), Vector3(0.0, 0.9, 0.42), trim_mat, Vector3(0.62, 0.0, 0.0))
	# Head and jaw.
	_sphere(root, meshes, 0.26, 0.46, Vector3(0.0, 0.62, -0.62), body_mat, Vector3(1.0, 0.85, 1.1))
	_box(root, meshes, Vector3(0.3, 0.1, 0.34), Vector3(0.0, 0.46, -0.66), limb_mat)
	# Eyes.
	_sphere(root, meshes, 0.055, 0.11, Vector3(-0.13, 0.68, -0.79), eye_mat, Vector3.ONE, false, 6)
	_sphere(root, meshes, 0.055, 0.11, Vector3(0.13, 0.68, -0.79), eye_mat, Vector3.ONE, false, 6)
	# Four legs.
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			_cylinder(
				root, meshes, 0.065, 0.09, 0.62,
				Vector3(0.3 * side, 0.26, 0.26 * front), limb_mat,
				Vector3(0.22 * front, 0.0, -0.3 * side), 6
			)
	# Back spikes.
	_prism(root, meshes, Vector3(0.14, 0.42, 0.16), Vector3(0.0, 1.02, -0.12), accent_mat, Vector3(0.32, 0.0, 0.0), false)
	_prism(root, meshes, Vector3(0.12, 0.34, 0.14), Vector3(0.0, 1.08, 0.22), glow_mat, Vector3(0.45, 0.0, 0.0), false)
	# Exposed glowing core on the back: the beast weakpoint.
	_sphere(root, meshes, 0.2, 0.4, Vector3(0.0, 0.72, 0.52), glow_mat, Vector3.ONE, false, 8)
	_box(root, meshes, Vector3(0.3, 0.06, 0.16), Vector3(0.0, 0.9, 0.5), accent_mat, Vector3.ZERO, false)
	# Spitter pod / matriarch bloom sac.
	if data.role == &"support" or data.role == &"elite" or data.boss:
		_sphere(root, meshes, 0.2, 0.42, Vector3(0.0, 1.02, 0.28), accent_mat, Vector3(1.0, 0.7, 1.0), false, 8)
		_sphere(root, meshes, 0.1, 0.2, Vector3(-0.22, 0.9, 0.42), glow_mat, Vector3.ONE, false, 6)
		_sphere(root, meshes, 0.1, 0.2, Vector3(0.22, 0.9, 0.42), glow_mat, Vector3.ONE, false, 6)
	muzzle.position = Vector3(0.0, 0.6, -0.92)


static func _build_flyer(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	muzzle: Marker3D,
	data: EnemyData,
	body_mat: Material,
	limb_mat: Material,
	trim_mat: Material,
	accent_mat: Material,
	eye_mat: Material,
	glow_mat: Material
) -> void:
	var hover := FLYER_HOVER
	# Core body floating at hover height.
	_sphere(root, meshes, 0.42, 0.8, Vector3(0.0, hover, 0.0), body_mat, Vector3(1.0, 0.72, 1.12))
	# Canopy / forehead shell.
	_sphere(root, meshes, 0.28, 0.52, Vector3(0.0, hover + 0.2, 0.06), trim_mat, Vector3(1.0, 0.6, 1.0))
	# Swept wings (prisms read as hard sci-fi fins).
	_prism(root, meshes, Vector3(1.15, 0.06, 0.44), Vector3(-0.62, hover + 0.05, 0.1), limb_mat, Vector3(0.0, 0.25, 0.3))
	_prism(root, meshes, Vector3(1.15, 0.06, 0.44), Vector3(0.62, hover + 0.05, 0.1), limb_mat, Vector3(0.0, -0.25, -0.3))
	_sphere(root, meshes, 0.09, 0.18, Vector3(-1.14, hover + 0.16, 0.2), accent_mat, Vector3.ONE, false, 6)
	_sphere(root, meshes, 0.09, 0.18, Vector3(1.14, hover + 0.16, 0.2), accent_mat, Vector3.ONE, false, 6)
	# Tri-eye sensor cluster facing forward (-Z).
	_sphere(root, meshes, 0.06, 0.12, Vector3(0.0, hover + 0.04, -0.44), eye_mat, Vector3.ONE, false, 6)
	_sphere(root, meshes, 0.045, 0.09, Vector3(-0.15, hover + 0.02, -0.4), eye_mat, Vector3.ONE, false, 6)
	_sphere(root, meshes, 0.045, 0.09, Vector3(0.15, hover + 0.02, -0.4), eye_mat, Vector3.ONE, false, 6)
	# Halo and under-glow.
	_cylinder(root, meshes, 0.34, 0.34, 0.035, Vector3(0.0, hover + 0.38, 0.0), accent_mat, Vector3.ZERO, 10, false)
	_sphere(root, meshes, 0.16, 0.32, Vector3(0.0, hover - 0.32, 0.0), glow_mat, Vector3.ONE, false, 8)
	# Chest weakpoint core.
	_sphere(root, meshes, 0.18, 0.36, Vector3(0.0, hover - 0.02, -0.45), glow_mat, Vector3.ONE, false, 8)
	# Hanging finials for silhouette.
	_prism(root, meshes, Vector3(0.14, 0.5, 0.16), Vector3(0.0, hover - 0.5, 0.28), trim_mat, Vector3(0.35, 0.0, 0.0))
	_prism(root, meshes, Vector3(0.1, 0.36, 0.12), Vector3(-0.2, hover - 0.42, 0.26), accent_mat, Vector3(0.3, 0.0, 0.15), false)
	muzzle.position = Vector3(0.0, hover - 0.02, -0.62)


static func _build_titan(
	root: Node3D,
	meshes: Array[MeshInstance3D],
	muzzle: Marker3D,
	data: EnemyData,
	body_mat: Material,
	trim_mat: Material,
	accent_mat: Material,
	eye_mat: Material,
	glow_mat: Material
) -> void:
	# Legs and feet.
	_box(root, meshes, Vector3(0.36, 1.04, 0.42), Vector3(-0.4, 0.56, 0.0), trim_mat)
	_box(root, meshes, Vector3(0.36, 1.04, 0.42), Vector3(0.4, 0.56, 0.0), trim_mat)
	_box(root, meshes, Vector3(0.42, 0.18, 0.54), Vector3(-0.4, 0.09, -0.06), body_mat)
	_box(root, meshes, Vector3(0.42, 0.18, 0.54), Vector3(0.4, 0.09, -0.06), body_mat)
	# Hips and tapered torso.
	_box(root, meshes, Vector3(1.02, 0.34, 0.62), Vector3(0.0, 1.16, 0.0), trim_mat)
	_box(root, meshes, Vector3(1.24, 0.98, 0.72), Vector3(0.0, 1.76, 0.0), body_mat)
	_box(root, meshes, Vector3(0.42, 0.5, 0.16), Vector3(0.0, 1.66, -0.4), trim_mat)
	# Chest core.
	_sphere(root, meshes, 0.3, 0.6, Vector3(0.0, 1.7, -0.42), glow_mat, Vector3.ONE, false, 10)
	_box(root, meshes, Vector3(1.0, 0.06, 0.04), Vector3(0.0, 1.96, -0.38), accent_mat, Vector3.ZERO, false)
	# Shoulder towers and fins.
	_box(root, meshes, Vector3(0.5, 0.62, 0.6), Vector3(-0.84, 2.02, 0.0), trim_mat)
	_box(root, meshes, Vector3(0.5, 0.62, 0.6), Vector3(0.84, 2.02, 0.0), trim_mat)
	_prism(root, meshes, Vector3(0.26, 0.6, 0.46), Vector3(-0.9, 2.44, 0.04), accent_mat, Vector3(0.0, 0.0, 0.26), false)
	_prism(root, meshes, Vector3(0.26, 0.6, 0.46), Vector3(0.9, 2.44, 0.04), accent_mat, Vector3(0.0, 0.0, -0.26), false)
	# Arms.
	_box(root, meshes, Vector3(0.3, 0.98, 0.34), Vector3(-0.88, 1.4, 0.0), body_mat, Vector3(0.0, 0.0, 0.05))
	_box(root, meshes, Vector3(0.3, 0.98, 0.34), Vector3(0.88, 1.4, 0.0), body_mat, Vector3(0.0, 0.0, -0.05))
	_box(root, meshes, Vector3(0.34, 0.3, 0.4), Vector3(0.88, 0.9, -0.08), trim_mat)
	# Head and crown.
	_box(root, meshes, Vector3(0.52, 0.42, 0.46), Vector3(0.0, 2.16, -0.02), body_mat)
	_box(root, meshes, Vector3(0.46, 0.1, 0.05), Vector3(0.0, 2.18, -0.26), eye_mat, Vector3.ZERO, false)
	for i in 3:
		_prism(
			root, meshes, Vector3(0.12, 0.48 - i * 0.1, 0.2),
			Vector3(-0.24 + i * 0.24, 2.48 - i * 0.04, 0.02), accent_mat,
			Vector3(0.0, 0.0, -0.18 + i * 0.18), false
		)
	# Back vents.
	_box(root, meshes, Vector3(0.7, 0.1, 0.06), Vector3(0.0, 1.62, 0.4), glow_mat, Vector3.ZERO, false)
	_box(root, meshes, Vector3(0.7, 0.1, 0.06), Vector3(0.0, 1.82, 0.4), glow_mat, Vector3.ZERO, false)
	# Siege cannon.
	_box(root, meshes, Vector3(0.24, 0.26, 1.3), Vector3(0.86, 1.42, -0.52), trim_mat)
	_cylinder(root, meshes, 0.13, 0.15, 0.3, Vector3(0.86, 1.42, -1.28), accent_mat, Vector3(1.57, 0.0, 0.0), 8, false)
	muzzle.position = Vector3(0.86, 1.42, -1.5)
