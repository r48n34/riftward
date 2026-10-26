class_name CombatVFX
extends RefCounted
## Lightweight, code-generated combat feedback. Effects are short-lived and
## intentionally cheap; high-frequency visuals use pool-friendly meshes.
##
## ## CC0 particle hooks (W6)
## The primitive meshes/lights below are the always-available baseline: every
## function works with no assets on disk and headless. On top of them we spawn a
## few small CC0 particle bursts through features/fx/particle_library.gd
## (Kenney Particle Pack, see docs/ASSET_PACKS.md). The particle layer is purely
## additive — if the library or its PNGs are missing, `_particle_library()`
## returns null and these calls become no-ops, so combat feel degrades to the
## original primitives and nothing errors.
##
## Hook points for other systems (do not duplicate texture paths elsewhere):
##   * Surface-aware impacts: pass the fifth `surface` argument to impact(),
##       e.g. CombatVFX.impact(parent, hit.position, hit.normal, accent, &"metal")
##     Recognised surfaces: metal/steel/armor/plate, glass/ceramic, dirt/sand/
##     soil/mud/foliage, wood/plank, water, flesh/organic. Unknown or omitted
##     surfaces default to the metal-spark look (the pre-W6 behaviour).
##   * Vehicles: dust and exhaust plumes come straight from the library —
##       ParticleLibrary.spawn(self, &"exhaust", exhaust_tip.global_position, 14, false)
##       ParticleLibrary.spawn(self, &"dust", wheel_contact_point, 10)
##   * Weather/world: rain, splash and ambient dust for weather emitters —
##       ParticleLibrary.make(&"rain", 400) (one_shot=false; parent to a moving
##       emitter) and ParticleLibrary.spawn(world, &"splash", ground_point, 10).
##   * VFX/abilities: portal/flare/trail ids; CombatVFX.beam_burst already
##     routes through spawn_tracer + impact, so it inherits the particle layer.

const PARTICLE_LIBRARY_PATH := "res://features/fx/particle_library.gd"
const MUZZLE_PARTICLE_COUNT := 8
const IMPACT_PARTICLE_COUNT := 10
const IMPACT_DEBRIS_COUNT := 5
const EXPLOSION_PARTICLE_COUNT := 18
const EXPLOSION_SMOKE_COUNT := 10

static var _particle_lib: GDScript = null
static var _particle_lib_checked := false


## Loads the optional ParticleLibrary once; returns null when it is absent.
static func _particle_library() -> GDScript:
	if not _particle_lib_checked:
		_particle_lib_checked = true
		if ResourceLoader.exists(PARTICLE_LIBRARY_PATH):
			var resource := load(PARTICLE_LIBRARY_PATH)
			if resource is GDScript:
				_particle_lib = resource as GDScript
	return _particle_lib


## Spawn a short-lived particle burst if the library and pack are available.
static func _spawn_particles(parent: Node3D, effect_id: StringName, position: Vector3, count: int) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var library := _particle_library()
	if library == null:
		return
	library.call("spawn", parent, effect_id, position, count)


## Testability hook: pretend the CC0 particle library/pack is not installed, so
## callers can be verified against the pre-W6 primitive-only behaviour without
## deleting committed files. Pair with restore_particle_library().
static func simulate_missing_particle_library() -> void:
	_particle_lib = null
	_particle_lib_checked = true


## Undo simulate_missing_particle_library(); the next call re-probes the pack.
static func restore_particle_library() -> void:
	_particle_lib = null
	_particle_lib_checked = false


## True when the optional particle layer is currently resolved (pack present).
static func has_particle_library() -> bool:
	return _particle_library() != null


## Releases the cached ParticleLibrary script reference. Test/tool teardown only:
## static holders otherwise keep the script (and its caches) alive until process
## exit, which the engine reports as "resources still in use". Gameplay never
## needs this; restore_particle_library() re-arms the lookup.
static func shutdown() -> void:
	_particle_lib = null
	_particle_lib_checked = true


## Maps a hit surface name to the particle effect that should sell the impact.
static func surface_impact_effect(surface: StringName = &"") -> StringName:
	match surface:
		&"metal", &"steel", &"armor", &"plate", &"iron":
			return &"impact_metal"
		&"glass", &"ceramic", &"crystal":
			return &"sparks"
		&"dirt", &"sand", &"soil", &"mud", &"foliage", &"grass", &"concrete", &"stone", &"rock":
			return &"impact_dirt"
		&"wood", &"plank", &"timber":
			return &"dust"
		&"water", &"slime":
			return &"splash"
		&"flesh", &"organic", &"chitin":
			return &"impact_dirt"
		_:
			return &"impact_metal"


static func _mat(color: Color, emission: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = emission > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = emission
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func spawn_tracer(parent: Node3D, from: Vector3, to: Vector3, color: Color = Color("ffe9b8")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, length)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(color, 3.0)
	parent.add_child(instance)
	instance.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.01:
		var dir := (to - from).normalized()
		instance.look_at(instance.global_position + dir, Vector3.UP)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.create_tween().tween_property(instance, "scale", Vector3(1.0, 1.0, 0.2), 0.06)
	instance.get_tree().create_timer(0.065).timeout.connect(instance.queue_free)


static func impact(
	parent: Node3D,
	position: Vector3,
	normal: Vector3,
	color: Color = Color("ffcf8a"),
	surface: StringName = &""
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position + normal * 0.02
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	flash.mesh = sphere
	flash.material_override = _mat(color, 3.5)
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 1.6
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(2.4, 2.4, 2.4), 0.12)
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.chain().tween_callback(root.queue_free)
	# CC0 particles (no-op without the pack): sparks or dust chosen by surface.
	var particle_id := surface_impact_effect(surface)
	var spark_position := position + normal * 0.05
	_spawn_particles(parent, particle_id, spark_position, IMPACT_PARTICLE_COUNT)
	if particle_id != &"impact_dirt":
		_spawn_particles(parent, &"impact_dirt", spark_position, IMPACT_DEBRIS_COUNT)


static func muzzle_flash(parent: Node3D, position: Vector3, color: Color = Color("ffd89a")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.18
	sphere.radial_segments = 6
	sphere.rings = 3
	flash.mesh = sphere
	flash.material_override = _mat(color, 4.0)
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.0
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(0.2, 0.2, 3.5), 0.05)
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.chain().tween_callback(root.queue_free)
	# CC0 muzzle puff (no-op without the pack).
	_spawn_particles(parent, &"muzzle", position, MUZZLE_PARTICLE_COUNT)


static func damage_number(parent: Node3D, position: Vector3, amount: float, crit: bool = false, weakpoint: bool = false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48 if crit else 32
	label.outline_size = 8
	label.modulate = Color("ffb866") if crit else (Color("ff6e6e") if weakpoint else Color("f4efe5"))
	label.outline_modulate = Color(0.02, 0.03, 0.04, 0.8)
	parent.add_child(label)
	label.global_position = position + Vector3(0.0, 0.4, 0.0)
	var drift := Vector3(randf_range(-0.2, 0.2), 0.9, randf_range(-0.2, 0.2))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + drift, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


static func explosion(parent: Node3D, position: Vector3, radius: float, color: Color = Color("ffb866")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 5
	var flash := MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.material_override = _mat(color, 3.0)
	root.add_child(flash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.2, radius * 0.75)
	torus.outer_radius = maxf(0.3, radius)
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat(color, 2.5)
	root.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = radius * 2.0
	root.add_child(light)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(radius * 2.0, radius * 2.0, radius * 2.0), 0.25)
	tween.tween_property(flash, "transparency", 1.0, 0.3)
	tween.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.35)
	tween.tween_property(ring, "transparency", 1.0, 0.35)
	tween.tween_property(light, "light_energy", 0.0, 0.25)
	tween.chain().tween_callback(root.queue_free)
	# CC0 fireball + rising smoke column (no-op without the pack).
	_spawn_particles(parent, &"explosion", position, EXPLOSION_PARTICLE_COUNT)
	_spawn_particles(parent, &"smoke", position + Vector3.UP * 0.4, EXPLOSION_SMOKE_COUNT)


static func ring(parent: Node3D, position: Vector3, radius: float, color: Color = Color("62e6c3"), duration: float = 0.7) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = position + Vector3.UP * 0.05
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55
	torus.rings = 24
	torus.ring_segments = 8
	mesh.mesh = torus
	mesh.material_override = _mat(color, 2.0)
	root.add_child(mesh)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(radius, 0.6, radius), duration * 0.7)
	tween.tween_property(mesh, "transparency", 1.0, duration)
	tween.chain().tween_callback(root.queue_free)


static func beam_burst(parent: Node3D, from: Vector3, to: Vector3, color: Color = Color("62e6c3")) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	spawn_tracer(parent, from, to, color)
	var mid := (from + to) * 0.5
	impact(parent, mid, (to - from).normalized(), color)


static func hit_direction_arc(source: Vector3, player_position: Vector3) -> Vector3:
	return (source - player_position).normalized()
