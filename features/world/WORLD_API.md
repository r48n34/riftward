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

var pois: Array = world.get_pois()     # 24 x {position, type, name, radius, pad_radius} (+ preset extras)
var roadside: Array = world.get_roadside_points()  # 10-14 outbuildings (more with a preset)
var exfils: Array = world.get_exfil_points()  # 3 x {position, name}
var loot_props: Array = world.get_loot_props()  # ~2 clutter anchors per POI for LootCache
var clutter: int = world.get_clutter_piece_count()  # ~480 POI-local MultiMesh pieces at density 1.0
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
| `func sample_fluid(world_xz: Vector2) -> Dictionary` | `{type: 0 none / 1 water / 2 lava, level, depth, center, radius}` |
| `func get_fluid_basins() -> Array[Dictionary]` | seeded basin descriptors |
| `func get_fluid_root() -> Node3D` | water/lava surface meshes |
| `func get_biome_names() -> Array[String]` | planet-remapped biome names |
| `func get_environment_director() -> Node` | single writer for sky/sun/fog |
| `func get_day_night_cycle() -> Node` | clock, keyframes, sun direction |
| `func get_weather_system() -> Node` | seeded weather state machine |
| `func get_interior_pois() -> Array[Dictionary]` | POIs with enterable interiors (15 on the base 24-POI layout, 16 on the world-test preset) |
| `func get_spawn_points() -> Array[Vector3]` | 2 flat drop zones near map center |
| `func get_exfil_points() -> Array[Dictionary]` | 3 entries `{position: Vector3, name: String}` |
| `func get_pois() -> Array[Dictionary]` | 24 base POIs (21 authored layout + 3 exfil) + 0–4 preset extras `{position, type, name, radius, pad_radius, interior, dungeon_anchor}` |
| `func get_loot_props() -> Array[Dictionary]` | POI clutter anchors for LootCache: `{position: Vector3, kind: StringName, poi_index: int, poi_type: StringName}` |
| `func get_clutter_piece_count() -> int` | total POI-local clutter MultiMesh instances (0 before generate) |
| `func get_path_weight_at(world_xz: Vector2) -> float` | road/path weight (0 away from roads, higher on them) |
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

Without a preset there are **24 base POIs**: 3 exfil pads plus **21 authored layout
entries** built from **20 authored POI types** (13 original kits + 7 second-wave kits).
Each has a procedural modular structure and a flattened combat pad:

| type | count | notes |
| --- | --- | --- |
| `exfil_pad` | 3 | landing pads — these ARE `get_exfil_points()` |
| `warden_outpost` | 1 | landmark monolith, courtyard cover, watchtower |
| `faction_camp` | 2 | hab, tents, watchtower, containers, barriers; the command hab is enterable |
| `relay_spire` | 2 | 46m lattice + glowing signal rings |
| `crash_site` | 1 | broken hull sections, debris, ember glow; the central hull is enterable |
| `vault` | 1 | bunker facade, open blast door and a 3-bay enterable interior |
| `anomaly` | 1 | hovering shards, monolith ring |
| `ruin_field` | 1 | arches, broken columns, alien growth |
| `ashen_stockade` | 1 | palisade gates, corner towers, cages, enterable command hall |
| `bloom_hive` | 1 | leaning organic spires, pods, membrane canopy |
| `choir_post` | 1 | dish, lattice mast, signal pylon ring, enterable bunker |
| `colony_ruins` | 1 | collapsed hab blocks, street slabs, broken tower, enterable hab |
| `derelict_ship` | 1 | landed freighter with ramp, cargo bay, corridor, cockpit and engine room |
| `foundry_hall` | 1 | two-storey smelter: catwalks, crucible, gantry crane; enterable |
| `hab_cluster` | 1 | three domed hab modules around a courtyard; all three enterable |
| `comms_array` | 1 | dish farm + equipment shed; enterable |
| `fuel_depot` | 1 | tank farm + pump gantry; enterable |
| `clinic_shelter` | 1 | field hospital with beds/med lockers; enterable |
| `research_lab` | 1 | glass-domed lab wing + live server racks; enterable |
| `water_works` | 1 | settling basins, elevated tanks, catwalks; enterable |

Map presets append up to 4 extra objectives **after** the 21 authored layout entries.
The extra kits cycle the 11 `EXTRA_POI_KINDS` (original camp/relay/ruin/freighter plus
the new foundry/hab/comms/fuel/clinic/lab/water kits), they prefer the preset's
`biome_index` biome, and they accept a tighter 195 m spacing plus relaxed ground
flatness. Extra placement is best-effort (a crowded map may place fewer than
`extra_pois`); all 21 authored POIs and the 3 exfil pads always land, so a run has at
least 24 POIs and at most 28.

Every POI root node is named `POI_<index>_<type>` and carries a
`world_info` meta dictionary `{name, type, position, radius, yaw}`; enterable POIs
also expose `InteriorSpawn_00..` markers and dungeon-capable POIs a
`DungeonAnchor` marker. `get_pois()` surfaces them as `interior` (spawn positions)
and `dungeon_anchor` (world position); `pad_radius` is the flattened combat pad
radius (mirrors `POISpecs.pad`). Drop zones are `DropZone_00/01`, and
roadside roots are `Roadside_00..nn` with `{name, type: "roadside", position,
radius, yaw}`. Objective/exfil marker gameplay can either consume the API
dictionaries or attach marker nodes to those roots. Exfil positions are the pad
centers (flat, collision-safe); beacon masts are visible from ~600m.

## POI clutter and loot props

`WorldScatter` adds a POI-local clutter pass: barrels, crates, pallets, cable spools
and debris in **5 MultiMesh batches**, 20 pieces per POI at `scatter_density` 1.0
(about **480 instances** on a 24-POI map; the world-test preset reports 598 across
26 POIs). Clutter is seeded per POI and uses `get_path_weight_at()` to stay out of
road lanes.

About two clutter pieces per POI are recorded as **loot-prop anchors** and exposed
through `get_loot_props()` (`{position: Vector3, kind: StringName, poi_index: int,
poi_type: StringName}`); the world-test preset yields **52 anchors**. Deployment puts
a `LootCache` on a capped subset of them (about 10 per run) and resolves the table
from `poi_type` through `POISpecs.loot_tier`, so rare POIs pay better.

## POISpecs

`features/world/poi_specs.gd` (`class_name POISpecs`) is a static, thread-safe
**20-row data table** — no scene tree, no nodes, no RNG state, safe to call from
worker threads and tests. Consumers (loot tables, `VehicleSites`, the Codex, the
tactical map) read it instead of hard-coding kit names.

| Member | Notes |
| --- | --- |
| `TYPE_IDS: Array[StringName]` | the 20 canonical POI type ids |
| `VEHICLES: Array[StringName]` | `""`, `rig`, `hoverbike`, `airplane`, `spaceship`, `horse` |
| `HAZARDS: Array[StringName]` | `none`, `hostile`, `ember`, `electrical`, `toxic`, `flood`, `radiation`, `vacuum`, `unstable` |
| `static func all() -> Array[Dictionary]` | every spec, deep-copied |
| `static func has_spec(type) -> bool` | type exists in the table |
| `static func get_spec(type) -> Dictionary` | spec for `type`, `{}` when unknown |
| `static func validate() -> Array[String]` | human-readable problems; empty = valid |

Each spec row carries `id`, `title`, `blurb`, `radius`, `pad`, `interior`, `loot_tier`
(0–4), `garrison`, `hazard`, `biomes`, `vehicle`, `map_bias` and `codex_icon`.
`validate()` cross-checks count/uniqueness, radius/pad sanity, loot-tier and garrison
ranges, hazard/vehicle vocabularies, biome indices and `TYPE_IDS` coverage; the world
suite asserts it is empty and that every `POI_LAYOUT`/`EXTRA_POI_KINDS` type has a
spec whose radius/pad mirror the layout.

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
| `extra_pois` | `int` | extra objectives appended after the 21 authored layout entries (max 4) |
| `extra_poi_names` | `Array[String]` | names for the extras, in order; missing entries get fallback names |
| `biome_index` | `int` | 0 / 1 / 2; extra POIs prefer this planet-remapped biome |
| `biome_rotation` | `float` | radians; rotates the three biome anchors around the origin (0.0 = authored geography) |
| `planet_id` | `StringName` | planet identity (biome names, palette, sky keyframes, weather pool, fluid config) |
| `start_time` | `float` | 0..1 time-of-day at deployment (0.25 sunrise, 0.5 noon, 0.75 sunset) |
| `fluid` | `Dictionary` | per-map overrides for the planet fluid config (`water_basins`, `lava_basins`, levels) |
| `planet` | `Dictionary` | embedded by `ContentDB.get_map_preset()`; consumed for tint/sky/biomes |
| `weather_defs` | `Array[Dictionary]` | embedded weather definitions for the planet's pool |
| `environment` | `Dictionary` | visual overrides, see below |
| `world_seed_salt` | `int` | **not consumed by the builder** — the caller mixes it into the `generate()` seed to vary the layout |

`environment` keys (all optional): `sky_top`, `sky_horizon`, `sky_ground`,
`sun_color`, `fill_color`, `fog_color` (`Color`), `sun_dir` (`Vector3`, direction
toward the sun), `sun_energy`, `fog_density`, `volumetric_fog_density`
(`float`). Missing values keep the default palette; the same dictionary is
accepted by `world_environment.gd::setup(parent, overrides, planet)`.

With an empty preset (never calling `apply_preset`, or `apply_preset({})`) the
builder reproduces the default frontier: 24 base POIs (21 authored + 3 exfil),
10–14 roadside buildings, `scatter_density` 1.0, no biome rotation, the default sky,
no fluid basins and no weather pool (the day/night cycle still runs with palette
defaults).

## Planets

`ContentDB.get_map_preset()` embeds the resolved planet dictionary, so the world
layer never calls an autoload. A planet carries:

| Planet field | Effect |
| --- | --- |
| `biome_names[3]` | names returned by `get_biome_names()` / `get_biome_at()` |
| `terrain_tint[3]`, `tint_strength` | per-biome terrain/scatter tint applied in the terrain worker and tactical map |
| `sky.night/dawn/day/dusk` | four colour/energy keyframes used by the day/night cycle; the map preset's `environment` overrides the day keyframe |
| `planet_sky` | ringed-body shader parameters (`planet_dir`, `planet_radius`, bands, ring colour) |
| `weather_pool` | ordered weather ids; the weather system starts seeded from this pool |
| `fluid` | water/lava enable flags, basin count ranges and level biases |
| `hazard` | HUD/codex hazard tag (`none`, `heat`, `deep_water`) |
| `day_length` | seconds per full day/night cycle |
| `dungeon_themes` | under-reach theme ids Deployment cycles through |

## Environment

`create_environment=true` adds:
- `WorldEnvironment` with a procedural sky shader (`assets/shaders/world/sky.gdshader`):
  warm late-afternoon gradient, sun disc/halo, ringed gas giant, faint stars.
- Warm key `Sun` (DirectionalLight3D, 4-split shadows, 420m shadow range) and a
  cool `SkyFill` rim light.
- Exponential dust fog + volumetric god-rays, ACES tone mapping, SSAO, bloom.
- `EnvironmentDirector` (`get_environment_director()`), the single writer for sky,
  sun, fill, fog and volumetric density. It merges planet keyframes, map-preset
  overrides and weather, and exposes `set_time_state()`, `set_weather_state()`,
  `set_indoor(bool)`, `flash()` and `get_state()`.
- `DayNightCycle` (`get_day_night_cycle()`): planet `day_length`, seeded
  `start_time`, four keyframes, moving sun, `get_clock_text()`, `is_night()`.
- `WeatherSystem` (`get_weather_system()`): seeded weighted state machine with
  transitions, particles, lightning, `get_state()`, `get_vision_multiplier()`
  and `get_move_multiplier()`. It is disabled when the preset has no weather defs.

Access via `get_environment_data()` if gameplay wants to tweak exposure/sun.
If the game scene adds its own `WorldEnvironment`, pass `create_environment=false`.

When a preset is applied, its `environment` dictionary is forwarded to
`world_environment.gd::setup(parent, overrides, planet)` (see "Map presets" above).
The overrides restyle the sky shader (`sky_top`, `sky_horizon`, `sky_ground`,
`sun_color`, `sun_dir`), the key/fill lights (`sun_energy`, `fill_color`) and the
atmosphere (`fog_color`, `fog_density`, `volumetric_fog_density`). Missing keys
keep the default palette, so the no-preset look is unchanged.

## Fluid basins

`_place_fluid_basins()` chooses 3–6 seeded basins on low, quiet ground away from
POIs, roads and drop zones, weighted by the planet's `fluid` config. The height
worker carves bowls and emits a shore/deep mask; `WorldFluid` builds one surface
mesh per basin (`assets/shaders/world/water.gdshader` or `lava.gdshader`) plus
lava glow lights. The tactical map tints water and lava.

```gdscript
var basins: Array = world.get_fluid_basins()
var sample: Dictionary = world.sample_fluid(Vector2(x, z))
# sample.type: 0 none, 1 water, 2 lava; level/depth are in metres
```

Gameplay queries are analytic (no physics volumes). `Player` uses the query for
buoyancy, swim drag, lava damage and HUD hazard state; `EnemyAgent` uses it for
water drag and lava damage; scatter skips fluid cells and dresses the shoreline.

## Interiors

**15 POIs** are hollow on the base 24-POI layout (14 interior types, with faction_camp appearing twice):
the faction-camp command habs, Vault bunker, crash hull, colony hab, Choir bunker, Ashen command hall, the
derelict freighter, and the seven second-wave kits (Foundry Hall, Habitation Cluster's three modules, Comms
Array, Fuel Depot, Field Clinic, Research Lab and Water Works). The world-test preset reports **16** because
its extra POI is a faction camp, and four preset extras can reach **17**. Doorways are 4.2 m wide and ceilings are
3.4 m+ so the 1.3 m-radius navmesh agent can path inside. Interiors carry
`InteriorSpawn_00..` markers (loot/garrison anchors) and dungeon-capable POIs a
`DungeonAnchor`; both are surfaced through `get_pois()`/`get_interior_pois()`.
The derelict ship is a full freighter kit with a boarding ramp, cargo bay,
corridor, cockpit and engine room.

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

## Performance (measured, seed 12345, Verdant Verge preset)

- Headless generation: **1,365 ms** total (phase A 134 ms, phase B 393 ms, terrain
  64 chunks on threads, structures/scatter/clutter/env + roadside, **nav bake 245 ms**).
- Windowed (renderer active): ~2–4 s wall (frame-based waits + shader compile).
- 64 terrain chunks / 204,800 triangles, **656 nodes**, **17 scatter MultiMesh
  batches (6,449 instances) + 5 POI-clutter batches (598 instances)**,
  one merged collision body for scatter, 3,252 navmesh polygons.
- Avoid per-frame noise sampling: all fields are baked at generation time;
  `sample_height` is a bilinear lookup.

## Threading

- Phase A (landforms/biome/detail noise) and phase B (pads, road grading,
  tactical map image) run in a `Thread` with plain Packed data only.
- Terrain chunk vertex data is generated by N `Thread`s (one batch per thread),
  then ArrayMesh/collision nodes are created on the main thread.
- No SceneTree/RenderingServer calls happen off the main thread. `POISpecs` is
  static pure data, so worker/loot code can read it without touching the tree.

## Self-test / preview

```bash
# Headless contract test (20 POI types, >=24 base POIs, 16 interiors, POI clutter,
# loot-prop anchors, POISpecs validation, fluids, nav, terrain, determinism replay)
godot --headless --path D:\godotGa\game res://features/world/world_test.tscn

# Interactive preview (free camera: WASD/QE, Shift, F12 screenshot)
godot --path D:\godotGa\game res://features/world/world_preview.tscn

# Framed screenshots -> features/world/preview_shots/
godot --path D:\godotGa\game res://features/world/world_preview.tscn -- --capture
```

The preview generates the world standalone and works without autoloads/UI.
