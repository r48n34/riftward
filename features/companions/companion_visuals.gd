class_name CompanionVisuals
extends RefCounted
## Procedural low-poly visual kits for friendly Wardens and Driftling pets.
## Everything is built from engine primitives (no external meshes/textures) so
## companions read as charming, colour-coded characters instead of grey capsules.
## Silhouettes carry role identity; mint emissive accents always mark them as
## friendly to the player.

const MINT := Color("62e6c3")
const IVORY := Color("f4efe5")
const INK := Color("121a1d")
const AMBER := Color("ffb866")
const BLUE := Color("6fa8ff")
const VIOLET := Color("c79cff")


# ---------------------------------------------------------------------------
# Material helpers
# ---------------------------------------------------------------------------

static func metal(color: Color, metallic: float = 0.15, roughness: float = 0.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func cloth(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.92
	return mat


static func emissive(color: Color, energy: float = 2.4, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func billboard_glow(color: Color, energy: float = 2.6) -> StandardMaterial3D:
	var mat := emissive(color, energy, 0.92)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	return mat


# ---------------------------------------------------------------------------
# Primitive helpers (all return the created MeshInstance3D)
# ---------------------------------------------------------------------------

static func add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	material: Material,
	rot_deg: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	parent.add_child(instance)
	return instance


static func add_sphere(
	parent: Node3D,
	radius: float,
	pos: Vector3,
	material: Material,
	scale_value: Vector3 = Vector3.ONE,
	segments: int = 10
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(3, segments / 2)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


static func add_cylinder(
	parent: Node3D,
	top_radius: float,
	bottom_radius: float,
	height: float,
	pos: Vector3,
	material: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	segments: int = 8
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	parent.add_child(instance)
	return instance


static func add_cone(
	parent: Node3D,
	radius: float,
	height: float,
	pos: Vector3,
	material: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	segments: int = 8
) -> MeshInstance3D:
	return add_cylinder(parent, 0.0, radius, height, pos, material, rot_deg, segments)


static func add_torus(
	parent: Node3D,
	inner_radius: float,
	outer_radius: float,
	pos: Vector3,
	material: Material,
	rot_deg: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	parent.add_child(instance)
	return instance


# ---------------------------------------------------------------------------
# Warden (ally) kit
# ---------------------------------------------------------------------------

## Builds a friendly Warden rig. The returned Dictionary contains the node refs
## the agent needs for procedural animation/aiming:
##   root, visual, hips, head, leg_l, leg_r, arm_l, arm_r, arm_l_base,
##   arm_r_base, weapon_pivot, muzzle, marker, marker_base_y, nameplate, light
static func build_warden(data: AllyData, weapon_data: WeaponData) -> Dictionary:
	var role: StringName = data.role if data != null else &"medic"
	var display_name: String = data.display_name if data != null else "Warden"
	var primary: Color = data.color if data != null else MINT

	var role_scale := 1.0
	match role:
		&"heavy":
			role_scale = 1.13
		&"scout":
			role_scale = 0.94
		&"engineer":
			role_scale = 1.02

	var suit := metal(primary.darkened(0.3), 0.12, 0.72)
	var suit_light := cloth(primary.lightened(0.34))
	var suit_dark := metal(INK.lerp(primary, 0.22), 0.28, 0.55)
	var trim := emissive(primary.lightened(0.12), 1.8)
	var mint := emissive(MINT, 2.2)
	var visor := emissive(MINT.lerp(Color.WHITE, 0.35), 2.8)

	var root := Node3D.new()
	root.name = "CompanionVisual"
	var visual := Node3D.new()
	visual.name = "Rig"
	visual.scale = Vector3.ONE * role_scale
	root.add_child(visual)

	# --- legs -------------------------------------------------------------
	var leg_l := Node3D.new()
	leg_l.name = "LegL"
	leg_l.position = Vector3(-0.15, 0.92, 0.0)
	visual.add_child(leg_l)
	add_box(leg_l, Vector3(0.17, 0.74, 0.19), Vector3(0.0, -0.37, 0.0), suit_dark)
	add_box(leg_l, Vector3(0.21, 0.14, 0.32), Vector3(0.0, -0.75, -0.05), suit_dark)
	add_box(leg_l, Vector3(0.2, 0.06, 0.1), Vector3(0.0, -0.68, -0.13), trim)

	var leg_r := Node3D.new()
	leg_r.name = "LegR"
	leg_r.position = Vector3(0.15, 0.92, 0.0)
	visual.add_child(leg_r)
	add_box(leg_r, Vector3(0.17, 0.74, 0.19), Vector3(0.0, -0.37, 0.0), suit_dark)
	add_box(leg_r, Vector3(0.21, 0.14, 0.32), Vector3(0.0, -0.75, -0.05), suit_dark)
	add_box(leg_r, Vector3(0.2, 0.06, 0.1), Vector3(0.0, -0.68, -0.13), trim)

	# --- hips / torso -----------------------------------------------------
	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 0.95, 0.0)
	visual.add_child(hips)

	add_box(hips, Vector3(0.38, 0.2, 0.26), Vector3(0.0, 0.02, 0.0), suit_dark)
	add_box(hips, Vector3(0.48, 0.52, 0.3), Vector3(0.0, 0.35, 0.0), suit)
	add_box(hips, Vector3(0.36, 0.24, 0.06), Vector3(0.0, 0.38, -0.17), suit_light)
	# Friendly mint core on every Warden (readability).
	add_box(hips, Vector3(0.11, 0.11, 0.05), Vector3(0.0, 0.42, -0.2), mint, Vector3(0.0, 0.0, 45.0))
	add_box(hips, Vector3(0.5, 0.05, 0.31), Vector3(0.0, 0.11, 0.0), trim)

	# --- head -------------------------------------------------------------
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.84, 0.0)
	hips.add_child(head)
	add_box(head, Vector3(0.3, 0.3, 0.3), Vector3.ZERO, suit_light)
	add_box(head, Vector3(0.22, 0.09, 0.05), Vector3(0.0, 0.02, -0.16), visor)
	add_box(head, Vector3(0.18, 0.1, 0.08), Vector3(0.0, -0.15, -0.12), suit_dark)
	add_box(head, Vector3(0.315, 0.07, 0.315), Vector3(0.0, 0.13, 0.0), suit)

	# --- arms -------------------------------------------------------------
	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	arm_l.position = Vector3(-0.3, 0.56, 0.0)
	arm_l.rotation_degrees = Vector3(-52.0, 8.0, 12.0)
	hips.add_child(arm_l)
	add_box(arm_l, Vector3(0.13, 0.36, 0.14), Vector3(0.0, -0.17, 0.0), suit)
	add_box(arm_l, Vector3(0.12, 0.12, 0.19), Vector3(0.0, -0.36, -0.04), suit_dark)

	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	arm_r.position = Vector3(0.3, 0.56, 0.0)
	arm_r.rotation_degrees = Vector3(-46.0, -10.0, -12.0)
	hips.add_child(arm_r)
	add_box(arm_r, Vector3(0.13, 0.36, 0.14), Vector3(0.0, -0.17, 0.0), suit)
	add_box(arm_r, Vector3(0.12, 0.12, 0.19), Vector3(0.0, -0.36, -0.04), suit_dark)

	var arm_l_base := arm_l.rotation
	var arm_r_base := arm_r.rotation

	# --- role-specific silhouette ----------------------------------------
	match role:
		&"medic":
			# Ivory coat skirt + halo + medical cross: the "keep you alive" read.
			add_cylinder(hips, 0.26, 0.42, 0.62, Vector3(0.0, -0.28, 0.0), cloth(IVORY.darkened(0.08)), Vector3.ZERO, 10)
			add_box(hips, Vector3(0.34, 0.06, 0.34), Vector3(0.0, -0.02, 0.0), trim)
			add_torus(head, 0.2, 0.26, Vector3(0.0, 0.26, 0.04), emissive(MINT, 1.5, 0.85), Vector3(90.0, 0.0, 0.0))
			add_box(head, Vector3(0.06, 0.2, 0.42), Vector3(0.0, 0.13, 0.04), mint)
			# Backpack + mint cross.
			add_box(hips, Vector3(0.34, 0.36, 0.16), Vector3(0.0, 0.34, 0.24), suit_dark)
			add_box(hips, Vector3(0.05, 0.2, 0.04), Vector3(0.0, 0.36, 0.33), mint)
			add_box(hips, Vector3(0.16, 0.05, 0.04), Vector3(0.0, 0.36, 0.33), mint)
			add_box(hips, Vector3(0.36, 0.06, 0.18), Vector3(0.0, 0.19, 0.24), suit_light)
		&"heavy":
			# Broad pauldrons + ammo belt: the "walking wall" read.
			add_sphere(hips, 0.17, Vector3(-0.34, 0.58, 0.0), metal(primary, 0.35, 0.4), Vector3(1.1, 0.9, 1.1))
			add_sphere(hips, 0.17, Vector3(0.34, 0.58, 0.0), metal(primary, 0.35, 0.4), Vector3(1.1, 0.9, 1.1))
			add_box(hips, Vector3(0.5, 0.16, 0.34), Vector3(0.0, 0.62, 0.0), suit_dark)
			add_box(hips, Vector3(0.2, 0.1, 0.05), Vector3(0.0, 0.62, -0.18), trim)
			add_box(head, Vector3(0.36, 0.08, 0.1), Vector3(0.0, 0.16, -0.06), metal(AMBER, 0.3, 0.4))
			add_box(head, Vector3(0.05, 0.05, 0.05), Vector3(0.2, 0.18, 0.0), emissive(AMBER, 2.0))
			add_box(hips, Vector3(0.56, 0.52, 0.18), Vector3(0.0, 0.32, 0.26), suit_dark)
			add_box(hips, Vector3(0.18, 0.2, 0.22), Vector3(-0.3, 0.24, 0.3), suit_dark)
			add_box(hips, Vector3(0.18, 0.2, 0.22), Vector3(0.3, 0.24, 0.3), suit_dark)
			add_box(hips, Vector3(0.3, 0.08, 0.12), Vector3(0.0, 0.08, 0.2), trim)
			add_box(head, Vector3(0.08, 0.18, 0.08), Vector3(-0.16, 0.24, 0.0), suit)
		&"scout":
			# Hood, cape, antenna: lean forward, see everything.
			add_cone(head, 0.28, 0.34, Vector3(0.0, 0.18, 0.02), cloth(primary.darkened(0.2)), Vector3.ZERO, 8)
			add_box(head, Vector3(0.24, 0.05, 0.05), Vector3(0.0, 0.02, -0.17), emissive(BLUE, 2.6))
			add_box(head, Vector3(0.03, 0.28, 0.03), Vector3(0.18, 0.22, 0.02), suit_dark)
			add_box(head, Vector3(0.05, 0.05, 0.05), Vector3(0.18, 0.38, 0.02), emissive(BLUE, 2.4))
			add_box(hips, Vector3(0.42, 0.72, 0.05), Vector3(0.0, 0.05, 0.22), cloth(primary.darkened(0.36)), Vector3(-6.0, 0.0, 0.0))
			add_box(hips, Vector3(0.26, 0.3, 0.14), Vector3(0.0, 0.34, 0.22), suit_dark)
			add_box(hips, Vector3(0.05, 0.18, 0.05), Vector3(-0.12, 0.5, 0.2), trim)
			add_box(hips, Vector3(0.05, 0.1, 0.05), Vector3(0.12, 0.5, 0.2), trim)
		&"engineer":
			# Reactor backpack + shoulder pod: the "keeps the lights on" read.
			add_box(hips, Vector3(0.4, 0.44, 0.18), Vector3(0.0, 0.34, 0.25), suit_dark)
			add_sphere(hips, 0.12, Vector3(0.0, 0.4, 0.35), emissive(VIOLET, 2.6), Vector3.ONE, 8)
			add_torus(hips, 0.14, 0.19, Vector3(0.0, 0.4, 0.35), emissive(VIOLET, 1.6), Vector3(90.0, 0.0, 0.0))
			add_box(hips, Vector3(0.04, 0.36, 0.04), Vector3(0.16, 0.6, 0.24), suit_dark)
			add_box(hips, Vector3(0.06, 0.06, 0.06), Vector3(0.16, 0.79, 0.24), emissive(VIOLET, 2.4))
			add_box(hips, Vector3(0.2, 0.22, 0.2), Vector3(-0.26, 0.56, 0.16), suit_dark)
			add_box(hips, Vector3(0.12, 0.06, 0.12), Vector3(-0.26, 0.68, 0.16), trim)
			add_box(head, Vector3(0.1, 0.1, 0.1), Vector3(0.16, 0.02, -0.04), suit_dark)
			add_sphere(head, 0.045, Vector3(0.16, 0.02, -0.1), emissive(VIOLET, 2.6), Vector3.ONE, 6)
		_:
			pass

	# --- weapon -----------------------------------------------------------
	var weapon_pivot := Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0.17, 0.5, -0.2)
	hips.add_child(weapon_pivot)

	var weapon_style := _weapon_style_for(role, weapon_data)
	var weapon_color := IVORY.darkened(0.05)
	if weapon_data != null:
		weapon_color = weapon_data.color.lerp(IVORY, 0.18)
	var weapon_view := build_weapon(weapon_style, weapon_color, primary.lightened(0.15))
	weapon_pivot.add_child(weapon_view)
	var muzzle: Marker3D = null
	if weapon_view.has_node("Muzzle"):
		muzzle = weapon_view.get_node("Muzzle") as Marker3D

	# --- friendly marker + nameplate -------------------------------------
	var marker := Node3D.new()
	marker.name = "FriendlyMarker"
	var marker_base_y := 2.42 * role_scale
	marker.position = Vector3(0.0, marker_base_y, 0.0)
	root.add_child(marker)
	add_torus(marker, 0.1, 0.145, Vector3.ZERO, emissive(MINT, 2.0, 0.9), Vector3(90.0, 0.0, 0.0))
	add_box(marker, Vector3(0.09, 0.09, 0.03), Vector3(0.0, 0.16, 0.0), billboard_glow(MINT.lerp(Color.WHITE, 0.45), 2.6), Vector3(0.0, 0.0, 45.0))

	var nameplate := Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.text = display_name
	nameplate.font_size = 42
	nameplate.outline_size = 10
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.modulate = Color(0.96, 0.94, 0.9, 0.92)
	nameplate.outline_modulate = Color(0.03, 0.05, 0.06, 0.9)
	nameplate.position = Vector3(0.0, marker_base_y + 0.28, 0.0)
	nameplate.visible = false
	root.add_child(nameplate)

	# Chest glow helps companions pop against the terrain.
	var glow := OmniLight3D.new()
	glow.name = "ChestGlow"
	glow.light_color = MINT
	glow.light_energy = 0.45
	glow.omni_range = 2.2
	glow.position = Vector3(0.0, 1.35, -0.1)
	root.add_child(glow)

	return {
		"root": root,
		"visual": visual,
		"hips": hips,
		"head": head,
		"leg_l": leg_l,
		"leg_r": leg_r,
		"arm_l": arm_l,
		"arm_r": arm_r,
		"arm_l_base": arm_l_base,
		"arm_r_base": arm_r_base,
		"weapon_pivot": weapon_pivot,
		"muzzle": muzzle,
		"marker": marker,
		"marker_base_y": marker_base_y,
		"nameplate": nameplate,
		"light": glow,
	}


static func _weapon_style_for(role: StringName, weapon_data: WeaponData) -> String:
	if weapon_data != null:
		var style := String(weapon_data.style)
		if not style.is_empty():
			return style
	match role:
		&"heavy":
			return "lmg"
		&"scout":
			return "dmr"
		&"engineer":
			return "shotgun"
		_:
			return "smg"


## Self-contained low-poly third-person weapon. Returns a Node3D with a
## Marker3D named "Muzzle". Built here rather than reusing WeaponModelBuilder so
## companions never depend on the first-person viewmodel pipeline.
static func build_weapon(style: String, body_color: Color, accent_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponView"
	var gun_metal := metal(body_color.darkened(0.12), 0.45, 0.48)
	var gun_dark := metal(INK, 0.32, 0.5)
	var glow := emissive(accent_color, 2.0)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"

	match style:
		"smg":
			add_box(root, Vector3(0.075, 0.1, 0.3), Vector3(0.0, 0.0, -0.08), gun_metal)
			add_box(root, Vector3(0.055, 0.2, 0.075), Vector3(0.0, -0.14, -0.02), gun_dark)
			add_cylinder(root, 0.022, 0.026, 0.2, Vector3(0.0, 0.02, -0.28), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_box(root, Vector3(0.06, 0.05, 0.18), Vector3(0.0, 0.076, -0.02), glow)
			add_box(root, Vector3(0.05, 0.11, 0.055), Vector3(0.0, -0.09, 0.1), gun_dark)
			muzzle.position = Vector3(0.0, 0.02, -0.41)
		"lmg":
			add_box(root, Vector3(0.11, 0.14, 0.52), Vector3(0.0, 0.0, -0.14), gun_metal)
			add_box(root, Vector3(0.14, 0.16, 0.22), Vector3(0.0, -0.07, 0.02), gun_dark)
			add_cylinder(root, 0.038, 0.042, 0.5, Vector3(0.0, 0.03, -0.45), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_box(root, Vector3(0.025, 0.03, 0.3), Vector3(0.048, 0.08, -0.22), glow)
			add_box(root, Vector3(0.06, 0.16, 0.08), Vector3(0.0, -0.14, 0.08), gun_dark)
			add_box(root, Vector3(0.03, 0.05, 0.2), Vector3(-0.06, 0.0, -0.1), gun_dark)
			muzzle.position = Vector3(0.0, 0.03, -0.72)
		"dmr":
			add_box(root, Vector3(0.07, 0.1, 0.48), Vector3(0.0, 0.0, -0.1), gun_metal)
			add_box(root, Vector3(0.058, 0.14, 0.09), Vector3(0.0, -0.1, 0.02), gun_dark)
			add_cylinder(root, 0.024, 0.028, 0.46, Vector3(0.0, 0.03, -0.42), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_cylinder(root, 0.032, 0.032, 0.16, Vector3(0.0, 0.112, -0.1), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_box(root, Vector3(0.03, 0.03, 0.012), Vector3(0.0, 0.112, -0.2), glow)
			add_box(root, Vector3(0.045, 0.05, 0.16), Vector3(0.0, -0.02, 0.2), gun_metal)
			muzzle.position = Vector3(0.0, 0.03, -0.66)
		"shotgun":
			add_box(root, Vector3(0.085, 0.1, 0.44), Vector3(0.0, 0.01, -0.16), gun_metal)
			add_box(root, Vector3(0.072, 0.09, 0.2), Vector3(0.0, -0.02, 0.12), gun_dark)
			add_cylinder(root, 0.036, 0.04, 0.44, Vector3(0.0, 0.055, -0.38), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_box(root, Vector3(0.06, 0.06, 0.4), Vector3(0.0, -0.06, -0.2), gun_dark)
			add_box(root, Vector3(0.022, 0.022, 0.34), Vector3(0.0, 0.09, -0.24), glow)
			muzzle.position = Vector3(0.0, 0.055, -0.62)
		_:
			add_box(root, Vector3(0.08, 0.105, 0.44), Vector3(0.0, 0.01, -0.12), gun_metal)
			add_box(root, Vector3(0.06, 0.16, 0.09), Vector3(0.0, -0.12, 0.05), gun_dark)
			add_box(root, Vector3(0.06, 0.16, 0.09), Vector3(0.0, -0.12, -0.16), gun_dark)
			add_box(root, Vector3(0.06, 0.08, 0.22), Vector3(0.0, 0.0, 0.18), gun_dark)
			add_cylinder(root, 0.023, 0.026, 0.34, Vector3(0.0, 0.025, -0.39), gun_dark, Vector3(90.0, 0.0, 0.0), 8)
			add_box(root, Vector3(0.035, 0.04, 0.24), Vector3(0.0, 0.086, -0.12), glow)
			muzzle.position = Vector3(0.0, 0.025, -0.58)

	root.add_child(muzzle)
	return root


# ---------------------------------------------------------------------------
# Driftling (pet) kit
# ---------------------------------------------------------------------------

## Builds a floating Driftling. Returned Dictionary:
##   root, visual, wing_l, wing_r, wing_base_l, wing_base_r, mote_ring,
##   light, beam, halo, core
static func build_driftling(data: PetData) -> Dictionary:
	var role: StringName = data.role if data != null else &"support"
	var effect: StringName = data.effect if data != null else &"mote_shield"
	var display_name: String = data.display_name if data != null else "Driftling"
	var accent: Color = data.color if data != null else MINT
	var shell_color: Color = data.shell_color if data != null else IVORY

	var root := Node3D.new()
	root.name = "DriftlingVisual"
	var visual := Node3D.new()
	visual.name = "Rig"
	root.add_child(visual)

	var shell := metal(shell_color, 0.32, 0.34)
	var belly := emissive(accent, 2.8)
	var mint := emissive(MINT, 2.0)
	var dark := metal(INK, 0.3, 0.5)

	# Shell body: flattened lantern-like orb.
	add_sphere(visual, 0.3, Vector3(0.0, 0.0, 0.0), shell, Vector3(1.0, 0.86, 1.04), 12)
	add_torus(visual, 0.29, 0.335, Vector3(0.0, 0.0, 0.0), emissive(accent, 1.4, 0.9), Vector3.ZERO)
	add_sphere(visual, 0.17, Vector3(0.0, -0.03, 0.02), belly, Vector3(1.0, 0.82, 1.0), 10)
	# Face plate: ivory mask with big friendly eyes.
	add_sphere(visual, 0.17, Vector3(0.0, 0.02, -0.2), metal(IVORY, 0.08, 0.5), Vector3(1.12, 0.92, 0.55), 10)
	var eye_mat := emissive(accent.lerp(Color.WHITE, 0.55), 3.0)
	add_sphere(visual, 0.052, Vector3(-0.085, 0.035, -0.3), eye_mat, Vector3.ONE, 6)
	add_sphere(visual, 0.052, Vector3(0.085, 0.035, -0.3), eye_mat, Vector3.ONE, 6)
	var pupil := metal(Color("0c1416"), 0.0, 0.35)
	add_sphere(visual, 0.024, Vector3(-0.085, 0.035, -0.345), pupil, Vector3.ONE, 6)
	add_sphere(visual, 0.024, Vector3(0.085, 0.035, -0.345), pupil, Vector3.ONE, 6)
	# Cheek blush (charming) + smile tick.
	add_box(visual, Vector3(0.16, 0.02, 0.02), Vector3(0.0, -0.06, -0.31), emissive(accent.darkened(0.2), 1.4, 0.7))

	# Tail fin.
	add_box(visual, Vector3(0.1, 0.06, 0.26), Vector3(0.0, -0.02, 0.3), shell)
	add_sphere(visual, 0.05, Vector3(0.0, 0.0, 0.44), belly, Vector3.ONE, 6)

	# Wings (flat fins that flap).
	var wing_l := Node3D.new()
	wing_l.name = "WingL"
	wing_l.position = Vector3(-0.24, 0.05, 0.03)
	wing_l.rotation_degrees = Vector3(0.0, -26.0, 18.0)
	visual.add_child(wing_l)
	add_box(wing_l, Vector3(0.3, 0.04, 0.18), Vector3(-0.14, 0.0, 0.0), metal(shell_color.lightened(0.1), 0.2, 0.55))
	add_box(wing_l, Vector3(0.16, 0.03, 0.12), Vector3(-0.3, 0.0, -0.02), emissive(accent, 1.4, 0.85))

	var wing_r := Node3D.new()
	wing_r.name = "WingR"
	wing_r.position = Vector3(0.24, 0.05, 0.03)
	wing_r.rotation_degrees = Vector3(0.0, 26.0, -18.0)
	visual.add_child(wing_r)
	add_box(wing_r, Vector3(0.3, 0.04, 0.18), Vector3(0.14, 0.0, 0.0), metal(shell_color.lightened(0.1), 0.2, 0.55))
	add_box(wing_r, Vector3(0.16, 0.03, 0.12), Vector3(0.3, 0.0, -0.02), emissive(accent, 1.4, 0.85))

	var wing_base_l := wing_l.rotation
	var wing_base_r := wing_r.rotation

	# Halo ring (friendly/Driftling identity).
	var halo := add_torus(visual, 0.17, 0.21, Vector3(0.0, 0.3, 0.02), mint, Vector3(90.0, 0.0, 0.0))

	# Orbiting motes.
	var mote_ring := Node3D.new()
	mote_ring.name = "MoteRing"
	visual.add_child(mote_ring)
	add_sphere(mote_ring, 0.035, Vector3(0.42, 0.1, 0.0), emissive(accent.lerp(Color.WHITE, 0.3), 3.0), Vector3.ONE, 6)
	add_sphere(mote_ring, 0.03, Vector3(-0.4, -0.12, 0.1), emissive(accent.lerp(Color.WHITE, 0.3), 2.6), Vector3.ONE, 6)

	# Role identity bits.
	var beam: MeshInstance3D = null
	match effect:
		&"mote_shield":
			# Lantern cage struts.
			for i in 4:
				var angle := TAU * float(i) / 4.0
				add_box(visual, Vector3(0.02, 0.4, 0.02), Vector3(cos(angle) * 0.3, 0.0, sin(angle) * 0.3), metal(IVORY.darkened(0.2), 0.2, 0.5), Vector3(0.0, rad_to_deg(angle), 0.0))
			add_torus(visual, 0.29, 0.33, Vector3(0.0, 0.2, 0.0), mint, Vector3.ZERO)
			add_torus(visual, 0.24, 0.28, Vector3(0.0, -0.22, 0.0), mint, Vector3.ZERO)
		&"cinder_bolt":
			# Ember vents and a flickering crest.
			add_box(visual, Vector3(0.34, 0.08, 0.16), Vector3(0.0, -0.16, 0.2), metal(Color("d28b58"), 0.4, 0.4))
			add_box(visual, Vector3(0.1, 0.03, 0.1), Vector3(-0.1, -0.2, 0.2), emissive(AMBER, 2.4))
			add_box(visual, Vector3(0.1, 0.03, 0.1), Vector3(0.1, -0.2, 0.2), emissive(AMBER, 2.4))
			add_cone(visual, 0.07, 0.2, Vector3(0.0, 0.34, 0.06), emissive(AMBER, 2.2), Vector3(0.0, 0.0, 0.0), 6)
		&"pip_scan":
			# Sensor lens + antenna + scan cone (hidden until scanning).
			add_torus(visual, 0.1, 0.14, Vector3(0.0, 0.04, -0.29), emissive(BLUE, 2.2), Vector3(90.0, 0.0, 0.0))
			add_cylinder(visual, 0.01, 0.02, 0.34, Vector3(0.16, 0.32, 0.06), metal(IVORY.darkened(0.2), 0.2, 0.5), Vector3(0.0, 0.0, -8.0), 6)
			add_sphere(visual, 0.04, Vector3(0.2, 0.5, 0.06), emissive(BLUE, 3.0), Vector3.ONE, 6)
			beam = add_cone(visual, 0.5, 1.6, Vector3(0.0, -0.1, -1.0), emissive(BLUE, 0.9, 0.22), Vector3(-90.0, 0.0, 0.0), 10)
			beam.visible = false
		_:
			add_torus(visual, 0.3, 0.34, Vector3(0.0, 0.0, 0.0), mint, Vector3.ZERO)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = accent
	light.light_energy = 0.9
	light.omni_range = 3.6
	light.position = Vector3(0.0, 0.0, -0.05)
	root.add_child(light)

	var nameplate := Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.text = display_name
	nameplate.font_size = 34
	nameplate.outline_size = 8
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.modulate = Color(0.96, 0.94, 0.9, 0.85)
	nameplate.outline_modulate = Color(0.03, 0.05, 0.06, 0.9)
	nameplate.position = Vector3(0.0, 0.62, 0.0)
	nameplate.visible = false
	root.add_child(nameplate)

	return {
		"root": root,
		"visual": visual,
		"wing_l": wing_l,
		"wing_r": wing_r,
		"wing_base_l": wing_base_l,
		"wing_base_r": wing_base_r,
		"mote_ring": mote_ring,
		"light": light,
		"beam": beam,
		"halo": halo,
		"nameplate": nameplate,
		"core": belly,
		"role": role,
	}
