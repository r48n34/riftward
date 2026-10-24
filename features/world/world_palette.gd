extends RefCounted
## WORLD PALETTE ??single source of truth for RIFTWARD's frontier look.
##
## Pure data + math helpers. Safe to call from worker threads (no scene tree,
## no editor dependencies). All colors are authored in sRGB.
##
## Palette identity: sunlit alien frontier ??warm ivory structures, rust
## salvage, teal alien growth, ochre canyons, pale glass flats.

# --- Lighting / atmosphere ---------------------------------------------------
const SUN_COLOR := Color(1.0, 0.80, 0.56)
const FILL_COLOR := Color(0.38, 0.58, 0.78)
const SKY_TOP := Color(0.10, 0.19, 0.38)
const SKY_HORIZON := Color(0.88, 0.57, 0.34)
const SKY_GROUND := Color(0.26, 0.19, 0.15)
const FOG_COLOR := Color(0.62, 0.52, 0.43)
const PLANET_BAND_A := Color(0.64, 0.55, 0.42)
const PLANET_BAND_B := Color(0.36, 0.25, 0.19)
const RING_COLOR := Color(0.72, 0.66, 0.55)

# --- Ashen Canyons -----------------------------------------------------------
const ASHEN_ROCK_DARK := Color(0.26, 0.16, 0.10)
const ASHEN_ROCK_MID := Color(0.48, 0.30, 0.16)
const ASHEN_ROCK_LIGHT := Color(0.73, 0.53, 0.31)
const ASHEN_CLIFF := Color(0.40, 0.20, 0.11)
const ASHEN_FLOOR := Color(0.60, 0.44, 0.27)

# --- Verdant Basin -----------------------------------------------------------
const VERDANT_SOIL := Color(0.08, 0.22, 0.19)
const VERDANT_MOSS := Color(0.15, 0.34, 0.25)
const VERDANT_TEAL := Color(0.18, 0.52, 0.42)
const VERDANT_BRIGHT := Color(0.42, 0.72, 0.52)
const VERDANT_STONE := Color(0.45, 0.50, 0.45)

# --- Glass Flats -------------------------------------------------------------
const GLASS_WHITE := Color(0.84, 0.83, 0.76)
const GLASS_PALE := Color(0.66, 0.73, 0.72)
const GLASS_BLUE := Color(0.50, 0.62, 0.65)
const GLASS_CRACK := Color(0.30, 0.35, 0.38)

# --- Infrastructure ----------------------------------------------------------
const PATH_COLOR := Color(0.62, 0.53, 0.40)
const PAD_COLOR := Color(0.72, 0.68, 0.57)
const BORDER_COLOR := Color(0.38, 0.31, 0.26)

# --- Built structures --------------------------------------------------------
const MAT_IVORY := Color(0.80, 0.76, 0.67)
const MAT_IVORY_WARM := Color(0.86, 0.78, 0.63)
const MAT_RUST := Color(0.52, 0.24, 0.12)
const MAT_RUST_DARK := Color(0.32, 0.15, 0.09)
const MAT_STEEL := Color(0.24, 0.26, 0.28)
const MAT_DARK := Color(0.10, 0.11, 0.12)
const MAT_CONCRETE := Color(0.55, 0.53, 0.47)
const MAT_GLASS := Color(0.32, 0.55, 0.58)
const MAT_ALIEN := Color(0.16, 0.48, 0.42)
const MAT_ALIEN_DARK := Color(0.06, 0.20, 0.19)
const MAT_GLOW_TEAL := Color(0.20, 1.0, 0.82)
const MAT_GLOW_AMBER := Color(1.0, 0.60, 0.16)

# --- Marker colors (map texture / integrations) ------------------------------
const MARKER_SPAWN := Color(0.92, 0.94, 0.86)
const MARKER_EXFIL := Color(1.0, 0.66, 0.20)
const MARKER_POI := Color(0.28, 0.92, 0.80)

## Biome weight components (must match world_gen_worker).
const BIOME_VERDANT := 0
const BIOME_ASHEN := 1
const BIOME_GLASS := 2
const BIOME_NAMES: Array[String] = ["Verdant Basin", "Ashen Canyons", "Glass Flats"]


# -----------------------------------------------------------------------------
# Biome weight helpers
# -----------------------------------------------------------------------------

static func dominant_biome(weights: Vector3) -> int:
	if weights.x >= weights.y and weights.x >= weights.z:
		return BIOME_VERDANT
	if weights.y >= weights.z:
		return BIOME_ASHEN
	return BIOME_GLASS


static func biome_name(index: int) -> String:
	if index < 0 or index >= BIOME_NAMES.size():
		return "Unknown"
	return BIOME_NAMES[index]


# -----------------------------------------------------------------------------
# Terrain color functions. `detail_a`/`detail_b`/`macro` are precomputed noise
# fields in [-1, 1]; `slope` is 0 (flat) .. 1 (vertical).
# -----------------------------------------------------------------------------

static func ashen_color(height: float, slope: float, detail_a: float, detail_b: float, macro: float) -> Color:
	var t := clampf((height + 45.0) / 150.0, 0.0, 1.0)
	var col := ASHEN_ROCK_DARK.lerp(ASHEN_ROCK_LIGHT, t)
	# Sediment banding gives the mesas readable strata.
	var band := sin(height * 0.46 + detail_a * 2.4) * 0.5 + 0.5
	col = col.lerp(ASHEN_ROCK_MID, band * 0.34)
	# Steep cliff faces read as exposed rust rock.
	col = col.lerp(ASHEN_CLIFF, clampf(slope * 1.9, 0.0, 1.0) * 0.62)
	# Low canyon floors collect pale dust.
	col = col.lerp(ASHEN_FLOOR, clampf(0.55 - t * 1.3, 0.0, 1.0) * 0.42)
	col = col.darkened(clampf(macro * 0.10 + detail_b * 0.035, 0.0, 0.22))
	return col


static func verdant_color(height: float, slope: float, detail_a: float, detail_b: float, macro: float) -> Color:
	var t := clampf((height + 30.0) / 80.0, 0.0, 1.0)
	var col := VERDANT_SOIL.lerp(VERDANT_MOSS, t)
	var growth := sin(height * 0.20 + detail_a * 3.1) * 0.5 + 0.5
	col = col.lerp(VERDANT_TEAL, growth * 0.48)
	# High ridges catch pale alien growth; cliffs expose grey stone.
	col = col.lerp(VERDANT_BRIGHT, clampf(t - 0.55, 0.0, 1.0) * 0.55)
	col = col.lerp(VERDANT_STONE, clampf(slope * 1.6, 0.0, 1.0) * 0.55)
	col = col.darkened(clampf(detail_b * 0.05 - macro * 0.08, 0.0, 0.16))
	return col


static func glass_color(height: float, slope: float, detail_a: float, detail_b: float, macro: float) -> Color:
	var t := clampf((height + 40.0) / 70.0, 0.0, 1.0)
	var col := GLASS_WHITE.lerp(GLASS_PALE, t * 0.7)
	# Cracked plate seams.
	var cracks := clampf(1.0 - absf(detail_a) * 2.2, 0.0, 1.0)
	col = col.lerp(GLASS_CRACK, cracks * 0.30)
	col = col.lerp(GLASS_BLUE, clampf(slope * 1.2, 0.0, 1.0) * 0.30)
	col = col.darkened(clampf(detail_b * 0.04 + macro * 0.05, 0.0, 0.14))
	return col


## Blended terrain color. `weights` is (verdant, ashen, glass) summing to ~1.
static func blend_terrain_color(weights: Vector3, height: float, slope: float, detail_a: float, detail_b: float, macro: float) -> Color:
	var out := Color(0.0, 0.0, 0.0)
	if weights.x > 0.004:
		out += verdant_color(height, slope, detail_a, detail_b, macro) * weights.x
	if weights.y > 0.004:
		out += ashen_color(height, slope, detail_a, detail_b, macro) * weights.y
	if weights.z > 0.004:
		out += glass_color(height, slope, detail_a, detail_b, macro) * weights.z
	return out


## Cheap topographical map color (UI map). Includes a sun-hillshade term.
static func map_color(weights: Vector3, height: float, slope: float, detail_a: float, detail_b: float, macro: float, path_w: float, shade: float, border: float) -> Color:
	var col := blend_terrain_color(weights, height, slope, detail_a, detail_b, macro)
	# Reading paths on the tactical map matters more than terrain fidelity.
	col = col.lerp(PATH_COLOR, clampf(path_w, 0.0, 1.0) * 0.78)
	# Hillshade (0.0 shadow .. 1.0 lit).
	col = col * lerpf(0.62, 1.22, clampf(shade, 0.0, 1.0))
	# Contour lines every 20m of elevation.
	var contour := absf(fposmod(height, 20.0) - 10.0)
	if contour > 9.35:
		col = col.darkened(0.16)
	# Border containment ridges darken into the fog.
	col = col.lerp(BORDER_COLOR, clampf(border, 0.0, 1.0) * 0.75)
	return col

