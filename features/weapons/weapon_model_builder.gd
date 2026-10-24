class_name WeaponModelBuilder
extends RefCounted
## Constructs distinct low-poly weapon viewmodels from primitives. No external
## meshes; silhouettes and accent emissives carry the identity.

static func build(stats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponView"
	var style := String(stats.get("style", "rifle"))
	var base_color: Color = stats.get("color", Color("f4efe5"))
	var accent: Color = stats.get("accent", Color("62e6c3"))
	var metal := _metal(base_color, 0.45, 0.55)
	var dark := _metal(Color("151d20"), 0.3, 0.5)
	var glow := _emission(accent)
	match style:
		"knife":
			# Straight combat blade with a dark grip and emissive edge.
			_add_box(root, Vector3(0.03, 0.012, 0.3), Vector3(0.0, 0.035, -0.16), metal, Vector3(-3, 0, 0))
			_add_box(root, Vector3(0.008, 0.026, 0.28), Vector3(0.016, 0.038, -0.17), glow, Vector3(-3, 0, 0))
			_add_box(root, Vector3(0.05, 0.075, 0.13), Vector3(0.0, -0.035, 0.06), dark)
			_add_box(root, Vector3(0.1, 0.018, 0.03), Vector3(0.0, -0.005, -0.01), dark)
			_add_box(root, Vector3(0.035, 0.06, 0.06), Vector3(0.0, -0.08, 0.1), _metal(Color("26383d"), 0.2, 0.8), Vector3(12, 0, 0))
		"pistol":
			_add_box(root, Vector3(0.07, 0.12, 0.28), Vector3(0.0, 0.0, -0.06), metal)
			_add_box(root, Vector3(0.055, 0.16, 0.085), Vector3(0.0, -0.1, 0.02), dark)
			_add_box(root, Vector3(0.03, 0.03, 0.18), Vector3(0.0, 0.015, -0.22), glow)
			_add_barrel(root, 0.028, 0.22, Vector3(0.0, 0.02, -0.28), dark)
		"shotgun":
			_add_box(root, Vector3(0.085, 0.1, 0.46), Vector3(0.0, 0.02, -0.18), metal)
			_add_box(root, Vector3(0.075, 0.09, 0.2), Vector3(0.0, -0.02, 0.12), dark)
			_add_box(root, Vector3(0.06, 0.06, 0.44), Vector3(0.0, -0.075, -0.22), dark)
			_add_barrel(root, 0.038, 0.48, Vector3(0.0, 0.06, -0.42), dark)
			_add_box(root, Vector3(0.022, 0.022, 0.36), Vector3(0.0, 0.085, -0.26), glow)
		"sniper":
			_add_box(root, Vector3(0.075, 0.1, 0.55), Vector3(0.0, 0.01, -0.18), metal)
			_add_box(root, Vector3(0.06, 0.08, 0.28), Vector3(0.0, -0.02, 0.18), dark)
			_add_barrel(root, 0.028, 0.62, Vector3(0.0, 0.03, -0.5), dark)
			_add_scope(root, Vector3(0.0, 0.12, -0.12), accent)
			_add_box(root, Vector3(0.06, 0.18, 0.09), Vector3(0.0, -0.12, 0.06), dark)
		"dmr":
			_add_box(root, Vector3(0.072, 0.1, 0.48), Vector3(0.0, 0.01, -0.12), metal)
			_add_box(root, Vector3(0.06, 0.14, 0.09), Vector3(0.0, -0.1, 0.04), dark)
			_add_barrel(root, 0.025, 0.48, Vector3(0.0, 0.03, -0.42), dark)
			_add_scope(root, Vector3(0.0, 0.115, -0.1), accent)
			_add_box(root, Vector3(0.05, 0.05, 0.16), Vector3(0.0, -0.02, 0.2), metal)
		"lmg":
			_add_box(root, Vector3(0.11, 0.14, 0.55), Vector3(0.0, 0.0, -0.15), metal)
			_add_box(root, Vector3(0.14, 0.16, 0.22), Vector3(0.0, -0.08, 0.02), dark)
			_add_barrel(root, 0.042, 0.56, Vector3(0.0, 0.03, -0.48), dark)
			_add_box(root, Vector3(0.025, 0.03, 0.3), Vector3(0.04, 0.08, -0.24), glow)
			_add_box(root, Vector3(0.06, 0.16, 0.08), Vector3(0.0, -0.13, 0.1), dark)
		"launcher":
			_add_box(root, Vector3(0.12, 0.12, 0.5), Vector3(0.0, 0.02, -0.16), metal)
			_add_barrel(root, 0.085, 0.36, Vector3(0.0, 0.06, -0.42), dark)
			_add_box(root, Vector3(0.07, 0.14, 0.08), Vector3(0.0, -0.11, 0.04), dark)
			_add_box(root, Vector3(0.035, 0.035, 0.18), Vector3(0.0, 0.1, -0.18), glow)
		"arc":
			_add_box(root, Vector3(0.08, 0.11, 0.45), Vector3(0.0, 0.01, -0.12), metal)
			_add_box(root, Vector3(0.06, 0.15, 0.08), Vector3(0.0, -0.11, 0.04), dark)
			_add_barrel(root, 0.035, 0.36, Vector3(0.0, 0.03, -0.38), dark)
			_add_box(root, Vector3(0.035, 0.035, 0.3), Vector3(0.0, 0.09, -0.2), glow)
			_add_box(root, Vector3(0.02, 0.02, 0.18), Vector3(0.055, 0.02, -0.15), glow)
			_add_box(root, Vector3(0.02, 0.02, 0.18), Vector3(-0.055, 0.02, -0.15), glow)
		"smg":
			_add_box(root, Vector3(0.075, 0.1, 0.3), Vector3(0.0, 0.0, -0.08), metal)
			_add_box(root, Vector3(0.055, 0.2, 0.075), Vector3(0.0, -0.14, -0.02), dark)
			_add_barrel(root, 0.025, 0.2, Vector3(0.0, 0.02, -0.28), dark)
			_add_box(root, Vector3(0.06, 0.055, 0.18), Vector3(0.0, 0.08, -0.02), glow)
			_add_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0.0, -0.1, 0.08), dark)
		_:
			# rifle / carbine
			_add_box(root, Vector3(0.08, 0.105, 0.44), Vector3(0.0, 0.01, -0.12), metal)
			_add_box(root, Vector3(0.06, 0.16, 0.09), Vector3(0.0, -0.12, 0.05), dark)
			_add_box(root, Vector3(0.06, 0.16, 0.09), Vector3(0.0, -0.12, -0.16), dark)
			_add_box(root, Vector3(0.062, 0.075, 0.3), Vector3(0.0, 0.0, 0.22), dark)
			_add_box(root, Vector3(0.085, 0.07, 0.28), Vector3(0.0, 0.015, -0.34), dark)
			_add_barrel(root, 0.025, 0.34, Vector3(0.0, 0.025, -0.54), dark)
			_add_barrel(root, 0.04, 0.09, Vector3(0.0, 0.025, -0.73), dark)
			_add_box(root, Vector3(0.035, 0.04, 0.25), Vector3(0.0, 0.095, -0.12), glow)
			_add_box(root, Vector3(0.012, 0.055, 0.24), Vector3(-0.044, 0.005, -0.12), dark)
			_add_box(root, Vector3(0.014, 0.017, 0.18), Vector3(-0.052, 0.043, -0.14), glow)
			_add_box(root, Vector3(0.03, 0.03, 0.14), Vector3(0.055, 0.0, -0.08), glow)
			_add_box(root, Vector3(0.055, 0.012, 0.16), Vector3(0.0, 0.13, -0.14), dark)
	if style != "pistol" and style != "knife":
		_add_arms(root, dark)
	elif style == "knife":
		_add_knife_arm(root, dark)
	if style in ["rifle", "carbine", "smg", "shotgun", "pistol", "lmg", "launcher", "arc"]:
		_add_iron_sights(root, style, dark, glow)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	root.add_child(muzzle)
	muzzle.position = _muzzle_position(style)
	return root


static func _muzzle_position(style: String) -> Vector3:
	match style:
		"pistol":
			return Vector3(0.0, 0.02, -0.4)
		"shotgun":
			return Vector3(0.0, 0.06, -0.68)
		"dmr":
			return Vector3(0.0, 0.03, -0.68)
		"sniper":
			return Vector3(0.0, 0.03, -0.86)
		"lmg":
			return Vector3(0.0, 0.03, -0.78)
		"launcher":
			return Vector3(0.0, 0.06, -0.62)
		"arc":
			return Vector3(0.0, 0.03, -0.58)
		"smg":
			return Vector3(0.0, 0.02, -0.4)
		"knife":
			return Vector3(0.0, 0.035, -0.32)
		_:
			return Vector3(0.0, 0.025, -0.6)


static func _add_arms(root: Node3D, material: Material) -> void:
	var sleeve := _metal(Color("1d2b2e"), 0.25, 0.7)
	_add_box(root, Vector3(0.075, 0.095, 0.3), Vector3(0.11, -0.194, 0.15), sleeve, Vector3(-18, -8, -12))
	_add_box(root, Vector3(0.09, 0.07, 0.11), Vector3(0.055, -0.113, 0.015), material, Vector3(10, 0, -8))
	_add_box(root, Vector3(0.06, 0.11, 0.08), Vector3(0.03, -0.175, 0.07), material, Vector3(22, 0, 6))
	_add_box(root, Vector3(0.05, 0.025, 0.05), Vector3(0.055, -0.07, -0.015), _metal(Color("62e6c3"), 0.2, 0.4), Vector3.ZERO)


static func _add_knife_arm(root: Node3D, material: Material) -> void:
	var sleeve := _metal(Color("1d2b2e"), 0.25, 0.7)
	_add_box(root, Vector3(0.075, 0.095, 0.3), Vector3(0.08, -0.17, 0.12), sleeve, Vector3(-14, -6, -10))
	_add_box(root, Vector3(0.085, 0.07, 0.12), Vector3(0.045, -0.095, 0.04), material, Vector3(8, 0, -6))
	_add_box(root, Vector3(0.055, 0.10, 0.075), Vector3(0.02, -0.05, 0.055), material, Vector3(16, 0, 4))


## Adds readable iron sights at the right height for the style. High-zoom
## weapons keep their bundled scope instead.
static func _add_iron_sights(root: Node3D, style: String, dark: Material, glow: Material) -> void:
	var all_specs: Dictionary = {
		"rifle": {"h": 0.128, "rear": 0.03, "front": -0.4},
		"carbine": {"h": 0.128, "rear": 0.03, "front": -0.4},
		"smg": {"h": 0.095, "rear": 0.01, "front": -0.21},
		"shotgun": {"h": 0.092, "rear": 0.07, "front": -0.37},
		"pistol": {"h": 0.088, "rear": 0.0, "front": -0.2},
		"lmg": {"h": 0.108, "rear": 0.12, "front": -0.36},
		"launcher": {"h": 0.115, "rear": 0.1, "front": -0.3},
		"arc": {"h": 0.112, "rear": 0.06, "front": -0.3},
	}
	var spec: Dictionary = all_specs.get(style, {})
	if spec.is_empty():
		return
	var h := float(spec["h"])
	var rear_z := float(spec["rear"])
	var front_z := float(spec["front"])
	# Rear notch and front post.
	_add_box(root, Vector3(0.052, 0.022, 0.022), Vector3(0.0, h, rear_z), dark)
	_add_box(root, Vector3(0.05, 0.018, 0.012), Vector3(0.0, h + 0.012, rear_z), glow)
	_add_box(root, Vector3(0.016, 0.034, 0.02), Vector3(0.0, h + 0.012, front_z), dark)
	_add_box(root, Vector3(0.01, 0.01, 0.008), Vector3(0.0, h + 0.028, front_z), glow)


static func _add_box(
	root: Node3D,
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
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance


static func _add_barrel(root: Node3D, radius: float, length: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.15
	mesh.height = length
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = Vector3(90, 0, 0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance


static func _add_scope(root: Node3D, pos: Vector3, color: Color) -> void:
	var body := _add_barrel(root, 0.035, 0.2, pos, _metal(Color("1c2528"), 0.3, 0.5))
	body.rotation_degrees = Vector3(90, 0, 0)
	_add_box(root, Vector3(0.055, 0.02, 0.08), pos + Vector3(0.0, 0.045, 0.0), _metal(Color("1c2528"), 0.3, 0.5))
	_add_box(root, Vector3(0.03, 0.03, 0.008), pos + Vector3(0.0, 0.0, -0.11), _emission(color))


static func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func _emission(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

