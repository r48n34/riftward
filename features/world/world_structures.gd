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
			"exfil_pad":
				_build_exfil_pad(root, kit, rng)
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
	# Command hab facing the pad center.
	kit.box(Vector3(10.0, 3.2, 7.0), Vector3(0.0, 1.75, -15.0), &"ivory")
	kit.box(Vector3(10.6, 0.35, 7.6), Vector3(0.0, 3.55, -15.0), &"rust")
	kit.box(Vector3(2.0, 2.2, 0.3), Vector3(0.0, 1.2, -11.4), &"dark")
	kit.box(Vector3(1.3, 0.16, 0.1), Vector3(0.0, 2.6, -11.2), &"glow_teal", Vector3.ZERO, false)
	_antenna(kit, Vector3(3.2, 3.7, -15.0), 11.0)
	# Rooftop shade + rail.
	kit.box(Vector3(6.0, 0.2, 4.0), Vector3(-2.2, 5.6, -15.0), &"ivory_warm")
	kit.cylinder(0.12, 0.12, 2.0, 8, Vector3(-5.0, 4.7, -17.0), &"steel", Vector3.ZERO, false)
	kit.cylinder(0.12, 0.12, 2.0, 8, Vector3(-5.0, 4.7, -13.0), &"steel", Vector3.ZERO, false)
	# Tents around the pad.
	for t in 3:
		var ang := TAU * float(t) / 3.0 + 0.6
		var tp := Vector3(cos(ang) * 15.0, 0.0, sin(ang) * 15.0)
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
	# Broken hull, three sections at rough angles.
	kit.box(Vector3(16.0, 4.2, 5.4), Vector3(-1.0, 2.3, 0.0), &"ivory", Vector3(0.0, 0.18, 0.06))
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
	# Massive blast door recessed into the facade.
	kit.box(Vector3(9.0, 7.0, 0.8), Vector3(0.0, 3.6, 5.4), &"steel")
	kit.box(Vector3(10.0, 0.6, 1.2), Vector3(0.0, 7.3, 5.5), &"ivory")
	kit.box(Vector3(10.0, 0.6, 1.2), Vector3(0.0, 0.3, 5.5), &"rust_dark")
	kit.box(Vector3(0.18, 5.0, 0.2), Vector3(0.0, 3.6, 5.85), &"glow_teal", Vector3.ZERO, false)
	kit.box(Vector3(7.4, 0.25, 0.25), Vector3(0.0, 5.2, 5.85), &"glow_amber", Vector3.ZERO, false)
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
	# Command hall and cages.
	kit.box(Vector3(14.0, 4.2, 9.0), Vector3(0.0, 2.4, -7.5), &"rust")
	kit.box(Vector3(14.6, 0.5, 9.6), Vector3(0.0, 4.7, -7.5), &"rust_dark")
	kit.box(Vector3(2.2, 2.6, 0.4), Vector3(0.0, 1.6, -2.9), &"dark")
	kit.box(Vector3(1.6, 0.2, 0.1), Vector3(0.0, 3.4, -2.7), &"glow_ember", Vector3.ZERO, false)
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
	_add_light(root, Vector3(0.0, 5.0, 0.0), Color(0.45, 1.0, 0.82), 2.2, 24.0)
	_add_light(root, Vector3(0.0, 9.0, 0.0), Color(0.70, 0.45, 1.0), 1.3, 16.0)


# =============================================================================
# POI: choir listening post
# =============================================================================
func _build_choir_post(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 18.0, &"concrete")
	# Bunker and dish mast.
	kit.box(Vector3(12.0, 3.4, 8.0), Vector3(0.0, 1.9, -4.0), &"ivory")
	kit.box(Vector3(12.6, 0.4, 8.4), Vector3(0.0, 3.8, -4.0), &"steel")
	kit.box(Vector3(2.8, 2.4, 0.3), Vector3(0.0, 1.5, 0.2), &"dark")
	kit.box(Vector3(2.0, 0.2, 0.1), Vector3(0.0, 3.1, 0.4), &"glow_teal", Vector3.ZERO, false)
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
	_add_light(root, Vector3(0.0, 14.0, -4.0), Color(0.35, 0.95, 1.0), 2.0, 30.0)
	_add_light(root, Vector3(8.0, 2.0, 2.0), Color(0.45, 1.0, 0.85), 0.8, 8.0)


# =============================================================================
# POI: colony ruins
# =============================================================================
func _build_colony_ruins(root: Node3D, kit: MeshKit, rng: RandomNumberGenerator) -> void:
	_pad(kit, 20.0, &"concrete")
	# Broken hab blocks arranged around a street.
	kit.box(Vector3(12.0, 5.0, 9.0), Vector3(-11.0, 2.5, -4.0), &"ivory")
	kit.box(Vector3(12.6, 0.4, 9.4), Vector3(-11.0, 5.2, -4.0), &"rust_dark")
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
	_add_light(root, Vector3(-11.0, 4.0, -4.0), Color(1.0, 0.68, 0.35), 0.9, 12.0)
	_add_light(root, Vector3(11.0, 6.0, 5.0), Color(1.0, 0.55, 0.24), 0.8, 10.0)


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


