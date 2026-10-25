extends RefCounted
## TERRAIN WORKER — computes one terrain chunk's vertex data off the main thread.
##
## Each task is handed its own result Dictionary and writes plain Packed arrays
## into it; the main thread only creates the ArrayMesh + collision node after
## all tasks complete. No SceneTree access, no RenderingServer calls.

const Palette := preload("res://features/world/world_palette.gd")
const GenWorker := preload("res://features/world/world_gen_worker.gd")


## Computes a batch of chunks sequentially on the calling thread. Returns an
## Array of per-chunk result Dictionaries (each owned by this thread until the
## thread is joined — no cross-thread mutation).
func compute_chunks_batch(common: Dictionary, chunk_coords: Array) -> Array:
	var out := []
	for coord in chunk_coords:
		var c: Vector2i = coord
		var params := common.duplicate()
		params["cx"] = c.x
		params["cz"] = c.y
		var holder: Dictionary = {}
		compute_chunk(params, holder)
		out.append(holder)
	return out


func compute_chunk(p: Dictionary, holder: Dictionary) -> void:
	var heights: PackedFloat32Array = p["heights"]
	var grid_res: int = p["grid_res"]
	var map_size: float = p["map_size"]
	var biome_res: int = p["biome_res"]
	var quads: int = p["quads"]
	var cx: int = p["cx"]
	var cz: int = p["cz"]
	var wv: PackedFloat32Array = p["w_verdant"]
	var wa: PackedFloat32Array = p["w_ashen"]
	var wg: PackedFloat32Array = p["w_glass"]
	var detail_a: PackedFloat32Array = p["detail_a"]
	var detail_b: PackedFloat32Array = p["detail_b"]
	var macro: PackedFloat32Array = p["macro"]
	var path_mask: PackedFloat32Array = p["path_mask"]
	var pad_mask: PackedFloat32Array = p["pad_mask"]
	var planet_palette: Dictionary = p.get("planet_palette", {})

	var pts := grid_res + 1
	var cell := map_size / float(grid_res)
	var half := map_size * 0.5
	var n := quads + 1
	var i0 := cx * quads
	var j0 := cz * quads
	var count := n * n

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(count)
	norms.resize(count)
	colors.resize(count)
	indices.resize(quads * quads * 6)

	var vi := 0
	for j in n:
		var iz := j0 + j
		var z := -half + float(iz) * cell
		var row := iz * pts
		for i in n:
			var ix := i0 + i
			var x := -half + float(ix) * cell
			var idx := row + ix
			var h := heights[idx]
			verts[vi] = Vector3(x, h, z)

			# Analytic smooth normal from the height grid.
			var hl := heights[row + maxi(ix - 1, 0)]
			var hr := heights[row + mini(ix + 1, grid_res)]
			var hd := heights[maxi(iz - 1, 0) * pts + ix]
			var hu := heights[mini(iz + 1, grid_res) * pts + ix]
			var nx := (hl - hr) / (2.0 * cell)
			var nz := (hd - hu) / (2.0 * cell)
			var nrm := Vector3(nx, 1.0, nz).normalized()
			norms[vi] = nrm

			var weights := GenWorker.sample_biome(wv, wa, wg, biome_res, map_size, x, z)
			var slope := 1.0 - clampf(nrm.y, 0.0, 1.0)
			var da := GenWorker.sample_scalar_grid(detail_a, biome_res, map_size, x, z)
			var db := GenWorker.sample_scalar_grid(detail_b, biome_res, map_size, x, z)
			var mc := GenWorker.sample_scalar_grid(macro, biome_res, map_size, x, z)
			var col := Palette.blend_terrain_color(weights, h, slope, da, db, mc, planet_palette)

			# Cheap cavity darkening for rock folds and canyon floors.
			var avg := (hl + hr + hd + hu) * 0.25
			var ao := clampf((avg - h) * 0.055, 0.0, 0.26)
			col = col.darkened(ao)

			# Roads and construction pads read as cleared, graded ground.
			var pw := GenWorker.sample_scalar_grid(path_mask, grid_res, map_size, x, z)
			if pw > 0.002:
				col = col.lerp(Palette.PATH_COLOR, clampf(pw, 0.0, 1.0) * 0.55)
			var padw := GenWorker.sample_scalar_grid(pad_mask, grid_res, map_size, x, z)
			if padw > 0.002:
				col = col.lerp(Palette.PAD_COLOR, clampf(padw, 0.0, 1.0) * 0.72)

			# Containment ridges fade into the boundary rock color.
			var edge := maxf(absf(x), absf(z)) / half
			if edge > 0.84:
				col = col.lerp(Palette.BORDER_COLOR, clampf((edge - 0.84) / 0.16, 0.0, 1.0) * 0.7)
			colors[vi] = col
			vi += 1

	# Triangle indices with alternating diagonals to avoid a visible grid pattern.
	# Godot uses clockwise winding for front faces; these triangles face +Y.
	var ii := 0
	for j in quads:
		for i in quads:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			if (i + j) % 2 == 0:
				indices[ii] = a
				indices[ii + 1] = b
				indices[ii + 2] = c
				ii += 3
				indices[ii] = b
				indices[ii + 1] = d
				indices[ii + 2] = c
				ii += 3
			else:
				indices[ii] = a
				indices[ii + 1] = b
				indices[ii + 2] = d
				ii += 3
				indices[ii] = a
				indices[ii + 1] = d
				indices[ii + 2] = c
				ii += 3

	holder["verts"] = verts
	holder["norms"] = norms
	holder["colors"] = colors
	holder["indices"] = indices
	holder["cx"] = cx
	holder["cz"] = cz
