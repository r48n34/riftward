extends Node3D
## Headless dungeon acceptance test: builds all three themed under-reach kits and
## exercises a runtime encounter (enemies, boss, loot, navmesh, anchors).
##
## Run with:
##   godot --headless --path . res://tests/dungeon_test.tscn

const BuilderScript := preload("res://features/dungeon/dungeon_builder.gd")
const RuntimeScript := preload("res://features/dungeon/dungeon_runtime.gd")
const THEMES: Array[StringName] = [&"rift_vault", &"ashen_mine", &"choir_catacomb"]

var _checks := 0
var _failures: Array[String] = []


class StubDeployment:
	extends Node
	var bosses: Array = []
	var cleared: Array = []

	func register_boss(enemy: Node) -> void:
		bosses.append(enemy)

	func build_dungeon_cache_payload() -> Dictionary:
		return {"salvage": 80, "cores": 1, "label": "Dungeon Cache", "item": {}}

	func on_dungeon_boss_defeated(runtime: Node) -> void:
		cleared.append(runtime)


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[DUNGEON-TEST] PASS: ", label)
	else:
		_failures.append(label)
		push_error("[DUNGEON-TEST] FAIL: " + label)


func _run() -> void:
	print("[DUNGEON-TEST] building themed dungeons")
	await get_tree().process_frame
	var stub := StubDeployment.new()
	stub.name = "StubDeployment"
	add_child(stub)
	var seed_value := 5150
	for theme_id in THEMES:
		var theme: Dictionary = ContentDB.get_dungeon_theme(theme_id)
		_check(not theme.is_empty(), "theme resolves: %s" % theme_id)
		if theme.is_empty():
			continue
		var builder = BuilderScript.new()
		builder.name = "Builder_%s" % String(theme_id)
		add_child(builder)
		var started := Time.get_ticks_msec()
		var ok: bool = builder.call("generate", seed_value, theme, 2, Vector3(4200.0, -620.0, 0.0))
		var elapsed := Time.get_ticks_msec() - started
		_check(ok, "dungeon generated: %s" % theme_id)
		_check(elapsed < 1500, "dungeon generation under 1.5s: %s (%dms)" % [theme_id, elapsed])
		_validate_builder(builder, theme, theme_id)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_validate_builder_physics(builder, theme_id)
		builder.queue_free()
		await get_tree().process_frame
		# Runtime encounter: spawn enemies, boss and loot for the same theme.
		var runtime = RuntimeScript.new()
		runtime.name = "Runtime_%s" % String(theme_id)
		add_child(runtime)
		runtime.call("setup", stub, theme, 2, 0)
		var built: bool = runtime.call("build", seed_value + 7, Vector3(4600.0, -620.0, 0.0))
		_check(built, "runtime built: %s" % theme_id)
		if built:
			var start: Vector3 = runtime.call("enter", null)
			_check(start.length() > 0.0, "runtime returns a start position: %s" % theme_id)
			_check(int(runtime.call("get_hostile_count")) > 0, "runtime spawns hostiles: %s" % theme_id)
			_check(runtime.call("get_boss_node") != null, "runtime spawns the theme boss: %s" % theme_id)
			_check(int(runtime.call("get_loot_cache_count")) > 0, "runtime spawns loot: %s" % theme_id)
			_check(runtime.call("get_nav_region") != null, "runtime exposes its nav region: %s" % theme_id)
			var boss = runtime.call("get_boss_node")
			if boss != null and is_instance_valid(boss):
				_check(stub.bosses.has(boss), "boss registered with the deployment: %s" % theme_id)
			runtime.call("despawn")
		runtime.queue_free()
		await get_tree().process_frame
	stub.queue_free()
	if _failures.is_empty():
		print("[DUNGEON-TEST] checks=%d failures=0" % _checks)
		print("[DUNGEON-TEST] RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("[DUNGEON-TEST] Failure: ", failure)
		print("[DUNGEON-TEST] checks=%d failures=%d" % [_checks, _failures.size()])
		print("[DUNGEON-TEST] RESULT: FAIL")
		get_tree().quit(1)


func _validate_builder(builder: Node3D, theme: Dictionary, theme_id: StringName) -> void:
	var rooms: Array = builder.call("get_room_centers")
	_check(rooms.size() >= 5, "dungeon has 5+ rooms: %s (%d)" % [theme_id, rooms.size()])
	_check(rooms.size() <= 9, "dungeon stays within the 3x3 grid: %s" % theme_id)
	var start: Vector3 = builder.call("get_start_position")
	var exit_position: Vector3 = builder.call("get_exit_position")
	var boss_position: Vector3 = builder.call("get_boss_position")
	_check(start.distance_to(boss_position) > 20.0, "boss room is far from the start: %s" % theme_id)
	_check(start.distance_to(exit_position) < 8.0, "exit anchor sits at the start room: %s" % theme_id)
	var loot: Array = builder.call("get_loot_positions")
	_check(loot.size() >= 2, "dungeon exposes loot anchors: %s" % theme_id)
	var nav: NavigationRegion3D = builder.call("get_nav_region")
	_check(nav != null and nav.navigation_mesh != null and nav.navigation_mesh.get_polygon_count() > 20,
		"dungeon navmesh baked: %s (%d polys)" % [theme_id, 0 if nav == null or nav.navigation_mesh == null else nav.navigation_mesh.get_polygon_count()])
	_check(builder.call("get_bounds") is AABB, "dungeon exposes bounds: %s" % theme_id)


func _validate_builder_physics(builder: Node3D, theme_id: StringName) -> void:
	var start: Vector3 = builder.call("get_start_position")
	# Collision: a downward ray inside the start room must hit the floor.
	var space := get_viewport().world_3d.direct_space_state
	var origin := builder.to_global(start) + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 8.0, 1)
	var hit := space.intersect_ray(query)
	_check(not hit.is_empty(), "dungeon floor collision exists: %s" % theme_id)
	# Ceiling: an upward ray from inside the start room must hit the roof.
	var up_query := PhysicsRayQueryParameters3D.create(builder.to_global(start) + Vector3.UP * 1.0, builder.to_global(start) + Vector3.UP * 8.0, 1)
	var up_hit := space.intersect_ray(up_query)
	_check(not up_hit.is_empty(), "dungeon ceiling collision exists: %s" % theme_id)
