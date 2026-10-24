extends RefCounted
## WORLD GEN WORKER ??pure-data generation that can run on a worker thread.
##
## This file never touches the SceneTree, nodes, physics or the RenderingServer.
## It takes plain Dictionaries / Packed arrays in and returns plain data out, so
## WorldBuilder can keep node creation on the main thread while the expensive
## noise + raster work happens in a Thread.
##
## Coordinate system: X/Z in world meters, Y is up. The height grid is stored
## row-major with idx = iz * (grid_res + 1) + ix, x = -half + ix*cell,
## z = -half + iz*cell.

const Palette := preload("res://features/world/world_palette.gd")

const VERDANT_ANCHOR := Vector2(-380.0, 250.0)
const ASHEN_ANCHOR := Vector2(-70.0, -540.0)
const GLASS_ANCHOR := Vector2(480.0, 190.0)
const BORDER_START := 0.84
const MAP_SUN_DIR := Vector3(-0.50, 0.56, 0.52)

# -----------------------------------------------------------------------------
# PHASE A ??base landforms
# -----------------------------------------------------------------------------

## Builds the raw landform heightmap plus the biome and detail fields.
## Optional p["biome_rotation"] (radians) rotates the three biome anchors around
## the origin; 0.0 preserves the default geography.
## Returns: heights, biome weight grids, detail noise grids.
func build_base_fields(p: Dictionary) -> Dictionary:
	var t_start := Time.get_ticks_msec()
	var map_size: float = float(p.get("map_size", 1800.0))
	var grid_res: int = int(p.get("grid_res", 320))
	var biome_res: int = int(p.get("biome_res", 160))
	var seed_value: int = int(p.get("seed", 12345))
	var half := map_size * 0.5
	var cell := map_size / float(grid_res)
	var pts := grid_res + 1
	var scale := 1800.0 / maxf(map_size, 1.0)

	# Map presets may rotate the three biome anchors around the origin; 0.0 keeps
	# the exact authored geography (the default no-preset path).
	var biome_rotation: float = float(p.get("biome_rotation", 0.0))
	var verdant_anchor := VERDANT_ANCHOR
	var ashen_anchor := ASHEN_ANCHOR
	var glass_anchor := GLASS_ANCHOR
	if not is_zero_approx(biome_rotation):
		verdant_anchor = verdant_anchor.rotated(biome_rotation)
		ashen_anchor = ashen_anchor.rotated(biome_rotation)
		glass_anchor = glass_anchor.rotated(biome_rotation)

	# --- noise fields (created inside the worker thread; read-only afterwards)
	var n_low := _make_noise(seed_value + 11, 0.0009 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM, 4)
	var n_mid := _make_noise(seed_value + 23, 0.0042 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM, 4)
	var n_fine := _make_noise(seed_value + 37, 0.013 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM, 3)
	var n_ridge := _make_noise(seed_value + 41, 0.0022 * scale, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED, 3)
	var n_canyon := _make_noise(seed_value + 53, 0.0036 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_NONE, 1)
	var n_warp := _make_noise(seed_value + 61, 0.0016 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM, 2)
	var n_bio := _make_noise(seed_value + 67, 0.0030 * scale, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM, 2)

	# --- biome weights (lower resolution; smooth regional fields)
	var bpts := biome_res + 1
	var bcell := map_size / float(biome_res)
	var bsize := bpts * bpts
	var w_verdant := PackedFloat32Array()
	var w_ashen := PackedFloat32Array()
	var w_glass := PackedFloat32Array()
	var detail_a := PackedFloat32Array()
	var detail_b := PackedFloat32Array()
	var macro := PackedFloat32Array()
	w_verdant.resize(bsize)
	w_ashen.resize(bsize)
	w_glass.resize(bsize)
	detail_a.resize(bsize)
	detail_b.resize(bsize)
	macro.resize(bsize)

	for iz in bpts:
		var z := -half + float(iz) * bcell
		for ix in bpts:
			var x := -half + float(ix) * bcell
			var wx := x + n_warp.get_noise_2d(x, z) * 235.0
			var wz := z + n_warp.get_noise_2d(x + 731.0, z - 419.0) * 235.0
			var jitter := 1.0 + n_bio.get_noise_2d(x * 1.3, z * 1.3) * 0.32
			var dv := Vector2(wx, wz).distance_squared_to(verdant_anchor)
			var da := Vector2(wx, wz).distance_squared_to(ashen_anchor)
			var dg := Vector2(wx, wz).distance_squared_to(glass_anchor)
			var wv := (1.0 / (dv + 150000.0)) * (1.0 + 0.22 * n_bio.get_noise_2d(x + 300.0, z + 900.0))
			var wa := (1.0 / (da + 150000.0)) * jitter
			var wg := (1.0 / (dg + 150000.0)) * (1.0 + 0.22 * n_bio.get_noise_2d(x - 800.0, z - 200.0))
			var inv := 1.0 / maxf(wv + wa + wg, 0.000001)
			var bidx := iz * bpts + ix
			w_verdant[bidx] = wv * inv
			w_ashen[bidx] = wa * inv
			w_glass[bidx] = wg * inv
			detail_a[bidx] = n_mid.get_noise_2d(x + 1700.0, z - 900.0) * 0.55 + n_fine.get_noise_2d(x - 420.0, z + 1300.0) * 0.45
			detail_b[bidx] = n_fine.get_noise_2d(x * 2.7, z * 2.7)
			macro[bidx] = n_low.get_noise_2d(x - 2500.0, z + 2500.0)

	# --- heightmap
	var heights := PackedFloat32Array()
	heights.resize(pts * pts)
	for iz in pts:
		var z := -half + float(iz) * cell
		for ix in pts:
			var x := -half + float(ix) * cell
			var w := sample_biome(w_verdant, w_ashen, w_glass, biome_res, map_size, x, z)
			var low := n_low.get_noise_2d(x, z)
			var mid := n_mid.get_noise_2d(x, z)
			var fine := n_fine.get_noise_2d(x, z)
			var ridge := n_ridge.get_noise_2d(x, z)
			var canyon := n_canyon.get_noise_2d(x, z)

			# Ashen Canyons ??high terraced mesas carved by winding canyons.
			var ha := 30.0 + low * 1.7 + mid * 1.3
			var step := 12.0
			var hterr := floorf(ha / step) * step
			var frac := clampf((ha - hterr) / step, 0.0, 1.0)
			ha = hterr + smoothstep(0.16, 0.84, frac) * step
			var carve := smoothstep(0.14, 0.60, -canyon)
			ha -= carve * 32.0
			ha += clampf(ridge, 0.0, 1.0) * (7.0 + carve * 12.0)
			ha += smoothstep(0.42, 0.95, clampf(ridge, 0.0, 1.0)) * 16.0

			# Verdant Basin ??low rolling alien growth with soft mounds.
			var hv := -18.0 + low * 1.10 + mid * 2.10 + fine * 1.0
			var mound := clampf(ridge, 0.0, 1.0)
			hv += mound * mound * 20.0
			hv -= smoothstep(0.30, 0.90, -ridge) * 6.0

			# Glass Flats ??nearly planar cracked plate country.
			var hg := -30.0 + low * 0.50 + mid * 0.30 + fine * 0.22
			var crackmask := smoothstep(0.55, 0.92, clampf(ridge * 0.5 + 0.5, 0.0, 1.0))
			hg -= crackmask * 3.0

			var h := w.x * hv + w.y * ha + w.z * hg
			h += mid * 0.45 + fine * 0.65

			# Containment ridge: the frontier rises into impassable mountains.
			var edge := maxf(absf(x), absf(z)) / half
			if edge > BORDER_START:
				var t := (edge - BORDER_START) / (1.0 - BORDER_START)
				h += pow(t, 2.4) * 210.0 + t * 26.0
				h += clampf(ridge, 0.0, 1.0) * t * 68.0
				h += fine * t * 24.0

			heights[iz * pts + ix] = h

	var elapsed := Time.get_ticks_msec() - t_start
	return {
		"heights": heights,
		"grid_res": grid_res,
		"biome_res": biome_res,
		"map_size": map_size,
		"w_verdant": w_verdant,
		"w_ashen": w_ashen,
		"w_glass": w_glass,
		"detail_a": detail_a,
		"detail_b": detail_b,
		"macro": macro,
		"elapsed_ms": elapsed,
	}


# -----------------------------------------------------------------------------
# PHASE B ??pads, roads, final heights, tactical map image
# -----------------------------------------------------------------------------

## Flattens POI/spawn pads, grades the road network into the terrain and renders
## the tactical map texture. Returns final heights + masks + Image.
func build_final_fields(p: Dictionary) -> Dictionary:
	var t_start := Time.get_ticks_msec()
	var heights: PackedFloat32Array = p["heights"]
	var grid_res: int = int(p["grid_res"])
	var map_size: float = float(p["map_size"])
	var pads: Array = p.get("pads", [])
	var links: Array = p.get("links", [])
	var markers: Array = p.get("markers", [])
	var path_width: float = float(p.get("path_width", 7.0))
	var map_tex_res: int = int(p.get("map_tex_res", 256))
	var pts := grid_res + 1
	var total := pts * pts
	var h := heights.duplicate()
	var pad_mask := PackedFloat32Array()
	pad_mask.resize(total)
	var path_mask := PackedFloat32Array()
	path_mask.resize(total)
	var path_hsum := PackedFloat32Array()
	path_hsum.resize(total)
	var path_wsum := PackedFloat32Array()
	path_wsum.resize(total)

	# 1) Pads first so roads can meet their graded height.
	for pad in pads:
		_flatten_pad(h, pad_mask, pad, grid_res, map_size)

	# 2) Roads.
	var half := map_size * 0.5
	var cell := map_size / float(grid_res)
	for poly in links:
		_rasterize_polyline(h, path_wsum, path_hsum, poly, path_width, grid_res, map_size)

	# 3) Grade terrain toward road centerline heights.
	for i in total:
		var w := path_wsum[i]
		if w > 0.00001:
			var target := path_hsum[i] / w
			var blend := clampf(w * 1.15, 0.0, 0.94)
			h[i] = lerpf(h[i], target, blend)
			path_mask[i] = clampf(w, 0.0, 1.0)

	# Legibility at 7m/px beats extra raster detail here; the map is a UI overlay.
	var map_image := _build_map_image(h, p, path_mask, pad_mask, markers, map_tex_res)
	var elapsed := Time.get_ticks_msec() - t_start
	return {
		"heights": h,
		"path_mask": path_mask,
		"pad_mask": pad_mask,
		"map_image": map_image,
		"elapsed_ms": elapsed,
		"half": half,
		"cell": cell,
	}


# -----------------------------------------------------------------------------
# Sampling helpers (static so the main thread can reuse them)
# -----------------------------------------------------------------------------

## Bilinear sample of a height grid. Safe to call from any thread.
static func sample_height_grid(heights: PackedFloat32Array, grid_res: int, map_size: float, x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
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
	return lerpf(lerpf(heights[i00], heights[i10], tx), lerpf(heights[i01], heights[i11], tx), tz)


## Bilinear sample of three biome weight grids at once.
static func sample_biome(wv: PackedFloat32Array, wa: PackedFloat32Array, wg: PackedFloat32Array, biome_res: int, map_size: float, x: float, z: float) -> Vector3:
	if wv.is_empty():
		return Vector3(1.0, 0.0, 0.0)
	var half := map_size * 0.5
	var cell := map_size / float(maxi(biome_res, 1))
	var bpts := biome_res + 1
	var gx := clampf((x + half) / cell, 0.0, float(biome_res))
	var gz := clampf((z + half) / cell, 0.0, float(biome_res))
	var x0 := mini(int(gx), biome_res - 1)
	var z0 := mini(int(gz), biome_res - 1)
	var tx := gx - float(x0)
	var tz := gz - float(z0)
	var i00 := z0 * bpts + x0
	var i10 := i00 + 1
	var i01 := i00 + bpts
	var i11 := i01 + 1
	var vx := lerpf(lerpf(wv[i00], wv[i10], tx), lerpf(wv[i01], wv[i11], tx), tz)
	var vy := lerpf(lerpf(wa[i00], wa[i10], tx), lerpf(wa[i01], wa[i11], tx), tz)
	var vz := lerpf(lerpf(wg[i00], wg[i10], tx), lerpf(wg[i01], wg[i11], tx), tz)
	var s := vx + vy + vz
	if s > 0.00001:
		return Vector3(vx / s, vy / s, vz / s)
	return Vector3(1.0, 0.0, 0.0)


## Bilinear sample of a scalar grid matching the height grid resolution.
static func sample_scalar_grid(grid: PackedFloat32Array, grid_res: int, map_size: float, x: float, z: float) -> float:
	return sample_height_grid(grid, grid_res, map_size, x, z)


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

func _make_noise(seed_value: int, frequency: float, noise_type: int, fractal_type: int, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = noise_type
	n.frequency = frequency
	n.fractal_type = fractal_type
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	return n


## Blends terrain toward a flat construction pad with a soft outer falloff.
func _flatten_pad(h: PackedFloat32Array, pad_mask: PackedFloat32Array, pad: Dictionary, grid_res: int, map_size: float) -> void:
	var center: Vector2 = pad["center"]
	var radius: float = float(pad.get("radius", 16.0))
	var falloff: float = float(pad.get("falloff", 14.0))
	var pts := grid_res + 1
	var cell := map_size / float(grid_res)
	var half := map_size * 0.5
	# Averaged reference height keeps pads from floating or burying.
	var pad_h := sample_height_grid(h, grid_res, map_size, center.x, center.y) * 0.4
	var ring_sum := 0.0
	var ring_count := 0
	for k in 8:
		var ang := TAU * float(k) / 8.0
		ring_sum += sample_height_grid(h, grid_res, map_size, center.x + cos(ang) * radius * 0.6, center.y + sin(ang) * radius * 0.6)
		ring_count += 1
	pad_h += (ring_sum / float(maxi(ring_count, 1))) * 0.6
	# Slight crown so pads drain and read as built-up ground.
	pad_h += 0.35

	var rmax := radius + falloff
	var ix0 := maxi(0, int(floorf((center.x - rmax + half) / cell)) - 1)
	var ix1 := mini(grid_res, int(ceilf((center.x + rmax + half) / cell)) + 1)
	var iz0 := maxi(0, int(floorf((center.y - rmax + half) / cell)) - 1)
	var iz1 := mini(grid_res, int(ceilf((center.y + rmax + half) / cell)) + 1)
	for iz in range(iz0, iz1 + 1):
		var z := -half + float(iz) * cell
		for ix in range(ix0, ix1 + 1):
			var x := -half + float(ix) * cell
			var d := Vector2(x, z).distance_to(center)
			if d > rmax:
				continue
			var w := smoothstep(rmax, radius, d)
			if w <= 0.0:
				continue
			var idx := iz * pts + ix
			h[idx] = lerpf(h[idx], pad_h, w * 0.96)
			pad_mask[idx] = maxf(pad_mask[idx], w)


## Rasterizes a road polyline: accumulates coverage weight and a smoothed
## centerline height target per grid cell.
func _rasterize_polyline(h: PackedFloat32Array, path_wsum: PackedFloat32Array, path_hsum: PackedFloat32Array, poly: PackedVector2Array, width: float, grid_res: int, map_size: float) -> void:
	if poly.size() < 2:
		return
	var pts := grid_res + 1
	var cell := map_size / float(grid_res)
	var half := map_size * 0.5
	var width_half := maxf(width * 0.5, 1.5)
	var influence := width_half * 2.6
	for si in range(poly.size() - 1):
		var a: Vector2 = poly[si]
		var b: Vector2 = poly[si + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.1:
			continue
		var ha := sample_height_grid(h, grid_res, map_size, a.x, a.y)
		var hb := sample_height_grid(h, grid_res, map_size, b.x, b.y)
		var ix0 := maxi(0, int(floorf((minf(a.x, b.x) - influence + half) / cell)) - 1)
		var ix1 := mini(grid_res, int(ceilf((maxf(a.x, b.x) + influence + half) / cell)) + 1)
		var iz0 := maxi(0, int(floorf((minf(a.y, b.y) - influence + half) / cell)) - 1)
		var iz1 := mini(grid_res, int(ceilf((maxf(a.y, b.y) + influence + half) / cell)) + 1)
		var ab := b - a
		var ab_len2 := maxf(ab.length_squared(), 0.0001)
		for iz in range(iz0, iz1 + 1):
			var z := -half + float(iz) * cell
			for ix in range(ix0, ix1 + 1):
				var x := -half + float(ix) * cell
				var p := Vector2(x, z)
				var t := clampf(((p - a).dot(ab)) / ab_len2, 0.0, 1.0)
				var closest := a + ab * t
				var d := p.distance_to(closest)
				if d > influence:
					continue
				var w := smoothstep(influence, width_half * 0.45, d)
				if w <= 0.0:
					continue
				var idx := iz * pts + ix
				path_wsum[idx] += w
				path_hsum[idx] += lerpf(ha, hb, t) * w


## Renders the tactical map overlay: biome colors + hillshade + contours +
## roads + objective rings. Runs inside the worker thread (pure Image data).
func _build_map_image(h: PackedFloat32Array, p: Dictionary, path_mask: PackedFloat32Array, pad_mask: PackedFloat32Array, markers: Array, res: int) -> Image:
	var grid_res: int = int(p["grid_res"])
	var map_size: float = float(p["map_size"])
	var biome_res: int = int(p["biome_res"])
	var wv: PackedFloat32Array = p["w_verdant"]
	var wa: PackedFloat32Array = p["w_ashen"]
	var wg: PackedFloat32Array = p["w_glass"]
	var detail_a: PackedFloat32Array = p["detail_a"]
	var detail_b: PackedFloat32Array = p["detail_b"]
	var macro: PackedFloat32Array = p["macro"]
	var half := map_size * 0.5
	var step := map_size / float(maxi(res - 1, 1))
	var sun := MAP_SUN_DIR.normalized()
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var probe := maxf(map_size / 140.0, 5.0)
	for py in res:
		var z := -half + float(py) * step
		for px in res:
			var x := -half + float(px) * step
			var hh := sample_height_grid(h, grid_res, map_size, x, z)
			var hx := sample_height_grid(h, grid_res, map_size, x + probe, z) - sample_height_grid(h, grid_res, map_size, x - probe, z)
			var hz := sample_height_grid(h, grid_res, map_size, x, z + probe) - sample_height_grid(h, grid_res, map_size, x, z - probe)
			var nrm := Vector3(-hx, probe * 2.0, -hz).normalized()
			var shade := nrm.dot(sun) * 0.5 + 0.5
			var weights := sample_biome(wv, wa, wg, biome_res, map_size, x, z)
			var da := sample_scalar_grid(detail_a, biome_res, map_size, x, z)
			var db := sample_scalar_grid(detail_b, biome_res, map_size, x, z)
			var mc := sample_scalar_grid(macro, biome_res, map_size, x, z)
			var pw := sample_scalar_grid(path_mask, grid_res, map_size, x, z)
			var edge := maxf(absf(x), absf(z)) / half
			var border := 0.0
			if edge > BORDER_START:
				border = clampf((edge - BORDER_START) / (1.0 - BORDER_START), 0.0, 1.0)
			var col := Palette.map_color(weights, hh, 1.0 - nrm.y, da, db, mc, pw, shade, border)
			# Construction pads read as pale cleared ground.
			var pad_w := sample_scalar_grid(pad_mask, grid_res, map_size, x, z)
			col = col.lerp(Palette.PAD_COLOR, pad_w * 0.55)
			img.set_pixel(px, py, Color(col.r, col.g, col.b, 1.0))

	# Objective / spawn / exfil rings.
	for marker in markers:
		var pos: Vector2 = marker.get("pos", Vector2.ZERO)
		var radius: float = float(marker.get("radius", 30.0))
		var kind: String = String(marker.get("kind", "poi"))
		var col := Palette.MARKER_POI
		if kind == "spawn":
			col = Palette.MARKER_SPAWN
		elif kind == "exfil":
			col = Palette.MARKER_EXFIL
		_draw_ring(img, res, half, step, pos, radius, col, 2.0)
		_draw_disc(img, res, half, step, pos, maxf(radius * 0.10, 3.0), col)
	return img


func _draw_ring(img: Image, res: int, half: float, step: float, world: Vector2, radius: float, col: Color, thickness: float) -> void:
	var steps := maxi(24, int(radius * 0.9))
	var ring_px := maxf(radius / step, 4.0)
	for i in steps:
		var ang := TAU * float(i) / float(steps)
		var px := (world.x + cos(ang) * radius + half) / step
		var py := (world.y + sin(ang) * radius + half) / step
		_plot_soft(img, res, int(round(px)), int(round(py)), col, thickness, ring_px)


func _draw_disc(img: Image, res: int, half: float, step: float, world: Vector2, radius: float, col: Color) -> void:
	var r := int(ceilf(radius / step))
	var cx := int(round((world.x + half) / step))
	var cy := int(round((world.y + half) / step))
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			if ox * ox + oy * oy <= r * r:
				_set_px(img, res, cx + ox, cy + oy, col)


func _plot_soft(img: Image, res: int, cx: int, cy: int, col: Color, thickness: float, _scale: float) -> void:
	var t := maxi(1, int(thickness))
	for oy in range(-t, t + 1):
		for ox in range(-t, t + 1):
			if ox * ox + oy * oy > t * t:
				continue
			_set_px(img, res, cx + ox, cy + oy, col)


func _set_px(img: Image, res: int, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= res or y >= res:
		return
	img.set_pixel(x, y, col)

