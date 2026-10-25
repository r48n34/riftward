class_name CinemaBossShot
extends UICinemaShot
## Act 01 — THREAT SIGNATURE. The loading cinema's boss screen.
##
## A code-drawn, faction-tinted boss reveal: layered halo, perspective stage
## grid, glowing seams, interference and a live threat dossier (name, class,
## phases, integrity/shield/armor, quote, counter-intel). The silhouette is
## rebuilt per `style` (titan / beast / flyer / swimmer / other) and per faction
## motif, so every authored boss presents differently.
##
## Everything is drawn from plain primitives: no textures, no 3D scene, no
## dependency on the deployment being generated behind the loader.

var brief: Dictionary = {}

var _boss: Dictionary = {}
var _body := Color("243744")
var _accent := Color("63b8ff")
var _eye := Color("b9f1ff")
var _faction := &"choir"
var _reveal := 0.0
var _boss_alpha := 1.0
var _art_rect := Rect2()
var _art_scale := 500.0
var _motes: Array = []
var _shards: Array = []
var _seeded := false
var _glitch_until := 0.0

var _dossier_margin: MarginContainer = null
var _dossier: VBoxContainer = null
var _name_label: Label = null
var _class_label: Label = null
var _quote_label: Label = null
var _counter_label: Label = null
var _footer_label: Label = null
var _phase_pips: HBoxContainer = null
var _integrity_bar: ProgressBar = null
var _shield_bar: ProgressBar = null
var _armor_value: Label = null
var _damage_value: Label = null
var _reveal_labels: Array[Control] = []
var _reveal_bars: Array[ProgressBar] = []

const DEFAULT_BOSS := {
	"id": &"the_warden",
	"name": "The Warden",
	"faction": &"choir",
	"faction_name": "Choir",
	"faction_color": Color("62e6c3"),
	"style": &"titan",
	"class_label": "TITAN-CLASS SIEGE FORM",
	"phases": 3,
	"health": 2800.0,
	"shield": 400.0,
	"armor": 35.0,
	"damage": 30.0,
	"speed": 3.6,
	"body_color": Color("243744"),
	"accent_color": Color("63b8ff"),
	"eye_color": Color("b9f1ff"),
	"body_scale": 2.8,
	"quote": "It was built to guard a door that no longer exists.",
	"counter": "Strip the relays first. Its shield folds when the choir goes quiet.",
	"tag": "GATEKEEPER",
}


func _on_shot_ready() -> void:
	shot_id = &"boss"
	static_pose_time = 2.4
	_build_dossier()
	resized.connect(_layout)
	_apply_boss(DEFAULT_BOSS)
	_layout()
	set_static_frame(UIPalette.reduce_motion)


# ---------------------------------------------------------------------------
# Public API (loading director + tests)
# ---------------------------------------------------------------------------

func set_brief(value: Dictionary) -> void:
	brief = value if value != null else {}
	var boss: Dictionary = brief.get("boss", {})
	_apply_boss(boss if not boss.is_empty() else DEFAULT_BOSS)
	_seed_scene()
	queue_redraw()


func get_boss() -> Dictionary:
	return _boss


func get_boss_id() -> StringName:
	return StringName(_boss.get("id", &""))


func get_boss_name() -> String:
	return String(_boss.get("name", "Unknown Signature"))


func get_dossier_rect() -> Rect2:
	return _dossier_margin.get_global_rect() if _dossier_margin != null and _dossier_margin.is_inside_tree() else Rect2()


func set_active_reveal(is_active: bool) -> void:
	super.set_active(is_active)


func set_active(is_active: bool) -> void:
	super.set_active(is_active)
	if not is_active:
		return
	_reveal = 0.0
	if is_frozen():
		_apply_static_reveal()
	else:
		_play_reveal()


func set_static_frame(is_static: bool) -> void:
	super.set_static_frame(is_static)
	if is_static:
		_apply_static_reveal()


func _apply_boss(boss: Dictionary) -> void:
	_boss = boss.duplicate(true)
	_body = _boss.get("body_color", Color("243744"))
	_accent = _boss.get("accent_color", Color("63b8ff"))
	_eye = _boss.get("eye_color", Color("b9f1ff"))
	_faction = StringName(_boss.get("faction", &"choir"))
	_glitch_until = 0.0
	_refresh_dossier()
	queue_redraw()


func _seed_scene() -> void:
	var rng := _seed_rng(int(StringName(_boss.get("id", &"boss")).hash()))
	_motes.clear()
	for i in 54:
		_motes.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"speed": rng.randf_range(0.01, 0.06),
			"size": rng.randf_range(0.6, 2.2),
			"alpha": rng.randf_range(0.05, 0.25),
			"phase": rng.randf_range(0.0, TAU),
		})
	_shards.clear()
	for i in 9:
		_shards.append({
			"angle": rng.randf_range(0.0, TAU),
			"radius": rng.randf_range(0.32, 0.62),
			"size": rng.randf_range(0.010, 0.030),
			"speed": rng.randf_range(0.15, 0.55),
			"phase": rng.randf_range(0.0, TAU),
		})
	_seeded = true


# ---------------------------------------------------------------------------
# Dossier
# ---------------------------------------------------------------------------

func _build_dossier() -> void:
	_dossier_margin = MarginContainer.new()
	_dossier_margin.name = "DossierMargin"
	_dossier_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dossier_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dossier_margin)

	_dossier = VBoxContainer.new()
	_dossier.name = "Dossier"
	_dossier.alignment = BoxContainer.ALIGNMENT_CENTER
	_dossier.add_theme_constant_override("separation", 9)
	_dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier_margin.add_child(_dossier)

	var eyebrow := UIFactory.label("THREAT SIGNATURE // PRIORITY ALPHA", "Eyebrow", UIPalette.danger)
	_reveal_labels.append(eyebrow)
	_dossier.add_child(eyebrow)

	_name_label = UIFactory.display_text("THE WARDEN", 54, 700, UIPalette.ivory)
	_name_label.name = "BossName"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_labels.append(_name_label)
	_dossier.add_child(_name_label)

	_class_label = UIFactory.label("", "MonoSmall", UIPalette.muted)
	_class_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_labels.append(_class_label)
	_dossier.add_child(_class_label)

	var tags := UIFactory.hbox(UIPalette.SP2)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier.add_child(tags)
	var faction_chip := UIFactory.chip("CHOIR", UIPalette.mint)
	faction_chip.name = "FactionChip"
	tags.add_child(faction_chip)
	var boss_chip := UIFactory.chip("BOSS", UIPalette.danger)
	tags.add_child(boss_chip)
	var tag_chip := UIFactory.chip("GATEKEEPER", UIPalette.amber)
	tag_chip.name = "TagChip"
	tags.add_child(tag_chip)

	_dossier.add_child(UIFactory.divider(UIPalette.alpha(UIPalette.line, 0.8)))

	_quote_label = UIFactory.wrapped("", "Flavor", UIPalette.ivory)
	_reveal_labels.append(_quote_label)
	_dossier.add_child(_quote_label)

	var phase_row := UIFactory.hbox(UIPalette.SP2)
	phase_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_row.add_child(UIFactory.label("PHASES", "StatLabel"))
	_phase_pips = UIFactory.pips(3, 3, UIPalette.danger, 9)
	_phase_pips.name = "PhasePips"
	phase_row.add_child(_phase_pips)
	phase_row.add_child(UIFactory.spacer_h())
	var phase_value := UIFactory.label("3", "MonoValue", UIPalette.danger)
	phase_value.name = "PhaseValue"
	phase_row.add_child(phase_value)
	_reveal_labels.append(phase_row)
	_dossier.add_child(phase_row)

	var integrity := _stat_bar_row("INTEGRITY", "BarDanger", UIPalette.danger)
	_integrity_bar = integrity[0]
	var integrity_value: Label = integrity[1]
	integrity_value.name = "IntegrityValue"
	_dossier.add_child(integrity[2])

	var shield := _stat_bar_row("SHIELD", "BarBlue", UIPalette.blue)
	_shield_bar = shield[0]
	var shield_value: Label = shield[1]
	shield_value.name = "ShieldValue"
	_dossier.add_child(shield[2])

	var small_stats := UIFactory.hbox(UIPalette.SP5)
	small_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armor_value = _mini_stat(small_stats, "ARMOR", "35", UIPalette.amber)
	_damage_value = _mini_stat(small_stats, "DAMAGE", "30", UIPalette.danger)
	_mini_stat(small_stats, "SPEED", "3.6", UIPalette.blue)
	_reveal_labels.append(small_stats)
	_dossier.add_child(small_stats)

	# Counter-intel: the one actionable instruction on the screen.
	var counter_panel := PanelContainer.new()
	counter_panel.name = "CounterIntel"
	counter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_panel.add_theme_stylebox_override(
		"panel",
		UITheme._box(UIPalette.alpha(UIPalette.amber, 0.08), UIPalette.alpha(UIPalette.amber, 0.55), UIPalette.R_MD, 1, Vector4(14, 10, 14, 10))
	)
	var counter_box := VBoxContainer.new()
	counter_box.add_theme_constant_override("separation", 3)
	counter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_panel.add_child(counter_box)
	counter_box.add_child(UIFactory.label("COUNTER-INTEL", "Eyebrow", UIPalette.amber))
	_counter_label = UIFactory.wrapped("", "BodySmall", UIPalette.ivory)
	_counter_label.name = "CounterIntelText"
	counter_box.add_child(_counter_label)
	_reveal_labels.append(counter_panel)
	_dossier.add_child(counter_panel)

	_footer_label = UIFactory.mono("", false, 10, UIPalette.muted_dim)
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dossier.add_child(_footer_label)


func _refresh_dossier() -> void:
	if _name_label == null:
		return
	var name := String(_boss.get("name", "Unknown Signature")).to_upper()
	_name_label.text = name
	_name_label.add_theme_font_size_override("font_size", 54 if name.length() <= 13 else 42)
	_class_label.text = "%s  ·  %s  ·  %s" % [
		_boss.get("class_label", "UNCLASSIFIED"),
		String(_boss.get("faction_name", "Unknown")).to_upper(),
		_boss.get("tag", "UNCLASSIFIED"),
	]
	var faction := String(_boss.get("faction_name", "Unknown")).to_upper()
	var faction_chip := _dossier.find_child("FactionChip", true, false) as PanelContainer
	if faction_chip != null:
		var accent: Color = _boss.get("faction_color", _accent)
		faction_chip.add_theme_stylebox_override(
			"panel",
			UITheme._box(UIPalette.alpha(accent, 0.1), UIPalette.alpha(accent, 0.55), UIPalette.R_CHIP, 1, Vector4(10, 4, 10, 4))
		)
		for child in faction_chip.get_children():
			if child is Label:
				(child as Label).text = faction
				(child as Label).add_theme_color_override("font_color", accent)
	var tag_chip := _dossier.find_child("TagChip", true, false) as PanelContainer
	if tag_chip != null:
		for child in tag_chip.get_children():
			if child is Label:
				(child as Label).text = String(_boss.get("tag", "UNCLASSIFIED"))
	_quote_label.text = "“%s”" % String(_boss.get("quote", ""))
	_counter_label.text = String(_boss.get("counter", ""))
	var phases := int(_boss.get("phases", 3))
	var phase_value := _dossier.find_child("PhaseValue", true, false) as Label
	if phase_value != null:
		phase_value.text = str(phases)
	if _phase_pips != null:
		UIFactory.clear_children(_phase_pips)
		for index in maxi(phases, 3):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(9, 9)
			pip.color = UIPalette.danger if index < phases else UIPalette.alpha(UIPalette.line, 0.9)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_phase_pips.add_child(pip)
	var health := maxf(1.0, float(_boss.get("health", 1.0)))
	var shield := float(_boss.get("shield", 0.0))
	_integrity_bar.max_value = health
	_integrity_bar.value = 0.0
	_shield_bar.max_value = maxf(1.0, health * 0.5)
	_shield_bar.value = 0.0
	_integrity_bar.set_meta("target_value", health)
	_shield_bar.set_meta("target_value", shield)
	var integrity_value := _dossier.find_child("IntegrityValue", true, false) as Label
	if integrity_value != null:
		integrity_value.text = UIPalette.format_int(int(health))
	var shield_value := _dossier.find_child("ShieldValue", true, false) as Label
	if shield_value != null:
		shield_value.text = UIPalette.format_int(int(shield))
	if _armor_value != null:
		_armor_value.text = str(int(round(float(_boss.get("armor", 0.0)))))
	if _damage_value != null:
		_damage_value.text = str(int(round(float(_boss.get("damage", 0.0)))))
	var seed_value := int(brief.get("seed", 0))
	var seed_text := "AUTO" if seed_value == 0 else UIPalette.format_int(seed_value)
	_footer_label.text = "SIGNAL LOCK 97%%  ·  SEED %s  ·  %s  ·  ROSTER %d/%d" % [
		seed_text,
		String(brief.get("map_name", "The Reach")).to_upper(),
		int(brief.get("boss_pool", 1)),
		int(brief.get("boss_pool", 1)),
	]


func _stat_bar_row(label_text: String, variation: String, accent: Color) -> Array:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := UIFactory.hbox(UIPalette.SP2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(UIFactory.label(label_text, "StatLabel", accent))
	header.add_child(UIFactory.spacer_h())
	var value := UIFactory.label("0", "MonoValue", UIPalette.ivory)
	header.add_child(value)
	row.add_child(header)
	var bar := UIFactory.progress(0.0, 1.0, variation, 5)
	row.add_child(bar)
	_reveal_bars.append(bar)
	_reveal_labels.append(row)
	return [bar, value, row]


func _mini_stat(parent: HBoxContainer, label_text: String, value_text: String, accent: Color) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UIFactory.label(label_text, "StatLabel"))
	var value := UIFactory.number_text(value_text, 16, accent)
	box.add_child(value)
	parent.add_child(box)
	return value


func _layout() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0 or height < 40.0:
		return
	_art_rect = Rect2(width * 0.03, height * 0.09, width * 0.56, height * 0.76)
	_art_scale = minf(_art_rect.size.y * 0.88, _art_rect.size.x * 0.94) * 0.80
	var panel_left := int(width * (0.60 if width >= 1180.0 else 0.56))
	_dossier_margin.add_theme_constant_override("margin_left", panel_left)
	_dossier_margin.add_theme_constant_override("margin_right", int(width * 0.05))
	_dossier_margin.add_theme_constant_override("margin_top", int(height * 0.19))
	_dossier_margin.add_theme_constant_override("margin_bottom", int(height * 0.20))
	if _dossier != null:
		_dossier.custom_minimum_size.x = maxf(340.0, float(width - panel_left - int(width * 0.05)))
	queue_redraw()


func _play_reveal() -> void:
	_reveal = 0.0
	for label in _reveal_labels:
		if is_instance_valid(label):
			label.modulate.a = 0.0
	for bar in _reveal_bars:
		bar.value = 0.0
	if not is_inside_tree():
		_apply_static_reveal()
		return
	var tween := create_tween()
	var delay := 0.06
	for label in _reveal_labels:
		if not is_instance_valid(label):
			continue
		tween.parallel().tween_property(label, "modulate:a", 1.0, UIPalette.motion(0.35)).set_delay(delay)
		delay += 0.055
	for bar in _reveal_bars:
		if not is_instance_valid(bar):
			continue
		var target := float(bar.get_meta("target_value", bar.max_value))
		tween.parallel().tween_property(bar, "value", target, UIPalette.motion(0.65)).set_delay(0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glitch_until = draw_time() + 0.5


func _apply_static_reveal() -> void:
	_reveal = 1.0
	for label in _reveal_labels:
		if is_instance_valid(label):
			label.modulate.a = 1.0
	for bar in _reveal_bars:
		bar.value = float(bar.get_meta("target_value", bar.max_value))


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 40.0 or height < 40.0:
		return
	if not _seeded:
		_seed_scene()
	var time := draw_time()
	_reveal = clampf(time / 0.85, 0.0, 1.0) if not is_frozen() else 1.0
	_boss_alpha = _ease_out(_reveal)
	_draw_backdrop(width, height, time)
	_draw_halo(width, height, time)
	_draw_stage_grid(width, height)
	_draw_beam(width, height, time)
	_draw_motes(width, height, time)
	_draw_boss(time)
	_draw_interference(width, height, time)
	_draw_subject_marks(height)
	_draw_foreground(width, height, time)


func _draw_backdrop(width: float, height: float, time: float) -> void:
	var top := UIPalette.darken(UIPalette.mix(UIPalette.ink, _body, 0.18), 0.02)
	var bottom := UIPalette.mix(UIPalette.ink, _body, 0.36)
	_draw_vertical_gradient(Rect2(0.0, 0.0, width, height), top, bottom, 40)
	# Caustic smears in the faction colour keep the frame from reading flat.
	for i in 5:
		var t := float(i) / 4.0
		var y := height * (0.22 + t * 0.56)
		draw_rect(
			Rect2(0.0, y, width, height * 0.035),
			UIPalette.alpha(_accent, 0.012 + 0.01 * sin(time * 0.3 + t * 4.0))
		)


func _draw_halo(width: float, height: float, time: float) -> void:
	var center := Vector2(_art_rect.position.x + _art_rect.size.x * 0.52, _art_rect.position.y + _art_rect.size.y * 0.48)
	var radius := _art_scale * 0.46
	var halo := UIPalette.alpha(_accent, 0.55)
	_draw_glow(center, radius * 1.9, UIPalette.alpha(_accent, 0.30), 18, 0.55)
	draw_circle(center, radius * 1.06, UIPalette.alpha(UIPalette.ink, 0.55))
	for ring in 3:
		var ring_radius := radius * (1.0 + float(ring) * 0.22)
		var segments := 96
		var start := time * (0.10 + float(ring) * 0.03) + float(ring) * 1.7
		draw_arc(center, ring_radius, start, start + TAU * 0.82, segments, UIPalette.alpha(halo, 0.20 - float(ring) * 0.045), 1.2, true)
	# Broken outer ring shards.
	for shard in _shards:
		var angle: float = float(shard.angle) + time * float(shard.speed) * 0.35
		var position := center + Vector2(cos(angle), sin(angle) * 0.42) * radius * float(shard.radius) * 2.2
		var size := _art_scale * float(shard.size)
		var wobble := sin(time * 1.2 + float(shard.phase)) * 4.0
		draw_colored_polygon(
			PackedVector2Array([
				position + Vector2(0, -size + wobble),
				position + Vector2(size * 0.55, size * 0.6),
				position + Vector2(-size * 0.55, size * 0.6),
			]),
			UIPalette.alpha(_accent, 0.10 + 0.05 * sin(time + float(shard.phase)))
		)
	# Eclipse disc behind the subject.
	draw_circle(center, radius * 0.72, UIPalette.alpha(UIPalette.ink, 0.78))
	draw_arc(center, radius * 0.72, -2.7, 1.4, 72, UIPalette.alpha(_accent, 0.5), 2.0, true)
	draw_arc(center, radius * 0.75, -2.6, 1.3, 72, UIPalette.alpha(_accent, 0.12), 8.0, true)
	# Three phase arcs: a slow mechanical countdown behind the subject.
	for index in 3:
		var start := -PI * 0.5 + float(index) * TAU / 3.0 + time * 0.12
		draw_arc(center, radius * 0.84, start, start + TAU / 3.0 - 0.22, 28, UIPalette.alpha(_accent, 0.26), 2.0, true)
		draw_circle(
			center + Vector2(cos(start), sin(start)) * radius * 0.84,
			2.6,
			UIPalette.alpha(_accent, 0.7)
		)
	# Faction motif.
	match _faction:
		&"bloom":
			for i in 5:
				var angle := time * 0.2 + float(i) * TAU / 5.0
				var start := center + Vector2(cos(angle), sin(angle) * 0.5) * radius * 0.9
				var end := center + Vector2(cos(angle + 0.3), sin(angle + 0.3) * 0.6) * radius * 1.6
				var mid := (start + end) * 0.5 + Vector2(sin(angle * 2.0) * 20.0, -18.0)
				draw_polyline(PackedVector2Array([start, mid, end]), UIPalette.alpha(_accent, 0.14), 1.4, true)
		&"ashen":
			for i in 8:
				var angle := float(i) * TAU / 8.0 + time * 0.05
				var start := center + Vector2(cos(angle), sin(angle)) * radius * 0.8
				var end := center + Vector2(cos(angle), sin(angle)) * radius * (1.3 + 0.1 * sin(time + float(i)))
				draw_line(start, end, UIPalette.alpha(_accent, 0.13), 1.0, true)
		_:
			pass


func _draw_stage_grid(width: float, height: float) -> void:
	var horizon := _art_rect.position.y + _art_rect.size.y * 0.84
	var vanish := Vector2(_art_rect.position.x + _art_rect.size.x * 0.52, horizon)
	var grid_color := UIPalette.alpha(_accent, 0.10)
	# Perspective floor.
	for i in 15:
		var t := float(i) / 14.0
		var x_bottom := _art_rect.position.x + _art_rect.size.x * lerpf(-0.25, 1.25, t)
		draw_line(Vector2(x_bottom, height * 0.96), vanish, UIPalette.alpha(_accent, 0.045), 1.0)
	for i in 7:
		var t := float(i) / 6.0
		var y := lerpf(horizon, height * 0.96, t * t)
		draw_line(Vector2(_art_rect.position.x - width * 0.02, y), Vector2(_art_rect.end.x + width * 0.02, y), UIPalette.alpha(_accent, 0.045 + 0.05 * t), 1.0)
	# Stage frame corners.
	var frame := Rect2(_art_rect.position + Vector2(-12, -16), _art_rect.size + Vector2(24, 22))
	var bracket := 26.0
	draw_line(Vector2(frame.position.x, frame.position.y + bracket), frame.position, grid_color, 1.4)
	draw_line(frame.position, Vector2(frame.position.x + bracket, frame.position.y), grid_color, 1.4)
	draw_line(Vector2(frame.end.x, frame.position.y + bracket), Vector2(frame.end.x, frame.position.y), grid_color, 1.4)
	draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x - bracket, frame.position.y), grid_color, 1.4)
	draw_line(Vector2(frame.position.x, frame.end.y - bracket), Vector2(frame.position.x, frame.end.y), grid_color, 1.4)
	draw_line(Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x + bracket, frame.end.y), grid_color, 1.4)
	draw_line(Vector2(frame.end.x, frame.end.y - bracket), Vector2(frame.end.x, frame.end.y), grid_color, 1.4)
	draw_line(Vector2(frame.end.x, frame.end.y), Vector2(frame.end.x - bracket, frame.end.y), grid_color, 1.4)


func _draw_beam(width: float, height: float, time: float) -> void:
	var center_x := _art_rect.position.x + _art_rect.size.x * 0.52
	var top := _art_rect.position.y + _art_rect.size.y * 0.06
	var bottom := _art_rect.position.y + _art_rect.size.y * 0.92
	var half := _art_scale * 0.22
	var pulse := 0.7 + 0.3 * sin(time * 1.3)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center_x - half * 0.25, top),
			Vector2(center_x + half * 0.25, top),
			Vector2(center_x + half, bottom),
			Vector2(center_x - half, bottom),
		]),
		UIPalette.alpha(_accent, 0.035 * pulse)
	)
	draw_line(Vector2(center_x, top), Vector2(center_x, bottom), UIPalette.alpha(_accent, 0.08 * pulse), 1.0)


func _draw_motes(width: float, height: float, time: float) -> void:
	for mote in _motes:
		var pos: Vector2 = mote.pos
		var x := fposmod(float(pos.x) + sin(time * 0.2 + float(mote.phase)) * 0.02, 1.0) * width
		var y := fposmod(float(pos.y) - time * float(mote.speed) * 0.15, 1.0) * height
		var twinkle := 0.5 + 0.5 * sin(time * 1.8 + float(mote.phase))
		draw_circle(Vector2(x, y), float(mote.size), UIPalette.alpha(_accent, float(mote.alpha) * twinkle))


func _draw_boss(time: float) -> void:
	var stage := _art_rect
	if stage.size.x < 10.0:
		return
	var origin := Vector2(
		stage.position.x + stage.size.x * 0.52,
		stage.position.y + stage.size.y * 0.90 + (1.0 - _boss_alpha) * stage.size.y * 0.05
	)
	var breathe := 1.0 + 0.006 * sin(time * 0.9)
	draw_set_transform(origin, 0.0, Vector2(breathe, breathe))
	# Contact shadow.
	draw_set_transform(origin, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, _art_scale * 0.30, UIPalette.alpha(UIPalette.ink, 0.65))
	draw_set_transform(origin, 0.0, Vector2(breathe, breathe))
	match StringName(_boss.get("style", &"titan")):
		&"beast":
			_draw_beast(time)
		&"flyer":
			_draw_flyer(time)
		&"swimmer":
			_draw_swimmer(time)
		&"heavy", &"humanoid", &"drone":
			_draw_titan(time, 0.86)
		_:
			_draw_titan(time, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_weakpoints(origin, time)


## Tactical weak-point brackets painted over the subject: the "boss screen"
## half of the loading cinema. Anchors follow the authored silhouette for each
## style so the brackets sit on the body at any resolution.
func _draw_weakpoints(origin: Vector2, time: float) -> void:
	var font := UIFonts.mono(true)
	var pulse := 0.65 + 0.35 * sin(time * 2.2)
	var style := StringName(_boss.get("style", &"titan"))
	var core_anchor := Vector2(0.0, 0.83)
	var optic_anchor := Vector2(0.0, 1.13)
	var core_radius := 0.105
	var optic_radius := 0.065
	match style:
		&"beast":
			core_anchor = Vector2(0.02, 0.44)
			optic_anchor = Vector2(0.645, 0.415)
			core_radius = 0.11
			optic_radius = 0.06
		&"flyer":
			core_anchor = Vector2(0.0, 0.865)
			optic_anchor = Vector2(0.0, 1.12)
			core_radius = 0.10
			optic_radius = 0.06
		&"swimmer":
			core_anchor = Vector2(0.0, 0.62)
			optic_anchor = Vector2(0.50, 0.82)
			core_radius = 0.12
			optic_radius = 0.075
		&"heavy", &"humanoid", &"drone":
			core_anchor = Vector2(0.0, 0.83 * 0.86)
			optic_anchor = Vector2(0.0, 1.13 * 0.86)
	_draw_weak_bracket(origin + _p(core_anchor.x, core_anchor.y), _art_scale * core_radius, _c(UIPalette.danger, 0.55 * pulse), "CORE", font)
	_draw_weak_bracket(origin + _p(optic_anchor.x, optic_anchor.y), _art_scale * optic_radius, _c(_accent, 0.5), "OPTIC", font)


func _draw_weak_bracket(center: Vector2, radius: float, color: Color, label: String, font: Font) -> void:
	var corner := radius * 0.55
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var x := center.x + radius * float(sx)
			var y := center.y + radius * float(sy)
			draw_line(Vector2(x, y), Vector2(x - corner * float(sx), y), color, 1.4)
			draw_line(Vector2(x, y), Vector2(x, y - corner * float(sy)), color, 1.4)
	draw_arc(center, radius * 0.62, 0.0, TAU, 24, UIPalette.alpha(color, 0.25), 1.0, true)
	draw_circle(center, 1.8, color)
	if font != null:
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var label_position := Vector2(center.x + radius + 8.0, center.y - 7.0)
		draw_rect(
			Rect2(label_position + Vector2(-4.0, -1.0), text_size + Vector2(8.0, 6.0)),
			UIPalette.alpha(UIPalette.ink, 0.62)
		)
		draw_string(
			font,
			label_position + Vector2(0.0, 9.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			UIPalette.alpha(color, 0.95)
		)
		draw_line(
			Vector2(center.x + radius * 0.78, center.y),
			Vector2(center.x + radius + 4.0, center.y),
			UIPalette.alpha(color, 0.55),
			1.0
		)


func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx * _art_scale, -ny * _art_scale)


## Normalised stage point helper: keeps authored y-values readable while the
## art remains resolution independent.
func _tp(x: float, y: float, unit: float = 1.0) -> Vector2:
	return Vector2(x, y * unit)


func _poly(points: Array, color: Color) -> void:
	var converted := PackedVector2Array()
	for point in points:
		var p: Vector2 = point
		converted.append(_p(p.x, p.y))
	draw_colored_polygon(converted, color)


func _line(a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), color, width, true)


func _stroke(points: Array, color: Color, width: float = 2.0, closed: bool = false) -> void:
	var converted := PackedVector2Array()
	for point in points:
		var p: Vector2 = point
		converted.append(_p(p.x, p.y))
	if closed and converted.size() > 2:
		converted.append(converted[0])
	draw_polyline(converted, color, width, true)


func _c(color: Color, alpha: float = 1.0) -> Color:
	return UIPalette.alpha(color, clampf(_boss_alpha * alpha, 0.0, 1.0))


func _draw_titan(time: float, scale: float) -> void:
	var unit := scale
	var body := _c(UIPalette.mix(_body, _accent, 0.10), 1.0)
	var body_dark := _c(UIPalette.mix(_body, UIPalette.ink, 0.38), 1.0)
	var plate := _c(UIPalette.mix(_body, _accent, 0.46), 1.0)
	var plate_dark := _c(UIPalette.mix(_body, _accent, 0.20), 1.0)
	var rim := _c(UIPalette.mix(_accent, UIPalette.ivory, 0.38), 0.95)
	var dark := _c(UIPalette.ink, 0.92)
	var pulse := 0.75 + 0.25 * sin(time * 1.6)

	# Ambient backlight so the silhouette separates from the stage.
	draw_circle(_p(0.0, 0.78 * unit), _art_scale * 0.36, _c(_accent, 0.045))
	draw_circle(_p(0.0, 0.78 * unit), _art_scale * 0.18, _c(_accent, 0.05))

	# Tattered cloak, drawn behind the body.
	_poly([_tp(-0.34, 0.98, unit), _tp(-0.02, 1.02, unit), _tp(-0.18, 0.34, unit), _tp(-0.47, 0.50, unit)], body_dark)
	_poly([_tp(0.34, 0.98, unit), _tp(0.02, 1.02, unit), _tp(0.18, 0.34, unit), _tp(0.47, 0.50, unit)], body_dark)
	_poly([_tp(-0.18, 0.46, unit), _tp(0.18, 0.46, unit), _tp(0.08, 0.12, unit), _tp(-0.07, 0.15, unit)], body_dark)
	_stroke([_tp(-0.47, 0.50, unit), _tp(-0.18, 0.34, unit), _tp(-0.08, 0.15, unit)], _c(_accent, 0.30), 1.2)
	_stroke([_tp(0.47, 0.50, unit), _tp(0.18, 0.34, unit), _tp(0.07, 0.15, unit)], _c(_accent, 0.30), 1.2)

	# Legs: feet, shins, knees, thighs.
	_poly([_tp(-0.24, 0.0, unit), _tp(-0.06, 0.0, unit), _tp(-0.055, 0.055, unit), _tp(-0.26, 0.07, unit)], dark)
	_poly([_tp(-0.21, 0.05, unit), _tp(-0.085, 0.05, unit), _tp(-0.10, 0.34, unit), _tp(-0.225, 0.32, unit)], body)
	_poly([_tp(-0.228, 0.30, unit), _tp(-0.095, 0.325, unit), _tp(-0.115, 0.41, unit), _tp(-0.245, 0.385, unit)], plate_dark)
	_poly([_tp(-0.24, 0.39, unit), _tp(-0.11, 0.415, unit), _tp(-0.155, 0.60, unit), _tp(-0.285, 0.565, unit)], body_dark)
	_poly([_tp(-0.245, 0.585, unit), _tp(-0.16, 0.60, unit), _tp(-0.17, 0.655, unit), _tp(-0.255, 0.64, unit)], body)
	_poly([_tp(0.24, 0.0, unit), _tp(0.06, 0.0, unit), _tp(0.055, 0.055, unit), _tp(0.26, 0.07, unit)], dark)
	_poly([_tp(0.21, 0.05, unit), _tp(0.085, 0.05, unit), _tp(0.10, 0.34, unit), _tp(0.225, 0.32, unit)], body)
	_poly([_tp(0.228, 0.30, unit), _tp(0.095, 0.325, unit), _tp(0.115, 0.41, unit), _tp(0.245, 0.385, unit)], plate_dark)
	_poly([_tp(0.24, 0.39, unit), _tp(0.11, 0.415, unit), _tp(0.155, 0.60, unit), _tp(0.285, 0.565, unit)], body_dark)
	_poly([_tp(0.245, 0.585, unit), _tp(0.16, 0.60, unit), _tp(0.17, 0.655, unit), _tp(0.255, 0.64, unit)], body)
	_line(_tp(0.10, 0.08, unit), _tp(0.105, 0.33, unit), _c(_accent, 0.30), 1.4)
	_line(_tp(-0.10, 0.08, unit), _tp(-0.105, 0.33, unit), _c(_accent, 0.18), 1.2)

	# Hips and belt.
	_poly([_tp(-0.28, 0.56, unit), _tp(0.28, 0.56, unit), _tp(0.235, 0.67, unit), _tp(-0.235, 0.67, unit)], body)
	_poly([_tp(-0.255, 0.63, unit), _tp(0.255, 0.63, unit), _tp(0.245, 0.685, unit), _tp(-0.245, 0.685, unit)], plate_dark)
	_poly([_tp(-0.05, 0.635, unit), _tp(0.05, 0.635, unit), _tp(0.045, 0.68, unit), _tp(-0.045, 0.68, unit)], _c(_eye, 0.55))

	# Torso.
	_poly([
		_tp(-0.26, 0.65, unit), _tp(0.26, 0.65, unit), _tp(0.42, 0.88, unit),
		_tp(0.35, 1.02, unit), _tp(-0.35, 1.02, unit), _tp(-0.42, 0.88, unit),
	], body)
	# Chest plate.
	_poly([
		_tp(-0.30, 0.75, unit), _tp(0.0, 0.71, unit), _tp(0.30, 0.75, unit),
		_tp(0.35, 0.90, unit), _tp(0.0, 0.97, unit), _tp(-0.35, 0.90, unit),
	], plate)
	_poly([
		_tp(-0.24, 0.665, unit), _tp(0.24, 0.665, unit), _tp(0.19, 0.735, unit), _tp(-0.19, 0.735, unit),
	], plate_dark)
	# Abdominal vents.
	for index in 3:
		var y := 0.60 + float(index) * 0.035
		_poly([_tp(-0.12, y, unit), _tp(0.12, y, unit), _tp(0.10, y + 0.018, unit), _tp(-0.10, y + 0.018, unit)], _c(UIPalette.ink, 0.65))
	_line(_tp(0.0, 0.66, unit), _tp(0.0, 1.0, unit), _c(_accent, 0.32), 1.6)
	_line(_tp(-0.34, 0.90, unit), _tp(-0.36, 1.0, unit), _c(_accent, 0.55), 2.4)
	_line(_tp(0.34, 0.90, unit), _tp(0.36, 1.0, unit), rim, 2.6)
	_stroke([
		_tp(0.35, 1.02, unit), _tp(0.42, 0.88, unit), _tp(0.26, 0.65, unit), _tp(0.235, 0.57, unit),
	], _c(_accent, 0.45), 1.8)

	# Arms. The right arm is held slightly forward for asymmetry.
	_poly([_tp(-0.44, 0.91, unit), _tp(-0.33, 0.855, unit), _tp(-0.36, 0.65, unit), _tp(-0.47, 0.68, unit)], body)
	_poly([_tp(-0.36, 0.65, unit), _tp(-0.47, 0.68, unit), _tp(-0.50, 0.51, unit), _tp(-0.39, 0.49, unit)], body_dark)
	_poly([_tp(-0.51, 0.46, unit), _tp(-0.39, 0.49, unit), _tp(-0.385, 0.535, unit), _tp(-0.50, 0.51, unit)], plate_dark)
	draw_circle(_p(-0.395, 0.655 * unit), _art_scale * 0.030, plate_dark)
	draw_circle(_p(-0.395, 0.655 * unit), _art_scale * 0.013, _c(_accent, 0.5))
	_poly([_tp(0.44, 0.91, unit), _tp(0.33, 0.855, unit), _tp(0.36, 0.63, unit), _tp(0.49, 0.66, unit)], body)
	_poly([_tp(0.49, 0.66, unit), _tp(0.36, 0.63, unit), _tp(0.40, 0.45, unit), _tp(0.54, 0.49, unit)], body_dark)
	_poly([_tp(0.55, 0.43, unit), _tp(0.41, 0.45, unit), _tp(0.405, 0.495, unit), _tp(0.54, 0.48, unit)], plate_dark)
	draw_circle(_p(0.395, 0.625 * unit), _art_scale * 0.030, plate_dark)
	draw_circle(_p(0.395, 0.625 * unit), _art_scale * 0.013, _c(_accent, 0.5))
	# Claws.
	for index in 3:
		var spread := float(index) * 0.028
		_line(_tp(0.54, 0.45 - spread, unit), _tp(0.60, 0.395 - spread, unit), _c(_accent, 0.6), 1.6)
		_line(_tp(-0.51, 0.48 - spread, unit), _tp(-0.57, 0.425 - spread, unit), _c(_accent, 0.35), 1.4)

	# Pauldrons and spikes.
	_poly([_tp(-0.35, 0.92, unit), _tp(-0.57, 0.84, unit), _tp(-0.68, 0.94, unit), _tp(-0.57, 1.05, unit), _tp(-0.36, 1.02, unit)], plate)
	_poly([_tp(-0.60, 0.98, unit), _tp(-0.74, 1.11, unit), _tp(-0.55, 1.06, unit)], plate_dark)
	_poly([_tp(0.35, 0.92, unit), _tp(0.57, 0.84, unit), _tp(0.68, 0.94, unit), _tp(0.57, 1.05, unit), _tp(0.36, 1.02, unit)], plate)
	_poly([_tp(0.60, 0.98, unit), _tp(0.74, 1.11, unit), _tp(0.55, 1.06, unit)], plate_dark)
	_poly([_tp(0.52, 0.86, unit), _tp(0.60, 0.78, unit), _tp(0.66, 0.88, unit), _tp(0.58, 0.94, unit)], plate_dark)
	_line(_tp(-0.36, 0.97, unit), _tp(-0.57, 1.05, unit), _c(_accent, 0.35), 2.0)
	_line(_tp(0.36, 0.97, unit), _tp(0.57, 1.05, unit), rim, 2.4)
	_stroke([_tp(0.36, 1.02, unit), _tp(0.57, 1.05, unit), _tp(0.68, 0.94, unit), _tp(0.57, 0.84, unit)], _c(_accent, 0.55), 1.8)

	# Neck and helmet.
	_poly([_tp(-0.08, 1.01, unit), _tp(0.08, 1.01, unit), _tp(0.065, 1.07, unit), _tp(-0.065, 1.07, unit)], body_dark)
	_poly([
		_tp(-0.135, 1.055, unit), _tp(0.135, 1.055, unit), _tp(0.155, 1.155, unit),
		_tp(0.10, 1.22, unit), _tp(-0.10, 1.22, unit), _tp(-0.155, 1.155, unit),
	], plate_dark)
	_poly([_tp(-0.125, 1.10, unit), _tp(0.125, 1.10, unit), _tp(0.10, 1.165, unit), _tp(-0.10, 1.165, unit)], dark)
	_line(_tp(-0.09, 1.125, unit), _tp(0.09, 1.125, unit), _c(_eye, 0.85 * pulse), 2.6)
	draw_circle(_p(-0.052, 1.145 * unit), _art_scale * 0.011, _c(_eye, 0.95))
	draw_circle(_p(0.052, 1.145 * unit), _art_scale * 0.011, _c(_eye, 0.95))
	draw_circle(_p(0.0, 1.14 * unit), _art_scale * 0.05, _c(_eye, 0.06))
	# Crown horns.
	_poly([_tp(-0.02, 1.21, unit), _tp(0.02, 1.21, unit), _tp(0.0, 1.34, unit)], plate)
	_poly([_tp(-0.135, 1.17, unit), _tp(-0.10, 1.16, unit), _tp(-0.23, 1.30, unit)], plate_dark)
	_poly([_tp(0.135, 1.17, unit), _tp(0.10, 1.16, unit), _tp(0.23, 1.30, unit)], plate_dark)
	_line(_tp(0.155, 1.155, unit), _tp(0.10, 1.22, unit), rim, 1.8)
	_line(_tp(0.135, 1.10, unit), _tp(0.155, 1.155, unit), rim, 1.8)

	# Chest core: the brightest point on the art.
	var core := _p(0.0, 0.83 * unit)
	draw_circle(core, _art_scale * 0.17, _c(_accent, 0.07 * pulse))
	draw_circle(core, _art_scale * 0.085, _c(_accent, 0.16))
	draw_circle(core, _art_scale * 0.048, _c(_eye, 0.55))
	draw_circle(core, _art_scale * 0.022, _c(UIPalette.ivory, 0.95))
	draw_circle(core, _art_scale * 0.010, _c(UIPalette.ivory, 1.0))
	for ring in 3:
		draw_arc(core, _art_scale * (0.09 + float(ring) * 0.03), time * 0.6 + float(ring), time * 0.6 + float(ring) + PI * 1.35, 28, _c(_accent, 0.22), 1.2, true)

	# Faction-specific surface treatment.
	match _faction:
		&"ashen":
			for index in 4:
				var start := _tp(-0.30 + float(index) * 0.17, 0.72 + float(index) * 0.06, unit)
				var mid := start + Vector2(_art_scale * 0.05, -_art_scale * 0.035)
				var end := mid + Vector2(_art_scale * 0.03, -_art_scale * 0.06)
				draw_polyline(PackedVector2Array([_p(start.x, start.y), _p(mid.x, mid.y), _p(end.x, end.y)]), _c(UIPalette.danger, 0.5), 1.2, true)
			# Foundry embers lift off the plating.
			for index in 10:
				var rise := fposmod(time * (0.10 + float(index) * 0.015) + float(index) * 0.19, 1.0)
				var ex := _art_scale * (-0.34 + float(index) * 0.075) + sin(time * 1.3 + float(index)) * 8.0
				var ey := -_art_scale * (0.15 + rise * 0.95)
				draw_circle(Vector2(ex, ey), 0.9 + 1.4 * (1.0 - rise), _c(_accent, 0.45 * (1.0 - rise)))
		&"bloom":
			for index in 3:
				var origin := _tp(-0.34 + float(index) * 0.34, 0.98, unit)
				var tip := origin + Vector2((float(index) - 1.0) * 0.10, 0.22)
				_stroke([origin, (origin + tip) * 0.5 + Vector2(0.04, 0.03), tip], _c(_accent, 0.25), 1.4)
		_:
			# Choir: floating coordinate shards orbit the shoulders.
			for index in 4:
				var angle := time * 0.5 + float(index) * TAU / 4.0
				var center := _p(0.56 + cos(angle) * 0.06, 0.80 + sin(angle) * 0.18)
				draw_colored_polygon(
					PackedVector2Array([
						center + Vector2(0, -_art_scale * 0.045),
						center + Vector2(_art_scale * 0.016, _art_scale * 0.022),
						center + Vector2(-_art_scale * 0.016, _art_scale * 0.022),
					]),
					_c(_accent, 0.40)
				)
	# Cool rim from the stage light picks out the left silhouette, contrasting the
	# warm faction fill.
	var cool := _c(UIPalette.mix(UIPalette.blue, UIPalette.ivory, 0.35), 0.8)
	_line(_tp(-0.43, 0.88, unit), _tp(-0.54, 0.79, unit), cool, 2.2)
	_line(_tp(-0.54, 0.79, unit), _tp(-0.64, 0.90, unit), cool, 1.8)
	_line(_tp(-0.33, 1.0, unit), _tp(-0.26, 0.82, unit), cool, 2.0)
	_line(_tp(-0.15, 1.14, unit), _tp(-0.15, 1.06, unit), cool, 1.8)
	_line(_tp(-0.11, 0.61, unit), _tp(-0.19, 0.39, unit), _c(UIPalette.blue, 0.45), 1.6)
	_line(_tp(-0.245, 0.39, unit), _tp(-0.20, 0.08, unit), _c(UIPalette.blue, 0.4), 1.4)
	# Core bloom and chest sheen.
	var core_bloom := _p(0.0, 0.83 * unit)
	draw_circle(core_bloom, _art_scale * 0.24, _c(_eye, 0.035 * pulse))
	draw_circle(core_bloom, _art_scale * 0.14, _c(_eye, 0.05 * pulse))
	_poly([_tp(-0.18, 0.96, unit), _tp(0.18, 0.96, unit), _tp(0.10, 0.86, unit), _tp(-0.10, 0.86, unit)], _c(UIPalette.ivory, 0.045))


func _draw_beast(time: float) -> void:
	var body := _c(UIPalette.darken(_body, 0.15), 0.95)
	var dark := _c(UIPalette.darken(_body, 0.38), 0.95)
	var plate := _c(UIPalette.mix(_body, _accent, 0.18), 0.95)
	var rim := _c(_accent, 0.65)
	# Four legs.
	for index in 4:
		var x := -0.32 + float(index) * 0.215
		var swing := sin(time * 0.8 + float(index)) * 0.012
		_poly([Vector2(x - 0.035, 0.0), Vector2(x + 0.035, 0.0), Vector2(x + 0.02 + swing, 0.34), Vector2(x - 0.02 + swing, 0.34)], dark)
	# Body and spine.
	_poly([
		Vector2(-0.42, 0.34), Vector2(-0.30, 0.50), Vector2(0.12, 0.56),
		Vector2(0.38, 0.48), Vector2(0.34, 0.30), Vector2(0.06, 0.24), Vector2(-0.30, 0.26),
	], body)
	_poly([Vector2(-0.26, 0.48), Vector2(0.24, 0.52), Vector2(0.16, 0.40), Vector2(-0.20, 0.38)], plate)
	# Neck and head.
	_poly([Vector2(0.30, 0.46), Vector2(0.44, 0.52), Vector2(0.60, 0.56), Vector2(0.58, 0.44), Vector2(0.42, 0.38)], body)
	_poly([Vector2(0.52, 0.42), Vector2(0.67, 0.44), Vector2(0.70, 0.37), Vector2(0.55, 0.33)], dark)
	draw_circle(_p(0.645, 0.415), _art_scale * 0.012, _c(_eye, 0.9))
	draw_circle(_p(0.645, 0.415), _art_scale * 0.032, _c(_eye, 0.10))
	# Back spines.
	for index in 4:
		var x := -0.22 + float(index) * 0.13
		_poly([
			Vector2(x - 0.03, 0.52), Vector2(x + 0.03, 0.52),
			Vector2(x + 0.01, 0.64 + 0.02 * float(index % 2)),
		], _c(UIPalette.mix(_accent, UIPalette.ink, 0.3), 0.75))
	# Tail.
	var tail := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		var point := _p(-0.42 - t * 0.24, 0.42 + sin(time * 1.4 + t * 4.0) * 0.04 * t - t * 0.10)
		tail.append(point)
	draw_polyline(tail, _c(_body, 0.8), 10.0, true)
	draw_polyline(tail, rim, 1.2, true)
	# Bloom growth on the back: the faction signature.
	for index in 5:
		var angle := float(index) / 5.0 * TAU + time * 0.2
		var center := _p(0.05 + cos(angle) * 0.06, 0.56 + sin(angle) * 0.02)
		draw_circle(center, _art_scale * 0.03, _c(_accent, 0.20))
		draw_circle(center, _art_scale * 0.012, _c(_eye, 0.55))
	_line(Vector2(-0.30, 0.34), Vector2(0.30, 0.30), _c(_accent, 0.22), 1.2)


func _draw_flyer(time: float) -> void:
	var body := _c(UIPalette.darken(_body, 0.18), 0.9)
	var dark := _c(UIPalette.darken(_body, 0.40), 0.9)
	var plate := _c(UIPalette.mix(_body, _accent, 0.25), 0.9)
	var hover := 0.10 * sin(time * 1.1)
	# Hovering torso, no legs.
	_poly([
		Vector2(-0.18, 0.64 + hover), Vector2(0.18, 0.64 + hover),
		Vector2(0.24, 0.88 + hover), Vector2(0.10, 1.02 + hover),
		Vector2(-0.10, 1.02 + hover), Vector2(-0.24, 0.88 + hover),
	], body)
	_poly([Vector2(-0.10, 1.02 + hover), Vector2(0.10, 1.02 + hover), Vector2(0.08, 1.14 + hover), Vector2(-0.08, 1.14 + hover)], dark)
	draw_circle(_p(0.0, 0.865 + hover), _art_scale * 0.03, _c(_eye, 0.8))
	draw_circle(_p(0.0, 0.865 + hover), _art_scale * 0.09, _c(_accent, 0.10))
	# Wing shards.
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		for index in 4:
			var length := 0.24 + 0.07 * float(index)
			var angle := -0.18 + float(index) * 0.14 * (1.0 if side > 0.0 else -1.0)
			var origin := _p(0.16 * side, 0.92 + hover)
			var tip := origin + Vector2(side * _art_scale * length, -_art_scale * (0.10 + angle * 0.2))
			var root_top := origin + Vector2(side * _art_scale * 0.05, -_art_scale * 0.05)
			var root_bottom := origin + Vector2(side * _art_scale * 0.04, _art_scale * 0.05)
			draw_colored_polygon(PackedVector2Array([root_top, tip, root_bottom]), _c(_accent, 0.18 + float(index) * 0.03))
	# Halo fragments.
	for index in 6:
		var angle := time * 0.25 + float(index) / 6.0 * TAU
		var radius := 0.42 + 0.03 * sin(time + float(index))
		draw_circle(_p(cos(angle) * radius, 0.86 + sin(angle) * radius * 0.35), _art_scale * 0.015, _c(_eye, 0.5))
	_line(Vector2(0.22, 0.82), Vector2(0.30, 0.80), _c(_accent, 0.4), 1.4)


func _draw_swimmer(time: float) -> void:
	var body := _c(UIPalette.mix(_body, UIPalette.ink, 0.10), 1.0)
	var dark := _c(UIPalette.mix(_body, UIPalette.ink, 0.48), 1.0)
	var belly := _c(UIPalette.mix(_body, _accent, 0.45), 0.85)
	var pulse := 0.6 + 0.4 * sin(time * 1.4)
	# A rising serpent fills the stage: tail low-left, head high-right.
	var centerline: Array[Vector2] = []
	var count := 20
	for i in count:
		var t := float(i) / float(count - 1)
		centerline.append(Vector2(
			lerpf(-0.56, 0.50, t),
			0.46 + sin(t * PI * 2.35 + time * 0.7) * 0.15 + t * 0.30
		))
	var screen := PackedVector2Array()
	for point in centerline:
		screen.append(_p(point.x, point.y))
	# Tail fin.
	var tail := screen[0]
	draw_colored_polygon(
		PackedVector2Array([
			tail,
			tail + Vector2(-_art_scale * 0.18, -_art_scale * 0.13),
			tail + Vector2(-_art_scale * 0.10, _art_scale * 0.05),
		]),
		belly
	)
	draw_colored_polygon(
		PackedVector2Array([
			tail,
			tail + Vector2(-_art_scale * 0.18, _art_scale * 0.03),
			tail + Vector2(-_art_scale * 0.07, _art_scale * 0.13),
		]),
		dark
	)
	# Segmented body with a lit dorsal rim and underbelly.
	for i in screen.size() - 1:
		var t := float(i) / float(screen.size() - 1)
		var width := lerpf(_art_scale * 0.17, _art_scale * 0.065, t)
		draw_line(screen[i], screen[i + 1], dark if i % 3 == 0 else body, width, true)
		draw_line(screen[i] + Vector2(0, width * 0.24), screen[i + 1] + Vector2(0, width * 0.24), belly, width * 0.30, true)
		draw_line(screen[i] - Vector2(0, width * 0.36), screen[i + 1] - Vector2(0, width * 0.36), _c(_accent, 0.30), 1.4, true)
	# Dorsal fins and bioluminescent spots.
	for i in range(2, screen.size() - 3, 3):
		var t := float(i) / float(screen.size() - 1)
		var base := screen[i]
		var fin_height := _art_scale * (0.09 + 0.04 * sin(time + t * 6.0))
		draw_colored_polygon(
			PackedVector2Array([
				base + Vector2(-_art_scale * 0.04, 0.0),
				base + Vector2(_art_scale * 0.03, 0.0),
				base + Vector2(-_art_scale * 0.02, -fin_height),
			]),
			_c(_accent, 0.22)
		)
		draw_circle(base + Vector2(0.0, _art_scale * 0.06), _art_scale * 0.014, _c(_eye, 0.55 + 0.35 * pulse))
	# Head: wedge, jaw, eye, tendrils.
	var head := screen[screen.size() - 1]
	var forward := (screen[screen.size() - 1] - screen[screen.size() - 3]).normalized()
	var side := Vector2(-forward.y, forward.x)
	var s := _art_scale
	draw_colored_polygon(
		PackedVector2Array([
			head + forward * s * 0.16 + side * s * 0.02,
			head + forward * s * 0.05 + side * s * 0.11,
			head - forward * s * 0.08 + side * s * 0.08,
			head - forward * s * 0.10 - side * s * 0.05,
			head + forward * s * 0.04 - side * s * 0.09,
		]),
		dark
	)
	draw_colored_polygon(
		PackedVector2Array([
			head + forward * s * 0.16 + side * s * 0.02,
			head + forward * s * 0.04 + side * s * 0.03,
			head - forward * s * 0.08 + side * s * 0.03,
			head - forward * s * 0.03 + side * s * 0.10,
		]),
		belly
	)
	draw_line(
		head + forward * s * 0.06 + side * s * 0.04,
		head + forward * s * 0.14 + side * s * 0.03,
		_c(_accent, 0.8),
		2.0,
		true
	)
	var eye_position := head + forward * s * 0.07 + side * s * 0.04
	draw_circle(eye_position, s * 0.020, _c(_eye, 0.95))
	draw_circle(eye_position, s * 0.060, _c(_eye, 0.10))
	for i in 3:
		var root := head - forward * s * (0.02 + float(i) * 0.03) - side * s * 0.05
		draw_line(root, root - side * s * (0.14 + float(i) * 0.04) + forward * s * 0.05, _c(_accent, 0.30), 1.4, true)


## Scanline sweep + signal interference. Kept subtle so the dossier stays
## readable on top of it.
func _draw_interference(width: float, height: float, time: float) -> void:
	var scan_y := _art_rect.position.y + fposmod(time * 0.28, 1.0) * _art_rect.size.y
	draw_rect(Rect2(_art_rect.position.x, scan_y - 10.0, _art_rect.size.x, 20.0), UIPalette.alpha(_accent, 0.025))
	draw_rect(Rect2(_art_rect.position.x, scan_y, _art_rect.size.x, 1.0), UIPalette.alpha(_accent, 0.22))
	if fmod(time, 3.3) < 0.16 or (not is_frozen() and time < 0.5):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(floor(time * 22.0)) * 131 + 7
		for i in 3:
			var y := _art_rect.position.y + rng.randf() * _art_rect.size.y
			var h := rng.randf_range(1.0, 5.0)
			var color := _accent if i % 2 == 0 else UIPalette.danger
			draw_rect(
				Rect2(_art_rect.position.x + rng.randf_range(-20.0, 40.0), y, _art_rect.size.x * rng.randf_range(0.5, 1.0), h),
				UIPalette.alpha(color, 0.22)
			)
	# Faint scanlines across the art area.
	var line_color := UIPalette.alpha(UIPalette.ink, 0.16)
	var step := 4.0
	var y := _art_rect.position.y
	while y < _art_rect.end.y:
		draw_rect(Rect2(_art_rect.position.x, y, _art_rect.size.x, 1.0), line_color)
		y += step


## Vertical subject slate on the left edge of the art. Reads like a tactical
## overlay without competing with the dossier text on the right.
func _draw_subject_marks(height: float) -> void:
	var font := UIFonts.mono(false)
	if font == null:
		return
	var seed_value := int(brief.get("seed", 0))
	var seed_text := "AUTO" if seed_value == 0 else UIPalette.format_int(seed_value)
	var text := "SUBJECT // %s" % String(_boss.get("name", "UNKNOWN")).to_upper()
	draw_set_transform(Vector2(24.0, height * 0.72), -PI * 0.5, Vector2.ONE)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIPalette.alpha(_accent, 0.42))
	draw_string(
		font,
		Vector2(0.0, 13.0),
		"%s // SEED %s" % [String(_boss.get("faction_name", "UNKNOWN")).to_upper(), seed_text],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		UIPalette.alpha(UIPalette.muted, 0.55)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Edge registration ticks.
	for index in 10:
		var t := float(index) / 9.0
		var y := lerpf(height * 0.20, height * 0.68, t)
		draw_line(Vector2(18.0, y), Vector2(24.0, y), UIPalette.alpha(_accent, 0.18), 1.0)


func _draw_foreground(width: float, height: float, time: float) -> void:
	var ground := _art_rect.position.y + _art_rect.size.y * 0.93
	draw_rect(Rect2(0.0, ground + 4.0, width, height - ground), UIPalette.alpha(UIPalette.ink, 0.35))
	# Arena rubble and broken plating in front of the subject.
	for index in 7:
		var t := float(index) / 6.0
		var x := _art_rect.position.x + _art_rect.size.x * (0.05 + t * 0.90)
		var rubble := _art_scale * (0.018 + 0.012 * float(index % 3))
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x - rubble, ground + height * 0.018),
				Vector2(x - rubble * 0.3, ground - rubble * 1.4),
				Vector2(x + rubble * 0.8, ground - rubble * 0.6),
				Vector2(x + rubble * 1.3, ground + height * 0.018),
			]),
			UIPalette.alpha(UIPalette.mix(_body, UIPalette.ink, 0.55), 0.55)
		)
	for i in 8:
		var t := float(i) / 7.0
		var center_x := _art_rect.position.x + _art_rect.size.x * (0.05 + t * 0.9)
		var radius := _art_scale * (0.05 + 0.03 * sin(time * 0.4 + t * 5.0))
		draw_set_transform(Vector2(center_x, ground + 6.0), 0.0, Vector2(2.2, 0.35))
		draw_circle(Vector2.ZERO, radius, UIPalette.alpha(UIPalette.mix(_body, UIPalette.ink, 0.5), 0.20))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
