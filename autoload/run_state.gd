extends Node
## Per-deployment state only. No Nodes, no persistent meta progression.
## The deployment director ticks this; UI reads it; EventBus broadcasts changes.

signal run_ended(result: Dictionary)

const RUN_DURATION := 1080.0
const STORM_START := 720.0
const EXFIL_HOLD := 75.0

var active: bool = false
var run_seed: int = 0
var contract_id: StringName = &"salvage_sweep"
var threat: int = 1
var mutator_ids: Array[StringName] = []
var difficulty_id: StringName = &"patrol"
var difficulty: Dictionary = {}
var mode_id: StringName = &"normal"
var time_scale: float = 1.0
var map_preset_id: StringName = &""
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
var started_unix: int = 0
var last_timer_emit: float = 0.0
var _ended: bool = false


func start_run(
	p_contract_id: StringName,
	p_seed: int,
	p_threat: int = 1,
	p_mutators: Array = [],
	p_difficulty_id: StringName = &"",
	p_mode_id: StringName = &"normal"
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
	mode_id = p_mode_id if p_mode_id in [&"normal", &"quick"] else &"normal"
	time_scale = 2.0 if mode_id == &"quick" else 1.0
	map_preset_id = StringName(difficulty.get("map_preset", &""))
	if map_preset_id == &"" or ContentDB.get_map_preset(map_preset_id).is_empty():
		var presets := ContentDB.get_map_presets()
		map_preset_id = StringName(presets[0].get("id", &"verdant_verge")) if not presets.is_empty() else &"verdant_verge"
	storm_start_time = clampf(float(difficulty.get("storm_fraction", STORM_START / RUN_DURATION)), 0.1, 1.0) * RUN_DURATION
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
	time_left = RUN_DURATION
	extraction_state = &"inactive"
	extraction_timer = 0.0
	kills = 0
	bosses = 0
	combat_xp = 0
	revives_used = 0
	completed_objectives = 0
	last_timer_emit = 0.0
	started_unix = int(Time.get_unix_time_from_system())
	EventBus.deployment_started.emit(run_seed, contract_id, threat, mutator_ids.duplicate())
	EventBus.timer_updated.emit(time_left)


func tick(delta: float) -> void:
	if not active or _ended:
		return
	delta *= time_scale
	elapsed += delta
	time_left = maxf(0.0, RUN_DURATION - elapsed)
	if not storm_active and elapsed >= storm_start_time:
		storm_active = true
		EventBus.storm_changed.emit(true, _safe_radius())
	last_timer_emit += delta
	if last_timer_emit >= 0.25:
		last_timer_emit = 0.0
		EventBus.timer_updated.emit(time_left)
		if storm_active:
			EventBus.storm_changed.emit(true, _safe_radius())
	if time_left <= 0.0 and not _ended:
		end_run(false, "The Collapse consumed the Reach.")


func _safe_radius() -> float:
	var start := 900.0
	var end := 140.0
	var t := clampf((elapsed - storm_start_time) / maxf(1.0, RUN_DURATION - storm_start_time), 0.0, 1.0)
	return lerpf(start, end, t)


func get_safe_radius() -> float:
	return _safe_radius() if storm_active else 2000.0


func get_time_left() -> float:
	return time_left


func get_run_fraction() -> float:
	return clampf(elapsed / maxf(1.0, RUN_DURATION), 0.0, 1.0)


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
	return maxf(0.1, float(difficulty.get("density", 1.0)))


func get_difficulty_elite_bonus() -> float:
	return maxf(0.0, float(difficulty.get("elite_bonus", 0.0)))


func get_difficulty_reward_mult() -> float:
	return maxf(0.0, float(difficulty.get("reward", 1.0)))


func get_difficulty_mission_sites() -> int:
	return clampi(int(difficulty.get("mission_sites", 3)), 1, 8)


func get_difficulty_side_caches() -> int:
	return clampi(int(difficulty.get("side_caches", 4)), 0, 24)


func get_difficulty_bounties() -> int:
	return clampi(int(difficulty.get("bounties", 1)), 0, 6)


func get_difficulty_objective_guards() -> int:
	return clampi(int(difficulty.get("objective_guards", 3)), 1, 8)


func get_difficulty_max_hostiles() -> int:
	return clampi(int(difficulty.get("max_hostiles", 56)), 24, 96)


func get_difficulty_enemy_health_mult() -> float:
	return maxf(0.1, float(difficulty.get("enemy_health_mult", 1.0)))


func get_difficulty_enemy_damage_mult() -> float:
	return maxf(0.1, float(difficulty.get("enemy_damage_mult", 1.0)))


func get_difficulty_loot_luck() -> float:
	return clampf(float(difficulty.get("loot_luck", 0.0)), 0.0, 0.5)


func get_difficulty_director_scale() -> float:
	return clampf(float(difficulty.get("director_interval_scale", 1.0)), 0.35, 1.5)


func get_difficulty_extraction_scale() -> float:
	return maxf(0.5, float(difficulty.get("extraction_scale", 1.0)))


func get_mode_id() -> StringName:
	return mode_id


func get_mode_name() -> String:
	return "Quick" if mode_id == &"quick" else "Normal"


func get_time_scale() -> float:
	return time_scale


func is_quick_mode() -> bool:
	return mode_id == &"quick"


func get_map_preset_id() -> StringName:
	return map_preset_id


func get_map_preset_name() -> String:
	var preset := ContentDB.get_map_preset(map_preset_id)
	return String(preset.get("display_name", "Verdant Verge"))


func get_storm_start_time() -> float:
	return storm_start_time


func get_exfil_hold_total() -> float:
	return EXFIL_HOLD


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
	extraction_timer = EXFIL_HOLD
	EventBus.extraction_state_changed.emit(extraction_state, extraction_timer)
	if is_quick_mode():
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
		"time_scale": time_scale,
		"map_preset_id": String(map_preset_id),
		"map_name": get_map_preset_name(),
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
	}
