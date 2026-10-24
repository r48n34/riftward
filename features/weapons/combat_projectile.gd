class_name CombatProjectile
extends Node3D
## Lightweight manually integrated projectile/grenade. No Area3D per bullet;
## collision is a physics-space ray each tick and damage uses the shared pipeline.

var speed: float = 45.0
var direction: Vector3 = Vector3.FORWARD
var gravity: float = 0.0
var radius: float = 0.18
var damage: float = 90.0
var team: StringName = StatKeys.TEAM_PLAYER
var source: Node = null
var world_root: Node3D = null
var explosion_radius: float = 4.5
var lifetime: float = 5.0
var fuse: float = -1.0
var color: Color = Color("ffb866")
var damage_type: StringName = StatKeys.DMG_KINETIC
var velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _exploded: bool = false
var _mesh: MeshInstance3D
var _pending_origin: Vector3 = Vector3.ZERO
var _has_pending_origin: bool = false


func setup(
	origin: Vector3,
	dir: Vector3,
	p_speed: float,
	p_damage: float,
	p_team: StringName,
	p_source: Node,
	p_radius: float = 0.18,
	p_explosion_radius: float = 4.5,
	p_color: Color = Color("ffb866"),
	p_gravity: float = 0.0,
	p_fuse: float = -1.0
) -> void:
	if is_inside_tree():
		global_position = origin
	else:
		# Callers configure the projectile before adding it to the tree.
		_pending_origin = origin
		_has_pending_origin = true
	direction = dir.normalized()
	speed = p_speed
	velocity = direction * speed
	damage = p_damage
	team = p_team
	source = p_source
	radius = p_radius
	explosion_radius = p_explosion_radius
	color = p_color
	gravity = p_gravity
	fuse = p_fuse
	world_root = get_parent() as Node3D


func _ready() -> void:
	if _has_pending_origin:
		global_position = _pending_origin
		_has_pending_origin = false
	if world_root == null and get_parent() is Node3D:
		world_root = get_parent() as Node3D
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 2.5
	add_child(light)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if lifetime > 0.0 and fuse < 0.0 and _age >= lifetime:
		_explode()
		return
	velocity += Vector3.DOWN * gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatUtils.HIT_MASK, [])
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.collider
		var health := CombatUtils.find_health(collider)
		if health != null and health.team != team:
			if explosion_radius > 0.5:
				_explode()
			else:
				var data := DamageData.make(damage, team, damage_type, source)
				data.hit_position = hit.position
				data.hit_normal = hit.normal
				CombatUtils.apply_hit(collider, data, int(hit.get("shape", -1)))
				_explode()
			return
		if fuse >= 0.0 and gravity > 0.0:
			# Grenade bounce.
			var normal: Vector3 = hit.normal
			global_position = hit.position + normal * 0.05
			velocity = velocity.bounce(normal) * 0.45
			gravity = gravity
		else:
			global_position = hit.position
			_explode()
			return
	global_position = to
	if fuse >= 0.0 and _age >= fuse:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	if damage > 0.0:
		CombatUtils.aoe_damage(global_position, explosion_radius, damage, team, self, damage_type, get_world_3d())
	CombatVFX.explosion(world_root if is_instance_valid(world_root) else get_parent(), global_position, explosion_radius, color)
	AudioDirector.play_3d(&"explosion", global_position, -2.0)
	queue_free()

