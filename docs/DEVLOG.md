# RIFTWARD — Developer Log

Engineering notes for every public source release: what changed, why it changed, how it was verified,
what migrates, what is still broken and how to cut the next build. This file is the long form;
[CHANGELOG.md](../CHANGELOG.md) is the short form and [docs/releases/](releases/) holds the
player-facing release bodies.

- Repository: [github.com/r48n34/riftward](https://github.com/r48n34/riftward)
- License: GNU GPL v3.0 or later ([LICENSE](../LICENSE))
- Engine: Godot 4.7.2 stable, Forward+, Jolt Physics, D3D12 on Windows

---

## Contents

- [0.2.0 — 2026-10-25](#020--2026-10-25)
  - [1. Release at a glance](#1-release-at-a-glance)
  - [2. Footprint](#2-footprint)
  - [3. Verification evidence](#3-verification-evidence)
  - [4. Design intent](#4-design-intent)
  - [5. World and planets](#5-world-and-planets)
  - [6. Weather and day/night](#6-weather-and-daynight)
  - [7. Water and lava](#7-water-and-lava)
  - [8. Enterable interiors](#8-enterable-interiors)
  - [9. Under-reach dungeons](#9-under-reach-dungeons)
  - [10. Field Training](#10-field-training)
  - [11. Run modes](#11-run-modes)
  - [12. Contracts and world events](#12-contracts-and-world-events)
  - [13. Enemies](#13-enemies)
  - [14. Weapons, abilities and perks](#14-weapons-abilities-and-perks)
  - [15. Squad and pets](#15-squad-and-pets)
  - [16. Outpost layout v2](#16-outpost-layout-v2)
  - [17. Save format v5 and migration](#17-save-format-v5-and-migration)
  - [18. UI expansion](#18-ui-expansion)
  - [19. Audio](#19-audio)
  - [20. Tooling, tests and documentation](#20-tooling-tests-and-documentation)
  - [21. Known issues and limitations](#21-known-issues-and-limitations)
  - [22. Upgrade and release instructions](#22-upgrade-and-release-instructions)
- [0.1.0 — 2026-10-24](#010--2026-10-24)
- [Maintaining this log](#maintaining-this-log)

---

## 0.2.0 — 2026-10-25

Theme: the **Frontier Update** plus the **UI/content expansion**. 0.2.0 turns the 0.1.0 vertical slice
into a wider frontier (five planets, weather, day/night, fluids, interiors, dungeons, onboarding, five
modes, staged contracts) and rebuilds the interface around the objects it is about (art components,
image-first screens, a deployment loading cinema, display settings, a Reach Event banner).

### 1. Release at a glance

| Field | Value |
|---|---|
| Version | `0.2.0` |
| Release date | 2026-10-25 |
| Baseline | commit `cfcbdec` — `0.1.0` "First Light" source drop, 2026-10-24 |
| Tag | `v0.2.0` |
| Engine | Godot 4.7.2 stable (`ed1daf0bf`), Forward+, Jolt Physics, D3D12 |
| Save schema | `SAVE_VERSION` **5**, `BASE_LAYOUT_VERSION` **2** |
| Content counts | 5 planets, 12 map presets, 18 weather states, 5 game modes, 13 contracts, 20 world events, 16 weapons, 24 abilities (20 active + 4 ultimates), 24 perks, 12 Rift Mods, 8 mutators, 37 enemies (20 base + 11 elites + 6 bosses), 3 dungeon themes, 8 outpost modules, 4 Warden allies, 3 Driftling pets |
| Test gate | 14/14 headless suites PASS (`powershell -ExecutionPolicy Bypass -File tests/run_all.ps1`) |
| Windows build | `release/RIFTWARD-win64.zip` — `README.txt` + `RIFTWARD.exe` + `RIFTWARD.pck` (about 40 MB zipped), checksummed in `release/SHA256SUMS.txt` |
| License | GPL-3.0-or-later; bundled fonts under SIL OFL 1.1, Godot under MIT — [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) |

### 2. Footprint

Measured against `cfcbdec` while preparing this release. Concurrent documentation edits during release
preparation can move the documentation numbers by a file or two; the code and content counts are stable.

| Area | Files | Notes |
|---|---|---|
| Modified code/config | 59 | +9,585 / -1,127 lines (autoloads, features, UI, tests, `project.godot`) |
| Modified documentation | 12 | `README.md`, ten files under `docs/` and `features/world/WORLD_API.md` |
| Refreshed screenshots | 20 | 16 core `ui/_screenshots/` files re-captured at 1600x900 and 4 new drop-feed acts added; `16_tactical_map` stayed byte-identical |
| New GDScript | 26 | dungeon, tutorial, world environment/weather/fluids, cinema + art components, load brief, tests |
| New scenes | 3 | `tests/dungeon_test.tscn`, `tests/tutorial_test.tscn`, `tests/world_variants_test.tscn` |
| New shaders | 2 | `assets/shaders/world/water.gdshader`, `lava.gdshader` |
| New SVG icons | 29 | 17 frontier icons (planet, moon, dungeon, lava, water, weather, ember, wave, smoke, drone, mine, grapple, training) plus the 12-icon UI expansion set |
| New capture files | 22 | 4 drop-feed captures (`18_loading_breach` … `21_loading_leviathan`, taking `ui/_screenshots/` to 21 files) and 18 planet world-preview frames |

Godot also writes `.import` and `.gd.uid` sidecars for the new assets; they are intentionally committed so
imports and script references stay stable across machines (see [docs/GITHUB.md](GITHUB.md) §8).

### 3. Verification evidence

The gate is the local aggregate runner; there is no CI in the repository by design
(see [docs/GITHUB.md](GITHUB.md) §0). A full run writes one log pair per suite to `tests/artifacts/logs/`.
The runner fails on `SCRIPT ERROR`, on engine `ERROR:` lines (with the Windows certificate-store line
that sandboxed machines emit filtered out) and on a missing PASS marker.

| Suite | Command | Result |
|---|---|---|
| Boot | `--headless --path . --quit-after 240` | PASS — boots to the main menu, no script errors |
| Shooting/input | `--headless --path . --quit-after 4000 -- --shoot-smoke` | PASS — real App boot, sniper charge fire, four weapon slots, knife, abilities, grenade, reload, squad/pet commands |
| Inventory | `--headless --path . --quit-after 4000 -- --inventory-smoke` | PASS — real boot, I-key pause, four weapon rows and satchel, clean close |
| Gameplay integration | `... res://tests/integration_test.tscn` | PASS — **118/118** checks |
| Death/downed/results | `... res://tests/death_test.tscn` | PASS — **9/9** checks |
| Under-reach dungeons | `... res://tests/dungeon_test.tscn` | PASS — **57/57** checks |
| Field Training | `... res://tests/tutorial_test.tscn` | PASS — **20/20** checks |
| World contract test | `... res://features/world/world_test.tscn` | PASS — POIs, interiors, fluids, navmesh, collision, map texture, environment systems |
| Planet variants | `... res://tests/world_variants_test.tscn` | PASS — **168/168** checks |
| Enemy AI | `--headless --path . --script res://features/ai/ai_test.gd` | PASS — **134/134** checks |
| Companions | `--headless --path . --script res://features/companions/companions_test.gd` | PASS — **78/78** checks |
| Progression/content | `--headless --path . --script res://tests/progression_test.gd` | PASS — **786/786** checks |
| UI harness | `... res://ui/ui_demo.tscn --quit-after 2400` | PASS — **130/130** checks |
| Icon catalog | `--headless --path . --script res://tests/ui_icons_test.gd` | PASS — **148/148** checks |

That is **14/14 suites** and **1,648 asserted checks** across the ten suites that report a check count
(the boot, shooting, inventory and world suites are marker/error-gated contract tests). Logs were produced
on 2026-10-25 during release preparation; the only engine `ERROR:` line in them is the Windows
certificate-store probe, which the runner strips because it is host noise, not a game error.

All check-counted suites report zero failures; the UI harness figure includes the loading-cinema,
art-component and icon checks added in the final pass.

Evidence beyond the headless suites:

- **21 screen captures** in `ui/_screenshots/` at 1600x900: `01_main_menu` … `17_quick_deploy`, plus the
  four drop-feed captures `18_loading_breach`, `19_loading_descent`, `20_loading_touchdown` and
  `21_loading_leviathan`. The 17 numbered captures were inspected in the windowed UI pass; the four
  drop-feed captures document the new cinema acts.
- **25 world-preview frames** in `features/world/preview_shots/`: seven default-frontier frames, and nine
  framed shots each for `cinder_caldera/` and `tidal_shelf/`, captured through the windowed D3D12
  renderer with `world_preview.tscn -- --capture --preset <id>`.
- **Windows export**: rebuilt for this release and smoke-run. The packaged build contains `README.txt`,
  `RIFTWARD.exe` and `RIFTWARD.pck`; the executable must stay beside the pack.
- **World metrics** (Verdant Verge preset, seed 12345, current log): generation about 1.3 s including a
  ~206 ms navigation bake; 19 POIs; 16 roadside outbuildings; 3 exfil pads; 2 drop zones; 9 interior
  markers; 64 terrain chunks; 204,800 terrain triangles; 3,144 navigation polygons; 5,802 MultiMesh
  scatter instances in 12 batches; 3 fluid basins (3 surface meshes, 2 lava lights, 20,384 fluid
  vertices).

### 4. Design intent

0.1.0 proved the extraction loop on one frontier: one planet's biome palette, two modes, six contracts,
23 enemies, ten weapons. The systems were sound but the game ran out of reasons to replay it. 0.2.0 was
scoped against that gap:

1. **More frontier per run, and a reason to choose it.** Planets, maps, weather, time of day and fluids
   change what a drop looks like and how it plays without rebuilding the core loop. Presets let a
   difficulty keep a featured map while the player overrides it.
2. **A second layer of risk.** Under-reach dungeons pause the storm but not the clock, add a boss and a
   loot decision, and feed staged contracts — an optional greed-versus-extraction move inside every run.
3. **Onboarding that does not patronise.** Field Training proves real actions (move, shoot, cast, loot,
   extract) before the Reach is allowed to kill a new Warden.
4. **Readable under pressure.** The interface moved from text-first rows to image-first objects: item art,
   portraits, medallions, map thumbnails, an outpost diorama, a cinematic drop feed and a Reach Event
   banner. Explanations moved into tooltips; recognition stayed on screen.
5. **Hardware honesty.** Display settings, render scale, AA, frame cap, quality preset and interface
   scale give players the controls the 0.1.0 build lacked.

Scope status is tracked in [docs/BUILD_PLAN.md](BUILD_PLAN.md) §2 (M7 "Frontier Update" and M8
"UI/content expansion", both COMPLETE).

### 5. World and planets

**Why.** One biome set cannot carry a full progression; every run looked the same after an hour. The
frontier needed distinct moods that also change gameplay, not just colour.

**What.**

- **Five planets**, each owning three biome names/palettes, terrain tint, day length, sky keyframes,
  weather pool, fluid configuration, hazard tag and dungeon theme list.

| Planet | Biome names | Day length | Fluid configuration | Weather pool |
|---|---|---|---|---|
| Meridian-9 (The Reach) | Verdant Basin / Ashen Canyons / Glass Flats | 1,080 s | water + lava | Clear, Dust Front, Rain, Rift Storm, Ion Tempest |
| Cinder-4 (The Ember Shelf) | Basalt Shelf / Ember Canyon / Ash Flats | 720 s | lava only | Clear, Ashfall, Ember Storm, Heat Haze, Meteor Shower |
| Thalassa-2 (The Drowned Shelf) | Tidal Shelf / Kelp Basin / Salt Flats | 900 s | water only | Clear, Rain, Squall, Fog Front, Toxic Squall |
| Frost-9 (The Long Winter) | Glacier Shelf / Frozen Canyon / White Expanse | 1,260 s | water only | Glacier Front, Fog Front, Overcast, Squall, Clear |
| Nyx-12 (The Silent Fold) | Rift Steppe / Null Basin / Echo Flats | 640 s | lava only | Whiteout, Rift Cyclone, Ion Tempest, Rift Storm, Clear |

- **Twelve map presets**, four per Meridian-9 and two per remaining planet: Verdant Verge, Ashen Shelf,
  Glass Expanse, Rift Scar, Cinder Caldera, Ember Reach, Tidal Shelf, Brine Expanse, Glacier Shelf,
  White Expanse, Null Steppe, Echo Basin. A preset carries a seed salt, biome emphasis, start time,
  scatter/roadside/extra-POI budgets, environment overrides and an optional preset-level weather pool
  that overrides the planet pool for that drop.
- **Map override.** `RunState.start_run()` accepts an explicit `map_id`; the difficulty's featured map
  remains the default. `ContentDB.get_map_preset()` enriches the authored preset with its planet, every
  weather definition (so forced weather can resolve on any map) and merged fluid configuration before
  `WorldBuilder.apply_preset()` consumes it.
- **POIs.** 14 authored landmark kits plus 3 exfil pads (17 base) and 2–4 preset-specific extras, for
  **17–21 points of interest**: Warden outpost, faction camps, relay spires, crash site, vault, anomaly,
  ruin field, Ashen stockade, Bloom hive, Choir listening post, colony ruins, derelict freighter and the
  preset survey camps/relays/ruins/wrecks. 16–22 roadside outbuildings line the road network.
- Roughly **5,000–9,000 MultiMesh scatter instances** (preset-scaled), 52 horizon spires, 8x8 terrain
  chunks and an asynchronous navmesh bake (cell 2.0 m, agent height 1.9 m, radius 1.3 m).

**Where.** `features/content/content_library.gd` (`_planets`, `_map_presets`), `autoload/content_db.gd`,
`autoload/run_state.gd`, `features/world/world_builder.gd`, `world_terrain_worker.gd`,
`world_scatter.gd`, `world_palette.gd`, `world_structures.gd`; API contract in
[features/world/WORLD_API.md](../features/world/WORLD_API.md).

**Verified.** `world_variants_test` (168/168) generates the original and expanded preset list, checks
planet biome names, per-planet fluid rules (Cinder lava-only, Thalassa water-only, Frost water, Nyx
lava-only), interiors, weather and day/night; `world_test` prints the generation metrics listed in §3;
`integration_test` asserts the content counts and that the tactical layer exposes map/planet/mode/weather
identity.

### 6. Weather and day/night

**Why.** Weather is the cheapest way to make the same map play differently: it changes what you can see,
how far enemies see, and whether standing still is survivable. Day/night gives the clock a second meaning
and makes Blackout a real mode rather than a tint.

**What.**

- **18 weather states**: Clear, Overcast, Rain, Squall, Dust Front, Ashfall, Ember Storm, Heat Haze, Rift
  Storm, Fog Front, Spore Drift, Rift Winds, Ion Tempest, Meteor Shower, Toxic Squall, Glacier Front,
  Whiteout, Rift Cyclone. Each authors fog density/colour, sky tint, sun/ambient multipliers, volumetric
  fog, particle kind and amount (rain, dust, ash, embers, spores, sparks, snow), lightning chance, dwell
  and transition times, a hazard tag and `vision_mult`/`move_mult`.
- Gameplay effect is real: `vision_mult` runs from **1.00 (Clear) down to 0.30 (Whiteout)** and
  `move_mult` down to 0.80 (Rift Cyclone). Enemy perception multiplies its max range by the weather
  vision multiplier (refreshed on a 2 s timer), so a fog front genuinely shortens engagement ranges.
- `WeatherSystem` is a seeded state machine: dwell/transition blended, particles follow the player,
  lightning drives an environment flash, and `force_weather()` lets world events (and tests) pin a state.
  The pool comes from the preset when authored, otherwise from the planet.
- **Day/night cycle** per planet: four sky keyframes (night, dawn, day, dusk), a moving sun, stars and a
  night headlamp on the player. `DayNightCycle` publishes time of day and a clock string; the HUD shows
  the local clock next to the weather icon. **Blackout** starts the run at `start_time = 0.94`
  (late night).
- "Environment director" is the single writer for sky, sun, fill light, fog and lightning; it also
  carries the indoor override used by dungeons.

**Where.** `features/world/weather_system.gd`, `day_night_cycle.gd`, `environment_director.gd`,
`world_environment.gd`, `features/player/player.gd` (headlamp, hazard tint), `ui/hud/hud_root.gd`
(weather/clock chip).

**Verified.** `world_variants_test` (168/168) covers weather and day/night per planet and preset;
`integration_test` covers the weather identity path and the forced-weather world events; the UI suite
binds the weather/clock chip.

### 7. Water and lava

**Why.** Fluids turn low ground into a hazard and a route decision, and they give the planets distinct
identities (Cinder should feel hot, Thalassa drowned). They also needed to be cheap: analytic queries, not
physics volumes.

**What.**

- Seeded `_place_fluid_basins()` picks low, quiet ground away from POIs/roads; terrain generation carves
  the bowls and emits a fluid mask; `WorldFluid` builds one surface mesh per basin with `water.gdshader`
  or `lava.gdshader`, adds lava glow lights and tints the tactical map.
- `WorldBuilder.sample_fluid(xz)` is an analytic query returning `{type, level, depth, center, radius}`.
  The player uses it for buoyancy/swim drag and `SWIM_SPEED` in water and for heat damage scaled by
  `HAZARD_RESIST` in lava; `EventBus.hazard_state_changed` drives the HUD tint. Scatter skips fluid cells.
- Enemies are fluid-aware too: `EnemyData.habitat` (land/water/lava/any) keeps water natives near basins
  and lava natives near ember ground, and lava/deep water slow or damage them.
- Per-planet fluid budget is authored in the planet dictionary; Meridian-9 carries both water and lava,
  Cinder-4 and Nyx-12 lava, Thalassa-2 and Frost-9 water.

**Where.** `features/world/world_builder.gd` (`_place_fluid_basins`, `sample_fluid`),
`features/world/world_fluid.gd`, `assets/shaders/world/{water,lava}.gdshader`,
`features/player/player_stats.gd` + `features/combat/stat_keys.gd` (hazard resist, swim speed),
`features/ai/enemy_agent.gd` (environment ticks).

**Verified.** `world_test` asserts 3 basins with surfaces and lava lights and a working fluid raycast;
`integration_test` asserts basins exist and `sample_fluid()` resolves; `world_variants_test` asserts the
per-planet fluid rules.

### 8. Enterable interiors

**Why.** The 0.1.0 POIs were exteriors only, which made buildings read as scenery. Enterable space adds
loot/enemy anchors and a slower, riskier rhythm inside an open frontier.

**What.** Hollow rooms with 4.2 m doorways and 3.4 m+ ceilings (wide enough for the 1.3 m navmesh agent
radius), interior lights and `InteriorSpawn` anchors; the navmesh bakes through the doorways. Enterable
sets exist on the faction camp command hab, Vault bunker, crash-site hull, colony hab, Choir bunker,
Ashen command hall and the full derelict-freighter interior. `WorldBuilder.get_pois()` exposes `interior`
and `dungeon_anchor` flags; `get_interior_pois()` returns the enterable set.

**Where.** `features/world/world_structures.gd`, `world_builder.gd`.

**Verified.** `world_test` fires interior floor/ceiling rays inside the shells and reports 9 interior
markers; `world_variants_test` asserts interiors on all presets; the windowed preview pass captured
interiors for the default frontier, Cinder Caldera and Tidal Shelf.

### 9. Under-reach dungeons

**Why.** Extraction shooters need opt-in greed. A dungeon is a deliberate detour: the storm stops, the
clock does not, exfil is unavailable, and the reward is behind a guardian. It also gives the game a boss
fight that is not tied to contract RNG.

**What.**

- **Three themed kits**, each generated from the run seed into a connected 3x3-slot room graph:

| Theme | Rooms | Boss | Enemy pools | Loot rolls |
|---|---|---|---|---|
| Rift Vault | 5–8 | The Warden | Choir Sentinel / Nullifier / Wisp; elites Choir Prime, Choir Herald | 3 |
| Ashen Mine | 5–8 | Cinder Titan | Ashen Scrapper / Marksman / Sapper; elites Ash Reaver, Caldera Warlord | 3 |
| Choir Catacomb | 6–9 | Leviathan | Choir Sentinel / Weaver / Tide Sentinel; elites Choir Prime, Abyss Matriarch | 4 |

- **2–3 entrances per run**, pre-baked behind the loading screen and placed as hatches at vault, choir,
  stockade, colony and freighter POIs (deterministic shuffle so a seed always yields the same entrance
  set). Entering teleports the player to a remote origin, suspends the squad at the entrance, switches
  the environment indoors and pauses storm damage; exiting restores the surface position and squad.
- Each instance builds hollow rooms/corridors/bulkheads as one merged mesh plus trimesh collider, bakes a
  private `NavigationRegion3D` synchronously in local space, then moves the instance to its remote origin
  (the build order is deliberate: it keeps the physics crash check happy). `DungeonRuntime` spawns room
  packs, an elite guard, the theme boss, 2–4 loot caches, and registers the boss with `Deployment`.
- Clears bank profile records (`dungeons_entered` / `dungeons_cleared` on the save) and satisfy the
  `dungeon` / `dungeon_boss` contract stage types.

**Where.** `features/dungeon/dungeon_builder.gd`, `dungeon_runtime.gd`, `dungeon_entrance.gd`;
integration in `features/run/deployment.gd` (`_prepare_dungeons`, `enter_dungeon`, `exit_dungeon`,
`_set_indoor`); content in `content_library.gd` (`_dungeon_themes`).

**Verified.** `dungeon_test` (57/57) builds all three themes and checks 5–9 rooms, navmesh polygons,
floor/ceiling collision, start/exit/boss anchors, loot anchors, a spawned encounter (hostiles/boss/loot),
boss registration and despawn. `integration_test` (118/118) enters a pre-baked dungeon, spawns its
encounter and restores the surface position on exit. The UI suite binds the HUD dungeon banner and
`integration` checks the dungeon contract stages.

### 10. Field Training

**Why.** The first ten minutes were the highest-friction part of 0.1.0: new players died to systems they
had not been taught. Training needed to prove the verbs, not show a modal.

**What.** A five-stage guided run — **MOVE & LOOK** (10 m / look threshold), **AIM & FIRE** (three
target hits), **FIELD ABILITY** (cast an ability), **RECOVER SALVAGE** (breach a cache), **EXFIL**
(complete the hold). A real `TutorialDirector` observes actual gameplay and broadcasts
`EventBus.tutorial_stage_changed` to a HUD training card with title, copy, key hint and a live progress
bar. The mode runs on a relaxed **30-minute clock**, a **12-second exfil hold** and never starts the
Collapse; deployment skips contracts, hostiles, side objectives and world events and spawns two target
dummies, a training cache and a training exfil beacon. Pause offers **Skip Training**; the main menu can
replay it at any time. Completion persists `tutorial_done`, grants a small starter reward and never counts
as a deployment or a death in records.

**Where.** `features/tutorial/tutorial_director.gd`, `training_target.gd`; `autoload/run_state.gd`
(tutorial mode), `features/run/deployment.gd` (`_setup_tutorial`), `autoload/profile_state.gd`
(`record_run` special case), `ui/hud/hud_root.gd` (training card), `ui/screens/main_menu.gd` +
`ui/screens/pause.gd` (replay/skip).

**Verified.** `tutorial_test` (20/20) starts the real tutorial deployment and checks no hostiles/squad,
all five stages, the tutorial result flag, profile completion and the reward path.

### 11. Run modes

**Why.** Two modes (Normal/Quick) only changed clock speed. Modes should change risk, reward and pacing
so the same contract board supports a 9-minute session, a night run, a speedrun and a fight-heavy run.

**What.** Five selectable modes layered on the four difficulties (`patrol`, `contact`, `breach`,
`collapse`), authored in `ContentLibrary._game_modes()` and applied by `RunState`:

| Mode | Clock | Run duration | Time scale | Storm | Density | Elite odds | Reward | Hostiles | Loot |
|---|---|---|---|---|---|---|---|---|---|
| Normal | 18:00 | 1,080 s | 1.0x | difficulty default | 1.0x | +0 | 1.0x | +0 | +0 |
| Quick | 09:00 | 1,080 s | **2.0x** | difficulty default | 1.0x | +0 | 1.0x | +0 | +0 |
| Blackout | 18:00 | 1,080 s | 1.0x | difficulty default | 1.0x | +0 | 1.15x | +0 | +10% |
| Gauntlet | 14:00 | **840 s** | 1.0x | **45% fraction** | 1.2x | +10% | 1.35x | +8 | +0 |
| Onslaught | 18:00 | 1,080 s | 1.0x | difficulty default | 1.35x | +20% | 1.5x | +12 | +5% |

- The mode also drives start time of day (Blackout `0.94`) and the run-duration denominator used by the
  timer, storm, safe radius, world-event windows, the reinforcement director and the exfil hold. Quick
  compresses the run clock, storm, exfil hold, event timings and director intervals; movement and combat
  stay real-time.
- `tutorial` is a runtime-only, non-selectable mode (see §10), not part of the five authored modes.
- Mode identity (name, tag, clock) is surfaced in Quick Deploy, the Hub, the loading cinema, the HUD
  timer caption and the results screen.

**Where.** `features/content/content_library.gd` (`_game_modes`), `autoload/run_state.gd`
(`_resolve_mode`, `start_run`, `get_run_duration`, mode start time, per-mode helpers),
`autoload/content_db.gd` (`get_game_modes`, `get_selectable_game_mode_ids`), Quick Deploy/Hub/results
screens.

**Verified.** `progression_test` (786/786) asserts the mode math exactly: Normal 1080 s at 1x, Quick
1080 s at 2x, Blackout start_time 0.94 with reward/loot bonuses, Gauntlet 840 s with a 0.45 storm
fraction, Onslaught 1.35 density / +0.20 elite / 1.5 reward / +12 hostile budget. `integration_test`
asserts the run identity and HUD snapshot carry map/mode/planet/weather/clock.

### 12. Contracts and world events

**Why.** 0.1.0 had six single-stage contracts and twelve events with two scheduled per run. Staged
contracts give a run an arc; more events make each drop less predictable without adding bespoke content.

**What.**

- **13 contracts** — seven classic (`salvage_sweep`, `relay_sabotage`, `headhunt`, `rescue`, `survey`,
  `vault_breach`, `black_box`) and six staged operations (`vault_descent`, `relay_chain`,
  `tidal_survey`, `beacon_hunt`, `whiteout_run`, `sovereign_hunt`). `ContractData` gained `icon`,
  `color`, and an optional `stages` array (`{title, type, count, label}`); valid stage types are
  `cache`, `relay`, `hunt`, `survey`, `rescue`, `vault`, `dungeon` and `dungeon_boss`. Deployment builds
  staged sites and advances the stage counter; `ContentDB` validates stage types and counts.
- **20 weighted world events**, **three scheduled per run** at run-relative windows scaled by
  `RunState.get_run_duration()`: supply drop, wandering elite, faction skirmish, rift surge, black-market
  drone, cache beacon, lost caravan, jammer field, sudden fog, Bloom spawn, supply convoy, rift echo,
  meteor strike, rift cyclone, toxic drift, whiteout, scavenger convoy, bounty broker, distress beacon and
  collapse tremor. Supply/convoy events create interactable sites; forced-weather events call
  `WeatherSystem.force_weather()`; others add elite/boss waves, Rift Mods, marked bounties or pull the
  storm clock forward. All paths null-check player/world and emit
  `EventBus.world_event(title, description, icon, color)`.
- Four timed endgame pressure events at 58/72/86/94% of the run add hunter packs, rift incursions,
  collapse surges and a final stand (including a random boss at high difficulty).
- The HUD turns events into a **Reach Event** banner (icon, title, wrapped description, colour, queued
  up to 4, about 7 s hold, reduce-motion aware); the Codex documents them under Operations.

**Where.** `features/content/content_library.gd` (`_contracts`, `_world_events`),
`features/content/contract_data.gd`, `autoload/content_db.gd`, `features/run/deployment.gd`
(`_setup_staged_contract`, `_advance_contract_stage`, `_schedule_world_events`,
`_trigger_world_event`), `ui/hud/hud_root.gd`, `ui/screens/codex.gd`.

**Verified.** `integration_test` (118/118) exercises the expanded content counts, every one of the 20
world-event effect paths through the real deployment path, staged contract advancement, objective
interaction, exfil request/cancel/complete, and the four endgame event definitions. `progression_test`
asserts 13 contracts, 20 events and 5 modes with their fields. The UI suite asserts the Reach Event banner
appears after `EventBus.world_event`.

### 13. Enemies

**Why.** The 0.1.0 roster (14 base + 6 elites + 3 bosses) could not cover five planets with distinct
hazards; Cinder-4, Thalassa-2 and Nyx-12 needed natives, and the boss roster needed a body for every
dungeon theme.

**What.** **37 enemy entries**: 20 base archetypes, 11 elites, 6 bosses.

| Faction | Base | Elites | Bosses | Total |
|---|---|---|---|---|
| Ashen | 7 | 4 | 1 (Cinder Titan) | 12 |
| Bloom | 7 | 4 | 2 (Bloomheart, Leviathan) | 13 |
| Choir | 6 | 3 | 3 (The Warden, Rift Colossus, Hollow Sovereign) | 12 |
| **Total** | **20** | **11** | **6** | **37** |

- New base natives: Cinder Husk, Magma Brute (Ashen), Brine Lurker, Reef Stalker (Bloom), Tide Sentinel,
  Void Wisp (Choir). New elites: Caldera Warlord, Abyss Matriarch, Ashen Ironjaw, Bloom Thornmatron,
  Choir Signal Warden. New bosses: Cinder Titan, Leviathan, Hollow Sovereign (three phases each).
- `EnemyData` gained `habitat` (land/water/lava/any) and a `swimmer`/`drone` style; `EnemyAgent` reads
  the weather vision multiplier (2 s timer), lava/deep-water slow and damage (1 s timer) and environment
  hazards. Behaviour, telegraphs, affixes, boss phases and volatile death are unchanged from 0.1.0.

**Where.** `features/content/content_library.gd` (`_enemies`), `features/content/enemy_data.gd`,
`features/ai/enemy_agent.gd`, `autoload/content_db.gd` (`get_elite_enemies`, `get_boss_enemies`,
mix validation), `features/run/deployment.gd` (roster, elite pools, boss registration).

**Verified.** `ai_test` (134/134) covers the spawn contract, vision/LOS/hearing, FSM, telegraphs, real
damage, statuses, elite affixes, boss phases and kill recording. `progression_test` asserts the 37-entry
mix and the new ids/fields. `integration_test` asserts head health bars track real damage and a real
weapon kill leaves the run active.

### 14. Weapons, abilities and perks

**Why.** More planets and modes multiply build variety expectations; the 0.1.0 arsenal (10 weapons,
16 abilities, 16 perks) left several archetypes empty (flamer, heavy LMG, shock shotgun).

**What.**

- **16 weapons** — added Ember Thrower (flamer), Tide Carbine, Quarry HMG, Mirage DMR, Scatter Arc and
  Ripper SMG on top of the 0.1.0 ten, with a procedural flamer viewmodel style. Four slots stay: two
  primaries, sidearm, issued Combat Knife.
- **24 abilities** = 20 actives + 4 ultimates. Added actives: Ember Ward, Tide Step, Bulwark Stance,
  Quake Step, Smoke Veil, Repair Drone, Mine Layer, Zip Line (all implemented in the dispatcher and
  exercised headlessly). Ultimates unchanged: Iron Tide, Ghost Protocol, Siegeworks, Hyperfocus.
- **24 perks** across four disciplines (eight added), 12 Rift Mods, 8 mutators, 3 grenade definitions
  (frag in play; shock/veil authored but not selectable — see §21), 10 gear templates, 4 armor sets,
  6 suits, 8 dyes, 8 weapon skins, 3 pet shells, 8 affixes.

**Where.** `features/content/content_library.gd`, `features/weapons/weapon_controller.gd`,
`weapon_model_builder.gd`, `features/abilities/ability_manager.gd`, `ability_deployable.gd` (mine mode),
`features/combat/stat_keys.gd`.

**Verified.** `progression_test` (786/786) asserts all 16 weapon viewmodels plus the knife, all 24
ability effects, per-weapon ADS zoom, mechanic/perk gates and XP math. `integration_test` fires a real
charge shot through the hitscan/weakpoint pipeline, equips/swings the knife, and executes all eight new
ability effects through the real dispatcher. `shooting` smoke exercises the full production scene graph.

### 15. Squad and pets

**Why.** The squad content did not need new members in 0.2.0 — it needed to survive the new spaces and
read as characters in the new UI.

**What.** Content is unchanged: **4 recruitable Wardens** (Mara Voss, Rook, Irie Sol, Toma Nix; 2 active)
and **3 Driftlings** (Mote, Cinder, Pip), with the same commands, downed/revive paths, ranks and shells.
Changes in 0.2.0:

- `CompanionManager.set_suspended()` freezes squad AI and parks members at the dungeon entrance while the
  player is under the Reach, then reforms the squad on exit. The manager never deletes the squad.
- Squad UI rebuilt around Warden portraits (`UIAllyPortrait`), Driftling art (`UIPetArt`, including
  per-shell cosmetic previews) and medallion stat blocks; the Locker previews pet shells without
  equipping them.
- Save fields already carried `active_allies`, `ally_ranks`, `active_pet`, `pet_ranks`; no schema change
  was needed for companions in v5.

**Where.** `features/companions/companion_manager.gd`, `features/run/deployment.gd` (enter/exit
suspension), `ui/screens/squad.gd`, `ui/screens/locker.gd`, `ui/components/{ally_portrait,pet_art}.gd`.

**Verified.** `companions_test` (78/78) covers all four Warden roles and all three Driftling roles,
commands, teleport catch-up, role abilities, downed -> revive, and the HUD squad payload. `dungeon_test`
asserts the suspension/restore path through Deployment.

### 16. Outpost layout v2

**Why.** 0.1.0 stored a diorama position table that the UI drew ad hoc; there was no validity contract,
so a save could describe overlaps or off-board modules and the screen had to tolerate it. The 0.2.0
diorama is a real object model, so the save had to describe it safely.

**What.**

- **8 modules x 3 tiers** on a versioned **8x8 board**. Authored plan (`ProfileState.BASE_LAYOUT`,
  version 2):

| Module | Top-left | Footprint |
|---|---|---|
| Foundry | (0, 0) | 2x2 |
| Armory | (3, 0) | 2x2 |
| Signal Array | (6, 0) | 2x2 |
| Infirmary | (0, 3) | 2x2 |
| Command Nexus | (3, 2) | 3x3 |
| Reactor | (6, 2) | 2x3 |
| Barracks | (0, 6) | 3x2 |
| Drift Den | (3, 6) | 2x2 |

- `ProfileState.validate_base_layout()` returns a `PackedStringArray` of errors: all eight modules present,
  integer/Vector2i positions, footprints inside 0..7 on both axes, no overlapping `Rect2i`. `ensure_base_layout()`
  resets an invalid or stale payload to the authored plan and never touches module tiers, currency or
  inventory.
- `UIOutpostDiorama` draws the board, module structures (`UIModuleArt`, one code-drawn isometric building
  per module), tier pips, built/planned/road states and click-to-select hit rects; the Outpost screen adds
  a `LAYOUT v2` badge, module icons and detail cards. QA inspected it at 1600x900 and 1280x720.

**Where.** `autoload/profile_state.gd` (`BASE_LAYOUT`, `BASE_LAYOUT_VERSION`, `validate_base_layout`,
`ensure_base_layout`), `ui/components/outpost_diorama.gd`, `ui/components/module_art.gd`,
`ui/screens/outpost.gd`, `features/content/base_module_data.gd` (new `icon`).

**Verified.** `progression_test` (786/786) asserts `validate_base_layout()` is empty for all eight
modules, in-bounds and non-overlapping; the UI suite asserts diorama geometry (8 module rects inside the
board) and hit selection.

### 17. Save format v5 and migration

**Why.** The layout payload is authored data, not player data, but it is persisted; a versioned payload
lets the board be redesigned without corrupting progression. v5 is deliberately a layout-only migration.

**What.**

- Path `user://riftward_profile.json`, `SAVE_VERSION = 5`; settings live separately in
  `user://settings.cfg`. Top-level save fields: version, profile id/callsign/playtime, level/XP,
  attributes and points, discipline, ability loadout, skill ranks, salvage/cores, next UID, inventory,
  equipped slot->UID map, `base_modules`, `base_layout` + `base_layout_version`, active allies/pet, ranks,
  cosmetics, records (including `dungeons_entered` / `dungeons_cleared`), `last_difficulty`, `last_mode`,
  `last_map`, daily slot, `tutorial_done`, `last_run`.
- `base_layout` is stored as `{module_id: [x, y]}` on the 8x8 board; `base_layout_version` is 2.
- Migration ladder: **v5** resets `base_layout`/`base_layout_version` to the authored v2 plan and nothing
  else; **v4** (for older profiles) adds the second primary slot and makes the Sable Rail the default
  primary for profiles that still carry the original starter rifle; **v1–v3** get the v4 loadout
  migration before the v5 layout rebuild. 0.1.0 shipped save **v3**, so every 0.1.0 profile upgrades by
  running both steps on first launch and is re-saved at v5.
- Loading deep-fills missing fields from defaults (so older saves load with new fields at safe defaults),
  validates/clamps values (`last_mode` falls back to Normal, `last_map` to the difficulty's featured map),
  writes atomically (temp file then rename) with a `.bak` copy, and restores the backup if the primary
  file is unreadable. There is no mid-run save.

**Where.** `autoload/profile_state.gd` (`SAVE_VERSION`, `_defaults`, `_migrate_save`,
`_migrate_loadout_v4`, `validate_base_layout`, `ensure_base_layout`, `_load_from`).

**Verified.** `progression_test` (786/786) asserts the v4 -> v5 stale-layout migration preserves module
tiers, currency and inventory, and that a synthetic v4 profile loads with the current save version and
layout version. `integration_test` asserts a loaded profile reports current save/layout versions.

### 18. UI expansion

**Why.** 0.1.0 was icon-first but still text-row-shaped: items, planets, maps, people and structures were
described rather than shown. The redesign makes the interface image-first and puts explanations in
tooltips, then adds the operational screens a bigger game needs (preflight, codex, display settings).

#### 18.1 Deployment loading cinema

Replaces the 0.1.0 "title + bar + rotating field notes" cover with a four-act drop feed driven by a
`LoadingBrief` payload resolved before `RunState.start_run()`:

| Act | Screen | Content |
|---|---|---|
| 01 | THREAT SIGNATURE | Code-drawn boss dossier: faction, class label, phase count, integrity/shield bars, quote and counter-intel line; boss chosen from the planet's dungeon roster by run seed |
| 02 | RIFT BREACH | The Reach tears open over the drop zone, tinted by the selected map/planet sky |
| 03 | DROP DESCENT | First-person pod footage with telemetry and an altitude tape |
| 04 | TOUCHDOWN | Ramp-down beat and the operations rail going live |

- All shots are deterministic, asset-free `UICinemaShot` subclasses (`CinemaBossShot`, `CinemaRiftShot`,
  `CinemaDescentShot`, `CinemaTouchdownShot`) plus a `CinemaFilmOverlay` presentation layer (letterbox,
  legibility scrims, vignette, scanlines, light grain).
- Act timing is progress-aware: each act has a minimum dwell and a progress gate, with a hard cap
  (`ACT_HARD_CAP = 2.6 s`) so a stalled terrain bake never freezes the feed. The live progress bar, step
  label and field-note rail stay visible and are the only contract gameplay depends on.
- Space/Enter or the rail button skips to a static briefing; reduced motion opens the same static
  briefing. Both paths are testable without a rendered 3D scene.
- Captures: `ui/_screenshots/18_loading_breach.png`, `19_loading_descent.png`,
  `20_loading_touchdown.png`, `21_loading_leviathan.png`.

**Where.** `ui/screens/loading.gd`, `ui/loading/loading_brief.gd`, `ui/components/cinema_*.gd`,
`autoload/app.gd` (brief construction), `ui/ui_root.gd` (show/update/hide loading).

**Verified.** The UI suite (130/130) asserts cinema instantiation, four acts, operation/boss brief
resolution, progress acceptance, the boss reveal, the rift cut, skip collapse and hide; the four
drop-feed captures document the acts.

#### 18.2 Visual-first screens

| Screen | 0.2.0 change |
|---|---|
| Quick Deploy | Preflight scopes difficulty, planet, map, game mode and weather forecast beside a deployment panel with contract/target intel; planet portraits and map thumbnails instead of name rows |
| Main menu | Oversized Quick Deploy CTA, compact Enter Hub secondary action, Field Training entry, remembered drop strip with map thumbnail + planet medallion + mode clock |
| Hub | Same planet/map/mode selection as preflight plus contract board, mutators and medallion contract rows |
| Loadout | Weapon/gear cards with `UIItemArt` silhouettes (knife included); stats and explanations in tooltips |
| Locker | Compact `UIWardenPreview` figures, item art, medallion cosmetic rows and pet-shell previews via `UIPetArt` shell overrides |
| Skills | Discipline and ability medallions, perk tiers, ultimate card, attribute rows |
| Squad | Warden portraits (`UIAllyPortrait`), Driftling art (`UIPetArt`), medallion stat blocks, command/assignment rows |
| Outpost | 8x8 diorama, module art, tier pips, `LAYOUT v2` badge, module list/detail cards |
| Codex | Nine tabs; new Planets, Weather, Operations and Dungeons tabs with portraits, thumbnails, medallions and target rosters |
| Settings | Display card with eight display controls plus a live monitor summary (below) |
| Results | Map/mode identity, mode clock, run duration, XP breakdown and level-up summary |

- Reusable code-drawn art components: `UIIconMedallion`, `UIItemArt`, `UIPlanetPortrait`,
  `UIMapThumbnail`, `UIAllyPortrait`, `UIPetArt`, `UIModuleArt`, plus compact `UIWardenPreview` and the
  cinema components. `UIFactory` gained the matching helpers (`medallion`, `icon_tab`, `icon_value`,
  `pips`, `empty_state`, `hint_row`, `key_hint`, `toast_row`, `animate_children`, ...).
- All screens are container-driven and reflow down to 1280x720; the outpost diorama keeps a 560 px minimum
  width and the module list scrolls.

**Where.** `ui/screens/*.gd`, `ui/components/*.gd`, `ui/ui_factory.gd`, `ui/ui_screen.gd`,
`ui/ui_icons.gd`, `ui/theme`.

**Verified.** The UI suite (130/130) covers registration/navigation for all screens, art component
payloads, preflight data (5 planets / 12 maps / 5 modes / 4 difficulties), settings display controls,
diorama geometry and hit selection, and the screen captures were visually inspected.

#### 18.3 HUD

- **Reach Event banner** above the subtitle rail: icon, title, wrapped description and colour from
  `EventBus.world_event`, queued (`WORLD_EVENT_MAX_QUEUE = 4`), auto-hiding after about 7 s
  (`WORLD_EVENT_HOLD = 7.0`) and reduce-motion aware; exposed to tests as `get_world_event_panel()`.
- **Weather icon + local clock** under the run timer, so time of day and conditions are always readable
  without competing with the timer.
- **Training card** replaces the objective stack during Field Training (stage title, copy, key hint,
  progress bar).
- **Dungeon banner** replaces the minimap while underground; **hazard overlay** tints the screen edges for
  water/lava; the existing minimap, tactical map, scope, FIELD OPS tracker, boss bar, radio subtitles and
  notification cap are unchanged.
- HUD state still comes from signals plus a 10 Hz snapshot fallback; the minimap polls at 5 Hz.

**Where.** `ui/hud/hud_root.gd`, `autoload/event_bus.gd` (`world_event`, `dungeon_state_changed`,
`tutorial_stage_changed`, `hazard_state_changed`).

**Verified.** The UI suite binds minimap, tactical map, scope, aim sight, mission trackers, weather/clock
chip, training card, dungeon banner, hazard overlay and the Reach Event banner after `EventBus.world_event`.

#### 18.4 Display settings

Settings -> Display exposes (rows carry `meta("setting_key")` and `get_control`/`get_option_control`
accessors for tests):

| Control | Values / range |
|---|---|
| Window mode | Windowed, Borderless Fullscreen, Fullscreen |
| Resolution | Native + standard 16:9/16:10 resolutions (clamped to the monitor) |
| V-Sync | on/off |
| Render scale | 0.50–1.00 in 0.05 steps |
| Anti-aliasing | Off, FXAA, MSAA 2x, MSAA 4x, TAA |
| Frame rate limit | Unlimited, 30, 60, 120, 144 |
| Quality preset | Low, Medium, High, Ultra (shadow atlas, LOD, debanding) |
| Interface scale | 0.80–1.40 in 0.05 steps |
| Monitor summary | live "W x H - Hz" line |

`App.apply_display_settings()` is the single display writer; every window mutation is guarded by
`DisplayServer.get_name() != "headless"`, so headless suites and CI apply settings without errors. Values
persist to `user://settings.cfg`.

**Where.** `ui/components/settings_panel.gd`, `ui/screens/settings_screen.gd`, `autoload/app.gd`
(`get_resolution_options`, `get_window_mode_options`, `get_aa_options`, `get_fps_options`,
`get_display_summary`, `apply_display_settings`).

**Verified.** `progression_test` asserts the display option getters and headless `apply_display_settings()`
with settings restored; the UI suite asserts the display card controls and option lists.

#### 18.5 Icons

- **29 new SVG line icons** since 0.1.0: the 17-icon frontier set (planet, moon, dungeon, lava, water,
  weather sun/rain/storm/fog/ash, ember, wave, smoke, drone, mine, grapple, training) and the 12-icon UI
  expansion set (weather snow/ion/void/meteor/toxic, Ashen/Bloom/Choir faction sigils and Vanguard/
  Infiltrator/Engineer/Pathfinder discipline sigils). Icons are authored in-repo, imported as textures and
  referenced by `StringName`.
- The icon catalog test resolves every icon referenced by the UI, including all 12 expansion icons
  (148/148 checks, including duplicate-listing checks).

**Where.** `assets/icons/`, `ui/ui_icons.gd`, `ui/screens/codex.gd` (faction/stage icon maps).

**Verified.** `ui_icons_test` 148/148.

### 19. Audio

**Why.** 0.2.0 adds systems (dungeons, training, loading) but not an audio direction change; the
procedural bank already covers weapons, impacts, abilities, UI, footsteps and storm.

**What.** The audio stack is unchanged: `AudioDirector` synthesises SFX at runtime with 2D/3D pools, a
looping ambient music bed and volume buses; there are no external audio assets. New systems reuse the
existing cues rather than adding assets — the dungeon entrance plays the door cue, training targets play
the hit cue and the tutorial director plays the UI confirm cue. Weather adds no audio layer in this
release.

**Where.** `autoload/audio_director.gd` (unchanged), `features/dungeon/dungeon_entrance.gd`,
`features/tutorial/{training_target,tutorial_director}.gd`.

**Verified.** No new audio assets or mixer changes; the editor import set contains no audio files, and the
boot/UI suites exercise the standard cues without errors.

### 20. Tooling, tests and documentation

**Why.** A feature set this wide needs its own regression surface; the 0.1.0 ten-suite gate did not cover
dungeons, onboarding, planet variants or icon coverage.

**What.**

- **Four new suites**: `tests/dungeon_test.tscn`, `tests/tutorial_test.tscn`,
  `tests/world_variants_test.tscn`, `tests/ui_icons_test.gd` (14 total).
- `tests/run_all.ps1` now fails on engine `ERROR:` lines in addition to `SCRIPT ERROR` and missing PASS
  markers, redirects Godot's `user://` root when `%APPDATA%` is not writable, and writes one log pair per
  suite to `tests/artifacts/logs/`. It supports `-Quick` for the fast subset.
- `.gitignore` excludes `tests/artifacts/*.txt`, `tests/.appdata/` and local agent-team session state, so
  test noise never enters history.
- Release tooling is unchanged and still packaged as `BUILD.cmd` /
  `tools/build_export.ps1` (Windows Desktop preset, x86_64, `.pck` alongside the executable, docs/tests
  filtered out of the pack) with `tools/find_godot.ps1`, `tools/play.ps1`, `tools/package_release.ps1`.
- Documentation: [README.md](../README.md), [docs/FEATURES.md](FEATURES.md), [docs/DESIGN.md](DESIGN.md),
  [docs/TECHNICAL.md](TECHNICAL.md), [docs/QA_REPORT.md](QA_REPORT.md), [docs/BUILD_PLAN.md](BUILD_PLAN.md),
  [docs/GITHUB.md](GITHUB.md), [docs/ITCH_PAGE.md](ITCH_PAGE.md), [docs/STORE_PAGE.md](STORE_PAGE.md),
  [docs/PLAYER_README.txt](PLAYER_README.txt) and [features/world/WORLD_API.md](../features/world/WORLD_API.md)
  updated for the new counts and systems. New in this release: this log, [CHANGELOG.md](../CHANGELOG.md)
  and [docs/releases/v0.2.0.md](releases/v0.2.0.md).

**Verified.** 14/14 suites pass (see §3); each suite's output is retained under `tests/artifacts/logs/` and
the aggregate runner prints `All 14 test suites passed.`

### 21. Known issues and limitations

1. **No installer, no auto-updater.** The Windows build is `release/RIFTWARD-win64.zip` (exe + pck,
   checksummed); rebuilding it needs Godot 4.7.2 export templates on the build machine. Players update by
   replacing the folder; the save folder is untouched.
2. **Unsigned executable.** Windows SmartScreen may warn on first launch (More info -> Run anyway); some
   corporate antivirus quarantines it.
3. **No mid-run save.** Quitting during a deployment abandons that run by design; profile saves happen at
   hub/results transitions and explicit upgrade actions.
4. **Minimap has no fog of war.** It is north-up, shows live hostiles in range and reveals POI icons after
   discovery; there is no permanent exploration history.
5. **Grenade selection is partial.** Frag/shock/veil definitions exist, but quick-throw uses frag only.
6. **Outpost placement is upgrade-driven.** Eight modules, three tiers and the versioned 8x8 layout work;
   freeform drag placement is not exposed.
7. **No weapon mastery tracks.** Weapons have rarity/affixes but no per-weapon XP or mastery progression.
8. **No manual weather picker.** Weather is seeded by planet/preset and can be forced by events and modes,
   but Quick Deploy has no weather selection.
9. **Performance evidence is informal.** No automated average/1% low FPS capture exists; the target is
   60 FPS at 1080p on a mid-range GPU and the windowed D3D12 captures run comfortably. Display settings
   (render scale, AA, frame cap, quality preset) are the player-facing mitigation. Formal profiling at
   1440p/ultrawide is on the backlog.
10. **Test-harness quirks.** PowerShell's `Start-Process` can report null exit codes in this environment,
    so `tests/run_all.ps1` gates on PASS markers and error lines instead; a few ObjectDB instances are
    reported when suites force-quit with active async effects (shutdown artifacts, not gameplay leaks).
    Recast prints benign precision warnings for agent height/climb/radius because they snap to voxel
    units.
11. **Viewmodel polish.** The procedural first-person viewmodel is intentionally blocky and can obscure the
    lower-right world edge at the default aspect; it is the least polished visual element.
12. **English only.** No voice acting or localisation; radio is subtitles.
13. **No browser build.** A web version needs a port, not an export; see [docs/WEB_PORT.md](WEB_PORT.md).

Scope still considered PARTIAL or NOT DELIVERED is tracked honestly in
[docs/BUILD_PLAN.md](BUILD_PLAN.md) §2: grenade selection, freeform base placement and weapon mastery.

### 22. Upgrade and release instructions

#### For players upgrading from 0.1.0

1. Keep the save folder (`%APPDATA%\Godot\app_userdata\RIFTWARD`); it is not part of the download.
2. Replace the whole game folder with the 0.2.0 download; keep `RIFTWARD.exe` and `RIFTWARD.pck` together.
3. Launch normally. The 0.1.0 profile (save v3) upgrades on first load: the v4 loadout migration runs,
   then the v5 layout rebuild. The outpost layout is reset to the authored v2 plan while module tiers,
   currencies, inventory and records are preserved. A `.bak` copy of the previous save is kept.
4. Settings from `user://settings.cfg` are preserved; new display keys take their defaults.
5. If a save was hand-edited or corrupted, the loader falls back to the `.bak` copy, or creates a fresh
   profile if neither parses.

#### Cutting the release (maintainers)

1. Confirm the tree is the intended release: `tests\run_all.ps1` prints
   `All 14 test suites passed.` and `git status` shows only the release changes.
2. Commit the 0.2.0 tree:
   `git add -A` then `git commit -m "RIFTWARD 0.2.0 - second source release"`, then `git push`.
3. Tag and push: `git tag -a v0.2.0 -m "RIFTWARD 0.2.0 - second public build"` then
   `git push origin v0.2.0`.
4. Build the Windows export: `powershell -ExecutionPolicy Bypass -File tools/build_export.ps1 -Zip`
   (requires the matching 4.7.2 export templates). Verify `release/windows/RIFTWARD.exe` launches and
   `release/RIFTWARD-win64.zip` + `release/SHA256SUMS.txt` are fresh; smoke-check with
   `--shoot-smoke` and `--inventory-smoke`.
5. Create the GitHub Release from tag `v0.2.0`, title `RIFTWARD 0.2.0`, body from
   [docs/releases/v0.2.0.md](releases/v0.2.0.md); attach `release/RIFTWARD-win64.zip` and
   `release/SHA256SUMS.txt`. GitHub's "Source code (zip)" satisfies the GPL source distribution.
6. Update itch.io: upload the same zip (Windows, downloadable, not HTML), set Version to `0.2.0`, and
   keep the GPL source line on the page. `docs/PLAYER_README.txt` ships inside the zip as `README.txt`.
7. Do not commit build output: `build/`, `release/`, `.build/`, `.godot/` are ignored, and a committed
   executable would put a 100 MB+ blob in history.

#### Platform and distribution notes

- Windows 10/11 64-bit, DirectX 12 GPU, 4 GB RAM minimum, about 150 MB disk; keyboard/mouse with gamepad
  support.
- GPL-3.0-or-later: shipping a binary requires the matching tagged source to be available — the public
  repository at the `v0.2.0` tag is that source. Bundled Godot (MIT) and Sora/Inter/JetBrains Mono
  (SIL OFL 1.1) notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- This is a single-player, offline build: no co-op, PvP, online play or browser version.

---

## 0.1.0 — 2026-10-24

Tag `v0.1.0`, commit `cfcbdec`. The first public source release ("First Light"): a complete single-player
extraction vertical slice proving the core loop.

- **World**: one seeded 1.8 km x 1.8 km Meridian-9 frontier, three blended biomes, 16–20 POIs, 16–22
  roadside outbuildings, four sky/fog moods (one per difficulty), 8x8 terrain chunks and an async
  navmesh bake.
- **Run loop**: two modes (Normal 18 min, Quick 2x clock/9 min real time), four difficulty presets
  (Patrol/Contact/Breach/Collapse), six contracts, 12 world events (two per run), 75-second exfil hold,
  Collapse storm, death/downed/bleedout/self-revive and a results screen.
- **Content**: 14 base enemies + 6 elites + 3 bosses (23), 10 weapons with four slots (two primaries,
  sidearm, issued knife), 12 active abilities + 4 ultimates, 16 perks, 12 Rift Mods, 8 mutators,
  8 outpost modules x 3 tiers, 4 Warden companions (2 active), 3 Driftlings, 8 equipment slots,
  rarities/affixes/sets and cosmetics.
- **UI**: 13 data-driven screens plus HUD and a paused inventory overlay, icon-first theme and tooltips,
  minimap + M-key tactical map, FIELD OPS tracker, accessibility options, full key rebinding.
- **Save**: schema **v3** (`user://riftward_profile.json`); settings in `user://settings.cfg`.
- **Audio**: procedural SFX with 2D/3D pools and a looping ambient bed.
- **Verification**: ten headless suites (boot, shooting, inventory, integration, death, world, AI,
  companions, progression, UI), windowed D3D12 capture pass, Windows export.

Retro: the loop and the combat systems held up; the gaps were replay breadth (one planet mood, two
modes), no onboarding, no optional greed layer, sparse content counts and a text-row UI. 0.2.0 closes
those specifically — see the design intent in §4.

---

## Maintaining this log

- Add a new section per release at the top; keep 0.1.0-style retros short.
- Every number in a release section must be reproducible from `autoload/content_db.gd` (content counts),
  the suite logs under `tests/artifacts/logs/`, or `git diff`/`git status` against the previous tag.
- Record the verification evidence actually observed, including count changes during the cycle (as in §3)
  rather than silently rewriting history.
- Keep known issues honest: a limitation listed here is not a bug report, it is a scope statement.
- Update [CHANGELOG.md](../CHANGELOG.md) and the player-facing body in `docs/releases/` in the same
  change.
