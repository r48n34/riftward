extends RefCounted
## WORLD ENVIRONMENT — alien sky, warm late-afternoon sun, atmospheric depth.
##
## Builds a WorldEnvironment (custom procedural sky shader), the key directional
## sun, and a cool bounce/rim light. Purely visual; no gameplay dependencies.

const Palette := preload("res://features/world/world_palette.gd")
const SkyShader := preload("res://assets/shaders/world/sky.gdshader")

## Direction from the world toward the sun (unit) — low western sun.
const TO_SUN := Vector3(-0.80, 0.30, -0.52)
## Direction from the world toward the cool fill light.
const TO_FILL := Vector3(0.55, 0.50, 0.66)


## Adds environment nodes as children of `parent` and returns a dict with keys
## "environment", "sun", "fill". Optional `overrides` keys (map presets):
## sky_top, sky_horizon, sky_ground, sun_color, sun_dir, sun_energy,
## fill_color, fog_color, fog_density, volumetric_fog_density. Unknown keys and
## missing values fall back to the default palette.
func setup(parent: Node3D, overrides: Dictionary = {}) -> Dictionary:
	var to_sun: Vector3 = overrides.get("sun_dir", TO_SUN)
	if to_sun.length_squared() < 0.000001:
		to_sun = TO_SUN
	to_sun = to_sun.normalized()
	var sky_top: Color = overrides.get("sky_top", Palette.SKY_TOP)
	var sky_horizon: Color = overrides.get("sky_horizon", Palette.SKY_HORIZON)
	var sky_ground: Color = overrides.get("sky_ground", Palette.SKY_GROUND)
	var sun_color: Color = overrides.get("sun_color", Palette.SUN_COLOR)
	var fill_color: Color = overrides.get("fill_color", Palette.FILL_COLOR)
	var fog_color: Color = overrides.get("fog_color", Palette.FOG_COLOR)
	var sun_energy: float = float(overrides.get("sun_energy", 1.55))
	var fog_density: float = float(overrides.get("fog_density", 0.00028))
	var volumetric_density: float = float(overrides.get("volumetric_fog_density", 0.0035))
	var result := {}
	result["sky_material"] = _make_sky_material(to_sun, sky_top, sky_horizon, sky_ground, sun_color)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = result["sky_material"]
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Warm filmic tone mapping.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0

	# Bloom on emissive tech and sun glints.
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.05

	# Contact shadows for the dense structures.
	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 1.3
	env.ssao_power = 1.4
	env.ssao_detail = 0.6

	# Dusty depth fog: warm near the sun, cool away from it.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog_color
	env.fog_light_energy = 0.55
	env.fog_density = fog_density
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.10
	env.fog_height = 6.0
	env.fog_height_density = 0.0022
	env.fog_sun_scatter = 0.30

	# Volumetric god-rays across the frontier (Forward+).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = volumetric_density
	env.volumetric_fog_albedo = Color(0.90, 0.84, 0.76)
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.10
	env.volumetric_fog_sky_affect = 0.12

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)
	result["environment"] = we

	# --- Sun ---------------------------------------------------------------
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.light_specular = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.07
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.52
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.1
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Directional light travels along its -Z axis; point it away from the sun.
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3(0.0, 120.0, 0.0))
	parent.add_child(sun)
	result["sun"] = sun

	# --- Cool rim/fill light ------------------------------------------------
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = fill_color
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	fill.transform = Transform3D(Basis.looking_at(-TO_FILL.normalized(), Vector3.UP), Vector3(0.0, 80.0, 0.0))
	parent.add_child(fill)
	result["fill"] = fill

	return result


func _make_sky_material(
	to_sun: Vector3,
	sky_top: Color,
	sky_horizon: Color,
	sky_ground: Color,
	sun_color: Color
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SkyShader
	mat.set_shader_parameter("sky_top_color", sky_top)
	mat.set_shader_parameter("sky_horizon_warm", sky_horizon)
	mat.set_shader_parameter("sky_horizon_cool", Color(0.42, 0.50, 0.62))
	mat.set_shader_parameter("ground_color", sky_ground)
	mat.set_shader_parameter("sun_color", sun_color)
	mat.set_shader_parameter("sun_dir", to_sun)
	mat.set_shader_parameter("sun_size", 0.99986)
	mat.set_shader_parameter("planet_dir", Vector3(0.38, 0.44, -0.81).normalized())
	mat.set_shader_parameter("planet_radius", 0.105)
	mat.set_shader_parameter("planet_tilt", 0.30)
	mat.set_shader_parameter("planet_band_a", Palette.PLANET_BAND_A)
	mat.set_shader_parameter("planet_band_b", Palette.PLANET_BAND_B)
	mat.set_shader_parameter("ring_color", Palette.RING_COLOR)
	mat.set_shader_parameter("star_amount", 0.22)
	return mat
