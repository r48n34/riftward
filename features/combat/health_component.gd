class_name HealthComponent
extends Node
## Owns health, shields, armor mitigation and death. Never write these fields
## from UI or unrelated systems — use take_damage(), heal() and signals.

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal damaged(info: Dictionary)
signal status_applied(status_type: StringName, power: float, duration: float)
signal died

@export var max_health: float = 100.0
@export var max_shield: float = 0.0
@export var armor: float = 0.0
@export var team: StringName = StatKeys.TEAM_ENEMY
@export var shield_regen_delay: float = 4.0
@export var shield_regen_rate: float = 12.0

var health: float = 100.0
var shield: float = 0.0
var dead: bool = false
var invulnerable: bool = false

var _since_damage: float = 99.0
var _invuln_until_msec: int = 0


func _ready() -> void:
	set_process(false)
	if health <= 0.0 and not dead:
		health = max_health
	shield = max_shield
	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)


func configure(p_max_health: float, p_max_shield: float, p_armor: float, p_team: StringName) -> void:
	max_health = maxf(1.0, p_max_health)
	max_shield = maxf(0.0, p_max_shield)
	armor = maxf(0.0, p_armor)
	team = p_team
	reset_full()


func reset_full() -> void:
	dead = false
	health = max_health
	shield = max_shield
	_since_damage = 99.0
	_invuln_until_msec = 0
	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)
	set_process(shield < max_shield)


func set_max_health(value: float, refill: bool = false) -> void:
	var ratio := health / maxf(max_health, 0.001)
	max_health = maxf(1.0, value)
	health = max_health if refill else clampf(max_health * ratio, 1.0, max_health)
	health_changed.emit(health, max_health)


func set_max_shield(value: float, refill: bool = false) -> void:
	var ratio := shield / maxf(max_shield, 0.001) if max_shield > 0.0 else 1.0
	max_shield = maxf(0.0, value)
	shield = max_shield if refill else clampf(max_shield * ratio, 0.0, max_shield)
	shield_changed.emit(shield, max_shield)
	set_process(shield < max_shield)


func set_armor(value: float) -> void:
	armor = maxf(0.0, value)


func set_invulnerable(duration: float) -> void:
	_invuln_until_msec = maxi(_invuln_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))


func take_damage(data: DamageData) -> float:
	if dead or data == null:
		return 0.0
	if invulnerable or Time.get_ticks_msec() < _invuln_until_msec:
		return 0.0
	if data.team == team:
		return 0.0
	var raw := maxf(0.0, data.amount)
	if raw <= 0.0:
		return 0.0
	raw *= maxf(0.15, data.weakpoint_mult)
	raw *= 100.0 / (100.0 + maxf(0.0, armor))
	var remaining := raw
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
		if shield <= 0.0:
			_since_damage = 0.0
	if remaining > 0.0:
		health = maxf(0.0, health - remaining)
		health_changed.emit(health, max_health)
	_since_damage = 0.0
	if max_shield > 0.0 and shield < max_shield:
		set_process(true)
	if data.status_type != StatKeys.STATUS_NONE and data.status_power > 0.0:
		status_applied.emit(data.status_type, data.status_power, data.status_duration)
	damaged.emit({
		"amount": raw,
		"health": health,
		"shield": shield,
		"crit": data.crit,
		"weakpoint": data.weakpoint_mult > 1.0,
		"damage_type": data.damage_type,
		"source": data.source,
		"hit_position": data.hit_position,
		"hit_normal": data.hit_normal,
	})
	if health <= 0.0 and not dead:
		dead = true
		set_process(false)
		died.emit()
	return raw


func heal(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var healed := minf(amount, max_health - health)
	health += healed
	if healed > 0.0:
		health_changed.emit(health, max_health)
	return healed


func revive(health_amount: float = -1.0) -> void:
	if not dead:
		return
	dead = false
	health = clampf(health_amount if health_amount >= 0.0 else max_health * 0.35, 1.0, max_health)
	shield = max_shield * 0.3
	set_process(shield < max_shield)
	_since_damage = 0.0
	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)


func restore_shield(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var restored := minf(amount, max_shield - shield)
	shield += restored
	if restored > 0.0:
		shield_changed.emit(shield, max_shield)
	return restored


func kill() -> void:
	if dead:
		return
	health = 0.0
	dead = true
	health_changed.emit(health, max_health)
	set_process(false)
	died.emit()


func get_health_fraction() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if dead or max_shield <= 0.0:
		set_process(false)
		return
	_since_damage += delta
	if _since_damage >= shield_regen_delay and shield < max_shield:
		shield = minf(max_shield, shield + shield_regen_rate * delta)
		shield_changed.emit(shield, max_shield)
