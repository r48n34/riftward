class_name ShockTurret
extends Node3D
## Temporary shock turret deployed by engineer Wardens. Pulses non-lethal shock
## damage into nearby enemies only (never the player or squad). Deliberately
## simple: one node, a few primitives, one bounded group scan per pulse.

const Visuals := preload("res://features/companions/companion_visuals.gd")

var team: StringName = StatKeys.TEAM_FRIENDLY
var damage: float = 10.0
var pulse_radius: float = 5.5
var lifetime: float = 12.0
var pulse_interval: float = 1.5
var source: Node = null

var _age: float = 0.0
var _pulse_timer: float = 0.2
var _built: bool = false
var _expiring: bool = false
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _core_mat: StandardMaterial3D


func setup(
	p_team: StringName,
	p_damage: float,
	p_lifetime: float = 12.0,
	p_radius: float = 5.5,
	p_source: Node = null
) -> void:
	team = p_team
	damage = p_damage
	lifetime = p_lifetime
	pulse_radius = p_radius
	source = p_source
	if is_inside_tree():
		_ensure_built()


func _ready() -> void:
	add_to_group("companion_deployable")
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_visual()


func _build_visual() -> void:
	var root := Node3D.new()
	root.name = "TurretVisual"
	add_child(root)

	var dark := Visuals.metal(Color("1b2427"), 0.4, 0.45)
	var shell := Visuals.metal(Color("2d3b40"), 0.5, 0.4)
	var violet := Visuals.emissive(Visuals.VIOLET, 2.6)

	# Tripod legs.
	for i in 3:
		var angle := TAU * float(i) / 3.0
		var leg := Visuals.add_box(
			root,
			Vector3(0.06, 0.6, 0.06),
			Vector3(cos(angle) * 0.26, 0.26, sin(angle) * 0.26),
			dark,
			Vector3(rad_to_deg(cos(angle)) * 16.0, rad_to_deg(angle), rad_to_deg(sin(angle)) * 16.0)
		)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	Visuals.add_cylinder(root, 0.16, 0.2, 0.16, Vector3(0.0, 0.52, 0.0), shell, Vector3.ZERO, 8)
	Visuals.add_cylinder(root, 0.05, 0.08, 0.3, Vector3(0.0, 0.72, 0.0), dark, Vector3.ZERO, 6)

	_core_mat = Visuals.emissive(Visuals.VIOLET, 2.6)
	_core = Visuals.add_sphere(root, 0.13, Vector3(0.0, 0.86, 0.0), _core_mat, Vector3.ONE, 10)
	_ring = Visuals.add_torus(root, 0.24, 0.29, Vector3(0.0, 0.86, 0.0), Visuals.emissive(Visuals.VIOLET, 1.6), Vector3(90.0, 0.0, 0.0))
	Visuals.add_box(root, Vector3(0.34, 0.05, 0.34), Vector3(0.0, 0.6, 0.0), violet)

	_light = OmniLight3D.new()
	_light.light_color = Visuals.VIOLET
	_light.light_energy = 1.4
	_light.omni_range = 4.0
	_light.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(_light)


func _physics_process(delta: float) -> void:
	if not _built:
		return
	_age += delta
	if _expiring:
		return
	if _ring != null:
		_ring.rotation.y += delta * 2.4
	if _age >= lifetime:
		_expire()
		return
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = pulse_interval
		_pulse()


func _pulse() -> void:
	if _core != null:
		var tw := create_tween()
		tw.tween_property(_core, "scale", Vector3.ONE * 1.6, 0.08)
		tw.tween_property(_core, "scale", Vector3.ONE, 0.18)
	if _light != null:
		_light.light_energy = 3.0
		var tl := create_tween()
		tl.tween_property(_light, "light_energy", 1.0, 0.35)

	var enemy_group := get_tree().get_nodes_in_group("enemy_ai")
	if enemy_group.is_empty():
		return
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var origin := global_position + Vector3.UP * 0.85
	var hit_any := false
	var pulse_pos := global_position
	for enemy in enemy_group:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		var enemy_node := enemy as Node3D
		var health := _enemy_health(enemy)
		if health == null or health.dead:
			continue
		if origin.distance_to(enemy_node.global_position) > pulse_radius:
			continue
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(origin, enemy_node.global_position + Vector3.UP * 1.0, 1)
			query.collide_with_areas = false
			if not space.intersect_ray(query).is_empty():
				continue
		var data := DamageData.make(damage, team, StatKeys.DMG_SHOCK, source)
		data.status_type = StatKeys.STATUS_SHOCK
		data.status_power = 0.8
		data.status_duration = 1.2
		data.hit_position = enemy_node.global_position
		data.hit_normal = Vector3.UP
		var applied := CombatUtils.apply_hit(enemy, data, -1)
		if bool(applied.get("applied", false)):
			hit_any = true
			CombatVFX.impact(_effects_parent(), enemy_node.global_position + Vector3.UP * 1.0, Vector3.UP, Visuals.VIOLET)
	if hit_any:
		CombatVFX.ring(_effects_parent(), pulse_pos, pulse_radius, Visuals.VIOLET, 0.45)
		AudioDirector.play_3d(&"shot_arc", pulse_pos, -13.0)


func _enemy_health(enemy: Node) -> HealthComponent:
	if enemy.has_method("get_health_component"):
		var hc = enemy.call("get_health_component")
		if hc is HealthComponent:
			return hc
	return CombatUtils.find_health(enemy)


func _effects_parent() -> Node3D:
	var parent := get_parent()
	if parent is Node3D:
		return parent as Node3D
	return self


func _expire() -> void:
	if _expiring:
		return
	_expiring = true
	if _light != null:
		_light.light_energy = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.35)
	if _core != null:
		tw.tween_property(_core, "scale", Vector3.ONE * 0.1, 0.35)
	tw.chain().tween_callback(queue_free)
