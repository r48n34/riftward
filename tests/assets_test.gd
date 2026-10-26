extends SceneTree
## Acceptance test for the committed CC0 asset packs and the ParticleLibrary /
## CombatVFX particle wiring. Runs without project autoloads:
##   Godot --headless --path . --script res://tests/assets_test.gd
##
## Verifies, for every pack manifest under res://assets/cc0/:
##   * MANIFEST.json parses and carries the required provenance fields,
##   * the CC0 LICENSE.txt exists and actually says CC0,
##   * every listed file exists, has the recorded byte size and a matching sha256,
##   * the curated payload stays under the documented size cap,
##   * the Particle Pack's logical_names cover every logical effect id.
## Then verifies ParticleLibrary returns valid, materialised GPUParticles3D
## nodes for every logical id, that unknown ids and missing texture paths fall
## back procedurally (without deleting committed files), and that CombatVFX
## keeps working headless with and without the particle hooks.
##
## Prints "RESULT: PASS" or "RESULT: FAIL - <reason>" and quits 0/1.

const MANIFEST_ROOT := "res://assets/cc0"
const PARTICLE_PACK_ID := "kenney_particle_pack"
const SIZE_CAP_BYTES := 18 * 1024 * 1024
const MAX_FILE_BYTES := 2 * 1024 * 1024  # no bloated music loops in the repo
const ALLOWED_ROOTS: Array[String] = [
	"res://assets/textures/",
	"res://assets/audio/cc0/",
	"res://assets/music/",
]

const PACK_IDS: Array[String] = [
	"kenney_particle_pack",
	"kenney_prototype_textures",
	"kenney_interface_sounds",
	"kenney_ui_audio",
	"kenney_scifi_sounds",
	"kenney_impact_sounds",
	"kenney_music_jingles",
]

const REQUIRED_EFFECT_IDS: Array[StringName] = [
	&"muzzle",
	&"impact_metal",
	&"impact_dirt",
	&"explosion",
	&"dust",
	&"exhaust",
	&"sparks",
	&"splash",
	&"smoke",
	&"rain",
	&"portal",
]

const PARTICLE_DIR := "res://assets/textures/particles/"
const MISSING_TEXTURE_PROBE := "res://assets/textures/particles/__missing_pack_probe__.png"

var _checks := 0
var _failures: Array[String] = []
var _total_bytes := 0
var _finished := false
# Every node the suite instantiates is tracked here and freed in _teardown() so
# the run exits with a clean ObjectDB/RID report. run_all.ps1 treats any ERROR:
# line (including exit-time leak reports) as a suite failure.
var _owned_nodes: Array[Node] = []
var _combat_script: GDScript = null

const WATCHDOG_SECONDS := 120.0


func _initialize() -> void:
	# The SceneTree root is not inside the tree yet during _initialize() and some
	# CombatVFX paths need an in-tree Node3D (global transforms, tweens, timers),
	# so wait for the first frame before running the suite. A watchdog guarantees
	# the suite can never hang the test gate.
	create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	_run_suite()


func _run_suite() -> void:
	await process_frame
	_test_manifests()
	_test_particle_library()
	_test_combat_vfx()
	await _teardown()
	_finish()


## Frees every node this suite owns, drops the static particle caches and lets
## one frame pass so deferred frees/timers/tweens settle before quit().
func _teardown() -> void:
	# Unparented GPUParticles3D nodes (and their ProcessMaterial/QuadMesh/curves)
	# are plain objects: free() immediately instead of waiting for a frame.
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	# Static caches keep textures/materials alive until process exit otherwise.
	ParticleLibrary.clear_cache()
	# Drop CombatVFX's cached library script reference too (static holder).
	if _combat_script != null:
		_combat_script.call("shutdown")
		_combat_script = null
	await process_frame


## Registers a node for teardown, both parented and unparented.
func _own(node: Node) -> Node:
	if node != null:
		_owned_nodes.append(node)
	return node


func _make_particles(effect_id: StringName, count := 24) -> GPUParticles3D:
	var node := ParticleLibrary.make(effect_id, count)
	_own(node)
	return node


func _on_watchdog() -> void:
	if _finished:
		return
	print("[ASSETS] RESULT: FAIL - timed out after %.0fs" % WATCHDOG_SECONDS)
	quit(1)


# --- Manifests -------------------------------------------------------------

func _test_manifests() -> void:
	var dir := DirAccess.open(MANIFEST_ROOT)
	_check(dir != null, "manifest root %s exists" % MANIFEST_ROOT)
	if dir == null:
		return

	var found_dirs: Array[String] = []
	for sub in dir.get_directories():
		found_dirs.append(sub)

	var seen_paths: Dictionary = {}
	for pack_id in PACK_IDS:
		_check(found_dirs.has(pack_id), "pack directory exists: %s" % pack_id)
		var manifest_path := "%s/%s/MANIFEST.json" % [MANIFEST_ROOT, pack_id]
		_check(FileAccess.file_exists(manifest_path), "manifest exists: %s" % manifest_path)
		if not FileAccess.file_exists(manifest_path):
			continue
		_test_manifest_file(pack_id, manifest_path, seen_paths)

	# Every directory on disk must be one of the known packs (no strays).
	for sub in found_dirs:
		_check(PACK_IDS.has(sub), "unexpected pack directory: %s" % sub)

	_check(_total_bytes > 0, "curated payload is non-empty")
	_check(
		_total_bytes <= SIZE_CAP_BYTES,
		"curated payload %d bytes <= cap %d bytes" % [_total_bytes, SIZE_CAP_BYTES]
	)
	print("[ASSETS] curated payload: %d files, %.2f MB" % [seen_paths.size(), float(_total_bytes) / 1048576.0])


func _test_manifest_file(pack_id: String, manifest_path: String, seen_paths: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(manifest_path)
	var parsed: Variant = JSON.parse_string(text)
	_check(typeof(parsed) == TYPE_DICTIONARY, "manifest parses as JSON object: %s" % pack_id)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var manifest: Dictionary = parsed

	_check(int(manifest.get("schema", 0)) >= 1, "%s: schema present" % pack_id)
	_check(String(manifest.get("pack_id", "")) == pack_id, "%s: pack_id matches folder" % pack_id)
	_check(String(manifest.get("title", "")) != "", "%s: title present" % pack_id)
	_check(String(manifest.get("author", "")) != "", "%s: author present" % pack_id)
	_check(String(manifest.get("license", "")) == "CC0-1.0", "%s: license is CC0-1.0" % pack_id)
	var source_url := String(manifest.get("source_url", ""))
	_check(source_url.begins_with("https://"), "%s: source_url is https" % pack_id)
	var source_kind := String(manifest.get("source_kind", ""))
	_check(source_kind in ["github-archive", "kenney.nl"], "%s: known source_kind (%s)" % [pack_id, source_kind])
	if source_kind == "github-archive":
		_check(String(manifest.get("commit", "")).length() == 40, "%s: 40-char commit recorded" % pack_id)
	if source_kind == "kenney.nl":
		_check(String(manifest.get("archive_sha256", "")).length() == 64, "%s: kenney.nl archive sha256 recorded" % pack_id)

	# Asset Library provenance, including the three entries whose Library download
	# URL is dead and had to be sourced from kenney.nl instead.
	var asset_library: Variant = manifest.get("asset_library", null)
	_check(typeof(asset_library) == TYPE_DICTIONARY, "%s: asset_library metadata present" % pack_id)
	if typeof(asset_library) == TYPE_DICTIONARY:
		var library: Dictionary = asset_library
		_check(int(library.get("id", 0)) > 0, "%s: asset_library id recorded" % pack_id)
		_check(String(library.get("version", "")) != "", "%s: asset_library version recorded" % pack_id)
		var listed_status := String(library.get("listed_download_status", ""))
		_check(
			listed_status in ["ok", "dead"],
			"%s: asset_library download status is ok/dead (%s)" % [pack_id, listed_status]
		)
		var listed_url := String(library.get("listed_download_url", ""))
		_check(listed_url.begins_with("https://"), "%s: asset_library listed download URL recorded" % pack_id)
		_check(
			String(library.get("fetched_download_url", "")) == source_url,
			"%s: fetched URL matches source_url" % pack_id
		)
		if source_kind == "kenney.nl":
			_check(listed_status == "dead", "%s: dead Asset Library link flagged as dead" % pack_id)
			_check(listed_url != source_url, "%s: dead link replaced by kenney.nl source" % pack_id)
			_check(source_url.contains("kenney.nl"), "%s: kenney.nl is the actual source" % pack_id)
		else:
			_check(listed_status == "ok", "%s: live Asset Library link flagged as ok" % pack_id)

	# License must be committed beside the pack and beside the curated files.
	var license_file := String(manifest.get("license_file", ""))
	_check(license_file.begins_with("res://assets/cc0/"), "%s: license_file under assets/cc0" % pack_id)
	_check(_license_file_ok(license_file), "%s: canonical LICENSE.txt is CC0 text" % pack_id)
	var license_copies: Array = manifest.get("license_copies", [])
	_check(license_copies.size() > 0, "%s: license copy recorded" % pack_id)
	for copy in license_copies:
		_check(_license_file_ok(String(copy)), "%s: license copy is CC0 text: %s" % [pack_id, copy])

	# File list integrity.
	var files: Array = manifest.get("files", [])
	_check(files.size() > 0, "%s: manifest lists files" % pack_id)
	_check(
		int(manifest.get("file_count", -1)) == files.size(),
		"%s: file_count matches file list (%d)" % [pack_id, files.size()]
	)
	var manifest_total := int(manifest.get("total_bytes", -1))
	var computed_total := 0
	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			_check(false, "%s: file entry is an object" % pack_id)
			continue
		var path := String(entry.get("path", ""))
		var recorded_bytes := int(entry.get("bytes", -1))
		var recorded_sha := String(entry.get("sha256", "")).to_lower()
		_check(path.begins_with("res://"), "%s: file path is res:// (%s)" % [pack_id, path])
		var allowed := false
		for root in ALLOWED_ROOTS:
			if path.begins_with(root):
				allowed = true
				break
		_check(allowed, "%s: file lives in a curated root: %s" % [pack_id, path])
		_check(not seen_paths.has(path), "%s: file listed once: %s" % [pack_id, path])
		seen_paths[path] = true
		_check(
			recorded_bytes > 0 and recorded_bytes <= MAX_FILE_BYTES,
			"%s: sane file size (%d <= %d): %s" % [pack_id, recorded_bytes, MAX_FILE_BYTES, path]
		)
		if not FileAccess.file_exists(path):
			_check(false, "%s: file exists: %s" % [pack_id, path])
			continue
		var disk_bytes := _file_size(path)
		_check(disk_bytes == recorded_bytes, "%s: byte size matches (%d): %s" % [pack_id, disk_bytes, path])
		var disk_sha := _sha256_file(path)
		_check(
			disk_sha == recorded_sha,
			"%s: sha256 matches (disk %s, manifest %s): %s" % [pack_id, disk_sha, recorded_sha, path]
		)
		computed_total += disk_bytes
	_total_bytes += computed_total
	_check(
		manifest_total == computed_total,
		"%s: total_bytes matches sum of files (%d)" % [pack_id, computed_total]
	)

	# The particle pack's logical names must cover the effect catalog.
	if pack_id == PARTICLE_PACK_ID:
		var logical: Variant = manifest.get("logical_names", null)
		_check(typeof(logical) == TYPE_DICTIONARY, "particle pack: logical_names present")
		if typeof(logical) == TYPE_DICTIONARY:
			var logical_map: Dictionary = logical
			for effect_id in REQUIRED_EFFECT_IDS:
				var key := String(effect_id)
				_check(logical_map.has(key), "particle pack: logical_names covers '%s'" % key)
				if logical_map.has(key):
					var res_path := String(logical_map[key])
					_check(FileAccess.file_exists(res_path), "particle pack: logical '%s' file exists" % key)
					_check(
						res_path.begins_with(PARTICLE_DIR),
						"particle pack: logical '%s' lives in %s" % [key, PARTICLE_DIR]
					)


func _license_file_ok(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path).to_lower()
	return text.length() > 64 and (text.contains("cc0") or text.contains("creative commons"))


# --- ParticleLibrary -------------------------------------------------------

func _test_particle_library() -> void:
	var ids := ParticleLibrary.get_effect_ids()
	_check(ids.size() >= REQUIRED_EFFECT_IDS.size(), "ParticleLibrary exposes %d effect ids" % ids.size())
	var unique: Dictionary = {}
	for effect_id in ids:
		_check(not unique.has(effect_id), "effect id is unique: %s" % effect_id)
		unique[effect_id] = true
	for required in REQUIRED_EFFECT_IDS:
		_check(ids.has(required), "effect id present: %s" % required)

	for effect_id in REQUIRED_EFFECT_IDS:
		_check(ParticleLibrary.has(effect_id), "has('%s')" % effect_id)
		var texture := ParticleLibrary.get_texture(effect_id)
		_check(
			texture != null and texture.get_width() > 0 and texture.get_height() > 0,
			"get_texture('%s') has pixels" % effect_id
		)
		var path := ParticleLibrary.get_texture_path(effect_id)
		_check(path.begins_with(PARTICLE_DIR), "get_texture_path('%s') under particle dir" % effect_id)
		_check(FileAccess.file_exists(path), "curated PNG committed for '%s': %s" % [effect_id, path])

		var material := ParticleLibrary.get_material(effect_id)
		_check(material is StandardMaterial3D, "get_material('%s') is StandardMaterial3D" % effect_id)
		if material is StandardMaterial3D:
			var std := material as StandardMaterial3D
			_check(std.albedo_texture != null, "material('%s') has albedo texture" % effect_id)
			_check(
				std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
				"material('%s') is alpha blended" % effect_id
			)
			_check(
				std.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED,
				"material('%s') billboards" % effect_id
			)
			_check(
				std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"material('%s') is unshaded" % effect_id
			)

		var node := _make_particles(effect_id, 16)
		_test_particle_node(node, effect_id, 16)

	# Unknown id: has() is false, make()/get_material() still return valid objects.
	var unknown: StringName = &"__definitely_not_an_effect__"
	_check(not ParticleLibrary.has(unknown), "has() is false for unknown id")
	var fallback_node := _make_particles(unknown, 8)
	_test_particle_node(fallback_node, unknown, 8)
	_check(ParticleLibrary.get_material(unknown) != null, "get_material() fallback for unknown id")
	_check(ParticleLibrary.get_texture(unknown) != null, "get_texture() fallback for unknown id")

	# Simulated missing pack path (without deleting committed files).
	_check(
		ParticleLibrary.load_texture_or_null(MISSING_TEXTURE_PROBE) == null,
		"missing texture path returns null (no load attempt)"
	)
	var fallback_texture := ParticleLibrary.get_texture_or_fallback(MISSING_TEXTURE_PROBE, Color("ff8844"))
	_check(
		fallback_texture != null and fallback_texture.get_width() > 0,
		"missing texture path falls back to a procedural texture"
	)
	_check(
		ParticleLibrary.get_texture_or_fallback("res://assets/textures/particles/muzzle_01.png") != null,
		"get_texture_or_fallback() still resolves committed PNGs"
	)

	# Manifest <-> ParticleLibrary agreement.
	var manifest_text := FileAccess.get_file_as_string("%s/%s/MANIFEST.json" % [MANIFEST_ROOT, PARTICLE_PACK_ID])
	var manifest: Variant = JSON.parse_string(manifest_text)
	if typeof(manifest) == TYPE_DICTIONARY:
		var logical: Variant = (manifest as Dictionary).get("logical_names", {})
		if typeof(logical) == TYPE_DICTIONARY:
			for effect_id in REQUIRED_EFFECT_IDS:
				var key := String(effect_id)
				if (logical as Dictionary).has(key):
					_check(
						String((logical as Dictionary)[key]) == ParticleLibrary.get_texture_path(effect_id),
						"manifest logical_names matches ParticleLibrary path: %s" % key
					)

	# spawn() parenting / auto-start contract.
	var parent := Node3D.new()
	parent.name = "AssetTestParticleParent"
	root.add_child(parent)
	_own(parent)
	var spawned := ParticleLibrary.spawn(parent, &"sparks", Vector3(1.0, 2.0, 3.0), 8)
	_check(spawned != null, "spawn() returns a node")
	if spawned != null:
		_check(spawned.get_parent() == parent, "spawn() parents the particles")
		_check(spawned.emitting, "spawn() starts emitting")
		_check(spawned.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), "spawn() positions the particles")
	var streamed := ParticleLibrary.spawn(parent, &"exhaust", Vector3.ZERO, 4, false)
	_check(streamed != null and not streamed.one_shot, "spawn(one_shot=false) streams continuously")


func _test_particle_node(node: GPUParticles3D, effect_id: StringName, expected_count: int) -> void:
	_check(node != null, "make('%s') returns GPUParticles3D" % effect_id)
	if node == null:
		return
	_check(node is GPUParticles3D, "make('%s') node type" % effect_id)
	_check(node.amount == expected_count, "make('%s') respects count (%d)" % [effect_id, expected_count])
	_check(node.lifetime > 0.01, "make('%s') has a lifetime" % effect_id)
	_check(node.process_material is ParticleProcessMaterial, "make('%s') has a process material" % effect_id)
	_check(node.draw_pass_1 != null, "make('%s') has a draw pass mesh" % effect_id)
	if node.draw_pass_1 is QuadMesh:
		var quad := node.draw_pass_1 as QuadMesh
		_check(quad.size.x > 0.0 and quad.size.y > 0.0, "make('%s') quad has a size" % effect_id)
		_check(quad.material != null, "make('%s') quad has a material" % effect_id)
	else:
		_check(false, "make('%s') uses a QuadMesh" % effect_id)
	_check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "make('%s') does not cast shadows" % effect_id)
	_check(node.visibility_aabb.size.length() > 0.0, "make('%s') has a visibility AABB" % effect_id)


# --- CombatVFX wiring ------------------------------------------------------

func _test_combat_vfx() -> void:
	var script_path := "res://features/combat/combat_vfx.gd"
	_check(ResourceLoader.exists(script_path), "combat_vfx.gd exists")
	var combat_script: GDScript = null
	if ResourceLoader.exists(script_path):
		combat_script = load(script_path) as GDScript
	_check(combat_script != null, "combat_vfx.gd loads")
	if combat_script == null:
		return
	_combat_script = combat_script
	for method in ["muzzle_flash", "impact", "explosion", "spawn_tracer", "ring", "beam_burst"]:
		_check(combat_script.has_method(method) or _static_method_exists(combat_script, method), "CombatVFX exposes %s()" % method)

	var parent := Node3D.new()
	parent.name = "AssetTestCombatParent"
	root.add_child(parent)
	_own(parent)
	# Legacy signatures keep working (no surface argument).
	combat_script.call("muzzle_flash", parent, Vector3(0.0, 1.0, 0.0), Color("ffd89a"))
	combat_script.call("impact", parent, Vector3(0.0, 0.0, 0.0), Vector3.UP, Color("ffcf8a"))
	combat_script.call("explosion", parent, Vector3(0.0, 0.5, 2.0), 2.5, Color("ffb060"))
	# Surface-aware impact (new optional argument) must not break either.
	combat_script.call("impact", parent, Vector3(1.0, 0.0, 0.0), Vector3.UP, Color("ffcf8a"), &"metal")
	combat_script.call("impact", parent, Vector3(2.0, 0.0, 0.0), Vector3.UP, Color("b98a5e"), &"dirt")
	_check(parent.get_child_count() > 0, "CombatVFX created feedback nodes headless")
	_check(combat_script.call("has_particle_library"), "CombatVFX resolves the committed particle library")
	_check(
		_count_gpu_particles(parent) > 0,
		"CombatVFX spawns CC0 particles when the pack is present"
	)

	# Graceful degradation: with the library "absent" the primitive visuals must
	# still be created and no particle node may be added.
	combat_script.call("simulate_missing_particle_library")
	_check(not combat_script.call("has_particle_library"), "missing-library simulation disables particles")
	var packless := Node3D.new()
	packless.name = "AssetTestCombatParentNoPack"
	root.add_child(packless)
	_own(packless)
	combat_script.call("muzzle_flash", packless, Vector3(0.0, 1.0, 0.0), Color("ffd89a"))
	combat_script.call("impact", packless, Vector3(0.0, 0.0, 0.0), Vector3.UP, Color("ffcf8a"), &"metal")
	combat_script.call("explosion", packless, Vector3(0.0, 0.5, 2.0), 2.5, Color("ffb060"))
	_check(packless.get_child_count() > 0, "CombatVFX stays alive without ParticleLibrary (primitives only)")
	_check(
		_count_gpu_particles(packless) == 0,
		"CombatVFX adds no particle nodes when ParticleLibrary is absent"
	)
	combat_script.call("restore_particle_library")
	_check(combat_script.call("has_particle_library"), "particle library restored after simulation")
	var reattached := Node3D.new()
	reattached.name = "AssetTestCombatParentRestored"
	root.add_child(reattached)
	_own(reattached)
	combat_script.call("muzzle_flash", reattached, Vector3(0.0, 1.0, 0.0), Color("ffd89a"))
	_check(
		_count_gpu_particles(reattached) > 0,
		"particle layer re-attaches after restore"
	)

	# Defensive contract: null parent must be a silent no-op, never a crash.
	combat_script.call("muzzle_flash", null, Vector3.ZERO, Color.WHITE)
	combat_script.call("impact", null, Vector3.ZERO, Vector3.UP, Color.WHITE)
	combat_script.call("explosion", null, Vector3.ZERO, 1.0, Color.WHITE)


func _count_gpu_particles(node: Node) -> int:
	var count := 0
	if node is GPUParticles3D:
		count += 1
	for child in node.get_children():
		count += _count_gpu_particles(child)
	return count


func _static_method_exists(script: GDScript, method: String) -> bool:
	for info in script.get_script_method_list():
		if String(info.get("name", "")) == method:
			return true
	return false


# --- Helpers / reporting ---------------------------------------------------

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var length := file.get_length()
	var offset := 0
	while offset < length:
		var chunk := file.get_buffer(mini(65536, length - offset))
		if chunk.is_empty():
			break
		ctx.update(chunk)
		offset += chunk.size()
	file.close()
	return ctx.finish().hex_encode().to_lower()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[ASSETS] PASS: ", label)
	else:
		_failures.append(label)
		print("[ASSETS] FAIL: ", label)


func _finish() -> void:
	_finished = true
	print("[ASSETS] checks=%d failures=%d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("[ASSETS] RESULT: PASS")
		quit(0)
	else:
		for failure in _failures:
			print("[ASSETS] Failure: ", failure)
		print("[ASSETS] RESULT: FAIL - %d check(s) failed: %s" % [_failures.size(), _failures[0]])
		quit(1)
