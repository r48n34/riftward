extends Node
## Per-deployment state only. No Nodes, no persistent meta progression.
## The deployment director ticks this; UI reads it; EventBus broadcasts changes.

signal run_ended(result: Dictionary)

const RUN_DURATION := 1080.0
const TUTORIAL_DURATION := 1800.0
const STORM_START := 720.0
const EXFIL_HOLD := 75.0
const TUTORIAL_EXFIL_HOLD := 12.0

var active: bool = false
var run_seed: int = 0
var contract_id: StringName = &"salvage_sweep"
var threat: int = 1
var mutator_ids: Array[StringName] = []
var difficulty_id: StringName = &"patrol"
var difficulty: Dictionary = {}
var mode: Dictionary = {}
var mode_id: StringName = &"normal"
var time_scale: float = 1.0
var map_preset_id: StringName = &""
var planet_id: StringName = &""
var storm_start_time: float = STORM_START
var objectives: Dictionary = {}
var satchel_items: Array = []
var satchel_salvage: int = 0
var satchel_cores: int = 0
var rift_mods: Array[StringName] = []
var elapsed: float = 0.0
var storm_active: bool = false
var time_left: float = RUN_DURATION
var extraction_state: StringName = &"inactive"
var extraction_timer: float = 0.0
var kills: int = 0
var bosses: int = 0
var combat_xp: int = 0
var revives_used: int = 0
var completed_objectives: int = 0
var dungeons_entered: int = 0
var dungeons_cleared: int = 0
var weather_id: StringName = &""
var weather_name: String = ""
var time_of_day: float = 0.62
var stage_index: int = 0
var stage_total: int = 1
var stage_title: String = ""
var started_unix: int = 0
var last_timer_emit: float = 0.0
var _ended: bool = false


## Resolves a requested mode id into the authored mode dictionary. Every
## selectable ContentDB mode is accepted, `tutorial` is a special runtime-only
## mode and anything unknown falls back to Normal.
func _resolve_mode(requested: StringName) -> void:
	var resolved := requested if requested != &"" else &"normal"
	mode = {}
	if resolved == &"tutorial":
		mode = {
			"id": &"tutorial", "display_name": "Field Training", "clock": "18:00",
			"tag": "TRAINING", "icon": &"training", "color": Color("6fa8ff"),
			"description": "Guided onboarding run with no hostiles and no storm.",
			"selectable": false, "run_duration": TUTORIAL_DURATION, "time_scale": 1.0,
			"density_mult": 1.0, "elite_bonus": 0.0, "reward_mult": 1.0,
			"max_hostiles_delta": 0, "loot_bonus": 0.0,
		}
	else:
		mode = ContentDB.get_game_mode(resolved)
	if mode.is_empty():
		mode = ContentDB.get_game_mode(&"normal")
	if mode.is_empty():
		mode = {
			"id": &"normal", "display_name": "Normal", "clock": "18:00",
			"tag": "STANDARD", "run_duration": RUN_DURATION, "time_scale": 1.0,
			"density_mult": 1.0, "elite_bonus": 0.0, "reward_mult": 1.0,
			"max_hostiles_delta": 0, "loot_bonus": 0.0,
		}
	mode_id = StringName(mode.get("id", &"normal"))


func start_run(
	p_contract_id: StringName,
	p_seed: int,
	p_threat: int = 1,
	p_mutators: Array = [],
	p_difficulty_id: StringName = &"",
	p_mode_id: StringName = &"normal",
	p_map_id: StringName = &""
) -> void:
	active = true
	_ended = false
	contract_id = p_contract_id
	difficulty = ContentDB.get_difficulty(p_difficulty_id)
	if difficulty.is_empty():
		difficulty = ContentDB.get_difficulty_for_threat(clampi(p_threat, 1, 4))
	if difficulty.is_empty():
		difficulty = {"id": &"patrol", "display_name": "Patrol", "threat": 1, "density": 1.0, "elite_bonus": 0.0, "reward": 1.0}
	difficulty_id = StringName(difficulty.get("id", &"patrol"))
	threat = clampi(maxi(p_threat, int(difficulty.get("threat", 1))), 1, 4)
	_resolve_mode(p_mode_id)
	time_scale = maxf(0.01, float(mode.get("time_scale", 1.0)))
	# Map selection: an explicit valid override wins; otherwise the difficulty's
	# featured map stays authoritative (backward compatible).
	var requested_map := p_map_id
	if requested_map == &"" or ContentDB.get_map_preset(requested_map).is_empty():
		requested_map = StringName(difficulty.get("map_preset", &""))
	if requested_map == &"" or ContentDB.get_map_preset(requested_map).is_empty():
		var presets := ContentDB.get_map_presets()
		requested_map = StringName(presets[0].get("id", &"verdant_verge")) if not presets.is_empty() else &"verdant_verge"
	map_preset_id = requested_map
	var preset := ContentDB.get_map_preset(map_preset_id)
	planet_id = StringName(preset.get("planet_id", &""))
	var storm_fraction := float(difficulty.get("storm_fraction", STORM_START / RUN_DURATION))
	if mode.has("storm_fraction"):
		storm_fraction = float(mode.get("storm_fraction", storm_fraction))
	storm_start_time = clampf(storm_fraction, 0.1, 1.0) * get_run_duration()
	if is_tutorial():
		storm_start_time = TUTORIAL_DURATION * 4.0
	mutator_ids.clear()
	for id in p_mutators:
		mutator_ids.append(StringName(id))
	if p_seed == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		run_seed = rng.randi()
	else:
		run_seed = p_seed
	objectives.clear()
	satchel_items.clear()
	satchel_salvage = 0
	satchel_cores = 0
	rift_mods.clear()
	elapsed = 0.0
	storm_active = false
	time_left = get_run_duration()
	extraction_state = &"inactive"
	extraction_timer = 0.0
	kills = 0
	bosses = 0
	combat_xp = 0
	revives_used = 0
	completed_objectives = 0
	dungeons_entered = 0
	dungeons_cleared = 0
	weather_id = &""
	weather_name = ""
	var mode_start_time := get_mode_start_time()
	time_of_day = clampf(
		mode_start_time if mode_start_time >= 0.0 else float(preset.get("start_time", 0.62)),
		0.0,
		0.999
	)
	stage_index = 0
	stage_total = 1
	stage_title = ""
	last_timer_emit = 0.0
	started_unix = int(Time.get_unix_time_from_system())
	EventBus.deployment_started.emit(run_seed, contract_id, threat, mutator_ids.duplicate())
	EventBus.timer_updated.emit(time_left)


func tick(delta: float) -> void:
	if not active or _ended:
		return
	delta *= time_scale
	elapsed += delta
	time_left = maxf(0.0, get_run_duration() - elapsed)
	if not is_tutorial() and not storm_active and elapsed >= storm_start_time:
		storm_active = true
		EventBus.storm_changed.emit(true, _safe_radius())
	last_timer_emit += delta
	if last_timer_emit >= 0.25:
		last_timer_emit = 0.0
		EventBus.timer_updated.emit(time_left)
		if storm_active:
			EventBus.storm_changed.emit(true, _safe_radius())
	if time_left <= 0.0 and not _ended:
		if is_tutorial():
			end_run(false, "Field training clock expired.")
		else:
			end_run(false, "The Collapse consumed the Reach.")


func get_run_duration() -> float:
	var duration := float(mode.get("run_duration", 0.0))
	if duration > 0.0:
		return duration
	return TUTORIAL_DURATION if is_tutorial() else RUN_DURATION


func _safe_radius() -> float:
	var start := 900.0
	var end := 140.0
	var t := clampf((elapsed - storm_start_time) / maxf(1.0, get_run_duration() - storm_start_time), 0.0, 1.0)
	return lerpf(start, end, t)


func get_safe_radius() -> float:
	return _safe_radius() if storm_active else 2000.0


func get_time_left() -> float:
	return time_left


func get_run_fraction() -> float:
	return clampf(elapsed / maxf(1.0, get_run_duration()), 0.0, 1.0)


## 0.0 for the calm opening half, easing to 1.0 as the Collapse closes in.
func get_pressure() -> float:
	var t := clampf((get_run_fraction() - 0.5) / 0.5, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	return clampf(eased * 1.15, 0.0, 1.0)


## 0 = calm, 1 = reinforcements, 2 = collapse surge, 3 = final stand.
func get_late_stage() -> int:
	var fraction := get_run_fraction()
	if fraction >= 0.94:
		return 3
	if fraction >= 0.86:
		return 2
	if fraction >= 0.72:
		return 1
	return 0


func get_difficulty() -> Dictionary:
	return difficulty


func get_difficulty_name() -> String:
	return String(difficulty.get("display_name", "Patrol"))


func get_difficulty_density() -> float:
	return maxf(0.1, float(difficulty.get("density", 1.0)) * float(mode.get("density_mult", 1.0)))


func get_difficulty_elite_bonus() -> float:
	return maxf(0.0, float(difficulty.get("elite_bonus", 0.0)) + float(mode.get("elite_bonus", 0.0)))


func get_difficulty_reward_mult() -> float:
	return maxf(0.0, float(difficulty.get("reward", 1.0)) * float(mode.get("reward_mult", 1.0)))


func get_difficulty_mission_sites() -> int:
	return clampi(int(difficulty.get("mission_sites", 3)), 1, 8)


func get_difficulty_side_caches() -> int:
	return clampi(int(difficulty.get("side_caches", 4)), 0, 24)


func get_difficulty_bounties() -> int:
	return clampi(int(difficulty.get("bounties", 1)), 0, 6)


func get_difficulty_objective_guards() -> int:
	return clampi(int(difficulty.get("objective_guards", 3)), 1, 8)


func get_difficulty_max_hostiles() -> int:
	return clampi(int(difficulty.get("max_hostiles", 56)) + int(mode.get("max_hostiles_delta", 0)), 24, 96)


func get_difficulty_enemy_health_mult() -> float:
	return maxf(0.1, float(difficulty.get("enemy_health_mult", 1.0)))


func get_difficulty_enemy_damage_mult() -> float:
	return maxf(0.1, float(difficulty.get("enemy_damage_mult", 1.0)))


func get_difficulty_loot_luck() -> float:
	return clampf(float(difficulty.get("loot_luck", 0.0)) + float(mode.get("loot_bonus", 0.0)), 0.0, 0.5)


func get_difficulty_director_scale() -> float:
	return clampf(float(difficulty.get("director_interval_scale", 1.0)), 0.35, 1.5)


func get_difficulty_extraction_scale() -> float:
	return maxf(0.5, float(difficulty.get("extraction_scale", 1.0)))


func get_mode_id() -> StringName:
	return mode_id


func get_mode() -> Dictionary:
	return mode.duplicate(true)


func get_mode_name() -> String:
	var mode_def := ContentDB.get_game_mode(mode_id)
	if not mode_def.is_empty():
		return String(mode_def.get("display_name", "Normal"))
	if is_tutorial():
		return "Field Training"
	return String(mode.get("display_name", "Normal"))


func get_mode_tag() -> String:
	return String(mode.get("tag", ""))


## Authored start-of-run time-of-day fraction, or -1 when the mode lets the map
## preset decide.
func get_mode_start_time() -> float:
	return float(mode.get("start_time", -1.0))


func get_mode_start_weather() -> StringName:
	return StringName(mode.get("starting_weather", &""))


func get_mode_clock() -> String:
	var clock := ContentDB.get_mode_clock(mode_id)
	if not clock.is_empty():
		return clock
	return String(mode.get("clock", "18:00"))


func is_tutorial() -> bool:
	return mode_id == &"tutorial"


func get_time_scale() -> float:
	return time_scale


func is_quick_mode() -> bool:
	return mode_id == &"quick"


func get_map_preset_id() -> StringName:
	return map_preset_id


func get_map_preset_name() -> String:
	var preset := ContentDB.get_map_preset(map_preset_id)
	return String(preset.get("display_name", "Verdant Verge"))


func get_planet_id() -> StringName:
	return planet_id


func get_planet_name() -> String:
	var planet := ContentDB.get_planet(planet_id)
	return String(planet.get("display_name", "Meridian-9"))


func record_dungeon_entered() -> void:
	dungeons_entered += 1


func record_dungeon_cleared() -> void:
	dungeons_cleared += 1


func set_environment_snapshot(p_weather_id: StringName, p_weather_name: String, p_time_of_day: float) -> void:
	weather_id = p_weather_id
	weather_name = p_weather_name
	time_of_day = clampf(p_time_of_day, 0.0, 0.999)


func set_stage(index: int, total: int, title: String) -> void:
	stage_index = clampi(index, 0, maxi(0, total - 1))
	stage_total = maxi(1, total)
	stage_title = title


func get_stage_info() -> Dictionary:
	return {
		"index": stage_index,
		"total": stage_total,
		"title": stage_title,
		"number": stage_index + 1,
	}


func get_storm_start_time() -> float:
	return storm_start_time


func get_exfil_hold_total() -> float:
	return TUTORIAL_EXFIL_HOLD if is_tutorial() else EXFIL_HOLD


func get_objective_total(id: StringName) -> int:
	return maxi(0, int(objectives.get(id, {}).get("total", 0)))


func is_objective_complete(id: StringName) -> bool:
	return bool(objectives.get(id, {}).get("complete", false))


func add_objective(id: StringName, title: String, total: int) -> void:
	objectives[id] = {"id": id, "title": title, "progress": 0, "total": maxi(1, total), "complete": false}
	EventBus.objective_updated.emit(id, title, 0, maxi(1, total))


func progress_objective(id: StringName, amount: int = 1) -> bool:
	if not objectives.has(id):
		return false
	var obj: Dictionary = objectives[id]
	if obj.complete:
		return false
	obj.progress = mini(obj.total, int(obj.progress) + amount)
	var completed_now := false
	if obj.progress >= obj.total:
		obj.complete = true
		completed_objectives += 1
		completed_now = true
	objectives[id] = obj
	EventBus.objective_updated.emit(id, obj.title, int(obj.progress), int(obj.total))
	return completed_now


func get_objective_progress(id: StringName) -> int:
	return int(objectives.get(id, {}).get("progress", 0))


func get_objectives() -> Array:
	return objectives.values()


func add_loot_item(item: Dictionary) -> void:
	if item.is_empty():
		return
	satchel_items.append(item.duplicate(true))
	var info := ItemFactory.describe(item)
	satchel_salvage += int(info.get("value", 0))
	EventBus.notification_requested.emit("Recovered " + String(info.get("display_name", "item")), "Satchel value %d" % satchel_salvage, &"loot")


func add_satchel_salvage(amount: int, cores: int = 0) -> void:
	satchel_salvage += maxi(0, amount)
	satchel_cores += maxi(0, cores)


func get_satchel_items() -> Array:
	return satchel_items.duplicate(true)


func add_rift_mod(id: StringName) -> void:
	if ContentDB.get_rift_mod(id) == null:
		return
	if id not in rift_mods:
		rift_mods.append(id)
		var mod := ContentDB.get_rift_mod(id)
		EventBus.notification_requested.emit("Rift Mod: " + mod.display_name, mod.description, &"rift")


func has_rift_mod(id: StringName) -> bool:
	return id in rift_mods


func record_kill(is_boss: bool = false, xp_value: int = -1) -> void:
	kills += 1
	if is_boss:
		bosses += 1
	combat_xp += xp_value if xp_value >= 0 else 4


func get_mutator_multiplier(key: String, fallback: float = 1.0) -> float:
	var result := fallback
	for id in mutator_ids:
		var mutator := ContentDB.get_mutator(id)
		if mutator == null:
			continue
		match key:
			"enemy_health":
				result *= mutator.enemy_health_mult
			"enemy_damage":
				result *= mutator.enemy_damage_mult
			"elite_chance":
				result += mutator.elite_chance_bonus
			"reward":
				result += mutator.reward_bonus
	return result


func has_mutator(id: StringName) -> bool:
	return id in mutator_ids


func get_extraction_available() -> bool:
	return active and not _ended


func begin_extraction() -> void:
	if not active or _ended:
		return
	if extraction_state != &"inactive":
		return
	extraction_state = &"holding"
	extraction_timer = get_exfil_hold_total()
	EventBus.extraction_state_changed.emit(extraction_state, extraction_timer)
	if is_tutorial():
		EventBus.notification_requested.emit("Exfil called", "Hold the pad for %d seconds to finish training." % int(get_exfil_hold_total()), &"success")
	elif is_quick_mode():
		EventBus.notification_requested.emit("Exfil called", "Quick clock: hold the pad for %d game seconds." % int(EXFIL_HOLD), &"success")
	else:
		EventBus.notification_requested.emit("Exfil called", "Hold the landing zone for %d seconds." % int(EXFIL_HOLD), &"success")


func cancel_extraction() -> void:
	if extraction_state == &"holding":
		extraction_state = &"inactive"
		extraction_timer = 0.0
		EventBus.extraction_state_changed.emit(extraction_state, 0.0)


func tick_extraction(delta: float) -> bool:
	if extraction_state != &"holding":
		return false
	extraction_timer = maxf(0.0, extraction_timer - delta * time_scale)
	EventBus.extraction_state_changed.emit(extraction_state, extraction_timer)
	if extraction_timer <= 0.0:
		if is_tutorial():
			end_run(true, "Field training complete.")
		else:
			end_run(true, "Extracted before the Collapse.")
		return true
	return false


func end_run(extracted: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	active = false
	var contract := ContentDB.get_contract(contract_id)
	var difficulty_mult := get_difficulty_reward_mult()
	var multiplier := 1.0
	if contract != null:
		multiplier += 0.15 * completed_objectives
	multiplier += maxf(0.0, get_mutator_multiplier("reward", 1.0) - 1.0)
	multiplier *= difficulty_mult
	var banked_salvage := 0
	var banked_cores := 0
	if extracted:
		var base_reward := contract.base_reward if contract != null else 0
		var core_reward := contract.core_reward if contract != null else 0
		banked_salvage = int(round((satchel_salvage + base_reward) * multiplier))
		banked_cores = satchel_cores + core_reward
	var contract_xp := contract.xp_reward if contract != null else 100
	var objective_xp := completed_objectives * 25
	var extraction_mult := 1.1 if extracted else 1.0
	var xp := int(round(float(contract_xp + combat_xp + objective_xp) * difficulty_mult * extraction_mult))
	var xp_breakdown := {
		"contract": contract_xp,
		"kills": combat_xp,
		"objectives": objective_xp,
		"difficulty_mult": difficulty_mult,
		"extraction_mult": extraction_mult,
		"total": maxi(0, xp),
	}
	var reward_items: Array = satchel_items.duplicate(true) if extracted else []
	var result := {
		"extracted": extracted,
		"reason": reason,
		"seed": run_seed,
		"contract_id": String(contract_id),
		"threat": threat,
		"difficulty_id": String(difficulty_id),
		"difficulty_name": get_difficulty_name(),
		"difficulty_reward_mult": difficulty_mult,
		"mode_id": String(mode_id),
		"mode_name": get_mode_name(),
		"mode_clock": get_mode_clock(),
		"mode_tag": get_mode_tag(),
		"run_duration": get_run_duration(),
		"time_scale": time_scale,
		"map_preset_id": String(map_preset_id),
		"map_name": get_map_preset_name(),
		"planet_id": String(planet_id),
		"planet_name": get_planet_name(),
		"weather_id": String(weather_id),
		"weather_name": weather_name,
		"time_of_day": time_of_day,
		"dungeons_entered": dungeons_entered,
		"dungeons_cleared": dungeons_cleared,
		"stage_index": stage_index,
		"stage_total": stage_total,
		"stage_title": stage_title,
		"tutorial": is_tutorial(),
		"xp_breakdown": xp_breakdown,
		"combat_xp": combat_xp,
		"elapsed": elapsed,
		"real_elapsed": elapsed / maxf(0.001, time_scale),
		"kills": kills,
		"bosses": bosses,
		"objectives": completed_objectives,
		"salvage": banked_salvage,
		"cores": banked_cores,
		"xp": maxi(0, xp),
		"value": satchel_salvage + (contract.base_reward if contract != null else 0),
		"items": reward_items,
		"item_count": reward_items.size(),
		"contract_completed": extracted and is_objective_complete(&"contract"),
		"rift_mods": rift_mods.map(func(id: StringName) -> String: return String(id)),
	}
	run_ended.emit(result)
	EventBus.deployment_ended.emit(result)


func get_result_preview() -> Dictionary:
	return {
		"satchel_value": satchel_salvage,
		"items": satchel_items.size(),
		"kills": kills,
		"objectives": completed_objectives,
		"rift_mods": rift_mods.size(),
		"dungeons_entered": dungeons_entered,
		"dungeons_cleared": dungeons_cleared,
		"stage_index": stage_index,
		"stage_total": stage_total,
		"stage_title": stage_title,
		"tutorial": is_tutorial(),
	}
