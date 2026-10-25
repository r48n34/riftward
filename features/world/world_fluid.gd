extends RefCounted
## WORLD FLUID — builds the visible water/lava surfaces for seeded terrain basins.
##
## The height field is carved into bowls by WorldGenWorker; this class turns the
## resulting fluid mask into one merged surface mesh per basin (a handful of draw
## calls) plus lava glow lights. Gameplay never uses these meshes for collision:
## Player/EnemyAgent query WorldBuilder.sample_fluid() analytically.

const WaterShader := preload("res://assets/shaders/world/water.gdshader")
const LavaShader := preload("res://assets/shaders/world/lava.gdshader")

const FLUID_NONE := 0
const FLUID_WATER := 1
const FLUID_LAVA := 2


## `basins` entries: {center: Vector2, radius: float, falloff: float, level: float,
## depth: float, type: int}. `fluid_mask` is the grid_res+1 square shore/deep mask.
## Returns {basins: int, meshes: int, vertices: int, lights: int}.
func build(
	root: Node3D,
	basins: Array,
	fluid_mask: PackedFloat32Array,
	heights: PackedFloat32Array,
	grid_res: int,
	map_size: float
) -> Dictionary:
	var stats := {"basins": 0, "meshes": 0, "vertices": 0, "lights": 0}
	if basins.is_empty() or fluid_mask.is_empty() or grid_res <= 0:
		return stats
	var water_material := _water_material()
	var lava_material := _lava_material()
	for basin in basins:
		if not (basin is Dictionary):
			continue
		var fluid_type := int(basin.get("type", FLUID_WATER))
		var mesh := _build_basin_mesh(basin, fluid_mask, grid_res, map_size)
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Fluid_%02d_%s" % [int(stats["basins"]), "lava" if fluid_type == FLUID_LAVA else "water"]
		instance.mesh = mesh
		instance.material_override = lava_material if fluid_type == FLUID_LAVA else water_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		stats["basins"] = int(stats["basins"]) + 1
		stats["meshes"] = int(stats["meshes"]) + 1
		stats["vertices"] = int(stats["vertices"]) + int(mesh.surface_get_array_len(0))
		if fluid_type == FLUID_LAVA:
			stats["lights"] = int(stats["lights"]) + _add_lava_lights(root, basin)
	return stats


func _build_basin_mesh(
	basin: Dictionary,
	fluid_mask: PackedFloat32Array,
	grid_res: int,
	map_size: float
) -> ArrayMesh:
	var center: Vector2 = basin.get("center", Vector2.ZERO)
	var radius: float = float(basin.get("radius", 40.0)) + float(basin.get("falloff", 14.0))
	var level: float = float(basin.get("level", 0.0))
	var half := map_size * 0.5
	# Build at 2x the height-grid resolution so shorelines read as curves rather
	# than blocky grid steps; the basin footprint is small, so the cost is modest.
	var res := grid_res * 2
	var step := map_size / float(res)
	var ix0 := maxi(0, int(floorf((center.x - radius + half) / step)))
	var ix1 := mini(res, int(ceilf((center.x + radius + half) / step)))
	var iz0 := maxi(0, int(floorf((center.y - radius + half) / step)))
	var iz1 := mini(res, int(ceilf((center.y + radius + half) / step)))
	if ix1 <= ix0 or iz1 <= iz0:
		return null
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for iz in range(iz0, iz1):
		for ix in range(ix0, ix1):
			var x0 := -half + float(ix) * step
			var z0 := -half + float(iz) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var m00 := _mask_at(fluid_mask, grid_res, map_size, x0, z0)
			var m10 := _mask_at(fluid_mask, grid_res, map_size, x1, z0)
			var m01 := _mask_at(fluid_mask, grid_res, map_size, x0, z1)
			var m11 := _mask_at(fluid_mask, grid_res, map_size, x1, z1)
			var m := maxf(maxf(m00, m10), maxf(m01, m11))
			if m <= 0.001:
				continue
			var base := verts.size()
			verts.append(Vector3(x0, level, z0))
			verts.append(Vector3(x1, level, z0))
			verts.append(Vector3(x1, level, z1))
			verts.append(Vector3(x0, level, z1))
			for k in 4:
				normals.append(Vector3.UP)
			colors.append(Color(1.0, 1.0, 1.0, clampf(m00 * 1.6, 0.0, 1.0)))
			colors.append(Color(1.0, 1.0, 1.0, clampf(m10 * 1.6, 0.0, 1.0)))
			colors.append(Color(1.0, 1.0, 1.0, clampf(m11 * 1.6, 0.0, 1.0)))
			colors.append(Color(1.0, 1.0, 1.0, clampf(m01 * 1.6, 0.0, 1.0)))
			indices.append(base)
			indices.append(base + 1)
			indices.append(base + 3)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 3)
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _mask_at(mask: PackedFloat32Array, grid_res: int, map_size: float, x: float, z: float) -> float:
	var half := map_size * 0.5
	var cell := map_size / float(maxi(grid_res, 1))
	var pts := grid_res + 1
	var gx := clampf((x + half) / cell, 0.0, float(grid_res))
	var gz := clampf((z + half) / cell, 0.0, float(grid_res))
	var x0 := mini(int(gx), grid_res - 1)
	var z0 := mini(int(gz), grid_res - 1)
	var tx := gx - float(x0)
	var tz := gz - float(z0)
	var i00 := z0 * pts + x0
	var i10 := i00 + 1
	var i01 := i00 + pts
	var i11 := i01 + 1
	return lerpf(lerpf(mask[i00], mask[i10], tx), lerpf(mask[i01], mask[i11], tx), tz)


func _add_lava_lights(root: Node3D, basin: Dictionary) -> int:
	var center: Vector2 = basin.get("center", Vector2.ZERO)
	var level: float = float(basin.get("level", 0.0))
	var radius: float = float(basin.get("radius", 40.0))
	var count := 0
	for i in 2:
		var light := OmniLight3D.new()
		light.name = "LavaGlow_%d" % i
		light.light_color = Color(1.0, 0.38, 0.10)
		light.light_energy = 1.7
		light.omni_range = minf(radius * 1.2, 42.0)
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		var offset := Vector2(cos(float(i) * 2.4), sin(float(i) * 2.4)) * radius * 0.35
		light.position = Vector3(center.x + offset.x, level + 2.2, center.y + offset.y)
		root.add_child(light)
		count += 1
	return count


func _water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WaterShader
	return material


func _lava_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LavaShader
	return material
