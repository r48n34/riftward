class_name WeaponController
extends Node
## Player weapon runtime. Hitscan and projectiles both resolve through
## CombatUtils/DamageData. HUD reads signals and get_hud_info().

signal weapon_changed(info: Dictionary)
signal ammo_changed(mag: int, reserve: int)
signal reload_state_changed(active: bool, progress: float)
signal hit_confirmed(killed: bool, crit: bool)
signal charge_changed(value: float)

const SWITCH_KEYS := ["weapon_1", "weapon_2", "weapon_3", "weapon_4"]
const SLOT_KEYS: Array[StringName] = [
	StatKeys.SLOT_PRIMARY, StatKeys.SLOT_PRIMARY_2, StatKeys.SLOT_SIDEARM, &"melee"
]
const SLOT_LABELS := ["PRIMARY 1", "PRIMARY 2", "SIDEARM", "KNIFE"]
## Vertical offset (metres) that puts each style's sight on the camera axis.
const ADS_SIGHT_HEIGHTS := {
	"rifle": 0.128, "carbine": 0.128, "smg": 0.095, "shotgun": 0.092,
	"dmr": 0.118, "sniper": 0.122, "lmg": 0.108, "pistol": 0.088,
	"launcher": 0.115, "arc": 0.112, "knife": 0.09,
}
static var KNIFE_STATS: Dictionary = {
	"id": "combat_knife",
	"display_name": "Combat Knife",
	"archetype": "melee",
	"slot": "melee",
	"damage": 55.0,
	"pellets": 1,
	"fire_rate": 110.0,
	"fire_mode": "melee",
	"burst_count": 1,
	"mag_size": 0,
	"reserve_ammo": 0,
	"reload_time": 0.0,
	"spread_hip": 0.0,
	"spread_ads": 0.0,
	"ads_zoom": 1.0,
	"recoil_pattern": PackedVector2Array(),
	"recoil_kick": 0.0,
	"effective_range": 2.8,
	"falloff_start": 2.8,
	"range_mult": 1.0,
	"crit_mult": 1.9,
	"projectile_speed": 0.0,
	"status_type": "none",
	"status_chance": 0.0,
	"status_power": 0.0,
	"style": "knife",
	"color": Color("d9e4e3"),
	"accent": Color("62e6c3"),
	"unique_perk": "Issued to every Warden. Fast, silent, always ready.",
	"rarity": 1,
	"rarity_color": Color("63e6c3"),
	"uid": -1,
}
const RELOAD_PADDING := 0.0

var player: Node = null
var camera: Camera3D = null
var viewmodel_root: Node3D = null
var enabled: bool = false
var current_index: int = 0
var rng := RandomNumberGenerator.new()

var _slots: Array[Dictionary] = []
var _states: Array[Dictionary] = []
var _models: Array[Node3D] = []
var _reloading: bool = false
var _reload_total: float = 0.0
var _reload_remaining: float = 0.0
var _cooldown: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _charging: bool = false
var _charge: float = 0.0
var _recoil_index: int = 0
var _recoil_reset: float = 0.0
var _time: float = 0.0
var _view_kick: float = 0.0
var _ads_amount: float = 0.0
var _muzzle_marker: Marker3D = null
var _last_hit_confirmed: bool = false
var _melee_swing: float = 0.0


func _ready() -> void:
	rng.randomize()
	set_physics_process(false)
	set_process(false)


func setup(p_player: Node, p_camera: Camera3D) -> void:
	player = p_player
	camera = p_camera
	if camera == null:
		push_error("[WeaponController] Camera missing.")
		return
	viewmodel_root = Node3D.new()
	viewmodel_root.name = "ViewmodelRoot"
	viewmodel_root.scale = Vector3(0.54, 0.54, 0.54)
	camera.add_child(viewmodel_root)
	_load_loadout()
	enabled = true
	set_physics_process(true)
	set_process(true)
	_equip_slot(0, true)


func _load_loadout() -> void:
	_slots.clear()
	_states.clear()
	_models.clear()
	var fallback_ids := ContentDB.get_starting_weapon_ids()
	var skin := ContentDB.get_cosmetic(StringName(ProfileState.get_equipped_cosmetic("weapon_skin")))
	for i in SLOT_KEYS.size():
		var slot_key := SLOT_KEYS[i]
		var stats: Dictionary = {}
		if slot_key == &"melee":
			stats = KNIFE_STATS.duplicate(true)
		else:
			var item := ProfileState.get_weapon_item(slot_key)
			if not item.is_empty():
				stats = ItemFactory.weapon_runtime_stats(item)
			if stats.is_empty():
				var fallback_id: StringName = fallback_ids[i] if i < fallback_ids.size() else &"sidewinder"
				var fallback_slot := String(StatKeys.SLOT_PRIMARY) if i < 2 else String(StatKeys.SLOT_SIDEARM)
				var fake := ItemFactory.make_item("weapon", fallback_id, fallback_slot, 0, 1, 0)
				stats = ItemFactory.weapon_runtime_stats(fake)
		if skin != null:
			stats["color"] = skin.color
			stats["accent"] = skin.accent
		stats["slot_key"] = String(slot_key)
		stats["slot_label"] = SLOT_LABELS[i]
		stats["slot_index"] = i
		_slots.append(stats)
		_states.append({
			"mag": int(stats.get("mag_size", 0)),
			"reserve": int(stats.get("reserve_ammo", 0)),
		})
		var model := WeaponModelBuilder.build(stats)
		model.visible = false
		viewmodel_root.add_child(model)
		_models.append(model)


func _equip_slot(index: int, force: bool = false) -> void:
	if index < 0 or index >= _slots.size():
		return
	if not force and index == current_index:
		return
	current_index = index
	_cancel_actions()
	for i in _models.size():
		_models[i].visible = i == current_index
	_muzzle_marker = _models[current_index].get_node_or_null("Muzzle") as Marker3D
	weapon_changed.emit(get_weapon_info())
	_emit_ammo()
	player.call("update_hud")


func _cancel_actions() -> void:
	_reloading = false
	_reload_remaining = 0.0
	_burst_left = 0
	_burst_timer = 0.0
	_charging = false
	_charge = 0.0
	_melee_swing = 0.0
	reload_state_changed.emit(false, 0.0)


func get_current_stats() -> Dictionary:
	return _slots[current_index] if current_index < _slots.size() else {}


func get_slot_count() -> int:
	return _slots.size()


func get_active_slot_index() -> int:
	return current_index


func is_melee_weapon() -> bool:
	return String(get_current_stats().get("style", "")) == "knife"


func get_slot_summary() -> Array:
	var out: Array = []
	for i in _slots.size():
		var stats: Dictionary = _slots[i]
		var state: Dictionary = _states[i] if i < _states.size() else {}
		out.append({
			"name": String(stats.get("display_name", "Weapon")),
			"slot_label": String(stats.get("slot_label", "SLOT %d" % (i + 1))),
			"slot_index": i,
			"rarity": int(stats.get("rarity", 0)),
			"rarity_color": stats.get("rarity_color", Color("a7b4b6")),
			"is_melee": String(stats.get("style", "")) == "knife",
			"active": i == current_index,
			"ammo": int(state.get("mag", 0)),
			"reserve": int(state.get("reserve", 0)),
		})
	return out


func get_loadout_info() -> Array:
	var out: Array = []
	for i in _slots.size():
		var stats: Dictionary = _slots[i]
		var state: Dictionary = _states[i] if i < _states.size() else {}
		out.append({
			"index": i,
			"slot_key": String(stats.get("slot_key", "")),
			"slot_label": String(stats.get("slot_label", "SLOT %d" % (i + 1))),
			"name": String(stats.get("display_name", "Weapon")),
			"style": String(stats.get("style", "rifle")),
			"rarity": int(stats.get("rarity", 0)),
			"rarity_color": stats.get("rarity_color", Color("a7b4b6")),
			"is_melee": String(stats.get("style", "")) == "knife",
			"active": i == current_index,
			"ammo": int(state.get("mag", 0)),
			"reserve": int(state.get("reserve", 0)),
			"mag_size": int(stats.get("mag_size", 0)),
			"damage": float(stats.get("damage", 0.0)),
			"range": float(stats.get("effective_range", 0.0)),
			"reloading": _reloading and i == current_index,
			"perk": String(stats.get("unique_perk", "")),
		})
	return out


func get_weapon_info() -> Dictionary:
	var stats := get_current_stats()
	if stats.is_empty():
		return {}
	return {
		"name": String(stats.get("display_name", "Weapon")),
		"slot": String(stats.get("slot", "primary")),
		"slot_key": String(stats.get("slot_key", "primary")),
		"slot_label": String(stats.get("slot_label", "PRIMARY")),
		"slot_index": int(stats.get("slot_index", 0)),
		"rarity": int(stats.get("rarity", 0)),
		"rarity_color": stats.get("rarity_color", Color("a7b4b6")),
		"style": String(stats.get("style", "rifle")),
		"accent": stats.get("accent", Color("62e6c3")),
		"is_melee": String(stats.get("style", "")) == "knife",
		"perk": String(stats.get("unique_perk", "")),
	}


func get_hud_info() -> Dictionary:
	var stats := get_current_stats()
	var state: Dictionary = _states[current_index] if current_index < _states.size() else {}
	var melee := String(stats.get("style", "")) == "knife"
	return {
		"weapon_name": String(stats.get("display_name", "Weapon")),
		"weapon_slot": String(stats.get("slot", "primary")),
		"weapon_slot_label": String(stats.get("slot_label", "PRIMARY")),
		"weapon_slot_index": int(stats.get("slot_index", 0)),
		"weapon_style": String(stats.get("style", "rifle")),
		"weapon_accent": stats.get("accent", Color("62e6c3")),
		"rarity": int(stats.get("rarity", 0)),
		"rarity_color": stats.get("rarity_color", Color("a7b4b6")),
		"ammo": -1 if melee else int(state.get("mag", 0)),
		"reserve": -1 if melee else int(state.get("reserve", 0)),
		"mag_size": maxi(1, int(stats.get("mag_size", 0))),
		"reloading": _reloading,
		"reload_progress": get_reload_progress(),
		"charge": _charge,
		"is_ads": is_ads(),
		"ads_amount": _ads_amount,
		"ads_zoom": get_ads_zoom(),
		"is_melee": melee,
		"effective_range": float(stats.get("effective_range", 120.0)),
		"weapon_slots": get_slot_summary(),
	}


func _emit_ammo() -> void:
	if current_index >= _states.size():
		return
	ammo_changed.emit(int(_states[current_index].mag), int(_states[current_index].reserve))


func is_ads() -> bool:
	return _ads_amount > 0.25


func get_ads_amount() -> float:
	return _ads_amount


func get_ads_zoom() -> float:
	var stats := get_current_stats()
	return clampf(float(stats.get("ads_zoom", 0.82)), 0.2, 1.0)


func get_reload_progress() -> float:
	if not _reloading or _reload_total <= 0.0:
		return 1.0 if not _reloading else 0.0
	return clampf(1.0 - _reload_remaining / _reload_total, 0.0, 1.0)


func set_enabled(value: bool) -> void:
	enabled = value
	if viewmodel_root != null:
		viewmodel_root.visible = value
	_cancel_actions()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not enabled:
		return
	if player.has_method("is_downed") and player.call("is_downed"):
		return
	_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_burst_timer = maxf(0.0, _burst_timer - delta)
	_recoil_reset = maxf(0.0, _recoil_reset - delta)
	_melee_swing = maxf(0.0, _melee_swing - delta * 4.5)
	if _recoil_reset <= 0.0:
		_recoil_index = 0
	var aim_pressed := Input.is_action_pressed("aim")
	var sprinting := false
	if player.has_method("is_sprinting"):
		sprinting = bool(player.call("is_sprinting"))
	var target_ads := 1.0 if aim_pressed and not _reloading and not sprinting and not is_melee_weapon() else 0.0
	_ads_amount = move_toward(_ads_amount, target_ads, delta * 6.0)
	if _reloading:
		_reload_remaining -= delta
		reload_state_changed.emit(true, get_reload_progress())
		if _reload_remaining <= 0.0:
			_finish_reload()
		player.call("update_hud")
		return
	if _charging:
		if not Input.is_action_pressed("fire") or int(_states[current_index].mag) <= 0:
			if int(_states[current_index].mag) > 0 and _charge >= 0.55:
				_fire_once(1.0 + _charge * 0.65)
			_charging = false
			_charge = 0.0
			charge_changed.emit(0.0)
		else:
			_charge = minf(1.0, _charge + delta / 0.9)
			charge_changed.emit(_charge)
			player.call("update_hud")
		return
	if _burst_left > 0:
		if _burst_timer <= 0.0:
			_fire_once(1.0)
			_burst_left -= 1
			_burst_timer = 60.0 / maxf(60.0, float(get_current_stats().get("fire_rate", 300.0)))
		if _burst_left <= 0:
			_cooldown = maxf(_cooldown, 0.14)
		return
	_handle_swap_input()
	if is_melee_weapon():
		if Input.is_action_just_pressed("fire"):
			_try_melee_attack()
		update_viewmodel(delta)
		return
	if Input.is_action_just_pressed("reload"):
		start_reload()
	var fire_mode := String(get_current_stats().get("fire_mode", "auto"))
	var trigger_down := Input.is_action_pressed("fire")
	var trigger_just := Input.is_action_just_pressed("fire")
	if fire_mode == "charge":
		if trigger_just:
			_charging = int(_states[current_index].mag) > 0
			_charge = 0.0
		return
	if fire_mode == "auto":
		if trigger_down:
			_try_fire(1.0)
	elif fire_mode == "burst":
		if trigger_just:
			if _try_fire(1.0):
				_burst_left = maxi(1, int(get_current_stats().get("burst_count", 3)))
				_burst_left -= 1
				_burst_timer = 60.0 / maxf(60.0, float(get_current_stats().get("fire_rate", 300.0)))
	else:
		if trigger_just:
			_try_fire(1.0)
	update_viewmodel(delta)


func _process(delta: float) -> void:
	if viewmodel_root == null or player == null or not is_instance_valid(player):
		return
	if player.has_method("is_downed") and player.call("is_downed"):
		return
	update_viewmodel(delta)


func _handle_swap_input() -> void:
	for i in mini(SWITCH_KEYS.size(), _slots.size()):
		var action: StringName = StringName(SWITCH_KEYS[i])
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			if i != current_index:
				_equip_slot(i)
				return
	if InputMap.has_action("weapon_swap") and Input.is_action_just_pressed("weapon_swap"):
		if _slots.size() > 1:
			_equip_slot((current_index + 1) % _slots.size())


func _try_melee_attack() -> bool:
	if not enabled or _reloading or _cooldown > 0.0 or current_index >= _slots.size():
		return false
	var stats := get_current_stats()
	var rpm := maxf(30.0, float(stats.get("fire_rate", 110.0)))
	_cooldown = 60.0 / rpm
	_melee_swing = 1.0
	_recoil_reset = 0.4
	AudioDirector.play_sfx(&"knife_swing", -7.0)
	var result := CombatUtils.melee_strike(
		player,
		camera,
		float(stats.get("damage", 55.0)) * _damage_multiplier(),
		float(stats.get("effective_range", 2.8)),
		StatKeys.DMG_KINETIC,
		stats.get("accent", Color("62e6c3"))
	)
	if bool(result.get("applied", false)):
		var killed := bool(result.get("killed", false))
		hit_confirmed.emit(killed, true)
		AudioDirector.play_sfx(&"hitmarker" if not killed else &"kill", -6.0)
		if player.has_method("add_trauma"):
			player.call("add_trauma", 0.09 if killed else 0.03)
	player.call("update_hud")
	return true


func _try_fire(damage_mult: float) -> bool:
	if not enabled or _reloading or _cooldown > 0.0 or is_melee_weapon():
		return false
	var state: Dictionary = _states[current_index]
	if int(state.mag) <= 0:
		start_reload()
		return false
	_fire_once(damage_mult)
	return true


func _fire_once(damage_mult: float) -> void:
	if _reloading or _cooldown > 0.0 or current_index >= _slots.size() or is_melee_weapon():
		return
	var state: Dictionary = _states[current_index]
	if int(state.mag) <= 0:
		start_reload()
		return
	var stats := get_current_stats()
	state.mag = int(state.mag) - 1
	_emit_ammo()
	var rpm := maxf(45.0, float(stats.get("fire_rate", 300.0)))
	var rate_mult := 1.0
	if player.has_method("get_fire_rate_mult"):
		rate_mult = float(player.call("get_fire_rate_mult"))
	_cooldown = 60.0 / (rpm * maxf(0.5, rate_mult))
	_recoil_reset = 0.55
	_play_fire_sound(stats)
	_muzzle_flash(stats)
	if String(stats.get("fire_mode", "auto")) == "projectile":
		_fire_projectile(stats, damage_mult)
	else:
		_fire_hitscan(stats, damage_mult)
	_apply_recoil(stats)
	_view_kick = 1.0
	if int(state.mag) <= 0 and int(state.reserve) > 0:
		start_reload()
	player.call("update_hud")
	if _muzzle_marker != null:
		var enemies := get_tree().get_nodes_in_group("enemy_ai")
		if not enemies.is_empty():
			get_tree().call_group(&"enemy_ai", &"hear_noise", _muzzle_marker.global_position, 42.0)


func _fire_hitscan(stats: Dictionary, damage_mult: float) -> void:
	var state: Dictionary = _states[current_index]
	var spread_deg := _current_spread(stats)
	var pellets := maxi(1, int(stats.get("pellets", 1)))
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var max_range := maxf(25.0, float(stats.get("effective_range", 120.0)) * 1.6)
	var hit_any := false
	var hit_killed := false
	var hit_crit := false
	if _muzzle_marker == null:
		return
	var muzzle_pos := _muzzle_marker.global_position
	for i in pellets:
		var dir := _apply_spread(forward, spread_deg)
		var end := origin + dir * max_range
		var query := PhysicsRayQueryParameters3D.create(origin, end, CombatUtils.HIT_MASK, [player.get_rid()])
		query.collide_with_areas = false
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		var resolved_end := end
		if not hit.is_empty():
			resolved_end = hit.position
			var collider = hit.collider
			var distance := origin.distance_to(hit.position)
			var falloff := _falloff_for(stats, distance)
			var crit := _roll_crit()
			var crit_mult := _crit_mult_for(stats)
			var amount := float(stats.get("damage", 10.0)) * damage_mult * falloff
			amount *= _damage_multiplier()
			if player.has_method("is_hyperfocused") and bool(player.call("is_hyperfocused")):
				amount *= 1.6
				crit = true
			if crit:
				amount *= crit_mult
			var data := DamageData.make(amount, StatKeys.TEAM_PLAYER, _damage_type_for(stats), player)
			data.crit = crit
			data.hit_position = hit.position
			data.hit_normal = hit.normal
			var status_type := StringName(stats.get("status_type", "none"))
			if status_type != StatKeys.STATUS_NONE and rng.randf() < float(stats.get("status_chance", 0.0)):
				data.status_type = status_type
				data.status_power = float(stats.get("status_power", 0.0)) * _status_multiplier()
				data.status_duration = 4.0
			data.impulse = dir * 2.0
			var applied := CombatUtils.apply_hit(collider, data, int(hit.get("shape", -1)))
			if bool(applied.get("applied", false)):
				hit_any = true
				var weakpoint := bool(applied.get("weakpoint", false))
				var killed := bool(applied.get("killed", false))
				hit_killed = hit_killed or killed
				hit_crit = hit_crit or crit or weakpoint
				if bool(App.get_setting("damage_numbers", true)):
					CombatVFX.damage_number(_get_effect_parent(), hit.position, amount, crit, weakpoint)
				AudioDirector.play_sfx(&"hitmarker" if not killed else &"kill", -6.0)
			else:
				CombatVFX.impact(_get_effect_parent(), hit.position, hit.normal, stats.get("accent", Color("ffb866")))
		CombatVFX.spawn_tracer(_get_effect_parent(), muzzle_pos, resolved_end, stats.get("accent", Color("ffe9b8")))
	if hit_any:
		hit_confirmed.emit(hit_killed, hit_crit)
		if player.has_method("add_trauma"):
			player.call("add_trauma", 0.1 if hit_killed else 0.04)


func _fire_projectile(stats: Dictionary, damage_mult: float) -> void:
	var projectile := CombatProjectile.new()
	projectile.name = "PlayerProjectile"
	projectile.setup(
		camera.global_position - camera.global_transform.basis.z * 0.7,
		-camera.global_transform.basis.z,
		float(stats.get("projectile_speed", 45.0)),
		float(stats.get("damage", 100.0)) * damage_mult * _damage_multiplier(),
		StatKeys.TEAM_PLAYER,
		player,
		0.16,
		5.0,
		stats.get("accent", Color("ffb866")),
		6.5,
		-1.0
	)
	_get_effect_parent().add_child(projectile)


func _get_effect_parent() -> Node3D:
	if player != null and player.has_method("get_effect_parent"):
		var parent = player.call("get_effect_parent")
		if parent is Node3D:
			return parent
	var parent := get_parent()
	if parent is Node3D:
		return parent
	return get_tree().current_scene as Node3D


func _apply_spread(forward: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.001:
		return forward
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var angle := rng.randf_range(0.0, TAU)
	var radius := sqrt(rng.randf()) * tan(deg_to_rad(degrees))
	return (forward + right * cos(angle) * radius + up * sin(angle) * radius).normalized()


func _current_spread(stats: Dictionary) -> float:
	var base := float(stats.get("spread_ads", 0.3)) if _ads_amount > 0.5 else float(stats.get("spread_hip", 2.0))
	var handling := _player_stat(StatKeys.HANDLING, 1.0)
	var spread_mult := clampf(1.35 - handling * 0.22, 0.65, 1.35)
	var move_penalty := 1.0
	if player.has_method("get_move_speed_ratio"):
		move_penalty += float(player.call("get_move_speed_ratio")) * 0.7
	var crouch_bonus := 1.0
	if player.has_method("is_crouching") and bool(player.call("is_crouching")):
		crouch_bonus = 0.82
	return base * spread_mult * move_penalty * crouch_bonus * (1.0 - _ads_amount * 0.25)


func _falloff_for(stats: Dictionary, distance: float) -> float:
	var start := float(stats.get("falloff_start", 40.0))
	var effective := float(stats.get("effective_range", 120.0))
	if distance <= start:
		return 1.0
	var t := clampf((distance - start) / maxf(10.0, effective - start), 0.0, 1.0)
	return lerpf(1.0, float(stats.get("range_mult", 0.5)), t)


func _damage_multiplier() -> float:
	return _player_stat(StatKeys.DAMAGE_MULT, 1.0)


func _crit_mult_for(stats: Dictionary) -> float:
	var player_mult := _player_stat(StatKeys.CRIT_MULT, 1.75)
	return maxf(player_mult, float(stats.get("crit_mult", 1.75)))


func _status_multiplier() -> float:
	return _player_stat(StatKeys.STATUS_POWER, 1.0)


func _roll_crit() -> bool:
	return rng.randf() < _player_stat(StatKeys.CRIT_CHANCE, 0.05)


func _player_stat(key: StringName, fallback: float) -> float:
	if player == null or not player.has_method("get_stat"):
		return fallback
	return float(player.call("get_stat", key, fallback))


func _damage_type_for(stats: Dictionary) -> StringName:
	match String(stats.get("style", "rifle")):
		"arc":
			return StatKeys.DMG_SHOCK
		"carbine":
			return StatKeys.DMG_CORROSIVE
		"launcher":
			return StatKeys.DMG_KINETIC
		"sniper", "dmr":
			return StatKeys.DMG_ENERGY
		_:
			return StatKeys.DMG_BALLISTIC


func _apply_recoil(stats: Dictionary) -> void:
	var pattern: PackedVector2Array = stats.get("recoil_pattern", PackedVector2Array())
	var offset := Vector2(0.0, 1.0)
	if not pattern.is_empty():
		offset = pattern[mini(_recoil_index, pattern.size() - 1)]
		_recoil_index += 1
	var handling := _player_stat(StatKeys.HANDLING, 1.0)
	var scale := float(stats.get("recoil_kick", 1.0)) * clampf(1.3 - handling * 0.2, 0.6, 1.3)
	if player.has_method("add_recoil"):
		player.call("add_recoil", offset * scale)
	if player.has_method("add_trauma"):
		player.call("add_trauma", 0.02 * float(stats.get("recoil_kick", 1.0)))


func _muzzle_flash(stats: Dictionary) -> void:
	if _muzzle_marker == null:
		return
	CombatVFX.muzzle_flash(_get_effect_parent(), _muzzle_marker.global_position, stats.get("accent", Color("ffd89a")))


func _play_fire_sound(stats: Dictionary) -> void:
	var id := &"shot_rifle"
	match String(stats.get("style", "rifle")):
		"smg":
			id = &"shot_smg"
		"shotgun":
			id = &"shot_shotgun"
		"dmr":
			id = &"shot_dmr"
		"sniper":
			id = &"shot_sniper"
		"lmg":
			id = &"shot_lmg"
		"pistol":
			id = &"shot_pistol"
		"launcher":
			id = &"shot_launcher"
		"arc":
			id = &"shot_arc"
		"carbine":
			id = &"shot_carbine"
	AudioDirector.play_sfx(id, -4.0)
	if player.has_method("add_trauma"):
		player.call("add_trauma", 0.015 * float(stats.get("recoil_kick", 1.0)))


func start_reload() -> void:
	if _reloading or current_index >= _states.size() or is_melee_weapon():
		return
	var stats := get_current_stats()
	var state: Dictionary = _states[current_index]
	if int(state.mag) >= int(stats.get("mag_size", 1)) or int(state.reserve) <= 0:
		return
	var reload_speed := _player_stat(StatKeys.RELOAD_SPEED, 1.0)
	_reload_total = maxf(0.25, float(stats.get("reload_time", 2.0)) / maxf(0.5, reload_speed))
	_reload_remaining = _reload_total
	_reloading = true
	reload_state_changed.emit(true, 0.0)
	AudioDirector.play_sfx(&"reload", -10.0)
	player.call("update_hud")


func _finish_reload() -> void:
	var stats := get_current_stats()
	var state: Dictionary = _states[current_index]
	var needed := int(stats.get("mag_size", 1)) - int(state.mag)
	var transfer := mini(needed, int(state.reserve))
	state.mag = int(state.mag) + transfer
	state.reserve = int(state.reserve) - transfer
	_reloading = false
	_reload_remaining = 0.0
	reload_state_changed.emit(false, 1.0)
	_emit_ammo()
	AudioDirector.play_sfx(&"reload", -14.0)
	player.call("update_hud")


func update_viewmodel(delta: float) -> void:
	if viewmodel_root == null or current_index >= _models.size():
		return
	_time += delta
	var stats := get_current_stats()
	var melee := String(stats.get("style", "")) == "knife"
	var ads := 0.0 if melee else _ads_amount
	var style := String(stats.get("style", "rifle"))
	var sight_height := float(ADS_SIGHT_HEIGHTS.get(style, 0.12))
	var base_pos := Vector3(0.22, -0.265, -0.58)
	if melee:
		base_pos = Vector3(0.24, -0.29, -0.5)
	# Centre the active iron sight / optic on the camera axis at full ADS.
	var ads_pos := Vector3(0.0, -sight_height, -0.48)
	var target := base_pos.lerp(ads_pos, ads)
	var speed := 0.0
	if player.has_method("get_move_speed_ratio"):
		speed = float(player.call("get_move_speed_ratio"))
	var bob_scale := (1.0 - ads * 0.7) * clampf(speed, 0.0, 1.0)
	var bob := Vector3(cos(_time * 8.0) * 0.012, sin(_time * 16.0) * 0.009, 0.0) * bob_scale
	target += bob
	target.z += _view_kick * 0.035
	_view_kick = move_toward(_view_kick, 0.0, delta * 10.0)
	var swing := 0.0
	if _melee_swing > 0.0:
		swing = sin((1.0 - _melee_swing) * PI) * _melee_swing
		target.x -= swing * 0.16
		target.z += swing * 0.2
	viewmodel_root.position = viewmodel_root.position.lerp(target, minf(1.0, delta * 14.0))
	var target_rot_x := -_view_kick * 0.04 - swing * 0.55
	var target_rot_z := lerpf(-0.035, 0.0, ads) + bob.x * 0.4 + swing * 0.35
	if _reloading:
		var p := get_reload_progress()
		target_rot_x += sin(p * PI) * 0.35
		var reload_offset := sin(p * PI) * 0.08
		viewmodel_root.position.y -= reload_offset
		viewmodel_root.position.z += reload_offset * 0.4
	viewmodel_root.rotation.x = lerp_angle(viewmodel_root.rotation.x, target_rot_x, minf(1.0, delta * 14.0))
	viewmodel_root.rotation.z = lerp_angle(viewmodel_root.rotation.z, target_rot_z, minf(1.0, delta * 12.0))
	var sway := Input.get_last_mouse_velocity() * 0.000004
	var target_rot_y := lerpf(0.23, 0.0, ads) + clampf(-sway.x, -0.04, 0.04) + swing * 0.7
	viewmodel_root.rotation.y = lerp_angle(viewmodel_root.rotation.y, target_rot_y, minf(1.0, delta * 8.0))
