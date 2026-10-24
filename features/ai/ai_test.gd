extends SceneTree
## Headless AI acceptance test for RIFTWARD.
## Run with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path D:\godotGa\game \
##       --script res://features/ai/ai_test.gd
##
## Builds a greybox floor + a stub Player target, spawns three real EnemyAgents,
## steps physics, then exercises perception, hear_noise, damage/death, loot
## auto-collect, status effects, marked/pull and boss phases. Exits 0 on pass,
## 1 on any failed assertion so CI/console can detect regressions.

const TEAM_ENEMY: StringName = StatKeys.TEAM_ENEMY
const TEAM_PLAYER: StringName = StatKeys.TEAM_PLAYER

var _failures: Array[String] = []
var _checks: int = 0
var _built: bool = false
var _frames: int = 0
var _finished: bool = false

var _world: Node3D = null
var _player: CharacterBody3D = null
var _player_health: HealthComponent = null
var _agents: Array[EnemyAgent] = []
var _marksman: EnemyAgent = null
var _scrapper: EnemyAgent = null
var _stalker: EnemyAgent = null
var _bulwark: EnemyAgent = null
var _boss: EnemyAgent = null

var _rs: Node = null
var _cdb: Node = null
var _bus: Node = null

var _defeated_count: int = 0
var _kill_events: Array[Dictionary] = []
var _deployment_ended_count: int = 0
var _kills_before: int = 0
var _bosses_before: int = 0
var _salvage_before: int = 0
var _salvage_before_auto: int = 0
var _auto_collect_ok: bool = false
var _player_took_damage: bool = false
var _checks_run: Dictionary = {}


func _initialize() -> void:
	print("==================================================================")
	print("[AI TEST] RIFTWARD enemy agent acceptance test")
	print("==================================================================")


func _process(_delta: float) -> bool:
	if not _built:
		_build_world()
	return false


func _physics_process(_delta: float) -> bool:
	if not _built or _finished:
		return false
	_frames += 1
	_poll_player_damage()
	_run_checkpoints()
	return false


func _poll_player_damage() -> void:
	if _player_health == null or _player_took_damage:
		return
	var total := _player_health.health + _player_health.shield
	var maximum := _player_health.max_health + _player_health.max_shield
	if total < maximum - 0.01:
		_player_took_damage = true


# ---------------------------------------------------------------------------
# World construction
# ---------------------------------------------------------------------------

func _build_world() -> void:
	_built = true
	_rs = root.get_node_or_null("/root/RunState")
	_cdb = root.get_node_or_null("/root/ContentDB")
	_bus = root.get_node_or_null("/root/EventBus")
	_check(_rs != null, "RunState autoload available")
	_check(_cdb != null, "ContentDB autoload available")
	_check(_bus != null, "EventBus autoload available")
	if _rs != null:
		_kills_before = int(_rs.get("kills"))
		_bosses_before = int(_rs.get("bosses"))
		_salvage_before = int(_rs.get("satchel_salvage"))
	if _bus != null:
		_bus.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
		_bus.connect("deployment_ended", Callable(self, "_on_deployment_ended"))

	_world = Node3D.new()
	_world.name = "AITestWorld"
	root.add_child(_world)

	# Greybox floor: 80 x 80 m static body on World layer.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(floor_body)

	# A couple of cover blocks so cover/steering paths are exercised.
	_add_cover(Vector3(5.0, 1.0, -6.0), Vector3(2.0, 2.0, 2.0))
	_add_cover(Vector3(-6.0, 1.0, -4.0), Vector3(2.4, 2.0, 1.6))

	# Stub player: real CharacterBody3D + HealthComponent wired exactly like Player
	# (meta "health_component", team player, group "player"). Player itself needs a
	# full Profile/UI stack, so the sandbox scene covers the real-Player path.
	_player = CharacterBody3D.new()
	_player.name = "TestPlayer"
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player.add_to_group("player")
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.4
	player_capsule.height = 1.8
	player_shape.shape = player_capsule
	player_shape.position = Vector3(0.0, 0.9, 0.0)
	_player.add_child(player_shape)
	_player_health = HealthComponent.new()
	_player_health.name = "Health"
	_player_health.team = TEAM_PLAYER
	_player.add_child(_player_health)
	_player_health.configure(500.0, 100.0, 0.0, TEAM_PLAYER)
	_player.set_meta("health_component", _player_health)
	_player.position = Vector3(0.0, 0.0, 0.0)
	_world.add_child(_player)

	# Three real agents: ranged marksman, melee rusher, beast stalker.
	var marksman_data: EnemyData = _cdb.call("get_enemy", &"ashen_marksman")
	var scrapper_data: EnemyData = _cdb.call("get_enemy", &"ashen_scrapper")
	var stalker_data: EnemyData = _cdb.call("get_enemy", &"bloom_stalker")
	_check(marksman_data != null, "ContentDB resolves ashen_marksman")
	_check(scrapper_data != null, "ContentDB resolves ashen_scrapper")
	_check(stalker_data != null, "ContentDB resolves bloom_stalker")
	if marksman_data == null or scrapper_data == null or stalker_data == null:
		_finish()
		return

	_marksman = _spawn_agent(marksman_data, Vector3(0.0, 0.2, -14.0), 2)
	_scrapper = _spawn_agent(scrapper_data, Vector3(-5.0, 0.2, -12.0), 2)
	_stalker = _spawn_agent(stalker_data, Vector3(5.0, 0.2, -12.0), 2)
	_agents = [_marksman, _scrapper, _stalker]

	_validate_agent_contract()
	_validate_visuals()
	print("[AI TEST] world built: agents=%d frames will step to 300" % _agents.size())


func _add_cover(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_world.add_child(body)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("26383d")
	mesh.mesh.surface_get_material(0)
	mesh.material_override = mat
	body.add_child(mesh)


func _spawn_agent(data: EnemyData, spawn_position: Vector3, threat: int) -> EnemyAgent:
	var agent := EnemyAgent.new()
	agent.setup(data, threat)
	agent.position = spawn_position
	agent.rotation.y = PI  # face +Z toward the stub player at the origin
	agent.defeated.connect(_on_agent_defeated)
	_world.add_child(agent)
	return agent


# ---------------------------------------------------------------------------
# Contract checks
# ---------------------------------------------------------------------------

func _validate_agent_contract() -> void:
	for agent in _agents:
		_check(agent != null, "agent instantiated")
		if agent == null:
			continue
		_check(agent.is_in_group("enemy_ai"), "agent in group enemy_ai")
		_check(agent.collision_layer == 4, "agent collision_layer == 4 (Enemy)")
		_check(agent.collision_mask == (1 | 2), "agent collision_mask == World|Player")
		var health := agent.get_health_component()
		_check(health != null, "agent exposes HealthComponent")
		_check(agent.get_node_or_null("Health") == health, "HealthComponent is child named Health")
		_check(agent.get_meta("health_component", null) == health, "root meta health_component set")
		_check(health.team == TEAM_ENEMY, "health team is enemy")
		_check(health.max_health > 0.0, "health configured")
		var weak := agent.get_node_or_null("Weakpoint") as CollisionShape3D
		_check(weak != null, "weakpoint CollisionShape3D exists")
		if weak != null:
			_check(weak.has_meta("weakpoint_mult"), "weakpoint shape meta weakpoint_mult")
			_check(float(weak.get_meta("weakpoint_mult")) >= 1.0, "weakpoint mult valid")
		_check(agent.get_node_or_null("NavigationAgent3D") != null, "NavigationAgent3D child present")
		_check(agent.get_enemy_data() != null, "get_enemy_data() returns EnemyData")
		_check(not agent.is_boss(), "base agent is not a boss")
		var weak_mult := float(weak.get_meta("weakpoint_mult", 1.0)) if weak != null else 0.0
		_check(weak_mult == float(agent.get_enemy_data().weakpoint_mult), "weakpoint mult matches EnemyData")


func _validate_visuals() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_marksman, meshes)
	_check(meshes.size() >= 8, "marksman visual built from primitives (meshes=%d)" % meshes.size())
	var emissive_found := false
	var shadows := 0
	for mesh in meshes:
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			emissive_found = true
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows += 1
	_check(emissive_found, "enemy has emissive eye/accent material")
	_check(shadows >= 3, "enemy body casts shadows (pieces=%d)" % shadows)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		_collect_meshes(child, out)


# ---------------------------------------------------------------------------
# Checkpoints (physics frames)
# ---------------------------------------------------------------------------

func _run_checkpoints() -> void:
	if _frames == 5 and not _checks_run.has(5):
		_checks_run[5] = true
		_test_hear_noise()
	if _frames == 30 and not _checks_run.has(30):
		_checks_run[30] = true
		_debug_dump("frame 30")
		_test_projectile_pipeline()
	if _frames == 60 and not _checks_run.has(60):
		_checks_run[60] = true
		_test_projectile_result()
		_test_perception_and_movement()
	if _frames == 90 and not _checks_run.has(90):
		_checks_run[90] = true
		_debug_dump("frame 90")
	if _frames == 100 and not _checks_run.has(100):
		_checks_run[100] = true
		_test_combat_result()
	if _frames == 120 and not _checks_run.has(120):
		_checks_run[120] = true
		_test_kill_and_loot_spawn()
		_test_status_effects()
	if _frames == 126 and not _checks_run.has(126):
		_checks_run[126] = true
		_test_loot_auto_collect()
	if _frames == 140 and not _checks_run.has(140):
		_checks_run[140] = true
		_test_damage_result()
	if _frames == 145 and not _checks_run.has(145):
		_checks_run[145] = true
		_test_auto_collect_result()
	if _frames == 150 and not _checks_run.has(150):
		_checks_run[150] = true
		_test_boss_spawn_and_phase()
	if _frames == 156 and not _checks_run.has(156):
		_checks_run[156] = true
		_test_boss_phase_result()
	if _frames == 175 and not _checks_run.has(175):
		_checks_run[175] = true
		_test_elite_and_item_loot()
	if _frames == 182 and not _checks_run.has(182):
		_checks_run[182] = true
		_test_loot_interact()
	if _frames == 200 and not _checks_run.has(200):
		_checks_run[200] = true
		_test_boss_kill()
	if _frames == 250 and not _checks_run.has(250):
		_checks_run[250] = true
		_test_deployment_spawn_order_add()
	if _frames == 252 and not _checks_run.has(252):
		_checks_run[252] = true
		_test_deployment_spawn_order_setup()
	if _frames == 300:
		_final_checks()
		_finish()


func _debug_dump(tag: String) -> void:
	for agent in _agents:
		if agent == null or not is_instance_valid(agent):
			continue
		var info := agent.get_debug_info()
		print("[AI TEST] %s %s: state=%s hp=%.1f target=%d visible=%s atk=%.2f teleg=%.2f shots=%d nav=%s pos=%s" % [
			tag,
			agent.get_display_name(),
			info["state"],
			float(info["hp"]),
			int(info["target"]),
			str(info["visible"]),
			float(info["attack_timer"]),
			float(info["telegraph"]),
			int(info["shots"]),
			str(info["nav"]),
			str(info["pos"]),
		])
	print("[AI TEST] %s stub player hp=%.1f" % [tag, _player_health.health])


func _test_hear_noise() -> void:
	_check(_scrapper != null and _scrapper.is_alive(), "scrapper alive before hearing noise")
	if _scrapper == null:
		return
	var state_before := _scrapper.get_state_name()
	_scrapper.hear_noise(_scrapper.global_position + Vector3(0.0, 0.0, 4.0), 30.0)
	var state_after := _scrapper.get_state_name()
	print("[AI TEST] hear_noise: state %s -> %s" % [state_before, state_after])
	_check(state_after != "idle", "hear_noise wakes an idle enemy")


func _test_perception_and_movement() -> void:
	for agent in _agents:
		if agent == null or not agent.is_alive():
			continue
		_check(agent.get_target_node() == _player, "%s targets the player stub" % agent.get_display_name())
	var marksman_position := _marksman.global_position if _marksman != null else Vector3.ZERO
	_check(
		marksman_position.distance_to(Vector3(0.0, 0.2, -14.0)) > 0.25,
		"ranged agent repositioned under AI steering"
	)
	_check(
		marksman_position.distance_to(Vector3(0.0, 0.2, -14.0)) > 0.25,
		"ranged agent repositioned under AI steering"
	)


func _test_combat_result() -> void:
	if _marksman == null or not is_instance_valid(_marksman):
		_check(false, "marksman alive for combat result")
		return
	_check(_marksman.get_shot_count() > 0, "ranged agent fired after acquiring the player (shots=%d)" % _marksman.get_shot_count())


func _test_damage_result() -> void:
	_check(_player_took_damage, "stub player took damage from enemy attacks (hp=%.1f shield=%.1f)" % [
		_player_health.health, _player_health.shield
	])


func _test_projectile_pipeline() -> void:
	# Standalone target off to the side so AI damage assertions stay meaningful.
	_dummy = CharacterBody3D.new()
	_dummy.name = "ProjectileDummy"
	_dummy.collision_layer = 2
	_dummy.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	_dummy.add_child(shape)
	_dummy_health = HealthComponent.new()
	_dummy_health.name = "Health"
	_dummy_health.team = TEAM_PLAYER
	_dummy.add_child(_dummy_health)
	_dummy_health.configure(200.0, 0.0, 0.0, TEAM_PLAYER)
	_dummy.set_meta("health_component", _dummy_health)
	_dummy.position = Vector3(14.0, 0.0, 6.0)
	_world.add_child(_dummy)
	var bolt := EnemyProjectile.spawn(
		_world,
		Vector3(14.0, 1.1, 13.0),
		Vector3(0.0, 0.0, -1.0),
		26.0,
		25.0,
		null,
		Color("ffb866")
	)
	_check(bolt != null, "EnemyProjectile.spawn creates a bolt")


func _test_projectile_result() -> void:
	if _dummy_health == null:
		return
	_check(_dummy_health.health < 200.0, "enemy bolt damaged a player-team target (hp=%.1f)" % _dummy_health.health)


var _dummy: CharacterBody3D = null
var _dummy_health: HealthComponent = null


func _test_kill_and_loot_spawn() -> void:
	_check(_scrapper != null and _scrapper.is_alive(), "scrapper alive before simulated player hit")
	if _scrapper == null:
		return
	# Simulate a player weapon kill straight through the shared hit pipeline.
	var data := DamageData.make(99999.0, TEAM_PLAYER, StatKeys.DMG_BALLISTIC, _player)
	data.hit_position = _scrapper.global_position + Vector3.UP
	var result := CombatUtils.apply_hit(_scrapper, data)
	var applied: bool = result.get("applied", false)
	var killed: bool = result.get("killed", false)
	_check(applied, "CombatUtils.apply_hit lands on enemy")
	_check(killed, "CombatUtils.apply_hit reports kill")
	_check(_defeated_count == 1, "defeated signal emitted once (got %d)" % _defeated_count)
	_check(_kill_events.size() == 1, "EventBus.enemy_killed emitted")
	if _kill_events.size() == 1:
		var event_is_boss: bool = _kill_events[0].get("is_boss", true)
		_check(not event_is_boss, "kill event is_boss=false for base enemy")
	_check(int(_rs.get("kills")) == _kills_before + 1, "RunState.record_kill incremented kills")
	var drops := _find_loot_drops()
	_check(drops.size() >= 1, "death spawned a loot drop (count=%d)" % drops.size())
	_check(_scrapper.get_loot_dropped_count() == 1, "enemy loot counter is 1")
	_check(_scrapper.get_health_component().dead, "enemy health reports dead")
	_check(_scrapper.get_state_name() == "dead", "enemy FSM state is dead")


func _test_status_effects() -> void:
	# Bulwark has innate armor, which lets the corrode status be verified.
	var bulwark_data: EnemyData = _cdb.call("get_enemy", &"ashen_bulwark")
	if bulwark_data == null:
		_check(false, "ContentDB resolves ashen_bulwark")
		return
	_bulwark = _spawn_agent(bulwark_data, Vector3(10.0, 0.2, -6.0), 2)
	if _bulwark == null:
		_check(false, "bulwark spawned for status test")
		return
	var health := _bulwark.get_health_component()
	var armor_before := health.armor
	_check(armor_before > 0.0, "bulwark starts with armor (%.1f)" % armor_before)
	# Corrode reduces armor.
	var corrode := DamageData.make(5.0, TEAM_PLAYER, StatKeys.DMG_CORROSIVE, _player)
	corrode.status_type = StatKeys.STATUS_CORRODE
	corrode.status_power = 1.0
	corrode.status_duration = 3.0
	health.take_damage(corrode)
	_check(health.armor < armor_before, "corrode reduced enemy armor (%.1f -> %.1f)" % [armor_before, health.armor])
	# Burn applies damage over time.
	var burn := DamageData.make(1.0, TEAM_PLAYER, StatKeys.DMG_BURN, _player)
	burn.status_type = StatKeys.STATUS_BURN
	burn.status_power = 2.0
	burn.status_duration = 3.0
	health.take_damage(burn)
	# Shock should interrupt movement/attack momentarily.
	var shock := DamageData.make(1.0, TEAM_PLAYER, StatKeys.DMG_SHOCK, _player)
	shock.status_type = StatKeys.STATUS_SHOCK
	shock.status_power = 1.0
	shock.status_duration = 1.2
	health.take_damage(shock)
	# Slow.
	var slow := DamageData.make(1.0, TEAM_PLAYER, StatKeys.DMG_ENERGY, _player)
	slow.status_type = StatKeys.STATUS_SLOW
	slow.status_power = 1.0
	slow.status_duration = 2.0
	health.take_damage(slow)
	# Marked + pull are called by player abilities through the enemy_ai group.
	_bulwark.set_marked(4.0)
	_check(_bulwark.get_marked_remaining() > 0.0, "set_marked marks the agent")
	_bulwark.apply_pull(_bulwark.global_position + Vector3(3.0, 0.0, 0.0), 5.0, 0.5)
	print("[AI TEST] statuses applied: armor=%.1f hp=%.1f marked=%.1f" % [
		health.armor, health.health, _bulwark.get_marked_remaining()
	])
	_check(health.health <= health.max_health, "status damage stays within bounds")
	# Group-call entry points used by abilities (scan/pull/slam) must not error.
	_bulwark.hear_noise(_bulwark.global_position + Vector3(0.0, 0.0, 2.0), 20.0)


func _test_loot_auto_collect() -> void:
	if _rs == null:
		return
	_salvage_before_auto = int(_rs.get("satchel_salvage"))
	var payload := {
		"salvage": 7,
		"cores": 0,
		"item": {},
		"rarity": 1,
		"label": "Test Cache",
		"prompt": "Collect Test Cache  [E]",
	}
	var drop := EnemyLootDrop.spawn(_world, _player.global_position + Vector3(0.9, 0.05, 0.0), payload)
	_check(drop != null, "EnemyLootDrop.spawn creates a pickup")
	if drop == null:
		return
	_check(drop.is_in_group("interactable"), "loot drop is interactable for the E prompt")
	_check(drop.get_interact_prompt().length() > 0, "loot drop exposes get_interact_prompt()")
	_auto_drop = drop


var _auto_drop: EnemyLootDrop = null


func _test_auto_collect_result() -> void:
	var salvage_after := int(_rs.get("satchel_salvage"))
	_auto_collect_ok = salvage_after >= _salvage_before_auto + 7
	_check(_auto_collect_ok, "loot auto-collect awarded satchel salvage (%d -> %d)" % [
		_salvage_before_auto, salvage_after
	])
	_check(_auto_drop == null or not is_instance_valid(_auto_drop) or _auto_drop.is_collected(), "loot drop consumed")


func _on_agent_defeated(enemy: EnemyAgent) -> void:
	_defeated_count += 1
	print("[AI TEST] defeated signal: %s" % enemy.get_display_name())


func _on_enemy_killed(enemy_name: String, position: Vector3, is_boss: bool) -> void:
	_kill_events.append({"name": enemy_name, "position": position, "is_boss": is_boss})
	print("[AI TEST] enemy_killed: %s boss=%s pos=%s" % [enemy_name, str(is_boss), str(position)])


func _on_deployment_ended(_result: Dictionary) -> void:
	_deployment_ended_count += 1
	push_error("[AI TEST] FAIL: enemy death ended the deployment!")


func _test_elite_and_item_loot() -> void:
	var elite_data: EnemyData = _cdb.call("get_enemy", &"ash_reaver")
	_check(elite_data != null, "ContentDB resolves elite ash_reaver")
	if elite_data == null:
		return
	_elite = _spawn_agent(elite_data, Vector3(14.0, 0.2, -12.0), 3)
	_check(_elite != null, "elite agent spawned")
	if _elite == null:
		return
	_check(_elite.is_in_group("enemy_elite"), "elite added to group enemy_elite")
	var affix := _elite.get_elite_affix()
	_check(affix != &"", "elite rolled an affix (%s)" % String(affix))
	_check(
		affix in [EnemyAgent.AFFIX_ARMORED, EnemyAgent.AFFIX_SHIELDED, EnemyAgent.AFFIX_BERSERK, EnemyAgent.AFFIX_VOLATILE],
		"elite affix is a known modifier"
	)
	var health := _elite.get_health_component()
	_check(health.max_health > elite_data.max_health, "elite stats scaled beyond base data")
	var kill := DamageData.make(99999.0, TEAM_PLAYER, StatKeys.DMG_BALLISTIC, _player)
	kill.hit_position = _elite.global_position + Vector3.UP
	health.take_damage(kill)
	_check(not _elite.is_alive(), "elite died")
	var elite_drop: EnemyLootDrop = null
	for drop in _find_loot_drops():
		if not drop.is_collected():
			elite_drop = drop
	_check(elite_drop != null, "elite spawned a loot drop")
	if elite_drop == null:
		return
	_elite_drop = elite_drop
	var payload := elite_drop.get_payload()
	var item: Dictionary = payload.get("item", {})
	_check(not item.is_empty(), "elite loot guaranteed a generated item")
	_check(int(payload.get("rarity", 0)) >= 2, "elite item rarity is at least Rare (got %d)" % int(payload.get("rarity", 0)))
	if not item.is_empty():
		_check(String(item.get("base_id", "")).length() > 0, "generated item has a base id")
		_check(int(item.get("level", 0)) >= 1, "generated item has a level")


var _elite: EnemyAgent = null
var _elite_drop: EnemyLootDrop = null
var _salvage_before_interact: int = 0
var _late_agent: EnemyAgent = null


func _test_deployment_spawn_order_add() -> void:
	# Mirrors features/run/deployment.gd: instantiate -> add_child -> position ->
	# setup(data, threat) one or more frames later, then connect defeated.
	_late_agent = EnemyAgent.new()
	_late_agent.name = "LateConfigured"
	_late_agent.position = Vector3(-16.0, 0.25, -14.0)
	_world.add_child(_late_agent)
	_check(is_instance_valid(_late_agent), "deployment-order agent added before setup")


func _test_deployment_spawn_order_setup() -> void:
	if _late_agent == null or not is_instance_valid(_late_agent):
		_check(false, "deployment-order agent alive before setup")
		return
	var data: EnemyData = _cdb.call("get_enemy", &"bloom_matriarch")
	_check(data != null, "ContentDB resolves bloom_matriarch")
	if data == null:
		return
	_late_agent.global_position = Vector3(-16.0, 0.3, -14.0)
	_late_agent.setup(data, 3)
	_check(_late_agent.get_enemy_data() == data, "setup() after add_child swaps in requested archetype")
	_check(_late_agent.get_display_name() == "Bloom Matriarch", "rebuild applied display name")
	_check(_late_agent.get_threat() == 3, "rebuild applied threat level")
	_check(_late_agent.is_in_group("enemy_elite"), "rebuild registered elite group")
	_check(_late_agent.get_elite_affix() != &"", "rebuild rolled elite affix")
	var health := _late_agent.get_health_component()
	_check(health != null and health.team == TEAM_ENEMY, "rebuild replaced health component")
	_check(health.max_health > data.max_health, "rebuild applied threat health scaling")
	var weak := _late_agent.get_node_or_null("Weakpoint") as CollisionShape3D
	_check(weak != null and weak.has_meta("weakpoint_mult"), "rebuild recreated weakpoint shape")
	_late_agent.queue_free()
	_check(_deployment_ended_count == 0, "setup/rebuild does not end deployment")


func _test_loot_interact() -> void:
	if _elite_drop == null or not is_instance_valid(_elite_drop):
		_check(false, "elite loot drop available for E interact")
		return
	_salvage_before_interact = int(_rs.get("satchel_salvage"))
	_check(_elite_drop.get_interact_prompt().length() > 0, "elite drop exposes interact prompt")
	_elite_drop.interact(_player)
	_check(_elite_drop.is_collected(), "interact() collects the loot drop")
	var salvage_after := int(_rs.get("satchel_salvage"))
	_check(salvage_after > _salvage_before_interact, "interact() awarded satchel value (%d -> %d)" % [
		_salvage_before_interact, salvage_after
	])


func _find_loot_drops() -> Array[EnemyLootDrop]:
	var out: Array[EnemyLootDrop] = []
	for child in _world.get_children():
		if child is EnemyLootDrop:
			out.append(child as EnemyLootDrop)
	return out


func _test_boss_spawn_and_phase() -> void:
	var warden_data: EnemyData = _cdb.call("get_enemy", &"the_warden")
	_check(warden_data != null, "ContentDB resolves the_warden")
	if warden_data == null:
		return
	_boss = _spawn_agent(warden_data, Vector3(0.0, 0.2, -30.0), 2)
	_check(_boss != null and _boss.is_boss(), "boss agent reports is_boss()")
	_check(_boss.is_in_group("enemy_boss"), "boss added to group enemy_boss")
	_check(_boss.get_boss_phase() == 1, "boss starts in phase 1")
	_check(_boss.get_health_component().armor >= 35.0, "boss has authored armor")
	var health := _boss.get_health_component()
	var heavy_hit := DamageData.make(3000.0, TEAM_PLAYER, StatKeys.DMG_BALLISTIC, _player)
	heavy_hit.hit_position = _boss.global_position + Vector3.UP
	health.take_damage(heavy_hit)
	print("[AI TEST] boss after heavy hit: hp=%.1f/%.1f phase=%d" % [
		health.health, health.max_health, _boss.get_boss_phase()
	])


func _test_boss_phase_result() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_check(false, "boss alive for phase result check")
		return
	_check(_boss.get_boss_phase() >= 2, "boss phase advances past 50%% health (phase=%d)" % _boss.get_boss_phase())


func _test_boss_kill() -> void:
	if _boss == null or not is_instance_valid(_boss):
		_check(false, "boss alive for kill test")
		return
	var health := _boss.get_health_component()
	var final_hit := DamageData.make(999999.0, TEAM_PLAYER, StatKeys.DMG_BALLISTIC, _player)
	final_hit.hit_position = _boss.global_position + Vector3.UP
	health.take_damage(final_hit)
	_check(int(_rs.get("bosses")) == _bosses_before + 1, "RunState.record_kill counted the boss")
	_check(_kill_events.size() >= 3, "boss kill event emitted")
	var boss_event_found := false
	for event in _kill_events:
		var is_boss_event: bool = event.get("is_boss", false)
		if is_boss_event:
			boss_event_found = true
	_check(boss_event_found, "boss kill event flags is_boss=true")
	var boss_drops := 0
	for drop in _find_loot_drops():
		var is_boss_drop: bool = drop.get_payload().get("boss", false)
		if is_boss_drop:
			boss_drops += 1
	_check(boss_drops >= 1, "boss dropped loot")


func _final_checks() -> void:
	# Scrapper should have been freed by the death timer.
	_check(not is_instance_valid(_scrapper), "dead enemy queue_free'd after death delay")
	_check(_marksman != null and _marksman.is_alive(), "marksman survived the sim")
	_check(_player_took_damage, "stub player took sustained damage")
	_check(_auto_collect_ok, "loot auto-collect verified")
	# No-navmesh fallback must have been exercised at least once.
	var fallback_seen := false
	for agent in _agents:
		if agent != null and is_instance_valid(agent) and not agent.uses_navigation():
			fallback_seen = true
	_check(fallback_seen, "direct-steering fallback used without a navmesh")
	# Boss should be freed too.
	_check(not is_instance_valid(_boss), "boss freed after death delay")
	_check(_agents.size() == 3, "harness spawned exactly 3 base agents")
	_check(_deployment_ended_count == 0, "enemy deaths never end the deployment")
	# Freed objects compare == null in Godot 4, so use validity directly here.
	_check(not is_instance_valid(_elite), "elite cleaned up after death")
	if is_instance_valid(_elite):
		print("[AI TEST] elite still alive: state=%s dead_var=%s grave=%.2f inside=%s" % [
			_elite.get_state_name(), str(_elite._dead), float(_elite._grave_time), str(_elite.is_inside_tree())
		])
	_check(_kill_events.size() >= 3, "kill events emitted for base, elite and boss")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var exit_code := 0 if _failures.is_empty() else 1
	print("------------------------------------------------------------------")
	print("[AI TEST] checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("[AI TEST]   FAILED: " + failure)
	print("[AI TEST] RESULT: " + ("PASS" if exit_code == 0 else "FAIL"))
	print("------------------------------------------------------------------")
	quit(exit_code)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("[AI TEST] FAIL: " + message)
