class_name UIFonts
extends RefCounted
## Bundled typefaces, loaded once and cached. Variable fonts are wrapped in
## FontVariation so each weight is a cheap shared Font resource.
##   Sora         - display / headings (variable wght 100-800)
##   Inter        - body / UI copy (variable opsz+wght)
##   JetBrains Mono - numbers, ammo, timers (static regular + bold)

const SORA_PATH := "res://assets/fonts/Sora/Sora-Variable.ttf"
const INTER_PATH := "res://assets/fonts/Inter/Inter-Variable.ttf"
const MONO_REGULAR_PATH := "res://assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
const MONO_BOLD_PATH := "res://assets/fonts/JetBrainsMono/JetBrainsMono-Bold.ttf"

static var _base: Dictionary = {}
static var _cache: Dictionary = {}


static func _base_font(path: String) -> Font:
	if _base.has(path):
		return _base[path]
	var font: Font = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			font = res
	_base[path] = font
	return font


static func _variable(path: String, axes: Dictionary) -> Font:
	var key := "%s|%s" % [path, str(axes)]
	if _cache.has(key):
		return _cache[key]
	var base := _base_font(path)
	if base == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = axes
	_cache[key] = variation
	return variation


static func _static(path: String) -> Font:
	var key := path
	if _cache.has(key):
		return _cache[key]
	var font := _base_font(path)
	_cache[key] = font
	return font


## Sora, 100-800. 600 is the editorial heading weight.
static func display(weight: int = 600) -> Font:
	return _variable(SORA_PATH, {"wght": float(weight)})


## Inter, 100-900.
static func body(weight: int = 400) -> Font:
	return _variable(INTER_PATH, {"wght": float(weight)})


## JetBrains Mono.
static func mono(bold: bool = false) -> Font:
	var font := _static(MONO_BOLD_PATH if bold else MONO_REGULAR_PATH)
	if font == null:
		font = _static(MONO_REGULAR_PATH if bold else MONO_BOLD_PATH)
	return font


static func is_available() -> bool:
	return _base_font(SORA_PATH) != null and _base_font(INTER_PATH) != null
