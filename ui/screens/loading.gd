class_name LoadingScreen
extends Control
## Deployment loading cover: title, progress, rotating field notes. Shown through
## UIRoot.show_loading / update_loading / hide_loading while App builds a run.

const TIPS := [
	["FIELD NOTE", "The Ashen rebuild faster than they fight. Hit relays, not patrols."],
	["FIELD NOTE", "Shield regen pauses while you take damage. Break contact, then re-engage."],
	["FIELD NOTE", "Driftlings can carry loot to exfil. Keep your pet alive out there."],
	["FIELD NOTE", "The Collapse starts after twelve minutes. Bank salvage before the storm."],
	["FIELD NOTE", "Outpost reactor tiers shave time off every ability cooldown."],
	["FIELD NOTE", "Warden medics restore squad shields, not just health. Stay in the field."],
	["FIELD NOTE", "Vault doors are sealed for a reason. Bring a squad that can open them."],
]

var _title: Label = null
var _step_label: Label = null
var _percent: Label = null
var _bar: ProgressBar = null
var _tip_row: HBoxContainer = null
var _tip_line: Label = null
var _tip_index := 0
var _tip_accum := 0.0
var _progress := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var backdrop := UIBackdrop.new()
	backdrop.configure(UIBackdrop.Mood.HUB)
	add_child(backdrop)
	var scrim := ColorRect.new()
	scrim.color = UIPalette.alpha(UIPalette.ink, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := UIFactory.vbox(UIPalette.SP5)
	column.custom_minimum_size = Vector2(660, 0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(column)

	var brand := UIFactory.hbox(UIPalette.SP2)
	brand.add_child(UIFactory.icon(&"outpost", 18, UIPalette.mint))
	brand.add_child(UIFactory.label("RIFTWARD · FRONTIER OPERATIONS", "Eyebrow", UIPalette.mint))
	column.add_child(brand)

	_title = UIFactory.heading("Preparing the Reach", "H1")
	column.add_child(_title)

	var progress_row := UIFactory.hbox(UIPalette.SP3)
	_step_label = UIFactory.label("Initialising deployment", "BodySmall")
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(_step_label)
	_percent = UIFactory.label("0%", "MonoValue", UIPalette.mint)
	progress_row.add_child(_percent)
	column.add_child(progress_row)

	_bar = UIFactory.progress(0.0, 100.0, "BarMint", 8)
	_bar.tooltip_text = "Terrain generation and navigation baking happen during the drop."
	column.add_child(_bar)

	column.add_child(UIFactory.fixed_spacer(0, UIPalette.SP4))
	# One icon + short line; the full field note rides on the tooltip.
	var tip_panel := UIFactory.panel("CardInset")
	var tip_box := UIFactory.pad_all(_make_tip_row(), 0)
	tip_panel.add_child(tip_box)
	column.add_child(tip_panel)

	var footer := UIFactory.hbox(UIPalette.SP3)
	footer.add_child(UIFactory.spacer_h())
	footer.add_child(UIFactory.label("ESC to abort", "Micro", UIPalette.muted_dim))
	column.add_child(footer)

	_apply_tip(0)


func _make_tip_row() -> HBoxContainer:
	_tip_row = UIFactory.hbox(UIPalette.SP2)
	_tip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var glyph := UIFactory.icon_or_null(&"info", 14, UIPalette.amber)
	if glyph != null:
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tip_row.add_child(glyph)
	_tip_line = UIFactory.label("", "BodySmall", UIPalette.ivory)
	_tip_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tip_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tip_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_row.add_child(_tip_line)
	return _tip_row


func _process(delta: float) -> void:
	if not visible or UIPalette.reduce_motion:
		return
	_tip_accum += delta
	if _tip_accum >= 5.0:
		_tip_accum = 0.0
		_apply_tip((_tip_index + 1) % TIPS.size())


func _apply_tip(index: int) -> void:
	_tip_index = index
	var body := String(TIPS[index][1])
	if _tip_line != null:
		_tip_line.text = _short_tip(body)
	if _tip_row != null:
		_tip_row.tooltip_text = body


## First sentence only; the full note stays on the tooltip. Keeps the loading
## cover to a single quiet line.
func _short_tip(text: String) -> String:
	var cut := text.find(". ")
	if cut > 0:
		return text.substr(0, cut + 1)
	if text.length() > 58:
		return text.substr(0, 55) + "…"
	return text


# ---------------------------------------------------------------------------
# API used by UIRoot
# ---------------------------------------------------------------------------

func present(title: String, progress: float = 0.0) -> void:
	visible = true
	_tip_accum = 0.0
	_apply_tip(randi() % TIPS.size())
	if _title != null:
		_title.text = title
	update_loading(progress, "Initialising deployment")


func update_loading(progress: float, label: String) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	if _bar != null:
		_bar.value = _progress * 100.0
	if _percent != null:
		_percent.text = "%d%%" % int(round(_progress * 100.0))
	if _step_label != null and not label.is_empty():
		_step_label.text = label


func dismiss() -> void:
	visible = false
