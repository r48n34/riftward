extends SceneTree
## Small asset acceptance test for the bundled icon catalog. It runs without the
## project autoloads (so it can use --script) and verifies every icon referenced
## by the new icon-first UI resolves to a non-empty imported texture. Run with:
##   Godot --headless --path . --script res://tests/ui_icons_test.gd

const REQUIRED_ICONS: Array[StringName] = [
	&"book", &"skull", &"cache", &"flag", &"layers", &"helmet", &"legs",
	&"timer", &"bolt", &"map", &"play", &"chevron-left", &"info", &"check",
	&"lock", &"star", &"trash", &"core", &"target", &"warning", &"users",
	&"coins", &"ammo", &"refresh", &"crosshair", &"heart-pulse", &"shield-check",
	&"arrow-up", &"exfil", &"grid", &"outpost", &"trophy", &"filter", &"paw",
	&"eye", &"backpack", &"arrow-right", &"arrow-up-right", &"chevron-down",
	&"gamepad", &"sound", &"display", &"accessibility", &"pause", &"exit",
	&"planet", &"dungeon", &"water", &"lava", &"training", &"moon",
	&"weather-sun", &"weather-rain", &"weather-storm", &"weather-fog", &"weather-ash",
	&"ember", &"wave", &"smoke", &"drone", &"mine", &"grapple",
	# --- UI/content expansion: extreme weather, faction and discipline sigils ---
	&"weather-snow", &"weather-ion", &"weather-void", &"weather-meteor", &"weather-toxic",
	&"faction-ashen", &"faction-bloom", &"faction-choir",
	&"discipline-vanguard", &"discipline-infiltrator", &"discipline-engineer", &"discipline-pathfinder",
]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var unique: Dictionary = {}
	for icon_name in REQUIRED_ICONS:
		_check(not unique.has(icon_name), "icon is listed once: %s" % icon_name)
		unique[icon_name] = true
		var texture := UIIcons.get_icon(icon_name)
		var resolved := texture != null and texture.get_width() > 0 and texture.get_height() > 0
		_check(resolved, "icon resolves with pixels: %s" % icon_name)
	print("[UI-ICONS] checks=%d failures=%d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("[UI-ICONS] RESULT: PASS")
		quit(0)
	else:
		for failure in _failures:
			print("[UI-ICONS] Failure: ", failure)
		print("[UI-ICONS] RESULT: FAIL")
		quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[UI-ICONS] PASS: ", label)
	else:
		_failures.append(label)
		print("[UI-ICONS] FAIL: ", label)
