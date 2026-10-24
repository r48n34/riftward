extends Node3D
## Headless end-to-end gameplay smoke: world -> player -> shoot -> ability ->
## objective -> exfil. Run with:
##   Godot_v4.7.2... --headless --path . res://tests/integration_test.tscn

var deployment: Deployment = null
var player: Player = null
var _failures: Array[String] = []
var _checks: int = 0
var result_signal: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[TEST] FAIL: " + label)


func _run() -> void:
	print("[TEST] RIFTWARD integration test starting")
	await get_tree().process_frame
	_check(ContentDB.initialized, "ContentDB initialized")
	_check(ContentDB.content_errors.is_empty(), "ContentDB has no validation errors")
	_check(ContentDB.weapons.size() == 10, "10 weapons loaded")
	_check(ContentDB.abilities.size() == 16, "16 abilities loaded")
	_check(ContentDB.enemies.size() == 23, "23 enemy entries loaded")
	_check(ContentDB.difficulties.size() == 4, "4 run difficulties loaded")
	_check(ContentDB.allies.size() == 4, "4 allies loaded")
	_check(ContentDB.pets.size() == 3, "3 pets loaded")
	_check(ContentDB.base_modules.size() == 8, "8 base modules loaded")
	_check(ContentDB.contracts.size() == 6, "6 contracts loaded")
	_check(ProfileState.get_level() >= 1, "profile loaded")
	RunState.run_ended.connect(_on_run_ended)
	deployment = Deployment.new()
	deployment.name = "TestDeployment"
	add_child(deployment)
	deployment.ready_to_play.connect(_on_ready)
	deployment.setup(&"salvage_sweep", 98765, 1, [])
	var waited := 0.0
	while player == null and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_check(player != null, "deployment reached playable state")
	if player == null:
		_finish()
		return
	_check(deployment.world != null, "procedural world instantiated")
	_check(deployment.world.get_pois().size() >= 16, "world exposes 16+ POIs")
	_check(String(RunState.map_preset_id) != "", "run carries a map preset")
	_check(String(RunState.mode_id) == "normal", "run carries the normal mode by default")
	_check(RunState.get_difficulty_density() >= 1.35, "deployment uses the hardened difficulty baseline")
	var tactical: Dictionary = deployment.get_tactical_data()
	_check(tactical.get("map_texture") != null, "tactical data carries the world map texture")
	_check((tactical.get("markers", []) as Array).size() >= 4, "tactical data exposes objective/exfil markers")
	_check((tactical.get("hostiles", []) as Array).size() >= 1, "tactical data exposes live hostiles")
	_check(String(tactical.get("map_name", "")).length() > 0, "tactical data carries the map name")
	_check(String(tactical.get("mode_name", "")).length() > 0, "tactical data carries the mode name")
	_check(RunState.objectives.size() >= 3, "deployment seeds contract and side objectives")
	_check(RunState.get_objective_total(&"contract") >= 3, "contract objective reports its site count")
	if deployment.has_method("get_loot_caches"):
		var caches: Array = deployment.call("get_loot_caches")
		_check(caches.size() >= 2, "deployment spawns loot caches")
	if deployment.has_method("get_mission_trackers"):
		var trackers: Array = deployment.call("get_mission_trackers")
		_check(trackers.size() >= 2, "deployment exposes HUD mission trackers")
	_check(get_tree().get_nodes_in_group("enemy_ai").size() >= 5, "enemy agents spawned")
	_check(get_tree().get_nodes_in_group("allies").size() >= 1, "Wardens spawned")
	_check(get_tree().get_nodes_in_group("pets").size() >= 1, "Driftling spawned")
	_check(player.get_health_component() != null, "player health component")
	_check(player.weapon_controller != null, "player weapon controller")
	_check(player.ability_manager != null, "player ability manager")
	_check(not player.get_hud_snapshot().is_empty(), "HUD snapshot available")
	_check(player.weapon_controller.get_ads_zoom() < 1.0, "equipped weapon exposes an ADS zoom factor")
	var loadout: Array = player.weapon_controller.get_loadout_info()
	_check(player.weapon_controller.get_slot_count() == 4, "weapon controller owns four slots")
	_check(loadout.size() == 4, "loadout exposes four weapon entries")
	_check(loadout.size() == 4 and bool(loadout[3].get("is_melee", false)), "slot 4 is the issued knife")
	var initial_hud := player.get_hud_snapshot()
	_check((initial_hud.get("weapon_slots", []) as Array).size() == 4, "HUD snapshot carries four weapon slots")
	var inventory_snapshot: Dictionary = player.get_inventory_snapshot()
	_check((inventory_snapshot.get("weapons", []) as Array).size() == 4, "inventory snapshot exposes four weapon slots")
	_check(inventory_snapshot.has("satchel_items"), "inventory snapshot exposes the satchel")
	Input.action_press("crouch_alt")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var crouched_with_c := player.is_crouching()
	Input.action_release("crouch_alt")
	await get_tree().physics_frame
	_check(crouched_with_c, "C crouch action enters crouch")
	Input.action_press("crouch_alt")
	await get_tree().physics_frame
	Input.action_release("crouch_alt")
	await get_tree().physics_frame
	_check(not player.is_crouching(), "second C crouch press stands up in the open")
	player.health_component.set_invulnerable(120.0)

	# Weapon fires and damages a real enemy.
	var enemy := _first_enemy()
	_check(enemy != null, "live enemy found")
	if enemy != null:
		var enemy_health := CombatUtils.find_health(enemy)
		var enemy_node := enemy as Node3D
		var enemy_bar = enemy_node.call("get_health_bar") if enemy_node.has_method("get_health_bar") else null
		_check(enemy_bar != null, "enemy exposes a head-mounted health bar")
		enemy.set_physics_process(false)
		print("[TEST] enemy layer=", enemy_node.collision_layer, " shapes=", enemy_node.get_child_count(), " data=", enemy_node.call("get_enemy_data").display_name if enemy_node.has_method("get_enemy_data") else "?")
		var player_pos := enemy_node.global_position - Vector3(6.0, 0.0, 0.0)
		if deployment.world != null and deployment.world.has_method("sample_height"):
			player_pos.y = float(deployment.world.call("sample_height", Vector2(player_pos.x, player_pos.z))) + 0.15
		player.global_position = player_pos
		var to_enemy := enemy_node.global_position - player.global_position
		var target_yaw := atan2(-to_enemy.x, -to_enemy.z)
		player.rotation.y = target_yaw
		player.yaw = target_yaw
		var target_pitch := atan2(
			enemy_node.global_position.y + 0.9 - (player.global_position.y + 1.62),
			maxf(0.1, Vector2(to_enemy.x, to_enemy.z).length())
		)
		player.head.rotation.x = target_pitch
		player.camera.rotation = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ray_origin := player.camera.global_position
		var ray_dir := -player.camera.global_transform.basis.z
		var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 50.0, 1 | 4 | 8 | 128, [player.get_rid()])
		var aim_hit := player.get_world_3d().direct_space_state.intersect_ray(ray_query)
		print("[TEST] aim ray collider=", aim_hit.get("collider"), " at ", aim_hit.get("position", Vector3.INF), " player=", player.global_position, " enemy=", enemy_node.global_position)
		var before := enemy_health.health + enemy_health.shield
		var ammo_before: int = int(player.weapon_controller.get_hud_info().get("ammo", 0))
		print("[TEST] firing weapon: ", player.weapon_controller.get_weapon_info(), " hud=", player.weapon_controller.get_hud_info())
		Input.action_press("aim")
		for i in 8:
			await get_tree().physics_frame
		Input.action_press("fire")
		for i in 90:
			await get_tree().physics_frame
		Input.action_release("fire")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("aim")
		var after := enemy_health.health + enemy_health.shield
		var ammo_after: int = int(player.weapon_controller.get_hud_info().get("ammo", 0))
		print("[TEST] shot result before=%s after=%s ammo=%d->%d dead=%s" % [before, after, ammo_before, ammo_after, enemy_health.dead])
		_check(ammo_after != ammo_before, "firing consumes ammo")
		_check(enemy_health.dead or after < before, "shots damage an enemy")
		if enemy_bar != null:
			_check(float(enemy_bar.call("get_health_fraction")) < 1.0, "enemy head bar tracks damage")
		enemy.process_mode = Node.PROCESS_MODE_INHERIT

	# Knife slot: switch, verify melee state, swing without ammo, return to primary.
	Input.action_press("weapon_4")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("weapon_4")
	await get_tree().physics_frame
	var knife_info: Dictionary = player.weapon_controller.get_hud_info()
	_check(bool(knife_info.get("is_melee", false)), "weapon_4 equips the knife")
	_check(String(knife_info.get("weapon_slot_label", "")) == "KNIFE", "knife reports its HUD slot label")
	var knife_ammo := int(knife_info.get("ammo", 0))
	Input.action_press("fire")
	for i in 5:
		await get_tree().physics_frame
	Input.action_release("fire")
	await get_tree().physics_frame
	_check(int(player.weapon_controller.get_hud_info().get("ammo", 0)) == knife_ammo, "knife swings do not consume ammo")
	Input.action_press("weapon_1")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("weapon_1")
	await get_tree().physics_frame
	_check(not bool(player.weapon_controller.get_hud_info().get("is_melee", true)), "weapon_1 returns to the firearm")

	# Ability input triggers cooldown.
	var ability_before := player.ability_manager.cooldowns[0]
	Input.action_press("ability_1")
	await get_tree().physics_frame
	Input.action_release("ability_1")
	await get_tree().physics_frame
	_check(player.ability_manager.cooldowns[0] > ability_before, "ability cast starts cooldown")

	# Exercise every authored ability effect for runtime errors.
	for ability_data in ContentDB.abilities.values():
		print("[TEST] exercising ability: ", ability_data.id)
		if ability_data.is_ultimate:
			player.ability_manager.ultimate = ability_data
			player.ability_manager.cooldowns[2] = 0.0
			player.ability_manager.cast_ability(2)
		else:
			player.ability_manager.abilities = [ability_data, ability_data]
			player.ability_manager.cooldowns[0] = 0.0
			player.ability_manager.cast_ability(0)
		await get_tree().create_timer(0.25).timeout
	player.health_component.set_invulnerable(120.0)

	# Exercise every world event definition through the real deployment effect path.
	for event_def in Deployment.WORLD_EVENTS:
		print("[TEST] exercising world event: ", event_def.get("id", ""))
		deployment.call("_trigger_world_event", {"event": event_def, "time": 0.0})
		await get_tree().create_timer(0.12).timeout
	_check(get_tree().get_nodes_in_group("enemy_ai").size() >= 5, "world events keep hostiles active")

	# Exercise every endgame pressure definition through the real effect path.
	for event_def in Deployment.ENDGAME_EVENTS:
		print("[TEST] exercising endgame event: ", event_def.get("id", ""))
		deployment.call("_trigger_endgame_event", event_def)
		await get_tree().create_timer(0.12).timeout
	_check(get_tree().get_nodes_in_group("enemy_ai").size() >= 5, "endgame events keep hostiles active")

	# Objective interaction through the real Player interaction ray and E input.
	var sites := deployment.get_objective_sites()
	var objective_site := sites[0] if not sites.is_empty() else null
	_check(objective_site != null, "objective site exists")
	if objective_site != null:
		var before_progress := RunState.get_objective_progress(&"contract")
		var prompt := ""
		for approach_angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			await _stand_near(objective_site, 4.0, approach_angle)
			await get_tree().create_timer(0.3).timeout
			prompt = String(player.get_hud_snapshot().get("interact_prompt", ""))
			if prompt.length() > 0:
				break
		_check(prompt.length() > 0, "player sees an objective interaction prompt")
		if prompt.length() == 0:
			print("[TEST] objective prompt debug: site_completed=", objective_site.completed,
				" site=", objective_site.global_position,
				" player=", player.global_position,
				" layer=", objective_site.collision_layer)
		Input.action_press("interact")
		await get_tree().physics_frame
		Input.action_release("interact")
		await get_tree().physics_frame
		_check(RunState.get_objective_progress(&"contract") > before_progress, "objective interaction advances contract")

	# Exfil flow through the real beacon interaction.
	var exfils := deployment.get_exfil_sites()
	var beacon = exfils[0] if not exfils.is_empty() else null
	_check(beacon != null, "exfil beacon exists")
	if beacon != null:
		await _stand_near(beacon, 6.0, 0.0)
		await get_tree().create_timer(0.4).timeout
		var exfil_prompt := String(player.get_hud_snapshot().get("interact_prompt", ""))
		_check("exfil" in exfil_prompt.to_lower(), "player sees an exfil interaction prompt")
		# H is the rebindable radio-call path; it must start the hold from the pad.
		Input.action_press("call_exfil")
		for i in 3:
			await get_tree().physics_frame
		Input.action_release("call_exfil")
		await get_tree().physics_frame
		_check(RunState.extraction_state == &"holding", "H calls exfil from the pad")
		_check(deployment.get_extraction_ship() != null, "H call spawns the dropship")
		RunState.cancel_extraction()
		await get_tree().create_timer(0.25).timeout
		_check(RunState.extraction_state == &"inactive", "exfil hold can be cancelled")
		Input.action_press("interact")
		await get_tree().physics_frame
		Input.action_release("interact")
		await get_tree().physics_frame
		_check(RunState.extraction_state == &"holding", "interacting with the beacon starts the exfil hold")
		if RunState.extraction_state != &"holding":
			deployment.request_extraction(null)
	else:
		deployment.request_extraction(null)
	_check(RunState.extraction_state == &"holding", "exfil is holding before acceleration")
	_check(deployment.get_extraction_ship() != null, "calling exfil spawns the dropship")
	RunState.tick_extraction(80.0)
	await get_tree().process_frame
	_check(not result_signal.is_empty(), "run ended with result")
	_check(bool(result_signal.get("extracted", false)), "accelerated exfil extracts successfully")
	_check(int(result_signal.get("salvage", 0)) > 0, "extraction grants salvage")
	_check(not String(result_signal.get("difficulty_id", "")).is_empty(), "result carries the chosen difficulty")
	_check(String(result_signal.get("map_name", "")).length() > 0, "result carries the map name")
	_check(String(result_signal.get("mode_id", "")) == "normal", "result carries the game mode")
	_check(result_signal.has("xp_breakdown"), "result carries an XP breakdown")
	_check(result_signal.has("item_count"), "result carries recovered item count")
	await get_tree().create_timer(0.2).timeout
	_finish()


func _stand_near(target: Node3D, distance: float, angle: float = 0.0) -> void:
	var origin := target.global_position
	var stand := origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	if deployment.world != null and deployment.world.has_method("sample_height"):
		stand.y = float(deployment.world.call("sample_height", Vector2(stand.x, stand.z))) + 0.15
	player.global_position = stand
	var to_target := origin - player.global_position
	var yaw := atan2(-to_target.x, -to_target.z)
	player.rotation.y = yaw
	player.yaw = yaw
	var target_height := 1.5
	var vertical := (origin.y + target_height) - (player.global_position.y + 1.62)
	var horizontal := maxf(0.1, Vector2(to_target.x, to_target.z).length())
	player.head.rotation.x = atan2(vertical, horizontal)
	player.camera.rotation = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame



func _on_ready(p: Node) -> void:
	player = p as Player


func _on_run_ended(result: Dictionary) -> void:
	result_signal = result


func _first_enemy() -> Node:
	for node in get_tree().get_nodes_in_group("enemy_ai"):
		if node is Node3D and is_instance_valid(node):
			var h := CombatUtils.find_health(node)
			if h != null and not h.dead and h.team != StatKeys.TEAM_PLAYER:
				return node
	return null


func _finish() -> void:
	if deployment != null and is_instance_valid(deployment):
		deployment.queue_free()
	print("[TEST] Checks: %d, Failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("[TEST] RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[TEST] Failure: ", failure)
		print("[TEST] RESULT: FAIL")
		get_tree().quit(1)

