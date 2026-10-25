class_name UIItemArt
extends Control
## Code-drawn item art for loadout, inventory, squad and salvage UI. Weapons
## resolve their silhouette family from ContentDB WeaponData.style/archetype;
## gear draws a silhouette per slot. Drawing is vector-only, static, deterministic
## and scales cleanly from 32x24 thumbnails up to large hero tiles.

const DESIGN_SIZE := Vector2(64.0, 36.0)
const GEAR_SLOTS := ["helmet", "chest", "legs", "cloak", "charm"]
const KNIFE_IDS := ["knife", "combat_knife", "blade", "standard_knife", "trench_knife"]

var kind := ""
var slot := ""
var base_id := ""
var rarity_color: Color = Color.TRANSPARENT
var accent: Color = UIPalette.mint
var compact := false

var _family := "rifle"
var _art_key := "weapon:empty"
var _empty := true
var _fallback := false
var _weapon: WeaponData = null
var _weapon_style: StringName = &""
var _body := UIPalette.muted
var _body_dark := UIPalette.surface_high
var _body_light := UIPalette.ivory
var _detail := UIPalette.mint
var _outline := Color(1.0, 1.0, 1.0, 0.45)
var _offset := Vector2.ZERO
var _scale := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 24)
	resized.connect(queue_redraw)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Resolve one piece of item art.
##   kind      "weapon"/"gear"/"knife" (empty is inferred from slot/base id)
##   slot      weapon slot or gear slot ("helmet", "chest", "legs", "cloak", "charm")
##   base_id   ContentDB weapon id for weapons; empty draws a greyed placeholder
##   rarity_color draws the top-right rarity corner (transparent falls back to accent)
##   accent    detail/energy tint
func configure(
	kind: String,
	slot: String,
	base_id: String,
	rarity_color: Color,
	accent: Color,
	compact: bool = false
) -> void:
	self.kind = kind.to_lower()
	self.slot = slot.to_lower()
	self.base_id = base_id
	self.rarity_color = rarity_color
	self.accent = accent if accent.a > 0.001 else UIPalette.mint
	self.compact = compact
	custom_minimum_size = Vector2(32, 24)
	_resolve_art()
	queue_redraw()


func get_art_key() -> String:
	return _art_key


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

func _resolve_art() -> void:
	_weapon = null
	_weapon_style = &""
	_fallback = false
	_empty = base_id.strip_edges().is_empty()
	var lower_id := base_id.to_lower()
	var is_knife := kind == "knife" or slot == "knife" or slot == "melee" or lower_id in KNIFE_IDS
	if is_knife:
		kind = "weapon"
		_family = "knife"
		_art_key = "weapon:knife"
		_empty = false
		_set_palette(Color("d9e2e4"), accent)
		return
	if kind == "gear" or slot in GEAR_SLOTS:
		kind = "gear"
		var gear_slot := slot if slot in GEAR_SLOTS else "charm"
		_family = gear_slot
		_art_key = "gear:%s" % gear_slot
		if _empty:
			_set_palette(UIPalette.muted_dim, UIPalette.muted_dim)
		else:
			_set_palette(UIPalette.mix(UIPalette.surface_high, accent, 0.35), accent)
		return
	kind = "weapon"
	if ContentDB != null and not base_id.is_empty():
		_weapon = ContentDB.get_weapon(StringName(base_id))
	if _weapon != null:
		_weapon_style = _weapon.style if _weapon.style != &"" else _weapon.archetype
		_family = _weapon_family(_weapon_style)
		_art_key = "weapon:%s" % _family
		_empty = false
		_set_palette(_weapon.color, _weapon.accent)
		return
	# No WeaponData (unknown id or knife without a resource).
	_family = "rifle"
	if _empty:
		_art_key = "weapon:empty"
		_set_palette(UIPalette.muted_dim, UIPalette.muted_dim)
	else:
		_art_key = "weapon:rifle"
		_fallback = true
		_set_palette(UIPalette.muted, UIPalette.muted_dim)


static func _weapon_family(style: StringName) -> String:
	match String(style).to_lower():
		"smg":
			return "smg"
		"dmr", "sniper", "rail", "marksman", "arc":
			return "dmr"
		"shotgun":
			return "shotgun"
		"pistol", "sidearm":
			return "pistol"
		"lmg", "hmg", "mg":
			return "lmg"
		"launcher", "gl", "rocket", "flamer":
			return "launcher"
		"knife", "blade", "melee":
			return "knife"
		_:
			return "rifle"


func _set_palette(base: Color, detail: Color) -> void:
	var tint := base if base.a > 0.001 else UIPalette.muted
	var luminance := tint.r * 0.2126 + tint.g * 0.7152 + tint.b * 0.0722
	if luminance < 0.26:
		tint = UIPalette.mix(tint, UIPalette.ivory, 0.34)
	elif luminance > 0.95:
		tint = UIPalette.mix(tint, UIPalette.surface_high, 0.16)
	_body = tint
	_body_dark = UIPalette.darken(tint, 0.2)
	_body_light = UIPalette.brighten(tint, 0.22)
	_detail = detail if detail.a > 0.001 else accent
	if _detail.a <= 0.001:
		_detail = accent
	_outline = UIPalette.alpha(UIPalette.mix(UIPalette.ivory, tint, 0.35), 0.55)


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return _offset + Vector2(x, y) * _scale


func _fill(values: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for value in values:
		var point: Vector2 = value
		points.append(_p(point.x, point.y))
	draw_colored_polygon(points, color)


func _stroke(values: Array, color: Color, width: float = 1.0, closed: bool = true) -> void:
	var points := PackedVector2Array()
	for value in values:
		var point: Vector2 = value
		points.append(_p(point.x, point.y))
	if closed and points.size() > 1:
		points.append(points[0])
	draw_polyline(points, color, maxf(1.0, width * _scale), true)


func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), color, maxf(1.0, width * _scale), true)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(_p(x, y), Vector2(w, h) * _scale), color)


func _circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(_p(center.x, center.y), maxf(0.6, radius * _scale), color)


func _draw() -> void:
	var area := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	if area.size.x < 6.0 or area.size.y < 5.0:
		return
	_scale = minf(area.size.x / DESIGN_SIZE.x, area.size.y / DESIGN_SIZE.y)
	if _scale <= 0.0:
		return
	_offset = area.position + (area.size - DESIGN_SIZE * _scale) * 0.5
	match _family:
		"rifle":
			_draw_rifle()
		"smg":
			_draw_smg()
		"dmr":
			_draw_dmr()
		"shotgun":
			_draw_shotgun()
		"pistol":
			_draw_pistol()
		"lmg":
			_draw_lmg()
		"launcher":
			_draw_launcher()
		"knife":
			_draw_knife()
		"helmet":
			_draw_helmet()
		"chest":
			_draw_chest()
		"legs":
			_draw_legs()
		"cloak":
			_draw_cloak()
		"charm":
			_draw_charm()
		_:
			_draw_gear_fallback()
	_draw_rarity_corner()
	if _empty:
		_draw_empty_mark(area)


# --- Weapon silhouettes ----------------------------------------------------

func _draw_rifle() -> void:
	_fill([Vector2(6.5, 17.5), Vector2(15, 15), Vector2(16, 21.5), Vector2(9, 23)], _body_dark)
	_stroke([Vector2(6.5, 17.5), Vector2(15, 15), Vector2(16, 21.5), Vector2(9, 23)], _outline, 0.7)
	_fill([Vector2(14, 13.5), Vector2(34.5, 13.5), Vector2(35.5, 20.5), Vector2(14, 21.5)], _body)
	_stroke([Vector2(14, 13.5), Vector2(34.5, 13.5), Vector2(35.5, 20.5), Vector2(14, 21.5)], _outline, 0.8)
	_line(Vector2(16, 13), Vector2(33, 13), _detail, 0.8)
	_fill([Vector2(34, 15), Vector2(45, 15), Vector2(45, 19.5), Vector2(34, 19.5)], _body_dark)
	_stroke([Vector2(34, 15), Vector2(45, 15), Vector2(45, 19.5), Vector2(34, 19.5)], _outline, 0.6)
	_rect(45, 16.3, 13.5, 2.2, _body_light)
	_rect(57.5, 15.2, 3, 4.5, _body_dark)
	_line(Vector2(51.5, 16.2), Vector2(51.5, 13.4), _body_light, 1.0)
	_fill([Vector2(22, 21), Vector2(28.5, 21), Vector2(27.5, 28.5), Vector2(24, 30), Vector2(21, 23.5)], _body_dark)
	_stroke([Vector2(22, 21), Vector2(28.5, 21), Vector2(27.5, 28.5), Vector2(24, 30), Vector2(21, 23.5)], _outline, 0.7)
	_line(Vector2(23, 23.8), Vector2(26.5, 23.8), _detail, 0.9)
	_fill([Vector2(16.5, 21), Vector2(21, 21), Vector2(19, 27.5), Vector2(14.5, 26.5)], _body_dark)
	_stroke([Vector2(16.5, 21), Vector2(21, 21), Vector2(19, 27.5), Vector2(14.5, 26.5)], _outline, 0.7)
	if not compact:
		_line(Vector2(19.8, 21.2), Vector2(21.6, 24.6), _outline, 0.7)
		_line(Vector2(21.6, 24.6), Vector2(24.6, 23.4), _outline, 0.7)
	_rect(24, 8.6, 10.5, 4.2, _body_dark)
	_stroke([Vector2(24, 8.6), Vector2(34.5, 8.6), Vector2(34.5, 12.8), Vector2(24, 12.8)], _outline, 0.6)
	_rect(25, 9.2, 8.5, 3.0, UIPalette.alpha(UIPalette.ink, 0.55))
	_line(Vector2(26.5, 12.8), Vector2(26.5, 13.6), _outline, 0.8)
	_line(Vector2(32.5, 12.8), Vector2(32.5, 13.6), _outline, 0.8)
	_circle(Vector2(34.2, 10.8), 1.7, _detail)
	_circle(Vector2(29, 17.3), 1.2, _detail)
	if compact:
		return
	_line(Vector2(36.5, 13.9), Vector2(43, 13.9), UIPalette.alpha(_body_light, 0.5), 0.6)
	_line(Vector2(58.8, 15.6), Vector2(58.8, 19.3), _outline, 0.5)


func _draw_smg() -> void:
	_line(Vector2(17, 16), Vector2(9, 12), _body_dark, 1.4)
	_line(Vector2(17, 20), Vector2(9, 24), _body_dark, 1.4)
	_line(Vector2(9, 12), Vector2(9, 24), _body_dark, 1.0)
	_fill([Vector2(16, 13), Vector2(34, 13), Vector2(34.5, 20), Vector2(16, 21)], _body)
	_stroke([Vector2(16, 13), Vector2(34, 13), Vector2(34.5, 20), Vector2(16, 21)], _outline, 0.8)
	_line(Vector2(18, 13), Vector2(32, 13), _detail, 0.8)
	_rect(34, 15.5, 9.5, 2.6, _body_light)
	_rect(43, 14.2, 2.8, 5.2, _body_dark)
	_fill([Vector2(24, 20), Vector2(29, 20), Vector2(28, 30), Vector2(23.5, 29.5)], _body_dark)
	_stroke([Vector2(24, 20), Vector2(29, 20), Vector2(28, 30), Vector2(23.5, 29.5)], _outline, 0.7)
	_line(Vector2(24.5, 23), Vector2(27.8, 23), _detail, 0.8)
	_fill([Vector2(18, 20), Vector2(22, 20), Vector2(20.5, 27), Vector2(16.5, 26)], _body_dark)
	_stroke([Vector2(18, 20), Vector2(22, 20), Vector2(20.5, 27), Vector2(16.5, 26)], _outline, 0.7)
	_rect(22, 9.5, 6.5, 3.2, _body_dark)
	_circle(Vector2(28.2, 11.1), 1.1, _detail)
	_line(Vector2(25, 12.7), Vector2(25, 13.2), _outline, 0.6)
	_line(Vector2(16.5, 14.2), Vector2(14, 14.2), _body_light, 1.0)
	if compact:
		return
	_line(Vector2(35, 14.4), Vector2(41.5, 14.4), UIPalette.alpha(_body_light, 0.45), 0.5)


func _draw_dmr() -> void:
	_fill([Vector2(5.5, 16), Vector2(14, 13.8), Vector2(15.5, 19.6), Vector2(8, 21.5)], _body_dark)
	_stroke([Vector2(5.5, 16), Vector2(14, 13.8), Vector2(15.5, 19.6), Vector2(8, 21.5)], _outline, 0.7)
	_fill([Vector2(13.5, 14), Vector2(38, 14), Vector2(38.5, 19.8), Vector2(13.5, 20.5)], _body)
	_stroke([Vector2(13.5, 14), Vector2(38, 14), Vector2(38.5, 19.8), Vector2(13.5, 20.5)], _outline, 0.8)
	_line(Vector2(15, 13.5), Vector2(36, 13.5), _detail, 0.8)
	_rect(38, 15.2, 18.5, 1.9, _body_light)
	_rect(56.5, 13.8, 3.2, 4.8, _body_dark)
	_line(Vector2(57.2, 14.6), Vector2(57.2, 17.8), _detail, 0.6)
	_fill([Vector2(21, 7.8), Vector2(36, 7.8), Vector2(36.5, 12.2), Vector2(21, 12.2)], _body_dark)
	_stroke([Vector2(21, 7.8), Vector2(36, 7.8), Vector2(36.5, 12.2), Vector2(21, 12.2)], _outline, 0.7)
	_rect(22, 8.5, 13, 3.2, UIPalette.alpha(UIPalette.ink, 0.55))
	_line(Vector2(25, 12.2), Vector2(25, 13.6), _outline, 0.8)
	_line(Vector2(32, 12.2), Vector2(32, 13.6), _outline, 0.8)
	_circle(Vector2(36.7, 10.3), 1.8, _detail)
	_line(Vector2(46, 17.5), Vector2(42, 29), _outline, 1.0)
	_line(Vector2(46, 17.5), Vector2(50, 29), _outline, 1.0)
	_line(Vector2(41.5, 29), Vector2(42.5, 29), _body_light, 1.0)
	_line(Vector2(49.5, 29), Vector2(50.5, 29), _body_light, 1.0)
	_fill([Vector2(24, 20), Vector2(30, 20), Vector2(29, 25.5), Vector2(24.5, 26)], _body_dark)
	_stroke([Vector2(24, 20), Vector2(30, 20), Vector2(29, 25.5), Vector2(24.5, 26)], _outline, 0.7)
	if _weapon_style == &"arc" or _weapon_style == &"rail":
		for index in 3:
			var x := 43.0 + float(index) * 4.0
			_line(Vector2(x, 13.6), Vector2(x, 18.6), UIPalette.alpha(_detail, 0.85), 0.8)
			_circle(Vector2(x, 13.6), 0.7, _detail)
	elif not compact:
		_line(Vector2(42, 18.8), Vector2(54, 18.8), UIPalette.alpha(_outline, 0.65), 0.5)


func _draw_shotgun() -> void:
	_fill([Vector2(5.5, 16.5), Vector2(15, 14.2), Vector2(17, 21), Vector2(9, 22.5)], _body_dark)
	_stroke([Vector2(5.5, 16.5), Vector2(15, 14.2), Vector2(17, 21), Vector2(9, 22.5)], _outline, 0.7)
	_fill([Vector2(15, 14), Vector2(29, 14), Vector2(29.5, 21), Vector2(15, 21.5)], _body)
	_stroke([Vector2(15, 14), Vector2(29, 14), Vector2(29.5, 21), Vector2(15, 21.5)], _outline, 0.8)
	_line(Vector2(16, 13.6), Vector2(28, 13.6), _detail, 0.8)
	_rect(29, 14.4, 24, 3.4, _body_light)
	_rect(29, 18.4, 19, 2.4, _body_dark)
	_fill([Vector2(32, 20.6), Vector2(42, 20.6), Vector2(41, 25.4), Vector2(33, 25.4)], _body_dark)
	_stroke([Vector2(32, 20.6), Vector2(42, 20.6), Vector2(41, 25.4), Vector2(33, 25.4)], _outline, 0.7)
	_line(Vector2(33.5, 22.6), Vector2(40.5, 22.6), _detail, 0.9)
	_rect(52.5, 14, 3.5, 4.2, _body_dark)
	_fill([Vector2(17, 21), Vector2(21.5, 21), Vector2(19.5, 27.5), Vector2(15, 26.5)], _body_dark)
	_stroke([Vector2(17, 21), Vector2(21.5, 21), Vector2(19.5, 27.5), Vector2(15, 26.5)], _outline, 0.7)
	if not compact:
		_circle(Vector2(13, 18.2), 1.2, UIPalette.alpha(_detail, 0.9))
		_circle(Vector2(16, 19), 1.2, UIPalette.alpha(_detail, 0.65))
		_line(Vector2(31, 19.6), Vector2(48, 19.6), UIPalette.alpha(UIPalette.ink, 0.4), 0.5)


func _draw_pistol() -> void:
	_fill([Vector2(19, 12.5), Vector2(41, 12.5), Vector2(42, 18.5), Vector2(30, 19), Vector2(19, 18.5)], _body)
	_stroke([Vector2(19, 12.5), Vector2(41, 12.5), Vector2(42, 18.5), Vector2(30, 19), Vector2(19, 18.5)], _outline, 0.8)
	_line(Vector2(20, 13), Vector2(40, 13), _detail, 0.8)
	_rect(41, 14, 3.8, 3.4, _body_light)
	_fill([Vector2(23, 18), Vector2(29.5, 18), Vector2(28, 27.5), Vector2(21, 26.5), Vector2(21.5, 21)], _body_dark)
	_stroke([Vector2(23, 18), Vector2(29.5, 18), Vector2(28, 27.5), Vector2(21, 26.5), Vector2(21.5, 21)], _outline, 0.7)
	_line(Vector2(23.5, 20.2), Vector2(27.3, 20.2), _detail, 0.7)
	_line(Vector2(30, 18.8), Vector2(31.5, 22.2), _outline, 0.8)
	_line(Vector2(31.5, 22.2), Vector2(35, 21.4), _outline, 0.8)
	_line(Vector2(35, 21.4), Vector2(35, 18.8), _outline, 0.8)
	_line(Vector2(22, 11.8), Vector2(22, 12.5), _outline, 1.0)
	_line(Vector2(38, 11.8), Vector2(38, 12.5), _outline, 1.0)
	_circle(Vector2(39.5, 15.7), 1.0, _detail)
	if compact:
		return
	for index in 3:
		var x := 34.0 + float(index) * 1.8
		_line(Vector2(x, 14.2), Vector2(x, 17.6), UIPalette.alpha(UIPalette.ink, 0.35), 0.5)


func _draw_lmg() -> void:
	_fill([Vector2(4.5, 16.5), Vector2(13.5, 14.2), Vector2(15, 20.5), Vector2(7.5, 22.5)], _body_dark)
	_stroke([Vector2(4.5, 16.5), Vector2(13.5, 14.2), Vector2(15, 20.5), Vector2(7.5, 22.5)], _outline, 0.7)
	_fill([Vector2(13, 13.5), Vector2(38.5, 13.5), Vector2(39, 21), Vector2(13, 21.5)], _body)
	_stroke([Vector2(13, 13.5), Vector2(38.5, 13.5), Vector2(39, 21), Vector2(13, 21.5)], _outline, 0.8)
	_rect(38, 13.8, 12, 6.4, _body_dark)
	_stroke([Vector2(38, 13.8), Vector2(50, 13.8), Vector2(50, 20.2), Vector2(38, 20.2)], _outline, 0.6)
	for index in 3:
		var x := 40.0 + float(index) * 3.2
		_line(Vector2(x, 14.6), Vector2(x, 19.4), UIPalette.alpha(_body_light, 0.5), 0.5)
	_rect(50, 15.5, 10.5, 2.8, _body_light)
	_rect(60, 14.2, 3, 5.6, _body_dark)
	_fill([Vector2(20, 21), Vector2(34, 21), Vector2(33, 28.5), Vector2(21, 28.5)], _body_dark)
	_stroke([Vector2(20, 21), Vector2(34, 21), Vector2(33, 28.5), Vector2(21, 28.5)], _outline, 0.7)
	_line(Vector2(22, 23.2), Vector2(31.5, 23.2), _detail, 0.9)
	_line(Vector2(22, 25.8), Vector2(31.5, 25.8), UIPalette.alpha(_detail, 0.5), 0.6)
	_fill([Vector2(16, 21), Vector2(20, 21), Vector2(18.5, 27), Vector2(14.5, 26)], _body_dark)
	_stroke([Vector2(16, 21), Vector2(20, 21), Vector2(18.5, 27), Vector2(14.5, 26)], _outline, 0.7)
	_line(Vector2(23, 11.5), Vector2(34, 11.5), _body_dark, 1.4)
	_line(Vector2(23, 11.5), Vector2(23, 13.4), _outline, 0.8)
	_line(Vector2(34, 11.5), Vector2(34, 13.4), _outline, 0.8)
	_line(Vector2(46, 20), Vector2(41.5, 30), _outline, 1.1)
	_line(Vector2(46, 20), Vector2(50.5, 30), _outline, 1.1)
	_circle(Vector2(45, 21), 1.2, _detail)


func _draw_launcher() -> void:
	_fill([Vector2(10, 13.5), Vector2(51, 13.5), Vector2(54, 17.5), Vector2(51, 21.5), Vector2(10, 21.5), Vector2(7.5, 17.5)], _body)
	_stroke([Vector2(10, 13.5), Vector2(51, 13.5), Vector2(54, 17.5), Vector2(51, 21.5), Vector2(10, 21.5), Vector2(7.5, 17.5)], _outline, 0.8)
	_rect(4.5, 15, 3.5, 5, _body_dark)
	_rect(53, 12, 6.5, 11, _body_dark)
	_circle(Vector2(56.2, 17.5), 2.3, UIPalette.alpha(UIPalette.ink, 0.7))
	_circle(Vector2(56.2, 17.5), 1.2, _detail)
	_line(Vector2(12, 17.5), Vector2(50, 17.5), UIPalette.alpha(_body_light, 0.5), 0.8)
	_fill([Vector2(22, 21), Vector2(27, 21), Vector2(25.5, 29), Vector2(20, 28.5)], _body_dark)
	_stroke([Vector2(22, 21), Vector2(27, 21), Vector2(25.5, 29), Vector2(20, 28.5)], _outline, 0.7)
	_fill([Vector2(36, 21), Vector2(40.5, 21), Vector2(39, 28.5), Vector2(34, 28)], _body_dark)
	_stroke([Vector2(36, 21), Vector2(40.5, 21), Vector2(39, 28.5), Vector2(34, 28)], _outline, 0.7)
	_circle(Vector2(29.5, 22.5), 5.2, _body_dark)
	_circle(Vector2(29.5, 22.5), 2.6, UIPalette.alpha(UIPalette.ink, 0.6))
	_circle(Vector2(29.5, 22.5), 1.0, _detail)
	_line(Vector2(42, 13.5), Vector2(42, 10.5), _outline, 1.0)
	_line(Vector2(41, 10.5), Vector2(43, 10.5), _detail, 1.2)
	if compact:
		return
	_line(Vector2(12, 19.6), Vector2(20, 19.6), UIPalette.alpha(_detail, 0.7), 1.0)
	_line(Vector2(44, 19.6), Vector2(50, 19.6), UIPalette.alpha(_detail, 0.7), 1.0)


func _draw_knife() -> void:
	_fill([Vector2(9, 25), Vector2(21.5, 17.5), Vector2(25, 21), Vector2(12.5, 28.5)], _body_dark)
	_stroke([Vector2(9, 25), Vector2(21.5, 17.5), Vector2(25, 21), Vector2(12.5, 28.5)], _outline, 0.8)
	for index in 3:
		var t := 0.18 + float(index) * 0.22
		var a := Vector2(9, 25).lerp(Vector2(21.5, 17.5), t)
		var b := Vector2(12.5, 28.5).lerp(Vector2(25, 21), t)
		_line(a, b, UIPalette.alpha(_detail, 0.7), 0.8)
	_line(Vector2(21, 15.5), Vector2(28.5, 24), _detail, 2.2)
	_fill([Vector2(24.5, 18), Vector2(49, 6.5), Vector2(54, 10), Vector2(31, 23.5)], _body_light)
	_stroke([Vector2(24.5, 18), Vector2(49, 6.5), Vector2(54, 10), Vector2(31, 23.5)], UIPalette.alpha(UIPalette.ivory, 0.75), 0.8)
	_line(Vector2(27.5, 20), Vector2(50.5, 9.2), UIPalette.alpha(UIPalette.ivory, 0.9), 0.9)
	if not compact:
		_line(Vector2(30, 20.8), Vector2(45, 12.2), UIPalette.alpha(_detail, 0.65), 0.7)
	_circle(Vector2(9.5, 25.2), 1.8, _body_dark)
	_circle(Vector2(9.5, 25.2), 0.8, _detail)


# --- Gear silhouettes ------------------------------------------------------

func _draw_helmet() -> void:
	var dome: Array = []
	for index in 17:
		var angle := PI + PI * float(index) / 16.0
		dome.append(Vector2(32.0 + cos(angle) * 13.5, 19.0 + sin(angle) * 13.5))
	_fill(dome, _body)
	_stroke(dome, _outline, 0.9, false)
	_fill([Vector2(18.5, 19), Vector2(45.5, 19), Vector2(45, 24.5), Vector2(19, 24.5)], _body_dark)
	_stroke([Vector2(18.5, 19), Vector2(45.5, 19), Vector2(45, 24.5), Vector2(19, 24.5)], _outline, 0.7)
	_line(Vector2(21, 21.8), Vector2(43, 21.8), UIPalette.alpha(_detail, 0.95), 1.8)
	_circle(Vector2(18, 20.5), 3.2, _body_dark)
	_circle(Vector2(46, 20.5), 3.2, _body_dark)
	_line(Vector2(32, 6.2), Vector2(32, 9.2), _detail, 1.4)
	_line(Vector2(28, 7.2), Vector2(36, 7.2), UIPalette.alpha(_detail, 0.6), 0.8)
	_circle(Vector2(22, 17), 0.8, _outline)
	_circle(Vector2(42, 17), 0.8, _outline)
	if not compact:
		_line(Vector2(21, 15.5), Vector2(25, 12.8), UIPalette.alpha(_body_light, 0.45), 0.6)


func _draw_chest() -> void:
	_fill([Vector2(19, 8), Vector2(45, 8), Vector2(49, 15), Vector2(44, 29), Vector2(20, 29), Vector2(15, 15)], _body)
	_stroke([Vector2(19, 8), Vector2(45, 8), Vector2(49, 15), Vector2(44, 29), Vector2(20, 29), Vector2(15, 15)], _outline, 0.8)
	_fill([Vector2(25, 8), Vector2(39, 8), Vector2(37, 13), Vector2(27, 13)], _body_dark)
	_fill([Vector2(15, 13), Vector2(22, 10), Vector2(23, 17), Vector2(16, 20)], _body_dark)
	_fill([Vector2(49, 13), Vector2(42, 10), Vector2(41, 17), Vector2(48, 20)], _body_dark)
	_stroke([Vector2(15, 13), Vector2(22, 10), Vector2(23, 17), Vector2(16, 20)], _outline, 0.6)
	_stroke([Vector2(49, 13), Vector2(42, 10), Vector2(41, 17), Vector2(48, 20)], _outline, 0.6)
	_circle(Vector2(32, 20), 4.2, UIPalette.alpha(_detail, 0.35))
	_circle(Vector2(32, 20), 2.4, _detail)
	_line(Vector2(32, 12.5), Vector2(32, 17), UIPalette.alpha(UIPalette.ivory, 0.35), 0.8)
	_line(Vector2(32, 24.5), Vector2(32, 28.2), UIPalette.alpha(UIPalette.ivory, 0.35), 0.8)
	_line(Vector2(21, 22), Vector2(26, 22), UIPalette.alpha(_detail, 0.7), 0.8)
	_line(Vector2(38, 22), Vector2(43, 22), UIPalette.alpha(_detail, 0.7), 0.8)


func _draw_legs() -> void:
	_fill([Vector2(19, 8), Vector2(30, 8), Vector2(29, 27), Vector2(19, 27)], _body)
	_fill([Vector2(34, 8), Vector2(45, 8), Vector2(45, 27), Vector2(35, 27)], _body)
	_stroke([Vector2(19, 8), Vector2(30, 8), Vector2(29, 27), Vector2(19, 27)], _outline, 0.7)
	_stroke([Vector2(34, 8), Vector2(45, 8), Vector2(45, 27), Vector2(35, 27)], _outline, 0.7)
	_fill([Vector2(18.5, 17), Vector2(30, 17), Vector2(29.5, 22), Vector2(19, 22)], _body_dark)
	_fill([Vector2(34, 17), Vector2(45.5, 17), Vector2(45, 22), Vector2(34.5, 22)], _body_dark)
	_fill([Vector2(17, 27), Vector2(30, 27), Vector2(30.5, 31), Vector2(16.5, 31)], _body_dark)
	_fill([Vector2(34, 27), Vector2(46, 27), Vector2(46.5, 31), Vector2(33.5, 31)], _body_dark)
	_line(Vector2(21, 11), Vector2(21, 15), _detail, 0.8)
	_line(Vector2(43, 11), Vector2(43, 15), _detail, 0.8)
	_line(Vector2(22, 25), Vector2(28, 25), UIPalette.alpha(_detail, 0.6), 0.7)
	_line(Vector2(36, 25), Vector2(42, 25), UIPalette.alpha(_detail, 0.6), 0.7)


func _draw_cloak() -> void:
	_fill([Vector2(24, 8), Vector2(40, 8), Vector2(48, 29), Vector2(39, 27), Vector2(32, 31), Vector2(25, 27), Vector2(16, 29)], _body)
	_stroke([Vector2(24, 8), Vector2(40, 8), Vector2(48, 29), Vector2(39, 27), Vector2(32, 31), Vector2(25, 27), Vector2(16, 29)], _outline, 0.8)
	_fill([Vector2(24, 8), Vector2(40, 8), Vector2(38, 13), Vector2(26, 13)], _body_dark)
	_circle(Vector2(32, 10.5), 2.2, _detail)
	_circle(Vector2(32, 10.5), 0.9, UIPalette.ink)
	_line(Vector2(27, 14), Vector2(23, 27), UIPalette.alpha(UIPalette.ink, 0.45), 0.8)
	_line(Vector2(32, 14), Vector2(32, 29), UIPalette.alpha(UIPalette.ink, 0.35), 0.8)
	_line(Vector2(37, 14), Vector2(41, 27), UIPalette.alpha(UIPalette.ink, 0.45), 0.8)
	_line(Vector2(17, 29), Vector2(24, 27), UIPalette.alpha(_detail, 0.5), 0.7)
	_line(Vector2(47, 29), Vector2(40, 27), UIPalette.alpha(_detail, 0.5), 0.7)


func _draw_charm() -> void:
	_line(Vector2(22, 7), Vector2(32, 16), _outline, 0.9)
	_line(Vector2(42, 7), Vector2(32, 16), _outline, 0.9)
	if not compact:
		_circle(Vector2(24.5, 9.2), 0.8, _outline)
		_circle(Vector2(39.5, 9.2), 0.8, _outline)
	_fill([Vector2(32, 13), Vector2(41, 21), Vector2(32, 31), Vector2(23, 21)], _body)
	_stroke([Vector2(32, 13), Vector2(41, 21), Vector2(32, 31), Vector2(23, 21)], _outline, 0.8)
	_fill([Vector2(32, 17), Vector2(37, 21), Vector2(32, 26), Vector2(27, 21)], UIPalette.alpha(_detail, 0.35))
	_circle(Vector2(32, 21), 2.2, _detail)
	_circle(Vector2(32, 21), 0.8, UIPalette.ivory)
	_circle(Vector2(32, 12), 1.2, _body_dark)


func _draw_gear_fallback() -> void:
	_fill([Vector2(32, 7), Vector2(47, 13), Vector2(45, 24), Vector2(32, 30), Vector2(19, 24), Vector2(17, 13)], _body)
	_stroke([Vector2(32, 7), Vector2(47, 13), Vector2(45, 24), Vector2(32, 30), Vector2(19, 24), Vector2(17, 13)], _outline, 0.8)
	_line(Vector2(32, 12), Vector2(32, 24), _detail, 1.2)
	_circle(Vector2(32, 18), 4.0, UIPalette.alpha(_detail, 0.3))


# --- Shared marks ----------------------------------------------------------

func _draw_rarity_corner() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	var tint := rarity_color
	if tint.a <= 0.001:
		tint = UIPalette.alpha(accent, 0.75)
	if _empty:
		tint = UIPalette.alpha(UIPalette.muted_dim, 0.6)
	var corner := clampf(minf(size.x, size.y) * 0.28, 4.0, 12.0)
	draw_line(Vector2(size.x - corner, 1.0), Vector2(size.x - 1.0, 1.0), tint, 1.6, true)
	draw_line(Vector2(size.x - 1.0, 1.0), Vector2(size.x - 1.0, corner), tint, 1.6, true)
	draw_circle(Vector2(size.x - corner * 0.55, corner * 0.55), maxf(0.8, corner * 0.1), tint)


func _draw_empty_mark(area: Rect2) -> void:
	var muted := UIPalette.alpha(UIPalette.muted_dim, 0.65)
	draw_dashed_line(
		Vector2(area.position.x + area.size.x * 0.1, area.end.y - area.size.y * 0.12),
		Vector2(area.end.x - area.size.x * 0.1, area.position.y + area.size.y * 0.12),
		muted,
		1.0,
		3.0
	)
