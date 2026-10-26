extends RefCounted
## CC0 audio override resolver for AudioDirector.
##
## Scans `res://assets/audio/cc0/**` (populated outside this workstream with
## Kenney Interface / UI / Sci-Fi / Impact packs) and maps audio filename stems
## onto the logical SFX ids used by gameplay code. A file whose stem already is a
## catalog id wins automatically, so dropping `engine_rig.wav` into the pack is
## enough; the alias table below covers the vendor naming conventions.
##
## The resolver is intentionally quiet: a missing folder, an unknown stem, an
## unimported file or a non-audio resource all fall back to the procedural synth
## with no push_error / warning spam. Nothing here touches the network.
##
## Usage:
##   var packs := AudioPacks.new()
##   packs.setup(catalog.recipe_ids())
##   packs.scan()
##   var stream := packs.resolve(&"ui_click")   # null -> use the synth

const ROOT := "res://assets/audio/cc0"
const AUDIO_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]

## Vendor stem fragments -> logical id. Most specific first: the first needle
## contained in the normalized stem wins, so keep narrow matches above broad ones
## ("impactmetalheavy" before "impactmetal", "dooropen" before "open").
const PATTERNS := [
	# --- doors / hatches (before generic open/close) -----------------------
	["dooropen", &"door"],
	["doorclose", &"door"],
	["slidedoor", &"door"],
	["door", &"door"],
	["hatch", &"hatch"],
	["hydraulic", &"hydraulic_door"],
	["servo", &"hydraulic_door"],
	# --- engines / vehicles (before generic "engine") ----------------------
	["enginecircular", &"engine_rig"],
	["engineloop", &"engine_rig"],
	["enginelow", &"engine_ship"],
	["spaceengine", &"engine_ship"],
	["spaceship", &"engine_ship"],
	["thrusterfire", &"boost"],
	["thruster", &"engine_plane"],
	["propeller", &"engine_plane"],
	["engine", &"engine_rig"],
	["boost", &"boost"],
	["brake", &"brake"],
	["skid", &"brake"],
	["horn", &"horn"],
	["hoof", &"hoof_walk"],
	["vehicle", &"vehicle_hit"],
	# --- impacts / explosions (specific first) -----------------------------
	["footstepgrass", &"footstep_grass"],
	["footstepwater", &"footstep_water"],
	["footstepmetal", &"footstep_metal"],
	["footstepcarpet", &"footstep"],
	["footstepconcrete", &"footstep"],
	["footstepsnow", &"footstep"],
	["footstepwood", &"footstep"],
	["footstep", &"footstep"],
	["impactmetalheavy", &"vehicle_hit"],
	["impactmetal", &"impact_metal"],
	["impactbell", &"impact_metal"],
	["impacttin", &"impact_metal"],
	["impactmining", &"impact_metal"],
	["impactplateheavy", &"armor_break"],
	["impactplate", &"armor_plate"],
	["impactglass", &"shield_break"],
	["impactsoft", &"impact_flesh"],
	["impactwood", &"impact_flesh"],
	["impactplank", &"impact_flesh"],
	["impactpunch", &"impact_flesh"],
	["impactgeneric", &"hit"],
	["impact", &"hit"],
	["explosioncrunch", &"explosion"],
	["lowfrequencyexplosion", &"explosion"],
	["explosion", &"explosion"],
	["laserlarge", &"shot_sniper"],
	["laserretro", &"shot_arc"],
	["lasersmall", &"shot_arc"],
	["laser", &"shot_arc"],
	["forcefield", &"shield_hit"],
	["shotgun", &"shot_shotgun"],
	["gunshot", &"shot_rifle"],
	["rifle", &"shot_rifle"],
	["pistol", &"shot_pistol"],
	["shoot", &"shot_rifle"],
	["reload", &"reload"],
	["sword", &"knife_swing"],
	["knife", &"knife_swing"],
	["swing", &"knife_swing"],
	["whoosh", &"boost"],
	# --- creatures / bosses ------------------------------------------------
	["bossroar", &"boss_roar"],
	["roar", &"boss_roar"],
	["growl", &"creature_growl"],
	["snarl", &"creature_snarl"],
	["monster", &"creature_growl"],
	["creature", &"creature_growl"],
	["beast", &"creature_growl"],
	# --- UI (before generic click) -----------------------------------------
	["rollover", &"ui_hover"],
	["hover", &"ui_hover"],
	["mouserelease", &"ui_click"],
	["mouseclick", &"ui_click"],
	["confirm", &"ui_confirm"],
	["positive", &"ui_confirm"],
	["select", &"ui_click"],
	["negative", &"ui_error"],
	["error", &"ui_error"],
	["switch", &"ui_tab"],
	["toggle", &"ui_tab"],
	["tab", &"ui_tab"],
	["slider", &"ui_slider"],
	["tick", &"ui_slider"],
	["maximize", &"ui_open"],
	["open", &"ui_open"],
	["minimize", &"ui_close"],
	["close", &"ui_close"],
	["back", &"ui_close"],
	["drop", &"ui_click"],
	["pluck", &"pickup"],
	["scratch", &"ui_hover"],
	["click", &"ui_click"],
	["bong", &"ui_confirm"],
	["question", &"ui_confirm"],
	["glitch", &"ui_error"],
	# --- pickups / progression / radio -------------------------------------
	["levelup", &"level_up"],
	["fanfare", &"level_up"],
	["powerup", &"level_up"],
	["pickup", &"pickup"],
	["coin", &"pickup"],
	["heal", &"heal"],
	["shield", &"shield_hit"],
	["glass", &"shield_break"],
	["armor", &"armor_plate"],
	["radio", &"radio_chirp"],
	["beep", &"radio_chirp"],
	["alarm", &"exfil"],
	["siren", &"exfil"],
	["computer", &"radio_chirp"],
	["machine", &"hydraulic_door"],
	# --- ambience ----------------------------------------------------------
	["rain", &"water_loop"],
	["water", &"water_loop"],
	["wind", &"wind_ambient"],
	["fire", &"lava_loop"],
	["lava", &"lava_loop"],
	["step", &"footstep"],
	["foot", &"footstep"],
	# --- last resort -------------------------------------------------------
	["hit", &"hit"],
	["thud", &"land"],
]

var _valid_ids: Dictionary = {}
var _ids: Dictionary = {}
var _streams: Dictionary = {}
var _unmapped: Array[String] = []
var _audio_files: int = 0
var _scanned: bool = false


## Registers the logical ids that filenames may map to. Call once before scan().
func setup(valid_ids: Array) -> void:
	_valid_ids.clear()
	for id in valid_ids:
		_valid_ids[_normalize(String(id))] = StringName(id)


## Walks the CC0 pack folder. Safe to call when the folder does not exist.
func scan() -> void:
	_ids.clear()
	_streams.clear()
	_unmapped.clear()
	_audio_files = 0
	_scanned = true
	if _valid_ids.is_empty():
		return
	if not DirAccess.dir_exists_absolute(ROOT):
		return
	_walk(ROOT)


## Resolved AudioStream for a logical id, or null when there is no usable pack
## file (callers then use the procedural synth). Never errors.
##
## The imported resource is duplicated into a runtime stream: a force-quit while
## a voice is still playing can leave the playback alive for a moment, and a
## playback that pins the *imported* resource would make the engine report
## "Resource still in use" at exit. The duplicate has no resource path, so the
## import cache always clears cleanly.
func resolve(id: StringName) -> AudioStream:
	var key := String(id)
	var cached: Variant = _streams.get(key, null)
	if cached != null:
		return cached
	var path: String = String(_ids.get(key, ""))
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		# Not imported (e.g. a fresh checkout) - keep the procedural fallback.
		_ids.erase(key)
		return null
	var resource: Resource = load(path)
	if not (resource is AudioStream):
		_ids.erase(key)
		return null
	var stream := _runtime_copy(resource as AudioStream)
	if stream == null:
		stream = resource as AudioStream
	_streams[key] = stream
	return stream


## Detached copy of an imported audio stream (no resource path, not cached).
func _runtime_copy(source: AudioStream) -> AudioStream:
	var copy: Resource = source.duplicate()
	if copy is AudioStream:
		return copy as AudioStream
	return null


## True when a pack file is mapped to this id (does not load the resource).
func has_override(id: StringName) -> bool:
	return _ids.has(String(id))


## Source path mapped to an id, or "" when none.
func get_override_path(id: StringName) -> String:
	return String(_ids.get(String(id), ""))


## Ids that have a pack override, sorted for stable diagnostics.
func get_override_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _ids.keys():
		ids.append(StringName(key))
	ids.sort()
	return ids


## Number of audio files found under the pack root.
func get_file_count() -> int:
	return _audio_files


## Number of logical ids that resolved to a pack file.
func get_mapped_count() -> int:
	return _ids.size()


## Stems that looked like audio but matched no alias (capped, diagnostics only).
func get_unmapped_stems() -> Array[String]:
	return _unmapped


func is_scanned() -> bool:
	return _scanned


func get_root() -> String:
	return ROOT


## Drops every cached path/resource reference. Called from AudioDirector's
## teardown so force-quit suites release imported CC0 streams before shutdown.
func clear() -> void:
	_valid_ids.clear()
	_ids.clear()
	_streams.clear()
	_unmapped.clear()
	_audio_files = 0
	_scanned = false


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_walk(full)
		else:
			var extension := full.get_extension().to_lower()
			if extension in AUDIO_EXTENSIONS:
				_audio_files += 1
				_register(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _register(path: String) -> void:
	var stem := path.get_file().get_basename()
	var normalized := _normalize(stem)
	var id := _match_id(normalized)
	if id == &"":
		if _unmapped.size() < 32:
			_unmapped.append(stem)
		return
	var key := String(id)
	var existing: String = String(_ids.get(key, ""))
	# Deterministic pick when several files map to the same id.
	if existing.is_empty() or path < existing:
		_ids[key] = path


func _match_id(normalized: String) -> StringName:
	# 1) The file already carries the logical id.
	if _valid_ids.has(normalized):
		return _valid_ids[normalized]
	# 2) Vendor naming conventions, most specific needle first.
	for pattern in PATTERNS:
		var needle := String(pattern[0])
		if not needle.is_empty() and normalized.contains(needle):
			var id: StringName = pattern[1]
			if _valid_ids.has(_normalize(String(id))):
				return id
	return &""


func _normalize(text: String) -> String:
	var out := ""
	var lower := text.to_lower()
	for index in lower.length():
		var c := lower[index]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out
