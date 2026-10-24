# RIFTWARD — World Feature API

`features/world/` owns the runtime procedural frontier: terrain, biomes, POIs,
roads, scatter, sky/environment, and navigation. Nothing here depends on
autoloads, UI, the player, or ContentDB — the world can be generated in
isolation (see `world_preview.tscn` / `world_test.tscn`).

## Quick start

```gdscript
const WorldBuilderScript := preload("res://features/world/world_builder.gd")

var world := WorldBuilderScript.new()
world.name = "World"
add_child(world)                       # must be in the tree before generate()
world.generation_progress.connect(func(v: float, label: String): ...)
world.generation_finished.connect(func(ok: bool): ...)

world.apply_preset(preset)             # optional; plain Dictionary, e.g. ContentDB.get_map_preset(&"ashen_shelf")
await world.generate(12345)            # async coroutine, deterministic per seed

var spawn := world.get_spawn_points()[0]
# spawn player at spawn (it is exactly on the flattened drop pad, y = ground)

var pois: Array = world.get_pois()     # 16 x {position, type, name, radius} (+ preset extras)
var roadside: Array = world.get_roadside_points()  # 10-14 outbuildings (more with a preset)
var exfils: Array = world.get_exfil_points()  # 3 x {position, name}
var nav: NavigationRegion3D = world.get_nav_region()
var map: Texture2D = world.get_map_texture()
var ground_y := world.sample_height(Vector2(x, z))
```

`generate()` is a coroutine (declared `-> void`): `await world.generate(seed)`
returns when the world is fully built, including the async navmesh bake.
A builder can be regenerated: calling `generate()` again clears the previous
world first.

## Public API (contract)

| Member | Notes |
| --- | --- |
| `signal generation_progress(value: float, label: String)` | 0..1 progress; safe for loading UI |
| `signal generation_finished(ok: bool)` | emitted once per generate() |
| `@export var map_size := 1800.0` | world is square, centered on origin |
| `func apply_preset(preset: Dictionary) -> void` | optional; call before `generate()`; `{}` = default frontier |
| `func get_map_preset_id() -> StringName` | applied preset id, or `&""` without a preset |
| `func generate(world_seed: int) -> void` | async; only main-thread node creation |
| `func sample_height(world_xz: Vector2) -> float` | bilinear height, valid after generate |
| `func get_spawn_points() -> Array[Vector3]` | 2 flat drop zones near map center |
| `func get_exfil_points() -> Array[Dictionary]` | 3 entries `{position: Vector3, name: String}` |
| `func get_pois() -> Array[Dictionary]` | 16 base POIs + 0–4 preset extras `{position, type, name, radius}` |
| `func get_roadside_points() -> Array[Dictionary]` | 10–14 roadside outbuildings `{position, yaw, kind}` (presets raise the cap) |
| `func get_nav_region() -> NavigationRegion3D` | null only if `bake_navigation == false` |
| `func get_map_texture() -> Texture2D` | 256×256 tactical overlay, null before generate |
| `func get_world_seed() -> int` | seed passed to the last successful generate() |

### Extra helpers (safe to use)

- `signal navigation_ready(ok: bool)` — fired after `generation_finished`.
- `is_generating() / is_generated() / is_navigation_ready()`
- `get_biome_at(world_xz) -> String` (`"Verdant Basin"`, `"Ashen Canyons"`, `"Glass Flats"`)
- `get_biome_weights_at(world_xz) -> Vector3` (`x`=verdant, `y`=ashen, `z`=glass)
- `get_path_segments() -> Array` (road polylines, for minimaps/patrol routes)
- `get_terrain_root() / get_structures_root() / get_scatter_root() / get_environment_root()`
- `get_environment_data() -> Dictionary` (`environment`, `sun`, `fill`, `sky_material`)
- `get_generation_stats() -> Dictionary` (timings, nav poly count, scatter counts)
- `is_scatter_clear(pos, clearance) / is_landmark_clear(pos)` (spawn placement helpers)

### Exported knobs

- `map_size` (1800), `terrain_chunks` (8), `terrain_resolution` (320)
- `scatter_density` (1.0), `map_texture_resolution` (256)
- `create_environment` (true) — set **false** if the game owns its own `WorldEnvironment`
- `bake_navigation` (true)

`apply_preset()` writes `map_size` and `scatter_density` from the preset (1800 /
1.0 when absent), so apply the preset before tweaking those fields by hand.

## POIs

Without a preset there are 16 POIs (13 authored objectives + 3 exfil pads), each
with a procedural modular structure and a flattened combat pad:

| type | count | notes |
| --- | --- | --- |
| `warden_outpost` | 1 | 60m landmark monolith, courtyard cover |
| `faction_camp` | 2 | hab, tents, watchtower, containers, barriers |
| `relay_spire` | 2 | 46m lattice + glowing signal rings |
| `crash_site` | 1 | broken hull sections, debris, ember glow |
| `vault` | 1 | bunker facade + blast door |
| `anomaly` | 1 | hovering shards, monolith ring |
| `ruin_field` | 1 | arches, broken columns, alien growth |
| `ashen_stockade` | 1 | palisade gates, corner towers, cages, command hall |
| `bloom_hive` | 1 | leaning organic spires, pods, membrane canopy |
| `choir_post` | 1 | dish, lattice mast, signal pylon ring, bunker |
| `colony_ruins` | 1 | collapsed hab blocks, street slabs, broken tower |
| `exfil_pad` | 3 | landing pads — these ARE `get_exfil_points()` |

Map presets append up to 4 extra objectives after the authored 13. Their kits
cycle `faction_camp` → `relay_spire` → `ruin_field`, they prefer the preset's
`biome_index` biome, and they accept a tighter 195 m spacing plus relaxed ground
flatness. Extra placement is best-effort (a crowded map may place fewer than
`extra_pois`); all 13 authored POIs and the 3 exfil pads always land.

Every POI root node is named `POI_<index>_<type>` and carries a
`world_info` meta dictionary `{name, type, position, radius, yaw}`; drop zones
are `DropZone_00/01`, and roadside roots are `Roadside_00..nn` with
`{name, type: "roadside", position, radius, yaw}`. Objective/exfil marker
gameplay can either consume the API dictionaries or attach marker nodes to
those roots. Exfil positions are the pad centers (flat, collision-safe); beacon
masts are visible from ~600m.

Roadside outbuildings are placed along the road polylines, offset 9–15 m to
alternating sides, rejected near POIs/spawns, and finalized with collision +
`nav_source` like any POI. Three kits are selected round-robin: checkpoint,
relay box, ruined wall.

## Map presets

A map preset is a plain `Dictionary` (e.g. `ContentDB.get_map_preset(id)`).
`apply_preset()` deep-copies it and only reads it during `generate()`, so always
apply the preset before generating; applying another one afterwards only affects
the next generation. Unknown keys are ignored and every key is optional.

```gdscript
var preset: Dictionary = ContentDB.get_map_preset(RunState.get_map_preset_id())
world.apply_preset(preset)
await world.generate(seed + int(preset.get("world_seed_salt", 0)))
print(world.get_map_preset_id())       # &"ashen_shelf"; &"" without a preset
```

| Preset field | Type | Effect |
| --- | --- | --- |
| `id` | `StringName` | returned by `get_map_preset_id()` |
| `display_name`, `subtitle`, `icon`, `color` | — | metadata only, not consumed here |
| `map_size` | `float` | optional; defaults to 1800 |
| `scatter_density` | `float` | scatter multiplier (default 1.0) |
| `roadside_target` | `int` | max roadside outbuildings (default 14) |
| `extra_pois` | `int` | extra objectives appended after the authored 13 |
| `extra_poi_names` | `Array[String]` | names for the extras, in order; missing entries get fallback names |
| `biome_index` | `int` | 0 Verdant / 1 Ashen / 2 Glass; extra POIs prefer this biome |
| `biome_rotation` | `float` | radians; rotates the three biome anchors around the origin (0.0 = authored geography) |
| `environment` | `Dictionary` | visual overrides, see below |
| `world_seed_salt` | `int` | **not consumed by the builder** — the caller mixes it into the `generate()` seed to vary the layout |

`environment` keys (all optional): `sky_top`, `sky_horizon`, `sky_ground`,
`sun_color`, `fill_color`, `fog_color` (`Color`), `sun_dir` (`Vector3`, direction
toward the sun), `sun_energy`, `fog_density`, `volumetric_fog_density`
(`float`). Missing values keep the default palette; the same dictionary is
accepted by `world_environment.gd::setup(parent, overrides)`.

With an empty preset (never calling `apply_preset`, or `apply_preset({})`) the
builder reproduces the default frontier exactly: 16 POIs, 10–14 roadside
buildings, `scatter_density` 1.0, no biome rotation and the default sky.

## Environment

`create_environment=true` adds:
- `WorldEnvironment` with a procedural sky shader (`assets/shaders/world/sky.gdshader`):
  warm late-afternoon gradient, sun disc/halo, ringed gas giant, faint stars.
- Warm key `Sun` (DirectionalLight3D, 4-split shadows, 420m shadow range) and a
  cool `SkyFill` rim light.
- Exponential dust fog + volumetric god-rays, ACES tone mapping, SSAO, bloom.

Access via `get_environment_data()` if gameplay wants to tweak exposure/sun.
If the game scene adds its own `WorldEnvironment`, pass `create_environment=false`.

When a preset is applied, its `environment` dictionary is forwarded to
`world_environment.gd::setup(parent, overrides)` (see "Map presets" above). The
overrides restyle the sky shader (`sky_top`, `sky_horizon`, `sky_ground`,
`sun_color`, `sun_dir`), the key/fill lights (`sun_energy`, `fill_color`) and the
atmosphere (`fog_color`, `fog_density`, `volumetric_fog_density`). Missing keys
keep the default palette, so the no-preset look is unchanged.

## Navigation

- A `NavigationRegion3D` is added as a child of the builder and exposed via
  `get_nav_region()`.
- Baked asynchronously with `NavigationServer3D.parse_source_geometry_data()` +
  `bake_from_source_geometry_data_async()` from all static colliders in the
  `"nav_source"` group (8×8 terrain chunks, POI structures, boulders/spires).
- Navmesh settings: cell 2.0m, agent height 1.9m, radius 1.3m, max climb 0.9m,
  45° max slope → ~3–6k walkable polygons over the 1.8km frontier.
- The bake is part of `generate()`; `generation_finished(true)` means nav is
  ready. Use `is_navigation_ready()`/`navigation_ready` when baking is disabled
  or times out (fallbacks: sync parse + async bake, then blocking bake).
- The navmesh is static. If gameplay adds static geometry later, rebake with:
  `nav_region.bake_navigation_mesh(true)` (needs geometry in the `nav_source` group).

## Map texture

`get_map_texture()` is a 256×256 RGBA tactical overlay with biome colors,
hillshade, 20m contour lines, roads, and objective rings (teal = POI,
amber = exfil, ivory = spawn).

World → UV mapping (for UI markers): `uv = world_xz / map_size + Vector2(0.5, 0.5)`.
Pixel (0,0) is world `(-map_size/2, -map_size/2)`, and pixel y increases with
world +z. The HUD minimap therefore draws north (`-z`) up and uses the same
mapping for the crop, full map and edge-clamped markers.

## Performance (measured, seed 12345)

- Headless generation: ~1.25 s total (landforms 0.21s, pads/roads/map ~0.37s,
  terrain 64 chunks on threads, structures/scatter/env + roadside ~0.5s,
  nav bake ~0.19s).
- Windowed (renderer active): ~2–4 s wall (frame-based waits + shader compile).
- 64 terrain chunks / 204,800 triangles, ~380 nodes, ~10 scatter MultiMesh
  batches (~5k instances), one merged collision body for scatter.
- Avoid per-frame noise sampling: all fields are baked at generation time;
  `sample_height` is a bilinear lookup.

## Threading

- Phase A (landforms/biome/detail noise) and phase B (pads, road grading,
  tactical map image) run in a `Thread` with plain Packed data only.
- Terrain chunk vertex data is generated by N `Thread`s (one batch per thread),
  then ArrayMesh/collision nodes are created on the main thread.
- No SceneTree/RenderingServer calls happen off the main thread.

## Self-test / preview

```bash
# Headless contract test (asserts 16 POIs, roadside, 3 exfils, terrain/nav/map)
godot --headless --path D:\godotGa\game res://features/world/world_test.tscn

# Interactive preview (free camera: WASD/QE, Shift, F12 screenshot)
godot --path D:\godotGa\game res://features/world/world_preview.tscn

# Framed screenshots -> features/world/preview_shots/
godot --path D:\godotGa\game res://features/world/world_preview.tscn -- --capture
```

The preview generates the world standalone and works without autoloads/UI.
