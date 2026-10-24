class_name StatsComponent
extends Node
## Reactive stat container. Base stats + typed/identified modifiers, recalculated
## only when modifiers change. UI must listen to stats_changed instead of polling.

signal stats_changed(stats: Dictionary)

var _base: Dictionary = {}
var _modifiers: Array[Dictionary] = []
var _final: Dictionary = {}
var _dirty: bool = true


func set_base_stats(stats: Dictionary) -> void:
	_base = stats.duplicate(true)
	_dirty = true
	_ensure_final()
	stats_changed.emit(get_all_stats())


func get_base() -> Dictionary:
	return _base.duplicate(true)


func add_modifier(modifier: Dictionary) -> void:
	var entry := {
		"id": StringName(modifier.get("id", "mod")),
		"source": StringName(modifier.get("source", "unknown")),
		"stat": StringName(modifier.get("stat", "")),
		"op": StringName(modifier.get("op", "add")),
		"value": float(modifier.get("value", 0.0)),
	}
	if entry.stat == &"":
		return
	_modifiers.append(entry)
	_dirty = true
	_ensure_final()
	stats_changed.emit(get_all_stats())


func remove_modifiers_from(source: StringName) -> void:
	var before := _modifiers.size()
	_modifiers = _modifiers.filter(func(m: Dictionary) -> bool: return m.source != source)
	if _modifiers.size() != before:
		_dirty = true
		_ensure_final()
		stats_changed.emit(get_all_stats())


func clear_modifiers() -> void:
	_modifiers.clear()
	_dirty = true
	_ensure_final()
	stats_changed.emit(get_all_stats())


func get_stat(key: StringName, fallback: float = 0.0) -> float:
	_ensure_final()
	return float(_final.get(key, _base.get(key, fallback)))


func get_all_stats() -> Dictionary:
	_ensure_final()
	return _final.duplicate(true)


func _ensure_final() -> void:
	if not _dirty:
		return
	_final = _base.duplicate(true)
	var adds: Dictionary = {}
	var muls: Dictionary = {}
	for m in _modifiers:
		if m.op == &"override":
			_final[m.stat] = m.value
		elif m.op == &"mult":
			muls[m.stat] = float(muls.get(m.stat, 1.0)) * float(m.value)
		else:
			adds[m.stat] = float(adds.get(m.stat, 0.0)) + float(m.value)
	for key in _final.keys():
		var base_value := float(_final[key])
		if adds.has(key):
			base_value += float(adds[key])
		if muls.has(key):
			base_value *= float(muls[key])
		_final[key] = base_value
	for key in adds.keys():
		if not _final.has(key):
			_final[key] = float(adds[key])
	_dirty = false
