class_name EnemyHealthBar
extends Node3D
## Billboard health / shield bar rendered above an enemy's head. Built from two
## unshaded quads (plus a shield strip), so a whole warband stays cheap.

const WIDTH := 1.12
const HEIGHT := 0.11
const SHIELD_HEIGHT := 0.04

var max_health := 100.0
var max_shield := 0.0
var health_fraction := 1.0
var shield_fraction := 0.0
var elite := false
var visibility_range := 55.0

var _backdrop: MeshInstance3D = null
var _fill: MeshInstance3D = null
var _shield: MeshInstance3D = null
var _fill_mat: StandardMaterial3D = null
var _shield_mat: StandardMaterial3D = null
var _back_mat: StandardMaterial3D = null



func _ready() -> void:
	visible = false
	set_process(false)


func setup(p_max_health: float, p_max_shield: float, p_elite: bool = false) -> void:
	max_health = maxf(1.0, p_max_health)
	max_shield = maxf(0.0, p_max_shield)
	elite = p_elite
	health_fraction = 1.0
	shield_fraction = 1.0 if max_shield > 0.0 else 0.0
	_build_quads()
	_apply_visuals()


func _build_quads() -> void:
	if _backdrop != null:
		return
	_back_mat = _make_material(Color(0.02, 0.03, 0.04, 0.78))
	_backdrop = _quad(Vector2(WIDTH + 0.06, HEIGHT + 0.1), _back_mat)
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	_fill_mat = _make_material(Color("62e6c3"))
	_fill = _quad(Vector2(WIDTH, HEIGHT), _fill_mat)
	_fill.name = "HealthFill"
	add_child(_fill)
	if max_shield > 0.0:
		_shield_mat = _make_material(Color("6fa8ff"))
		_shield = _quad(Vector2(WIDTH, SHIELD_HEIGHT), _shield_mat)
		_shield.name = "ShieldFill"
		_shield.position.y = HEIGHT * 0.5 + SHIELD_HEIGHT * 0.5 + 0.015
		add_child(_shield)
	# Elite / boss trim.
	if elite:
		var trim := _quad(Vector2(WIDTH + 0.1, 0.018), _make_material(Color("ffb866")))
		trim.name = "EliteTrim"
		trim.position.y = HEIGHT * 0.5 + 0.055
		add_child(trim)


func _quad(size: Vector2, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.disable_receive_shadows = true
	material.render_priority = 2
	return material


func set_values(p_health: float, p_max_health: float, p_shield: float, p_max_shield: float) -> void:
	max_health = maxf(1.0, p_max_health)
	max_shield = maxf(0.0, p_max_shield)
	health_fraction = clampf(p_health / max_health, 0.0, 1.0)
	shield_fraction = clampf(p_shield / maxf(1.0, max_shield), 0.0, 1.0) if max_shield > 0.0 else 0.0
	_apply_visuals()


func _apply_visuals() -> void:
	if _fill == null:
		return
	var fraction := clampf(health_fraction, 0.0, 1.0)
	_fill.scale.x = maxf(0.02, fraction)
	_fill.position.x = -WIDTH * 0.5 + WIDTH * fraction * 0.5
	if _fill_mat != null:
		var health_color := Color("62e6c3")
		if fraction <= 0.2:
			health_color = Color("ff6e6e")
		elif fraction <= 0.5:
			health_color = Color("ffb866")
		_fill_mat.albedo_color = health_color
	if _shield != null:
		var shield_visible := max_shield > 0.0 and shield_fraction > 0.001
		_shield.visible = shield_visible and health_fraction > 0.0
		_shield.scale.x = maxf(0.02, shield_fraction)
		_shield.position.x = -WIDTH * 0.5 + WIDTH * shield_fraction * 0.5


func set_visibility_for_distance(distance: float, forced: bool = false) -> void:
	if health_fraction <= 0.0:
		visible = false
		return
	visible = forced or distance <= visibility_range


func get_health_fraction() -> float:
	return health_fraction


func get_shield_fraction() -> float:
	return shield_fraction
