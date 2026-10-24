class_name UIIcons
extends RefCounted
## Crisp line-icon catalog. SVGs live in res://assets/icons and are imported by
## Godot as textures; everything is cached and tinted at draw time via modulate.

const ICON_DIR := "res://assets/icons/"

static var _cache: Dictionary = {}


static func get_icon(icon_name: StringName) -> Texture2D:
	var key := String(icon_name)
	if key.is_empty():
		return null
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = null
	var path := ICON_DIR + key + ".svg"
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			texture = res
	_cache[key] = texture
	return texture


static func has_icon(icon_name: StringName) -> bool:
	return get_icon(icon_name) != null


static func get_icon_or(icon_name: StringName, fallback: StringName) -> Texture2D:
	var texture := get_icon(icon_name)
	if texture == null:
		texture = get_icon(fallback)
	return texture


## Ability/perk data uses its own short icon ids; map them onto the bundled set
## with graceful fallbacks so content can add icons without breaking the HUD.
static func ability_icon(icon_name: StringName) -> StringName:
	var mapping := {
		&"arrow": &"arrow-right",
		&"shield": &"shield",
		&"eye": &"eye",
		&"bolt": &"bolt",
		&"lightning": &"bolt",
		&"vortex": &"refresh",
		&"impact": &"warning",
		&"turret": &"outpost",
		&"radar": &"crosshair",
		&"cross": &"heart-pulse",
		&"rocket": &"rocket",
		&"clock": &"timer",
		&"tide": &"shield-check",
		&"ghost": &"eye",
		&"fort": &"grid",
		&"focus": &"target",
		&"diamond": &"star",
		&"heart": &"heart",
		&"wind": &"refresh",
		&"boot": &"arrow-up",
		&"wall": &"shield",
		&"crate": &"backpack",
		&"skull": &"warning",
	}
	var resolved: StringName = mapping.get(icon_name, &"bolt")
	if not has_icon(resolved):
		return &"bolt"
	return resolved
