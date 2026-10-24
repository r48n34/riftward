class_name UIStubPlayer
extends Node3D
## Stand-in Player used by the UI test/screenshot harness. Implements the same
## signal + snapshot contract as the real Player so the HUD can be verified
## without running a deployment.

signal hud_updated(snapshot: Dictionary)
signal hitmarker(killed: bool, crit: bool)
signal damage_indicator(world_direction: Vector3)
signal downed_changed(is_downed: bool, bleedout: float)
signal died

var health := 84.0
var max_health := 120.0
var shield := 34.0
var max_shield := 62.0
var ammo := 22
var reserve := 168
var reloading := false
var reload_progress := 0.0
var kills := 3
var downed := false
var elapsed := 0.0
var ads_amount := 0.0
var ads_zoom := 0.82
var weapon_range := 120.0
var _emit_accum := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	_emit_accum += delta
	if _emit_accum >= 0.1:
		_emit_accum = 0.0
		hud_updated.emit(get_hud_snapshot())


func get_hud_snapshot() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"shield": shield,
		"max_shield": max_shield,
		"armor": 26.0,
		"weapon_name": "Lattice AR",
		"weapon_slot": "primary",
		"weapon_slot_label": "PRIMARY 1",
		"weapon_slot_index": 0,
		"weapon_style": "rifle",
		"weapon_accent": Color("62e6c3"),
		"weapon_slots": [
			{"name": "Lattice AR", "slot_label": "PRIMARY 1", "slot_index": 0, "active": true, "is_melee": false, "rarity_color": Color("63e6c3")},
			{"name": "Longview DMR", "slot_label": "PRIMARY 2", "slot_index": 1, "active": false, "is_melee": false, "rarity_color": Color("6fa8ff")},
			{"name": "Sidewinder", "slot_label": "SIDEARM", "slot_index": 2, "active": false, "is_melee": false, "rarity_color": Color("a7b4b6")},
			{"name": "Combat Knife", "slot_label": "KNIFE", "slot_index": 3, "active": false, "is_melee": true, "rarity_color": Color("63e6c3")},
		],
		"is_melee": false,
		"inventory_key": "I",
		"rarity_color": Color("63e6c3"),
		"ammo": ammo,
		"reserve": reserve,
		"mag_size": 30,
		"reloading": reloading,
		"reload_progress": reload_progress,
		"ads_amount": ads_amount,
		"ads_zoom": ads_zoom,
		"weapon_range": weapon_range,
		"abilities": [
			{"name": "Blink Step", "icon": &"arrow", "cooldown": 0.0, "cooldown_total": 8.0, "ready": true, "charges": 1, "is_ultimate": false},
			{"name": "Aegis Wall", "icon": &"shield", "cooldown": 4.2, "cooldown_total": 22.0, "ready": false, "charges": 1, "is_ultimate": false},
			{"name": "Iron Tide", "icon": &"tide", "cooldown": 0.0, "cooldown_total": 120.0, "ready": true, "charges": 1, "is_ultimate": true},
		],
		"grenade_name": "Frag",
		"grenade_charges": 2,
		"kills": kills,
		"downed": downed,
		"revive_progress": 0.0,
		"position": global_position,
		"yaw": global_rotation.y,
		"squad": [
			{"name": "Mara Voss", "role": "medic", "health": 88.0, "max_health": 100.0, "downed": false},
			{"name": "Irie Sol", "role": "scout", "health": 74.0, "max_health": 90.0, "downed": false},
			{"name": "Mote", "role": "driftling", "health": 30.0, "max_health": 30.0, "downed": false},
		],
	}


func simulate_damage() -> void:
	shield = maxf(0.0, shield - 18.0)
	health = maxf(1.0, health - 9.0)
	damage_indicator.emit(Vector3(1.0, 0.0, 0.4))
	hud_updated.emit(get_hud_snapshot())


func simulate_hit() -> void:
	hitmarker.emit(true, true)


func simulate_aim(zoom: float, amount: float = 1.0) -> void:
	ads_zoom = zoom
	ads_amount = amount
	hud_updated.emit(get_hud_snapshot())


func simulate_down() -> void:
	downed = true
	downed_changed.emit(true, 42.0)
	hud_updated.emit(get_hud_snapshot())


func simulate_death() -> void:
	died.emit()
