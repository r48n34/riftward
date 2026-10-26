extends RefCounted
## WORLD MATERIALS ??procedural material library for the frontier.
##
## No external textures: surface grain comes from FastNoiseLite images baked at
## generation time, and per-vertex/per-instance color does the biome tinting.
## All materials are built once on the main thread and shared by reference.

const Palette := preload("res://features/world/world_palette.gd")

var mats: Dictionary = {}
var detail_strong: ImageTexture
var detail_soft: ImageTexture


func _init() -> void:
	_build_detail_textures()
	_build_materials()


func get_mat(key: StringName) -> Material:
	return mats.get(key, null)


func _build_detail_textures() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 90210
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var src := noise.get_seamless_image(256, 256, false, false, 0.18)
	detail_strong = ImageTexture.create_from_image(_remap_gray(src, 0.70, 1.0))
	detail_soft = ImageTexture.create_from_image(_remap_gray(src, 0.82, 1.0))


func _remap_gray(src: Image, low: float, high: float) -> Image:
	var img := Image.create(src.get_width(), src.get_height(), true, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var v := src.get_pixel(x, y).r
			var g := lerpf(low, high, v)
			img.set_pixel(x, y, Color(g, g, g, 1.0))
	img.generate_mipmaps()
	return img


func _mat(albedo: Color, roughness: float, metallic: float, key: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	mats[key] = m
	return m


func _mat_textured(albedo: Color, roughness: float, metallic: float, key: StringName, tex_scale: float, tex: ImageTexture) -> StandardMaterial3D:
	var m := _mat(albedo, roughness, metallic, key)
	m.albedo_texture = tex
	m.texture_repeat = true
	m.uv1_scale = Vector3(tex_scale, tex_scale, tex_scale)
	return m


func _mat_glow(albedo: Color, emission: Color, energy: float, key: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.rim_enabled = true
	m.rim = 0.4
	mats[key] = m
	return m


func _build_materials() -> void:
	# --- Terrain: vertex-color biomes + triplanar rock grain -----------------
	var terrain := StandardMaterial3D.new()
	terrain.albedo_texture = detail_strong
	terrain.texture_repeat = true
	terrain.uv1_triplanar = true
	terrain.uv1_scale = Vector3(0.20, 0.20, 0.20)
	terrain.vertex_color_use_as_albedo = true
	terrain.roughness = 0.94
	terrain.metallic = 0.0
	terrain.metallic_specular = 0.30
	mats[&"terrain"] = terrain

	# --- Architecture -------------------------------------------------------
	_mat_textured(Palette.MAT_IVORY, 0.62, 0.05, &"ivory", 0.6, detail_soft)
	_mat_textured(Palette.MAT_IVORY_WARM, 0.55, 0.06, &"ivory_warm", 0.6, detail_soft)
	_mat_textured(Palette.MAT_CONCRETE, 0.88, 0.0, &"concrete", 0.9, detail_soft)
	_mat_textured(Palette.MAT_RUST, 0.78, 0.25, &"rust", 1.3, detail_soft)
	_mat_textured(Palette.MAT_RUST_DARK, 0.82, 0.30, &"rust_dark", 1.5, detail_soft)
	_mat_textured(Palette.MAT_STEEL, 0.42, 0.72, &"steel", 1.0, detail_soft)
	_mat(Palette.MAT_DARK, 0.50, 0.55, &"dark")
	_mat(Palette.MAT_GLASS, 0.18, 0.55, &"glass")
	_mat(Palette.MAT_ALIEN, 0.70, 0.05, &"alien")
	_mat(Palette.MAT_ALIEN_DARK, 0.80, 0.0, &"alien_dark")
	_mat(Palette.MAT_RUST.darkened(0.25), 1.0, 0.0, &"fabric")
	_mat(Palette.PAD_COLOR, 0.72, 0.05, &"pad")
	_mat(Color(0.10, 0.09, 0.08), 1.0, 0.0, &"scorch")
	var rock_solid := StandardMaterial3D.new()
	rock_solid.albedo_color = Color(0.52, 0.42, 0.32)
	rock_solid.roughness = 0.95
	rock_solid.vertex_color_use_as_albedo = true
	rock_solid.metallic_specular = 0.22
	mats[&"rock_solid"] = rock_solid
	_mat_glow(Color(0.05, 0.20, 0.18), Palette.MAT_GLOW_TEAL, 2.6, &"glow_teal")
	_mat_glow(Color(0.22, 0.12, 0.04), Palette.MAT_GLOW_AMBER, 2.2, &"glow_amber")
	_mat_glow(Color(0.16, 0.05, 0.02), Color(1.0, 0.35, 0.10), 1.8, &"glow_ember")
	_mat_glow(Color(0.02, 0.18, 0.15), Palette.MAT_GLOW_TEAL, 1.5, &"warden_eye")

	# --- Scatter (instance colors tint these) -------------------------------
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = detail_soft
	rock.texture_repeat = true
	rock.uv1_triplanar = true
	rock.uv1_scale = Vector3(0.42, 0.42, 0.42)
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.92
	rock.metallic_specular = 0.25
	mats[&"rock"] = rock

	var crystal := StandardMaterial3D.new()
	crystal.vertex_color_use_as_albedo = true
	crystal.roughness = 0.16
	crystal.metallic = 0.35
	crystal.rim_enabled = true
	crystal.rim = 0.8
	crystal.emission_enabled = true
	crystal.emission = Color(0.55, 0.92, 0.90)
	crystal.emission_energy_multiplier = 0.22
	mats[&"crystal"] = crystal

	var trunk := StandardMaterial3D.new()
	trunk.albedo_color = Palette.MAT_ALIEN_DARK
	trunk.roughness = 0.85
	trunk.vertex_color_use_as_albedo = true
	mats[&"flora_trunk"] = trunk

	var canopy := StandardMaterial3D.new()
	canopy.albedo_color = Color(0.28, 0.72, 0.58)
	canopy.roughness = 0.65
	canopy.vertex_color_use_as_albedo = true
	canopy.emission_enabled = true
	canopy.emission = Palette.MAT_GLOW_TEAL
	canopy.emission_energy_multiplier = 0.12
	canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[&"flora_canopy"] = canopy

	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.40, 0.74, 0.58)
	grass.roughness = 0.9
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[&"grass"] = grass

	var spore := StandardMaterial3D.new()
	spore.albedo_color = Color(0.12, 0.45, 0.42)
	spore.emission_enabled = true
	spore.emission = Palette.MAT_GLOW_TEAL
	spore.emission_energy_multiplier = 1.6
	spore.roughness = 0.4
	mats[&"spore"] = spore

	var glass_shard := StandardMaterial3D.new()
	glass_shard.albedo_color = Color(0.72, 0.86, 0.88, 1.0)
	glass_shard.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	glass_shard.vertex_color_use_as_albedo = true
	glass_shard.roughness = 0.10
	glass_shard.metallic = 0.55
	glass_shard.rim_enabled = true
	glass_shard.rim = 1.0
	mats[&"glass_shard"] = glass_shard

	# --- Road markers -------------------------------------------------------
	var pylon := StandardMaterial3D.new()
	pylon.albedo_color = Palette.MAT_IVORY_WARM
	pylon.roughness = 0.5
	pylon.metallic = 0.2
	pylon.vertex_color_use_as_albedo = true
	mats[&"pylon"] = pylon

	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.1, 0.4, 0.36)
	lamp.emission_enabled = true
	lamp.emission = Palette.MAT_GLOW_TEAL
	lamp.emission_energy_multiplier = 3.0
	lamp.vertex_color_use_as_albedo = true
	mats[&"lamp"] = lamp

	# --- POI clutter (barrels / crates / pallets / spools / debris) ---------
	# Instanced props tint their material per instance, so clutter reuses one
	# material and stays at a handful of draw calls across the whole map.
	var clutter := StandardMaterial3D.new()
	clutter.albedo_texture = detail_soft
	clutter.texture_repeat = true
	clutter.uv1_triplanar = true
	clutter.uv1_scale = Vector3(1.1, 1.1, 1.1)
	clutter.vertex_color_use_as_albedo = true
	clutter.roughness = 0.78
	clutter.metallic = 0.10
	clutter.metallic_specular = 0.32
	mats[&"clutter"] = clutter







