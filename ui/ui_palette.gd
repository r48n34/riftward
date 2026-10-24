class_name UIPalette
extends RefCounted
## Single source of truth for colour, spacing, typography and formatting across
## the whole UI. Values are static vars (not consts) so accessibility settings
## can retheme the interface without rebuilding every script.

# --- Core palette -----------------------------------------------------------
static var ink := Color("0b1114")
static var ink_deep := Color("070c0e")
static var surface := Color("121a1d")
static var surface_raised := Color("182326")
static var surface_high := Color("1f2d31")
static var line := Color("26383d")
static var line_soft := Color("1d2a2e")
static var ivory := Color("f4efe5")
static var muted := Color("93a5a8")
static var muted_dim := Color("6d7f82")
static var mint := Color("62e6c3")
static var mint_dim := Color("3fa48d")
static var amber := Color("ffb866")
static var danger := Color("ff6e6e")
static var blue := Color("6fa8ff")
static var violet := Color("c79cff")
static var sun := Color("ffd9a0")
static var warn := amber

# --- Accents per faction / discipline --------------------------------------
static var faction_colors := {
	&"ashen": Color("ffb866"),
	&"bloom": Color("c79cff"),
	&"choir": Color("63b8ff"),
	&"warden": Color("62e6c3"),
	&"rift": Color("ff6e6e"),
	&"neutral": Color("93a5a8"),
}

static var discipline_colors := {
	&"vanguard": Color("ffb866"),
	&"infiltrator": Color("6fa8ff"),
	&"engineer": Color("62e6c3"),
	&"pathfinder": Color("c79cff"),
}

# --- Spacing scale (8px rhythm, 4px half-step) ------------------------------
const SP1 := 4
const SP2 := 8
const SP3 := 12
const SP4 := 16
const SP5 := 24
const SP6 := 32
const SP7 := 48
const SP8 := 64
const SP9 := 96

# --- Radii ------------------------------------------------------------------
const R_SM := 6
const R_MD := 10
const R_LG := 14
const R_XL := 20
const R_CHIP := 13

# --- Type scale -------------------------------------------------------------
const FONT_WORDMARK := 92
const FONT_DISPLAY := 56
const FONT_H1 := 40
const FONT_H2 := 28
const FONT_H3 := 20
const FONT_TITLE := 16
const FONT_BODY := 15
const FONT_SMALL := 13
const FONT_MICRO := 11
const FONT_MONO := 15
const FONT_HUD_NUM := 34

# --- Motion -----------------------------------------------------------------
const MOTION_FAST := 0.16
const MOTION := 0.2
const MOTION_SLOW := 0.32

# --- Live accessibility state ----------------------------------------------
static var reduce_motion := false
static var high_contrast := false
static var ui_scale := 1.0


static func apply_settings(app: Node) -> void:
	if app == null:
		return
	reduce_motion = bool(app.get_setting("reduce_motion", false))
	high_contrast = bool(app.get_setting("high_contrast", false))
	ui_scale = clampf(float(app.get_setting("ui_scale", 1.0)), 0.75, 1.6)
	_apply_contrast()


static func _apply_contrast() -> void:
	if high_contrast:
		ink = Color("05090a")
		ink_deep = Color("030607")
		surface = Color("0d1416")
		surface_raised = Color("152023")
		surface_high = Color("1c2b2f")
		line = Color("5b7a80")
		line_soft = Color("3a5055")
		ivory = Color("ffffff")
		muted = Color("ccd9da")
		muted_dim = Color("a5b6b8")
		mint = Color("7df5d4")
		amber = Color("ffcb8c")
		danger = Color("ff8a8a")
		blue = Color("8fc0ff")
		violet = Color("d7b6ff")
	else:
		ink = Color("0b1114")
		ink_deep = Color("070c0e")
		surface = Color("121a1d")
		surface_raised = Color("182326")
		surface_high = Color("1f2d31")
		line = Color("26383d")
		line_soft = Color("1d2a2e")
		ivory = Color("f4efe5")
		muted = Color("93a5a8")
		muted_dim = Color("6d7f82")
		mint = Color("62e6c3")
		amber = Color("ffb866")
		danger = Color("ff6e6e")
		blue = Color("6fa8ff")
		violet = Color("c79cff")


# --- Helpers ----------------------------------------------------------------
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)


static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


static func brighten(color: Color, amount: float = 0.12) -> Color:
	return Color(
		clampf(color.r + amount, 0.0, 1.0),
		clampf(color.g + amount, 0.0, 1.0),
		clampf(color.b + amount, 0.0, 1.0),
		color.a
	)


static func darken(color: Color, amount: float = 0.12) -> Color:
	return Color(
		clampf(color.r - amount, 0.0, 1.0),
		clampf(color.g - amount, 0.0, 1.0),
		clampf(color.b - amount, 0.0, 1.0),
		color.a
	)


static func on_color(background: Color) -> Color:
	var luminance := background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
	return ink if luminance > 0.55 else ivory


static func severity_color(severity: StringName) -> Color:
	match severity:
		&"error", &"danger":
			return danger
		&"warning":
			return amber
		&"success":
			return mint
		&"rift":
			return violet
		&"loot":
			return sun
		_:
			return blue


static func faction_color(faction: Variant) -> Color:
	return faction_colors.get(StringName(faction), muted)


static func discipline_color(discipline: Variant) -> Color:
	return discipline_colors.get(StringName(discipline), mint)


static func rarity_color(rarity: int) -> Color:
	if ContentDB != null:
		return ContentDB.get_rarity_color(rarity)
	return StatKeys.RARITY_COLORS[clampi(rarity, 0, StatKeys.RARITY_COLORS.size() - 1)]


static func rarity_name(rarity: int) -> String:
	if ContentDB != null:
		return ContentDB.get_rarity_name(rarity)
	return StatKeys.RARITY_NAMES[clampi(rarity, 0, StatKeys.RARITY_NAMES.size() - 1)]


# --- Formatting -------------------------------------------------------------
static func format_int(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if negative else "") + out


static func format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	var minutes := total / 60
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]


static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	if total >= 3600:
		return "%dh %02dm" % [total / 3600, (total % 3600) / 60]
	return "%dm %02ds" % [total / 60, total % 60]


static func format_seconds(seconds: float) -> String:
	return "%.1fs" % maxf(0.0, seconds)


static func format_stat_value(stat: StringName, value: float) -> String:
	var label := String(stat).replace("_", " ").capitalize()
	match stat:
		&"crit_chance", &"luck", &"status_power":
			return "%+.1f%% %s" % [value * 100.0, label]
		&"reload_speed", &"handling":
			return "%+d%% %s" % [int(round(value * 100.0)), label]
		&"move_speed", &"sprint_speed", &"jump_velocity":
			return "%+.2f %s" % [value, label]
		_:
			if absf(value) < 1.0 and value != 0.0 and absf(value) < 10.0:
				return "%+.0f%% %s" % [value * 100.0, label]
			return "%+.1f %s" % [value, label]


static func format_affix(stat: StringName, op: StringName, value: float) -> String:
	var label := String(stat).replace("_", " ").capitalize()
	if op == &"mult":
		return "%+d%% %s" % [int(round((value - 1.0) * 100.0)), label]
	if value > 0.0 and value < 1.0:
		return "+%d%% %s" % [int(round(value * 100.0)), label]
	return "+%s %s" % [str(snappedf(value, 0.01)), label]


# --- Responsiveness ---------------------------------------------------------
static func page_padding(viewport_width: float) -> int:
	# Generous editorial gutters that cap content width on ultrawide displays.
	if viewport_width <= 1400.0:
		return SP5
	var pad := int((viewport_width - 1740.0) * 0.5)
	return clampi(pad, SP5, 220)


static func rail_width(viewport_width: float) -> int:
	if viewport_width <= 1400.0:
		return 190
	if viewport_width >= 2300.0:
		return 248
	return 220


static func is_compact(viewport_width: float) -> bool:
	return viewport_width <= 1400.0


# --- Motion helpers ---------------------------------------------------------
static func motion(seconds: float) -> float:
	return 0.0 if reduce_motion else seconds


static func hand_font() -> Font:
	return UIFonts.display(650)


static func body_font(weight: int = 400) -> Font:
	return UIFonts.body(weight)


static func mono_font(bold: bool = false) -> Font:
	return UIFonts.mono(bold)
