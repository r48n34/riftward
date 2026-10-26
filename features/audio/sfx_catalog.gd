extends RefCounted
## Pure-data SFX recipe table + procedural PCM synthesis for AudioDirector.
##
## `features/audio/sfx_catalog.gd` owns the sound design: one row per catalog id
## (kind / frequency / duration / volume / bus / options) plus a hand-written
## renderer per synth kind. It deliberately never touches the SceneTree, the
## AudioServer or any Resource, so a fresh instance can be handed to a
## WorkerThreadPool task and fill a plain result Dictionary while the main thread
## keeps playing. AudioDirector turns that PCM into AudioStreamWAV on the main
## thread (resource creation is cheap; sample generation is not).
##
## Recipe row format:
##   [kind: String, freq: float, dur: float, vol: float, bus: String, opts?: Dictionary]
##
## Every extra option is renderer specific (loop, decay, ring, lfo, down, up,
## partials, wet, roar, snarl, hurt, noise...). Unknown options are ignored, so
## the table stays append-only and tolerant.

const SAMPLE_RATE := 16000
const NOISE_SCALE := 1.0 / 1073741824.0
## Guard against a zero-length AudioStreamWAV from a bad recipe row.
const MIN_SAMPLES := 8
## Loop seam crossfade length in seconds; the rendered tail is folded into the
## head so the wrap point is sample continuous.
const LOOP_WRAP_SEC := 0.14

# ---------------------------------------------------------------------------
# Recipe table. Ids are grouped by gameplay system; other streams call these
# ids by name, so treat them as public API (append, never rename casually).
# ---------------------------------------------------------------------------
const RECIPES := {
	# --- UI -----------------------------------------------------------------
	"ui_click": ["click", 980.0, 0.055, 0.32, "UI"],
	"ui_hover": ["tone", 1240.0, 0.035, 0.12, "UI"],
	"ui_confirm": ["chime", 680.0, 0.22, 0.26, "UI"],
	"ui_error": ["buzz", 160.0, 0.18, 0.25, "UI"],
	"ui_skip": ["click", 640.0, 0.09, 0.22, "UI"],
	"ui_tab": ["click", 760.0, 0.06, 0.20, "UI"],
	"ui_slider": ["click", 520.0, 0.03, 0.10, "UI"],
	"ui_open": ["sweep", 420.0, 0.26, 0.22, "UI"],
	"ui_close": ["sweep", 520.0, 0.20, 0.20, "UI", {"down": true}],

	# --- Weapons ------------------------------------------------------------
	"shot_rifle": ["shot", 130.0, 0.20, 0.62, "SFX"],
	"shot_smg": ["shot", 180.0, 0.11, 0.48, "SFX"],
	"shot_shotgun": ["boom", 85.0, 0.34, 0.72, "SFX"],
	"shot_dmr": ["shot", 100.0, 0.31, 0.66, "SFX"],
	"shot_sniper": ["rail", 72.0, 0.55, 0.70, "SFX"],
	"shot_lmg": ["shot", 115.0, 0.17, 0.55, "SFX"],
	"shot_pistol": ["shot", 210.0, 0.12, 0.42, "SFX"],
	"shot_launcher": ["boom", 70.0, 0.30, 0.62, "SFX"],
	"shot_arc": ["zap", 420.0, 0.22, 0.45, "SFX"],
	"shot_carbine": ["shot", 160.0, 0.15, 0.46, "SFX"],
	"shot_rifle_tail": ["hiss", 900.0, 0.35, 0.18, "SFX", {"decay": 5.0}],
	"shot_smg_tail": ["hiss", 1100.0, 0.22, 0.14, "SFX", {"decay": 6.0}],
	"shot_shotgun_tail": ["hiss", 700.0, 0.45, 0.20, "SFX", {"decay": 3.5}],
	"shot_sniper_tail": ["hiss", 500.0, 0.70, 0.22, "SFX", {"decay": 2.4}],
	"shot_launcher_tail": ["hiss", 380.0, 0.60, 0.20, "SFX", {"decay": 2.8}],
	"reload": ["reload", 320.0, 0.52, 0.28, "SFX"],
	"reload_start": ["click", 480.0, 0.10, 0.20, "SFX"],
	"reload_mag_in": ["thump", 220.0, 0.16, 0.24, "SFX"],
	"reload_bolt": ["click", 900.0, 0.12, 0.22, "SFX"],
	"knife_swing": ["whoosh", 720.0, 0.12, 0.18, "SFX"],
	"knife_hit": ["hit", 320.0, 0.08, 0.30, "SFX"],
	"hit": ["hit", 1600.0, 0.045, 0.23, "SFX"],
	"hitmarker": ["chime", 1450.0, 0.08, 0.22, "SFX"],
	"headshot": ["chime", 2100.0, 0.15, 0.32, "SFX"],
	"headshot_crit": ["chime", 2400.0, 0.20, 0.34, "SFX", {"partials": 3}],
	"kill": ["kill", 520.0, 0.18, 0.25, "SFX"],
	"kill_alt": ["kill", 620.0, 0.22, 0.24, "SFX"],
	"kill_streak": ["fanfare", 660.0, 0.50, 0.30, "SFX"],
	"explosion": ["boom", 55.0, 0.65, 0.82, "SFX"],
	"impact_metal": ["impact", 520.0, 0.18, 0.35, "SFX", {"ring": 3.4}],
	"impact_flesh": ["thump", 140.0, 0.12, 0.28, "SFX"],
	"impact_shield": ["glass", 1800.0, 0.28, 0.34, "SFX"],
	"shield_break": ["glass", 1800.0, 0.40, 0.42, "SFX", {"decay": 2.2}],
	"shield_hit": ["glass", 1400.0, 0.16, 0.26, "SFX", {"decay": 4.0}],
	"armor_plate": ["impact", 380.0, 0.16, 0.30, "SFX", {"ring": 2.2}],
	"armor_break": ["boom", 240.0, 0.35, 0.36, "SFX"],
	"player_hurt": ["thump", 90.0, 0.22, 0.50, "SFX"],
	"grenade_throw": ["whoosh", 400.0, 0.22, 0.22, "SFX"],
	"grenade_bounce": ["impact", 300.0, 0.18, 0.26, "SFX", {"ring": 1.6}],
	"grenade_pin": ["click", 1200.0, 0.07, 0.18, "SFX"],
	"grenade_explode": ["boom", 62.0, 0.55, 0.70, "SFX"],

	# --- Abilities ----------------------------------------------------------
	"ability": ["sweep", 420.0, 0.35, 0.36, "SFX"],
	"ability_ready": ["chime", 940.0, 0.18, 0.18, "SFX"],
	"ability_cast_a": ["sweep", 300.0, 0.45, 0.34, "SFX", {"noise": 0.12}],
	"ability_cast_b": ["zap", 360.0, 0.35, 0.34, "SFX"],
	"ability_cast_c": ["chime", 520.0, 0.40, 0.32, "SFX", {"partials": 3}],

	# --- Player movement ----------------------------------------------------
	"footstep": ["step", 100.0, 0.07, 0.12, "SFX"],
	"footstep_metal": ["step", 180.0, 0.06, 0.14, "SFX", {"ring": 2400.0}],
	"footstep_grass": ["step", 70.0, 0.09, 0.11, "SFX"],
	"footstep_water": ["step", 250.0, 0.10, 0.14, "SFX", {"wet": true}],
	"jump": ["whoosh", 260.0, 0.18, 0.20, "SFX", {"up": true}],
	"land": ["thump", 80.0, 0.20, 0.34, "SFX"],
	"vault": ["whoosh", 300.0, 0.26, 0.24, "SFX", {"up": true}],
	"swim": ["water", 200.0, 0.35, 0.16, "SFX"],
	"splash": ["splash", 400.0, 0.30, 0.30, "SFX"],
	"lava_sizzle": ["crackle", 900.0, 0.55, 0.22, "SFX"],

	# --- Ambience / weather loops (bus Ambience, seamless) ------------------
	"wind_ambient": ["wind", 120.0, 2.6, 0.22, "Ambience", {"loop": true}],
	"wind_loop": ["wind", 160.0, 2.2, 0.24, "Ambience", {"loop": true}],
	"water_loop": ["water", 90.0, 2.4, 0.20, "Ambience", {"loop": true}],
	"lava_loop": ["lava", 60.0, 2.4, 0.22, "Ambience", {"loop": true}],
	"birds": ["birds", 1200.0, 2.8, 0.16, "Ambience", {"loop": true}],
	"crickets": ["crickets", 2400.0, 2.2, 0.12, "Ambience", {"loop": true}],
	"shrine_hum": ["drone", 96.0, 2.4, 0.18, "Ambience", {"loop": true}],
	"storm": ["rumble", 42.0, 1.2, 0.30, "SFX"],
	"storm_rumble": ["rumble", 36.0, 2.0, 0.26, "SFX"],
	"storm_wind": ["wind", 140.0, 2.2, 0.22, "Ambience", {"loop": true}],
	"storm_thunder": ["thunder", 46.0, 1.8, 0.34, "SFX"],
	"dungeon_ambient": ["drone", 55.0, 2.6, 0.18, "Ambience", {"loop": true}],
	"dungeon_drone": ["drone", 72.0, 2.4, 0.14, "Ambience", {"loop": true}],

	# --- World objects, exfil and progression -------------------------------
	"door": ["thump", 65.0, 0.26, 0.30, "SFX"],
	"hydraulic_door": ["servo", 140.0, 0.45, 0.28, "SFX"],
	"hatch": ["impact", 240.0, 0.22, 0.30, "SFX", {"ring": 1.4}],
	"radio_chirp": ["beep", 1800.0, 0.28, 0.22, "SFX"],
	"insertion_thud": ["boom", 48.0, 0.45, 0.48, "SFX"],
	"cache_open": ["chime", 760.0, 0.35, 0.26, "SFX", {"partials": 3}],
	"build_complete": ["fanfare", 523.25, 0.80, 0.30, "SFX"],
	"outpost_upgrade": ["fanfare", 392.0, 0.90, 0.32, "SFX"],
	"level_up": ["fanfare", 523.25, 0.90, 0.38, "SFX"],
	"pickup": ["chime", 880.0, 0.20, 0.26, "SFX"],
	"heal": ["soft", 640.0, 0.45, 0.25, "SFX"],
	"scan": ["sweep", 760.0, 0.50, 0.24, "SFX"],
	"exfil": ["alarm", 620.0, 0.80, 0.34, "SFX"],
	"exfil_liftoff": ["boom", 60.0, 1.40, 0.40, "SFX"],
	"exfil_countdown": ["beep", 1500.0, 0.16, 0.24, "SFX"],

	# --- Creatures and bosses ----------------------------------------------
	"boss_roar": ["creature", 48.0, 1.60, 0.55, "SFX", {"roar": true}],
	"boss_stinger": ["stinger", 73.42, 1.20, 0.45, "SFX"],
	"creature_growl": ["creature", 85.0, 0.80, 0.32, "SFX"],
	"creature_snarl": ["creature", 130.0, 0.50, 0.34, "SFX", {"snarl": true}],
	"creature_hurt": ["creature", 160.0, 0.35, 0.30, "SFX", {"hurt": true}],
	"creature_death": ["creature", 70.0, 1.00, 0.38, "SFX", {"roar": true}],

	# --- Vehicles, mounts and engines (bus Vehicles) ------------------------
	"engine_rig": ["engine", 70.0, 1.6, 0.30, "Vehicles", {"loop": true, "lfo": 7.0}],
	"engine_bike": ["engine", 120.0, 1.4, 0.28, "Vehicles", {"loop": true, "lfo": 11.0}],
	"engine_plane": ["engine", 95.0, 1.8, 0.26, "Vehicles", {"loop": true, "lfo": 5.0}],
	"engine_ship": ["engine", 55.0, 2.0, 0.26, "Vehicles", {"loop": true, "lfo": 3.0}],
	"boost": ["whoosh", 240.0, 0.80, 0.32, "Vehicles", {"up": true}],
	"brake": ["squeal", 900.0, 0.55, 0.28, "Vehicles"],
	"horn": ["horn", 320.0, 0.50, 0.30, "Vehicles"],
	"hoof_walk": ["hoof", 120.0, 0.22, 0.22, "SFX"],
	"hoof_trot": ["hoof", 150.0, 0.17, 0.24, "SFX"],
	"hoof_gallop": ["hoof", 180.0, 0.13, 0.26, "SFX"],
	"whinny": ["whinny", 700.0, 0.70, 0.26, "SFX"],
	"vehicle_hit": ["impact", 180.0, 0.25, 0.34, "Vehicles", {"ring": 1.2}],
	"vehicle_explode": ["boom", 45.0, 0.90, 0.78, "Vehicles"],
	"ramp_hiss": ["hiss", 500.0, 0.70, 0.26, "Vehicles", {"decay": 2.0}],
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## True when the id has a procedural recipe (does not look at CC0 overrides).
func has_recipe(id: StringName) -> bool:
	return RECIPES.has(String(id))


## Every authored id, sorted so boot output and tests are stable.
func recipe_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in RECIPES.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids


## Logical bus name for an id ("SFX" when unknown).
func bus_for(id: StringName) -> String:
	var row: Array = RECIPES.get(String(id), [])
	if row.size() >= 5:
		return String(row[4])
	return "SFX"


## Authored duration in seconds (0.0 when unknown).
func duration_for(id: StringName) -> float:
	var row: Array = RECIPES.get(String(id), [])
	if row.size() >= 3:
		return float(row[2])
	return 0.0


## True when the id is a seamless loop (ambience / engine beds).
func is_loop(id: StringName) -> bool:
	var row: Array = RECIPES.get(String(id), [])
	if row.size() >= 6 and row[5] is Dictionary:
		return bool((row[5] as Dictionary).get("loop", false))
	return false


## Renders one id to raw PCM info. Safe on any thread.
## Returns {} when the id is unknown; otherwise:
##   {"data": PackedByteArray, "rate": int, "count": int, "loop": bool}
func render_info(id: StringName) -> Dictionary:
	var key := String(id)
	if not RECIPES.has(key):
		return {}
	var row: Array = RECIPES[key]
	var recipe := {
		"kind": String(row[0]),
		"freq": float(row[1]),
		"dur": float(row[2]),
		"vol": float(row[3]),
		"bus": String(row[4]) if row.size() >= 5 else "SFX",
		"seed": hash(key),
	}
	if row.size() >= 6 and row[5] is Dictionary:
		for option in (row[5] as Dictionary).keys():
			recipe[option] = row[5][option]
	return _render(recipe)


## Renders a batch of ids into `target` (id String -> PCM info Dictionary).
## Designed to be the WorkerThreadPool entry point; touches no shared state.
func build_batch(ids: Array, target: Dictionary) -> void:
	for id in ids:
		target[String(id)] = render_info(StringName(id))


# ---------------------------------------------------------------------------
# Core render pass
# ---------------------------------------------------------------------------

func _render(recipe: Dictionary) -> Dictionary:
	var rate := int(recipe.get("rate", SAMPLE_RATE))
	var dur := maxf(float(recipe.get("dur", 0.2)), 1.0 / float(rate))
	var count := maxi(MIN_SAMPLES, int(dur * float(rate)))
	var is_loop := bool(recipe.get("loop", false))
	var wrap := int(float(rate) * LOOP_WRAP_SEC) if is_loop else 0
	wrap = mini(wrap, count / 2)
	var total := count + wrap
	var buf := PackedFloat32Array()
	buf.resize(total)
	var kind := String(recipe.get("kind", "tone"))
	match kind:
		"click":
			_click(buf, total, rate, recipe)
		"tone":
			_tone(buf, total, rate, recipe)
		"chime":
			_chime(buf, total, rate, recipe)
		"buzz":
			_buzz(buf, total, rate, recipe)
		"hit":
			_hit(buf, total, rate, recipe)
		"step":
			_step(buf, total, rate, recipe)
		"thump":
			_thump(buf, total, rate, recipe)
		"shot":
			_shot(buf, total, rate, recipe)
		"boom":
			_boom(buf, total, rate, recipe)
		"rail":
			_rail(buf, total, rate, recipe)
		"zap":
			_zap(buf, total, rate, recipe)
		"reload":
			_reload(buf, total, rate, recipe)
		"kill":
			_kill(buf, total, rate, recipe)
		"sweep":
			_sweep(buf, total, rate, recipe)
		"fanfare":
			_fanfare(buf, total, rate, recipe)
		"alarm":
			_alarm(buf, total, rate, recipe)
		"soft":
			_soft(buf, total, rate, recipe)
		"glass":
			_glass(buf, total, rate, recipe)
		"rumble":
			_rumble(buf, total, rate, recipe)
		"hiss":
			_hiss(buf, total, rate, recipe)
		"whoosh":
			_whoosh(buf, total, rate, recipe)
		"impact":
			_impact(buf, total, rate, recipe)
		"engine":
			_engine(buf, total, rate, recipe)
		"wind":
			_wind(buf, total, rate, recipe)
		"water":
			_water(buf, total, rate, recipe)
		"lava":
			_lava(buf, total, rate, recipe)
		"birds":
			_birds(buf, total, rate, recipe)
		"crickets":
			_crickets(buf, total, rate, recipe)
		"drone":
			_drone(buf, total, rate, recipe)
		"creature":
			_creature(buf, total, rate, recipe)
		"servo":
			_servo(buf, total, rate, recipe)
		"horn":
			_horn(buf, total, rate, recipe)
		"squeal":
			_squeal(buf, total, rate, recipe)
		"beep":
			_beep(buf, total, rate, recipe)
		"crackle":
			_crackle(buf, total, rate, recipe)
		"splash":
			_splash(buf, total, rate, recipe)
		"thunder":
			_thunder(buf, total, rate, recipe)
		"stinger":
			_stinger(buf, total, rate, recipe)
		"hoof":
			_hoof(buf, total, rate, recipe)
		"whinny":
			_whinny(buf, total, rate, recipe)
		_:
			_tone(buf, total, rate, recipe)
	return _encode(buf, count, rate, is_loop, wrap)


func _encode(buf: PackedFloat32Array, count: int, rate: int, is_loop: bool, wrap: int) -> Dictionary:
	if is_loop and wrap > 0:
		# Fold the rendered tail into the head so the loop point is continuous.
		for i in wrap:
			var w := float(i) / float(wrap)
			buf[i] = buf[i] * w + buf[count + i] * (1.0 - w)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return {"data": data, "rate": rate, "count": count, "loop": is_loop}


# ---------------------------------------------------------------------------
# Renderers. Each fills `buf[0..n)` with mono float samples. `n` includes the
# loop wrap tail for loops; one-shots use an envelope over the whole buffer.
# ---------------------------------------------------------------------------

func _click(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 980.0))
	var vol := float(r.get("vol", 0.3))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 1)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := pow(1.0 - p, 5.0)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		buf[i] = (sin(TAU * f * t) * 0.75 + nz * 0.25) * env * vol


func _tone(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 440.0))
	var vol := float(r.get("vol", 0.3))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		buf[i] = sin(TAU * f * t) * exp(-4.0 * p) * vol * 0.8


func _chime(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 880.0))
	var vol := float(r.get("vol", 0.3))
	var partials := int(r.get("partials", 2))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-3.5 * p)
		var s := sin(TAU * f * t) * 0.62 + sin(TAU * f * 1.5 * t) * 0.3
		if partials >= 3:
			s += sin(TAU * f * 2.02 * t) * 0.16
		buf[i] = s * env * vol


func _buzz(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 160.0))
	var vol := float(r.get("vol", 0.25))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-3.2 * p)
		var s := signf(sin(TAU * f * t)) * 0.4 + sin(TAU * 51.0 * t) * 0.28
		buf[i] = s * env * vol


func _hit(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 1600.0))
	var vol := float(r.get("vol", 0.24))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 3)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-11.0 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		buf[i] = (sin(TAU * f * t) * 0.7 + sin(TAU * f * 0.5 * t) * 0.25 + nz * 0.22) * env * vol


func _step(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 100.0))
	var vol := float(r.get("vol", 0.12))
	var ring := float(r.get("ring", 0.0))
	var wet := bool(r.get("wet", false))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 5)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := pow(1.0 - p, 3.2)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.22
		var s := lp * 0.9 + sin(TAU * f * t) * 0.35
		if ring > 0.0:
			s += sin(TAU * ring * t) * exp(-14.0 * p) * 0.3
		if wet:
			s += nz * 0.18 * exp(-2.0 * p)
		buf[i] = s * env * vol


func _thump(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 90.0))
	var vol := float(r.get("vol", 0.4))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 7)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-5.0 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		buf[i] = (sin(TAU * f * t) * 0.82 + nz * 0.14) * env * vol


func _shot(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 130.0))
	var vol := float(r.get("vol", 0.55))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 11)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-6.0 * p) * (1.0 - p * 0.25)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var pitch := f * (1.0 - p * 0.35)
		var s := sin(TAU * pitch * t) * 0.55 + nz * 0.45 + sin(TAU * 55.0 * t) * 0.3
		buf[i] = s * env * vol


func _boom(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 55.0))
	var vol := float(r.get("vol", 0.7))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 13)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-3.4 * p) * (1.0 - p * 0.2)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.18
		var low := sin(TAU * f * t) * (1.0 - p * 0.25) * 0.7 + sin(TAU * f * 0.5 * t) * 0.25
		buf[i] = (low + lp * 0.55) * env * vol


func _rail(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 72.0))
	var vol := float(r.get("vol", 0.6))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 17)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-4.0 * p) * (1.0 - p * 0.15)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.01 * t) * 0.24 + sin(TAU * f * 3.02 * t) * 0.12 + nz * 0.16
		buf[i] = s * env * vol


func _zap(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 420.0))
	var vol := float(r.get("vol", 0.4))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 19)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-6.0 * p) * (1.0 - p * 0.3)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var carrier := f + sin(TAU * 19.0 * t) * 95.0
		var s := signf(sin(TAU * carrier * t)) * 0.22 + nz * 0.36
		buf[i] = s * env * vol


func _reload(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 320.0))
	var vol := float(r.get("vol", 0.28))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 23)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var burst := 0.0
		if p > 0.14 and p < 0.22:
			burst = 1.0
		elif p > 0.52 and p < 0.60:
			burst = 1.0
		elif p > 0.84 and p < 0.90:
			burst = 0.6
		var bed := nz * 0.1 + sin(TAU * f * t) * 0.08
		var click := (sin(TAU * 1180.0 * t) * 0.42 + nz * 0.58) * burst
		var env := clampf(1.0 - p * 0.5, 0.0, 1.0)
		buf[i] = (click + bed) * env * vol


func _kill(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 520.0))
	var vol := float(r.get("vol", 0.25))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 29)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-3.0 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var pitch := f if p < 0.5 else f * 0.75
		var s := sin(TAU * pitch * t) * 0.62 + sin(TAU * pitch * 1.5 * t) * 0.24 + nz * 0.12
		buf[i] = s * env * vol


func _sweep(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 420.0))
	var vol := float(r.get("vol", 0.3))
	var down := bool(r.get("down", false))
	var noise := float(r.get("noise", 0.0))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 31)) | 1
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var env := sin(p * PI) * 0.9
		var pitch := f * (0.5 + p * 1.7) if not down else f * (1.7 - p * 1.2)
		phase += TAU * pitch * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := sin(phase) * 0.7 + sin(phase * 0.5) * 0.22 + nz * noise
		buf[i] = s * env * vol


func _fanfare(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 523.25))
	var vol := float(r.get("vol", 0.3))
	var inv := 1.0 / float(rate)
	var notes := [0.0, 4.0, 7.0, 12.0]
	var segments := notes.size()
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var seg := mini(segments - 1, int(p * float(segments)))
		var local := p * float(segments) - float(seg)
		var env := sin(clampf(local, 0.0, 1.0) * PI) * exp(-0.8 * p)
		var pitch := f * pow(2.0, float(notes[seg]) / 12.0)
		var s := sin(TAU * pitch * t) * 0.66 + sin(TAU * pitch * 2.0 * t) * 0.2
		buf[i] = s * env * vol


func _alarm(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 620.0))
	var vol := float(r.get("vol", 0.32))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var gate := 1.0 if fmod(t, 0.4) < 0.2 else 0.0
		var env := clampf(1.0 - p * 0.7, 0.0, 1.0)
		buf[i] = sin(TAU * f * t) * gate * env * vol * 0.8


func _soft(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 640.0))
	var vol := float(r.get("vol", 0.25))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.14)
		var env := attack * exp(-2.4 * p)
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.5 * t) * 0.25 + sin(TAU * f * 2.01 * t) * 0.1
		buf[i] = s * env * vol


func _glass(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 1800.0))
	var vol := float(r.get("vol", 0.35))
	var decay := float(r.get("decay", 3.6))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 37)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-decay * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := nz * 0.62 + sin(TAU * (f + p * 420.0) * t) * 0.3 + sin(TAU * f * 1.51 * t) * 0.14
		buf[i] = s * env * vol


func _rumble(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 42.0))
	var vol := float(r.get("vol", 0.28))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 41)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.1)
		var env := attack * (1.0 - p) * 0.8
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.06
		var s := lp * 1.6 + sin(TAU * f * t) * 0.22 + sin(TAU * f * 0.5 * t) * 0.12
		buf[i] = s * env * vol


func _hiss(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 800.0))
	var vol := float(r.get("vol", 0.2))
	var decay := float(r.get("decay", 3.0))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 43)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-decay * p) * minf(1.0, p * 24.0)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * clampf(0.05 + f / 12000.0, 0.03, 0.5)
		var s := (nz - lp) * 0.9 + sin(TAU * f * 0.5 * t) * 0.08
		buf[i] = s * env * vol


func _whoosh(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 400.0))
	var vol := float(r.get("vol", 0.22))
	var up := bool(r.get("up", true))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 47)) | 1
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var env := sin(p * PI) * 0.85
		var pitch := f * (0.2 + p * 2.2) if up else f * (2.4 - p * 1.8)
		phase += TAU * pitch * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := sin(phase) * 0.26 + nz * 0.5 * (0.3 + p * 0.7)
		buf[i] = s * env * vol


func _impact(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 400.0))
	var vol := float(r.get("vol", 0.32))
	var ring := float(r.get("ring", 2.0))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 53)) | 1
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-7.0 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := nz * 0.6 * exp(-18.0 * p)
		s += sin(TAU * f * ring * t) * 0.3 * exp(-6.0 * p)
		s += sin(TAU * f * ring * 1.61 * t) * 0.16 * exp(-9.0 * p)
		buf[i] = s * env * 1.8 * vol


func _engine(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 70.0))
	var vol := float(r.get("vol", 0.28))
	var lfo := float(r.get("lfo", 7.0))
	var dur := float(n) / float(rate)
	# Snap the LFO to a whole number of cycles so the loop point is periodic.
	var cycles := maxi(1, int(round(lfo * dur)))
	var lfo_hz := float(cycles) / dur
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 59)) | 1
	for i in n:
		var t := float(i) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var wobble := 1.0 + sin(TAU * lfo_hz * t) * 0.16
		var s := sin(TAU * f * t) * 0.42
		s += sin(TAU * f * 2.0 * t) * 0.2
		s += sin(TAU * f * 3.0 * t) * 0.1
		s += sin(TAU * f * 4.02 * t) * 0.06
		s += nz * 0.1
		buf[i] = s * wobble * vol


func _wind(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 120.0))
	var vol := float(r.get("vol", 0.22))
	var dur := float(n) / float(rate)
	var cycles := maxi(1, int(round(0.35 * dur)))
	var lfo_hz := float(cycles) / dur
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 61)) | 1
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.05
		lp2 += (lp - lp2) * 0.08
		var gust := 0.55 + sin(TAU * lfo_hz * t) * 0.3 + sin(TAU * lfo_hz * 2.0 * t + 1.1) * 0.12
		var tonal := sin(TAU * f * t) * 0.12 + sin(TAU * f * 0.5 * t) * 0.08
		buf[i] = (lp2 * 3.2 + lp * 0.8 + tonal) * gust * vol


func _water(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 90.0))
	var vol := float(r.get("vol", 0.2))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 67)) | 1
	var lp := 0.0
	var bubble_phase := 0.0
	for i in n:
		var t := float(i) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.08
		# Bubbles: short upwards blips scattered through the loop.
		var region := fmod(t * 3.1, 1.0)
		var blip := 0.0
		if region < 0.18:
			blip = sin(TAU * (f * 4.0 + region * 900.0) * t) * (1.0 - region / 0.18) * 0.3
		bubble_phase += 0.0
		var s := lp * 2.2 + blip + sin(TAU * f * t) * 0.1
		buf[i] = s * vol


func _lava(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 60.0))
	var vol := float(r.get("vol", 0.22))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 71)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.04
		var crackle := 0.0
		if st > 1060000000:
			crackle = nz * 0.6
		var s := lp * 2.6 + sin(TAU * f * t) * 0.2 + crackle
		buf[i] = s * vol


func _birds(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 1200.0))
	var vol := float(r.get("vol", 0.16))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 73)) | 1
	var dur := float(n) / float(rate)
	# Deterministic chirp events, each 90 ms long.
	var chirp_len := 0.09
	var event_count := int(dur / 0.35)
	for e in event_count:
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var start := (float(e) * 0.35 + float(st & 0xFFFF) / 65536.0 * 0.2) * float(rate)
		var base := f * (0.7 + float((st >> 8) & 0xFF) / 255.0 * 0.9)
		var length := int(chirp_len * float(rate))
		for k in length:
			var idx := int(start) + k
			if idx < 0 or idx >= n:
				continue
			var p := float(k) / float(length)
			var pitch := base * (1.0 + sin(p * PI) * 0.45)
			var env := sin(p * PI) * exp(-1.2 * p)
			buf[idx] += sin(TAU * pitch * float(k) * inv) * env * 0.45
	# Thin the buffer down by the authored volume (events were summed already).
	for i in n:
		buf[i] *= vol


func _crickets(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 2400.0))
	var vol := float(r.get("vol", 0.12))
	var inv := 1.0 / float(rate)
	var dur := float(n) / float(rate)
	# Snap the chirp period so the loop point is sample periodic.
	var cycles := maxi(1, int(round(11.0 * dur)))
	var period := dur / float(cycles)
	var period_samples := maxi(2, int(period * float(rate)))
	for start in range(0, n, period_samples):
		for k in period_samples:
			var idx := start + k
			if idx >= n:
				break
			var p := float(k) / float(period_samples)
			if p > 0.32:
				break
			var env := sin(p / 0.32 * PI)
			var s := signf(sin(TAU * f * float(k) * inv)) * 0.22 + sin(TAU * f * 0.5 * float(k) * inv) * 0.1
			buf[idx] += s * env * 0.5
	for i in n:
		buf[i] *= vol


func _drone(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 60.0))
	var vol := float(r.get("vol", 0.18))
	var dur := float(n) / float(rate)
	var cycles := maxi(1, int(round(0.22 * dur)))
	var lfo_hz := float(cycles) / dur
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 79)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var swell := 0.7 + sin(TAU * lfo_hz * t) * 0.24
		var s := sin(TAU * f * t) * 0.3 + sin(TAU * f * 1.005 * t) * 0.22
		s += sin(TAU * f * 1.5 * t) * 0.16 + sin(TAU * f * 2.01 * t) * 0.1
		lp += (nz - lp) * 0.03
		s += lp * 1.1
		buf[i] = s * swell * vol


func _creature(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 85.0))
	var vol := float(r.get("vol", 0.32))
	var roar := bool(r.get("roar", false))
	var snarl := bool(r.get("snarl", false))
	var hurt := bool(r.get("hurt", false))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 83)) | 1
	var lp := 0.0
	var mod_hz := 14.0
	if roar:
		mod_hz = 8.0
	elif snarl:
		mod_hz = 26.0
	elif hurt:
		mod_hz = 33.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.08)
		var env := attack * (exp(-2.2 * p) if not roar else sin(clampf(p, 0.0, 1.0) * PI) * 0.9)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.2
		var growl := sin(TAU * f * t + sin(TAU * mod_hz * t) * 2.4) * 0.55
		var sub := sin(TAU * f * 0.5 * t) * 0.3
		var s := (growl + sub + lp * 0.5) * env * 1.1
		if hurt:
			s *= (1.0 - p * 0.5)
		buf[i] = s * vol


func _servo(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 140.0))
	var vol := float(r.get("vol", 0.28))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 89)) | 1
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.12)
		var env := attack * (1.0 - p * 0.25)
		phase += TAU * f * (1.0 + p * 0.7) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := signf(sin(phase)) * 0.24 + sin(phase * 2.0) * 0.18 + nz * 0.12
		buf[i] = s * env * vol


func _horn(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 320.0))
	var vol := float(r.get("vol", 0.3))
	var inv := 1.0 / float(rate)
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.04)
		var env := attack * (1.0 - p * 0.3)
		var s := sin(TAU * f * t) * 0.34 + sin(TAU * f * 1.5 * t) * 0.24 + sin(TAU * f * 2.0 * t) * 0.12
		buf[i] = s * env * vol


func _squeal(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 900.0))
	var vol := float(r.get("vol", 0.28))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 97)) | 1
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var env := minf(1.0, p / 0.1) * (1.0 - p * 0.4)
		phase += TAU * f * (1.45 - p * 0.85) * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := sin(phase) * 0.42 + sin(phase * 1.51) * 0.16 + nz * 0.22
		buf[i] = s * env * vol


func _beep(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 1500.0))
	var vol := float(r.get("vol", 0.24))
	var inv := 1.0 / float(rate)
	var period := 0.14
	var beep_len := 0.07
	for i in n:
		var t := float(i) * inv
		var local := fmod(t, period)
		if local >= beep_len:
			continue
		var p := local / beep_len
		var env := minf(1.0, p / 0.08) * (1.0 - p * 0.8)
		buf[i] = sin(TAU * f * t) * env * vol


func _crackle(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 900.0))
	var vol := float(r.get("vol", 0.22))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 101)) | 1
	var lp := 0.0
	for i in n:
		var p := float(i) / float(n)
		var env := exp(-1.8 * p) * minf(1.0, p * 18.0)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.35
		var pop := nz * 0.8 if (st & 0x7) == 0 else nz * 0.16
		var s := (nz - lp) * 0.5 + pop + sin(TAU * f * 0.25 * float(i) * inv) * 0.05
		buf[i] = s * env * vol


func _splash(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 400.0))
	var vol := float(r.get("vol", 0.3))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 103)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-5.0 * p) * minf(1.0, p * 30.0)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * (0.3 * (1.0 - p) + 0.02)
		var s := lp * 1.8 + nz * 0.3 * exp(-9.0 * p) + sin(TAU * f * 0.3 * t) * 0.18
		buf[i] = s * env * vol


func _thunder(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 46.0))
	var vol := float(r.get("vol", 0.34))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 107)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := minf(1.0, p / 0.05) * exp(-2.6 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.035
		var crack := nz * 0.7 * exp(-30.0 * p)
		var s := lp * 2.8 + sin(TAU * f * t) * 0.24 + sin(TAU * f * 0.5 * t) * 0.16 + crack
		buf[i] = s * env * vol


func _stinger(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 73.42))
	var vol := float(r.get("vol", 0.45))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 109)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var swell := minf(1.0, p / 0.18) * (1.0 - p * 0.2)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.1
		var s := sin(TAU * f * t) * 0.32 + sin(TAU * f * 1.06 * t) * 0.26
		s += sin(TAU * f * 1.5 * t) * 0.18 + sin(TAU * f * 2.12 * t) * 0.12
		s += lp * 0.6
		buf[i] = s * swell * vol


func _hoof(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 120.0))
	var vol := float(r.get("vol", 0.22))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 113)) | 1
	var lp := 0.0
	for i in n:
		var t := float(i) * inv
		var p := float(i) / float(n)
		var env := exp(-12.0 * p)
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		lp += (nz - lp) * 0.35
		var s := sin(TAU * f * (1.0 - p * 0.4) * t) * 0.6 + lp * 0.7 + nz * 0.12
		buf[i] = s * env * vol


func _whinny(buf: PackedFloat32Array, n: int, rate: int, r: Dictionary) -> void:
	var f := float(r.get("freq", 700.0))
	var vol := float(r.get("vol", 0.26))
	var inv := 1.0 / float(rate)
	var st := int(r.get("seed", 127)) | 1
	var phase := 0.0
	for i in n:
		var p := float(i) / float(n)
		var attack := minf(1.0, p / 0.1)
		var env := attack * (1.0 - p * 0.35)
		var vibrato := sin(TAU * 22.0 * float(i) * inv) * 0.12
		var pitch := f * (1.3 - p * 0.75) * (1.0 + vibrato)
		phase += TAU * pitch * inv
		st = (st * 1103515245 + 12345) & 0x7FFFFFFF
		var nz := float(st) * NOISE_SCALE - 1.0
		var s := sin(phase) * 0.42 + sin(phase * 2.0) * 0.16 + nz * 0.14
		buf[i] = s * env * vol
