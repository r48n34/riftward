class_name VehicleBuilder
extends RefCounted
## Procedural vehicle meshes in the ExtractionShip idiom: BoxMesh / PrismMesh /
## CylinderMesh primitives with StandardMaterial3D, merged through MeshKit so a
## whole rideable body is two or three draw calls. Nothing is loaded from disk ??## every archetype is built from code, and only the animated parts (wheels,
## propeller, horse legs, tail) stay as separate nodes.
##
## build_mesh(vehicle_id) -> Node3D returns a "Visuals" root the Rideable adds as
## a child. The root carries two metadata hints for the base class:
##   glow_material : StandardMaterial3D  (animated emissive accents)
##   headlight     : OmniLight3D         (lamp / landing light)
## plus wheel_radius for the wheel-spin animation.

const MESH_KIT := preload("res://features/world/mesh_kit.gd")

const HORSE_BROWN := Color("6b4a32")
const HORSE_DARK := Color("3a271b")
const HOOF := Color("1b1511")
const LEATHER := Color("4a3a2a")


## Main entry point. Unknown ids fall back to the rig silhouette so the builder
## is always safe to call.
static func build_mesh(vehicle_id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Visuals"
	match vehicle_id:
		&"rig":
			_build_rig(root)
		&"hoverbike":
			_build_hover_bike(root)
		&"airplane":
			_build_airplane(root)
		&"spaceship":
			_build_spaceship(root)
		&"horse":
			_build_horse(root)
		_:
			_build_rig(root)
	return root


# --- materials / kit helpers ------------------------------------------------


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _emission(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func _glass(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.2, 0.12)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _materials(accent: Color) -> Dictionary:
	return {
		&"hull": _material(Color("2b383c"), 0.55, 0.45),
		&"hull_dark": _material(Color("11181b"), 0.35, 0.55),
		&"trim": _material(Color("93a5a8"), 0.7, 0.35),
		&"glass": _glass(Color(0.20, 0.42, 0.48, 0.55)),
		&"seat": _material(Color("1f2d31"), 0.2, 0.8),
		&"glow": _emission(accent, 3.2),
	}


static func _horse_materials(accent: Color) -> Dictionary:
	return {
		&"horse": _material(HORSE_BROWN, 0.05, 0.9),
		&"horse_dark": _material(HORSE_DARK, 0.05, 0.92),
		&"hoof": _material(HOOF, 0.2, 0.7),
		&"trim": _material(LEATHER, 0.15, 0.75),
		&"glow": _emission(accent, 2.6),
	}


static func _new_kit(materials: Dictionary):
	var kit = MESH_KIT.new()
	kit.set_materials(materials)
	return kit


static func _commit(root: Node3D, kit, node_name: String, cast_shadow: bool = true) -> MeshInstance3D:
	var mesh = kit.build_mesh()
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	root.add_child(instance)
	return instance


static func _lamp(root: Node3D, position: Vector3, color: Color, light_range: float = 26.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "Headlight"
	light.position = position
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	root.add_child(light)
	root.set_meta("headlight", light)
	return light


static func _wheel(
	root: Node3D,
	position: Vector3,
	radius: float,
	width: float,
	material: Material,
	wheel_name: String
) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = wheel_name
	pivot.position = position
	root.add_child(pivot)
	var wheel := MeshInstance3D.new()
	wheel.name = "Tyre"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 14
	cylinder.rings = 1
	wheel.mesh = cylinder
	wheel.material_override = material
	wheel.rotation.z = PI * 0.5
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(wheel)
	var hub := MeshInstance3D.new()
	hub.name = "Hub"
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.45
	hub_mesh.bottom_radius = radius * 0.45
	hub_mesh.height = width * 1.06
	hub_mesh.radial_segments = 8
	hub.mesh = hub_mesh
	hub.material_override = material
	hub.rotation.z = PI * 0.5
	hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(hub)
	return pivot


# --- rig (ground car) -------------------------------------------------------


static func _build_rig(root: Node3D) -> void:
	var accent := Color("ffb866")
	var materials := _materials(accent)
	var kit = _new_kit(materials)
	var glow = _new_kit(materials)
	# Chassis, fenders and cabin.
	kit.box(Vector3(2.15, 0.68, 4.15), Vector3(0.0, 0.74, 0.0), &"hull")
	kit.box(Vector3(1.75, 0.62, 1.95), Vector3(0.0, 1.36, -0.25), &"hull_dark")
	kit.box(Vector3(1.52, 0.38, 1.6), Vector3(0.0, 1.42, -0.32), &"glass")
	kit.prism(Vector3(2.05, 0.52, 1.25), Vector3(0.0, 0.78, -2.3), &"hull", Vector3(0.0, PI * 0.5, 0.0))
	kit.prism(Vector3(2.05, 0.46, 0.9), Vector3(0.0, 0.8, 2.22), &"hull_dark", Vector3(0.0, -PI * 0.5, 0.0))
	# Fenders over each wheel.
	for side in [-1.0, 1.0]:
		for z in [-1.32, 1.32]:
			kit.box(Vector3(0.34, 0.22, 1.18), Vector3(side * 1.12, 0.58, z), &"hull_dark")
	# Roll bar, roof rack and side steps.
	kit.box(Vector3(0.14, 0.62, 0.14), Vector3(-0.82, 1.62, 0.5), &"trim")
	kit.box(Vector3(0.14, 0.62, 0.14), Vector3(0.82, 1.62, 0.5), &"trim")
	kit.box(Vector3(1.82, 0.12, 1.5), Vector3(0.0, 1.78, 0.35), &"hull_dark")
	kit.box(Vector3(0.12, 0.12, 2.5), Vector3(-1.1, 1.18, 0.2), &"trim")
	kit.box(Vector3(0.12, 0.12, 2.5), Vector3(1.1, 1.18, 0.2), &"trim")
	# Bull bar + bumper.
	kit.box(Vector3(2.3, 0.24, 0.28), Vector3(0.0, 0.5, -2.18), &"hull_dark")
	kit.box(Vector3(0.16, 0.62, 0.16), Vector3(-0.72, 0.72, -2.26), &"trim")
	kit.box(Vector3(0.16, 0.62, 0.16), Vector3(0.72, 0.72, -2.26), &"trim")
	# Snorkel + exhaust.
	kit.box(Vector3(0.16, 1.1, 0.16), Vector3(0.98, 1.58, 0.62), &"trim")
	kit.cylinder(0.09, 0.12, 0.62, 8, Vector3(-0.7, 1.1, 1.92), &"trim", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Emissive strips: headlights, tail lights, roof marker.
	glow.box(Vector3(1.56, 0.14, 0.06), Vector3(0.0, 0.84, -2.66), &"glow")
	glow.box(Vector3(0.44, 0.2, 0.06), Vector3(-0.82, 0.9, -2.63), &"glow")
	glow.box(Vector3(0.44, 0.2, 0.06), Vector3(0.82, 0.9, -2.63), &"glow")
	glow.box(Vector3(1.7, 0.12, 0.06), Vector3(0.0, 0.96, 2.32), &"glow")
	glow.box(Vector3(0.1, 0.1, 1.7), Vector3(-1.12, 1.22, 0.2), &"glow")
	glow.box(Vector3(0.1, 0.1, 1.7), Vector3(1.12, 1.22, 0.2), &"glow")
	_commit(root, kit, "Body")
	_commit(root, glow, "Glow")
	for side in [-1.0, 1.0]:
		for z in [-1.32, 1.32]:
			var wheel_name := ""
			if z < 0.0:
				wheel_name = "WheelFL" if side < 0.0 else "WheelFR"
			else:
				wheel_name = "WheelRL" if side < 0.0 else "WheelRR"
			_wheel(root, Vector3(side * 1.06, 0.0, z), 0.55, 0.36, materials[&"hull_dark"], wheel_name)
	root.set_meta("wheel_radius", 0.55)
	root.set_meta("glow_material", materials[&"glow"])
	_lamp(root, Vector3(0.0, 0.95, -2.55), accent, 30.0)


# --- hover bike -------------------------------------------------------------


static func _build_hover_bike(root: Node3D) -> void:
	var accent := Color("62e6c3")
	var materials := _materials(accent)
	var kit = _new_kit(materials)
	var glow = _new_kit(materials)
	# Central spine and saddle.
	kit.box(Vector3(0.62, 0.42, 2.3), Vector3(0.0, 0.1, 0.0), &"hull")
	kit.prism(Vector3(0.66, 0.4, 0.9), Vector3(0.0, 0.08, -1.42), &"hull_dark", Vector3(0.0, PI * 0.5, 0.0))
	kit.box(Vector3(0.5, 0.16, 0.86), Vector3(0.0, 0.38, 0.34), &"seat")
	kit.box(Vector3(0.42, 0.3, 0.5), Vector3(0.0, 0.46, -0.92), &"glass")
	# Handlebar and forks.
	kit.box(Vector3(0.9, 0.07, 0.07), Vector3(0.0, 0.62, -1.12), &"trim")
	kit.box(Vector3(0.08, 0.44, 0.08), Vector3(-0.32, 0.42, -1.1), &"trim")
	kit.box(Vector3(0.08, 0.44, 0.08), Vector3(0.32, 0.42, -1.1), &"trim")
	# Side stabiliser pods (thrusters live underneath, no wheels).
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.3, 0.34, 1.5), Vector3(side * 0.62, -0.04, 0.28), &"hull_dark")
		kit.cylinder(0.16, 0.24, 0.34, 10, Vector3(side * 0.62, -0.26, 0.72), &"trim", Vector3.ZERO, false)
		glow.cylinder(0.13, 0.2, 0.1, 10, Vector3(side * 0.62, -0.42, 0.72), &"glow", Vector3.ZERO, false)
	# Rear engine block + nozzle.
	kit.box(Vector3(0.52, 0.46, 0.55), Vector3(0.0, 0.12, 1.24), &"hull_dark")
	glow.cylinder(0.16, 0.22, 0.12, 12, Vector3(0.0, 0.12, 1.54), &"glow", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Emissive nose + spine strips.
	glow.box(Vector3(0.3, 0.1, 0.06), Vector3(0.0, 0.18, -1.86), &"glow")
	glow.box(Vector3(0.06, 0.08, 1.35), Vector3(-0.3, 0.3, 0.1), &"glow")
	glow.box(Vector3(0.06, 0.08, 1.35), Vector3(0.3, 0.3, 0.1), &"glow")
	_commit(root, kit, "Body")
	_commit(root, glow, "Glow")
	root.set_meta("glow_material", materials[&"glow"])
	_lamp(root, Vector3(0.0, 0.24, -1.8), accent, 24.0)


# --- airplane ---------------------------------------------------------------


static func _build_airplane(root: Node3D) -> void:
	var accent := Color("6fa8ff")
	var materials := _materials(accent)
	var kit = _new_kit(materials)
	var glow = _new_kit(materials)
	# Fuselage, nose and tail boom.
	kit.box(Vector3(1.55, 1.05, 5.2), Vector3(0.0, 0.72, 0.1), &"hull")
	kit.prism(Vector3(1.42, 0.8, 1.5), Vector3(0.0, 0.68, -2.75), &"hull", Vector3(0.0, PI * 0.5, 0.0))
	kit.box(Vector3(1.1, 0.72, 1.1), Vector3(0.0, 0.68, 2.75), &"hull_dark")
	# Cockpit canopy.
	kit.box(Vector3(1.15, 0.52, 1.55), Vector3(0.0, 1.28, -0.62), &"glass")
	kit.box(Vector3(1.28, 0.16, 1.7), Vector3(0.0, 1.02, -0.62), &"hull_dark")
	# Swept wings and tip pods.
	kit.prism(Vector3(7.4, 0.22, 1.6), Vector3(-3.2, 0.72, 0.35), &"hull", Vector3(0.0, 0.28, 0.0))
	kit.prism(Vector3(7.4, 0.22, 1.6), Vector3(3.2, 0.72, 0.35), &"hull", Vector3(0.0, -0.28, 0.0))
	kit.box(Vector3(0.4, 0.34, 0.8), Vector3(-4.86, 0.74, 0.62), &"trim")
	kit.box(Vector3(0.4, 0.34, 0.8), Vector3(4.86, 0.74, 0.62), &"trim")
	# Tail fin and stabiliser.
	kit.prism(Vector3(0.16, 1.25, 1.2), Vector3(0.0, 1.3, 2.55), &"hull", Vector3(0.0, 0.0, 0.0))
	kit.box(Vector3(2.6, 0.14, 0.82), Vector3(0.0, 0.82, 2.9), &"hull_dark")
	# Engine nacelles under the wings.
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.62, 0.58, 1.7), Vector3(side * 1.58, 0.34, 0.25), &"hull_dark")
		kit.cylinder(0.26, 0.32, 0.24, 10, Vector3(side * 1.58, 0.34, 1.16), &"trim", Vector3(PI * 0.5, 0.0, 0.0), false)
		glow.cylinder(0.2, 0.24, 0.08, 10, Vector3(side * 1.58, 0.34, 1.3), &"glow", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Propeller pivot (spins in _update_visuals) and blades.
	var propeller := Node3D.new()
	propeller.name = "Propeller"
	propeller.position = Vector3(0.0, 0.68, -3.42)
	root.add_child(propeller)
	var blade_kit = _new_kit(materials)
	for i in 3:
		var angle := TAU * float(i) / 3.0
		blade_kit.box(Vector3(0.1, 0.9, 0.06), Vector3(0.0, 0.0, 0.0), &"hull_dark", Vector3(0.0, 0.0, angle))
	blade_kit.cylinder(0.16, 0.2, 0.24, 10, Vector3(0.0, 0.0, 0.0), &"trim", Vector3(PI * 0.5, 0.0, 0.0), false)
	_commit(propeller, blade_kit, "Blades", false)
	# Landing gear (three wheels, radius 0.32; origin rests 0.45 above ground).
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.1, 0.5, 0.1), Vector3(side * 0.85, 0.12, -1.15), &"trim")
	_wheel(root, Vector3(-0.85, -0.13, -1.15), 0.32, 0.2, materials[&"hull_dark"], "WheelFL")
	_wheel(root, Vector3(0.85, -0.13, -1.15), 0.32, 0.2, materials[&"hull_dark"], "WheelFR")
	_wheel(root, Vector3(0.0, -0.13, 2.35), 0.32, 0.2, materials[&"hull_dark"], "WheelRL")
	# Lamps and tinted nav lights.
	glow.box(Vector3(0.24, 0.1, 0.06), Vector3(0.0, 0.52, -3.35), &"glow")
	glow.box(Vector3(0.16, 0.16, 0.16), Vector3(-4.95, 0.9, 0.62), &"glow")
	glow.box(Vector3(0.16, 0.16, 0.16), Vector3(4.95, 0.9, 0.62), &"glow")
	_commit(root, kit, "Body")
	_commit(root, glow, "Glow")
	root.set_meta("wheel_radius", 0.32)
	root.set_meta("glow_material", materials[&"glow"])
	_lamp(root, Vector3(0.0, 0.6, -3.2), Color("bfefff"), 32.0)


# --- spaceship --------------------------------------------------------------


static func _build_spaceship(root: Node3D) -> void:
	var accent := Color("c79cff")
	var materials := _materials(accent)
	var kit = _new_kit(materials)
	var glow = _new_kit(materials)
	# Lifting body and armoured nose.
	kit.box(Vector3(2.25, 0.9, 4.6), Vector3(0.0, 0.55, 0.1), &"hull")
	kit.prism(Vector3(2.0, 0.72, 1.6), Vector3(0.0, 0.5, -2.6), &"hull", Vector3(0.0, PI * 0.5, 0.0))
	kit.box(Vector3(1.7, 0.62, 1.25), Vector3(0.0, 1.18, -0.9), &"hull_dark")
	kit.box(Vector3(1.42, 0.4, 1.05), Vector3(0.0, 1.3, -0.98), &"glass")
	# Docking collar on the spine.
	kit.cylinder(0.44, 0.5, 0.22, 12, Vector3(0.0, 1.24, 1.45), &"trim", Vector3.ZERO, false)
	kit.torus(0.4, 0.5, Vector3(0.0, 1.34, 1.45), &"glow")
	# Downward VTOL pods and rear main engines.
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.58, 0.66, 1.55), Vector3(side * 1.42, 0.3, 0.15), &"hull_dark")
		kit.cylinder(0.22, 0.3, 0.26, 10, Vector3(side * 1.42, -0.15, 0.15), &"trim", Vector3.ZERO, false)
		glow.cylinder(0.18, 0.24, 0.1, 12, Vector3(side * 1.42, -0.32, 0.15), &"glow", Vector3.ZERO, false)
		kit.prism(Vector3(2.5, 0.16, 1.35), Vector3(side * 2.15, 0.5, 0.95), &"hull", Vector3(0.0, side * 0.22, 0.0))
		kit.box(Vector3(0.18, 0.18, 1.9), Vector3(side * 2.05, 0.62, 1.0), &"trim")
		# Landing skid.
		kit.box(Vector3(0.16, 0.5, 2.2), Vector3(side * 1.05, -0.45, 0.0), &"trim")
		kit.box(Vector3(0.5, 0.12, 0.7), Vector3(side * 1.05, -0.74, 0.0), &"hull_dark")
	# Rear thruster bank.
	kit.box(Vector3(1.9, 0.72, 0.55), Vector3(0.0, 0.55, 2.4), &"hull_dark")
	for side in [-1.0, 1.0]:
		glow.cylinder(0.2, 0.28, 0.12, 12, Vector3(side * 0.6, 0.55, 2.72), &"glow", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Hull strips, docking beacon and forward landing light.
	glow.box(Vector3(0.1, 0.1, 3.4), Vector3(-1.14, 0.78, 0.1), &"glow")
	glow.box(Vector3(0.1, 0.1, 3.4), Vector3(1.14, 0.78, 0.1), &"glow")
	glow.box(Vector3(0.24, 0.1, 0.06), Vector3(0.0, 0.6, -3.4), &"glow")
	_commit(root, kit, "Body")
	_commit(root, glow, "Glow")
	root.set_meta("glow_material", materials[&"glow"])
	_lamp(root, Vector3(0.0, 0.55, -3.15), Color("d7b6ff"), 34.0)


# --- horse ------------------------------------------------------------------


static func _build_horse(root: Node3D) -> void:
	var accent := Color("ffb866")
	var materials := _horse_materials(accent)
	var kit = _new_kit(materials)
	var glow = _new_kit(materials)
	# Barrel, chest, rump.
	kit.box(Vector3(0.82, 0.82, 1.85), Vector3(0.0, 1.45, 0.05), &"horse")
	kit.box(Vector3(0.72, 0.76, 0.55), Vector3(0.0, 1.42, -0.94), &"horse")
	kit.prism(Vector3(0.78, 0.7, 0.62), Vector3(0.0, 1.5, 1.05), &"horse_dark", Vector3(0.0, -PI * 0.5, 0.0))
	# Neck and head, leaning forward over the front legs.
	kit.prism(Vector3(0.42, 1.05, 0.55), Vector3(0.0, 1.98, -1.28), &"horse", Vector3(0.42, 0.0, 0.0))
	kit.box(Vector3(0.34, 0.36, 0.78), Vector3(0.0, 2.48, -1.86), &"horse")
	kit.prism(Vector3(0.3, 0.24, 0.4), Vector3(0.0, 2.4, -2.26), &"horse_dark", Vector3(PI * 0.5, 0.0, 0.0))
	# Ears and mane.
	kit.box(Vector3(0.06, 0.26, 0.06), Vector3(-0.1, 2.68, -1.62), &"horse_dark")
	kit.box(Vector3(0.06, 0.26, 0.06), Vector3(0.1, 2.68, -1.62), &"horse_dark")
	kit.box(Vector3(0.1, 0.24, 1.0), Vector3(0.0, 2.2, -1.4), &"horse_dark")
	# Saddle and tack.
	kit.box(Vector3(0.72, 0.14, 0.82), Vector3(0.0, 1.9, 0.05), &"trim")
	kit.box(Vector3(0.62, 0.24, 0.22), Vector3(0.0, 2.0, 0.42), &"trim")
	kit.box(Vector3(0.08, 0.44, 0.6), Vector3(-0.42, 1.66, 0.05), &"trim")
	kit.box(Vector3(0.08, 0.44, 0.6), Vector3(0.42, 1.66, 0.05), &"trim")
	# Glowing eyes and a lantern on the brow band (emissive accents).
	glow.box(Vector3(0.07, 0.07, 0.05), Vector3(-0.11, 2.54, -2.24), &"glow")
	glow.box(Vector3(0.07, 0.07, 0.05), Vector3(0.11, 2.54, -2.24), &"glow")
	glow.box(Vector3(0.12, 0.14, 0.1), Vector3(0.0, 2.42, -2.16), &"glow")
	_commit(root, kit, "Body")
	_commit(root, glow, "Glow")
	# Tail.
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 1.72, 1.16)
	root.add_child(tail)
	var tail_kit = _new_kit(materials)
	tail_kit.cylinder(0.05, 0.14, 0.95, 8, Vector3(0.0, -0.42, 0.12), &"horse_dark", Vector3(0.42, 0.0, 0.0), false)
	_commit(tail, tail_kit, "TailMesh")
	# Four legs on hip pivots so the horse script can animate a gallop without bones.
	var hips := {
		"LegFL": Vector3(-0.32, 1.08, -0.72),
		"LegFR": Vector3(0.32, 1.08, -0.72),
		"LegRL": Vector3(-0.32, 1.1, 0.82),
		"LegRR": Vector3(0.32, 1.1, 0.82),
	}
	for leg_name in hips.keys():
		var leg := Node3D.new()
		leg.name = leg_name
		leg.position = hips[leg_name]
		root.add_child(leg)
		var leg_kit = _new_kit(materials)
		leg_kit.cylinder(0.1, 0.14, 0.6, 8, Vector3(0.0, -0.3, 0.0), &"horse", Vector3.ZERO, false)
		leg_kit.cylinder(0.07, 0.1, 0.48, 8, Vector3(0.0, -0.82, 0.03), &"horse_dark", Vector3.ZERO, false)
		leg_kit.box(Vector3(0.15, 0.14, 0.24), Vector3(0.0, -1.05, -0.04), &"hoof")
		_commit(leg, leg_kit, "LegMesh")
	root.set_meta("glow_material", materials[&"glow"])
	_lamp(root, Vector3(0.0, 2.5, -2.3), Color("ffd9a0"), 18.0)
