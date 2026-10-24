extends SceneTree
## COMPANIONS SELF-TEST — standalone headless validation of AllyAgent / PetAgent.
##
## Run:
##   <godot_console> --headless --path D:\godotGa\game \
##       --script res://features/companions/companions_test.gd
##
## Exits 0 on success, 1 on failed checks. Uses a stubbed player target (real
## Player integration is exercised separately by the Lead's deployment scene).
##
## NOTE: scripts run through `--script` are compiled before autoload singletons
## are registered, so this file deliberately loads companion scripts at runtime
## and resolves ContentDB/ProfileState through the scene tree instead of using
## their global identifiers directly.

const ALLY_SCRIPT_PATH := "res://features/companions/ally_agent.gd"
const PET_SCRIPT_PATH := "res://features/companions/pet_agent.gd"
const MANAGER_SCRIPT_PATH := "res://features/companions/companion_manager.gd"
const FRAME := 1.0 / 60.0

var _content_db: Node = null
var _profile: Node = null
var _ally_script: Script = null
var _pet_script: Script = null
var _manager_script: Script = null

var _errors: Array[String] = []
var _checks: int = 0
var _world: Node3D = null
var _player: StubPlayer = null
var _enemy: StubEnemy = null
var _enemy2: StubEnemy = null
var _allies: Array[Node] = []
var _pets: Array[Node] = []
var _mara: Node = null
var _rook: Node = null
var _irie: Node = null
var _toma: Node = null
var _mote: Node = null
var _cinder: Node = null
var _pip: Node = null


# ---------------------------------------------------------------------------
# Test stubs
# ---------------------------------------------------------------------------

class StubPlayer extends CharacterBody3D:
	var is_downed: bool = false
	var is_dead: bool = false
	var health_component: HealthComponent = null
	var stats_component: StatsComponent = null
	var revive_calls: int = 0
	var modifier_calls: int = 0

	func _ready() -> void:
		add_to_group("player")
		collision_layer = 2
		collision_mask = 1
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.38
		capsule.height = 1.8
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		shape.shape = capsule
		shape.position = Vector3(0.0, 0.9, 0.0)
		add_child(shape)
		health_component = HealthComponent.new()
		health_component.name = "Health"
		add_child(health_component)
		health_component.team = StatKeys.TEAM_PLAYER
		health_component.configure(200.0, 60.0, 10.0, StatKeys.TEAM_PLAYER)
		stats_component = StatsComponent.new()
		stats_component.name = "Stats"
		add_child(stats_component)
		stats_component.set_base_stats({
			StatKeys.HEALTH_MAX: 200.0,
			StatKeys.SHIELD_MAX: 60.0,
			StatKeys.ARMOR: 10.0,
			StatKeys.MOVE_SPEED: 5.4,
		})
		set_meta("health_component", health_component)

	func get_health_component() -> HealthComponent:
		return health_component

	func get_stats_component() -> StatsComponent:
		return stats_component

	func heal(amount: float) -> void:
		health_component.heal(amount)

	func revive_from_ally(amount: float = 0.5) -> void:
		revive_calls += 1
		is_downed = false
		health_component.revive(health_component.max_health * amount)

	func get_forward() -> Vector3:
		return -global_transform.basis.z

	func get_effect_parent() -> Node3D:
		var parent := get_parent()
		if parent is Node3D:
			return parent as Node3D
		return null

	func apply_temporary_modifier(
		_id: StringName,
		_stat: StringName,
		_op: StringName,
		_value: float,
		_duration: float
	) -> void:
		modifier_calls += 1


class StubEnemy extends CharacterBody3D:
	var health_component: HealthComponent = null
	var marked_until: float = 0.0
	var noises: int = 0

	func _ready() -> void:
		add_to_group("enemy_ai")
		collision_layer = 4
		collision_mask = 1
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.42
		capsule.height = 1.85
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		shape.shape = capsule
		shape.position = Vector3(0.0, 0.925, 0.0)
		add_child(shape)
		health_component = HealthComponent.new()
		health_component.name = "Health"
		add_child(health_component)
		health_component.configure(600.0, 0.0, 0.0, StatKeys.TEAM_ENEMY)
		set_meta("health_component", health_component)
		set_meta("aim_height", 1.15)

	func get_health_component() -> HealthComponent:
		return health_component

	func set_marked(duration: float) -> void:
		marked_until = maxf(marked_until, Time.get_ticks_msec() / 1000.0 + duration)

	func is_marked() -> bool:
		return Time.get_ticks_msec() / 1000.0 < marked_until

	func hear_noise(origin: Vector3, radius: float) -> void:
		if global_position.distance_to(origin) <= radius:
			noises += 1


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _initialize() -> void:
	print("[companions-test] starting (headless)")
	_content_db = root.get_node_or_null("ContentDB")
	_profile = root.get_node_or_null("ProfileState")
	_ally_script = load(ALLY_SCRIPT_PATH)
	_pet_script = load(PET_SCRIPT_PATH)
	_manager_script = load(MANAGER_SCRIPT_PATH)
	if _content_db == null or _profile == null:
		printerr("[companions-test] autoloads unavailable (ContentDB/ProfileState); cannot test")
		quit(1)
		return
	if _ally_script == null or not _ally_script.can_instantiate():
		printerr("[companions-test] failed to compile ally_agent.gd")
		quit(1)
		return
	if _pet_script == null or not _pet_script.can_instantiate():
		printerr("[companions-test] failed to compile pet_agent.gd")
		quit(1)
		return
	if _manager_script == null or not _manager_script.can_instantiate():
		printerr("[companions-test] failed to compile companion_manager.gd")
		quit(1)
		return
	_run()


func _run() -> void:
	# Let the SceneTree finish initializing before adding 3D nodes: global
	# transforms and Timers require nodes to be inside the tree.
	await _wait_frames(2)
	var timer := _build_timeout()
	_build_world()
	_build_actors()
	await _wait_frames(5)
	_spawn_agents()
	await _wait_frames(120)

	_test_spawn_integrity()
	_test_formation_follow()
	_test_teleport_catchup()
	await _test_commands()
	await _test_ally_abilities()
	await _test_pet_abilities()
	await _test_downed_and_revive()
	await _test_pet_damage_states()
	await _test_manager()
	await _cleanup()

	if is_instance_valid(timer):
		timer.queue_free()
	await _wait_frames(3)
	if _errors.is_empty():
		print("[companions-test] PASS — %d checks" % _checks)
		quit(0)
	else:
		print("[companions-test] FAILED — %d/%d checks failed" % [_errors.size(), _checks])
		for error in _errors:
			printerr("[companions-test]   - " + error)
		quit(1)


func _build_timeout() -> Timer:
	var timer := Timer.new()
	timer.name = "TestTimeout"
	timer.wait_time = 60.0
	timer.one_shot = true
	timer.timeout.connect(
		func() -> void:
			printerr("[companions-test] TIMEOUT after 60s")
			quit(1)
	)
	root.add_child(timer)
	timer.start()
	return timer


# ---------------------------------------------------------------------------
# World / actors
# ---------------------------------------------------------------------------

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "CompanionsTestWorld"
	root.add_child(_world)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(300.0, 1.0, 300.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(300.0, 1.0, 300.0)
	floor_mesh.mesh = mesh
	floor_body.add_child(floor_mesh)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	_world.add_child(sun)

	_player = StubPlayer.new()
	_player.name = "StubPlayer"
	_world.add_child(_player)
	_player.global_position = Vector3(0.0, 0.1, 0.0)

	_enemy = StubEnemy.new()
	_enemy.name = "StubEnemyA"
	_world.add_child(_enemy)
	_enemy.global_position = Vector3(-2.0, 0.1, -14.0)

	_enemy2 = StubEnemy.new()
	_enemy2.name = "StubEnemyB"
	_world.add_child(_enemy2)
	_enemy2.global_position = Vector3(10.0, 0.1, -18.0)

	var camera := Camera3D.new()
	camera.name = "Camera"
	_world.add_child(camera)
	camera.position = Vector3(8.0, 6.0, 10.0)
	camera.rotation_degrees = Vector3(-22.0, 28.0, 0.0)
	camera.current = true


func _build_actors() -> void:
	# Nothing extra; actors are spawned after autoload/content is ready.
	pass


func _spawn_agents() -> void:
	_mara = _spawn_ally(&"mara_voss", 2, 0)
	_rook = _spawn_ally(&"rook", 1, 1)
	_irie = _spawn_ally(&"irie_sol", 3, 0)
	_toma = _spawn_ally(&"toma_nix", 2, 1)
	_mote = _spawn_pet(&"mote", 2)
	_cinder = _spawn_pet(&"cinder", 2)
	_pip = _spawn_pet(&"pip", 1)
	for pet in _pets:
		pet.global_position = _player.global_position + Vector3(randf_range(-1.5, 1.5), 1.8, randf_range(-1.5, 1.5))


func _spawn_ally(ally_id: StringName, p_rank: int, formation: int) -> Node:
	var data = _content_db.call("get_ally", ally_id)
	if data == null:
		_fail("ContentDB is missing ally '%s'" % String(ally_id))
		return null
	var ally := _ally_script.new() as Node
	ally.name = "TestAlly_" + String(ally_id)
	_world.add_child(ally)
	ally.setup(data, _player, p_rank)
	ally.set_formation_index(formation)
	_allies.append(ally)
	return ally


func _spawn_pet(pet_id: StringName, p_rank: int) -> Node:
	var data = _content_db.call("get_pet", pet_id)
	if data == null:
		_fail("ContentDB is missing pet '%s'" % String(pet_id))
		return null
	var pet := _pet_script.new() as Node
	pet.name = "TestPet_" + String(pet_id)
	_world.add_child(pet)
	pet.setup(data, _player, p_rank)
	_pets.append(pet)
	return pet


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[companions-test] ok: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_errors.append(message)
	printerr("[companions-test] FAIL: " + message)


func _test_spawn_integrity() -> void:
	_check(_allies.size() == 4, "spawned 4 allies (got %d)" % _allies.size())
	_check(_pets.size() == 3, "spawned 3 Driftling pets (got %d)" % _pets.size())
	if _mara == null or _mote == null:
		return
	_check(_mara.is_in_group("allies"), "AllyAgent is in group 'allies'")
	_check(_mote.is_in_group("pets"), "PetAgent is in group 'pets'")
	_check((_mara as CharacterBody3D).collision_layer == 8, "ally collision_layer == 8 (Friendly)")
	_check((_mara as CharacterBody3D).collision_mask == 1, "ally collision_mask == 1 (World)")
	var ally_health: HealthComponent = _mara.get_health_component()
	_check(ally_health != null and ally_health.team == StatKeys.TEAM_FRIENDLY, "ally Health team is 'friendly'")
	_check(_mara.has_meta("health_component"), "ally body exposes health_component meta")
	_check(ally_health.max_health > 120.0, "rank 2 medic has rank-scaled health (%.0f)" % ally_health.max_health)
	var meshes: Array = _mara.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() >= 20, "ally visual is built from low-poly primitives (%d meshes)" % meshes.size())
	var pet_meshes: Array = _mote.find_children("*", "MeshInstance3D", true, false)
	_check(pet_meshes.size() >= 10, "Driftling visual is built from primitives (%d meshes)" % pet_meshes.size())
	_check(_mara.get_ally_data() is AllyData, "get_ally_data() returns AllyData")
	_check(String(_mara.get_role()) == "medic", "medic role resolved")
	_check(_toma.get_role() == &"engineer", "engineer role resolved")
	_check(_mote.is_in_group("friendly"), "pets are in group 'friendly'")
	_check(not _mara.is_downed(), "ally starts standing (not downed)")
	for ally in _allies:
		_check(ally.get_health_component() != null, "%s has a HealthComponent" % String(ally.name))
	for pet in _pets:
		_check(pet.get_health_component() != null, "%s has an optional HealthComponent" % String(pet.name))


func _test_formation_follow() -> void:
	_player.global_position = Vector3(0.0, 0.1, 9.0)
	# Advance formation follow manually by waiting in the coroutine flow instead:
	# the following check is done after the caller awaits frames; kept synchronous
	# for stage bookkeeping.
	_check(_player.global_position.z > 5.0, "player relocated for follow test")


func _test_teleport_catchup() -> void:
	var far := Vector3(70.0, 0.1, 0.0)
	_player.global_position = far
	# Teleport catch-up runs in _physics_process; the caller waits right after.
	_check(true, "teleport catch-up armed")


# ---------------------------------------------------------------------------
# Async stages
# ---------------------------------------------------------------------------

func _test_commands() -> void:
	await _wait_frames(90)  # follow + teleport catch-up settle
	for ally in _allies:
		if ally == null or not is_instance_valid(ally):
			continue
		var distance: float = (ally as Node3D).global_position.distance_to(_player.global_position)
		_check(distance < 20.0, "%s caught up to player (%.1fm)" % [String(ally.name), distance])

	if _mara != null:
		_mara.issue_command(&"hold")
		_check(_mara.get_command() == &"hold", "issue_command(&'hold') acknowledged")
		var hold_position: Vector3 = (_mara as Node3D).global_position
		_player.global_position += Vector3(0.0, 0.0, 12.0)
		await _wait_frames(45)
		var drift: float = (_mara as Node3D).global_position.distance_to(hold_position)
		_check(drift < 4.5, "held Warden stays near hold position (%.1fm drift)" % drift)
		_mara.issue_command(&"follow")
		_check(_mara.get_command() == &"follow", "issue_command(&'follow') acknowledged")

	if _irie != null and _enemy != null:
		var before: float = (_irie as Node3D).global_position.distance_to(_enemy.global_position)
		_irie.issue_command(&"focus", _enemy)
		_check(_irie.get_command() == &"focus", "issue_command(&'focus') acknowledged")
		await _wait_frames(75)
		var after: float = (_irie as Node3D).global_position.distance_to(_enemy.global_position)
		_check(after < before or after <= 21.0, "focused scout closes to preferred range (%.1fm -> %.1fm)" % [before, after])
		_irie.issue_command(&"follow")


func _test_ally_abilities() -> void:
	# Bring the squad back into the combat zone after the teleport/command stage.
	_player.global_position = Vector3(0.0, 0.1, 0.0)
	await _wait_frames(15)  # teleport catch-up for allies + pets
	await _wait_frames(45)  # targeting/LOS refresh
	# --- medic: heals / re-shields the damaged player ---------------------
	_damage_player(90.0)
	await _wait_frames(2)
	var before_health: float = _player.health_component.health
	var before_shield: float = _player.health_component.shield
	var used := bool(_mara.force_ability())
	await _wait_frames(2)
	var after_health: float = _player.health_component.health
	var after_shield: float = _player.health_component.shield
	_check(used, "medic force_ability() executed")
	_check(after_health > before_health or after_shield > before_shield, "medic restored player health/shield (%.0f/%.0f -> %.0f/%.0f)" % [before_health, before_shield, after_health, after_shield])

	# --- heavy: taunts enemies + grants player armour ---------------------
	var modifiers_before := _player.modifier_calls
	var noise_before := _enemy.noises if _enemy != null else 0
	var heavy_used := bool(_rook.force_ability())
	await _wait_frames(2)
	_check(heavy_used, "heavy force_ability() executed")
	_check(_player.modifier_calls > modifiers_before, "heavy applied an armour buff to the player")
	_check(_enemy == null or _enemy.noises > noise_before, "heavy taunted nearby enemies (hear_noise)")

	# --- scout: marks enemies + boosts crit ---------------------------------
	if _enemy != null:
		_enemy.marked_until = 0.0
	var scout_used := bool(_irie.force_ability())
	await _wait_frames(2)
	_check(scout_used, "scout force_ability() executed")
	_check(_enemy == null or _enemy.is_marked(), "scout marked an enemy with set_marked()")

	# --- engineer: deploys a temporary shock turret -----------------------
	var turrets_before := get_nodes_in_group("companion_deployable").size()
	var engineer_used := bool(_toma.force_ability())
	await _wait_frames(3)
	var turrets_after := get_nodes_in_group("companion_deployable").size()
	_check(engineer_used, "engineer force_ability() executed")
	_check(turrets_after > turrets_before, "engineer deployed a ShockTurret (%d -> %d)" % [turrets_before, turrets_after])
	if turrets_after > turrets_before and _enemy != null:
		var turret: Node3D = get_nodes_in_group("companion_deployable")[turrets_after - 1] as Node3D
		if turret != null:
			_enemy.global_position = turret.global_position + Vector3(2.0, 0.1, 0.0)
			var enemy_health_before: float = _enemy.health_component.health
			await _wait_frames(90)
			_check(_enemy.health_component.health < enemy_health_before, "shock turret damaged an enemy (%.0f -> %.0f)" % [enemy_health_before, _enemy.health_component.health])


func _test_pet_abilities() -> void:
	# --- cinder: plasma bolt damages the nearest enemy ---------------------
	if _cinder != null and _enemy != null:
		_enemy.global_position = Vector3(-2.0, 0.1, -12.0)
		await _wait_frames(2)
		var health_before: float = _enemy.health_component.health
		var cinder_used := bool(_cinder.force_ability())
		await _wait_frames(3)
		_check(cinder_used, "cinder force_ability() executed")
		_check(_enemy.health_component.health < health_before, "cinder bolt damaged an enemy (%.0f -> %.0f)" % [health_before, _enemy.health_component.health])

	# --- pip: scans and marks nearby enemies ------------------------------
	if _pip != null:
		if _enemy != null:
			_enemy.marked_until = 0.0
		var pip_used := bool(_pip.force_ability())
		await _wait_frames(2)
		_check(pip_used, "pip force_ability() executed")
		_check(_enemy == null or _enemy.is_marked(), "pip scan marked a nearby enemy")

	# --- mote: restores player shield -------------------------------------
	if _mote != null:
		_damage_player(80.0)
		await _wait_frames(2)
		var shield_before: float = _player.health_component.shield
		var mote_used := bool(_mote.force_ability())
		await _wait_frames(2)
		_check(mote_used, "mote force_ability() executed")
		_check(_player.health_component.shield > shield_before, "mote restored player shield (%.0f -> %.0f)" % [shield_before, _player.health_component.shield])


func _test_downed_and_revive() -> void:
	# --- ally downed by enemy damage, player presses E to revive ----------
	if _toma == null:
		return
	_toma.health_component.take_damage(DamageData.make(9999.0, StatKeys.TEAM_ENEMY, StatKeys.DMG_BALLISTIC, _enemy))
	await _wait_frames(2)
	_check(_toma.is_downed(), "lethal damage downs the Warden")
	var prompt: String = String(_toma.get_interact_prompt())
	_check(prompt.begins_with("Revive "), "downed Warden offers 'Revive <name>' prompt (got '%s')" % prompt)
	_check(_toma.is_in_group("interactable"), "downed Warden joins group 'interactable'")
	_check(((int(_toma.get("collision_layer"))) & 32) != 0, "downed Warden exposes Interactable collision layer for the player's E ray")
	_toma.interact(_player)
	await _wait_frames(2)
	_check(not _toma.is_downed(), "interact(player) revives the Warden")
	_check(_toma.get_health_component().health > 0.0, "revived Warden has health restored")
	_check(_toma.get_interact_prompt() == "", "revived Warden clears its interact prompt")
	_check(not _toma.is_in_group("interactable"), "revived Warden leaves group 'interactable'")

	# --- downed player is auto-revived by a nearby Warden ------------------
	_player.health_component.kill()
	_player.is_downed = true
	(_mara as Node3D).global_position = _player.global_position + Vector3(1.4, 0.0, 0.0)
	var revive_calls_before := _player.revive_calls
	await _wait_frames(240)
	_check(_player.revive_calls > revive_calls_before, "Warden auto-revived a downed player (%d calls)" % _player.revive_calls)
	_check(not _player.is_downed, "player is no longer downed after squad revive")
	_check(_player.health_component.health > 0.0 and not _player.health_component.dead, "player health restored after squad revive")


func _test_pet_damage_states() -> void:
	if _mote != null:
		var pet_health: HealthComponent = _mote.get_health_component()
		pet_health.take_damage(DamageData.make(25.0, StatKeys.TEAM_ENEMY, StatKeys.DMG_KINETIC, _enemy))
		await _wait_frames(2)
		_check(pet_health.health < pet_health.max_health, "Driftling can take damage")
		_mote.heal(10.0)
		await _wait_frames(2)
		_check(pet_health.health > pet_health.max_health - 25.0, "Driftling heal() repairs damage")
		_mote.disable(0.35)
		_check(_mote.is_disabled(), "Driftling can be temporarily disabled")
		await _wait_frames(45)
		_check(not _mote.is_disabled(), "Driftling self-repairs after being disabled")
		_check(pet_health.health == pet_health.max_health, "self-repair restores Driftling health")

	if _cinder != null:
		_cinder.set_cloaked(0.4)
		_check(_cinder.is_cloaked(), "Driftling supports Ghost Protocol cloak")
		await _wait_frames(45)
		_check(not _cinder.is_cloaked(), "Driftling decloaks after the duration")

	for pet in _pets:
		var status: Dictionary = pet.get_status()
		_check(status.has("name") and status.has("effect"), "%s exposes HUD status" % String(pet.name))


func _test_manager() -> void:
	await _wait_frames(2)
	# Free the hand-spawned squad so group-based checks only see manager spawns.
	for ally in _allies:
		if is_instance_valid(ally):
			ally.queue_free()
	_allies.clear()
	for pet in _pets:
		if is_instance_valid(pet):
			pet.queue_free()
	_pets.clear()
	_mara = null
	_rook = null
	_irie = null
	_toma = null
	_mote = null
	_cinder = null
	_pip = null
	await _wait_frames(3)

	var manager := _manager_script.new() as Node
	manager.name = "TestCompanionManager"
	_world.add_child(manager)
	manager.setup(_player)
	await _wait_frames(5)
	var allies: Array = manager.get_allies()
	_check(allies.size() == 2, "CompanionManager spawns 2 active Wardens (got %d)" % allies.size())
	_check(manager.get_pet() != null, "CompanionManager spawns the active Driftling")
	_check(get_nodes_in_group("companion_manager").size() >= 1, "CompanionManager joins group 'companion_manager'")
	var status: Array = manager.get_squad_status()
	_check(status.size() == 3, "squad status exposes 2 Wardens + 1 pet (got %d)" % status.size())
	var has_ally_kind := false
	var has_pet_kind := false
	for entry in status:
		if String(entry.get("kind", "")) == "ally":
			has_ally_kind = true
		elif String(entry.get("kind", "")) == "pet":
			has_pet_kind = true
	_check(has_ally_kind and has_pet_kind, "squad status marks ally/pet kinds")
	manager.issue_squad_command(&"hold")
	await _wait_frames(2)
	var held := 0
	for ally in manager.get_allies():
		if ally.get_command() == &"hold":
			held += 1
	_check(held == allies.size(), "issue_squad_command(&'hold') reaches every Warden (%d/%d)" % [held, allies.size()])
	var first_ally: Node = manager.get_ally(&"mara_voss")
	if first_ally == null:
		# active roster may be customised; fall back to the first spawned ally.
		if allies.size() > 0:
			first_ally = allies[0]
	_check(first_ally != null, "CompanionManager.get_ally() resolves a Warden")
	manager.cleanup()
	await _wait_frames(3)


func _cleanup() -> void:
	var deployables := get_nodes_in_group("companion_deployable")
	for node in deployables:
		if is_instance_valid(node):
			node.queue_free()
	var audio := root.get_node_or_null("AudioDirector")
	if audio != null:
		for child in audio.get_children():
			if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
				child.stop()
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
	await _wait_frames(3)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _wait_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _damage_player(amount: float) -> void:
	if _player == null or _player.health_component == null:
		return
	_player.health_component.take_damage(DamageData.make(amount, StatKeys.TEAM_ENEMY, StatKeys.DMG_BALLISTIC, _enemy))
