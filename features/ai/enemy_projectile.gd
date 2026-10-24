class_name EnemyProjectile
extends Node3D
## Lightweight enemy bolt. CombatProjectile is tuned for player team and its
## ray mask excludes the Player layer, so enemy attacks use this small variant:
## world / player / friendly ray test, shared damage pipeline, no per-bullet Area3D.

const HIT_MASK := 1 | 2 | 8  # World, Player, Friendly
const MAX_LIFETIME := 4.5

var speed: float = 28.0
var direction: Vector3 = Vector3.FORWARD
var damage: float = 10.0
var team: StringName = StatKeys.TEAM_ENEMY
var damage_type: StringName = StatKeys.DMG_ENERGY
var source: Node = null
var color: Color = Color("ffb866")
var radius: float = 0.09
var life_left: float = MAX_LIFETIME
var _traveled: float = 0.0


static func spawn(
	parent: Node3D,
	origin: Vector3,
	dir: Vector3,
	p_speed: float,
	p_damage: float,
	p_source: Node,
	p_color: Color = Color("ffb866"),
	p_damage_type: StringName = StatKeys.DMG_ENERGY
) -> EnemyProjectile:
	if parent == null or not is_instance_valid(parent):
		return null
	var bolt := EnemyProjectile.new()
	bolt.name = "EnemyBolt"
	bolt.speed = maxf(6.0, p_speed)
	bolt.damage = p_damage
	bolt.source = p_source
	bolt.color = p_color
	bolt.damage_type = p_damage_type
	bolt.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	bolt.team = StatKeys.TEAM_ENEMY
	parent.add_child(bolt)
	bolt.global_position = origin
	if bolt.direction.length_squared() > 0.0001:
		bolt.look_at(origin + bolt.direction, Vector3.UP)
	return bolt


func _ready() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 0.52
	mesh.radial_segments = 6
	mesh.rings = 2
	body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = mat
	body.rotation.x = PI * 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	if damage >= 20.0:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.9
		light.omni_range = 2.2
		light.shadow_enabled = false
		add_child(light)


func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.collider
		var health := CombatUtils.find_health(collider)
		if health != null and is_instance_valid(health) and health.team != team:
			var data := DamageData.make(damage, team, damage_type, source)
			data.hit_position = hit.position
			data.hit_normal = hit.normal
			data.impulse = direction * 1.5
			CombatUtils.apply_hit(collider, data, int(hit.get("shape", -1)))
			_impact(hit.position, hit.normal)
			queue_free()
			return
		if health == null:
			_impact(hit.position, hit.normal)
			queue_free()
			return
		# Same-team body: pass through without consuming the bolt.
	global_position = to
	_traveled += speed * delta


func _impact(position: Vector3, normal: Vector3) -> void:
	var fx_parent := get_parent() as Node3D
	if fx_parent != null and is_instance_valid(fx_parent):
		CombatVFX.impact(fx_parent, position, normal, color)
