extends Node3D
## Headless acceptance suite for W4 vehicles.
##
## Covers: all five archetypes instantiate, spec dictionaries carry the required
## keys, collision layers/groups are correct, mount/dismount round-trip with a
## stub player, forward input displaces the rig over 60 physics frames, the horse
## walks -> trots -> gallops and drains stamina, the HUD snapshot/panel contract,
## weapon-lock reporting, and deterministic VehicleSites placement.
##
## Run with:
##   godot --headless --path . res://tests/vehicles_test.tscn

const VehicleSitesScript := preload("res://features/vehicles/vehicle_sites.gd")
const HUDVehicleScript := preload("res://ui/hud/hud_vehicle.gd")
const VEHICLE_SCRIPTS := {
	&"rig": preload("res://features/vehicles/ground_car.gd"),
	&"hoverbike": preload("res://features/vehicles/hover_bike.gd"),
	&"airplane": preload("res://features/vehicles/airplane.gd"),
	&"spaceship": preload("res://features/vehicles/spaceship.gd"),
	&"horse": preload("res://features/vehicles/horse.gd"),
}
const ARCHETYPE_ORDER: Array[StringName] = [&"rig", &"hoverbike", &"airplane", &"spaceship", &"horse"]
const REQUIRED_SPEC_KEYS := [
	"id", "name", "kind", "seats", "max_speed", "accel", "turn_rate",
	"health", "mass", "icon", "hud_color",
]
const REQUIRED_HUD_KEYS := [
	"id", "name", "kind", "speed_kph", "health", "max_health", "boost",
	"gear", "icon", "accent",
]
const TIMEOUT_SECONDS := 90.0
const PHYSICS_FRAME_BUDGET := 600

var _checks := 0
var _failures: Array[String] = []
var _done := false
var _ground: StaticBody3D = null


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[VEHICLES-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[VEHICLES-TEST] FAIL: " + label)


func _run() -> void:
	print("[VEHICLES-TEST] starting rideable validation")
	var timeout := Timer.new()
	timeout.name = "HardTimeout"
	timeout.wait_time = TIMEOUT_SECONDS
	timeout.one_shot = true
	timeout.timeout.connect(_on_timeout)
	add_child(timeout)
	timeout.start()
	_build_ground()
	await get_tree().physics_frame
	var vehicles: Dictionary = await _test_instantiation()
	await _test_mount_round_trip(vehicles)
	await _test_drive(vehicles)
	await _test_hud(vehicles)
	await _test_real_player(vehicles)
	await _test_horse(vehicles)
	await _test_sites()
	await _cleanup(vehicles)
	_done = true
	if is_instance_valid(timeout):
		timeout.queue_free()
	_finish()


func _on_timeout() -> void:
	if _done:
		return
	_failures.append("TIMEOUT after %.0fs" % TIMEOUT_SECONDS)
	_done = true
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[VEHICLES-TEST] checks=%d failures=0" % _checks)
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[VEHICLES-TEST] Failure: ", failure)
		print("[VEHICLES-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
		print("RESULT: FAIL - " + ", ".join(_failures))
		get_tree().quit(1)


func _build_ground() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "TestGround"
	_ground.collision_layer = 1
	_ground.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	_ground.add_child(shape)
	add_child(_ground)


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 1. Instantiation, specs, layers, groups
# ---------------------------------------------------------------------------

func _test_instantiation() -> Dictionary:
	var vehicles: Dictionary = {}
	var index := 0
	for vehicle_id in ARCHETYPE_ORDER:
		var script: Script = VEHICLE_SCRIPTS.get(vehicle_id, null)
		_check(script != null, "archetype script present: %s" % String(vehicle_id))
		if script == null:
			continue
		var instance: Variant = script.new()
		_check(instance is CharacterBody3D, "instantiates as CharacterBody3D: %s" % String(vehicle_id))
		if not (instance is CharacterBody3D):
			continue
		var vehicle = instance
		vehicle.name = "Test_%s" % String(vehicle_id)
		add_child(vehicle)
		vehicle.global_position = Vector3(float(index) * 16.0, 2.0, 0.0)
		vehicles[vehicle_id] = vehicle
		index += 1
	await _physics_frames(3)
	for vehicle_id in ARCHETYPE_ORDER:
		if not vehicles.has(vehicle_id):
			continue
		var vehicle = vehicles[vehicle_id]
		var spec: Dictionary = vehicle.get_vehicle_spec()
		for key in REQUIRED_SPEC_KEYS:
			_check(spec.has(key), "%s spec key: %s" % [String(vehicle_id), String(key)])
		_check(StringName(spec.get("id", &"")) == vehicle_id,
			"spec id matches archetype: %s" % String(vehicle_id))
		_check(int(spec.get("seats", 0)) >= 1, "spec seats >= 1: %s" % String(vehicle_id))
		_check(float(spec.get("max_speed", 0.0)) > 1.0, "spec max_speed > 1: %s" % String(vehicle_id))
		_check(float(spec.get("accel", 0.0)) > 0.5, "spec accel > 0.5: %s" % String(vehicle_id))
		_check(float(spec.get("turn_rate", 0.0)) > 0.05, "spec turn_rate > 0.05: %s" % String(vehicle_id))
		_check(float(spec.get("health", 0.0)) > 10.0, "spec health > 10: %s" % String(vehicle_id))
		_check(float(spec.get("mass", 0.0)) > 10.0, "spec mass > 10: %s" % String(vehicle_id))
		_check(spec.get("hud_color") is Color, "spec hud_color is Color: %s" % String(vehicle_id))
		_check(vehicle.collision_layer == 1 << 10,
			"collision layer 11 (1024): %s" % String(vehicle_id))
		_check(vehicle.collision_mask == 7,
			"collision mask World|Player|Enemy (7): %s" % String(vehicle_id))
		_check(vehicle.is_in_group("rideable"), "in group rideable: %s" % String(vehicle_id))
		_check(vehicle.is_in_group("interactable"), "in group interactable: %s" % String(vehicle_id))
		_check(vehicle.get_seat_node() is Node3D, "seat node is Node3D: %s" % String(vehicle_id))
		_check(not bool(vehicle.is_occupied()), "starts unoccupied: %s" % String(vehicle_id))
		_check(String(vehicle.get_interact_prompt()).length() > 0,
			"interact prompt while empty: %s" % String(vehicle_id))
		_check(not bool(vehicle.is_weapon_locked()), "weapon lock false while empty: %s" % String(vehicle_id))
	return vehicles


# ---------------------------------------------------------------------------
# 2. Mount / dismount round-trip with a stub player
# ---------------------------------------------------------------------------

func _test_mount_round_trip(vehicles: Dictionary) -> void:
	var car = vehicles.get(&"rig", null)
	if car == null:
		_failures.append("rig unavailable for mount test")
		return
	var stub := CharacterBody3D.new()
	stub.name = "StubPlayer"
	stub.collision_layer = 2
	stub.collision_mask = 1 | 128
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	stub.add_child(shape)
	add_child(stub)
	stub.global_position = car.global_position + Vector3(4.0, 0.5, 0.0)
	await get_tree().physics_frame
	var original_parent: Node = stub.get_parent()
	var mount_signal := [0]
	var dismount_signal := [0, false]
	car.mounted.connect(func(_player: Node) -> void: mount_signal[0] += 1)
	car.dismounted.connect(func(_player: Node, forced: bool) -> void:
		dismount_signal[0] += 1
		dismount_signal[1] = forced
	)
	var bus_mounts := [0]
	var bus_dismounts := [0]
	if EventBus != null and EventBus.has_signal(&"vehicle_mounted"):
		EventBus.connect("vehicle_mounted", func(_vehicle: Node, _vehicle_id: StringName) -> void:
			bus_mounts[0] += 1
		)
	if EventBus != null and EventBus.has_signal(&"vehicle_dismounted"):
		EventBus.connect("vehicle_dismounted", func(_vehicle: Node, _vehicle_id: StringName) -> void:
			bus_dismounts[0] += 1
		)
	# Mount.
	var mounted: bool = bool(car.mount(stub))
	_check(mounted, "mount() returns true")
	_check(bool(car.is_occupied()), "is_occupied() true after mount")
	_check(stub.get_parent() == car.get_seat_node(), "stub player reparented onto seat")
	_check(mount_signal[0] == 1, "mounted signal emitted once")
	_check(not bool(car.mount(stub)), "mount() is idempotent (second call returns false)")
	_check(String(car.get_interact_prompt()).is_empty(), "interact prompt empty while occupied")
	_check(bool(car.is_weapon_locked()), "weapon lock reported while occupied")
	var snapshot: Dictionary = car.get_hud_snapshot()
	for key in REQUIRED_HUD_KEYS:
		_check(snapshot.has(key), "HUD snapshot key: %s" % String(key))
	_check(bool(snapshot.get("weapon_locked", false)), "HUD snapshot reports weapon lock")
	_check(bool(snapshot.get("occupied", false)), "HUD snapshot reports occupied")
	_check(int(snapshot.get("gear", 0)) >= 1, "HUD snapshot gear >= 1")
	_check(float(snapshot.get("max_speed_kph", 0.0)) > 10.0, "HUD snapshot max_speed_kph present")
	if EventBus != null and EventBus.has_signal(&"vehicle_mounted"):
		_check(bus_mounts[0] >= 1, "EventBus vehicle_mounted emitted")
	# Dismount.
	var exit_before: Vector3 = car.get_exit_position()
	car.dismount(false)
	_check(not bool(car.is_occupied()), "is_occupied() false after dismount")
	_check(stub.get_parent() == original_parent, "stub player reparented back to original parent")
	_check(dismount_signal[0] == 1, "dismounted signal emitted once")
	_check(not dismount_signal[1], "forced flag false on normal dismount")
	_check(stub.global_position.distance_to(exit_before) <= 1.0, "dismounted at get_exit_position()")
	_check(stub.global_position.y > _ground.global_position.y + 0.2, "exit position is above ground")
	_check(not bool(car.is_weapon_locked()), "weapon lock cleared after dismount")
	_check(String(car.get_interact_prompt()).length() > 0, "interact prompt restored after dismount")
	if EventBus != null and EventBus.has_signal(&"vehicle_dismounted"):
		_check(bus_dismounts[0] >= 1, "EventBus vehicle_dismounted emitted")
	# Damage plumbing.
	var health_before: float = car.get_health()
	car.apply_damage(12.0, self)
	_check(car.get_health() < health_before, "apply_damage reduces vehicle health")
	stub.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 3. Forward input displaces the rig
# ---------------------------------------------------------------------------

func _test_drive(vehicles: Dictionary) -> void:
	var car = vehicles.get(&"rig", null)
	if car == null:
		_failures.append("rig unavailable for drive test")
		return
	var driver := Node3D.new()
	driver.name = "DriveStub"
	add_child(driver)
	driver.global_position = car.global_position + Vector3(3.0, 0.5, 0.0)
	await get_tree().physics_frame
	_check(bool(car.mount(driver)), "rig mounts drive stub")
	car.set_control_state({"throttle": 1.0, "steer": 0.0})
	var start: Vector3 = car.global_position
	await _physics_frames(60)
	var travelled := Vector2(car.global_position.x - start.x, car.global_position.z - start.z).length()
	_check(travelled > 2.0, "forward input displaces the rig after 60 frames (%0.2fm)" % travelled)
	var speed_kph: float = float(car.get_hud_snapshot().get("speed_kph", 0.0))
	_check(speed_kph > 5.0, "rig builds speed under throttle (%0.1f km/h)" % speed_kph)
	_check(speed_kph <= float(car.get_vehicle_spec().get("max_speed", 30.0)) * 3.6 * 1.2,
		"rig speed stays within spec headroom")
	# Steering changes heading without exploding the speed.
	var heading_before: float = car.global_rotation.y
	car.set_control_state({"throttle": 0.0, "steer": 1.0})
	await _physics_frames(30)
	_check(absf(wrapf(car.global_rotation.y - heading_before, -PI, PI)) > 0.02,
		"steering input rotates the rig")
	car.set_control_state({})
	car.dismount(false)
	driver.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 4. HUD panel contract
# ---------------------------------------------------------------------------

func _test_hud(vehicles: Dictionary) -> void:
	var car = vehicles.get(&"rig", null)
	if car == null:
		_failures.append("rig unavailable for HUD test")
		return
	var panel = HUDVehicleScript.new()
	_check(panel is Control, "UIVehiclePanel extends Control")
	if not (panel is Control):
		return
	add_child(panel)
	await get_tree().process_frame
	_check(not bool(panel.is_visible_panel()), "HUD panel starts hidden")
	var snapshot: Dictionary = car.get_hud_snapshot()
	panel.configure(snapshot)
	await get_tree().process_frame
	var stored: Dictionary = panel.get_snapshot()
	for key in REQUIRED_HUD_KEYS:
		_check(stored.has(key), "HUD panel snapshot key: %s" % String(key))
	_check(StringName(stored.get("id", &"")) == &"rig", "HUD panel snapshot id matches")
	_check(stored.get("accent") is Color, "HUD panel snapshot accent is Color")
	panel.show_panel()
	await get_tree().process_frame
	_check(bool(panel.is_visible_panel()), "show_panel() makes the panel visible")
	var updated := snapshot.duplicate(true)
	updated["speed_kph"] = 42.0
	updated["health"] = 100.0
	panel.update_snapshot(updated)
	_check(is_equal_approx(float(panel.get_snapshot().get("speed_kph", 0.0)), 42.0),
		"update_snapshot() refreshes the data")
	panel.hide_panel()
	_check(not bool(panel.is_visible_panel()), "hide_panel() hides the panel")
	panel.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 5. Real Player hook round-trip (interact must prefer Player.enter_vehicle)
# ---------------------------------------------------------------------------

func _test_real_player(vehicles: Dictionary) -> void:
	var car = vehicles.get(&"rig", null)
	if car == null or not ResourceLoader.exists("res://features/player/player.gd"):
		return
	var player_script: Script = load("res://features/player/player.gd")
	var real_player: Variant = player_script.new()
	if not (real_player is CharacterBody3D):
		_check(false, "real Player script instantiates")
		return
	real_player.name = "RealPlayer"
	add_child(real_player)
	real_player.global_position = car.global_position + Vector3(6.0, 0.5, 0.0)
	await _physics_frames(3)
	var original_parent: Node = real_player.get_parent()
	# rideable.interact() must route through Player.enter_vehicle (combat lock + bus signals).
	car.interact(real_player)
	await get_tree().physics_frame
	_check(bool(real_player.call("is_riding")), "interact() routes through Player.enter_vehicle")
	_check(bool(car.is_occupied()), "real Player interaction occupies the rig")
	_check(real_player.get_parent() == car.get_seat_node(), "real Player parented onto the seat")
	real_player.call("exit_vehicle")
	await get_tree().physics_frame
	_check(not bool(car.is_occupied()), "real Player.exit_vehicle empties the rig")
	_check(not bool(real_player.call("is_riding")), "real Player stops riding after exit_vehicle")
	_check(real_player.get_parent() == original_parent, "real Player restored to its pre-mount parent")
	# Interact-to-exit path: Player._update_ride() calls vehicle.dismount() from its
	# own physics tick, so dismount() must reconcile the Player's riding state.
	car.interact(real_player)
	await _physics_frames(2)
	_check(bool(real_player.call("is_riding")), "real Player re-enters the rig")
	Input.action_press(&"interact")
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _physics_frames(2)
	_check(not bool(real_player.call("is_riding")), "interact-to-exit clears the player riding state")
	_check(not bool(car.is_occupied()), "interact-to-exit frees the rig")
	if bool(real_player.call("is_riding")):
		real_player.call("exit_vehicle")
	real_player.queue_free()
	await _physics_frames(2)


# ---------------------------------------------------------------------------
# 6. Horse gaits, stamina, jump and summon
# ---------------------------------------------------------------------------

func _test_horse(vehicles: Dictionary) -> void:
	var horse = vehicles.get(&"horse", null)
	if horse == null:
		_failures.append("horse unavailable for gait test")
		return
	var rider := Node3D.new()
	rider.name = "HorseRider"
	add_child(rider)
	rider.global_position = horse.global_position + Vector3(2.5, 0.4, 0.0)
	await get_tree().physics_frame
	_check(bool(horse.mount(rider)), "horse mounts rider")
	_check(StringName(horse.get_gait()) == &"idle", "horse starts idle after mount")
	var stamina_start: float = float(horse.get_stamina())
	horse.set_control_state({"throttle": 1.0})
	var gait_order: Array[String] = []
	var last_gait := String(horse.get_gait())
	var frames := 0
	while frames < PHYSICS_FRAME_BUDGET and not gait_order.has("gallop"):
		await get_tree().physics_frame
		frames += 1
		var gait := String(horse.get_gait())
		if gait != last_gait:
			if not gait_order.has(gait):
				gait_order.append(gait)
			last_gait = gait
	_check(gait_order.has("walk"), "horse gait walk reached (order: %s)" % str(gait_order))
	_check(gait_order.has("trot"), "horse gait trot reached")
	_check(gait_order.has("gallop"), "horse gait gallop reached within budget")
	var walk_index := gait_order.find("walk")
	var trot_index := gait_order.find("trot")
	var gallop_index := gait_order.find("gallop")
	_check(walk_index >= 0 and trot_index > walk_index, "horse gait order walk -> trot")
	_check(trot_index >= 0 and gallop_index > trot_index, "horse gait order trot -> gallop")
	_check(float(horse.get_stamina()) < stamina_start, "galloping drains horse stamina")
	_check(int(horse.get_hud_snapshot().get("gear", 0)) >= 1, "horse HUD gear reflects gait")
	# Jump: costs height and drops the gait a step.
	horse.set_control_state({"throttle": 0.0})
	await _physics_frames(40)
	horse.set_control_state({"throttle": 0.0, "jump": true})
	await get_tree().physics_frame
	_check(float(horse.velocity.y) > 1.0 or int(horse.get_gait_index()) <= 2,
		"horse jump produces upward velocity / gait step-down")
	horse.set_control_state({})
	horse.dismount(false)
	# Summon hook for Deployment's `summon_ride` (KEY_T).
	await get_tree().physics_frame
	var summon_ok: bool = bool(horse.whistle(rider))
	_check(summon_ok, "horse whistle()/summon() returns true when unoccupied")
	_check(horse.global_position.distance_to(rider.global_position) < 12.0,
		"summoned horse lands near the player")
	rider.queue_free()
	await get_tree().physics_frame


# ---------------------------------------------------------------------------
# 6. VehicleSites determinism and POI affinity
# ---------------------------------------------------------------------------

class MockWorld extends Node3D:
	var _pois: Array[Dictionary] = [
		{"position": Vector3(140.0, 1.0, 0.0), "type": "comms_array", "name": "Comms Array", "radius": 32.0},
		{"position": Vector3(0.0, 1.0, 140.0), "type": "foundry_hall", "name": "Foundry Hall", "radius": 32.0},
		{"position": Vector3(-140.0, 1.0, 0.0), "type": "warden_outpost", "name": "Warden Outpost", "radius": 40.0},
	]

	func get_spawn_points() -> Array[Vector3]:
		return [Vector3(0.0, 2.0, 0.0)]

	func get_pois() -> Array[Dictionary]:
		return _pois.duplicate(true)

	func sample_height(_world_xz: Vector2) -> float:
		return 0.0


class MockTagWorld extends Node3D:
	## POI types with no hard-coded VehicleSites preference; their vehicle slots
	## come from the authored POISpecs table (see poi_specs.gd).
	var _pois: Array[Dictionary] = [
		{"position": Vector3(80.0, 1.0, 0.0), "type": "crash_site", "name": "Crash Site", "radius": 30.0},
		{"position": Vector3(-80.0, 1.0, 0.0), "type": "derelict_ship", "name": "Derelict Freighter", "radius": 30.0},
		{"position": Vector3(0.0, 1.0, 80.0), "type": "ashen_stockade", "name": "Ashen Stockade", "radius": 30.0},
	]

	func get_spawn_points() -> Array[Vector3]:
		return [Vector3(0.0, 2.0, 0.0)]

	func get_pois() -> Array[Dictionary]:
		return _pois.duplicate(true)

	func sample_height(_world_xz: Vector2) -> float:
		return 0.0


func _test_sites() -> void:
	var mock = MockWorld.new()
	mock.name = "MockWorld"
	add_child(mock)
	var sites_script: Script = VehicleSitesScript
	var root_a := Node3D.new()
	root_a.name = "SiteRootA"
	add_child(root_a)
	var first: Array = sites_script.new().build(root_a, mock, 778899, {})
	_check(first.size() == 5, "VehicleSites spawns all five rideables (%d)" % first.size())
	var ids: Array[String] = []
	for vehicle in first:
		var vehicle_id := StringName(vehicle.get_vehicle_id())
		if not ids.has(String(vehicle_id)):
			ids.append(String(vehicle_id))
	for expected in ARCHETYPE_ORDER:
		_check(ids.has(String(expected)), "VehicleSites spawned %s" % String(expected))
	_check(ids.size() == 5, "VehicleSites archetypes are unique")
	# Drop-zone guarantee: rig + hoverbike near the drop point.
	for vehicle in first:
		if StringName(vehicle.get_vehicle_id()) == &"rig" or StringName(vehicle.get_vehicle_id()) == &"hoverbike":
			_check(vehicle.global_position.distance_to(Vector3(0.0, vehicle.global_position.y, 0.0)) < 40.0,
				"drop-zone vehicle near the drop point: %s" % String(vehicle.get_vehicle_id()))
	# POI affinity.
	for vehicle in first:
		var vehicle_id := StringName(vehicle.get_vehicle_id())
		var position: Vector3 = vehicle.global_position
		match vehicle_id:
			&"airplane":
				_check(position.distance_to(Vector3(140.0, position.y, 0.0)) < 70.0,
					"airplane placed at the comms array POI")
			&"spaceship":
				_check(position.distance_to(Vector3(0.0, position.y, 140.0)) < 70.0,
					"spaceship placed at the foundry hall POI")
			&"horse":
				_check(position.distance_to(Vector3(-140.0, position.y, 0.0)) < 70.0,
					"horse placed at the warden outpost stable")
	# Determinism: same seed yields identical ids + positions.
	var root_b := Node3D.new()
	root_b.name = "SiteRootB"
	add_child(root_b)
	var second: Array = sites_script.new().build(root_b, mock, 778899, {})
	var signature_a := _placement_signature(first)
	var signature_b := _placement_signature(second)
	_check(signature_a == signature_b, "VehicleSites placement is deterministic for one seed")
	# Different seed must move at least one vehicle.
	var root_c := Node3D.new()
	root_c.name = "SiteRootC"
	add_child(root_c)
	var third: Array = sites_script.new().build(root_c, mock, 112233, {})
	_check(_placement_signature(third) != signature_a, "VehicleSites placement varies with the seed")
	# No world data at all: must still spawn the guaranteed five.
	var root_d := Node3D.new()
	root_d.name = "SiteRootD"
	add_child(root_d)
	var fallback: Array = sites_script.new().build(root_d, null, 445566, {})
	_check(fallback.size() == 5, "VehicleSites degrades safely with no world (%d)" % fallback.size())
	for vehicle in fallback:
		_check(is_instance_valid(vehicle) and vehicle is CharacterBody3D,
			"fallback-spawned rideable is valid: %s" % String(vehicle.get_vehicle_id() if is_instance_valid(vehicle) else "?"))
	# POISpecs affinity: POI types without a hard-coded preference resolve their
	# vehicle slot from the authored POISpecs table (crash_site -> airplane,
	# derelict_ship -> spaceship, ashen_stockade -> horse).
	if ResourceLoader.exists("res://features/world/poi_specs.gd"):
		var tag_world = MockTagWorld.new()
		tag_world.name = "MockTagWorld"
		add_child(tag_world)
		var root_e := Node3D.new()
		root_e.name = "SiteRootE"
		add_child(root_e)
		var tagged: Array = sites_script.new().build(root_e, tag_world, 515151, {})
		_check(tagged.size() == 5, "VehicleSites spawns five with spec-tagged POIs")
		for vehicle in tagged:
			var vehicle_id := StringName(vehicle.get_vehicle_id())
			var position: Vector3 = vehicle.global_position
			match vehicle_id:
				&"airplane":
					_check(position.distance_to(Vector3(80.0, position.y, 0.0)) < 60.0,
						"POISpecs tag routes airplane to crash_site")
				&"spaceship":
					_check(position.distance_to(Vector3(-80.0, position.y, 0.0)) < 60.0,
						"POISpecs tag routes spaceship to derelict_ship")
				&"horse":
					_check(position.distance_to(Vector3(0.0, position.y, 80.0)) < 60.0,
						"POISpecs tag routes horse to ashen_stockade")
		root_e.queue_free()
		tag_world.queue_free()
	root_a.queue_free()
	root_b.queue_free()
	root_c.queue_free()
	root_d.queue_free()
	mock.queue_free()
	await _physics_frames(2)


func _placement_signature(vehicles: Array) -> String:
	var parts: PackedStringArray = []
	for vehicle in vehicles:
		if vehicle == null or not is_instance_valid(vehicle):
			continue
		var position: Vector3 = vehicle.global_position
		parts.append("%s@%.2f,%.2f,%.2f" % [
			String(vehicle.get_vehicle_id()), position.x, position.y, position.z,
		])
	parts.sort()
	return "|".join(parts)


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func _cleanup(vehicles: Dictionary) -> void:
	for vehicle_id in vehicles.keys():
		var vehicle = vehicles[vehicle_id]
		if vehicle != null and is_instance_valid(vehicle):
			if bool(vehicle.is_occupied()):
				vehicle.dismount(true)
			vehicle.queue_free()
	vehicles.clear()
	await _physics_frames(2)
