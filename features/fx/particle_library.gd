class_name ParticleLibrary
extends RefCounted
## CC0 particle-effect catalog: maps stable logical effect ids to the curated
## Kenney Particle Pack textures in `res://assets/textures/particles/` and
## builds ready-to-use `GPUParticles3D` nodes with sane per-effect defaults.
##
## The library is deliberately forgiving: if a texture is missing (packs not
## fetched, trimmed checkout, exported build without assets) it falls back to a
## procedurally generated soft-dot texture, so `make()` never returns null and
## never raises. Callers can therefore wire particles without null checks on the
## texture side — only the parent node has to be valid.
##
## PROVENANCE: every PNG here comes from the Kenney Particle Pack (CC0), curated
## by tools/fetch_asset_packs.ps1. See assets/cc0/kenney_particle_pack/MANIFEST.json
## and docs/ASSET_PACKS.md. Do not hand-edit PNGs; re-run the fetcher instead.
##
## REUSE HOOK POINTS (other systems are expected to call these instead of
## duplicating texture paths):
##   * Combat (features/combat/combat_vfx.gd) — muzzle, impact_metal/impact_dirt,
##     explosion, smoke, sparks.
##   * Vehicles (features/vehicles/*): exhaust/dust for tyres and engines, e.g.
##       ParticleLibrary.spawn(self, &"exhaust", exhaust_tip.global_position, 18)
##   * Weather (features/world/weather_system.gd): rain/splash/dust for weather
##     emitters, e.g. ParticleLibrary.make(&"rain", 400) then parent it under a
##     moving emitter; ParticleLibrary.spawn(world, &"splash", ground_point, 10)
##   * VFX/abilities: portal/flare/trail for rifts and beams.
## All ids are also discoverable at runtime via get_effect_ids(), and the raw
## texture can be queried with get_texture(id) for custom materials.
##
## Proposed usage:
##   var burst := ParticleLibrary.make(&"explosion", 28)
##   add_child(burst)
##   burst.global_position = hit_point
##   burst.emitting = true
##   get_tree().create_timer(burst.lifetime + 0.3).timeout.connect(burst.queue_free)
## or simply:
##   ParticleLibrary.spawn(self, &"muzzle", muzzle_position, 12)

const TEXTURE_DIR := "res://assets/textures/particles/"

## Logical id -> curated Kenney filename. Keep in sync with the "logical_names"
## map written by tools/fetch_asset_packs.ps1 (tests/assets_test.gd cross-checks
## the two sides). Missing files degrade to _fallback_texture().
const TEXTURE_FILES := {
	&"muzzle": "muzzle_01.png",
	&"impact_metal": "spark_02.png",
	&"impact_dirt": "dirt_01.png",
	&"explosion": "fire_01.png",
	&"dust": "smoke_01.png",
	&"exhaust": "smoke_03.png",
	&"sparks": "spark_05.png",
	&"splash": "circle_02.png",
	&"smoke": "smoke_05.png",
	&"rain": "trace_01.png",
	&"portal": "twirl_01.png",
	&"scorch": "scorch_01.png",
	&"flare": "flare_01.png",
	&"trail": "trace_03.png",
}

## Ids resolved through the procedural fallback when a request is unknown.
const FALLBACK_EFFECT: StringName = &"dust"

static var _effect_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _fallback_cache: Dictionary = {}
static var _fallback_config: Dictionary = {}


# --- Public API ------------------------------------------------------------

## True when `effect_id` is a known logical effect (whether or not the pack PNG
## is present — make() still returns a working node using the fallback texture).
static func has(effect_id: StringName) -> bool:
	return _effects().has(effect_id)


## All logical effect ids, in catalog order.
static func get_effect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _effects().keys():
		ids.append(StringName(key))
	return ids


## Resolved effect colour (used for lights, decals and fallback textures).
static func get_effect_color(effect_id: StringName) -> Color:
	return _config(effect_id).get("color", Color.WHITE)


## Curated PNG path for an effect id ("" when the id only has a fallback).
static func get_texture_path(effect_id: StringName) -> String:
	var file: String = String(TEXTURE_FILES.get(effect_id, ""))
	if file.is_empty():
		return ""
	return TEXTURE_DIR + file


## Texture for an effect id: the curated CC0 PNG, or a procedural soft-dot
## fallback when the pack (or just that PNG) is unavailable. Never null.
static func get_texture(effect_id: StringName) -> Texture2D:
	if _texture_cache.has(effect_id):
		return _texture_cache[effect_id]
	var texture: Texture2D = null
	var path := get_texture_path(effect_id)
	if not path.is_empty():
		texture = load_texture_or_null(path)
	if texture == null:
		texture = _fallback_texture(effect_id)
	_texture_cache[effect_id] = texture
	return texture


## Loads a texture only when it exists as a res:// resource; returns null
## otherwise (no "missing resource" errors in the console).
static func load_texture_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource := load(path)
	if resource is Texture2D:
		var texture := resource as Texture2D
		if texture.get_width() > 0 and texture.get_height() > 0:
			return texture
	return null


## Releases every texture/material held by the static caches. The caches keep
## GPU resources alive for the whole session, which is what we want in gameplay
## and exactly what the engine's exit-time leak check reports in short-lived
## tools/tests. Live particle nodes still reference their material through normal
## refcounting, and the next get_texture()/get_material() call reloads.
static func clear_cache() -> void:
	_texture_cache.clear()
	_material_cache.clear()
	_fallback_cache.clear()


## Same contract as load_texture_or_null() but always returns a valid texture:
## useful for tests and for callers passing arbitrary paths.
static func get_texture_or_fallback(path: String, tint: Color = Color.WHITE) -> Texture2D:
	var texture := load_texture_or_null(path)
	if texture != null:
		return texture
	return _gradient_fallback(tint, Vector2i(64, 64))


## Material for an effect id (StandardMaterial3D, billboarded + alpha blend).
## Cached per id; never null.
static func get_material(effect_id: StringName) -> Material:
	var key := effect_id if _effects().has(effect_id) else FALLBACK_EFFECT
	if _material_cache.has(key):
		return _material_cache[key]
	var config := _config(key)
	var material := StandardMaterial3D.new()
	material.resource_name = "ParticleLibrary/%s" % key
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if config.get("additive", false) else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = get_texture(key)
	_material_cache[key] = material
	return material


## Builds a configured (but not yet emitting) GPUParticles3D for `effect_id`.
## The node is not parented and does not start; the caller adds it, positions it,
## sets `emitting = true` (or calls spawn()). Unknown ids fall back to &"dust"
## while still returning a fully valid node.
static func make(effect_id: StringName, count := 24) -> GPUParticles3D:
	var known := _effects().has(effect_id)
	var key := effect_id if known else FALLBACK_EFFECT
	var config := _config(key)

	var particles := GPUParticles3D.new()
	particles.name = "Particle_%s" % String(effect_id)
	var default_count: int = int(config.get("amount", 24))
	var resolved_count := count if count > 0 else default_count
	particles.amount = clampi(resolved_count, 1, 1000)
	particles.lifetime = float(config.get("lifetime", 0.8))
	particles.one_shot = bool(config.get("one_shot", true))
	particles.explosiveness = float(config.get("explosiveness", 1.0 if particles.one_shot else 0.0))
	particles.randomness = 0.4
	particles.local_coords = bool(config.get("local_coords", false))
	particles.fixed_fps = 0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(
		Vector3(-6.0, -6.0, -6.0),
		Vector3(12.0, 12.0, 12.0)
	)

	particles.process_material = _process_material(key)
	var mesh := QuadMesh.new()
	mesh.size = config.get("size", Vector2(0.3, 0.3))
	mesh.material = get_material(key)
	particles.draw_pass_1 = mesh
	return particles


## Convenience: make + parent + position + start, with automatic cleanup.
## Returns the node (never null when parent is valid). Falls back to a plain
## Node3D parent-safe no-op if `parent` is null/invalid, matching CombatVFX's
## defensive style.
static func spawn(
	parent: Node3D,
	effect_id: StringName,
	position: Vector3,
	count := 0,
	one_shot := true,
	auto_free := true
) -> GPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var particles := make(effect_id, count)
	if not one_shot:
		particles.one_shot = false
		particles.explosiveness = 0.0
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	if auto_free:
		_schedule_free(parent, particles)
	return particles


## Same as spawn() but with a full transform (use for oriented emitters such as
## exhaust pipes or vehicle dust plumes).
static func spawn_transformed(
	parent: Node3D,
	effect_id: StringName,
	transform: Transform3D,
	count := 0,
	one_shot := true,
	auto_free := true
) -> GPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var particles := make(effect_id, count)
	if not one_shot:
		particles.one_shot = false
		particles.explosiveness = 0.0
	parent.add_child(particles)
	particles.global_transform = transform
	particles.emitting = true
	if auto_free:
		_schedule_free(parent, particles)
	return particles


# --- Internals -------------------------------------------------------------

static func _schedule_free(parent: Node3D, particles: GPUParticles3D) -> void:
	if not parent.is_inside_tree():
		# No SceneTreeTimer available; callers own the lifetime in this case.
		return
	var ttl: float = maxf(0.1, particles.lifetime + 0.35)
	var timer := parent.get_tree().create_timer(ttl)
	timer.timeout.connect(particles.queue_free)


static func _config(effect_id: StringName) -> Dictionary:
	var effects := _effects()
	if effects.has(effect_id):
		return effects[effect_id]
	return _fallback_effect()


static func _fallback_effect() -> Dictionary:
	if _fallback_config.is_empty():
		_fallback_config = {
			"color": Color("b9a68c"),
			"size": Vector2(0.5, 0.5),
			"lifetime": 1.2,
			"amount": 16,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 60.0,
			"speed": Vector2(0.8, 1.8),
			"gravity": Vector3(0.0, -0.6, 0.0),
			"damping": Vector2(0.0, 1.0),
			"scale": Vector2(0.7, 1.3),
			"growth": 1.4,
			"emission_radius": 0.2,
			"hold": 0.4,
			"additive": false,
		}
	return _fallback_config


## Single source of truth for effect tuning. Kept as a lazily built table so the
## Color/Vector values stay readable (const expressions are limited).
static func _effects() -> Dictionary:
	if not _effect_cache.is_empty():
		return _effect_cache
	_effect_cache = {
		&"muzzle": {
			"color": Color("ffd89a"),
			"size": Vector2(0.22, 0.22),
			"lifetime": 0.24,
			"amount": 12,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3(0.0, 0.0, 1.0),
			"spread": 18.0,
			"speed": Vector2(0.6, 2.2),
			"gravity": Vector3.ZERO,
			"damping": Vector2(2.0, 4.0),
			"scale": Vector2(0.8, 1.6),
			"growth": 1.1,
			"emission_radius": 0.04,
			"hold": 0.05,
			"additive": true,
			"align_y": false,
			"angular_velocity": Vector2(-90.0, 90.0),
		},
		&"impact_metal": {
			"color": Color("ffc27a"),
			"size": Vector2(0.09, 0.16),
			"lifetime": 0.42,
			"amount": 16,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 70.0,
			"speed": Vector2(3.0, 7.0),
			"gravity": Vector3(0.0, -12.0, 0.0),
			"damping": Vector2(0.0, 1.0),
			"scale": Vector2(0.6, 1.2),
			"growth": 0.5,
			"emission_radius": 0.06,
			"hold": 0.1,
			"additive": true,
			"align_y": true,
			"angular_velocity": Vector2(0.0, 0.0),
		},
		&"impact_dirt": {
			"color": Color("b98a5e"),
			"size": Vector2(0.22, 0.22),
			"lifetime": 0.7,
			"amount": 14,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 55.0,
			"speed": Vector2(1.2, 3.4),
			"gravity": Vector3(0.0, -6.5, 0.0),
			"damping": Vector2(0.0, 1.5),
			"scale": Vector2(0.6, 1.3),
			"growth": 1.2,
			"emission_radius": 0.08,
			"hold": 0.25,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-60.0, 60.0),
		},
		&"explosion": {
			"color": Color("ffb060"),
			"size": Vector2(0.9, 0.9),
			"lifetime": 0.65,
			"amount": 26,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 45.0,
			"speed": Vector2(2.0, 6.0),
			"gravity": Vector3(0.0, 1.2, 0.0),
			"damping": Vector2(1.0, 2.5),
			"scale": Vector2(0.9, 1.8),
			"growth": 2.2,
			"emission_radius": 0.35,
			"hold": 0.1,
			"additive": true,
			"align_y": false,
			"angular_velocity": Vector2(-40.0, 40.0),
		},
		&"dust": {
			"color": Color("b9a68c"),
			"size": Vector2(0.55, 0.55),
			"lifetime": 1.5,
			"amount": 14,
			"one_shot": true,
			"explosiveness": 0.8,
			"direction": Vector3.UP,
			"spread": 70.0,
			"speed": Vector2(0.5, 1.6),
			"gravity": Vector3(0.0, -0.35, 0.0),
			"damping": Vector2(0.6, 1.8),
			"scale": Vector2(0.7, 1.4),
			"growth": 1.8,
			"emission_radius": 0.25,
			"hold": 0.45,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-50.0, 50.0),
		},
		&"exhaust": {
			"color": Color("9aa0a6"),
			"size": Vector2(0.3, 0.3),
			"lifetime": 0.85,
			"amount": 10,
			"one_shot": false,
			"explosiveness": 0.0,
			"direction": Vector3(0.0, 0.0, 1.0),
			"spread": 14.0,
			"speed": Vector2(1.6, 3.2),
			"gravity": Vector3(0.0, 0.5, 0.0),
			"damping": Vector2(1.0, 2.0),
			"scale": Vector2(0.6, 1.2),
			"growth": 1.9,
			"emission_radius": 0.05,
			"hold": 0.3,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-30.0, 30.0),
		},
		&"sparks": {
			"color": Color("ffcf8a"),
			"size": Vector2(0.07, 0.26),
			"lifetime": 0.48,
			"amount": 20,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 80.0,
			"speed": Vector2(4.0, 9.0),
			"gravity": Vector3(0.0, -16.0, 0.0),
			"damping": Vector2(0.0, 0.5),
			"scale": Vector2(0.5, 1.0),
			"growth": 0.4,
			"emission_radius": 0.05,
			"hold": 0.0,
			"additive": true,
			"align_y": true,
			"angular_velocity": Vector2(0.0, 0.0),
		},
		&"splash": {
			"color": Color("a8d8ff"),
			"size": Vector2(0.16, 0.16),
			"lifetime": 0.55,
			"amount": 14,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 40.0,
			"speed": Vector2(1.6, 3.8),
			"gravity": Vector3(0.0, -9.0, 0.0),
			"damping": Vector2(0.0, 0.8),
			"scale": Vector2(0.6, 1.2),
			"growth": 0.7,
			"emission_radius": 0.08,
			"hold": 0.1,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-80.0, 80.0),
		},
		&"smoke": {
			"color": Color("a8a8a8"),
			"size": Vector2(0.85, 0.85),
			"lifetime": 2.2,
			"amount": 18,
			"one_shot": false,
			"explosiveness": 0.0,
			"direction": Vector3.UP,
			"spread": 25.0,
			"speed": Vector2(0.35, 1.1),
			"gravity": Vector3(0.05, 0.4, 0.05),
			"damping": Vector2(1.0, 2.0),
			"scale": Vector2(0.8, 1.5),
			"growth": 2.0,
			"emission_radius": 0.2,
			"hold": 0.5,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-25.0, 25.0),
		},
		&"rain": {
			"color": Color("cfe8ff"),
			"size": Vector2(0.03, 0.5),
			"lifetime": 0.9,
			"amount": 220,
			"one_shot": false,
			"explosiveness": 0.0,
			"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
			"box_extents": Vector3(9.0, 6.0, 9.0),
			"direction": Vector3(0.0, -1.0, 0.0),
			"spread": 5.0,
			"speed": Vector2(9.0, 13.0),
			"gravity": Vector3(0.0, -20.0, 0.0),
			"damping": Vector2(0.0, 0.0),
			"scale": Vector2(0.8, 1.2),
			"growth": 1.0,
			"emission_radius": 0.0,
			"hold": 0.0,
			"additive": false,
			"align_y": true,
			"angular_velocity": Vector2(0.0, 0.0),
			"local_coords": false,
		},
		&"portal": {
			"color": Color("c07bff"),
			"size": Vector2(0.45, 0.45),
			"lifetime": 0.9,
			"amount": 20,
			"one_shot": false,
			"explosiveness": 0.0,
			"direction": Vector3.UP,
			"spread": 30.0,
			"speed": Vector2(0.9, 2.4),
			"gravity": Vector3(0.0, 0.8, 0.0),
			"damping": Vector2(0.5, 1.5),
			"scale": Vector2(0.7, 1.4),
			"growth": 1.3,
			"emission_radius": 0.35,
			"hold": 0.3,
			"additive": true,
			"align_y": false,
			"angular_velocity": Vector2(-120.0, 120.0),
		},
		&"scorch": {
			"color": Color("3a2e26"),
			"size": Vector2(0.5, 0.5),
			"lifetime": 0.5,
			"amount": 10,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 80.0,
			"speed": Vector2(0.8, 2.0),
			"gravity": Vector3(0.0, -1.5, 0.0),
			"damping": Vector2(1.0, 2.0),
			"scale": Vector2(0.8, 1.4),
			"growth": 1.5,
			"emission_radius": 0.15,
			"hold": 0.35,
			"additive": false,
			"align_y": false,
			"angular_velocity": Vector2(-70.0, 70.0),
		},
		&"flare": {
			"color": Color("fff2c0"),
			"size": Vector2(0.4, 0.4),
			"lifetime": 0.2,
			"amount": 8,
			"one_shot": true,
			"explosiveness": 1.0,
			"direction": Vector3.UP,
			"spread": 25.0,
			"speed": Vector2(0.2, 0.8),
			"gravity": Vector3.ZERO,
			"damping": Vector2(2.0, 4.0),
			"scale": Vector2(0.7, 1.3),
			"growth": 1.1,
			"emission_radius": 0.05,
			"hold": 0.0,
			"additive": true,
			"align_y": false,
			"angular_velocity": Vector2(-45.0, 45.0),
		},
		&"trail": {
			"color": Color("b8e6ff"),
			"size": Vector2(0.12, 0.4),
			"lifetime": 0.4,
			"amount": 12,
			"one_shot": false,
			"explosiveness": 0.0,
			"direction": Vector3(0.0, 0.0, 1.0),
			"spread": 12.0,
			"speed": Vector2(0.2, 0.8),
			"gravity": Vector3.ZERO,
			"damping": Vector2(1.0, 2.0),
			"scale": Vector2(0.6, 1.1),
			"growth": 0.4,
			"emission_radius": 0.03,
			"hold": 0.0,
			"additive": true,
			"align_y": true,
			"angular_velocity": Vector2(0.0, 0.0),
		},
	}
	return _effect_cache


static func _process_material(effect_id: StringName) -> ParticleProcessMaterial:
	var config := _config(effect_id)
	var process := ParticleProcessMaterial.new()
	process.resource_name = "ParticleLibrary/%s/process" % effect_id
	process.emission_shape = int(config.get("emission_shape", ParticleProcessMaterial.EMISSION_SHAPE_SPHERE))
	process.emission_sphere_radius = maxf(0.01, float(config.get("emission_radius", 0.1)))
	var box_extents: Vector3 = config.get("box_extents", Vector3(1.0, 1.0, 1.0))
	process.emission_box_extents = box_extents
	process.direction = (config.get("direction", Vector3.UP) as Vector3).normalized()
	process.spread = float(config.get("spread", 45.0))
	var speed: Vector2 = config.get("speed", Vector2(1.0, 2.0))
	if process.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE:
		# Sphere emission already randomises locally; keep it radial.
		process.initial_velocity_min = speed.x
		process.initial_velocity_max = speed.y
	else:
		process.initial_velocity_min = speed.x
		process.initial_velocity_max = speed.y
	process.gravity = config.get("gravity", Vector3(0.0, -9.8, 0.0))
	var damping: Vector2 = config.get("damping", Vector2.ZERO)
	process.damping_min = damping.x
	process.damping_max = damping.y
	var scale_range: Vector2 = config.get("scale", Vector2.ONE)
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	var angular: Vector2 = config.get("angular_velocity", Vector2(-30.0, 30.0))
	process.angular_velocity_min = angular.x
	process.angular_velocity_max = angular.y
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.particle_flag_align_y = bool(config.get("align_y", false))

	var color: Color = config.get("color", Color.WHITE)
	process.color = color
	process.color_ramp = _alpha_ramp(color, float(config.get("hold", 0.3)))
	process.scale_curve = _growth_curve(float(config.get("growth", 1.0)))
	return process


static func _alpha_ramp(color: Color, hold: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	var clamped_hold := clampf(hold, 0.0, 0.95)
	if clamped_hold > 0.001:
		gradient.set_color(0, Color(color, 1.0))
		gradient.add_point(clamped_hold, Color(color, 1.0))
		gradient.add_point(1.0, Color(color, 0.0))
	else:
		gradient.set_color(0, Color(color, 1.0))
		gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture


static func _growth_curve(growth: float) -> CurveTexture:
	var curve := Curve.new()
	var mid := lerpf(1.0, growth, 0.55)
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.55, mid))
	curve.add_point(Vector2(1.0, maxf(0.01, growth)))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


## Procedural soft-dot texture used when the CC0 pack is unavailable. Coloured
## like the effect so the fallback still reads (warm for muzzle/explosion, grey
## for smoke/dust, etc.).
static func _fallback_texture(effect_id: StringName) -> Texture2D:
	if _fallback_cache.has(effect_id):
		return _fallback_cache[effect_id]
	var color: Color = _config(effect_id).get("color", Color.WHITE)
	var texture := _gradient_fallback(color, Vector2i(64, 64))
	_fallback_cache[effect_id] = texture
	return texture


static func _gradient_fallback(tint: Color, size: Vector2i) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(tint, 1.0))
	gradient.set_color(1, Color(tint, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size.x
	texture.height = size.y
	return texture
