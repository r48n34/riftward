class_name CombatUtils
extends RefCounted
## Shared hit resolution helpers for bullets, explosions and abilities.

const HIT_MASK := 1 | 4 | 8 | 128  # World, Enemy, Friendly, Deployable


static func find_health(collider: Object) -> HealthComponent:
	if collider == null:
		return null
	if collider.has_meta("health_component"):
		var direct = collider.get_meta("health_component")
		if direct is HealthComponent and is_instance_valid(direct):
			return direct
	var node: Node = collider as Node
	while node != null:
		if node is HealthComponent:
			return node
		for child in node.get_children():
			if child is HealthComponent:
				return child
		node = node.get_parent()
	return null


static func get_hit_weakpoint_mult(collider: Object, shape_index: int) -> float:
	if collider is CollisionObject3D and shape_index >= 0:
		var owner_id := (collider as CollisionObject3D).shape_find_owner(shape_index)
		var shape_node = (collider as CollisionObject3D).shape_owner_get_owner(owner_id)
		if shape_node != null and shape_node.has_meta("weakpoint_mult"):
			return float(shape_node.get_meta("weakpoint_mult"))
	return 1.0


static func apply_hit(
	collider: Object,
	data: DamageData,
	shape_index: int = -1
) -> Dictionary:
	var health := find_health(collider)
	if health == null or health.dead or health.team == data.team:
		return {"applied": false, "killed": false}
	data.weakpoint_mult = get_hit_weakpoint_mult(collider, shape_index)
	var was_dead := health.dead
	health.take_damage(data)
	return {
		"applied": true,
		"killed": not was_dead and health.dead,
		"weakpoint": data.weakpoint_mult > 1.0,
		"health": health,
	}


## Shared close-combat strike for the knife slot and the quick-melee action.
## Returns {applied, killed, weakpoint, hit_position} for hitmarkers/audio.
static func melee_strike(
	attacker: Node,
	camera: Camera3D,
	damage: float,
	reach: float,
	damage_type: StringName = StatKeys.DMG_KINETIC,
	accent: Color = Color("ffb866")
) -> Dictionary:
	var out := {"applied": false, "killed": false, "weakpoint": false, "hit_position": Vector3.ZERO}
	if attacker == null or camera == null or not is_instance_valid(attacker) or not is_instance_valid(camera):
		return out
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var exclude: Array[RID] = []
	if attacker is CollisionObject3D:
		exclude.append((attacker as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * maxf(0.5, reach), HIT_MASK, exclude)
	query.collide_with_areas = false
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return out
	var effect_parent: Node3D = null
	if attacker.has_method("get_effect_parent"):
		var candidate = attacker.call("get_effect_parent")
		if candidate is Node3D:
			effect_parent = candidate
	if effect_parent == null and attacker is Node3D:
		effect_parent = (attacker as Node3D).get_parent() as Node3D
	if effect_parent != null:
		CombatVFX.impact(effect_parent, hit.position, hit.normal, accent)
	var data := DamageData.make(damage, StatKeys.TEAM_PLAYER, damage_type, attacker)
	data.hit_position = hit.position
	data.hit_normal = hit.normal
	data.is_melee = true
	var applied := apply_hit(hit.collider, data, int(hit.get("shape", -1)))
	out["applied"] = bool(applied.get("applied", false))
	out["killed"] = bool(applied.get("killed", false))
	out["weakpoint"] = bool(applied.get("weakpoint", false))
	out["hit_position"] = hit.position
	return out


static func aoe_damage(
	origin: Vector3,
	radius: float,
	damage: float,
	team: StringName,
	source: Node,
	damage_type: StringName = StatKeys.DMG_KINETIC,
	world: World3D = null
) -> int:
	if world == null:
		if source is Node3D:
			world = (source as Node3D).get_world_3d()
		if world == null:
			return 0
	var space := world.direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = HIT_MASK
	var results := space.intersect_shape(params, 32)
	var already: Dictionary = {}
	var count := 0
	for result in results:
		var collider = result.collider
		if collider == null or already.has(collider.get_instance_id()):
			continue
		already[collider.get_instance_id()] = true
		var health := find_health(collider)
		if health == null or health.team == team:
			continue
		var target_pos := origin
		var health_parent := health.get_parent()
		if health_parent is Node3D:
			target_pos = (health_parent as Node3D).global_position
		var falloff := clampf(1.0 - origin.distance_to(target_pos) / maxf(radius, 0.1), 0.25, 1.0)
		var data := DamageData.make(damage * falloff, team, damage_type, source)
		data.hit_position = target_pos
		health.take_damage(data)
		count += 1
	return count
