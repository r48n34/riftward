extends Node
## Global, low-frequency lifecycle bus. Keep this under 15 signals: gameplay
## events belong to scene-scoped components, not to this bus.

signal deployment_started(seed: int, contract_id: StringName, threat: int, mutators: Array)
signal deployment_ended(result: Dictionary)
signal objective_updated(objective_id: StringName, title: String, progress: int, total: int)
signal timer_updated(seconds_left: float)
signal storm_changed(active: bool, safe_radius: float)
signal extraction_state_changed(state: StringName, seconds_left: float)
signal notification_requested(title: String, message: String, severity: StringName)
signal loading_progress(value: float, label: String)
signal radio_message(speaker: String, line: String)
signal player_spawned(player: Node)
signal player_downed(is_downed: bool)
signal game_paused(is_paused: bool)
signal settings_changed(key: String, value: Variant)
signal enemy_killed(enemy_name: String, position: Vector3, is_boss: bool)
signal world_event(title: String, description: String, icon: StringName, color: Color)
signal dungeon_state_changed(active: bool, dungeon_name: String)
signal hazard_state_changed(state: StringName)
signal tutorial_stage_changed(stage: Dictionary)
## Cinematic ownership. Emitted when a cut-scene starts and when it releases the
## view back to gameplay; every listener must be able to survive the end signal
## arriving without a matching start.
signal cinematic_state_changed(active: bool, cutscene_id: StringName)
## Rideables. Vehicles are scene-local, but HUD, audio and the tutorial watch
## the seat state through the bus instead of polling every frame.
signal vehicle_mounted(vehicle: Node, vehicle_id: StringName)
signal vehicle_dismounted(vehicle: Node, vehicle_id: StringName)


func notify(title: String, message: String, severity: StringName = &"info") -> void:
	notification_requested.emit(title, message, severity)


func radio(speaker: String, line: String) -> void:
	radio_message.emit(speaker, line)
