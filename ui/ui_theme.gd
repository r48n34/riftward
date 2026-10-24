class_name UITheme
extends RefCounted
## Builds the single Theme resource used by the entire interface. Everything is
## semantic: screens request variations (PrimaryButton, Card, Eyebrow, ...) and
## never hardcode colours or sizes. Rebuilt after accessibility changes.

const FOCUS_COLOR := Color("62e6c3")
const FOCUS_HC := Color("9dffe9")


static func build() -> Theme:
	var theme := Theme.new()
	var body_font := UIFonts.body(400)
	if body_font != null:
		theme.default_font = body_font
	theme.default_font_size = UIPalette.FONT_BODY
	_setup_labels(theme)
	_setup_buttons(theme)
	_setup_option_and_inputs(theme)
	_setup_panels(theme)
	_setup_progress(theme)
	_setup_sliders(theme)
	_setup_scrollbars(theme)
	_setup_misc(theme)
	return theme


# ---------------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------------

static func _box(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = UIPalette.R_MD,
	border_width: int = 1,
	margins: Vector4 = Vector4(16, 10, 16, 10)
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if border.a > 0.001 and border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	else:
		style.set_border_width_all(0)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style


static func _focus_box(radius: int = UIPalette.R_MD, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.draw_center = false
	style.set_corner_radius_all(radius + 1)
	style.border_color = FOCUS_HC if UIPalette.high_contrast else FOCUS_COLOR
	style.set_border_width_all(width)
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	return style


static func _empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func _set_font(theme: Theme, theme_type: String, font: Font, size: int) -> void:
	if font != null:
		theme.set_font("font", theme_type, font)
	theme.set_font_size("font_size", theme_type, size)


# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------

static func _setup_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UIPalette.ivory)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", 3)

	var defs := [
		["Wordmark", UIFonts.display(700), 92, UIPalette.ivory],
		["Display", UIFonts.display(650), UIPalette.FONT_DISPLAY, UIPalette.ivory],
		["H1", UIFonts.display(650), UIPalette.FONT_H1, UIPalette.ivory],
		["H2", UIFonts.display(600), UIPalette.FONT_H2, UIPalette.ivory],
		["H3", UIFonts.display(600), UIPalette.FONT_H3, UIPalette.ivory],
		["TitleLabel", UIFonts.display(600), UIPalette.FONT_TITLE, UIPalette.ivory],
		["Body", UIFonts.body(400), UIPalette.FONT_BODY, UIPalette.ivory],
		["BodyMuted", UIFonts.body(400), UIPalette.FONT_BODY, UIPalette.muted],
		["BodySmall", UIFonts.body(400), UIPalette.FONT_SMALL, UIPalette.muted],
		["Micro", UIFonts.body(600), UIPalette.FONT_MICRO, UIPalette.muted],
		["Eyebrow", UIFonts.body(600), UIPalette.FONT_MICRO, UIPalette.mint],
		["EyebrowMuted", UIFonts.body(600), UIPalette.FONT_MICRO, UIPalette.muted_dim],
		["Mono", UIFonts.mono(false), UIPalette.FONT_MONO, UIPalette.ivory],
		["MonoSmall", UIFonts.mono(false), 12, UIPalette.muted],
		["MonoValue", UIFonts.mono(true), 14, UIPalette.ivory],
		["NumberBig", UIFonts.mono(true), 32, UIPalette.ivory],
		["NumberHuge", UIFonts.mono(true), 44, UIPalette.ivory],
		["StatLabel", UIFonts.body(500), UIPalette.FONT_MICRO, UIPalette.muted],
		["StatValue", UIFonts.mono(true), 14, UIPalette.ivory],
		["AccentLabel", UIFonts.body(600), UIPalette.FONT_SMALL, UIPalette.mint],
		["DangerLabel", UIFonts.body(600), UIPalette.FONT_SMALL, UIPalette.danger],
		["SuccessLabel", UIFonts.body(600), UIPalette.FONT_SMALL, UIPalette.mint],
		["PlayerName", UIFonts.display(600), 18, UIPalette.ivory],
		["Flavor", UIFonts.body(400), 16, UIPalette.muted],
	]
	for entry in defs:
		var var_name: String = entry[0]
		theme.set_type_variation(var_name, "Label")
		_set_font(theme, var_name, entry[1], int(entry[2]))
		theme.set_color("font_color", var_name, entry[3])


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

static func _setup_buttons(theme: Theme) -> void:
	var font := UIFonts.body(500)
	_set_font(theme, "Button", font, 14)
	theme.set_color("font_color", "Button", UIPalette.ivory)
	theme.set_color("font_hover_color", "Button", UIPalette.ivory)
	theme.set_color("font_pressed_color", "Button", UIPalette.ivory)
	theme.set_color("font_focus_color", "Button", UIPalette.ivory)
	theme.set_color("font_hover_pressed_color", "Button", UIPalette.ivory)
	theme.set_color("font_disabled_color", "Button", UIPalette.alpha(UIPalette.muted, 0.45))
	theme.set_color("font_outline_color", "Button", UIPalette.ink)
	theme.set_constant("h_separation", "Button", UIPalette.SP2)
	theme.set_constant("outline_size", "Button", 0)

	theme.set_stylebox("normal", "Button", _box(UIPalette.surface_raised, UIPalette.line, UIPalette.R_MD))
	theme.set_stylebox("hover", "Button", _box(UIPalette.surface_high, UIPalette.alpha(UIPalette.mint, 0.45), UIPalette.R_MD))
	theme.set_stylebox("pressed", "Button", _box(UIPalette.mix(UIPalette.surface_high, UIPalette.mint, 0.10), UIPalette.mint_dim, UIPalette.R_MD))
	theme.set_stylebox("focus", "Button", _focus_box(UIPalette.R_MD))
	theme.set_stylebox("disabled", "Button", _box(UIPalette.alpha(UIPalette.surface_raised, 0.5), UIPalette.alpha(UIPalette.line, 0.5), UIPalette.R_MD))
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "Button", UIPalette.ivory)
	theme.set_color("icon_disabled_color", "Button", UIPalette.alpha(UIPalette.muted, 0.4))

	# --- Primary: the single strongest action on a screen -------------------
	theme.set_type_variation("PrimaryButton", "Button")
	_set_font(theme, "PrimaryButton", UIFonts.body(600), 14)
	theme.set_stylebox("normal", "PrimaryButton", _box(UIPalette.mint, UIPalette.mint, UIPalette.R_MD, 1, Vector4(20, 12, 20, 12)))
	theme.set_stylebox("hover", "PrimaryButton", _box(UIPalette.brighten(UIPalette.mint, 0.08), UIPalette.ivory, UIPalette.R_MD, 1, Vector4(20, 12, 20, 12)))
	theme.set_stylebox("pressed", "PrimaryButton", _box(UIPalette.darken(UIPalette.mint, 0.08), UIPalette.mint, UIPalette.R_MD, 1, Vector4(20, 12, 20, 12)))
	theme.set_stylebox("focus", "PrimaryButton", _focus_box(UIPalette.R_MD))
	theme.set_stylebox("disabled", "PrimaryButton", _box(UIPalette.alpha(UIPalette.muted, 0.25), Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(20, 12, 20, 12)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "PrimaryButton", UIPalette.ink)
	theme.set_color("font_disabled_color", "PrimaryButton", UIPalette.alpha(UIPalette.ink, 0.5))
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "PrimaryButton", UIPalette.ink)

	# --- Secondary / ghost --------------------------------------------------
	theme.set_type_variation("SecondaryButton", "Button")
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "SecondaryButton", UIPalette.ivory)
	theme.set_color("icon_disabled_color", "SecondaryButton", UIPalette.alpha(UIPalette.muted, 0.4))
	theme.set_type_variation("GhostButton", "Button")
	theme.set_stylebox("normal", "GhostButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_MD, 0))
	theme.set_stylebox("hover", "GhostButton", _box(UIPalette.alpha(UIPalette.surface_high, 0.85), Color.TRANSPARENT, UIPalette.R_MD, 0))
	theme.set_stylebox("pressed", "GhostButton", _box(UIPalette.surface_high, Color.TRANSPARENT, UIPalette.R_MD, 0))
	theme.set_stylebox("focus", "GhostButton", _focus_box(UIPalette.R_MD))
	theme.set_stylebox("disabled", "GhostButton", _empty_box())
	theme.set_color("font_color", "GhostButton", UIPalette.muted)
	theme.set_color("font_hover_color", "GhostButton", UIPalette.ivory)
	theme.set_color("font_pressed_color", "GhostButton", UIPalette.ivory)
	for icon_color in ["icon_normal_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "GhostButton", UIPalette.muted)
	theme.set_color("icon_hover_color", "GhostButton", UIPalette.ivory)

	# --- Inline text action (Change, View all, ...) -------------------------
	theme.set_type_variation("InlineButton", "GhostButton")
	_set_font(theme, "InlineButton", UIFonts.body(600), 12)
	theme.set_stylebox("normal", "InlineButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(4, 2, 4, 2)))
	theme.set_stylebox("hover", "InlineButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(4, 2, 4, 2)))
	theme.set_stylebox("pressed", "InlineButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(4, 2, 4, 2)))
	theme.set_color("font_color", "InlineButton", UIPalette.mint)
	theme.set_color("font_hover_color", "InlineButton", UIPalette.brighten(UIPalette.mint, 0.1))
	theme.set_color("font_pressed_color", "InlineButton", UIPalette.ivory)
	theme.set_color("font_disabled_color", "InlineButton", UIPalette.alpha(UIPalette.muted, 0.4))
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "InlineButton", UIPalette.mint)

	# --- Danger -------------------------------------------------------------
	theme.set_type_variation("DangerButton", "Button")
	theme.set_stylebox("normal", "DangerButton", _box(UIPalette.alpha(UIPalette.danger, 0.06), UIPalette.alpha(UIPalette.danger, 0.5), UIPalette.R_MD))
	theme.set_stylebox("hover", "DangerButton", _box(UIPalette.alpha(UIPalette.danger, 0.16), UIPalette.danger, UIPalette.R_MD))
	theme.set_stylebox("pressed", "DangerButton", _box(UIPalette.alpha(UIPalette.danger, 0.24), UIPalette.danger, UIPalette.R_MD))
	theme.set_stylebox("focus", "DangerButton", _focus_box(UIPalette.R_MD))
	theme.set_stylebox("disabled", "DangerButton", _box(Color.TRANSPARENT, UIPalette.alpha(UIPalette.line, 0.6), UIPalette.R_MD))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(key, "DangerButton", UIPalette.danger)
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "DangerButton", UIPalette.danger)

	# --- Nav rail item ------------------------------------------------------
	theme.set_type_variation("NavButton", "Button")
	_set_font(theme, "NavButton", UIFonts.body(500), 14)
	theme.set_constant("h_separation", "NavButton", UIPalette.SP3)
	theme.set_stylebox("normal", "NavButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(14, 11, 14, 11)))
	theme.set_stylebox("hover", "NavButton", _box(UIPalette.alpha(UIPalette.surface_high, 0.7), Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(14, 11, 14, 11)))
	var nav_active := _box(UIPalette.alpha(UIPalette.mint, 0.10), Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(14, 11, 14, 11))
	nav_active.border_width_left = 2
	nav_active.border_color = UIPalette.mint
	theme.set_stylebox("pressed", "NavButton", nav_active)
	theme.set_stylebox("hover_pressed", "NavButton", nav_active)
	theme.set_stylebox("focus", "NavButton", _focus_box(UIPalette.R_MD))
	theme.set_color("font_color", "NavButton", UIPalette.muted)
	theme.set_color("font_hover_color", "NavButton", UIPalette.ivory)
	theme.set_color("font_pressed_color", "NavButton", UIPalette.mint)
	theme.set_color("font_hover_pressed_color", "NavButton", UIPalette.mint)
	for icon_color in ["icon_normal_color"]:
		theme.set_color(icon_color, "NavButton", UIPalette.muted)
	for icon_color in ["icon_hover_color", "icon_focus_color"]:
		theme.set_color(icon_color, "NavButton", UIPalette.ivory)
	for icon_color in ["icon_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(icon_color, "NavButton", UIPalette.mint)

	# --- Filter chips -------------------------------------------------------
	theme.set_type_variation("ChipButton", "Button")
	_set_font(theme, "ChipButton", UIFonts.body(500), 12)
	theme.set_stylebox("normal", "ChipButton", _box(Color.TRANSPARENT, UIPalette.line, UIPalette.R_CHIP, 1, Vector4(13, 6, 13, 6)))
	theme.set_stylebox("hover", "ChipButton", _box(UIPalette.alpha(UIPalette.surface_high, 0.9), UIPalette.muted_dim, UIPalette.R_CHIP, 1, Vector4(13, 6, 13, 6)))
	theme.set_stylebox("pressed", "ChipButton", _box(UIPalette.alpha(UIPalette.mint, 0.14), UIPalette.mint, UIPalette.R_CHIP, 1, Vector4(13, 6, 13, 6)))
	theme.set_stylebox("hover_pressed", "ChipButton", _box(UIPalette.alpha(UIPalette.mint, 0.2), UIPalette.mint, UIPalette.R_CHIP, 1, Vector4(13, 6, 13, 6)))
	theme.set_stylebox("focus", "ChipButton", _focus_box(UIPalette.R_CHIP))
	theme.set_color("font_color", "ChipButton", UIPalette.muted)
	theme.set_color("font_hover_color", "ChipButton", UIPalette.ivory)
	for key in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(key, "ChipButton", UIPalette.mint)

	# --- Tab (underline) ----------------------------------------------------
	theme.set_type_variation("TabButton", "Button")
	theme.set_stylebox("normal", "TabButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(4, 8, 4, 9)))
	theme.set_stylebox("hover", "TabButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(4, 8, 4, 9)))
	var tab_active := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(4, 8, 4, 9))
	tab_active.border_width_bottom = 2
	tab_active.border_color = UIPalette.mint
	theme.set_stylebox("pressed", "TabButton", tab_active)
	theme.set_stylebox("hover_pressed", "TabButton", tab_active)
	theme.set_stylebox("focus", "TabButton", _focus_box(2))
	theme.set_color("font_color", "TabButton", UIPalette.muted)
	theme.set_color("font_hover_color", "TabButton", UIPalette.ivory)
	theme.set_color("font_pressed_color", "TabButton", UIPalette.ivory)
	theme.set_color("font_hover_pressed_color", "TabButton", UIPalette.ivory)

	# --- Selectable card (Button that hosts arbitrary card content) ---------
	theme.set_type_variation("CardButton", "Button")
	theme.set_constant("h_separation", "CardButton", 0)
	theme.set_stylebox("normal", "CardButton", _box(UIPalette.surface, UIPalette.line, UIPalette.R_LG, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("hover", "CardButton", _box(UIPalette.surface_raised, UIPalette.alpha(UIPalette.mint, 0.55), UIPalette.R_LG, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("pressed", "CardButton", _box(UIPalette.mix(UIPalette.surface_raised, UIPalette.mint, 0.07), UIPalette.mint, UIPalette.R_LG, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("hover_pressed", "CardButton", _box(UIPalette.mix(UIPalette.surface_raised, UIPalette.mint, 0.07), UIPalette.mint, UIPalette.R_LG, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("focus", "CardButton", _focus_box(UIPalette.R_LG))
	theme.set_stylebox("disabled", "CardButton", _box(UIPalette.alpha(UIPalette.surface, 0.55), UIPalette.alpha(UIPalette.line, 0.6), UIPalette.R_LG, 1, Vector4(0, 0, 0, 0)))
	theme.set_color("font_color", "CardButton", UIPalette.ivory)

	# --- Icon only ----------------------------------------------------------
	theme.set_type_variation("IconButton", "Button")
	theme.set_stylebox("normal", "IconButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(8, 8, 8, 8)))
	theme.set_stylebox("hover", "IconButton", _box(UIPalette.alpha(UIPalette.surface_high, 0.9), Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(8, 8, 8, 8)))
	theme.set_stylebox("pressed", "IconButton", _box(UIPalette.surface_high, Color.TRANSPARENT, UIPalette.R_MD, 0, Vector4(8, 8, 8, 8)))
	theme.set_stylebox("focus", "IconButton", _focus_box(UIPalette.R_MD))
	for icon_color in ["icon_normal_color", "icon_focus_color"]:
		theme.set_color(icon_color, "IconButton", UIPalette.muted)
	for icon_color in ["icon_hover_color", "icon_pressed_color"]:
		theme.set_color(icon_color, "IconButton", UIPalette.ivory)

	# --- Hero deploy CTA ----------------------------------------------------
	theme.set_type_variation("DeployButton", "Button")
	_set_font(theme, "DeployButton", UIFonts.display(650), 16)
	theme.set_stylebox("normal", "DeployButton", _box(UIPalette.mint, UIPalette.mint, UIPalette.R_LG, 1, Vector4(28, 16, 28, 16)))
	theme.set_stylebox("hover", "DeployButton", _box(UIPalette.brighten(UIPalette.mint, 0.07), UIPalette.ivory, UIPalette.R_LG, 1, Vector4(28, 16, 28, 16)))
	theme.set_stylebox("pressed", "DeployButton", _box(UIPalette.darken(UIPalette.mint, 0.08), UIPalette.mint, UIPalette.R_LG, 1, Vector4(28, 16, 28, 16)))
	theme.set_stylebox("focus", "DeployButton", _focus_box(UIPalette.R_LG))
	theme.set_stylebox("disabled", "DeployButton", _box(UIPalette.alpha(UIPalette.muted, 0.2), Color.TRANSPARENT, UIPalette.R_LG, 0, Vector4(28, 16, 28, 16)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "DeployButton", UIPalette.ink)
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "DeployButton", UIPalette.ink)

	# --- Oversized quick-deploy CTA (main menu hero) ------------------------
	theme.set_type_variation("QuickDeployButton", "Button")
	_set_font(theme, "QuickDeployButton", UIFonts.display(700), 22)
	theme.set_constant("h_separation", "QuickDeployButton", UIPalette.SP3)
	theme.set_stylebox("normal", "QuickDeployButton", _box(UIPalette.mint, UIPalette.mint, UIPalette.R_LG, 2, Vector4(34, 22, 34, 22)))
	theme.set_stylebox("hover", "QuickDeployButton", _box(UIPalette.brighten(UIPalette.mint, 0.08), UIPalette.ivory, UIPalette.R_LG, 2, Vector4(34, 22, 34, 22)))
	theme.set_stylebox("pressed", "QuickDeployButton", _box(UIPalette.darken(UIPalette.mint, 0.10), UIPalette.mint, UIPalette.R_LG, 2, Vector4(34, 22, 34, 22)))
	theme.set_stylebox("focus", "QuickDeployButton", _focus_box(UIPalette.R_LG, 3))
	theme.set_stylebox("disabled", "QuickDeployButton", _box(UIPalette.alpha(UIPalette.muted, 0.25), Color.TRANSPARENT, UIPalette.R_LG, 0, Vector4(34, 22, 34, 22)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "QuickDeployButton", UIPalette.ink)
	theme.set_color("font_disabled_color", "QuickDeployButton", UIPalette.alpha(UIPalette.ink, 0.5))
	for icon_color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		theme.set_color(icon_color, "QuickDeployButton", UIPalette.ink)
	theme.set_color("icon_disabled_color", "QuickDeployButton", UIPalette.alpha(UIPalette.ink, 0.45))


# ---------------------------------------------------------------------------
# OptionButton, PopupMenu, LineEdit
# ---------------------------------------------------------------------------

static func _setup_option_and_inputs(theme: Theme) -> void:
	theme.set_icon("arrow", "OptionButton", UIIcons.get_icon(&"arrow-small"))
	theme.set_constant("arrow_margin", "OptionButton", 10)
	_set_font(theme, "OptionButton", UIFonts.body(500), 14)
	theme.set_color("font_color", "OptionButton", UIPalette.ivory)
	theme.set_color("font_hover_color", "OptionButton", UIPalette.ivory)
	theme.set_color("font_pressed_color", "OptionButton", UIPalette.ivory)
	theme.set_color("font_focus_color", "OptionButton", UIPalette.ivory)
	theme.set_color("font_disabled_color", "OptionButton", UIPalette.alpha(UIPalette.muted, 0.5))
	theme.set_stylebox("normal", "OptionButton", _box(UIPalette.surface_raised, UIPalette.line, UIPalette.R_MD, 1, Vector4(14, 10, 14, 10)))
	theme.set_stylebox("hover", "OptionButton", _box(UIPalette.surface_high, UIPalette.alpha(UIPalette.mint, 0.45), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10)))
	theme.set_stylebox("pressed", "OptionButton", _box(UIPalette.surface_high, UIPalette.mint_dim, UIPalette.R_MD, 1, Vector4(14, 10, 14, 10)))
	theme.set_stylebox("focus", "OptionButton", _focus_box(UIPalette.R_MD))
	theme.set_stylebox("disabled", "OptionButton", _box(UIPalette.alpha(UIPalette.surface_raised, 0.5), UIPalette.alpha(UIPalette.line, 0.5), UIPalette.R_MD))
	theme.set_color("icon_normal_color", "OptionButton", UIPalette.muted)
	theme.set_color("icon_hover_color", "OptionButton", UIPalette.ivory)

	theme.set_stylebox("panel", "PopupMenu", _box(UIPalette.surface_raised, UIPalette.line, UIPalette.R_MD, 1, Vector4(8, 8, 8, 8)))
	theme.set_stylebox("hover", "PopupMenu", _box(UIPalette.alpha(UIPalette.mint, 0.12), Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(8, 6, 8, 6)))
	theme.set_stylebox("separator", "PopupMenu", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 4, 0, 4)))
	_set_font(theme, "PopupMenu", UIFonts.body(400), 14)
	theme.set_color("font_color", "PopupMenu", UIPalette.ivory)
	theme.set_color("font_hover_color", "PopupMenu", UIPalette.mint)
	theme.set_color("font_disabled_color", "PopupMenu", UIPalette.alpha(UIPalette.muted, 0.4))
	theme.set_constant("v_separation", "PopupMenu", 6)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)

	_set_font(theme, "LineEdit", UIFonts.body(400), 14)
	theme.set_color("font_color", "LineEdit", UIPalette.ivory)
	theme.set_color("font_placeholder_color", "LineEdit", UIPalette.muted_dim)
	theme.set_color("font_selected_color", "LineEdit", UIPalette.ink)
	theme.set_color("caret_color", "LineEdit", UIPalette.mint)
	theme.set_color("selection_color", "LineEdit", UIPalette.alpha(UIPalette.mint, 0.35))
	theme.set_stylebox("normal", "LineEdit", _box(UIPalette.ink, UIPalette.line, UIPalette.R_MD, 1, Vector4(12, 9, 12, 9)))
	theme.set_stylebox("focus", "LineEdit", _box(UIPalette.ink, UIPalette.mint, UIPalette.R_MD, 1, Vector4(12, 9, 12, 9)))
	theme.set_stylebox("read_only", "LineEdit", _box(UIPalette.alpha(UIPalette.surface, 0.8), UIPalette.line_soft, UIPalette.R_MD))


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

static func _setup_panels(theme: Theme) -> void:
	var card := _box(UIPalette.surface, UIPalette.line, UIPalette.R_LG, 1, Vector4(22, 20, 22, 20))
	theme.set_stylebox("panel", "PanelContainer", card)
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", card)

	theme.set_type_variation("CardRaised", "PanelContainer")
	theme.set_stylebox("panel", "CardRaised", _box(UIPalette.surface_raised, UIPalette.line, UIPalette.R_LG, 1, Vector4(22, 20, 22, 20)))

	theme.set_type_variation("CardInset", "PanelContainer")
	theme.set_stylebox("panel", "CardInset", _box(UIPalette.ink, UIPalette.line_soft, UIPalette.R_MD, 1, Vector4(16, 14, 16, 14)))

	theme.set_type_variation("HeroCard", "PanelContainer")
	var hero := _box(UIPalette.surface_raised, UIPalette.line, UIPalette.R_XL, 1, Vector4(30, 26, 30, 26))
	hero.shadow_color = UIPalette.alpha(Color.BLACK, 0.28)
	hero.shadow_size = 18
	hero.shadow_offset = Vector2(0, 8)
	theme.set_stylebox("panel", "HeroCard", hero)

	theme.set_type_variation("ModalPanel", "PanelContainer")
	var modal := _box(UIPalette.surface, UIPalette.line, UIPalette.R_XL, 1, Vector4(32, 28, 32, 28))
	modal.shadow_color = UIPalette.alpha(Color.BLACK, 0.5)
	modal.shadow_size = 32
	theme.set_stylebox("panel", "ModalPanel", modal)

	theme.set_type_variation("HudPanel", "PanelContainer")
	var hud := _box(UIPalette.alpha(UIPalette.ink, 0.74), UIPalette.alpha(UIPalette.line, 0.9), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10))
	theme.set_stylebox("panel", "HudPanel", hud)

	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", _box(UIPalette.alpha(UIPalette.surface_high, 0.8), UIPalette.line, UIPalette.R_CHIP, 1, Vector4(10, 4, 10, 4)))

	theme.set_type_variation("RowPanel", "PanelContainer")
	var row := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(4, 10, 4, 10))
	row.border_width_bottom = 1
	row.border_color = UIPalette.line_soft
	theme.set_stylebox("panel", "RowPanel", row)

	theme.set_type_variation("SidebarPanel", "PanelContainer")
	theme.set_stylebox("panel", "SidebarPanel", _box(UIPalette.alpha(UIPalette.ink, 0.55), UIPalette.alpha(UIPalette.line, 0.8), UIPalette.R_LG, 1, Vector4(20, 18, 20, 18)))

	theme.set_type_variation("TransparentPanel", "PanelContainer")
	theme.set_stylebox("panel", "TransparentPanel", _empty_box())

	var accent_defs := [
		["ToneMint", UIPalette.mint],
		["ToneAmber", UIPalette.amber],
		["ToneDanger", UIPalette.danger],
		["ToneBlue", UIPalette.blue],
		["ToneViolet", UIPalette.violet],
		["ToneIvory", UIPalette.ivory],
	]
	for entry in accent_defs:
		var key: String = entry[0]
		var accent: Color = entry[1]
		theme.set_type_variation(key, "PanelContainer")
		var tone := _box(UIPalette.alpha(accent, 0.08), UIPalette.alpha(accent, 0.55), UIPalette.R_LG, 1, Vector4(20, 18, 20, 18))
		theme.set_stylebox("panel", key, tone)


# ---------------------------------------------------------------------------
# Progress bars
# ---------------------------------------------------------------------------

static func _setup_progress(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _box(UIPalette.ink, UIPalette.line_soft, UIPalette.R_SM, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("fill", "ProgressBar", _box(UIPalette.mint, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 0, 0, 0)))
	theme.set_color("font_color", "ProgressBar", UIPalette.ivory)
	_set_font(theme, "ProgressBar", UIFonts.mono(true), 11)

	var bars := [
		["BarMint", UIPalette.mint],
		["BarAmber", UIPalette.amber],
		["BarDanger", UIPalette.danger],
		["BarBlue", UIPalette.blue],
		["BarViolet", UIPalette.violet],
		["BarIvory", UIPalette.ivory],
	]
	for entry in bars:
		var key: String = entry[0]
		var fill: Color = entry[1]
		theme.set_type_variation(key, "ProgressBar")
		theme.set_stylebox("fill", key, _box(fill, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 0, 0, 0)))

	theme.set_type_variation("BarThin", "BarMint")
	theme.set_stylebox("background", "BarThin", _box(UIPalette.alpha(UIPalette.ink, 0.7), UIPalette.alpha(UIPalette.line, 0.7), UIPalette.R_SM, 1, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("fill", "BarThin", _box(UIPalette.mint, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 0, 0, 0)))


# ---------------------------------------------------------------------------
# Sliders
# ---------------------------------------------------------------------------

static func _setup_sliders(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider", _box(UIPalette.ink, UIPalette.line_soft, UIPalette.R_SM, 1, Vector4(0, 2, 0, 2)))
	theme.set_stylebox("grabber_area", "HSlider", _box(UIPalette.mint, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 2, 0, 2)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(UIPalette.brighten(UIPalette.mint, 0.05), Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 2, 0, 2)))
	theme.set_icon("grabber", "HSlider", _knob_texture(UIPalette.ivory, UIPalette.mint))
	theme.set_icon("grabber_highlight", "HSlider", _knob_texture(UIPalette.mint, UIPalette.ivory))
	theme.set_icon("grabber_disabled", "HSlider", _knob_texture(UIPalette.muted_dim, UIPalette.surface))
	theme.set_constant("center_grabber", "HSlider", 0)
	theme.set_constant("grabber_offset", "HSlider", 0)


static func _knob_texture(fill: Color, ring: Color) -> Texture2D:
	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(9.5, 9.5)
	for y in 20:
		for x in 20:
			var distance := Vector2(float(x), float(y)).distance_to(center)
			if distance <= 7.2:
				image.set_pixel(x, y, fill)
			elif distance <= 9.2:
				image.set_pixel(x, y, ring)
	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------------------
# Scrollbars
# ---------------------------------------------------------------------------

static func _setup_scrollbars(theme: Theme) -> void:
	for bar_type in ["VScrollBar", "HScrollBar"]:
		var vertical: bool = String(bar_type) == "VScrollBar"
		var track := _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 0, 0, 0))
		theme.set_stylebox("scroll", bar_type, track)
		var grabber := _box(UIPalette.alpha(UIPalette.line, 0.9), Color.TRANSPARENT, 4, 0)
		var grabber_hover := _box(UIPalette.muted_dim, Color.TRANSPARENT, 4, 0)
		var grabber_pressed := _box(UIPalette.mint_dim, Color.TRANSPARENT, 4, 0)
		if vertical:
			for style in [grabber, grabber_hover, grabber_pressed]:
				style.content_margin_left = 3
				style.content_margin_right = 3
		else:
			for style in [grabber, grabber_hover, grabber_pressed]:
				style.content_margin_top = 3
				style.content_margin_bottom = 3
		theme.set_stylebox("grabber", bar_type, grabber)
		theme.set_stylebox("grabber_highlight", bar_type, grabber_hover)
		theme.set_stylebox("grabber_pressed", bar_type, grabber_pressed)


# ---------------------------------------------------------------------------
# Check buttons, separators, tooltips, misc
# ---------------------------------------------------------------------------

static func _setup_misc(theme: Theme) -> void:
	# CheckButton (used for all boolean settings) as a switch.
	theme.set_type_variation("SwitchRow", "CheckButton")
	_set_font(theme, "CheckButton", UIFonts.body(400), 14)
	theme.set_color("font_color", "CheckButton", UIPalette.ivory)
	theme.set_color("font_hover_color", "CheckButton", UIPalette.ivory)
	theme.set_color("font_pressed_color", "CheckButton", UIPalette.ivory)
	theme.set_color("font_focus_color", "CheckButton", UIPalette.ivory)
	theme.set_color("font_disabled_color", "CheckButton", UIPalette.alpha(UIPalette.muted, 0.45))
	theme.set_icon("checked", "CheckButton", UIIcons.get_icon(&"toggle-on"))
	theme.set_icon("unchecked", "CheckButton", UIIcons.get_icon(&"toggle-off"))
	theme.set_icon("checked_disabled", "CheckButton", UIIcons.get_icon(&"toggle-off"))
	theme.set_icon("unchecked_disabled", "CheckButton", UIIcons.get_icon(&"toggle-off"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 4, 0, 4)))
	theme.set_stylebox("focus", "CheckButton", _focus_box(UIPalette.R_SM))
	theme.set_constant("h_separation", "CheckButton", UIPalette.SP3)

	# CheckBox (radio/tick variants for optional grids).
	_set_font(theme, "CheckBox", UIFonts.body(400), 14)
	theme.set_color("font_color", "CheckBox", UIPalette.ivory)
	theme.set_color("font_hover_color", "CheckBox", UIPalette.ivory)
	theme.set_icon("checked", "CheckBox", UIIcons.get_icon(&"checkbox-checked"))
	theme.set_icon("unchecked", "CheckBox", UIIcons.get_icon(&"checkbox"))
	theme.set_icon("radio_checked", "CheckBox", UIIcons.get_icon(&"radio-on"))
	theme.set_icon("radio_unchecked", "CheckBox", UIIcons.get_icon(&"radio-off"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckBox", _box(Color.TRANSPARENT, Color.TRANSPARENT, UIPalette.R_SM, 0, Vector4(0, 4, 0, 4)))
	theme.set_stylebox("focus", "CheckBox", _focus_box(UIPalette.R_SM))

	# Separators.
	theme.set_stylebox("separator", "HSeparator", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 0, 0, 0)))
	theme.set_stylebox("separator", "VSeparator", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(0, 0, 0, 0)))

	# Tooltips.
	theme.set_stylebox("panel", "TooltipPanel", _box(UIPalette.ink, UIPalette.line, UIPalette.R_SM, 1, Vector4(10, 7, 10, 7)))
	_set_font(theme, "TooltipLabel", UIFonts.body(400), 12)
	theme.set_color("font_color", "TooltipLabel", UIPalette.ivory)

	# Rich text (codex prose, tips).
	_set_font(theme, "RichTextLabel", UIFonts.body(400), UIPalette.FONT_BODY)
	theme.set_font("mono_font", "RichTextLabel", UIFonts.mono(false))
	theme.set_color("default_color", "RichTextLabel", UIPalette.ivory)
	theme.set_color("font_selected_color", "RichTextLabel", UIPalette.ink)
	theme.set_color("selection_color", "RichTextLabel", UIPalette.alpha(UIPalette.mint, 0.3))
	theme.set_stylebox("normal", "RichTextLabel", _empty_box())

	# Tab container fallback (unused directly, keeps defaults cohesive).
	theme.set_stylebox("panel", "TabContainer", _box(UIPalette.surface, UIPalette.line, UIPalette.R_MD, 1, Vector4(16, 14, 16, 14)))
