# RIFTWARD - Technical Architecture

## 1. Runtime target

- Engine: Godot 4.7.2 stable, Forward+ renderer, D3D12 on Windows.
- Physics: Jolt Physics, 60 physics ticks per second.
- Language: typed GDScript.
- Display: 1600x900 default window, resizable; canvas_items stretch with expand aspect.
- Dependencies: none beyond Godot. No addons, no network services.
- Entry scene: `res://scenes/boot.tscn` -> `App.boot()` -> UIRoot main menu.

## 2. High-level architecture

```
Boot
  -> App (autoload)
       -> UIRoot (CanvasLayer, ui/ui_root.gd)
            -> 13 screens + loading/pause/results overlays (includes Quick Deploy preflight)
            -> HUD (ui/hud/hud_root.gd) while deployed
       -> Deployment (Node3D, features/run/deployment.gd)
            -> WorldBuilder (features/world, planet/map presets)
                 -> EnvironmentDirector -> DayNightCycle + WeatherSystem
                 -> WorldFluid (water/lava surfaces)
            -> DungeonRuntime x2-3 (features/dungeon, remote world offsets)
            -> Player
                 -> StatsComponent / HealthComponent
                 -> WeaponController
                 -> AbilityManager
            -> CompanionManager -> 2 AllyAgents + PetAgent
            -> EnemyAgent population + loot drops
            -> ObjectiveSites / ExtractionBeacons / LootCaches / WorldMarkers
            -> TutorialDirector (tutorial mode only)
```

The project follows signals up, calls down. UI reads state through signals and explicit snapshots; gameplay never reaches into UI internals. Global events are restricted to EventBus; combat and cooldowns use scene-local signals.

## 3. Autoloads

| Autoload | Responsibility |
|---|---|
| EventBus | Low-frequency lifecycle signals: deployment start/end, objectives, timer, storm, exfil, notifications, loading progress, radio, player spawn/downed, pause, settings, enemy kills, world events |
| ContentDB | Validates and indexes authored Resources by StringName; O(1) lookup; rarity and discipline helpers |
| ProfileState | Persistent meta progression, save/load/migration, inventory, loadout, base, squad, pets, cosmetics, records |
| RunState | Per-deployment seed, RNG, timer, objectives, satchel, Rift Mods, kills, exfil state and result construction; no Node references |
| AudioDirector | Procedural sound bank, ambient music loop, buses, 2D/3D SFX pools, volume settings |
| App | Boot, settings, input map, scene/UI routing, deployment lifecycle, pause, debug capture hooks |

Autoload order: EventBus -> ContentDB -> ProfileState -> RunState -> AudioDirector -> App.

## 4. Content model

Content is authored in `features/content/content_library.gd` and materialized as typed Resources by ContentDB. The catalog is code-hosted to guarantee export inclusion and easy validation. ContentDB enforces counts:

- 16 weapons, 24 abilities (20 active + 4 ultimates), 24 passive perks with level requirements
- 37 enemy entries (20 base + 11 elites + 6 bosses)
- 4 allies, 3 pets, 8 base modules, 13 contracts (7 classic + 6 staged)
- 12 Rift Mods, 8 mutators, 3 grenades, 10 gear templates
- 6 suits, 8 dyes, 8 weapon skins, 3 pet shells, 8 affixes
- 4 named run difficulties (read-only dictionaries indexed by ContentDB), each linked to one of 12 map presets
- 5 planets, 12 map presets: a planet owns biome names/palette, day/night sky keyframes, weather pool,
  fluid configuration and dungeon themes; a map preset owns layout salt, POIs/roadside/scatter budgets,
  start time, environment overrides and an optional preset-level weather pool (it overrides the planet
  pool for that drop)
- 18 weather states and 3 dungeon themes, both plain read-only dictionaries
- 5 selectable game modes (normal/quick/blackout/gauntlet/onslaught) and 20 weighted world events,
  also plain read-only dictionaries; the mode drives clock, storm fraction, start time, density,
  elite odds, reward, hostile budget and bonus loot

Typed Resource types: WeaponData, AbilityData, PerkData, EnemyData, AllyData, PetData, ItemTemplate, BaseModuleData, ContractData, RiftModData, MutatorData, GrenadeData, CosmeticData. Difficulty presets, map presets, planets, weather, game modes and dungeon themes are plain read-only data to avoid global class-cache dependencies. Each difficulty carries map_preset, mission_sites, side_caches, bounties, objective_guards, max_hostiles, enemy_health_mult, enemy_damage_mult, loot_luck, storm_fraction, director_interval_scale and extraction_scale. Each map preset carries a seed salt, biome rotation, scatter/roadside/extra-POI budgets, environment overrides and an optional `weather_pool`. Each game mode carries run_duration, time_scale, start_time, storm_fraction, density_mult, elite_bonus, reward_mult, max_hostiles_delta, loot_bonus, tag, clock, icon, colour and description. Each world event carries id, title, text, icon, colour and weight. `ContentDB.get_map_preset()` enriches the authored preset with its planet, all weather definitions (so forced weather works on any map) and merged fluid configuration so `WorldBuilder` receives everything through `apply_preset()` without an autoload dependency. `ContractData.stages` adds optional multi-stage operations; `BaseModuleData.icon` and `ContractData.icon/color` feed the icon-first UI. `EnemyData.habitat` drives water/lava-aware spawning.

Runtime item instances are save-friendly dictionaries: `{uid, kind, base_id, slot, rarity, level, affixes[]}`. ItemFactory generates, describes, resolves and values them; WeaponData/ItemTemplate remain immutable definitions.

## 5. Player and combat

Player extends CharacterBody3D and builds its children in code:

- CollisionShape3D (capsule, crouch-resized)
- Head -> CameraPivot -> Camera3D (yaw on body, pitch on head, recoil/trauma on pivot)
- StatsComponent and HealthComponent
- WeaponController with procedural viewmodels under the camera
- AbilityManager
- interaction ray through direct space state

Movement is accelerated/friction-based and ticked in `_physics_process`. Mouse look happens in `_unhandled_input`; gamepad look is polled in physics. Crouch (Ctrl/C with ceiling-safe stand-up), slide, jump buffering, coyote time, per-weapon ADS zoom, footstep cadence, shield regen, downed/self-revive and first-person HUD snapshots are integrated here. Advanced verbs query `ProfileState.is_mechanic_unlocked()`; the mechanic table lives in `features/player/mechanic_unlocks.gd`.

Fluid/hazard handling is analytic: `_update_fluid_state()` queries `WorldBuilder.sample_fluid()` at the player's XZ, applies buoyancy/swim drag and `SWIM_SPEED` in water, heat damage scaled by `HAZARD_RESIST` in lava, and emits `EventBus.hazard_state_changed` for the HUD tint. A small camera headlamp switches on when the day/night cycle reports night.

### Damage pipeline

DamageData (RefCounted) carries amount, damage type, team, source, crit, weakpoint multiplier, status effect, impulse and hit info. HealthComponent.take_damage() applies armor mitigation, shield absorption and health loss, then emits damaged, health_changed, shield_changed, status_applied and died.

Hitscan shots use PhysicsDirectSpaceState3D.intersect_ray() with a 141 mask (World | Enemy | Friendly | Deployable), excluding the player RID. Weapon damage includes player damage multiplier, falloff, critical roll and status chance. Weakpoints are extra collision shapes with meta `weakpoint_mult`; CombatUtils resolves them from the hit shape. CombatUtils.aoe_damage() handles explosions and ability damage.

Player hitscan and enemy projectiles use separate masks: CombatUtils.HIT_MASK excludes the Player layer so player explosives cannot self-damage; EnemyProjectile uses World | Player | Friendly and checks team through HealthComponent.

### Weapon runtime

WeaponController loads equipped primary/sidearm from ProfileState, resolves stats through ItemFactory.weapon_runtime_stats(), builds a procedural low-poly viewmodel, and manages auto/semi/burst/charge/projectile fire modes, spread/bloom, recoil, per-weapon ADS zoom, reload, ammo, swap, muzzle flash, tracers, impacts, damage numbers, hitmarkers, camera kick and audio. The HUD renders a procedural scope overlay for weapons whose ADS zoom is 0.60 or lower. Projectiles/grenades use CombatProjectile.

### Abilities

AbilityManager is a scene-scoped child of the player. It owns two active abilities and one ultimate, cooldown timers ticked in `_physics_process`, and dispatches effect IDs to a readable registry. Effects include dashes, barriers, cloaks, buffs, chain lightning, gravity wells, cone slams, turrets, scans, healing fields, barrages, rewinds, hazard wards, smoke veils, mines, zip lines and four ultimates. Deployables are AbilityDeployable StaticBody3D instances with wall, sentry or mine behavior. All 24 abilities are exercised headlessly.

## 6. World generation and navigation

WorldBuilder generates a deterministic region from a seed:

1. Data-only worker phases produce base landforms, biome weights, POI anchors, roads, a map image and chunk vertex data.
2. Main-thread commits build 8x8 terrain chunks (ArrayMesh + trimesh collision), flattened POI pads, roads/pylons and merged POI geometry.
3. About 5,000 MultiMesh scatter instances and horizon landmarks are added.
4. A procedural sky, directional sun, fill light, dust fog and volumetric effects are installed.
5. A NavigationRegion3D is baked asynchronously from static colliders in group nav_source.

Expansion world systems:

- **Planets / map presets**: `apply_preset()` now consumes the enriched preset (planet, weather defs,
  fluid config). Planet terrain tints are applied in the terrain worker and tactical map; biome names
  come from the planet. Five planets share the same schema (Meridian-9, Cinder-4, Thalassa-2, Frost-9,
  Nyx-12) across 12 presets. `RunState.start_run(..., map_id)` supports an explicit map override while
  the difficulty's featured map remains the default. The environment systems prefer a preset-level
  weather pool when authored and fall back to the planet pool otherwise.
- **Fluid basins**: `_place_fluid_basins()` chooses seeded low, quiet ground away from POIs/roads,
  `build_final_fields()` carves the bowls and emits a fluid mask, `WorldFluid` builds one surface mesh
  per basin with water/lava shaders, and `sample_fluid(xz)` answers gameplay queries analytically.
  Player and EnemyAgent use the query for swim drag and lava damage; scatter skips fluid cells.
- **Enterable interiors**: WorldStructures builds hollow rooms with 4.2 m doorways and 3.4 m+ ceilings
  (wide enough for the 1.3 m navmesh agent radius), interior lights and `InteriorSpawn` markers; the
  derelict freighter POI is fully enterable. `WorldBuilder.get_pois()` exposes `interior` and
  `dungeon_anchor`; the navmesh bakes through the doorways.
- **Environment systems**: `WorldEnvironment` creates an `EnvironmentDirector` (single writer for sky,
  sun, fill and fog), a `DayNightCycle` (planet day length, four keyframes, moving sun) and a
  `WeatherSystem` (seeded state machine, particle layer, lightning, vision/move multipliers). The
  director also supports an indoor override used by dungeons.

Public API: generate(seed), sample_height(Vector2), get_spawn_points(), get_exfil_points(), get_pois(), get_roadside_points(), get_nav_region(), get_map_texture(), get_world_seed(), plus get_biome_names(), get_fluid_basins(), sample_fluid(), get_fluid_root(), get_environment_director(), get_day_night_cycle(), get_weather_system(), get_interior_pois(). generation_progress, generation_finished and navigation_ready drive loading.

Measured generation after the expansion (default frontier, no preset): about 1.1 s total, nav bake about 190 ms, 16 POIs, 14 roadside outbuildings, 3 exfils, 2 spawns, 64 chunks, about 204,800 terrain triangles and 3,165 navigation polygons. Preset generation adds optional extra POIs and raises roadside/scatter budgets; the observed default world-test budget remains well inside the 180 s suite timeout.

## 7. Enemies

EnemyAgent extends CharacterBody3D and is the single enemy implementation for all archetypes, configured by EnemyData:

- procedural visual kits by style (humanoid, heavy, beast, flyer, titan), faction colors and emissive weakpoints
- collision layer 4, mask 1|2, floor snap, NavigationAgent3D with direct-steering fallback
- Health child + weakpoint shape; root meta health_component
- perception (vision cone + LOS + hearing) at 0.2 s intervals, FSM, role-based combat, telegraphs, melee/ranged attacks, elite affixes, boss phases, statuses and death VFX/audio
- group enemy_ai; elites also enemy_elite, bosses enemy_boss
- death records kills and authored XP into RunState, emits EventBus events, spawns EnemyLootDrop, never ends the run; `behavior_flags` can add a volatile death blast

EnemyProjectile handles enemy bolts; a private enemy AoE handles volatile/slam damage to player and allies. EnemySpawner is an optional bounded helper.

## 8. Companions

CompanionManager spawns up to two active Wardens and the active Driftling from ProfileState, exposes get_squad_status() for HUD polling and issue_squad_command(). AllyAgent handles formation follow, LOS combat, role support, downed/E-revive, auto-revive of the player and commands. PetAgent handles float-follow and the three pet effects. ShockTurret is the engineer's temporary turret.

## 9. Run lifecycle and world events

Deployment owns one operation:

- App.start_deployment(contract, seed, threat, mutators, difficulty_id, mode_id, map_id) selects a named difficulty, game mode and optional explicit map; RunState.start_run stores them, resolves the map preset, reward/density/elite/max-hostile/loot helpers and time scale (2x for Quick). Mode `run_duration`, `storm_fraction`, `start_time` and `starting_weather` are applied here; `get_run_duration()` is the single denominator for timer, fraction, storm and safe radius.
- WorldBuilder.apply_preset(ContentDB.get_map_preset(...)) runs before WorldBuilder.generate(); the world seed is mixed with the preset seed salt. This selects biome rotation, extra POIs, roadside/scatter density and the sky/fog/sun mood.
- Player, companions, objectives, exfils, Rift Shrine, loot caches, bounty elites, POI beacons and enemies are spawned with difficulty-scaled counts. Four nearest POIs are garrisoned immediately; the rest stage in when the player comes within 140 m. Contract sites scale 3–6 with difficulty, plus side objectives (caches/bounties/shrine). Non-boss hostiles farther than 300 m are pruned every 5 s.
- ready_to_play(player) tells App to show the HUD and capture the mouse.
- `_process` ticks the run timer through RunState (game-time scaled), storm damage, compass/tracker markers, extraction holds, scheduled world events, a reinforcement director after 40 s and four timed endgame pressure events. Director/extraction timers apply RunState.time_scale and difficulty scales.
- Deployment.get_tactical_data() feeds the HUD minimap/overlay with the map texture, map/mode identity, player pose, objective/building/cache/bounty markers, hostiles, allies and extraction/storm state. _update_compass_markers() also feeds HUD mission trackers (contract + side objectives) with positions and progress.
- RunState.end_run() constructs a result (difficulty, map, mode, mode clock, run duration, time scale, XP breakdown) and emits EventBus.deployment_ended; ProfileState.record_run returns a level-up summary that App attaches before Results.

**Three of twenty world events** are scheduled per run at weighted, run-relative windows scaled to `RunState.get_run_duration()`. Events are authored in `ContentDB.get_world_events()` (supply drops, wandering elites, faction skirmishes, rift surges, black-market drops, cache beacons, lost caravans, jammer fields, fog fronts, Bloom spawns, supply convoys, rift echoes, meteor strikes, rift cyclones, toxic drift, whiteouts, scavenger convoys, bounty brokers, distress beacons and collapse tremors). Supply/convoy events create interactable supply sites/caches; forced-weather events call `WeatherSystem.force_weather()`; new event ids add elite/boss waves, rift mods, marked bounties, rescue flavour or pull the storm clock earlier. All events null-check the player/world, emit `EventBus.world_event(title, description, icon, color)` for the HUD Reach Event banner, and never crash before the player exists. Endgame events at 58/72/86/94% of the run add hunter packs, rift incursions, collapse surges and a final stand (including a random boss from `ContentDB.get_boss_enemies()` at high difficulty).

Loot: enemies drop physical EnemyLootDrop caches scaled by difficulty loot luck; objective/supply completion spawns physical drops; LootCache nodes are one-shot interactable crates on POIs/roadsides that feed the side-cache objective.

Death, bleedout, self-revive, ally revive, timer expiry, exfil success and objective completion all feed the same result path.

## 9b. Under-reach dungeons and Field Training

**Dungeons** live in `features/dungeon/`. `DungeonBuilder` grows a connected 3x3-slot room graph,
builds hollow rooms/corridors/bulkheads with one merged mesh + trimesh collider, and bakes a private
`NavigationRegion3D` synchronously in local space (the instance is moved to a remote origin after the
bake so the crash-prevention check stays happy). `DungeonRuntime` owns encounter spawns (room packs,
elite, theme boss, loot caches), boss registration with Deployment, and clear state. `Deployment`
pre-generates 2–3 instances during loading, places `DungeonEntrance` hatches at world POI anchors,
teleports the player on entry (suspending the squad and switching the environment indoors), pauses
storm damage while inside, and restores everything on exit. Dungeon clears feed `RunState` results and
profile records, and `dungeon`/`dungeon_boss` contract stages.

**Field Training** lives in `features/tutorial/`. `RunState` mode `tutorial` uses a relaxed 30-minute
clock, a 12-second exfil hold and never starts the Collapse. Deployment skips contracts, hostiles,
side objectives and world events, spawns two `TrainingTarget` dummies, a tutorial loot cache and a
training exfil beacon, then attaches `TutorialDirector`. The director observes real actions
(movement/look, weapon hits, ability cast, cache open, exfil hold), broadcasts
`EventBus.tutorial_stage_changed` to the HUD card, and lets the normal extraction path end the run.
`ProfileState.record_run()` special-cases tutorial results: it marks `tutorial_done` and grants a small
starter reward without counting a deployment or death.

## 10. UI

UIRoot extends CanvasLayer and owns theme, screen stack, overlays and HUD. App interacts through public methods: show_main_menu, show_hub, show_loading, show_deployment_hud, show_results, show_pause, refresh. `show_loading(title, progress, brief)` passes a `LoadingBrief.build(...)` payload (operation, map/planet, mode/difficulty, seed and boss dossier) resolved before `RunState.start_run()`. The HUD is a separate Control bound to Player and EventBus.

- Loading cinema: `LoadingScreen` is a four-act drop feed instead of a static progress page — **01 Threat Signature** (code-drawn boss dossier with weak points, phases, integrity/shield bars and counter-intel), **02 Rift Breach**, **03 Drop Descent** and **04 Touchdown**. Shots are `UICinemaShot` subclasses (`CinemaBossShot`, `CinemaRiftShot`, `CinemaDescentShot`, `CinemaTouchdownShot`) drawing from plain primitives with map/planet sky colours and the actual boss selected for the planet roster + seed. A `CinemaFilmOverlay` supplies letterbox, scrims, scanlines, grain and vignette. Act timing is progress-aware with minimum dwell and a hard cap; the live progress/step/field-note rail never blocks the loader. Space/Enter or the rail button skips to a static briefing; reduced motion opens the same static briefing, and both remain fully testable without a rendered 3D scene.
- Theme: code-built with Sora/Inter/JetBrains Mono variable fonts and semantic type variations.
- Screens: data-driven from ContentDB/ProfileState; Quick Deploy preflight offers planet portraits, map thumbnails, four difficulties, 12 maps, 5 planets, 5 mode cards, weather forecast and target intel; hub offers the same choices plus contract/mutator selection; skills shows level-gated mechanics and perks with discipline/ability medallions; results shows map/mode identity, mode clock and run duration, XP breakdown and level-up progression; loadout/locker/skills/squad use reusable code-drawn art (`UIItemArt`, `UIWardenPreview.compact`, `UIIconMedallion`, `UIAllyPortrait`, `UIPetArt`), and the outpost renders an 8×8 isometric diorama with `UIModuleArt` children. The menu language is image-first, with explanatory copy in tooltips.
- HUD: signals plus 10 Hz snapshot fallback; top-left minimap (polled at 5 Hz) with building/cache/bounty markers, M-key tactical map, procedural precision scope, objectives, FIELD OPS tracker (distance/direction, max 4 + overflow), compass markers with shapes per kind, squad status, boss bar, subtitles/toasts, interaction, downed and KIA states. Timer caption carries map/threat/mode identity. `EventBus.world_event` drives a queued, auto-hiding **Reach Event banner** (icon, title, wrapped description, colour, reduce-motion aware) exposed as `get_world_event_panel()`.
- Settings: the Display card exposes window mode, resolution, V-Sync, render scale, anti-aliasing, frame-rate cap, quality preset and interface scale through App option getters; rows carry `meta("setting_key")` and test accessors (`get_control`, `get_option_control`).
- Accessibility: UI scale, high contrast, reduced motion, subtitles, damage numbers, minimap toggle, key rebinding (including C crouch alternate) and gamepad focus.

## 11. Save format

Path: `user://riftward_profile.json`, schema version **5**. Settings: `user://settings.cfg`.

Top-level fields: version, profile_id, callsign, playtime, level/XP, attributes and points, discipline, ability loadout, skill ranks, salvage/cores, next item UID, inventory, equipped slot->UID mapping, base module tiers/layout (`base_layout` + `base_layout_version`), active allies/pet, ranks, unlocked/equipped cosmetics, records (including dungeon entered/cleared counts), last difficulty, last mode, last map, daily slot, tutorial flag and last run. New fields deep-fill from defaults, so older saves load unchanged (`last_mode` is validated against the selectable mode ids and falls back to Normal, `last_map` to the difficulty's featured map).

The v5 save adds the versioned outpost layout. `ProfileState.validate_base_layout()` checks all eight modules, integer/Vector2i positions, in-bounds footprints on the 8×8 board and no overlap; `ensure_base_layout()` resets an invalid or stale payload to the authored v2 plan. The v4→v5 migration resets only `base_layout`/`base_layout_version`, preserving module tiers, currencies, inventory and everything else. Writes are atomic (temp file then rename) with a .bak copy; load deep-fills defaults, validates and clamps values, and falls back to the backup if the primary file is corrupt. There is no mid-run save; profile saves happen at hub/results transitions and explicit upgrade actions.

## 12. Input and settings

Input actions are registered in App.ensure_input_actions() (physical keycodes, mouse buttons, gamepad buttons/axes). Crouch has two actions (`crouch` on Ctrl, `crouch_alt` on C) so rebinding one preserves the other; `map` (M) toggles the tactical overlay. Gameplay uses _unhandled_input for mouse look and _physics_process for movement/abilities. App.rebind_action() erases the action's events and persists the new binding; Settings exposes rebinding UI.

Settings stored in user://settings.cfg: volumes, FOV, mouse/ADS sensitivity, invert Y, window mode, resolution, render scale, anti-aliasing, FPS limit, fullscreen (legacy, migrated into window_mode), VSync, UI scale, reduced motion, high contrast, damage numbers, subtitles, camera shake, minimap visibility, quality preset, FPS display and bindings. `App.apply_display_settings()` is the single display writer: it maps window mode to Godot window modes, clamps resolution to the monitor and centres windowed mode, applies V-Sync, `Engine.max_fps`, viewport `scaling_3d_scale`, MSAA/SSAA/TAA, and quality-preset shadow-atlas/LOD/debanding values. Every window mutation is guarded by `DisplayServer.get_name() != "headless"`, so headless suites and CI apply settings without errors. Audio, display and gameplay-facing settings are applied through App and EventBus.

## 13. Threading and performance notes

- World data generation runs in worker threads; SceneTree mutations happen on the main thread.
- POI/terrain geometry is merged and collision simplified per POI; scatter uses MultiMesh.
- Enemy perception/path retargeting and ally scans are timer-based, not per-frame.
- Tracers, impacts, damage labels and explosions are short-lived nodes; high-volume projectile visuals could be pooled further.
- Target: 60 FPS at 1080p on a mid-range desktop GPU. The reference machine is an RTX 3060; D3D12 render smoke tests complete without renderer errors. A formal FPS capture was not automated in this build.

## 14. Tests

| Suite | Command | Current result |
|---|---|---|
| Project boot | `--headless --path . --quit-after 240` | exit 0, no script errors |
| Shooting/input regression | `--headless --path . --quit-after 4000 -- --shoot-smoke` | PASS - real App boot, sniper fire, four weapon slots, knife, abilities, grenade, reload, swaps and commands |
| Inventory regression | `--headless --path . --quit-after 4000 -- --inventory-smoke` | PASS - paused field inventory, four weapon rows, satchel, clean close |
| Gameplay integration | `--headless --path . res://tests/integration_test.tscn` | PASS - includes map/planet/weather data, fluid sampling, interiors and dungeon entry/exit |
| Death/downed/results | `--headless --path . res://tests/death_test.tscn` | PASS |
| Under-reach dungeons | `--headless --path . res://tests/dungeon_test.tscn` | PASS - all 3 themes, rooms, nav, collision, encounter, boss, loot |
| Field Training | `--headless --path . res://tests/tutorial_test.tscn` | PASS - five stages, exfil, persistence |
| World contract test | `--headless --path . res://features/world/world_test.tscn` | PASS - 17+ POIs, interiors, fluid basins, nav, map texture, environment systems |
| Planet variants | `--headless --path . res://tests/world_variants_test.tscn` | PASS - original and new planet/map presets, fluids, weather, day/night |
| Enemy AI test | `--headless --path . --script res://features/ai/ai_test.gd` | 134/134 checks PASS |
| Companion test | `--headless --path . --script res://features/companions/companions_test.gd` | 78/78 checks PASS |
| Progression/content | `--headless --path . --script res://tests/progression_test.gd` | PASS - counts, planets/maps/weather/dungeons, modes, contracts, world events, layouts, display settings |
| UI harness | `--headless --path . res://ui/ui_demo.tscn --quit-after 2400` | PASS - includes map/planet/mode preflight, loading-cinema acts/boss dossier/skip/reduced motion, art components, settings display, Reach Event HUD |
| Icon catalog | `--headless --path . --script res://tests/ui_icons_test.gd` | PASS - every referenced icon (including the 12 new SVGs) resolves |

Run all 14 suites with `tests/run_all.ps1`. See QA_REPORT.md for logs and screenshot evidence.

## 15. Packaging

The project runs from source with Godot 4.7.2, and it also exports as a standalone Windows x86_64 build.

### One-command build

```powershell
# double-click BUILD.cmd, or:
powershell -ExecutionPolicy Bypass -File tools/build_export.ps1
```

`tools/build_export.ps1` resolves the Godot binary through `tools/find_godot.ps1` (or `$env:GODOT_BIN`), verifies that export templates for the running engine version are installed, creates `build/`, and exports the **Windows Desktop** preset to `build/RIFTWARD.exe` + `build/RIFTWARD.pck`. Add `-Zip` to also produce `build/RIFTWARD-win64.zip`, or `-Debug` to export the debug template.

`RIFTWARD.exe` and `RIFTWARD.pck` must stay in the same folder; only the `.pck` is updatable on its own.

### Prerequisites

1. Godot 4.7.2 - `tools/find_godot.ps1` searches `$env:GODOT_BIN`, PATH, `Downloads`, `Desktop`, `Program Files` and `D:\`.
2. Export templates for **exactly** the engine version (for example `4.7.2.stable`), installed in `%APPDATA%\Godot\export_templates\4.7.2.stable\`. Get them from **Editor -> Manage Export Templates** or by extracting `Godot_v4.7.2-stable_export_templates.tpz` (the `templates/` folder) into that directory. Only the `windows_*_x86_64*.exe` files and `version.txt` are required for this preset.

### Preset

`export_presets.cfg` is checked in and defines a single preset, **Windows Desktop**:

- Output: `build/RIFTWARD.exe` (x86_64, release, `.pck` alongside the executable, no embedded pack).
- Filters out `.build/`, `build/`, `release/`, `media/`, `tests/`, `docs/`, `captures/`, `tools/`, `ui/_screenshots/`, `.agent-teams/`, the `preview_shots/` and `preview/` QA folders, `*.md`, `*.cmd` and `*.ps1`, so no documentation, marketing art, QA evidence or build caches ship inside the pack (the packaged `.pck` is currently about 2.4 MB).
- App icon from `assets/icons/riftward_icon.svg`, product metadata `RIFTWARD`.

### Manual export

Open the project in Godot 4.7.2, use **Project -> Export...**, pick **Windows Desktop**, and export to `build/RIFTWARD.exe`. The folder must exist first; Godot does not create the parent directory.

The `tools/play.ps1` launcher and `RIFTWARD.cmd` remain the way to run directly from source.

## 16. Extension guide

- Add a weapon: add an entry to ContentLibrary._weapons(), add viewmodel style handling in WeaponModelBuilder if unique, update counts in ContentDB, run the integration suite.
- Add an ability: add AbilityData to _abilities(), implement its effect_id in AbilityManager._execute_effect(), assign an unlock level.
- Add an enemy: add EnemyData to _enemies() and optionally extend EnemyVisuals for a new style; EnemyAgent handles the rest. Optional `behavior_flags` entries such as `volatile_death` are read by EnemyAgent.
- Add a POI kit: extend WorldStructures with a builder and add its type to the POI placement pool in WorldBuilder. Roadside kits are selected from the `_roadside_points` list.
- Add a mechanic unlock: add an entry to `features/player/mechanic_unlocks.gd`, then gate the input/UI through `ProfileState.is_mechanic_unlocked()`.
- Add a difficulty: add a dictionary preset (with map_preset + mission/side-cache/hostile/scale fields) to ContentLibrary._difficulties() and update the expected count in ContentDB.
- Add a map preset: add a preset dictionary to ContentLibrary._map_presets(), point a difficulty at it, and keep the expected count at 12 in ContentDB. WorldBuilder.apply_preset() consumes it before generation.
- Add a planet: add a dictionary to ContentLibrary._planets() with biome names, tint, sky keyframes, weather pool, fluid config and dungeon themes; point map presets at it and update the ContentDB count (5).
- Add weather: add a dictionary to ContentLibrary._weather() (icon/colour/hazard/fog/sun/particles/vision/move) and include its id in a planet weather_pool or a map preset weather_pool.
- Add a game mode: add a dictionary to ContentLibrary._game_modes() with run_duration/time_scale/start_time/storm_fraction/density/elite/reward/hostile/loot fields, clock, tag, icon, colour and description; RunState and the UI resolve it by id. Update the expected count (5).
- Add a world event: add a dictionary to ContentLibrary._world_events() with id/title/text/icon/colour/weight and a matching effect branch in Deployment._trigger_world_event(); the HUD and Codex pick it up automatically. Update the expected count (20).
- Add a UI art component: create a static Control under ui/components/ that draws with primitives, expose configure()/get_* accessors and a UIFactory helper; screens stay data-driven.
- Add a dungeon theme: add a dictionary to ContentLibrary._dungeon_themes() (room range, enemy/elite pools, boss, colours); DungeonBuilder consumes it through the injected theme dictionary.
- Add a tutorial stage: extend TutorialDirector.STAGES and its observation branch in `_process`; emit progress through `EventBus.tutorial_stage_changed`.
- Add a base module: add BaseModuleData (including icon), add a BASE_LAYOUT position in ProfileState and update BASE_LAYOUT_VERSION if the authored board changes; the Outpost UI picks it up automatically.
- Add a screen: create a Control screen under ui/screens/, register it in UIRoot.SCREEN_PATHS and add navigation.
