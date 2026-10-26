extends RefCounted
## WORLD STRUCTURES ??procedural modular POI architecture.
##
## Every structure is built from Godot primitives, merged into a handful of
## material surfaces via MeshKit, with one cheap trimesh collider per POI.
## Design goals: strong silhouettes readable at 300m+, clear central fighting
## space with cover rings, and a coherent ivory / rust / teal material story.

const MeshKit := preload("res://features/world/mesh_kit.gd")
const Palette := preload("res://features/world/world_palette.gd")

var _materials: Dictionary = {}


## Builds every POI, the two drop-zone pods and the roadside outbuildings.
func build_all(
	structures_root: Node3D,
	pois: Array,
	spawns: Array,
	world_seed: int,
	materials: Dictionary,
	roadside: Array = []
) -> Dictionary:
	_materials = materials
	var built := 0
	for i in pois.size():
		var poi: Dictionary = pois[i]
		var root := _make_root(structures_root, "POI_%02d_%s" % [i, String(poi.get("type", "poi"))], poi)
		var kit := MeshKit.new()
		kit.set_materials(_materials)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("poi:%d:%d:%s" % [world_seed, i, String(poi.get("name", ""))])
		match String(poi.get("type", "")):
			"faction_camp":
				_build_camp(root, kit, rng)
			"relay_spire":
				_build_relay_spire(root, kit, rng)
			"crash_site":
				_build_crash_site(root, kit, rng)
			"vault":
				_build_vault(root, kit, rng)
			"warden_outpost":
				_build_warden_outpost(root, kit, rng)
			"anomaly":
				_build_anomaly(root, kit, rng)
			"ruin_field":
				_build_ruin_field(root, kit, rng)
			"ashen_stockade":
				_build_ashen_stockade(root, kit, rng)
			"bloom_hive":
				_build_bloom_hive(root, kit, rng)
			"choir_post":
				_build_choir_post(root, kit, rng)
			"colony_ruins":
				_build_colony_ruins(root, kit, rng)
			"derelict_ship":
				_build_derelict_ship(root, kit, rng)
			"exfil_pad":
				_build_exfil_pad(root, kit, rng)
			"foundry_hall":
				_build_foundry_hall(root, kit, rng)
			"hab_cluster":
				_build_hab_cluster(root, kit, rng)
			"comms_array":
				_build_comms_array(root, kit, rng)
			"fuel_depot":
				_build_fuel_depot(root, kit, rng)
			"clinic_shelter":
				_build_clinic_shelter(root, kit, rng)
			"research_lab":
				_build_research_lab(root, kit, rng)
			"water_works":
				_build_water_works(root, kit, rng)
			_:
				_build_fallback(root, kit, rng)
		_finalize(root, kit, poi)
		built += 1

	for i in spawns.size():
		var spawn: Dictionary = spawns[i]
		var info := {
			"name": "Drop Zone %s" % String(spawn.get("name", str(i))),
			"type": "drop_zone",
			"position": spawn["position"],
			"radius": 18.0,
			"yaw": 0.0,
		}
		var root := _make_root(structures_root, "DropZone_%02d" % i, info)
		var kit := MeshKit.new()
		kit.set_materials(_materials)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("drop:%d:%d" % [world_seed, i])
		_build_drop_pod(root, kit, rng)
		_finalize(root, kit, info)
	var roadside_built := 0
	for i in roadside.size():
		var entry: Dictionary = roadside[i]
		var info := {
			"name": "Roadside %02d" % i,
			"type": "roadside",
			"position": entry.get("position", Vector3.ZERO),
			"radius": 12.0,
			"yaw": float(entry.get("yaw", 0.0)),
		}
		var root := _make_root(structures_root, "Roadside_%02d" % i, info)
		var kit := MeshKit.new()
		kit.set_materials(_materials)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("roadside:%d:%d" % [world_seed, i])
		match int(entry.get("kind", 0)) % 3:
			1:
				_build_roadside_relay(root, kit, rng)
			2:
				_build_roadside_ruin(root, kit, rng)
			_:
				_build_roadside_checkpoint(root, kit, rng)
		_finalize(root, kit, info)
		roadside_built += 1
	return {"count": built, "spawn_count": spawns.size(), "roadside_count": roadside_built}


# =============================================================================
# POI: faction camp
# =============================================================================
func _build_camp(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 20.0, &"pad")
	# Enterable command hab facing the pad center.
	_interior_shell(root, kit, Vector3(0.0, 0.0, -15.0), Vector3(9.0, 0.0, 6.0), [0], &"ivory", &"concrete", 3.4, Color(0.35, 0.95, 0.85), &"glow_teal")
	kit.box(Vector3(10.6, 0.35, 7.6), Vector3(0.0, 3.75, -15.0), &"rust")
	_interior_partition(kit, Vector3(0.0, 0.0, -15.0), Vector3(9.0, 0.0, 6.0), 1, -1.0, true, &"ivory_warm", 3.4)
	_crates(kit, rng, Vector3(2.0, 0.0, -16.5), 2)
	_interior_light(root, Vector3(-2.0, 2.2, -16.0), Color(1.0, 0.72, 0.42), 0.9, 7.0)
	_antenna(kit, Vector3(3.2, 3.7, -15.0), 11.0)
	# Rooftop shade + rail.
	kit.box(Vector3(6.0, 0.2, 4.0), Vector3(-2.2, 5.6, -15.0), &"ivory_warm")
	kit.cylinder(0.12, 0.12, 2.0, 8, Vector3(-5.0, 4.7, -17.0), &"steel", Vector3.ZERO, false)
	kit.cylinder(0.12, 0.12, 2.0, 8, Vector3(-5.0, 4.7, -13.0), &"steel", Vector3.ZERO, false)
	# Tents around the pad (skip the footprint now occupied by the command hab).
	for t in 3:
		var ang := TAU * float(t) / 3.0 + 0.6
		var tp := Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 15.0)
		if tp.z < -8.0 and absf(tp.x) < 8.0:
			continue
		kit.cylinder(2.7, 2.7, 1.1, 8, tp + Vector3(0.0, 0.7, 0.0), &"fabric")
		kit.cylinder(0.15, 2.9, 2.0, 8, tp + Vector3(0.0, 2.2, 0.0), &"fabric", Vector3.ZERO, false)
		kit.cylinder(0.2, 0.2, 3.2, 6, tp + Vector3(0.0, 3.4, 0.0), &"steel", Vector3.ZERO, false)
	# Watchtower.
	_watchtower(kit, Vector3(13.0, 0.0, 9.0), -0.5)
	# Salvage containers double as hard cover.
	_container(kit, Vector3(-13.0, 1.35, 6.0), 0.35, &"rust")
	_container(kit, Vector3(-9.5, 1.35, -9.0), -0.2, &"steel")
	# Crates and low cover.
	_crates(kit, rng, Vector3(6.5, 0.0, 6.0), 4)
	_crates(kit, rng, Vector3(-6.0, 0.0, 2.0), 3)
	for b in 6:
		var ang := TAU * float(b) / 6.0 + 0.25
		_barrier(kit, Vector3(cos(ang) * 21.0, 0.0, sin(ang) * 21.0), ang + PI * 0.5)
	# --- Detail pass: command hab furnishing, roof kit and camp services -----
	_desk(kit, Vector3(-2.4, 0.0, -17.0), PI)
	_locker_bank(kit, Vector3(3.0, 0.0, -17.4), PI, 3)
	_shelf(kit, Vector3(-3.2, 0.0, -13.4), 0.0, 1.6, 1.7)
	_screen(kit, Vector3(0.0, 2.1, -17.7), PI)
	_holo_table(kit, Vector3(2.0, 0.0, -13.2), 0.0)
	_cable_run(kit, Vector3(-4.0, 0.0, -14.0), Vector3(4.0, 0.0, -14.0))
	_roof_kit(kit, Vector3(0.0, 0.0, -15.0), Vector2(6.5, 4.0), 3.95)
	_awning(kit, Vector3(-3.4, 0.0, -12.0), 0.0, 4.0, 2.2)
	_vent(kit, Vector3(4.6, 2.2, -13.0), PI * 0.5)
	_pipe_run(kit, Vector3(4.9, 3.9, -15.0), Vector3(4.9, 1.6, -15.0), 0.16, &"steel")
	_pipe_run(kit, Vector3(4.9, 0.6, -15.0), Vector3(9.0, 0.6, -10.0), 0.16, &"steel")
	_ladder(kit, Vector3(-5.2, 0.0, -18.2), 3.9, 0.0)
	_water_tank(kit, Vector3(-11.0, 0.0, 2.0), 1.4, 2.8)
	_solar_panel(kit, Vector3(-13.0, 2.65, 6.0), 0.0)
	_signage(kit, Vector3(4.0, 0.0, 8.0), 0.0, &"glow_amber")
	_crate_row(kit, Vector3(7.5, 0.0, 1.0), 0.0, 3, &"rust")
	_hazard_stripes(kit, Vector3(-2.0, 0.02, 6.4), 0.0, 4.0, 0.6)
	# Entry banner + lamps.
	_banner(kit, Vector3(0.0, 0.0, 9.0), 0.0, &"rust")
	_banner(kit, Vector3(-4.0, 0.0, 8.0), 0.2, &"rust_dark")
	_lamp(kit, Vector3(4.5, 0.0, 4.5), &"glow_amber")
	_lamp(kit, Vector3(-4.5, 0.0, 4.8), &"glow_teal")
	_add_light(root, Vector3(0.0, 2.4, -12.0), Color(1.0, 0.72, 0.42), 1.1, 10.0)
	_add_light(root, Vector3(13.0, 7.0, 9.0), Color(0.45, 0.95, 0.85), 0.7, 8.0)


# =============================================================================
# POI: relay spire
# =============================================================================
func _build_relay_spire(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 15.0, &"concrete")
	# Bunker base.
	kit.box(Vector3(9.0, 3.0, 7.0), Vector3(0.0, 1.65, 0.0), &"ivory")
	kit.box(Vector3(9.6, 0.4, 7.6), Vector3(0.0, 3.4, 0.0), &"rust")
	kit.box(Vector3(2.6, 2.4, 0.3), Vector3(0.0, 1.4, 3.7), &"dark")
	kit.box(Vector3(7.0, 0.3, 5.0), Vector3(0.0, 3.8, 0.0), &"steel")
	# Lattice tower: tapering legs + cross braces.
	var height := 46.0
	for leg in 4:
		var ang := TAU * float(leg) / 4.0 + PI * 0.25
		var base := Vector3(cos(ang) * 3.0, 3.8, sin(ang) * 3.0)
		var top := Vector3(cos(ang) * 0.9, height, sin(ang) * 0.9)
		var mid := (base + top) * 0.5
		var dirv := (top - base)
		var leg_len := dirv.length()
		var rot := _rotation_from_up(dirv.normalized())
		kit.cylinder(0.16, 0.30, leg_len, 6, mid, &"steel", rot, false)
	for brace in 5:
		var y := 8.0 + float(brace) * 8.0
		var radius := lerpf(3.0, 0.9, float(brace) / 5.0)
		kit.cylinder(0.10, 0.10, radius * 2.0, 5, Vector3(0.0, y, 0.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
		kit.cylinder(0.10, 0.10, radius * 2.0, 5, Vector3(0.0, y, 0.0), &"steel", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Glowing signal rings.
	for ring_i in 3:
		var y := 16.0 + float(ring_i) * 11.0
		var r := lerpf(2.6, 1.2, float(ring_i) / 3.0)
		kit.torus(r, r + 0.30, Vector3(0.0, y, 0.0), &"glow_teal", Vector3.ZERO, false)
		kit.sphere(0.28, Vector3(r, y, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
		kit.sphere(0.28, Vector3(-r, y, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# Platform, dish and beacon.
	kit.box(Vector3(4.0, 0.35, 4.0), Vector3(0.0, height, 0.0), &"ivory_warm")
	kit.cylinder(2.6, 2.6, 0.4, 12, Vector3(3.0, height - 0.4, 2.6), &"ivory", Vector3(0.5, 0.4, 0.2), false)
	kit.cylinder(0.25, 0.25, 3.0, 6, Vector3(3.0, height - 1.6, 2.6), &"steel", Vector3.ZERO, false)
	kit.cylinder(0.12, 0.5, 4.0, 7, Vector3(0.0, height + 2.2, 0.0), &"ivory", Vector3.ZERO, false)
	kit.sphere(0.7, Vector3(0.0, height + 4.5, 0.0), &"glow_teal", Vector3.ZERO, false, 8, 4)
	# --- Detail pass: bunker roof deck, service runs and ground consoles ----
	_roof_kit(kit, Vector3(0.0, 0.0, 0.0), Vector2(6.0, 4.4), 3.95)
	_ladder(kit, Vector3(4.8, 0.0, 3.0), 3.9, 0.0)
	_vent(kit, Vector3(-4.6, 2.0, -2.0), PI * 0.5, Vector3(0.9, 0.7, 0.35))
	_vent(kit, Vector3(0.0, 2.0, -3.6), PI)
	_pipe_run(kit, Vector3(-4.9, 0.5, 0.0), Vector3(-4.9, 3.9, 0.0), 0.16, &"steel")
	_cable_run(kit, Vector3(6.5, 0.0, -4.0), Vector3(2.0, 0.0, -3.0))
	_desk(kit, Vector3(6.5, 0.0, -2.0), PI * 0.5)
	_locker_bank(kit, Vector3(-6.5, 0.0, 3.0), 0.0, 2)
	_signage(kit, Vector3(3.0, 0.0, 6.0), 0.0, &"glow_teal")
	_water_tank(kit, Vector3(8.5, 0.0, 5.0), 1.3, 2.6)
	_solar_panel(kit, Vector3(6.5, 0.0, 5.2), 0.0)
	_railing(kit, Vector3(-2.0, 46.2, -2.0), Vector3(2.0, 46.2, -2.0), 0.9, 2)
	_railing(kit, Vector3(-2.0, 46.2, 2.0), Vector3(2.0, 46.2, 2.0), 0.9, 2)
	# Ground equipment + cover ring.
	kit.box(Vector3(2.6, 1.5, 1.6), Vector3(6.5, 0.9, -4.0), &"dark")
	kit.box(Vector3(2.6, 1.5, 1.6), Vector3(-6.0, 0.9, -5.0), &"steel")
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.8
		_barrier(kit, Vector3(cos(ang) * 13.0, 0.0, sin(ang) * 13.0), ang + PI * 0.5)
	_crates(kit, rng, Vector3(-5.0, 0.0, 4.0), 3)
	_crates(kit, rng, Vector3(5.5, 0.0, 5.5), 2)
	_add_light(root, Vector3(0.0, 20.0, 0.0), Color(0.35, 0.95, 0.85), 1.2, 26.0)


# =============================================================================
# POI: crash site
# =============================================================================
func _build_crash_site(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Scorched glass ground.
	kit.cylinder(20.0, 22.0, 0.18, 16, Vector3(0.0, 0.02, 0.0), &"scorch", Vector3.ZERO, false)
	# Broken hull: the central section is enterable through both torn ends.
	_interior_shell(root, kit, Vector3(-1.0, 0.0, 0.0), Vector3(15.0, 0.0, 4.6), [2, 3], &"ivory", &"steel", 3.6, Color(1.0, 0.55, 0.24), &"glow_ember")
	kit.box(Vector3(16.6, 0.4, 6.0), Vector3(-1.0, 3.85, 0.0), &"rust", Vector3(0.0, 0.18, 0.06), false)
	kit.box(Vector3(0.4, 4.2, 5.4), Vector3(-8.6, 2.3, 0.0), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(0.4, 4.2, 5.4), Vector3(6.6, 2.3, 0.0), &"steel", Vector3.ZERO, false)
	_crates(kit, rng, Vector3(-3.0, 0.0, 0.0), 2)
	kit.box(Vector3(9.0, 3.8, 5.0), Vector3(11.5, 1.9, 2.4), &"rust", Vector3(0.0, -0.35, 0.12))
	kit.box(Vector3(7.0, 3.2, 4.2), Vector3(-11.0, 1.7, -2.0), &"steel", Vector3(0.0, 0.62, -0.05))
	# Cockpit / nose.
	kit.cylinder(0.6, 2.6, 6.0, 8, Vector3(18.0, 1.6, 4.0), &"rust_dark", Vector3(0.0, 0.0, -PI * 0.5), true)
	kit.sphere(1.5, Vector3(-4.0, 4.3, 0.0), &"glass", Vector3.ZERO, false, 8, 4)
	# Torn wing panel and engines.
	kit.box(Vector3(14.0, 0.35, 5.0), Vector3(-4.0, 0.8, -9.0), &"ivory", Vector3(0.1, 0.5, 0.22), true)
	kit.cylinder(1.8, 1.8, 4.5, 10, Vector3(9.0, 1.5, -7.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), true)
	kit.cylinder(1.2, 1.2, 3.6, 8, Vector3(14.0, 1.2, -9.5), &"rust_dark", Vector3(0.3, 0.0, PI * 0.5), true)
	# Debris field (low cover + visual noise).
	for d in 9:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(9.0, 26.0)
		var size := Vector3(rng.randf_range(1.0, 3.4), rng.randf_range(0.5, 2.2), rng.randf_range(1.0, 3.0))
		var dp := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		kit.box(size, dp + Vector3(0.0, size.y * 0.35, 0.0), &"rust" if d % 2 == 0 else &"steel", Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)), false)
	# --- Detail pass: hull interior, salvage services and roof patch --------
	_desk(kit, Vector3(-5.5, 0.0, 0.0), PI * 0.5)
	_locker_bank(kit, Vector3(3.0, 0.0, 1.4), 0.0, 2)
	_screen(kit, Vector3(-1.0, 2.1, -2.05), 0.0)
	_holo_table(kit, Vector3(4.0, 0.0, 0.0), 0.0)
	_cable_run(kit, Vector3(-6.0, 0.0, -1.4), Vector3(4.0, 0.0, -1.4))
	_vent(kit, Vector3(-1.0, 4.0, 2.6), 0.0)
	_pipe_run(kit, Vector3(-7.0, 4.2, 2.6), Vector3(6.0, 4.2, 2.6), 0.18, &"steel")
	_ladder(kit, Vector3(-9.0, 0.0, 3.2), 4.2, 0.0)
	_roof_kit(kit, Vector3(2.0, 0.0, 0.0), Vector2(8.0, 4.0), 4.9)
	_signage(kit, Vector3(4.0, 0.0, 12.0), 0.0, &"glow_amber")
	_hazard_stripes(kit, Vector3(1.0, 0.02, 9.0), 0.0, 4.0, 0.6)
	_water_tank(kit, Vector3(-16.0, 0.0, 7.0), 1.4, 2.8)
	_tarp(kit, Vector3(9.0, 0.0, -7.0), 0.5, 2.6, 2.0)
	_crate_row(kit, Vector3(-15.0, 0.0, -6.0), PI * 0.5, 2, &"steel")
	# Ember glow + wreck beacon.
	kit.sphere(0.8, Vector3(2.0, 1.2, -1.5), &"glow_ember", Vector3.ZERO, false, 6, 3)
	kit.sphere(0.5, Vector3(12.5, 2.0, 3.6), &"glow_ember", Vector3.ZERO, false, 6, 3)
	_antenna(kit, Vector3(-12.0, 1.0, 3.0), 7.0)
	_crates(kit, rng, Vector3(6.0, 0.0, -9.0), 3)
	# Cover ring around the wreck.
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 1.1
		_barrier(kit, Vector3(cos(ang) * 24.0, 0.0, sin(ang) * 24.0), ang + PI * 0.5)
	_add_light(root, Vector3(2.0, 2.0, -1.5), Color(1.0, 0.45, 0.18), 1.6, 14.0)


# =============================================================================
# POI: vault
# =============================================================================
func _build_vault(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 20.0, &"concrete")
	# Bunker facade.
	kit.box(Vector3(13.0, 9.0, 11.0), Vector3(-11.0, 4.6, 0.0), &"ivory")
	kit.box(Vector3(13.0, 9.0, 11.0), Vector3(11.0, 4.6, 0.0), &"ivory")
	kit.box(Vector3(9.0, 4.0, 11.0), Vector3(0.0, 8.0, 0.0), &"ivory_warm")
	kit.box(Vector3(9.4, 0.5, 11.4), Vector3(0.0, 10.2, 0.0), &"rust")
	# Open blast-door frame; the enterable Vault interior sits behind it.
	kit.box(Vector3(10.0, 0.6, 1.2), Vector3(0.0, 7.3, 5.5), &"ivory")
	kit.box(Vector3(10.0, 0.6, 1.2), Vector3(0.0, 0.3, 5.5), &"rust_dark")
	kit.box(Vector3(0.18, 5.0, 0.2), Vector3(-4.6, 3.6, 5.85), &"glow_teal", Vector3.ZERO, false)
	kit.box(Vector3(0.18, 5.0, 0.2), Vector3(4.6, 3.6, 5.85), &"glow_teal", Vector3.ZERO, false)
	kit.box(Vector3(7.4, 0.25, 0.25), Vector3(0.0, 5.2, 5.85), &"glow_amber", Vector3.ZERO, false)
	_interior_shell(root, kit, Vector3(0.0, 0.0, -1.5), Vector3(8.0, 0.0, 11.0), [0], &"ivory", &"concrete", 4.2, Color(0.35, 0.95, 0.85), &"glow_teal")
	_interior_partition(kit, Vector3(0.0, 0.0, -1.5), Vector3(8.0, 0.0, 11.0), 1, -2.0, true, &"ivory_warm", 4.2)
	_crates(kit, rng, Vector3(0.0, 0.0, -5.0), 3)
	_dungeon_anchor(root, Vector3(0.0, 0.5, 7.6))
	# Approach ramp / steps.
	kit.box(Vector3(10.0, 0.7, 3.0), Vector3(0.0, 0.35, 7.4), &"concrete")
	kit.box(Vector3(8.0, 1.4, 2.4), Vector3(0.0, 0.70, 5.9), &"concrete")
	# Buttresses + roof pipes.
	for s in 2:
		var sx := -6.2 if s == 0 else 6.2
		kit.box(Vector3(2.4, 8.0, 2.4), Vector3(sx, 4.0, 5.0), &"rust")
	kit.cylinder(0.5, 0.5, 12.0, 8, Vector3(0.0, 10.8, -3.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	kit.box(Vector3(4.0, 2.6, 3.0), Vector3(-6.0, 1.5, -8.0), &"steel")
	# Facade ribs + vents break up the bunker mass.
	for r in 4:
		var rx := -9.0 + float(r) * 6.0
		kit.box(Vector3(0.7, 8.4, 0.4), Vector3(rx, 4.6, 5.6), &"rust_dark", Vector3.ZERO, false)
		kit.box(Vector3(1.6, 1.0, 0.3), Vector3(rx, 1.6, 5.95), &"dark", Vector3.ZERO, false)
	# Sloped roof caps over the flanking blocks.
	kit.box(Vector3(13.4, 1.2, 11.4), Vector3(-11.0, 10.1, 0.0), &"rust", Vector3(0.0, 0.0, -0.20), false)
	kit.box(Vector3(13.4, 1.2, 11.4), Vector3(11.0, 10.1, 0.0), &"rust", Vector3(0.0, 0.0, 0.20), false)
	kit.cylinder(0.35, 0.35, 10.0, 8, Vector3(-11.0, 11.0, 3.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	kit.cylinder(0.35, 0.35, 10.0, 8, Vector3(11.0, 11.0, 3.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	# Blast-door seal ring + hazard chevrons.
	kit.torus(3.6, 4.0, Vector3(0.0, 3.6, 6.1), &"glow_teal", Vector3(PI * 0.5, 0.0, 0.0), false)
	for h in 3:
		kit.box(Vector3(2.6, 0.35, 0.2), Vector3(-3.2 + float(h) * 3.2, 7.7, 6.0), &"glow_amber", Vector3(0.0, 0.0, 0.35), false)
	_crates(kit, rng, Vector3(6.0, 0.0, 9.0), 4)
	_crates(kit, rng, Vector3(-6.0, 0.0, 10.0), 3)
	for b in 4:
		_barrier(kit, Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(12.0, 19.0)), rng.randf() * TAU)
	# --- Detail pass: vault interior furnishings and facade services --------
	_desk(kit, Vector3(2.4, 0.0, -3.0), PI * 0.5)
	_locker_bank(kit, Vector3(-3.0, 0.0, -5.4), 0.0, 3)
	_shelf(kit, Vector3(3.0, 0.0, -6.0), PI, 1.8, 1.9)
	_screen(kit, Vector3(0.0, 2.2, -6.7), 0.0)
	_holo_table(kit, Vector3(-1.0, 0.0, -1.0), 0.0)
	_cable_run(kit, Vector3(-3.4, 0.0, -2.0), Vector3(3.4, 0.0, -2.0))
	_crate_row(kit, Vector3(2.6, 0.0, 0.6), PI * 0.5, 2, &"ivory_warm")
	_vent(kit, Vector3(-11.0, 2.4, 5.6), 0.0)
	_vent(kit, Vector3(11.0, 2.4, 5.6), 0.0)
	_ladder(kit, Vector3(-6.6, 0.0, 6.2), 9.4, 0.0)
	_pipe_run(kit, Vector3(0.0, 9.4, 5.7), Vector3(0.0, 9.4, -6.0), 0.22, &"steel")
	_signage(kit, Vector3(-3.4, 0.0, 8.6), 0.0, &"glow_teal")
	_hazard_stripes(kit, Vector3(0.0, 0.02, 8.4), 0.0, 5.0, 0.7)
	_water_tank(kit, Vector3(7.5, 0.0, -9.0), 1.5, 3.0)
	_solar_panel(kit, Vector3(11.0, 10.6, 2.0), 0.0)
	kit.box(Vector3(1.4, 0.9, 1.1), Vector3(-11.0, 11.0, -2.0), &"steel")
	_tarp(kit, Vector3(-7.0, 0.0, 10.0), 0.3, 2.4, 2.0)
	_add_light(root, Vector3(0.0, 3.0, 8.0), Color(0.35, 0.95, 0.85), 0.9, 9.0)
	_add_light(root, Vector3(0.0, 6.0, 8.0), Color(1.0, 0.62, 0.22), 1.2, 12.0)


# =============================================================================
# POI: Warden outpost (landmark)
# =============================================================================
func _build_warden_outpost(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Stepped bastion.
	kit.cylinder(26.0, 28.0, 1.6, 12, Vector3(0.0, 0.8, 0.0), &"concrete")
	kit.box(Vector3(34.0, 2.2, 30.0), Vector3(0.0, 2.7, 0.0), &"ivory")
	kit.box(Vector3(24.0, 2.6, 21.0), Vector3(0.0, 5.1, 0.0), &"ivory_warm")
	kit.box(Vector3(14.0, 2.6, 12.0), Vector3(0.0, 7.7, 0.0), &"ivory")
	# Rust trim strips make the stepped layers readable at distance.
	kit.box(Vector3(34.4, 0.35, 30.4), Vector3(0.0, 3.85, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.box(Vector3(24.4, 0.35, 21.4), Vector3(0.0, 6.4, 0.0), &"rust_dark", Vector3.ZERO, false)
	# Angled buttresses around the bastion.
	for b in 4:
		var bang := TAU * float(b) / 4.0 + PI * 0.25
		kit.box(Vector3(2.6, 5.0, 10.0), Vector3(cos(bang) * 13.5, 2.0, sin(bang) * 12.0), &"ivory_warm", Vector3(0.0, -bang, 0.32))
	# Perimeter wall segments with deliberate gate gaps.
	for side in 4:
		for seg in 2:
			var x := 0.0
			var z := 0.0
			var rot := 0.0
			var off := -7.5 + float(seg) * 15.0
			if side == 0:
				x = off
				z = -20.0
			elif side == 1:
				x = off
				z = 20.0
				rot = PI
			elif side == 2:
				x = -20.0
				z = off
				rot = PI * 0.5
			else:
				x = 20.0
				z = off
				rot = PI * 0.5
			kit.box(Vector3(13.0, 3.0, 1.2), Vector3(x, 1.9, z), &"ivory", Vector3(0.0, rot, 0.0))
			kit.box(Vector3(2.0, 3.6, 2.0), Vector3(x + (6.0 if off >= 0.0 else -6.0), 2.2, z), &"rust", Vector3(0.0, rot, 0.0))
	# Monolith command tower ??the landmark silhouette.
	kit.box(Vector3(10.0, 18.0, 10.0), Vector3(0.0, 17.0, 0.0), &"ivory")
	kit.box(Vector3(8.4, 15.0, 8.4), Vector3(0.0, 33.5, 0.0), &"ivory_warm")
	kit.box(Vector3(6.4, 13.0, 6.4), Vector3(0.0, 47.5, 0.0), &"ivory")
	# Vertical dark grooves + rust fins give the tower human scale.
	for g in 4:
		var gang := TAU * float(g) / 4.0 + PI * 0.25
		kit.box(Vector3(0.5, 14.0, 0.5), Vector3(cos(gang) * 5.05, 18.0, sin(gang) * 5.05), &"dark", Vector3.ZERO, false)
	for f in 4:
		var fang := TAU * float(f) / 4.0
		kit.box(Vector3(0.3, 11.0, 2.2), Vector3(cos(fang) * 4.6, 33.5, sin(fang) * 4.6), &"rust", Vector3(0.0, -fang, 0.0), false)
	# Observation decks + antenna crown.
	kit.box(Vector3(11.0, 0.6, 11.0), Vector3(0.0, 26.2, 0.0), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(9.8, 0.5, 9.8), Vector3(0.0, 41.2, 0.0), &"steel", Vector3.ZERO, false)
	kit.cylinder(2.2, 2.2, 0.4, 12, Vector3(5.4, 44.0, -3.2), &"ivory_warm", Vector3(0.4, 0.2, 0.35), false)
	kit.cylinder(0.18, 1.1, 9.0, 7, Vector3(0.0, 58.5, 0.0), &"ivory", Vector3.ZERO, false)
	for a in 3:
		var ay := 52.0 + float(a) * 3.0
		kit.cylinder(0.06, 0.06, 3.2, 4, Vector3(0.0, ay, 0.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	kit.sphere(0.7, Vector3(0.0, 63.5, 0.0), &"glow_amber", Vector3.ZERO, false, 8, 4)
	# The Warden's eye ??big enough to read from the drop zones.
	kit.box(Vector3(3.8, 4.6, 1.2), Vector3(0.0, 38.0, 4.6), &"dark", Vector3.ZERO, false)
	kit.sphere(1.5, Vector3(0.0, 38.0, 5.3), &"warden_eye", Vector3.ZERO, false, 12, 6)
	kit.box(Vector3(4.2, 0.4, 1.0), Vector3(0.0, 40.6, 4.9), &"rust", Vector3.ZERO, false)
	# Faction banners flank the approach.
	_banner(kit, Vector3(9.0, 3.9, 13.0), 0.5, &"rust")
	_banner(kit, Vector3(-9.0, 3.9, 13.0), -0.5, &"rust_dark")
	# Barracks + support structures on the lower tier.
	kit.box(Vector3(11.0, 3.4, 6.0), Vector3(-11.0, 6.0, 8.0), &"ivory")
	kit.box(Vector3(11.6, 0.4, 6.6), Vector3(-11.0, 7.9, 8.0), &"rust_dark")
	kit.box(Vector3(9.0, 3.0, 5.0), Vector3(11.5, 5.8, -8.0), &"ivory_warm")
	_antenna(kit, Vector3(12.5, 7.3, -8.0), 12.0)
	_crates(kit, rng, Vector3(-9.0, 3.9, -6.0), 3)
	# Courtyard cover: hardened blocks, deliberately leaving lanes open.
	for c in 5:
		var ang := TAU * float(c) / 5.0 + 0.35
		var r := 6.5 + float(c % 2) * 3.0
		kit.box(Vector3(3.2, 1.4, 1.6), Vector3(cos(ang) * r, 4.5, sin(ang) * r), &"concrete", Vector3(0.0, ang, 0.0))
	# --- Detail pass: courtyard consoles, barracks roof kit, deck rails ------
	_desk(kit, Vector3(-4.0, 3.8, 5.0), 0.0)
	_screen(kit, Vector3(-5.4, 5.6, 8.0), -PI * 0.5)
	_locker_bank(kit, Vector3(2.0, 3.8, 5.0), 0.0, 2)
	_holo_table(kit, Vector3(0.0, 3.8, 4.0), 0.0)
	_cable_run(kit, Vector3(-3.0, 3.8, 4.5), Vector3(3.0, 3.8, 4.5))
	_roof_kit(kit, Vector3(-11.0, 0.0, 8.0), Vector2(8.0, 4.5), 8.0)
	_solar_panel(kit, Vector3(11.5, 7.35, -8.0), 0.0)
	_vent(kit, Vector3(0.0, 9.1, 6.9), 0.0)
	_ladder(kit, Vector3(-11.0, 3.8, 11.2), 4.0, 0.0)
	_railing(kit, Vector3(-4.0, 26.5, -4.0), Vector3(4.0, 26.5, -4.0), 0.9, 3)
	_railing(kit, Vector3(-4.0, 26.5, 4.0), Vector3(4.0, 26.5, 4.0), 0.9, 3)
	_railing(kit, Vector3(-4.0, 41.5, -4.0), Vector3(4.0, 41.5, -4.0), 0.9, 3)
	_railing(kit, Vector3(-4.0, 41.5, 4.0), Vector3(4.0, 41.5, 4.0), 0.9, 3)
	_pipe_run(kit, Vector3(5.2, 4.0, 0.0), Vector3(5.2, 26.0, 0.0), 0.2, &"steel")
	_signage(kit, Vector3(4.5, 3.8, 12.0), 0.0, &"glow_amber")
	_crate_row(kit, Vector3(-6.0, 3.8, -4.0), PI * 0.5, 3, &"rust")
	_water_tank(kit, Vector3(13.0, 3.8, 10.0), 1.5, 3.0)
	# Lamps on the ramp corners.
	_lamp(kit, Vector3(-13.0, 3.9, 13.0), &"glow_teal")
	_lamp(kit, Vector3(13.0, 3.9, 13.0), &"glow_amber")
	_add_light(root, Vector3(0.0, 38.0, 6.0), Color(0.30, 0.95, 0.88), 1.5, 34.0)
	_add_light(root, Vector3(0.0, 6.0, 12.0), Color(1.0, 0.72, 0.40), 1.0, 14.0)


# =============================================================================
# POI: anomaly
# =============================================================================
func _build_anomaly(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Vitrified ground and a ring of leaning monoliths.
	kit.cylinder(17.0, 19.0, 0.22, 18, Vector3(0.0, 0.04, 0.0), &"scorch", Vector3.ZERO, false)
	for m in 7:
		var ang := TAU * float(m) / 7.0
		var pos := Vector3(cos(ang) * 15.0, 4.4, sin(ang) * 15.0)
		kit.box(Vector3(1.6, 9.0, 2.6), pos, &"alien_dark", Vector3(0.18 * cos(ang), ang, -0.16 * sin(ang)))
		kit.sphere(0.35, pos + Vector3(0.0, 4.8, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# The hovering core and its shards.
	kit.sphere(2.2, Vector3(0.0, 7.5, 0.0), &"glow_teal", Vector3.ZERO, false, 12, 8)
	kit.torus(3.2, 3.9, Vector3(0.0, 7.5, 0.0), &"glow_teal", Vector3(0.6, 0.3, 0.2), false)
	kit.torus(4.6, 5.1, Vector3(0.0, 7.5, 0.0), &"glow_teal", Vector3(-0.4, 0.9, 0.5), false)
	for s in 7:
		var ang := TAU * float(s) / 7.0 + 0.4
		var dist := rng.randf_range(5.0, 11.0)
		var y := rng.randf_range(3.0, 13.0)
		kit.box(Vector3(rng.randf_range(0.6, 1.8), rng.randf_range(0.6, 2.6), rng.randf_range(0.6, 1.6)), Vector3(cos(ang) * dist, y, sin(ang) * dist), &"alien", Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU), false)
	# Field emitters anchoring the anomaly (cover).
	for e in 3:
		var ang := TAU * float(e) / 3.0 + 0.2
		var ep := Vector3(cos(ang) * 12.0, 0.0, sin(ang) * 12.0)
		kit.cylinder(2.4, 3.0, 1.0, 8, ep + Vector3(0.0, 0.45, 0.0), &"ivory")
		kit.box(Vector3(1.4, 3.0, 1.4), ep + Vector3(0.0, 2.4, 0.0), &"ivory_warm")
		kit.sphere(0.45, ep + Vector3(0.0, 4.2, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	_crates(kit, rng, Vector3(8.0, 0.0, -8.0), 3)
	# --- Detail pass: survey camp, sensor mast and alien conduits -----------
	_desk(kit, Vector3(10.0, 0.0, -4.0), PI * 0.5)
	_screen(kit, Vector3(12.0, 1.7, -4.0), PI * 0.5)
	_locker_bank(kit, Vector3(-11.0, 0.0, 4.0), 0.0, 2)
	_holo_table(kit, Vector3(7.0, 0.0, 7.0), 0.0)
	_crate_row(kit, Vector3(-9.0, 0.0, -6.0), PI * 0.5, 2, &"ivory_warm")
	_tarp(kit, Vector3(12.0, 0.0, 7.0), 0.6, 2.4, 2.0)
	_pipe_run(kit, Vector3(9.6, 0.8, -6.0), Vector3(13.0, 0.8, -10.0), 0.14, &"alien_dark")
	_pipe_run(kit, Vector3(-8.0, 0.8, 5.0), Vector3(-11.4, 0.8, 3.0), 0.14, &"alien_dark")
	_cable_run(kit, Vector3(-8.0, 0.0, 5.2), Vector3(-11.0, 0.0, 7.0))
	_signage(kit, Vector3(5.0, 0.0, 10.0), 0.0, &"glow_teal")
	_solar_panel(kit, Vector3(-11.0, 0.0, 8.0), 0.0)
	_vent(kit, Vector3(9.0, 1.3, -4.0), 0.0, Vector3(0.8, 0.5, 0.35))
	_planter(kit, Vector3(2.0, 0.0, -12.0), 0.0)
	_add_light(root, Vector3(0.0, 7.0, 0.0), Color(0.30, 1.0, 0.86), 2.2, 26.0)
	_add_light(root, Vector3(0.0, 1.0, 0.0), Color(0.20, 0.70, 0.75), 0.8, 10.0)


# =============================================================================
# POI: ruin field
# =============================================================================
func _build_ruin_field(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 17.0, &"ivory_warm")
	# Broken ceremonial arches.
	for a in 3:
		var ang := TAU * float(a) / 3.0 + 0.7
		var center := Vector3(cos(ang) * 12.0, 0.0, sin(ang) * 12.0)
		var tangent := Vector3(-sin(ang), 0.0, cos(ang))
		var half := 4.5
		var left := center - tangent * half
		var right := center + tangent * half
		var h_left := rng.randf_range(6.0, 9.0)
		var h_right := rng.randf_range(3.5, 8.5)
		kit.cylinder(1.1, 1.35, h_left, 8, left + Vector3(0.0, h_left * 0.5, 0.0), &"ivory_warm")
		kit.cylinder(1.1, 1.35, h_right, 8, right + Vector3(0.0, h_right * 0.5, 0.0), &"ivory_warm")
		if rng.randf() > 0.35:
			kit.box(Vector3(10.0, 1.0, 1.6), Vector3(center.x, minf(h_left, h_right) + 0.4, center.z), &"ivory", Vector3(0.0, -ang, rng.randf_range(-0.12, 0.12)))
	# Scattered fallen columns and slabs.
	for c in 10:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(5.0, 22.0)
		var p := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		if c % 3 == 0:
			kit.cylinder(1.0, 1.0, rng.randf_range(3.0, 6.0), 8, p + Vector3(0.0, 0.6, 0.0), &"ivory", Vector3(PI * 0.5, rng.randf() * TAU, 0.0))
		else:
			kit.box(Vector3(rng.randf_range(3.0, 6.5), 0.7, rng.randf_range(2.0, 4.0)), p + Vector3(0.0, 0.2, 0.0), &"concrete", Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))
	# Alien growth reclaiming the plaza.
	for g in 8:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(3.0, 15.0)
		var p := Vector3(cos(ang) * dist, 0.25, sin(ang) * dist)
		kit.sphere(rng.randf_range(0.3, 0.8), p, &"glow_teal", Vector3.ZERO, false, 6, 3)
	_crates(kit, rng, Vector3(-8.0, 0.0, 6.0), 2)
	# A single tall surviving obelisk.
	kit.box(Vector3(2.2, 16.0, 2.2), Vector3(-4.0, 8.0, -3.0), &"ivory", Vector3(0.04, 0.3, -0.03))
	kit.sphere(0.5, Vector3(-4.0, 16.4, -3.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# --- Detail pass: survey camp in the archive plaza ----------------------
	_desk(kit, Vector3(-12.0, 0.0, -7.0), 0.0)
	_shelf(kit, Vector3(-13.2, 0.0, -5.0), 0.0, 1.5, 1.7)
	_locker_bank(kit, Vector3(-10.5, 0.0, -9.5), 0.0, 2)
	_holo_table(kit, Vector3(-7.0, 0.0, -9.0), 0.0)
	_awning(kit, Vector3(-11.0, 0.0, -6.0), 0.0, 3.6, 2.2)
	_crate_row(kit, Vector3(-14.0, 0.0, -4.0), PI * 0.5, 2, &"ivory_warm")
	_cable_run(kit, Vector3(-12.0, 0.0, -6.0), Vector3(-8.0, 0.0, -2.0))
	_ladder(kit, Vector3(-6.0, 0.0, -2.0), 5.0, 0.0)
	_signage(kit, Vector3(0.0, 0.0, 8.0), 0.0, &"glow_amber")
	_solar_panel(kit, Vector3(-11.0, 0.0, -11.0), 0.0)
	_tarp(kit, Vector3(-16.0, 0.0, -9.0), 0.3, 2.4, 2.0)
	_vent(kit, Vector3(-10.0, 1.3, -7.0), 0.0, Vector3(0.8, 0.5, 0.35))
	_planter(kit, Vector3(-9.0, 0.0, 12.0), 0.0)
	_add_light(root, Vector3(-4.0, 12.0, -3.0), Color(0.30, 0.95, 0.85), 0.9, 14.0)


# =============================================================================
# POI: exfil pad
# =============================================================================
func _build_exfil_pad(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Landing platform with a rust rim.
	kit.cylinder(17.0, 18.0, 0.9, 24, Vector3(0.0, 0.35, 0.0), &"pad")
	kit.cylinder(18.2, 18.6, 0.5, 24, Vector3(0.0, 0.2, 0.0), &"rust_dark")
	# Landing markings: ring, cross bars, chevrons.
	kit.torus(9.4, 10.2, Vector3(0.0, 0.82, 0.0), &"glow_amber", Vector3.ZERO, false)
	for i in 4:
		var ang := TAU * float(i) / 4.0
		kit.box(Vector3(7.0, 0.06, 0.55), Vector3(cos(ang) * 6.6, 0.83, sin(ang) * 6.6), &"steel", Vector3(0.0, -ang, 0.0), false)
	# Amber perimeter marker lights.
	for m in 12:
		var ang := TAU * float(m) / 12.0
		var p := Vector3(cos(ang) * 15.0, 0.95, sin(ang) * 15.0)
		kit.box(Vector3(0.55, 0.5, 0.55), p, &"glow_amber", Vector3.ZERO, false)
	# Corner pylons.
	for c in 4:
		var ang := TAU * float(c) / 4.0 + PI * 0.25
		var p := Vector3(cos(ang) * 16.0, 0.0, sin(ang) * 16.0)
		kit.box(Vector3(1.4, 4.6, 1.4), p + Vector3(0.0, 2.3, 0.0), &"ivory")
		kit.box(Vector3(1.7, 0.3, 1.7), p + Vector3(0.0, 4.7, 0.0), &"glow_teal", Vector3.ZERO, false)
	# Beacon mast ??visible from across the frontier.
	kit.box(Vector3(3.0, 1.4, 3.0), Vector3(0.0, 0.9, -11.0), &"concrete")
	kit.cylinder(0.22, 0.5, 24.0, 7, Vector3(0.0, 13.0, -11.0), &"steel", Vector3.ZERO, false)
	for r in 3:
		var y := 6.0 + float(r) * 6.5
		kit.cylinder(0.06, 0.06, 2.6, 4, Vector3(0.0, y, -11.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	kit.sphere(0.9, Vector3(0.0, 25.6, -11.0), &"glow_amber", Vector3.ZERO, false, 8, 4)
	# Shelter hab + supply crates.
	kit.box(Vector3(9.0, 3.2, 6.0), Vector3(-13.0, 1.8, 12.0), &"ivory_warm")
	kit.box(Vector3(9.6, 0.35, 6.6), Vector3(-13.0, 3.6, 12.0), &"rust")
	kit.box(Vector3(1.8, 2.2, 0.3), Vector3(-13.0, 1.3, 8.9), &"dark")
	_crates(kit, rng, Vector3(9.0, 0.8, 10.0), 4)
	_crates(kit, rng, Vector3(13.0, 0.8, -6.0), 2)
	for b in 3:
		var ang := TAU * float(b) / 3.0 + 2.2
		_barrier(kit, Vector3(cos(ang) * 20.0, 0.0, sin(ang) * 20.0), ang + PI * 0.5)
	# --- Detail pass: pad-side services and shelter roof --------------------
	_roof_kit(kit, Vector3(-13.0, 0.0, 12.0), Vector2(7.0, 4.5), 3.8)
	_awning(kit, Vector3(-13.0, 0.0, 8.8), PI, 4.6, 2.2)
	_vent(kit, Vector3(-13.0, 1.9, 14.6), 0.0)
	_ladder(kit, Vector3(-17.6, 0.0, 12.0), 3.8, 0.0)
	_cable_run(kit, Vector3(-8.5, 0.0, 13.0), Vector3(-6.0, 0.0, 17.5))
	_pipe_run(kit, Vector3(-13.0, 0.6, 9.0), Vector3(-13.0, 3.8, 9.0), 0.16, &"steel")
	_signage(kit, Vector3(4.0, 0.8, 14.0), 0.0, &"glow_teal")
	_crate_row(kit, Vector3(9.0, 0.8, 10.0), 0.0, 3, &"ivory_warm")
	_water_tank(kit, Vector3(14.0, 0.8, 9.0), 1.4, 2.8)
	_solar_panel(kit, Vector3(-17.0, 3.8, 12.0), PI * 0.5)
	_holo_table(kit, Vector3(6.0, 0.82, -4.0), 0.0)
	_tarp(kit, Vector3(11.0, 0.8, -9.0), 0.4, 2.4, 2.0)
	_add_light(root, Vector3(0.0, 26.0, -11.0), Color(1.0, 0.62, 0.22), 2.2, 40.0)
	_add_light(root, Vector3(0.0, 2.0, 0.0), Color(1.0, 0.70, 0.35), 0.8, 12.0)


# =============================================================================
# Spawn: drop pod
# =============================================================================
func _build_drop_pod(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.cylinder(11.0, 13.0, 0.14, 14, Vector3(0.0, 0.05, 0.0), &"scorch", Vector3.ZERO, false)
	# Pod body, half-buried and canted ??offset so the drop zone center stays
	# clear for spawning.
	var tilt := Vector3(0.30, 0.2, -0.22)
	var pod_rot := Basis.from_euler(tilt)
	var pod_off := Vector3(7.0, 0.0, -7.5)
	kit.cylinder(2.3, 2.7, 5.6, 10, pod_off + pod_rot * Vector3(0.0, 2.4, 0.0), &"ivory", tilt)
	kit.cylinder(0.9, 2.3, 2.2, 10, pod_off + pod_rot * Vector3(0.0, 6.2, 0.0), &"rust", tilt, true)
	kit.cylinder(0.35, 0.9, 0.8, 8, pod_off + pod_rot * Vector3(0.0, 7.7, 0.0), &"steel", tilt, false)
	kit.box(Vector3(1.4, 2.0, 0.3), pod_off + pod_rot * Vector3(0.0, 2.8, 2.5), &"dark", tilt, false)
	# Landing fins torn up around the impact.
	for fin in 4:
		var fang := TAU * float(fin) / 4.0 + 0.4
		var fin_pos := pod_off + pod_rot * Vector3(cos(fang) * 2.6, 0.6, sin(fang) * 2.6)
		kit.box(Vector3(0.5, 2.0, 1.3), fin_pos, &"rust", Vector3(0.5, -fang, 0.35), true)
	# Debris ribs torn off the pod (cover).
	kit.box(Vector3(4.2, 0.5, 1.1), pod_off + Vector3(-4.6, 0.35, 2.0), &"steel", Vector3(0.1, 0.4, 0.2), true)
	# Storage racks ejected around the pod.
	_crates(kit, rng, Vector3(9.0, 0.0, 4.0), 3)
	_crates(kit, rng, Vector3(-5.5, 0.0, -6.0), 2)
	# Drop beacon (teal, on the opposite side of the landing circle).
	kit.box(Vector3(1.2, 0.6, 1.2), Vector3(-7.0, 0.3, 6.0), &"concrete")
	kit.cylinder(0.12, 0.25, 6.0, 6, Vector3(-7.0, 3.3, 6.0), &"steel", Vector3.ZERO, false)
	kit.sphere(0.6, Vector3(-7.0, 6.5, 6.0), &"glow_teal", Vector3.ZERO, false, 8, 4)
	# Light cover at the edge of the drop zone.
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.7
		_barrier(kit, Vector3(cos(ang) * 14.0, 0.0, sin(ang) * 14.0), ang + PI * 0.5)
	_add_light(root, Vector3(-7.0, 6.5, 6.0), Color(0.35, 0.95, 0.85), 1.0, 16.0)


# =============================================================================
# POI: ashen stockade
# =============================================================================
func _build_ashen_stockade(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 22.0, &"pad")
	# Palisade ring with two deliberate gate gaps.
	for side in 4:
		for seg in 3:
			var off := -13.0 + float(seg) * 13.0
			if side in [0, 1] and seg == 1:
				continue
			var pos := Vector3.ZERO
			var rot := 0.0
			match side:
				0:
					pos = Vector3(off, 1.4, -20.0)
				1:
					pos = Vector3(off, 1.4, 20.0)
				2:
					pos = Vector3(-20.0, 1.4, off)
					rot = PI * 0.5
				_:
					pos = Vector3(20.0, 1.4, off)
					rot = PI * 0.5
			kit.box(Vector3(10.5, 2.8, 0.9), pos, &"rust", Vector3(0.0, rot, 0.0))
			kit.cylinder(0.22, 0.28, 3.6, 6, pos + Vector3(0.0, 0.3, 0.0), &"steel", Vector3(0.0, rot, 0.0), false)
			kit.box(Vector3(0.9, 0.35, 0.9), pos + Vector3(-4.2, 1.7, 0.0), &"glow_ember", Vector3(0.0, rot, 0.0), false)
	# Corner towers.
	for corner in 4:
		var angle := TAU * float(corner) / 4.0 + PI * 0.25
		var tower_pos := Vector3(cos(angle) * 20.0, 0.0, sin(angle) * 20.0)
		_watchtower(kit, tower_pos, -angle)
		kit.box(Vector3(2.2, 2.2, 2.2), tower_pos + Vector3(0.0, 8.6, 0.0), &"rust_dark", Vector3(0.0, -angle, 0.0))
	# Enterable command hall and cages.
	_interior_shell(root, kit, Vector3(0.0, 0.0, -7.5), Vector3(13.0, 0.0, 8.0), [0], &"rust", &"concrete", 3.8, Color(1.0, 0.42, 0.18), &"glow_ember")
	kit.box(Vector3(14.6, 0.5, 9.6), Vector3(0.0, 4.15, -7.5), &"rust_dark")
	_interior_partition(kit, Vector3(0.0, 0.0, -7.5), Vector3(13.0, 0.0, 8.0), 0, -1.8, true, &"rust_dark", 3.8)
	_crates(kit, rng, Vector3(3.0, 0.0, -9.0), 2)
	_dungeon_anchor(root, Vector3(0.0, 0.5, -2.0))
	for cage in 3:
		var cage_x := -9.0 + float(cage) * 9.0
		kit.box(Vector3(3.4, 2.4, 3.4), Vector3(cage_x, 1.3, 8.0), &"steel")
		for bar in 4:
			kit.cylinder(0.05, 0.05, 2.2, 4, Vector3(cage_x - 1.4 + float(bar) * 0.9, 1.3, 6.3), &"steel", Vector3.ZERO, false)
	# Cover and loot.
	_container(kit, Vector3(-15.0, 1.35, 2.0), 0.2, &"rust")
	_container(kit, Vector3(15.0, 1.35, 3.0), -0.3, &"steel")
	_crates(kit, rng, Vector3(5.0, 0.0, 4.0), 4)
	_crates(kit, rng, Vector3(-6.0, 0.0, 2.0), 3)
	for b in 5:
		var ang := TAU * float(b) / 5.0 + 0.3
		_barrier(kit, Vector3(cos(ang) * 16.0, 0.0, sin(ang) * 16.0), ang + PI * 0.5)
	_banner(kit, Vector3(-6.0, 2.2, -1.0), 0.2, &"rust")
	_banner(kit, Vector3(6.0, 2.2, -1.0), -0.2, &"rust_dark")
	_lamp(kit, Vector3(0.0, 4.2, -2.0), &"glow_ember")
	# --- Detail pass: command hall furnishing, roof kit and gate services ---
	_bunk(kit, Vector3(-4.6, 0.0, -8.8), 0.0)
	_bunk(kit, Vector3(-4.6, 0.0, -5.8), 0.0)
	_desk(kit, Vector3(2.8, 0.0, -4.6), PI)
	_locker_bank(kit, Vector3(5.0, 0.0, -4.6), 0.0, 2)
	_shelf(kit, Vector3(-4.6, 0.0, -4.2), 0.0, 1.6, 1.7)
	_screen(kit, Vector3(-4.6, 2.1, -11.2), 0.0)
	_cable_run(kit, Vector3(-5.2, 0.0, -7.2), Vector3(5.2, 0.0, -7.2))
	_roof_kit(kit, Vector3(0.0, 0.0, -7.5), Vector2(11.0, 7.0), 4.45)
	_awning(kit, Vector3(0.0, 0.0, -3.4), 0.0, 4.6, 2.4)
	_vent(kit, Vector3(-6.6, 2.2, -7.5), PI * 0.5)
	_ladder(kit, Vector3(6.9, 0.0, -7.5), 4.3, 0.0)
	_signage(kit, Vector3(0.0, 0.0, 3.0), 0.0, &"glow_amber")
	_hazard_stripes(kit, Vector3(0.0, 0.02, -1.6), 0.0, 4.5, 0.7)
	_tarp(kit, Vector3(-6.5, 0.0, 8.0), 0.2, 2.4, 2.0)
	_water_tank(kit, Vector3(14.0, 0.0, 12.0), 1.5, 3.0)
	_crate_row(kit, Vector3(8.0, 0.0, 1.0), 0.0, 3, &"rust")
	_add_light(root, Vector3(0.0, 3.0, -6.0), Color(1.0, 0.42, 0.18), 1.4, 14.0)
	_add_light(root, Vector3(0.0, 6.0, 6.0), Color(1.0, 0.62, 0.28), 0.9, 10.0)


# =============================================================================
# POI: bloom hive
# =============================================================================
func _build_bloom_hive(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.cylinder(20.0, 22.0, 0.2, 18, Vector3(0.0, 0.05, 0.0), &"scorch", Vector3.ZERO, true)
	# Leaning spires around a central membrane.
	for spire in 6:
		var angle := TAU * float(spire) / 6.0 + 0.2
		var base := Vector3(cos(angle) * 12.0, 0.0, sin(angle) * 12.0)
		var height := rng.randf_range(10.0, 19.0)
		var lean := Vector3(cos(angle) * -0.12, 0.0, sin(angle) * -0.12)
		kit.cylinder(0.6, 2.4, height, 8, base + Vector3(0.0, height * 0.5, 0.0), &"alien_dark", lean, true)
		kit.sphere(1.5, base + Vector3(0.0, height, 0.0), &"glow_teal", Vector3.ZERO, false, 8, 4)
		kit.torus(2.4, 3.1, base + Vector3(0.0, height - 2.0, 0.0), &"alien", Vector3(0.4, angle, 0.2), false)
	# Central organic mound and pod clusters.
	kit.cylinder(4.0, 7.0, 3.2, 10, Vector3(0.0, 1.6, 0.0), &"alien", Vector3.ZERO, true)
	kit.sphere(3.2, Vector3(0.0, 4.6, 0.0), &"alien_dark", Vector3.ZERO, true, 10, 6)
	for pod in 7:
		var angle := TAU * float(pod) / 7.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(6.0, 11.0)
		var p := Vector3(cos(angle) * dist, rng.randf_range(0.4, 1.4), sin(angle) * dist)
		kit.sphere(rng.randf_range(1.0, 2.0), p, &"alien", Vector3.ZERO, false, 8, 4)
		kit.sphere(0.35, p + Vector3(0.0, 1.0, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# Membrane canopy over the centre.
	kit.torus(7.5, 8.2, Vector3(0.0, 7.5, 0.0), &"glow_teal", Vector3(0.1, 0.2, 0.0), false)
	kit.torus(5.2, 5.8, Vector3(0.0, 9.2, 0.0), &"glow_teal", Vector3(-0.2, 0.6, 0.1), false)
	# Bone arches (cover).
	for arch in 3:
		var angle := TAU * float(arch) / 3.0 + 1.0
		var center := Vector3(cos(angle) * 16.0, 0.0, sin(angle) * 16.0)
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		kit.cylinder(0.7, 1.0, 5.0, 7, center - tangent * 4.0 + Vector3(0.0, 2.5, 0.0), &"alien_dark", Vector3(0.0, 0.0, 0.12), true)
		kit.cylinder(0.7, 1.0, 4.2, 7, center + tangent * 4.0 + Vector3(0.0, 2.1, 0.0), &"alien_dark", Vector3(0.0, 0.0, -0.15), true)
		kit.box(Vector3(8.0, 0.7, 0.9), center + Vector3(0.0, 4.6, 0.0), &"alien", Vector3(0.0, -angle, 0.1), true)
	_crates(kit, rng, Vector3(13.0, 0.0, -7.0), 2)
	# --- Detail pass: survey station and salvage at the hive edge -----------
	_desk(kit, Vector3(14.0, 0.0, 8.0), PI * 0.5)
	_screen(kit, Vector3(16.0, 1.7, 8.0), PI * 0.5)
	_holo_table(kit, Vector3(-6.0, 0.0, 12.0), 0.0)
	_locker_bank(kit, Vector3(-13.0, 0.0, 10.0), PI, 2)
	_crate_row(kit, Vector3(-12.0, 0.0, -10.0), PI * 0.5, 2, &"steel")
	_tarp(kit, Vector3(15.0, 0.0, -4.0), 0.4, 2.6, 2.0)
	_cable_run(kit, Vector3(13.0, 0.0, 9.0), Vector3(9.0, 0.0, 4.0))
	_pipe_run(kit, Vector3(12.0, 1.0, 10.0), Vector3(6.0, 1.0, 6.0), 0.16, &"alien_dark")
	_signage(kit, Vector3(0.0, 0.0, 15.0), 0.0, &"glow_ember")
	_vent(kit, Vector3(14.0, 1.3, 8.0), 0.0, Vector3(0.8, 0.5, 0.35))
	_planter(kit, Vector3(-9.0, 0.0, 14.0), 0.0)
	_solar_panel(kit, Vector3(-9.0, 0.0, 3.0), 0.0)
	_railing(kit, Vector3(-4.0, 0.0, -14.0), Vector3(4.0, 0.0, -14.0), 0.9, 3)
	_add_light(root, Vector3(0.0, 5.0, 0.0), Color(0.45, 1.0, 0.82), 2.2, 24.0)
	_add_light(root, Vector3(0.0, 9.0, 0.0), Color(0.70, 0.45, 1.0), 1.3, 16.0)


# =============================================================================
# POI: choir listening post
# =============================================================================
func _build_choir_post(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 18.0, &"concrete")
	# Enterable bunker and dish mast.
	_interior_shell(root, kit, Vector3(0.0, 0.0, -4.0), Vector3(11.0, 0.0, 7.0), [0], &"ivory", &"concrete", 3.2, Color(0.35, 0.95, 1.0), &"glow_teal")
	kit.box(Vector3(12.6, 0.4, 8.4), Vector3(0.0, 3.4, -4.0), &"steel")
	_interior_partition(kit, Vector3(0.0, 0.0, -4.0), Vector3(11.0, 0.0, 7.0), 0, -1.5, true, &"ivory_warm", 3.2)
	_crates(kit, rng, Vector3(-3.0, 0.0, -5.0), 2)
	_dungeon_anchor(root, Vector3(0.0, 0.5, 1.5))
	kit.cylinder(0.8, 0.8, 10.0, 8, Vector3(0.0, 8.0, -4.0), &"steel", Vector3.ZERO, true)
	kit.cylinder(5.0, 5.0, 0.5, 16, Vector3(0.0, 13.4, -4.0), &"ivory_warm", Vector3(0.7, 0.3, 0.1), true)
	kit.cylinder(0.3, 0.3, 3.0, 6, Vector3(0.0, 13.4, -8.6), &"steel", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Signal pylon ring.
	for pylon in 6:
		var angle := TAU * float(pylon) / 6.0
		var p := Vector3(cos(angle) * 15.0, 0.0, sin(angle) * 15.0)
		kit.cylinder(0.28, 0.45, 7.0, 6, p + Vector3(0.0, 3.5, 0.0), &"ivory", Vector3(0.0, angle, 0.0), true)
		kit.sphere(0.42, p + Vector3(0.0, 7.3, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
		kit.box(Vector3(2.0, 0.25, 0.25), p + Vector3(0.0, 5.4, 0.0), &"steel", Vector3(0.0, angle, 0.0), false)
	# Antenna web and equipment.
	for a in 3:
		var angle := TAU * float(a) / 3.0 + 0.5
		_antenna(kit, Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0), rng.randf_range(8.0, 13.0))
	kit.box(Vector3(3.0, 1.8, 2.0), Vector3(8.0, 0.9, 2.0), &"steel")
	kit.box(Vector3(1.4, 0.3, 0.14), Vector3(8.0, 2.1, 2.0), &"glow_teal", Vector3.ZERO, false)
	_crates(kit, rng, Vector3(-8.0, 0.0, 4.0), 3)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.8
		_barrier(kit, Vector3(cos(ang) * 20.0, 0.0, sin(ang) * 20.0), ang + PI * 0.5)
	# --- Detail pass: bunker furnishing and mast services -------------------
	_desk(kit, Vector3(-3.4, 0.0, -6.0), PI * 0.5)
	_locker_bank(kit, Vector3(3.4, 0.0, -6.4), 0.0, 2)
	_shelf(kit, Vector3(-4.6, 0.0, -2.0), 0.0, 1.6, 1.8)
	_holo_table(kit, Vector3(1.0, 0.0, -2.0), 0.0)
	_screen(kit, Vector3(0.0, 2.0, -7.3), 0.0)
	_cable_run(kit, Vector3(-4.4, 0.0, -3.6), Vector3(4.4, 0.0, -3.6))
	_roof_kit(kit, Vector3(0.0, 0.0, -4.0), Vector2(9.0, 6.0), 3.7)
	_pipe_run(kit, Vector3(-5.6, 0.4, -4.0), Vector3(-5.6, 3.4, -4.0), 0.16, &"steel")
	_pipe_run(kit, Vector3(-5.6, 3.3, -4.0), Vector3(0.0, 7.6, -4.0), 0.14, &"steel")
	_ladder(kit, Vector3(5.8, 0.0, -4.0), 3.6, 0.0)
	_signage(kit, Vector3(5.0, 0.0, 5.0), 0.0, &"glow_teal")
	_vent(kit, Vector3(-6.4, 2.2, -6.0), PI * 0.5)
	_water_tank(kit, Vector3(-11.0, 0.0, 8.0), 1.4, 2.8)
	_solar_panel(kit, Vector3(3.5, 3.7, -4.0), 0.0)
	_add_light(root, Vector3(0.0, 14.0, -4.0), Color(0.35, 0.95, 1.0), 2.0, 30.0)
	_add_light(root, Vector3(8.0, 2.0, 2.0), Color(0.45, 1.0, 0.85), 0.8, 8.0)


# =============================================================================
# POI: colony ruins
# =============================================================================
func _build_colony_ruins(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 20.0, &"concrete")
	# Broken hab blocks arranged around a street; the western block is enterable.
	_interior_shell(root, kit, Vector3(-11.0, 0.0, -4.0), Vector3(11.0, 0.0, 8.0), [2], &"ivory", &"concrete", 3.8, Color(1.0, 0.68, 0.35), &"glow_amber")
	kit.box(Vector3(12.6, 0.4, 9.4), Vector3(-11.0, 3.95, -4.0), &"rust_dark")
	_interior_partition(kit, Vector3(-11.0, 0.0, -4.0), Vector3(11.0, 0.0, 8.0), 0, 2.0, true, &"ivory_warm", 3.8)
	_crates(kit, rng, Vector3(-13.0, 0.0, -6.0), 2)
	_dungeon_anchor(root, Vector3(-5.4, 0.5, -4.0))
	kit.box(Vector3(4.0, 5.0, 9.0), Vector3(-5.0, 2.5, -4.0), &"ivory_warm")
	kit.box(Vector3(9.0, 3.4, 7.0), Vector3(-12.0, 1.7, 8.0), &"concrete")
	kit.box(Vector3(11.0, 6.5, 8.0), Vector3(11.0, 3.25, 5.0), &"ivory")
	kit.box(Vector3(11.0, 2.8, 0.5), Vector3(11.0, 6.6, 8.9), &"rust", Vector3(0.0, 0.0, 0.12), false)
	kit.box(Vector3(0.6, 6.5, 8.0), Vector3(5.8, 3.25, 5.0), &"dark", Vector3.ZERO, false)
	# Street slabs and a toppled tower.
	for slab in 5:
		kit.box(Vector3(4.0, 0.2, 4.0), Vector3(rng.randf_range(-14.0, 14.0), 0.15, rng.randf_range(-2.0, 14.0)), &"concrete", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	kit.cylinder(1.2, 1.6, 18.0, 8, Vector3(0.0, 2.0, 16.0), &"ivory_warm", Vector3(0.42, 0.3, 0.1), true)
	kit.cylinder(1.0, 1.2, 7.0, 8, Vector3(4.0, 1.0, 18.0), &"ivory", Vector3(0.1, 0.6, 1.2), true)
	# Ruined walls and street clutter.
	for wall in 6:
		var angle := TAU * float(wall) / 6.0 + 0.4
		var p := Vector3(cos(angle) * 19.0, 0.0, sin(angle) * 19.0)
		kit.box(Vector3(7.0, 2.4, 0.7), p + Vector3(0.0, 1.2, 0.0), &"ivory", Vector3(0.0, angle, 0.12))
	_crates(kit, rng, Vector3(8.0, 0.0, -8.0), 4)
	_crates(kit, rng, Vector3(-8.0, 0.0, -12.0), 2)
	for b in 4:
		_barrier(kit, Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-16.0, 16.0)), rng.randf() * TAU)
	_banner(kit, Vector3(2.0, 0.0, 12.0), 0.2, &"rust")
	# --- Detail pass: hab interior, roof kit and street salvage -------------
	_desk(kit, Vector3(-9.0, 0.0, -6.0), 0.0)
	_bunk(kit, Vector3(-14.6, 0.0, -6.4), 0.0)
	_locker_bank(kit, Vector3(-9.0, 0.0, -1.0), 0.0, 2)
	_shelf(kit, Vector3(-14.0, 0.0, -1.0), 0.0, 1.6, 1.7)
	_screen(kit, Vector3(-11.0, 2.1, -7.8), 0.0)
	_cable_run(kit, Vector3(-15.0, 0.0, -4.0), Vector3(-7.0, 0.0, -4.0))
	_roof_kit(kit, Vector3(11.0, 0.0, 5.0), Vector2(8.0, 6.0), 7.0)
	_solar_panel(kit, Vector3(11.0, 6.6, 8.0), 0.0)
	_vent(kit, Vector3(-12.0, 2.0, 11.0), 0.0)
	_pipe_run(kit, Vector3(-5.0, 5.0, -4.0), Vector3(-5.0, 1.0, 2.0), 0.18, &"rust")
	_ladder(kit, Vector3(15.9, 0.0, 5.0), 6.4, 0.0)
	_signage(kit, Vector3(2.0, 0.0, 14.0), 0.0, &"glow_amber")
	_water_tank(kit, Vector3(0.0, 0.0, 13.0), 1.4, 2.8)
	_tarp(kit, Vector3(-3.0, 0.0, 10.0), 0.4, 2.4, 2.0)
	_hazard_stripes(kit, Vector3(0.0, 0.02, 6.0), 0.0, 4.0, 0.6)
	_add_light(root, Vector3(-11.0, 4.0, -4.0), Color(1.0, 0.68, 0.35), 0.9, 12.0)
	_add_light(root, Vector3(11.0, 6.0, 5.0), Color(1.0, 0.55, 0.24), 0.8, 10.0)


# =============================================================================
# POI: derelict ship (enterable freighter)
# =============================================================================
func _build_derelict_ship(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	# Landing scar and drag marks.
	kit.cylinder(26.0, 29.0, 0.14, 22, Vector3(0.0, 0.05, 0.0), &"scorch", Vector3.ZERO, false)
	for skid in 3:
		kit.box(Vector3(2.0, 0.12, 22.0), Vector3(-9.0 + float(skid) * 9.0, 0.10, 0.0), &"scorch", Vector3.ZERO, false)
	# Enterable main hull: cargo bay / hold / cockpit behind two bulkheads.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 0.0), Vector3(26.0, 0.0, 9.0), [0], &"ivory", &"steel", 4.0, Color(0.35, 0.95, 0.85), &"glow_teal")
	kit.box(Vector3(30.0, 0.8, 12.0), Vector3(0.0, 4.35, 0.0), &"ivory", Vector3.ZERO, false)
	kit.box(Vector3(30.6, 0.4, 12.6), Vector3(0.0, 4.8, 0.0), &"rust", Vector3.ZERO, false)
	# Nose wedge and cockpit glass.
	kit.prism(Vector3(12.0, 4.0, 8.0), Vector3(0.0, 2.2, -8.5), &"ivory", Vector3(0.0, PI * 0.5, 0.0))
	kit.box(Vector3(6.0, 2.0, 4.0), Vector3(0.0, 1.5, -9.0), &"steel")
	kit.box(Vector3(4.0, 0.15, 3.0), Vector3(0.0, 2.7, -10.1), &"glow_teal", Vector3.ZERO, false)
	# Side ribs give the hull readable scale.
	for rib in 5:
		var rx := -12.0 + float(rib) * 6.0
		kit.box(Vector3(0.5, 4.4, 12.4), Vector3(rx, 2.2, 0.0), &"rust_dark", Vector3.ZERO, false)
	# Torn wings and engine pods.
	kit.box(Vector3(11.0, 0.4, 5.0), Vector3(-17.0, 2.6, 2.0), &"ivory", Vector3(0.0, 0.2, 0.0))
	kit.box(Vector3(11.0, 0.4, 5.0), Vector3(17.0, 2.6, 2.0), &"ivory", Vector3(0.0, -0.2, 0.0))
	for side in [-1.0, 1.0]:
		kit.cylinder(1.8, 2.2, 3.0, 10, Vector3(side * 4.0, 2.0, 7.5), &"steel", Vector3(PI * 0.5, 0.0, 0.0))
		kit.cylinder(1.2, 1.2, 0.4, 10, Vector3(side * 4.0, 2.0, 9.1), &"glow_ember", Vector3(PI * 0.5, 0.0, 0.0), false)
	# Boarding ramp up to the rear door.
	kit.box(Vector3(5.2, 0.4, 7.2), Vector3(0.0, 1.15, 7.8), &"steel", Vector3(0.30, 0.0, 0.0))
	for rail in 2:
		kit.box(Vector3(0.18, 0.9, 7.2), Vector3(-2.5 + float(rail) * 5.0, 1.7, 7.8), &"rust_dark", Vector3(0.30, 0.0, 0.0), false)
	# Bulkheads and interior props.
	_interior_partition(kit, Vector3(0.0, 0.0, 0.0), Vector3(26.0, 0.0, 9.0), 0, -7.0, true, &"steel", 4.0)
	_interior_partition(kit, Vector3(0.0, 0.0, 0.0), Vector3(26.0, 0.0, 9.0), 0, 7.0, true, &"steel", 4.0)
	kit.box(Vector3(3.0, 1.0, 1.5), Vector3(-10.0, 0.9, 0.0), &"steel")
	kit.box(Vector3(3.0, 1.0, 1.5), Vector3(10.0, 0.9, 0.0), &"steel")
	_crates(kit, rng, Vector3(-3.0, 0.0, 0.0), 4)
	_crates(kit, rng, Vector3(3.0, 0.0, 0.0), 2)
	_lamp(kit, Vector3(-11.0, 0.0, 3.0), &"glow_teal")
	_lamp(kit, Vector3(11.0, 0.0, -3.0), &"glow_amber")
	# --- Detail pass: freighter interior, hull services and roof kit --------
	_desk(kit, Vector3(10.5, 0.0, -2.4), PI * 0.5)
	_screen(kit, Vector3(12.8, 2.1, -2.4), PI * 0.5)
	_locker_bank(kit, Vector3(5.6, 0.0, 2.8), PI, 2)
	_holo_table(kit, Vector3(-5.5, 0.0, -2.6), 0.0)
	_cable_run(kit, Vector3(-6.0, 0.0, -1.6), Vector3(6.0, 0.0, -1.6))
	_bunk(kit, Vector3(-11.5, 0.0, -2.6), 0.0)
	_roof_kit(kit, Vector3(0.0, 0.0, 0.0), Vector2(10.0, 6.0), 5.05)
	_pipe_run(kit, Vector3(-12.0, 4.9, 5.0), Vector3(12.0, 4.9, 5.0), 0.2, &"steel")
	_vent(kit, Vector3(0.0, 4.4, 6.2), 0.0)
	_ladder(kit, Vector3(14.0, 0.0, 5.0), 4.6, 0.0)
	_signage(kit, Vector3(0.0, 1.2, 12.0), 0.0, &"glow_teal")
	_hazard_stripes(kit, Vector3(0.0, 0.02, 9.6), 0.0, 4.0, 0.7)
	_water_tank(kit, Vector3(20.0, 0.0, 6.0), 1.4, 2.8)
	_tarp(kit, Vector3(-20.0, 0.0, 4.0), 0.3, 2.6, 2.0)
	_add_light(root, Vector3(0.0, 3.0, 0.0), Color(0.35, 0.95, 0.85), 1.2, 16.0)
	_dungeon_anchor(root, Vector3(0.0, 0.5, 6.5))


# =============================================================================
# POI: foundry hall (two-storey catwalk interior + crucible + gantry)
# =============================================================================
func _build_foundry_hall(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 26.0, &"concrete")
	# Production hall: 16 x 12 m clear floor, 7.6 m to the roof trusses.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 0.0), Vector3(16.0, 0.0, 12.0), [0, 1], &"ivory", &"concrete", 7.6, Color(1.0, 0.46, 0.20), &"glow_ember")
	kit.box(Vector3(17.4, 0.4, 13.4), Vector3(0.0, 7.9, 0.0), &"rust_dark")
	kit.box(Vector3(16.6, 0.3, 12.6), Vector3(0.0, 8.15, 0.0), &"rust")
	# Foreman's office under the mezzanine (partitioned off the foundry floor).
	_interior_partition(kit, Vector3(0.0, 0.0, 0.0), Vector3(16.0, 0.0, 12.0), 0, -4.0, true, &"ivory_warm", 3.8)
	_dungeon_anchor(root, Vector3(0.0, 0.5, 5.5))
	# Mezzanine catwalk ring at 3.9 m plus the stair up from the south door.
	_catwalk(kit, Vector3(-7.6, 0.0, -4.6), Vector3(7.6, 0.0, -4.6), 3.9, 2.6)
	_catwalk(kit, Vector3(-7.6, 0.0, 4.6), Vector3(7.6, 0.0, 4.6), 3.9, 2.6)
	_catwalk(kit, Vector3(-6.7, 0.0, -3.3), Vector3(-6.7, 0.0, 3.3), 3.9, 2.0)
	_stair(kit, Vector3(5.6, 0.0, 2.0), 0.0, 1.7, 12, 0.30, 0.32)
	# Crucible on a plinth, banded with steel and lit from the tap hole.
	kit.cylinder(3.5, 3.7, 0.5, 12, Vector3(0.0, 0.3, 0.0), &"concrete")
	kit.cylinder(2.3, 2.7, 3.8, 12, Vector3(0.0, 2.3, 0.0), &"rust_dark")
	kit.torus(2.45, 2.72, Vector3(0.0, 1.3, 0.0), &"steel", Vector3.ZERO, false)
	kit.torus(2.55, 2.82, Vector3(0.0, 3.9, 0.0), &"steel", Vector3.ZERO, false)
	kit.cylinder(0.6, 0.6, 1.5, 8, Vector3(0.0, 4.7, 0.0), &"steel", Vector3.ZERO, false)
	kit.prism(Vector3(1.2, 0.7, 0.9), Vector3(2.6, 4.4, 0.0), &"rust", Vector3(0.0, 0.0, -0.45), false)
	kit.cylinder(1.9, 2.2, 0.16, 10, Vector3(4.2, 0.12, 0.0), &"scorch", Vector3.ZERO, false)
	kit.sphere(0.7, Vector3(3.9, 3.9, 0.0), &"glow_ember", Vector3.ZERO, false, 6, 3)
	# Overhead gantry crane spanning the hall.
	for gx in [-1.0, 1.0]:
		for gz in [-1.0, 1.0]:
			kit.box(Vector3(0.55, 7.2, 0.55), Vector3(float(gx) * 6.9, 3.6, float(gz) * 4.3), &"steel")
	kit.box(Vector3(14.6, 0.5, 0.8), Vector3(0.0, 7.1, 0.0), &"steel")
	kit.box(Vector3(1.4, 1.0, 1.4), Vector3(-2.2, 6.5, 0.0), &"rust")
	kit.cylinder(0.06, 0.06, 3.0, 4, Vector3(-2.2, 4.9, 0.0), &"dark", Vector3.ZERO, false)
	kit.box(Vector3(0.5, 0.5, 0.5), Vector3(-2.2, 3.3, 0.0), &"glow_amber", Vector3.ZERO, false)
	# Twin chimney stacks: the horizon silhouette.
	_chimney(kit, Vector3(-10.5, 0.0, -8.0), 17.0)
	_chimney(kit, Vector3(10.5, 0.0, 8.0), 13.5)
	# Sawtooth roof lights, vents and the service run along the east wall.
	for s in 3:
		var sx := -5.5 + float(s) * 5.5
		kit.box(Vector3(3.6, 0.12, 2.4), Vector3(sx, 8.55, 0.0), &"glass", Vector3(0.0, 0.0, 0.22), false)
		kit.box(Vector3(3.8, 0.3, 0.3), Vector3(sx, 8.45, -1.3), &"steel", Vector3(0.0, 0.0, 0.22), false)
	_roof_kit(kit, Vector3(0.0, 0.0, 3.4), Vector2(9.0, 4.0), 8.3)
	_pipe_run(kit, Vector3(8.1, 0.7, -8.0), Vector3(8.1, 5.6, -8.0), 0.24, &"steel")
	_pipe_run(kit, Vector3(8.1, 5.6, -8.0), Vector3(8.1, 5.6, 7.0), 0.24, &"steel")
	_pipe_run(kit, Vector3(8.1, 5.6, 7.0), Vector3(-10.5, 5.6, 7.0), 0.24, &"steel")
	_cable_run(kit, Vector3(-7.0, 0.0, 6.4), Vector3(7.0, 0.0, 6.4))
	_ladder(kit, Vector3(8.4, 0.0, -5.0), 8.2, 0.0)
	_water_tank(kit, Vector3(12.5, 0.0, -11.0), 1.7, 3.4)
	_signage(kit, Vector3(-4.5, 0.0, 8.4), 0.0, &"glow_amber")
	_awning(kit, Vector3(-4.5, 0.0, 6.2), 0.0, 4.2, 2.4)
	_hazard_stripes(kit, Vector3(2.0, 0.02, 7.6), 0.0, 6.4, 0.8)
	# Foreman's bay under the catwalk plus production clutter.
	_desk(kit, Vector3(6.2, 0.0, -5.0), PI)
	_locker_bank(kit, Vector3(7.4, 0.0, 2.6), PI * 0.5, 3)
	_shelf(kit, Vector3(-7.4, 0.0, 2.0), PI * 0.5)
	_shelf(kit, Vector3(-7.4, 0.0, -1.0), PI * 0.5)
	_screen(kit, Vector3(6.6, 2.0, -8.2), PI)
	_crate_row(kit, Vector3(-5.5, 0.0, -5.2), 0.0, 3, &"rust")
	_crate_row(kit, Vector3(4.0, 0.0, -7.6), PI * 0.5, 3, &"ivory_warm")
	_holo_table(kit, Vector3(-3.0, 0.0, 4.6), 0.0)
	for m in 5:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(5.0, 9.0)
		kit.box(Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.4, 1.0), rng.randf_range(0.8, 1.6)), Vector3(cos(ang) * dist, 0.4, sin(ang) * dist), &"rust_dark", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_add_light(root, Vector3(0.0, 2.2, 0.0), Color(1.0, 0.42, 0.16), 1.5, 14.0)
	_add_light(root, Vector3(-10.5, 16.8, -8.0), Color(1.0, 0.45, 0.18), 1.0, 12.0)
	_add_light(root, Vector3(0.0, 7.0, 0.0), Color(1.0, 0.70, 0.38), 0.9, 12.0)


# =============================================================================
# POI: hab cluster (three enterable domed modules around a courtyard)
# =============================================================================
func _build_hab_cluster(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 24.0, &"pad")
	# Three hab shells, each opening onto the courtyard.
	_hab_module(root, kit, Vector3(-14.0, 0.0, -7.0), 2, "A")
	_hab_module(root, kit, Vector3(14.0, 0.0, -7.0), 3, "B")
	_hab_module(root, kit, Vector3(0.0, 0.0, 15.0), 1, "C")
	# Courtyard deck, holo table and benches.
	kit.cylinder(6.2, 6.6, 0.35, 16, Vector3(0.0, 0.18, 2.0), &"pad")
	kit.torus(5.6, 6.0, Vector3(0.0, 0.38, 2.0), &"glow_teal", Vector3.ZERO, false)
	_holo_table(kit, Vector3(0.0, 0.0, 2.0), 0.0)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + PI * 0.25
		_bench(kit, Vector3(cos(ang) * 3.4, 0.0, 2.0 + sin(ang) * 3.4), -ang)
	_planter(kit, Vector3(-4.0, 0.0, -1.5), 0.0)
	_planter(kit, Vector3(4.0, 0.0, -1.5), 0.0)
	_planter(kit, Vector3(0.0, 0.0, 6.8), 0.0)
	_crate_row(kit, Vector3(6.6, 0.0, 3.0), PI * 0.5, 2, &"ivory_warm")
	_crate_row(kit, Vector3(-6.6, 0.0, 3.0), PI * 0.5, 2, &"rust")
	# Covered walkways link the modules to the courtyard.
	_walkway(kit, Vector3(-14.0, 0.0, -1.6), Vector3(-4.6, 0.0, 1.4), 2.0)
	_walkway(kit, Vector3(14.0, 0.0, -1.6), Vector3(4.6, 0.0, 1.4), 2.0)
	_walkway(kit, Vector3(0.0, 0.0, 11.8), Vector3(0.0, 0.0, 7.2), 2.0)
	# Service spine behind the courtyard: tank, generator, cable runs, vents.
	_water_tank(kit, Vector3(-9.5, 0.0, 12.5), 1.6, 3.2)
	kit.box(Vector3(2.2, 1.2, 1.4), Vector3(9.5, 0.6, 11.5), &"steel")
	_vent(kit, Vector3(10.4, 1.25, 11.5), 0.0, Vector3(0.9, 0.5, 0.5))
	_cable_run(kit, Vector3(-9.0, 0.0, 9.5), Vector3(9.0, 0.0, 9.5))
	_pipe_run(kit, Vector3(-9.5, 0.4, 12.5), Vector3(9.5, 0.4, 11.5), 0.16, &"rust")
	_antenna(kit, Vector3(11.5, 0.0, 1.0), 8.5)
	_lamp(kit, Vector3(-5.2, 0.0, 7.4), &"glow_teal")
	_lamp(kit, Vector3(5.2, 0.0, 7.4), &"glow_amber")
	_signage(kit, Vector3(0.0, 0.0, 8.6), PI, &"glow_teal")
	for b in 5:
		var ang := TAU * float(b) / 5.0 + 0.5
		_barrier(kit, Vector3(cos(ang) * 18.0, 0.0, 2.0 + sin(ang) * 15.0), ang + PI * 0.5)
	# A little laundry / salvage clutter between the modules.
	for c in 6:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(9.0, 13.0)
		kit.box(Vector3(rng.randf_range(0.7, 1.5), rng.randf_range(0.5, 1.1), rng.randf_range(0.7, 1.3)), Vector3(cos(ang) * dist, 0.55, 2.0 + sin(ang) * dist), &"fabric" if c % 2 == 0 else &"rust", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_add_light(root, Vector3(0.0, 3.4, 2.0), Color(0.45, 1.0, 0.88), 1.2, 12.0)
	_add_light(root, Vector3(0.0, 2.2, 9.5), Color(1.0, 0.72, 0.40), 0.8, 8.0)


func _hab_module(root: Node3D, kit: MeshKit, center: Vector3, door_side: int, tag: String) -> void:
	_interior_shell(root, kit, center, Vector3(8.0, 0.0, 6.0), [door_side], &"ivory", &"concrete", 3.3, Color(1.0, 0.70, 0.40), &"glow_amber", tag)
	# Module A is split into an entry room and a sleeping alcove.
	if tag == "A":
		_interior_partition(kit, center, Vector3(8.0, 0.0, 6.0), 0, -1.5, true, &"ivory_warm", 3.3)
	# Pressure dome and trim ring give the cluster its roofscape identity.
	var dome := SphereMesh.new()
	dome.radius = 4.9
	dome.height = 9.8
	dome.radial_segments = 12
	dome.rings = 6
	kit.add_mesh_instance(dome, Transform3D(Basis.from_scale(Vector3(1.0, 0.52, 1.0)), center + Vector3(0.0, 3.3, 0.0)), &"ivory_warm", false)
	kit.torus(4.4, 4.65, center + Vector3(0.0, 3.55, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.sphere(0.26, center + Vector3(0.0, 6.05, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# Door frame, glowing lintel and a ribbed window on each long side.
	_basis_door_frame(kit, center, Vector3(8.0, 0.0, 6.0), door_side, &"rust")
	_screen(kit, center + Vector3(3.6, 2.0, 0.0), PI * 0.5)
	for s in 2:
		var sx := -2.4 if s == 0 else 2.4
		kit.box(Vector3(1.8, 0.9, 0.1), center + Vector3(sx, 1.95, -3.1) if door_side != 1 else center + Vector3(sx, 1.95, 3.1), &"glass", Vector3.ZERO, false)
		kit.box(Vector3(2.0, 0.12, 0.16), center + Vector3(sx, 2.5, -3.1) if door_side != 1 else center + Vector3(sx, 2.5, 3.1), &"steel", Vector3.ZERO, false)
	# Furnishing: bunk, desk, lockers and a supply shelf.
	match door_side:
		0:
			_bunk(kit, center + Vector3(-2.6, 0.0, 1.6), 0.0)
			_desk(kit, center + Vector3(2.2, 0.0, -1.4), PI)
			_locker_bank(kit, center + Vector3(2.6, 0.0, 1.5), 0.0, 2)
			_shelf(kit, center + Vector3(-2.8, 0.0, -2.0), 0.0, 1.5, 1.7)
		1:
			_bunk(kit, center + Vector3(-2.6, 0.0, -1.4), PI)
			_desk(kit, center + Vector3(2.2, 0.0, 1.2), 0.0)
			_locker_bank(kit, center + Vector3(2.6, 0.0, -1.5), PI, 2)
			_shelf(kit, center + Vector3(-2.8, 0.0, 1.8), PI, 1.5, 1.7)
		2:
			_bunk(kit, center + Vector3(-1.4, 0.0, -2.0), 0.0)
			_desk(kit, center + Vector3(1.6, 0.0, 1.4), PI * 0.5)
			_locker_bank(kit, center + Vector3(-1.6, 0.0, 2.0), 0.0, 2)
			_shelf(kit, center + Vector3(2.4, 0.0, -2.0), PI * 0.5, 1.5, 1.7)
		3:
			_bunk(kit, center + Vector3(-1.6, 0.0, 2.0), PI)
			_desk(kit, center + Vector3(1.6, 0.0, -1.4), PI * 0.5)
			_locker_bank(kit, center + Vector3(-1.4, 0.0, -2.2), PI, 2)
			_shelf(kit, center + Vector3(2.4, 0.0, 2.0), PI * 0.5, 1.5, 1.7)
	_crate(kit, center + Vector3(-3.2, 0.0, 2.0), 0.3, &"ivory_warm")
	_cable_run(kit, center + Vector3(-3.4, 0.0, -2.4), center + Vector3(3.4, 0.0, -2.4))
	_vent(kit, center + Vector3(3.4, 2.6, -2.2), 0.0, Vector3(0.8, 0.5, 0.4))
	# Solar panel and small roof aerial.
	_solar_panel(kit, center + Vector3(3.8, 0.0, 2.8), 0.0)
	_antenna(kit, center + Vector3(-3.6, 0.0, -2.6), 4.5)


# =============================================================================
# POI: comms array (dish farm + cable runs + equipment shed)
# =============================================================================
func _build_comms_array(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 20.0, &"concrete")
	# Uplink tower carrying the big dish: four tapering legs and a service deck.
	for leg in 4:
		var ang := TAU * float(leg) / 4.0 + PI * 0.25
		var base := Vector3(cos(ang) * 3.4, 0.0, sin(ang) * 3.4 - 6.0)
		_beam(kit, base, Vector3(cos(ang) * 1.1, 10.5, sin(ang) * 1.1 - 6.0), 0.28, &"steel", true)
		kit.box(Vector3(0.5, 0.5, 3.0), Vector3(cos(ang) * 2.2, 5.4, sin(ang) * 2.2 - 6.0), &"rust_dark", Vector3(0.0, -ang, 0.0), false)
	kit.box(Vector3(3.6, 0.3, 3.6), Vector3(0.0, 10.6, -6.0), &"steel")
	kit.cylinder(1.1, 6.2, 0.9, 18, Vector3(0.0, 12.6, -6.0), &"ivory_warm", Vector3(0.85, 0.3, 0.1), false)
	kit.torus(5.9, 6.3, Vector3(0.0, 12.7, -6.0), &"steel", Vector3(0.85, 0.3, 0.1), false)
	kit.cylinder(0.1, 0.1, 3.6, 5, Vector3(1.6, 14.9, -5.0), &"steel", Vector3(0.55, 0.3, 0.2), false)
	kit.sphere(0.3, Vector3(2.9, 16.2, -4.4), &"glow_teal", Vector3.ZERO, false, 8, 4)
	kit.cylinder(0.3, 0.45, 3.2, 6, Vector3(0.0, 12.2, -6.0), &"steel", Vector3.ZERO, false)
	# Small dish farm on pedestals.
	for d in 4:
		var ang := TAU * float(d) / 4.0 + 0.6
		var p := Vector3(cos(ang) * 13.0, 0.0, sin(ang) * 11.0 - 3.0)
		kit.cylinder(0.5, 0.75, 1.5, 8, p + Vector3(0.0, 0.75, 0.0), &"concrete")
		kit.box(Vector3(0.4, 0.8, 0.4), p + Vector3(0.0, 1.8, 0.0), &"steel")
		var face := (Vector3(0.0, 2.4, -6.0) - p).normalized()
		kit.cylinder(0.45, 2.3, 0.22, 14, p + Vector3(0.0, 2.5, 0.0), &"ivory_warm", _rotation_from_up(face), false)
		kit.sphere(0.22, p + Vector3(0.0, 2.5, 0.0) + face * 0.9, &"glow_teal", Vector3.ZERO, false, 6, 3)
	# Equipment shed: enterable, with the uplink racks inside.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 12.0), Vector3(7.0, 0.0, 5.0), [1], &"ivory", &"concrete", 3.0, Color(0.40, 0.95, 1.0), &"glow_teal")
	kit.box(Vector3(8.2, 0.35, 6.2), Vector3(0.0, 3.2, 12.0), &"rust")
	_interior_partition(kit, Vector3(0.0, 0.0, 12.0), Vector3(7.0, 0.0, 5.0), 1, -0.5, true, &"ivory_warm", 3.0)
	_roof_kit(kit, Vector3(0.0, 0.0, 12.0), Vector2(4.2, 2.4), 3.4)
	# Junction boxes and exposed cable runs stitching the farm together.
	for j in 3:
		var jp := Vector3(-6.0 + float(j) * 6.0, 0.0, 3.0)
		kit.box(Vector3(0.9, 1.1, 0.7), jp + Vector3(0.0, 0.55, 0.0), &"dark")
		kit.box(Vector3(0.86, 0.1, 0.06), jp + Vector3(0.0, 0.95, 0.37), &"glow_teal", Vector3.ZERO, false)
	_cable_run(kit, Vector3(-6.0, 0.0, 3.2), Vector3(-12.0, 0.0, -2.0))
	_cable_run(kit, Vector3(0.0, 0.0, 3.2), Vector3(1.0, 0.0, -8.6))
	_cable_run(kit, Vector3(6.0, 0.0, 3.2), Vector3(12.0, 0.0, -2.5))
	_cable_run(kit, Vector3(-2.8, 0.0, 9.4), Vector3(-6.0, 0.0, 3.2))
	_cable_run(kit, Vector3(2.8, 0.0, 9.4), Vector3(6.0, 0.0, 3.2))
	# Perimeter masts, fence stubs and signage.
	for m in 4:
		var ang := TAU * float(m) / 4.0 + PI * 0.25
		_antenna(kit, Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 13.0 + 3.0), 10.0)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.9
		_barrier(kit, Vector3(cos(ang) * 18.0, 0.0, sin(ang) * 16.0 + 2.0), ang + PI * 0.5)
	_water_tank(kit, Vector3(-11.5, 0.0, 10.0), 1.4, 2.8)
	_solar_panel(kit, Vector3(10.5, 0.0, 9.0), PI)
	_signage(kit, Vector3(4.6, 0.0, 8.6), 0.0, &"glow_teal")
	_lamp(kit, Vector3(-4.8, 0.0, 8.8), &"glow_teal")
	_lamp(kit, Vector3(5.0, 0.0, -0.8), &"glow_amber")
	# Interior: racks, analysis desk and cable trays.
	_locker_bank(kit, Vector3(-2.6, 0.0, 12.6), PI, 3)
	_desk(kit, Vector3(2.2, 0.0, 12.4), PI)
	_screen(kit, Vector3(0.0, 1.9, 14.2), PI)
	_holo_table(kit, Vector3(0.0, 0.0, 10.2), 0.0)
	_cable_run(kit, Vector3(-2.8, 0.0, 10.0), Vector3(2.8, 0.0, 10.0))
	for c in 4:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(7.0, 13.0)
		kit.box(Vector3(rng.randf_range(0.6, 1.2), rng.randf_range(0.3, 0.7), rng.randf_range(0.6, 1.2)), Vector3(cos(ang) * dist, 0.3, sin(ang) * dist + 4.0), &"rust_dark", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_add_light(root, Vector3(0.0, 13.0, -6.0), Color(0.35, 0.95, 1.0), 1.6, 24.0)
	_add_light(root, Vector3(0.0, 2.4, 12.0), Color(0.45, 1.0, 0.86), 0.9, 8.0)


# =============================================================================
# POI: fuel depot (tank farm, pump gantry, hazard markings)
# =============================================================================
func _build_fuel_depot(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 26.0, &"concrete")
	# Four storage tanks on plinths, banded and piped into the manifold.
	var tanks := [
		Vector3(-12.0, 0.0, -9.0), Vector3(12.0, 0.0, -9.0),
		Vector3(-12.0, 0.0, 5.0), Vector3(12.0, 0.0, 5.0),
	]
	for t in tanks.size():
		var tank_pos: Vector3 = tanks[t]
		var body_mat: StringName = &"ivory_warm" if t % 2 == 0 else &"rust"
		kit.cylinder(3.9, 4.1, 0.45, 14, tank_pos + Vector3(0.0, 0.22, 0.0), &"concrete")
		kit.cylinder(3.0, 3.1, 8.0, 14, tank_pos + Vector3(0.0, 4.45, 0.0), body_mat)
		kit.torus(2.95, 3.15, tank_pos + Vector3(0.0, 2.2, 0.0), &"steel", Vector3.ZERO, false)
		kit.torus(2.95, 3.15, tank_pos + Vector3(0.0, 6.8, 0.0), &"steel", Vector3.ZERO, false)
		var lid := SphereMesh.new()
		lid.radius = 3.0
		lid.height = 6.0
		lid.radial_segments = 14
		lid.rings = 4
		kit.add_mesh_instance(lid, Transform3D(Basis.from_scale(Vector3(1.0, 0.32, 1.0)), tank_pos + Vector3(0.0, 8.4, 0.0)), &"rust_dark", false)
		_ladder(kit, tank_pos + Vector3(3.2, 0.0, 0.0), 8.6, 0.0)
		_pipe_run(kit, tank_pos + Vector3(3.0, 0.5, 0.0), tank_pos + Vector3(3.0, 0.5, 3.0), 0.18, &"steel")
		kit.box(Vector3(0.8, 0.8, 0.8), tank_pos + Vector3(3.1, 0.55, 3.0), &"rust_dark")
		kit.box(Vector3(1.4, 0.3, 0.06), tank_pos + Vector3(0.0, 2.6, 3.15), &"glow_amber", Vector3.ZERO, false)
	# Manifold trench feeding the pump gantry.
	_pipe_run(kit, Vector3(-12.0, 0.7, -5.8), Vector3(12.0, 0.7, -5.8), 0.22, &"steel")
	_pipe_run(kit, Vector3(-12.0, 0.7, 8.0), Vector3(12.0, 0.7, 8.0), 0.22, &"steel")
	_pipe_run(kit, Vector3(0.0, 0.7, -5.8), Vector3(0.0, 0.7, 2.0), 0.22, &"steel")
	_box_valve_cluster(kit, Vector3(-2.0, 0.0, 0.0), 0.0)
	# Raised pump gantry under a rust canopy.
	kit.box(Vector3(9.0, 0.35, 4.2), Vector3(0.0, 2.2, 4.0), &"steel")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.box(Vector3(0.35, 2.2, 0.35), Vector3(float(sx) * 4.1, 1.1, 4.0 + float(sz) * 1.7), &"rust_dark")
	_railing(kit, Vector3(-4.3, 2.2, 2.0), Vector3(4.3, 2.2, 2.0), 1.0, 4)
	_railing(kit, Vector3(-4.3, 2.2, 6.0), Vector3(4.3, 2.2, 6.0), 1.0, 4)
	_stair(kit, Vector3(4.6, 0.0, 2.2), PI * 0.5, 1.6, 8, 0.28, 0.30)
	_ladder(kit, Vector3(-4.0, 2.2, 4.0), 2.2, 0.0)
	kit.box(Vector3(10.0, 0.3, 5.2), Vector3(0.0, 5.2, 4.0), &"rust")
	kit.box(Vector3(10.4, 0.18, 5.6), Vector3(0.0, 5.45, 4.0), &"rust_dark", Vector3.ZERO, false)
	for px in [-2.6, 2.6]:
		kit.cylinder(0.7, 0.9, 1.6, 10, Vector3(px, 3.2, 4.0), &"ivory_warm", Vector3.ZERO, true)
		kit.cylinder(0.18, 0.18, 1.2, 6, Vector3(px, 3.2, 5.0), &"steel", Vector3(PI * 0.5, 0.0, 0.0), false)
		kit.box(Vector3(0.5, 0.5, 0.5), Vector3(px, 4.15, 4.0), &"steel", Vector3.ZERO, false)
	for hs in 3:
		kit.box(Vector3(1.1, 0.04, 0.5), Vector3(-3.2 + float(hs) * 3.2, 2.4, 1.95), &"glow_amber", Vector3.ZERO, false)
	# Flare stack: the long-range silhouette.
	kit.cylinder(1.2, 1.5, 0.6, 10, Vector3(0.0, 0.3, -18.0), &"concrete")
	kit.cylinder(0.32, 0.55, 13.0, 8, Vector3(0.0, 6.8, -18.0), &"steel")
	for f in 3:
		kit.torus(0.5, 0.62, Vector3(0.0, 3.5 + float(f) * 3.2, -18.0), &"rust_dark", Vector3.ZERO, false)
	kit.sphere(0.55, Vector3(0.0, 13.7, -18.0), &"glow_ember", Vector3.ZERO, false, 8, 4)
	for w in 3:
		var ang := TAU * float(w) / 3.0
		_beam(kit, Vector3(0.0, 9.0, -18.0), Vector3(cos(ang) * 6.5, 0.2, -18.0 + sin(ang) * 6.5), 0.05, &"steel", false)
	# Control shack with the manifold controls inside.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 17.0), Vector3(7.0, 0.0, 5.0), [1], &"ivory", &"concrete", 3.0, Color(1.0, 0.60, 0.24), &"glow_amber")
	kit.box(Vector3(8.2, 0.35, 6.2), Vector3(0.0, 3.2, 17.0), &"rust")
	_interior_partition(kit, Vector3(0.0, 0.0, 17.0), Vector3(7.0, 0.0, 5.0), 1, -0.5, true, &"ivory_warm", 3.0)
	_dungeon_anchor(root, Vector3(0.0, 0.5, 18.0))
	_roof_kit(kit, Vector3(0.0, 0.0, 17.0), Vector2(4.2, 2.4), 3.4)
	_awning(kit, Vector3(0.0, 0.0, 14.4), 0.0, 3.8, 2.2)
	_hazard_stripes(kit, Vector3(0.0, 0.02, 11.6), 0.0, 6.0, 0.9)
	_desk(kit, Vector3(2.2, 0.0, 17.2), PI)
	_locker_bank(kit, Vector3(-2.6, 0.0, 17.6), PI, 2)
	_screen(kit, Vector3(0.0, 2.0, 19.2), PI)
	_box_valve_cluster(kit, Vector3(0.0, 0.0, 15.0), PI * 0.5)
	# Bund wall with deliberate gate gaps.
	for b in 10:
		if b == 2 or b == 7:
			continue
		var ang := TAU * float(b) / 10.0 + 0.15
		var bp := Vector3(cos(ang) * 17.5, 0.0, sin(ang) * 16.5 - 1.0)
		kit.box(Vector3(4.6, 1.0, 0.6), bp + Vector3(0.0, 0.5, 0.0), &"concrete", Vector3(0.0, -ang, 0.0))
		kit.box(Vector3(4.6, 0.06, 0.66), bp + Vector3(0.0, 1.03, 0.0), &"glow_amber", Vector3(0.0, -ang, 0.0), false)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.6
		_barrier(kit, Vector3(cos(ang) * 21.0, 0.0, sin(ang) * 14.0 + 2.0), ang + PI * 0.5)
	_water_tank(kit, Vector3(-15.0, 0.0, 12.0), 1.5, 3.0)
	_solar_panel(kit, Vector3(15.0, 0.0, 12.5), PI)
	_signage(kit, Vector3(8.0, 0.0, 12.0), 0.0, &"glow_amber")
	_lamp(kit, Vector3(-7.0, 0.0, 12.5), &"glow_amber")
	_lamp(kit, Vector3(7.0, 0.0, 12.5), &"glow_amber")
	# Spilled drums and debris in the service yard.
	for c in 7:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(8.0, 15.0)
		var p := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist + 4.0)
		if c % 2 == 0:
			kit.cylinder(0.42, 0.42, 1.05, 8, p + Vector3(0.0, 0.52, 0.0), &"rust")
			kit.torus(0.4, 0.46, p + Vector3(0.0, 0.65, 0.0), &"rust_dark", Vector3.ZERO, false)
		else:
			kit.box(Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.4, 0.8), rng.randf_range(0.7, 1.3)), p + Vector3(0.0, 0.3, 0.0), &"steel", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_add_light(root, Vector3(0.0, 13.8, -18.0), Color(1.0, 0.42, 0.14), 1.8, 22.0)
	_add_light(root, Vector3(0.0, 3.0, 17.0), Color(1.0, 0.62, 0.26), 1.0, 10.0)
	_add_light(root, Vector3(0.0, 5.6, 4.0), Color(1.0, 0.74, 0.40), 0.8, 10.0)


# =============================================================================
# POI: clinic shelter (beds, med lockers, triage screen)
# =============================================================================
func _build_clinic_shelter(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 22.0, &"pad")
	# Long clinic block split into reception / ward / supply bays.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 0.0), Vector3(12.0, 0.0, 8.0), [0], &"ivory", &"concrete", 3.4, Color(0.55, 1.0, 0.92), &"glow_teal")
	kit.box(Vector3(13.2, 0.35, 9.2), Vector3(0.0, 3.55, 0.0), &"ivory_warm")
	kit.box(Vector3(13.6, 0.16, 9.6), Vector3(0.0, 3.8, 0.0), &"rust_dark", Vector3.ZERO, false)
	_interior_partition(kit, Vector3(0.0, 0.0, 0.0), Vector3(12.0, 0.0, 8.0), 0, -3.6, true, &"ivory_warm", 3.4)
	_interior_partition(kit, Vector3(0.0, 0.0, 0.0), Vector3(12.0, 0.0, 8.0), 0, 3.6, true, &"ivory_warm", 3.4)
	# Lit medical cross on a mast: readable from 300 m.
	kit.cylinder(0.14, 0.20, 7.2, 6, Vector3(6.4, 3.6, 6.4), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(3.4, 0.62, 0.35), Vector3(6.4, 6.4, 6.4), &"glow_teal", Vector3.ZERO, false)
	kit.box(Vector3(0.62, 2.6, 0.35), Vector3(6.4, 6.4, 6.4), &"glow_teal", Vector3.ZERO, false)
	kit.box(Vector3(3.9, 1.0, 0.2), Vector3(6.4, 6.4, 6.2), &"dark", Vector3.ZERO, false)
	kit.sphere(0.3, Vector3(6.4, 7.5, 6.4), &"glow_amber", Vector3.ZERO, false, 6, 3)
	# Entrance canopy, triage tent and waiting benches.
	_awning(kit, Vector3(-1.5, 0.0, 4.2), 0.0, 5.4, 3.0)
	kit.cylinder(2.4, 2.6, 0.9, 8, Vector3(9.0, 0.45, 9.0), &"fabric")
	kit.cylinder(0.14, 2.5, 1.8, 8, Vector3(9.0, 1.8, 9.0), &"fabric", Vector3.ZERO, false)
	kit.cylinder(0.16, 0.16, 2.8, 6, Vector3(9.0, 2.4, 9.0), &"steel", Vector3.ZERO, false)
	_bench(kit, Vector3(-4.6, 0.0, 5.4), PI)
	_bench(kit, Vector3(2.0, 0.0, 5.4), PI)
	_signage(kit, Vector3(3.4, 0.0, 4.8), 0.0, &"glow_teal")
	# Ward: three screened beds, monitors, and an autoclave.
	_bunk(kit, Vector3(-5.0, 0.0, -2.2), 0.0)
	_bunk(kit, Vector3(-5.0, 0.0, 2.2), 0.0)
	_bunk(kit, Vector3(-1.6, 0.0, 2.4), 0.0)
	kit.box(Vector3(0.08, 2.2, 2.6), Vector3(-2.6, 1.15, 2.3), &"fabric", Vector3.ZERO, false)
	kit.box(Vector3(0.08, 2.2, 2.6), Vector3(-2.6, 1.15, -0.2), &"fabric", Vector3.ZERO, false)
	_holo_table(kit, Vector3(-1.8, 0.0, -2.6), 0.0)
	_screen(kit, Vector3(-5.6, 2.0, 0.0), PI * 0.5)
	_vent(kit, Vector3(2.0, 2.9, -3.4), 0.0, Vector3(1.0, 0.6, 0.4))
	# Reception: desk, lockers, records shelf.
	_desk(kit, Vector3(4.6, 0.0, 1.4), PI * 0.5)
	_locker_bank(kit, Vector3(5.6, 0.0, -3.4), PI, 3)
	_shelf(kit, Vector3(2.0, 0.0, -3.4), PI, 1.8, 1.9)
	_crate_row(kit, Vector3(4.4, 0.0, -2.4), 0.0, 2, &"ivory_warm")
	_cable_run(kit, Vector3(-5.4, 0.0, 0.0), Vector3(5.4, 0.0, 0.0))
	# Supply bay: stacked medical crates and oxygen bottles.
	for s in 4:
		kit.cylinder(0.3, 0.3, 1.5, 8, Vector3(3.0 + float(s) * 0.7, 0.75, -3.2), &"steel")
		kit.sphere(0.18, Vector3(3.0 + float(s) * 0.7, 1.6, -3.2), &"glow_teal", Vector3.ZERO, false, 6, 3)
	_crate_row(kit, Vector3(4.6, 0.0, 3.0), 0.0, 3, &"ivory_warm")
	# Generator + water tank + cable runs outside.
	kit.box(Vector3(2.4, 1.4, 1.6), Vector3(-10.5, 0.7, 7.0), &"steel")
	_vent(kit, Vector3(-10.5, 1.65, 7.0), 0.0, Vector3(1.2, 0.6, 0.5))
	_pipe_run(kit, Vector3(-9.0, 0.5, 7.0), Vector3(-6.6, 0.5, 5.2), 0.16, &"rust")
	_water_tank(kit, Vector3(10.5, 0.0, -5.0), 1.6, 3.2)
	_solar_panel(kit, Vector3(-6.0, 0.0, 7.6), 0.0)
	_antenna(kit, Vector3(-12.0, 0.0, -3.0), 7.0)
	_tarp(kit, Vector3(8.0, 0.0, 4.0), 0.4, 2.4, 2.0)
	_lamp(kit, Vector3(-6.4, 0.0, 6.0), &"glow_teal")
	_lamp(kit, Vector3(6.4, 0.0, 6.0), &"glow_amber")
	_roof_kit(kit, Vector3(-3.0, 0.0, 0.0), Vector2(5.0, 4.0), 3.85)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 1.2
		_barrier(kit, Vector3(cos(ang) * 16.0, 0.0, sin(ang) * 14.0 + 2.0), ang + PI * 0.5)
	for c in 5:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(9.0, 14.0)
		kit.box(Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 1.1)), Vector3(cos(ang) * dist, 0.3, sin(ang) * dist + 4.0), &"ivory_warm" if c % 2 == 0 else &"rust", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_add_light(root, Vector3(0.0, 3.0, 0.0), Color(0.55, 1.0, 0.92), 1.2, 12.0)
	_add_light(root, Vector3(6.4, 6.4, 7.2), Color(0.55, 1.0, 0.95), 1.4, 18.0)


# =============================================================================
# POI: research lab (glass dome + server wing)
# =============================================================================
func _build_research_lab(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 24.0, &"pad")
	# Server wing: enterable, wrapped in glass panels.
	_interior_shell(root, kit, Vector3(0.0, 0.0, -11.0), Vector3(12.0, 0.0, 7.0), [0], &"ivory", &"concrete", 3.6, Color(0.45, 0.95, 1.0), &"glow_teal")
	kit.box(Vector3(13.0, 0.35, 8.0), Vector3(0.0, 3.75, -11.0), &"ivory_warm")
	for g in 3:
		kit.box(Vector3(3.0, 2.4, 0.1), Vector3(-4.0 + float(g) * 4.0, 1.9, -14.6), &"glass", Vector3.ZERO, false)
		kit.box(Vector3(3.1, 0.12, 0.2), Vector3(-4.0 + float(g) * 4.0, 3.15, -14.6), &"steel", Vector3.ZERO, false)
	for g in 2:
		kit.box(Vector3(0.1, 2.4, 3.0), Vector3(-6.1, 1.9, -12.0 + float(g) * 3.0), &"glass", Vector3.ZERO, false)
	# Glass dome: the landmark silhouette, lit from inside.
	kit.cylinder(8.6, 8.9, 1.2, 18, Vector3(0.0, 0.6, 7.0), &"ivory")
	kit.torus(8.4, 8.8, Vector3(0.0, 1.25, 7.0), &"steel", Vector3.ZERO, false)
	var dome := SphereMesh.new()
	dome.radius = 8.0
	dome.height = 16.0
	dome.radial_segments = 18
	dome.rings = 8
	kit.add_mesh_instance(dome, Transform3D(Basis.from_scale(Vector3(1.0, 0.52, 1.0)), Vector3(0.0, 1.2, 7.0)), &"glass", false)
	for meridian in 6:
		var ang := TAU * float(meridian) / 6.0
		var base := Vector3(cos(ang) * 7.8, 1.3, 7.0 + sin(ang) * 7.8)
		_pipe_run(kit, base, Vector3(0.0, 5.4, 7.0), 0.1, &"steel")
	kit.sphere(0.7, Vector3(0.0, 5.5, 7.0), &"glow_teal", Vector3.ZERO, false, 10, 6)
	kit.torus(4.6, 5.0, Vector3(0.0, 3.4, 7.0), &"glow_teal", Vector3(0.1, 0.3, 0.0), false)
	# Alien botany inside the dome (visible through the glass).
	for p in 5:
		var ang := TAU * float(p) / 5.0 + 0.4
		kit.cylinder(0.25, 0.6, 1.6, 6, Vector3(cos(ang) * 4.6, 1.9, 7.0 + sin(ang) * 4.6), &"alien_dark")
		kit.sphere(0.9, Vector3(cos(ang) * 4.6, 3.1, 7.0 + sin(ang) * 4.6), &"alien", Vector3.ZERO, false, 8, 4)
		kit.sphere(0.2, Vector3(cos(ang) * 4.6, 3.9, 7.0 + sin(ang) * 4.6), &"glow_teal", Vector3.ZERO, false, 6, 3)
	# Twin sensor masts flanking the complex.
	for side in [-1.0, 1.0]:
		kit.cylinder(0.35, 0.55, 11.0, 7, Vector3(float(side) * 14.0, 5.5, 11.0), &"ivory")
		kit.cylinder(0.14, 0.3, 4.0, 6, Vector3(float(side) * 14.0, 12.5, 11.0), &"steel", Vector3.ZERO, false)
		kit.sphere(0.4, Vector3(float(side) * 14.0, 14.7, 11.0), &"glow_teal", Vector3.ZERO, false, 8, 4)
		kit.cylinder(0.4, 1.7, 0.2, 10, Vector3(float(side) * 12.6, 9.4, 11.0), &"ivory_warm", Vector3(0.9, 0.4, 0.2), false)
	# Coolant pipes, vents and solar array.
	_pipe_run(kit, Vector3(8.0, 0.6, -11.0), Vector3(8.0, 0.6, 2.0), 0.22, &"steel")
	_pipe_run(kit, Vector3(8.0, 0.6, 2.0), Vector3(4.0, 0.6, 5.0), 0.22, &"steel")
	_vent(kit, Vector3(-6.6, 2.0, -11.0), PI * 0.5, Vector3(1.2, 0.9, 0.35))
	_vent(kit, Vector3(6.6, 2.0, -11.0), PI * 0.5, Vector3(1.2, 0.9, 0.35))
	for s in 3:
		_solar_panel(kit, Vector3(-11.0 + float(s) * 2.6, 0.0, -2.0), 0.0)
	_cable_run(kit, Vector3(-5.0, 0.0, -7.0), Vector3(5.0, 0.0, -7.0))
	_roof_kit(kit, Vector3(3.0, 0.0, -11.0), Vector2(5.0, 3.0), 3.95)
	_ladder(kit, Vector3(-6.8, 0.0, -8.4), 3.9, 0.0)
	_signage(kit, Vector3(-4.0, 0.0, -6.6), 0.0, &"glow_teal")
	# Interior: server racks, lab tables, cryo pods, cable trays.
	_interior_partition(kit, Vector3(0.0, 0.0, -11.0), Vector3(12.0, 0.0, 7.0), 0, 0.5, true, &"ivory_warm", 3.6)
	_dungeon_anchor(root, Vector3(0.0, 0.5, -9.0))
	for row in 2:
		for col in 2:
			_server_rack(kit, Vector3(-4.6 + float(col) * 2.0, 0.0, -13.0 + float(row) * 2.4), 0.0)
	_desk(kit, Vector3(3.4, 0.0, -12.4), PI * 0.5)
	_desk(kit, Vector3(3.4, 0.0, -9.0), PI * 0.5)
	_holo_table(kit, Vector3(0.8, 0.0, -10.5), 0.0)
	_screen(kit, Vector3(-0.4, 2.1, -14.2), PI)
	_locker_bank(kit, Vector3(4.6, 0.0, -7.8), 0.0, 2)
	kit.cylinder(0.8, 0.9, 2.4, 10, Vector3(-3.0, 1.2, -7.4), &"glass")
	kit.torus(0.82, 0.98, Vector3(-3.0, 1.7, -7.4), &"glow_teal", Vector3.ZERO, false)
	kit.cylinder(0.8, 0.9, 2.4, 10, Vector3(-1.0, 1.2, -7.4), &"glass")
	kit.torus(0.82, 0.98, Vector3(-1.0, 1.7, -7.4), &"glow_teal", Vector3.ZERO, false)
	_cable_run(kit, Vector3(-5.4, 0.0, -10.8), Vector3(-5.4, 0.0, -7.2))
	_crate_row(kit, Vector3(5.2, 0.0, -13.0), PI * 0.5, 2, &"ivory_warm")
	for c in 4:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(10.0, 15.0)
		kit.box(Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.2)), Vector3(cos(ang) * dist, 0.35, sin(ang) * dist), &"steel" if c % 2 == 0 else &"rust", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 0.7
		_barrier(kit, Vector3(cos(ang) * 19.0, 0.0, sin(ang) * 17.0), ang + PI * 0.5)
	_add_light(root, Vector3(0.0, 4.2, 7.0), Color(0.40, 1.0, 0.92), 1.8, 20.0)
	_add_light(root, Vector3(0.0, 2.6, -11.0), Color(0.45, 0.95, 1.0), 1.0, 10.0)


# =============================================================================
# POI: water works (tanks, catwalks, pipes, settling basins)
# =============================================================================
func _build_water_works(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 24.0, &"concrete")
	# Two settling basins ringed by low concrete walls.
	_settling_basin(kit, Vector3(-11.5, 0.0, -6.0), 6.4)
	_settling_basin(kit, Vector3(11.5, 0.0, -6.0), 5.6)
	# Elevated tank pair joined by a catwalk.
	_elevated_water_tank(kit, Vector3(-6.5, 0.0, 11.0))
	_elevated_water_tank(kit, Vector3(6.5, 0.0, 11.0))
	_catwalk(kit, Vector3(-4.0, 0.0, 11.0), Vector3(4.0, 0.0, 11.0), 5.6, 1.8)
	_catwalk(kit, Vector3(0.0, 0.0, 12.2), Vector3(0.0, 0.0, 16.4), 5.4, 1.6)
	_stair(kit, Vector3(0.0, 0.0, 16.8), PI, 1.6, 18, 0.30, 0.32)
	# Water tower: tall silhouette for 300 m readability.
	kit.cylinder(1.5, 1.8, 0.4, 10, Vector3(15.5, 0.2, 8.5), &"concrete")
	kit.cylinder(0.32, 0.45, 14.0, 8, Vector3(15.5, 7.2, 8.5), &"steel")
	for f in 3:
		kit.torus(0.45, 0.58, Vector3(15.5, 4.0 + float(f) * 3.6, 8.5), &"rust_dark", Vector3.ZERO, false)
	kit.cylinder(3.5, 3.5, 3.0, 14, Vector3(15.5, 15.8, 8.5), &"ivory_warm")
	kit.cylinder(0.2, 3.6, 1.2, 14, Vector3(15.5, 17.9, 8.5), &"rust_dark", Vector3.ZERO, false)
	kit.torus(3.35, 3.55, Vector3(15.5, 14.4, 8.5), &"steel", Vector3.ZERO, false)
	kit.sphere(0.3, Vector3(15.5, 18.7, 8.5), &"glow_teal", Vector3.ZERO, false, 6, 3)
	_ladder(kit, Vector3(18.9, 0.0, 8.5), 14.0, 0.0)
	# Pump house at the courtyard edge.
	_interior_shell(root, kit, Vector3(0.0, 0.0, 20.0), Vector3(8.0, 0.0, 6.0), [1], &"ivory", &"concrete", 3.2, Color(0.45, 0.95, 1.0), &"glow_teal")
	kit.box(Vector3(9.2, 0.35, 7.2), Vector3(0.0, 3.4, 20.0), &"rust")
	_roof_kit(kit, Vector3(0.0, 0.0, 20.0), Vector2(4.6, 3.0), 3.6)
	_awning(kit, Vector3(0.0, 0.0, 17.0), 0.0, 4.4, 2.4)
	# Pipe network: basins -> pump house, tanks -> pump house, tower -> manifold.
	_pipe_run(kit, Vector3(-11.5, 1.0, -3.4), Vector3(-11.5, 1.0, 13.0), 0.28, &"steel")
	_pipe_run(kit, Vector3(-11.5, 1.0, 13.0), Vector3(-3.0, 1.0, 17.4), 0.28, &"steel")
	_pipe_run(kit, Vector3(11.5, 1.0, -3.4), Vector3(11.5, 1.0, 13.0), 0.28, &"steel")
	_pipe_run(kit, Vector3(11.5, 1.0, 13.0), Vector3(3.0, 1.0, 17.4), 0.28, &"steel")
	_pipe_run(kit, Vector3(-6.5, 5.6, 11.0), Vector3(-6.5, 5.6, 16.0), 0.2, &"rust")
	_pipe_run(kit, Vector3(6.5, 5.6, 11.0), Vector3(6.5, 5.6, 16.0), 0.2, &"rust")
	_pipe_run(kit, Vector3(15.5, 2.0, 8.5), Vector3(9.0, 2.0, 14.0), 0.24, &"steel")
	for v in 4:
		_box_valve_cluster(kit, Vector3(-6.0 + float(v) * 4.0, 0.0, 14.6), 0.0)
	# Pump machinery and interior control furniture.
	for p in 2:
		var px := -2.2 + float(p) * 4.4
		kit.cylinder(0.9, 1.1, 1.3, 10, Vector3(px, 0.65, 21.4), &"rust")
		kit.box(Vector3(1.2, 0.9, 1.2), Vector3(px, 0.65, 19.8), &"steel")
		kit.torus(0.5, 0.62, Vector3(px, 1.35, 20.6), &"glow_teal", Vector3(PI * 0.5, 0.0, 0.0), false)
	_desk(kit, Vector3(-2.8, 0.0, 22.4), PI)
	_locker_bank(kit, Vector3(3.2, 0.0, 22.2), PI, 2)
	_screen(kit, Vector3(2.6, 2.1, 23.2), PI)
	_interior_partition(kit, Vector3(0.0, 0.0, 20.0), Vector3(8.0, 0.0, 6.0), 0, -0.5, true, &"ivory_warm", 3.2)
	_cable_run(kit, Vector3(-3.4, 0.0, 18.6), Vector3(3.4, 0.0, 18.6))
	# Service details: vents, hazard rails, marker lamps, salvage.
	_vent(kit, Vector3(-4.4, 2.6, 20.0), PI * 0.5, Vector3(1.0, 0.7, 0.4))
	_vent(kit, Vector3(4.4, 2.6, 20.0), PI * 0.5, Vector3(1.0, 0.7, 0.4))
	_hazard_stripes(kit, Vector3(0.0, 0.02, 16.4), 0.0, 5.0, 0.8)
	_railing(kit, Vector3(-11.5, 1.0, -2.0), Vector3(-11.5, 1.0, 2.0), 0.9, 3)
	_railing(kit, Vector3(11.5, 1.0, -2.0), Vector3(11.5, 1.0, 2.0), 0.9, 3)
	_water_tank(kit, Vector3(-16.5, 0.0, 4.0), 1.5, 3.0)
	_tarp(kit, Vector3(-8.0, 0.0, 18.0), 0.3, 2.6, 2.0)
	_crate_row(kit, Vector3(8.0, 0.0, 17.5), PI * 0.5, 3, &"rust")
	_signage(kit, Vector3(4.4, 0.0, 16.6), 0.0, &"glow_teal")
	for b in 4:
		var ang := TAU * float(b) / 4.0 + 1.0
		_barrier(kit, Vector3(cos(ang) * 20.0, 0.0, sin(ang) * 18.0), ang + PI * 0.5)
	for c in 5:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(10.0, 16.0)
		kit.box(Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.3, 0.7), rng.randf_range(0.5, 1.2)), Vector3(cos(ang) * dist, 0.35, sin(ang) * dist + 4.0), &"rust" if c % 2 == 0 else &"steel", Vector3(0.0, rng.randf() * TAU, 0.0), false)
	_lamp(kit, Vector3(-7.0, 0.0, 15.0), &"glow_teal")
	_lamp(kit, Vector3(7.0, 0.0, 15.0), &"glow_teal")
	_add_light(root, Vector3(0.0, 3.0, 20.0), Color(0.45, 0.95, 1.0), 1.0, 10.0)
	_add_light(root, Vector3(15.5, 18.8, 8.5), Color(0.35, 0.95, 0.85), 1.4, 18.0)


# =============================================================================
# Roadside outbuildings
# =============================================================================
func _build_roadside_checkpoint(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.box(Vector3(5.0, 2.6, 4.0), Vector3(-2.0, 1.4, 0.0), &"concrete")
	kit.box(Vector3(5.6, 0.3, 4.6), Vector3(-2.0, 2.9, 0.0), &"rust")
	kit.box(Vector3(1.0, 1.8, 0.2), Vector3(-2.0, 1.2, 2.1), &"dark")
	kit.box(Vector3(4.8, 0.3, 0.13), Vector3(6.0, 1.0, 0.0), &"glow_amber", Vector3.ZERO, false)
	for leg in 2:
		kit.cylinder(0.09, 0.12, 2.4, 5, Vector3(4.0 + float(leg) * 2.4, 1.2, 0.0), &"steel", Vector3.ZERO, false)
	_barrier(kit, Vector3(6.0, 0.0, 3.0), PI * 0.5)
	_crates(kit, rng, Vector3(-1.0, 0.0, -3.5), 2)
	_lamp(kit, Vector3(-4.5, 0.0, 2.0), &"glow_amber")


func _build_roadside_relay(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.box(Vector3(3.0, 0.5, 3.0), Vector3(0.0, 0.25, 0.0), &"concrete")
	kit.cylinder(0.16, 0.3, 6.0, 6, Vector3(0.0, 3.3, 0.0), &"steel", Vector3.ZERO, true)
	kit.box(Vector3(1.2, 1.6, 1.2), Vector3(0.0, 1.0, 0.0), &"steel")
	kit.sphere(0.35, Vector3(0.0, 6.5, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)
	for fence in 2:
		kit.box(Vector3(3.0, 1.2, 0.2), Vector3(-3.0 + float(fence) * 6.0, 0.7, 2.2), &"rust_dark", Vector3(0.0, 0.2, 0.0))
	_crates(kit, rng, Vector3(2.2, 0.0, -2.0), 1)


func _build_roadside_ruin(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	kit.box(Vector3(9.0, 3.6, 0.9), Vector3(0.0, 1.8, -1.5), &"ivory", Vector3(0.0, 0.15, 0.0))
	kit.box(Vector3(0.9, 3.2, 5.0), Vector3(-4.0, 1.6, 0.8), &"ivory", Vector3(0.0, 0.15, 0.0))
	kit.box(Vector3(3.0, 1.0, 2.4), Vector3(1.0, 0.5, 1.6), &"concrete", Vector3(0.0, 0.3, 0.05))
	kit.cylinder(0.8, 1.0, 4.0, 7, Vector3(3.5, 0.6, 2.4), &"ivory_warm", Vector3(1.2, 0.4, 0.2), true)
	_crates(kit, rng, Vector3(-2.0, 0.0, 2.0), 1)


func _build_fallback(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 14.0, &"pad")
	kit.box(Vector3(6.0, 2.6, 5.0), Vector3(0.0, 1.5, 0.0), &"ivory")
	_crates(kit, rng, Vector3(5.0, 0.0, 3.0), 2)


# =============================================================================
# Prop helpers
# =============================================================================
func _make_root(parent: Node3D, node_name: String, info: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = info["position"]
	root.rotation.y = float(info.get("yaw", 0.0))
	parent.add_child(root)
	root.set_meta("world_info", info)
	return root


func _finalize(root: Node3D, kit: MeshKit, info: Dictionary) -> void:
	# Authored-content budget is surfaced on the root so world_test can assert the
	# detail pass actually authored geometry per kit (and not just scaled noise).
	root.set_meta("primitive_count", kit.primitive_count)
	root.set_meta("collision_triangle_count", kit.collision_triangle_count)
	var mesh := kit.build_mesh()
	if mesh != null:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		root.add_child(mi)
	var shape := kit.build_collision_shape()
	if shape != null:
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("nav_source")
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	var anchor := Marker3D.new()
	anchor.name = "Anchor"
	root.add_child(anchor)
	anchor.set_meta("world_info", info)


# =============================================================================
# Enterable interiors
# =============================================================================

const INTERIOR_WALL := 0.5
const INTERIOR_DOOR_W := 4.2
const INTERIOR_DOOR_H := 3.2


## Builds a hollow room: floor, ceiling, four walls and optional 4.2m doorways.
## Doorways are deliberately wider than the navmesh agent diameter so the baked
## navmesh can path through them.
func _interior_shell(
	root: Node3D,
	kit: MeshKit,
	center: Vector3,
	inner: Vector3,
	door_sides: Array,
	wall_mat: StringName,
	floor_mat: StringName,
	height: float = 3.8,
	light_color: Color = Color(0.45, 0.95, 0.85),
	accent: StringName = &"glow_teal",
	spawn_tag: String = ""
) -> void:
	var wall_len_x := inner.x + INTERIOR_WALL * 2.0
	var wall_len_z := inner.z + INTERIOR_WALL * 2.0
	kit.box(Vector3(wall_len_x, 0.3, wall_len_z), center + Vector3(0.0, 0.15, 0.0), floor_mat)
	kit.box(Vector3(wall_len_x, 0.3, wall_len_z), center + Vector3(0.0, height + 0.15, 0.0), wall_mat)
	for side in 4:
		_interior_wall(kit, center, inner, side, side in door_sides, wall_mat, height)
	for rib in 3:
		var rz := center.z - inner.z * 0.33 + float(rib) * inner.z * 0.33
		kit.box(Vector3(wall_len_x, 0.16, 0.16), Vector3(center.x, height - 0.1, rz), accent, Vector3.ZERO, false)
	_interior_light(root, center + Vector3(0.0, height - 0.7, 0.0), light_color, 1.4, maxf(inner.x, inner.z) * 0.8)
	_interior_spawns(root, center, inner, 4, spawn_tag)


func _interior_wall(
	kit: MeshKit,
	center: Vector3,
	inner: Vector3,
	side: int,
	has_door: bool,
	wall_mat: StringName,
	height: float
) -> void:
	var t := INTERIOR_WALL
	var wall_len := 0.0
	var pos := Vector3.ZERO
	var size := Vector3.ZERO
	var axis_x := side == 0 or side == 1
	if axis_x:
		wall_len = inner.x + t * 2.0
		var z := center.z + (inner.z * 0.5 + t * 0.5) if side == 0 else center.z - (inner.z * 0.5 + t * 0.5)
		pos = Vector3(center.x, height * 0.5, z)
		size = Vector3(wall_len, height, t)
	else:
		wall_len = inner.z + t * 2.0
		var x := center.x + (inner.x * 0.5 + t * 0.5) if side == 2 else center.x - (inner.x * 0.5 + t * 0.5)
		pos = Vector3(x, height * 0.5, center.z)
		size = Vector3(t, height, wall_len)
	if not has_door:
		kit.box(size, pos, wall_mat)
		return
	var door_w := minf(INTERIOR_DOOR_W, wall_len * 0.62)
	var seg_len := (wall_len - door_w) * 0.5
	for side_sign in [-1.0, 1.0]:
		var offset: float = float(side_sign) * (door_w * 0.5 + seg_len * 0.5)
		var seg_pos := pos
		var seg_size := size
		if axis_x:
			seg_pos.x += offset
			seg_size.x = seg_len
		else:
			seg_pos.z += offset
			seg_size.z = seg_len
		kit.box(seg_size, seg_pos, wall_mat)
	var lintel_h := maxf(0.2, height - INTERIOR_DOOR_H)
	var lintel_pos := pos
	var lintel_size := size
	lintel_pos.y = INTERIOR_DOOR_H + lintel_h * 0.5
	if axis_x:
		lintel_size.x = door_w
	else:
		lintel_size.z = door_w
	lintel_size.y = lintel_h
	kit.box(lintel_size, lintel_pos, wall_mat)


## Interior partition with an optional doorway. `axis` 0 runs across X (a wall
## plane at center.x + offset); axis 1 runs across Z.
func _interior_partition(
	kit: MeshKit,
	center: Vector3,
	inner: Vector3,
	axis: int,
	offset: float,
	has_door: bool,
	wall_mat: StringName,
	height: float
) -> void:
	var t := 0.4
	var wall_len := inner.z if axis == 0 else inner.x
	var pos := Vector3(center.x + offset, height * 0.5, center.z) if axis == 0 else Vector3(center.x, height * 0.5, center.z + offset)
	var size := Vector3(t, height, wall_len) if axis == 0 else Vector3(wall_len, height, t)
	if not has_door:
		kit.box(size, pos, wall_mat)
		return
	var door_w := minf(INTERIOR_DOOR_W, wall_len * 0.62)
	var seg_len := (wall_len - door_w) * 0.5
	for side_sign in [-1.0, 1.0]:
		var seg_pos := pos
		var seg_size := size
		if axis == 0:
			seg_pos.z += side_sign * (door_w * 0.5 + seg_len * 0.5)
			seg_size.z = seg_len
		else:
			seg_pos.x += side_sign * (door_w * 0.5 + seg_len * 0.5)
			seg_size.x = seg_len
		kit.box(seg_size, seg_pos, wall_mat)
	var lintel_h := maxf(0.2, height - INTERIOR_DOOR_H)
	var lintel_pos := pos
	var lintel_size := size
	lintel_pos.y = INTERIOR_DOOR_H + lintel_h * 0.5
	if axis == 0:
		lintel_size.z = door_w
	else:
		lintel_size.x = door_w
	lintel_size.y = lintel_h
	kit.box(lintel_size, lintel_pos, wall_mat)


func _interior_spawns(root: Node3D, center: Vector3, inner: Vector3, count: int, tag: String = "") -> void:
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(inner.x * 0.30, 0.0, inner.z * 0.30),
		Vector3(-inner.x * 0.30, 0.0, -inner.z * 0.30),
		Vector3(inner.x * 0.30, 0.0, -inner.z * 0.30),
		Vector3(-inner.x * 0.30, 0.0, inner.z * 0.30),
	]
	for i in mini(count, offsets.size()):
		var marker := Marker3D.new()
		if tag.is_empty():
			marker.name = "InteriorSpawn_%02d" % i
		else:
			marker.name = "InteriorSpawn_%s_%02d" % [tag, i]
		marker.position = center + offsets[i] + Vector3(0.0, 0.25, 0.0)
		marker.add_to_group("interior_spawn")
		root.add_child(marker)


func _interior_light(root: Node3D, pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	root.add_child(light)


func _dungeon_anchor(root: Node3D, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "DungeonAnchor"
	marker.position = pos
	marker.add_to_group("dungeon_anchor")
	root.add_child(marker)


func _pad(kit: MeshKit, radius: float, mat: StringName) -> void:
	kit.cylinder(radius, radius + 0.6, 0.5, 20, Vector3(0.0, 0.05, 0.0), mat)
	kit.cylinder(radius + 0.7, radius + 1.0, 0.22, 20, Vector3(0.0, -0.05, 0.0), &"rust_dark")
	# A few inset plates so the pad is not a perfect disc.
	kit.box(Vector3(radius * 0.9, 0.1, 0.5), Vector3(0.0, 0.32, 0.0), &"concrete", Vector3.ZERO, false)
	kit.box(Vector3(0.5, 0.1, radius * 0.9), Vector3(0.0, 0.32, 0.0), &"concrete", Vector3.ZERO, false)


func _crate(kit: MeshKit, pos: Vector3, yaw: float, mat: StringName) -> void:
	kit.box(Vector3(1.3, 1.3, 1.3), pos + Vector3(0.0, 0.65, 0.0), mat, Vector3(0.0, yaw, 0.0))


func _crates(kit: MeshKit, rng: RandomNumberGenerator, center: Vector3, count: int) -> void:
	for i in count:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.0, 2.2)
		var p := center + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		var mat: StringName = &"rust" if i % 2 == 0 else &"ivory_warm"
		var stack := rng.randi_range(1, 2)
		for s in stack:
			kit.box(Vector3(1.2, 1.0, 1.2), p + Vector3(0.0, 0.5 + float(s) * 1.02, 0.0), mat, Vector3(0.0, rng.randf() * TAU, 0.0), s == 0)


func _barrier(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var rot := Vector3(0.0, yaw, 0.0)
	kit.box(Vector3(3.0, 1.15, 0.85), pos + Vector3(0.0, 0.6, 0.0), &"concrete", rot)
	kit.box(Vector3(0.45, 0.35, 1.0), pos + Vector3(-0.9, 0.18, 0.0), &"rust_dark", rot, false)
	kit.box(Vector3(0.45, 0.35, 1.0), pos + Vector3(0.9, 0.18, 0.0), &"rust_dark", rot, false)


func _container(kit: MeshKit, pos: Vector3, yaw: float, mat: StringName) -> void:
	var rot := Vector3(0.0, yaw, 0.0)
	kit.box(Vector3(6.2, 2.6, 2.5), pos, mat, rot)
	kit.box(Vector3(6.3, 0.28, 2.62), pos + Vector3(0.0, 0.7, 0.0), &"ivory_warm", rot, false)
	kit.box(Vector3(6.3, 0.28, 2.62), pos + Vector3(0.0, -0.7, 0.0), &"rust_dark", rot, false)
	kit.box(Vector3(0.18, 1.1, 2.3), pos + Vector3(2.4, 0.0, 0.0), &"dark", rot, false)


func _watchtower(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var rot := Vector3(0.0, yaw, 0.0)
	for l in 4:
		var sx := -1.7 if l % 2 == 0 else 1.7
		var sz := -1.7 if l < 2 else 1.7
		kit.cylinder(0.16, 0.22, 6.4, 6, pos + Vector3(sx, 3.2, sz), &"steel", rot, false)
	kit.box(Vector3(4.6, 0.3, 4.6), pos + Vector3(0.0, 6.5, 0.0), &"ivory_warm", rot)
	kit.box(Vector3(0.25, 1.0, 4.6), pos + Vector3(-2.2, 7.1, 0.0), &"ivory", rot, false)
	kit.box(Vector3(0.25, 1.0, 4.6), pos + Vector3(2.2, 7.1, 0.0), &"ivory", rot, false)
	kit.box(Vector3(4.6, 0.25, 0.3), pos + Vector3(0.0, 7.1, -2.2), &"ivory", rot, false)
	kit.box(Vector3(5.0, 0.25, 5.0), pos + Vector3(0.0, 8.4, 0.0), &"rust", rot, false)
	kit.cylinder(0.12, 0.12, 6.4, 5, pos + Vector3(1.7, 3.2, 1.7), &"steel", rot, false)
	kit.box(Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 6.9, 2.1), &"glow_amber", rot, false)


func _antenna(kit: MeshKit, pos: Vector3, height: float) -> void:
	kit.cylinder(0.10, 0.20, height, 5, pos + Vector3(0.0, height * 0.5, 0.0), &"steel", Vector3.ZERO, false)
	for b in 3:
		var y := height * (0.35 + 0.2 * float(b))
		kit.cylinder(0.05, 0.05, 2.4 - float(b) * 0.5, 4, pos + Vector3(0.0, y, 0.0), &"steel", Vector3(0.0, 0.0, PI * 0.5), false)
	kit.sphere(0.22, pos + Vector3(0.0, height + 0.2, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)


func _banner(kit: MeshKit, pos: Vector3, yaw: float, mat: StringName) -> void:
	var rot := Vector3(0.0, yaw, 0.0)
	kit.cylinder(0.08, 0.10, 5.0, 5, pos + Vector3(0.0, 2.5, 0.0), &"steel", rot, false)
	kit.box(Vector3(0.08, 2.2, 1.5), pos + Vector3(0.0, 3.7, 0.8), mat, rot, false)


func _lamp(kit: MeshKit, pos: Vector3, mat: StringName) -> void:
	kit.cylinder(0.08, 0.12, 3.4, 5, pos + Vector3(0.0, 1.7, 0.0), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(0.45, 0.35, 0.45), pos + Vector3(0.0, 3.5, 0.0), mat, Vector3.ZERO, false)


# =============================================================================
# Detail-pass vocabulary: furniture, roof kits, services, props.
## Every helper is authored (deterministic offsets), so detail reads as design
## rather than random visual noise. Compound helpers keep the builders short.
# =============================================================================

## One stretched box between two points (headers, beams, rails, cable trays).
func _beam(kit: MeshKit, a: Vector3, b: Vector3, thickness: float, mat: StringName, collide := false) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.01:
		return
	kit.box(Vector3(thickness, length, thickness), (a + b) * 0.5, mat, _rotation_from_up(delta / length), collide)


## Cylinder pipe run between two points (pipes, conduits, coolant lines).
func _pipe_run(kit: MeshKit, a: Vector3, b: Vector3, radius: float, mat: StringName) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.01:
		return
	kit.cylinder(radius, radius, length, 6, (a + b) * 0.5, mat, _rotation_from_up(delta / length), false)


## Guardrail between two floor points: posts plus two horizontal rails.
func _railing(kit: MeshKit, a: Vector3, b: Vector3, height: float, posts: int) -> void:
	var count := maxi(2, posts)
	for p in count + 1:
		var base := a.lerp(b, float(p) / float(count))
		kit.cylinder(0.05, 0.05, height, 4, base + Vector3(0.0, height * 0.5, 0.0), &"steel", Vector3.ZERO, false)
	_beam(kit, a + Vector3(0.0, height, 0.0), b + Vector3(0.0, height, 0.0), 0.09, &"steel")
	_beam(kit, a + Vector3(0.0, height * 0.55, 0.0), b + Vector3(0.0, height * 0.55, 0.0), 0.055, &"steel")


## Wall ladder with capped rungs (service access to roofs and catwalks).
func _ladder(kit: MeshKit, base: Vector3, height: float, yaw := 0.0) -> void:
	if height < 0.8:
		return
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in 2:
		var off := b * Vector3(0.32 * (1.0 if s == 0 else -1.0), 0.0, 0.0)
		kit.cylinder(0.05, 0.05, height, 4, base + off + Vector3(0.0, height * 0.5, 0.0), &"steel", rot, false)
	var rungs := clampi(int(height / 0.55), 2, 10)
	for r in rungs:
		var y := height * (float(r) + 0.5) / float(rungs)
		kit.box(Vector3(0.68, 0.05, 0.06), base + b * Vector3(0.0, y, 0.0), &"steel", rot, false)


## Desk with terminal, papers and a stool. Cover at gameplay height.
func _desk(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(1.7, 0.09, 0.85), pos + Vector3(0.0, 0.78, 0.0), &"ivory_warm", rot, true)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.08, 0.74, 0.78), pos + b * Vector3(float(side) * 0.76, 0.38, 0.0), &"steel", rot, false)
	var term := pos + b * Vector3(-0.4, 0.98, -0.2)
	kit.box(Vector3(0.62, 0.42, 0.08), term, &"dark", rot, false)
	kit.box(Vector3(0.5, 0.3, 0.03), term + b * Vector3(0.0, 0.0, 0.055), &"glow_teal", rot, false)
	kit.box(Vector3(0.34, 0.04, 0.24), pos + b * Vector3(0.5, 0.84, 0.16), &"ivory", rot, false)
	kit.box(Vector3(0.46, 0.09, 0.46), pos + b * Vector3(0.0, 0.5, 0.95), &"dark", rot, false)
	kit.cylinder(0.05, 0.06, 0.5, 5, pos + b * Vector3(0.0, 0.25, 0.95), &"steel", rot, false)


## Open shelf unit with a few authored supply boxes.
func _shelf(kit: MeshKit, pos: Vector3, yaw: float, width := 1.8, height := 1.9, depth := 0.45) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(width, height, 0.06), pos + b * Vector3(0.0, height * 0.5, -depth * 0.5), &"steel", rot, false)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.06, height, depth), pos + b * Vector3(float(side) * width * 0.5, height * 0.5, 0.0), &"steel", rot, false)
	for i in 3:
		var y := 0.32 + float(i) * (height - 0.5) * 0.5
		kit.box(Vector3(width, 0.05, depth), pos + b * Vector3(0.0, y, 0.0), &"ivory_warm", rot, false)
	kit.box(Vector3(0.42, 0.3, 0.3), pos + b * Vector3(-0.35, 1.02, 0.0), &"rust", rot, false)
	kit.box(Vector3(0.34, 0.26, 0.28), pos + b * Vector3(0.4, 0.55, 0.0), &"ivory_warm", rot, false)


## Bank of crew lockers with lit vents.
func _locker_bank(kit: MeshKit, pos: Vector3, yaw: float, count := 3) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	var span := 0.95 * float(count)
	for i in count:
		var off := -span * 0.5 + 0.475 + float(i) * 0.95
		var p := pos + b * Vector3(off, 0.0, 0.0)
		kit.box(Vector3(0.9, 2.0, 0.6), p + Vector3(0.0, 1.0, 0.0), &"steel", rot, true)
		kit.box(Vector3(0.78, 1.7, 0.05), p + b * Vector3(0.0, 1.0, 0.32), &"dark", rot, false)
		kit.box(Vector3(0.5, 0.06, 0.05), p + b * Vector3(0.0, 1.62, 0.35), &"glow_teal", rot, false)
		kit.box(Vector3(0.06, 0.3, 0.05), p + b * Vector3(0.3, 1.0, 0.35), &"rust_dark", rot, false)


## Two-tier bunk with frame, mattresses and a storage crate underneath.
func _bunk(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.cylinder(0.06, 0.07, 1.95, 5, pos + b * Vector3(float(sx) * 0.9, 0.98, float(sz) * 1.0), &"steel", rot, false)
	kit.box(Vector3(1.8, 0.18, 1.95), pos + Vector3(0.0, 0.58, 0.0), &"fabric", rot, true)
	kit.box(Vector3(1.9, 0.08, 2.0), pos + Vector3(0.0, 1.66, 0.0), &"steel", rot, false)
	kit.box(Vector3(1.75, 0.14, 1.9), pos + Vector3(0.0, 1.79, 0.0), &"fabric", rot, false)
	kit.box(Vector3(0.5, 0.12, 0.3), pos + b * Vector3(-0.55, 0.72, -0.7), &"ivory_warm", rot, false)
	kit.box(Vector3(0.8, 0.5, 0.7), pos + b * Vector3(0.6, 0.25, 0.6), &"rust_dark", rot, false)


## Round holo-table with an emitter rim and floating projection.
func _holo_table(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.cylinder(0.7, 0.9, 0.9, 8, pos + Vector3(0.0, 0.45, 0.0), &"steel", rot, false)
	kit.cylinder(1.1, 1.1, 0.12, 12, pos + Vector3(0.0, 0.95, 0.0), &"ivory_warm", rot, false)
	kit.torus(0.84, 0.96, pos + Vector3(0.0, 1.03, 0.0), &"glow_teal", Vector3.ZERO, false)
	kit.sphere(0.34, pos + Vector3(0.0, 1.48, 0.0), &"glow_teal", Vector3.ZERO, false, 8, 4)
	for e in 3:
		var ang := TAU * float(e) / 3.0
		kit.box(Vector3(0.14, 0.14, 0.14), pos + b * Vector3(cos(ang) * 0.75, 1.0, sin(ang) * 0.75), &"dark", rot, false)


## Flat screen with a glow panel and mount.
func _screen(kit: MeshKit, pos: Vector3, yaw: float, size := Vector3(1.4, 0.9, 0.12)) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(size, pos, &"dark", rot, false)
	kit.box(Vector3(size.x * 0.86, size.y * 0.78, 0.03), pos + b * Vector3(0.0, 0.0, 0.07), &"glow_teal", rot, false)
	kit.box(Vector3(0.14, 0.12, 0.16), pos + b * Vector3(0.0, size.y * 0.5 + 0.05, -0.1), &"steel", rot, false)


## Exterior vent housing with slats.
func _vent(kit: MeshKit, pos: Vector3, yaw: float, size := Vector3(1.1, 0.8, 0.35)) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(size, pos, &"steel", rot, false)
	kit.box(Vector3(size.x * 0.82, size.y * 0.78, 0.04), pos + b * Vector3(0.0, 0.0, size.z * 0.5), &"dark", rot, false)
	for s in 3:
		var y := -size.y * 0.28 + float(s) * size.y * 0.28
		kit.box(Vector3(size.x * 0.7, 0.05, 0.05), pos + b * Vector3(0.0, y, size.z * 0.5 + 0.03), &"rust_dark", rot, false)


## Fabric awning on two posts, with a lit valance.
func _awning(kit: MeshKit, pos: Vector3, yaw: float, width := 4.0, depth := 2.4) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in [-1.0, 1.0]:
		kit.cylinder(0.06, 0.08, 2.6, 5, pos + b * Vector3(float(s) * width * 0.45, 1.3, depth), &"steel", rot, false)
	var slab_basis := b * Basis(Vector3.RIGHT, 0.16)
	kit.box(Vector3(width, 0.1, depth), pos + b * Vector3(0.0, 2.72, depth * 0.5), &"fabric", slab_basis.get_euler(), false)
	kit.box(Vector3(width, 0.24, 0.08), pos + b * Vector3(0.0, 2.5, depth), &"rust", rot, false)
	kit.box(Vector3(width * 0.8, 0.05, 0.1), pos + b * Vector3(0.0, 2.6, depth * 0.55), &"glow_amber", rot, false)


## Freestanding sign board with posts and a lit face.
func _signage(kit: MeshKit, pos: Vector3, yaw: float, accent: StringName = &"glow_amber", width := 2.2) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in [-1.0, 1.0]:
		kit.cylinder(0.06, 0.07, 2.5, 5, pos + b * Vector3(float(s) * width * 0.4, 1.25, 0.0), &"steel", rot, false)
	kit.box(Vector3(width, 0.9, 0.1), pos + Vector3(0.0, 2.4, 0.0), &"dark", rot, false)
	kit.box(Vector3(width * 0.88, 0.6, 0.04), pos + b * Vector3(0.0, 2.4, 0.07), accent, rot, false)
	kit.box(Vector3(width, 0.08, 0.14), pos + Vector3(0.0, 2.9, 0.0), &"rust_dark", rot, false)


## Ground water tank on legs with banding, lid and outlet.
func _water_tank(kit: MeshKit, pos: Vector3, radius := 1.6, height := 3.2) -> void:
	var leg_h := height * 0.45
	for l in 4:
		var ang := TAU * float(l) / 4.0 + PI * 0.25
		kit.cylinder(0.1, 0.13, leg_h, 5, pos + Vector3(cos(ang) * radius * 0.62, leg_h * 0.5, sin(ang) * radius * 0.62), &"steel", Vector3.ZERO, false)
	kit.cylinder(radius, radius, height, 12, pos + Vector3(0.0, leg_h + height * 0.5, 0.0), &"ivory_warm")
	kit.torus(radius - 0.06, radius + 0.06, pos + Vector3(0.0, leg_h + 0.35, 0.0), &"steel", Vector3.ZERO, false)
	kit.torus(radius - 0.06, radius + 0.06, pos + Vector3(0.0, leg_h + height - 0.4, 0.0), &"steel", Vector3.ZERO, false)
	kit.cylinder(0.2, radius * 1.02, 0.55, 12, pos + Vector3(0.0, leg_h + height + 0.27, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.cylinder(0.12, 0.12, height * 0.8, 5, pos + Vector3(radius + 0.35, leg_h * 0.6, 0.0), &"steel", Vector3.ZERO, false)
	_pipe_run(kit, pos + Vector3(radius, leg_h + 0.5, 0.0), pos + Vector3(radius + 1.2, 0.3, 0.0), 0.1, &"rust")
	kit.box(Vector3(0.5, 0.5, 0.5), pos + Vector3(-radius - 0.2, 0.9, 0.0), &"rust_dark", Vector3.ZERO, false)


## Tilted solar panel array on two legs.
func _solar_panel(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in [-1.0, 1.0]:
		kit.box(Vector3(0.08, 0.8, 0.08), pos + b * Vector3(float(s) * 0.8, 0.4, 0.0), &"steel", rot, false)
	var panel_basis := b * Basis(Vector3.RIGHT, 0.42)
	kit.box(Vector3(2.2, 0.08, 1.4), pos + b * Vector3(0.0, 0.95, 0.0), &"glass", panel_basis.get_euler(), false)
	kit.box(Vector3(2.3, 0.1, 0.12), pos + b * Vector3(0.0, 1.06, 0.74), &"steel", panel_basis.get_euler(), false)
	kit.box(Vector3(2.3, 0.1, 0.12), pos + b * Vector3(0.0, 0.84, -0.74), &"steel", panel_basis.get_euler(), false)


## Straight stair of authored steps (collidable so the catwalks are reachable).
func _stair(kit: MeshKit, pos: Vector3, yaw: float, width := 1.6, steps := 8, rise := 0.28, run := 0.34) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in steps:
		var step_pos := pos + b * Vector3(0.0, float(s) * rise + rise * 0.5, float(s) * run)
		kit.box(Vector3(width, rise, run * 1.15), step_pos, &"concrete", rot, true)
	for side in [-1.0, 1.0]:
		var rail_a := pos + b * Vector3(float(side) * width * 0.5, 0.95, 0.0)
		var rail_b := pos + b * Vector3(float(side) * width * 0.5, 0.95 + float(steps) * rise, float(steps) * run)
		_beam(kit, rail_a, rail_b, 0.06, &"steel")


## Elevated catwalk deck between two floor points, with guardrails.
func _catwalk(kit: MeshKit, a: Vector3, b: Vector3, deck_y: float, width: float) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 1.0:
		return
	var dir := Vector3(delta.x / length, 0.0, delta.z / length)
	var yaw := atan2(-dir.z, dir.x)
	var rot := Vector3(0.0, yaw, 0.0)
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var mid := (a + b) * 0.5 + Vector3(0.0, deck_y - 0.12, 0.0)
	kit.box(Vector3(length, 0.24, width), mid, &"steel", rot, true)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(length, 0.12, 0.14), mid + perp * float(side) * (width * 0.5) + Vector3(0.0, 0.16, 0.0), &"rust_dark", rot, false)
	var posts := maxi(2, int(length / 4.0))
	_railing(kit, a + perp * (width * 0.5) + Vector3(0.0, deck_y, 0.0), b + perp * (width * 0.5) + Vector3(0.0, deck_y, 0.0), 1.0, posts)
	_railing(kit, a - perp * (width * 0.5) + Vector3(0.0, deck_y, 0.0), b - perp * (width * 0.5) + Vector3(0.0, deck_y, 0.0), 1.0, posts)


## Covered ground-level walkway with posts, fabric roof and a lit underside.
func _walkway(kit: MeshKit, a: Vector3, b: Vector3, width: float) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 1.0:
		return
	var dir := Vector3(delta.x / length, 0.0, delta.z / length)
	var yaw := atan2(-dir.z, dir.x)
	var rot := Vector3(0.0, yaw, 0.0)
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var mid := (a + b) * 0.5
	kit.box(Vector3(length, 0.22, width), mid + Vector3(0.0, 0.11, 0.0), &"pad", rot)
	for s in [0.22, 0.78]:
		var p := a.lerp(b, s)
		for side in [-1.0, 1.0]:
			kit.cylinder(0.09, 0.11, 2.5, 5, p + perp * float(side) * width * 0.5 + Vector3(0.0, 1.25, 0.0), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(length + 0.6, 0.12, width + 0.5), mid + Vector3(0.0, 2.55, 0.0), &"fabric", rot, false)
	kit.box(Vector3(length * 0.8, 0.06, 0.12), mid + Vector3(0.0, 2.45, 0.0), &"glow_teal", rot, false)


## Door frame + lit lintel around an interior shell doorway.
func _basis_door_frame(kit: MeshKit, center: Vector3, inner: Vector3, side: int, mat: StringName) -> void:
	var t := INTERIOR_WALL
	var axis_x := side == 0 or side == 1
	var wall_len := (inner.x + t * 2.0) if axis_x else (inner.z + t * 2.0)
	var door_w := minf(INTERIOR_DOOR_W, wall_len * 0.62)
	var pos := Vector3.ZERO
	var yaw := 0.0
	if axis_x:
		var z := center.z + (inner.z * 0.5 + t * 0.5) if side == 0 else center.z - (inner.z * 0.5 + t * 0.5)
		pos = Vector3(center.x, 0.0, z)
	else:
		var x := center.x + (inner.x * 0.5 + t * 0.5) if side == 2 else center.x - (inner.x * 0.5 + t * 0.5)
		pos = Vector3(x, 0.0, center.z)
		yaw = PI * 0.5
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	for s in [-1.0, 1.0]:
		kit.box(Vector3(0.28, 3.2, 0.32), pos + b * Vector3(float(s) * (door_w * 0.5 + 0.16), 1.6, 0.0), mat, rot, false)
	kit.box(Vector3(door_w + 0.64, 0.3, 0.34), pos + Vector3(0.0, 3.35, 0.0), mat, rot, false)
	kit.box(Vector3(door_w * 0.9, 0.08, 0.1), pos + b * Vector3(0.0, 2.98, 0.18), &"glow_teal", rot, false)


## Authoritative roof kit: AC units, skylight, vent, solar panel and aerial.
func _roof_kit(kit: MeshKit, center: Vector3, size: Vector2, roof_y: float) -> void:
	var ac_offsets := [Vector3(-size.x * 0.22, 0.0, -size.y * 0.16), Vector3(size.x * 0.2, 0.0, size.y * 0.18)]
	for i in ac_offsets.size():
		var p: Vector3 = center + ac_offsets[i]
		kit.box(Vector3(1.3, 0.9, 1.0), p + Vector3(0.0, roof_y + 0.45, 0.0), &"steel")
		kit.box(Vector3(1.2, 0.5, 0.05), p + Vector3(0.0, roof_y + 0.45, 0.52), &"dark", Vector3.ZERO, false)
		kit.cylinder(0.42, 0.42, 0.1, 10, p + Vector3(0.0, roof_y + 0.94, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.box(Vector3(minf(size.x * 0.45, 2.4), 0.1, 1.2), center + Vector3(0.0, roof_y + 0.12, -size.y * 0.3), &"glass", Vector3.ZERO, false)
	kit.box(Vector3(minf(size.x * 0.45, 2.4) + 0.2, 0.14, 0.12), center + Vector3(0.0, roof_y + 0.16, -size.y * 0.3 - 0.62), &"steel", Vector3.ZERO, false)
	kit.box(Vector3(0.6, 0.5, 0.6), center + Vector3(size.x * 0.38, roof_y + 0.25, -size.y * 0.12), &"steel")
	kit.box(Vector3(0.5, 0.08, 0.5), center + Vector3(size.x * 0.38, roof_y + 0.54, -size.y * 0.12), &"dark", Vector3.ZERO, false)
	_solar_panel(kit, center + Vector3(-size.x * 0.36, roof_y, size.y * 0.3), 0.0)
	_antenna(kit, center + Vector3(size.x * 0.4, roof_y, size.y * 0.4), 3.4)
	_beam(kit, center + Vector3(-size.x * 0.3, roof_y + 0.12, size.y * 0.05), center + Vector3(size.x * 0.3, roof_y + 0.12, size.y * 0.05), 0.12, &"dark")


## Chimney stack with banding and an ember-lit crown.
func _chimney(kit: MeshKit, base: Vector3, height: float) -> void:
	kit.cylinder(1.25, 1.6, 0.6, 8, base + Vector3(0.0, 0.3, 0.0), &"concrete")
	kit.cylinder(0.92, 1.25, height, 10, base + Vector3(0.0, 0.6 + height * 0.5, 0.0), &"rust")
	for b in 3:
		var y := 1.0 + height * (0.25 + 0.25 * float(b))
		kit.torus(0.95 - float(b) * 0.05, 1.18 - float(b) * 0.05, base + Vector3(0.0, y, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.cylinder(0.98, 0.98, 0.3, 10, base + Vector3(0.0, height + 0.75, 0.0), &"steel", Vector3.ZERO, false)
	kit.sphere(0.6, base + Vector3(0.0, height + 1.0, 0.0), &"glow_ember", Vector3.ZERO, false, 6, 3)


## Server rack with three lit status bars.
func _server_rack(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(1.0, 2.2, 0.8), pos + Vector3(0.0, 1.1, 0.0), &"dark", rot, true)
	for i in 3:
		var mat: StringName = &"glow_teal" if i < 2 else &"glow_amber"
		kit.box(Vector3(0.86, 0.06, 0.05), pos + b * Vector3(0.0, 0.7 + float(i) * 0.4, 0.42), mat, rot, false)
	kit.box(Vector3(0.7, 0.1, 0.3), pos + Vector3(0.0, 2.25, 0.0), &"steel", rot, false)


## Valve manifold cluster (pipes, wheel and a junction box).
func _box_valve_cluster(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(1.6, 0.9, 0.7), pos + Vector3(0.0, 0.45, 0.0), &"steel", rot, false)
	kit.cylinder(0.12, 0.12, 1.4, 6, pos + Vector3(0.0, 1.3, 0.0), &"rust", rot, false)
	kit.torus(0.28, 0.38, pos + Vector3(0.0, 1.45, 0.0), &"glow_amber", Vector3(PI * 0.5, 0.0, 0.0), false)
	kit.box(Vector3(0.5, 0.08, 0.08), pos + b * Vector3(0.0, 1.0, 0.4), &"rust_dark", rot, false)


## Settling basin: ring of concrete wall segments over a glassy water disc.
func _settling_basin(kit: MeshKit, center: Vector3, radius: float) -> void:
	var segs := 16
	var seg_len := TAU * radius / float(segs) * 1.08
	for i in segs:
		var ang := TAU * float(i) / float(segs)
		var p := center + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		kit.box(Vector3(seg_len, 1.1, 0.55), p + Vector3(0.0, 0.55, 0.0), &"concrete", Vector3(0.0, -ang, 0.0))
	kit.cylinder(radius - 0.42, radius - 0.42, 0.12, 20, center + Vector3(0.0, 0.9, 0.0), &"glass", Vector3.ZERO, false)
	kit.torus(radius - 0.5, radius - 0.32, center + Vector3(0.0, 1.0, 0.0), &"glow_teal", Vector3.ZERO, false)
	kit.cylinder(0.5, 0.7, 0.7, 8, center + Vector3(0.0, 1.05, 0.0), &"steel")
	kit.sphere(0.32, center + Vector3(0.0, 1.6, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)


## Raised water tank on four legs with a domed lid and service ladder.
func _elevated_water_tank(kit: MeshKit, base: Vector3) -> void:
	for l in 4:
		var ang := TAU * float(l) / 4.0 + PI * 0.25
		kit.cylinder(0.22, 0.3, 5.6, 6, base + Vector3(cos(ang) * 2.0, 2.8, sin(ang) * 2.0), &"steel")
	kit.box(Vector3(4.4, 0.2, 4.4), base + Vector3(0.0, 5.5, 0.0), &"steel")
	for s in 2:
		var ang2 := TAU * float(s) / 2.0 + 0.4
		_beam(kit, base + Vector3(cos(ang2) * 2.0, 0.4, sin(ang2) * 2.0), base + Vector3(cos(ang2) * 2.0, 5.2, sin(ang2) * 2.0), 0.08, &"rust_dark")
	kit.cylinder(2.7, 2.7, 4.2, 14, base + Vector3(0.0, 7.7, 0.0), &"ivory_warm")
	kit.torus(2.62, 2.78, base + Vector3(0.0, 6.0, 0.0), &"steel", Vector3.ZERO, false)
	var lid := SphereMesh.new()
	lid.radius = 2.7
	lid.height = 5.4
	lid.radial_segments = 14
	lid.rings = 4
	kit.add_mesh_instance(lid, Transform3D(Basis.from_scale(Vector3(1.0, 0.3, 1.0)), base + Vector3(0.0, 9.8, 0.0)), &"rust_dark", false)
	_ladder(kit, base + Vector3(2.9, 0.0, 0.0), 10.0, 0.0)
	_pipe_run(kit, base + Vector3(2.7, 6.2, 0.0), base + Vector3(5.6, 1.0, 0.0), 0.16, &"steel")
	kit.box(Vector3(0.6, 0.6, 0.6), base + Vector3(-2.8, 0.6, 0.0), &"rust_dark", Vector3.ZERO, false)


## Row of crates along a short line.
func _crate_row(kit: MeshKit, pos: Vector3, yaw: float, count := 3, mat: StringName = &"ivory_warm") -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	var span := 1.35 * float(count)
	for i in count:
		var off := -span * 0.5 + 0.675 + float(i) * 1.35
		var p := pos + b * Vector3(off, 0.0, 0.0)
		kit.box(Vector3(1.2, 1.1, 1.2), p + Vector3(0.0, 0.55, 0.0), mat, rot, true)
		kit.box(Vector3(1.24, 0.12, 1.24), p + Vector3(0.0, 0.32, 0.0), &"rust_dark", rot, false)
		kit.box(Vector3(1.24, 0.12, 1.24), p + Vector3(0.0, 0.86, 0.0), &"rust_dark", rot, false)
		if i % 2 == 1:
			kit.box(Vector3(0.8, 0.7, 0.8), p + Vector3(0.0, 1.45, 0.0), &"rust" if mat == &"ivory_warm" else &"ivory_warm", rot, false)


## Bench with back rest.
func _bench(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(1.8, 0.1, 0.5), pos + Vector3(0.0, 0.48, 0.0), &"ivory_warm", rot, true)
	kit.box(Vector3(1.8, 0.5, 0.08), pos + b * Vector3(0.0, 0.76, -0.24), &"rust_dark", rot, false)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.1, 0.45, 0.44), pos + b * Vector3(float(side) * 0.72, 0.24, 0.0), &"steel", rot, false)


## Planter with alien growth.
func _planter(kit: MeshKit, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.cylinder(0.8, 1.0, 0.7, 8, pos + Vector3(0.0, 0.35, 0.0), &"concrete", rot)
	kit.torus(0.82, 0.96, pos + Vector3(0.0, 0.7, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.cylinder(0.12, 0.22, 0.9, 5, pos + Vector3(0.0, 1.1, 0.0), &"alien_dark", Vector3(0.1, yaw, -0.08), false)
	kit.sphere(0.44, pos + Vector3(0.0, 1.7, 0.0), &"alien", Vector3.ZERO, false, 8, 4)
	kit.sphere(0.13, pos + Vector3(0.0, 2.1, 0.0), &"glow_teal", Vector3.ZERO, false, 6, 3)


## Draped tarp over salvage with pegs and a crate.
func _tarp(kit: MeshKit, pos: Vector3, yaw: float, width := 2.4, depth := 2.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	kit.box(Vector3(0.8, 0.5, 0.8), pos + Vector3(0.0, 0.4, 0.0), &"rust", rot, true)
	kit.box(Vector3(width, 0.1, depth), pos + Vector3(0.0, 1.0, 0.0), &"fabric", Vector3(-0.08, yaw, 0.05), false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.cylinder(0.04, 0.05, 0.9, 4, pos + b * Vector3(float(sx) * width * 0.4, 0.45, float(sz) * depth * 0.4), &"steel", rot, false)


## Alternating hazard markings painted on the ground.
func _hazard_stripes(kit: MeshKit, pos: Vector3, yaw: float, length := 4.5, width := 0.7) -> void:
	var b := Basis(Vector3.UP, yaw)
	var rot := b.get_euler()
	var count := maxi(2, int(length / 0.85))
	var step := length / float(count)
	for i in count:
		var off := -length * 0.5 + (float(i) + 0.5) * step
		var mat: StringName = &"glow_amber" if i % 2 == 0 else &"dark"
		kit.box(Vector3(step * 0.92, 0.04, width), pos + b * Vector3(off, 0.02, 0.0), mat, rot, false)


## Low cable bundle with stakes and a junction box.
func _cable_run(kit: MeshKit, a: Vector3, b: Vector3) -> void:
	_beam(kit, a + Vector3(0.0, 0.08, 0.0), b + Vector3(0.0, 0.08, 0.0), 0.1, &"dark")
	_beam(kit, a + Vector3(0.0, 0.16, 0.0), b + Vector3(0.0, 0.16, 0.0), 0.055, &"steel")
	for s in 3:
		var p := a.lerp(b, (float(s) + 0.5) / 3.0)
		kit.cylinder(0.05, 0.06, 0.4, 4, p + Vector3(0.0, 0.2, 0.0), &"rust_dark", Vector3.ZERO, false)
	kit.box(Vector3(0.7, 0.5, 0.5), a + Vector3(0.0, 0.25, 0.0), &"rust_dark", Vector3.ZERO, false)


func _add_light(root: Node3D, pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	root.add_child(light)


func _rotation_from_up(dir: Vector3) -> Vector3:
	# CylinderMesh is Y-up; derive euler angles for a direction vector.
	var up := Vector3.UP
	var axis := up.cross(dir)
	var angle := up.angle_to(dir)
	if axis.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 0.0)
	return Basis(axis.normalized(), angle).get_euler()


