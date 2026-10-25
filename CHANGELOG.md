# Changelog

All notable changes to RIFTWARD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project uses release
version numbers (`MAJOR.MINOR.PATCH`) without a public API-stability promise; RIFTWARD is a standalone
game application, not a library. The long-form engineering notes — design intent, verification evidence,
save migrations and upgrade instructions — live in [docs/DEVLOG.md](docs/DEVLOG.md). Player-facing
release bodies live in [docs/releases/](docs/releases/).

## [Unreleased]

### Fixed

- The README **headless-tests** badge is restored and now points at a workflow that exists instead of a
  URL that 404s. `.github/workflows/tests.yml` runs every suite listed in `tests/suites.json` on Linux —
  one job per suite, then one stable `headless-tests gate` check — and `tests/run_all.ps1` reads the same
  manifest, so the badge and the local gate cannot drift apart again.

## [0.2.0] - 2026-10-25

Second public source release: the **Frontier Update** plus the **UI/content expansion**. Adds five
planets, weather and day/night, water and lava, enterable interiors, under-reach dungeons, Field Training,
five run modes, staged contracts, 20 world events, 14 new enemies, six new weapons, eight new abilities,
eight new perks, the outpost layout v2 diorama, save format v5, a four-act deployment loading cinema, a
visual-first UI expansion, display settings and 29 new SVG icons. Full details:
[docs/DEVLOG.md#020--2026-10-25](docs/DEVLOG.md#020--2026-10-25). Player notes:
[docs/releases/v0.2.0.md](docs/releases/v0.2.0.md).

### Added

**World and planets**

- Five planets with distinct biome names, terrain tints, day lengths, sky keyframes, weather pools, fluid
  rules and dungeon themes: Meridian-9 (The Reach), Cinder-4 (The Ember Shelf), Thalassa-2 (The Drowned
  Shelf), Frost-9 (The Long Winter) and Nyx-12 (The Silent Fold).
- Twelve selectable map presets — Verdant Verge, Ashen Shelf, Glass Expanse, Rift Scar, Cinder Caldera,
  Ember Reach, Tidal Shelf, Brine Expanse, Glacier Shelf, White Expanse, Null Steppe and Echo Basin.
  Each preset carries a seed salt, biome emphasis, start time, scatter/roadside/extra-POI budgets,
  environment overrides and an optional preset-level weather pool.
- Explicit map override for a deployment: `RunState.start_run()` accepts a `map_id` while the
  difficulty's featured map remains the default; Quick Deploy and the Hub expose the selection.
- 17–21 points of interest per run (14 authored landmark kits plus 3 exfil pads and 2–4 preset extras),
  16–22 roadside outbuildings and 5,000–9,000 MultiMesh scatter instances.
- Enterable interiors on seven POI types, including a full derelict-freighter interior, with 4.2 m
  doorways, 3.4 m+ ceilings, interior lights and loot/enemy anchors that the navmesh bakes through.
- Water and lava basins carved into low ground with animated surfaces (`water.gdshader`,
  `lava.gdshader`), shoreline props, tactical-map tinting and analytic gameplay queries: buoyancy and swim
  drag in water, heat damage scaled by `HAZARD_RESIST` in lava, plus habitat-aware enemy spawning.
- 18 weather states (Clear, Overcast, Rain, Squall, Dust Front, Ashfall, Ember Storm, Heat Haze, Rift
  Storm, Fog Front, Spore Drift, Rift Winds, Ion Tempest, Meteor Shower, Toxic Squall, Glacier Front,
  Whiteout, Rift Cyclone) with fog/sky/sun transitions, particles, lightning, dwell/transition timing and
  vision/move modifiers (vision multiplier from 1.00 down to 0.30).
- Per-planet day/night cycle: four sky keyframes (night, dawn, day, dusk), a moving sun, stars, a night
  headlamp and HUD weather/clock readouts. Blackout runs start late at night (0.94).
- Environment director as the single writer for sky, sun, fill light, fog and lightning, including an
  indoor override used by dungeons.

**Under-reach dungeons**

- Three themed procedural dungeon kits — Rift Vault, Ashen Mine and Choir Catacomb — with seeded 3x3
  room graphs, 5–9 rooms, corridors, bulkheads, a boss chamber, room packs, an elite guard, 2–4 loot
  caches and a private baked navmesh.
- 2–3 dungeon entrances per run, pre-baked during loading and placed as interactable hatches at vault,
  choir, stockade, colony and freighter POIs. Entry suspends the squad at the entrance and switches the
  environment indoors; the storm pauses, the run clock does not and exfil is unavailable underground.
- Dungeon clears bank profile records and can satisfy `dungeon` / `dungeon_boss` staged contract
  objectives.

**Field Training**

- Five-stage guided onboarding run for new profiles: move/look, aim/fire, field ability, recover salvage
  and exfil. A HUD training card shows stage title, copy, key hints and live progress.
- Pause offers **Skip Training**; the main menu can replay it at any time. Completion persists
  `tutorial_done`, grants a small starter reward and never counts as a deployment or death.

**Run modes**

- Five selectable modes layered on the four difficulties: Normal, Quick (2x clock), Blackout (night
  insertion, 1.15x reward, +10% loot), Gauntlet (14-minute clock, 45% storm fraction, 1.2x density,
  +10% elites, 1.35x reward, +8 hostiles) and Onslaught (1.35x density, +20% elites, 1.5x reward,
  +12 hostiles, +5% loot).
- Mode drives run duration, time scale, start time of day, storm timing, density, elite odds, reward,
  hostile budget, loot bonus, world-event windows, reinforcement director and exfil hold.
- Mode identity shown in Quick Deploy, the Hub, the loading cinema, the HUD timer caption and results.

**Contracts and world events**

- 13 contracts: seven classic (Salvage Sweep, Relay Sabotage, Headhunt, Rescue Signal, Anomaly Survey,
  Vault Breach, Black Box Recovery) and six staged operations (Vault Descent, Relay Chain, Tidal Survey,
  Beacon Hunt, Whiteout Run, Sovereign Hunt) with `icon`, `color` and optional multi-stage `stages`.
- 20 weighted world events with three scheduled per run at run-relative windows scaled to the run
  duration; supply/convoy events create interactable sites, forced-weather events pin weather, others add
  elite/boss waves, Rift Mods, bounties or storm pressure.
- **Reach Event** HUD banner (icon, title, wrapped description, colour), queued up to four entries,
  auto-hiding after about 7 seconds and reduce-motion aware.
- Four timed endgame pressure events at 58/72/86/94% of the run, including a final stand that can field a
  random boss at high difficulty.

**Enemies**

- 37 enemy entries: 20 base archetypes, 11 elites and 6 bosses. New base natives: Cinder Husk, Magma
  Brute (Ashen), Brine Lurker, Reef Stalker (Bloom), Tide Sentinel and Void Wisp (Choir). New elites:
  Caldera Warlord, Abyss Matriarch, Ashen Ironjaw, Bloom Thornmatron and Choir Signal Warden. New bosses:
  Cinder Titan, Leviathan and Hollow Sovereign (three phases each).
- `EnemyData.habitat` (land/water/lava/any) and new swimmer/drone styles; enemies react to weather vision
  loss, lava/deep-water slow and hazard damage.

**Weapons, abilities and progression**

- 16 weapons total; added Ember Thrower (flamer, with a procedural flamer viewmodel), Tide Carbine,
  Quarry HMG, Mirage DMR, Scatter Arc and Ripper SMG.
- 24 abilities (20 actives + 4 ultimates); added Ember Ward, Tide Step, Bulwark Stance, Quake Step, Smoke
  Veil, Repair Drone, Mine Layer and Zip Line.
- 24 passive perks across four disciplines (eight added), 12 Rift Mods, 8 mutators and 8 affixes.

**Outpost and save**

- Outpost **layout v2**: a versioned 8x8 board, 8 modules with footprints (Foundry, Armory, Signal
  Array, Infirmary, Command Nexus, Reactor, Barracks, Drift Den), tier pips, built/planned/road states and
  a clickable isometric diorama with module icons.
- `ProfileState.validate_base_layout()` / `ensure_base_layout()` reject empty, off-board, non-integer or
  overlapping layouts and rebuild the authored plan without touching tiers, currency or inventory.
- Save format **v5** adds `base_layout` + `base_layout_version` (2); v4 -> v5 and 0.1.0's v3 -> v5
  migrations are documented in [docs/DEVLOG.md#17-save-format-v5-and-migration](docs/DEVLOG.md#17-save-format-v5-and-migration).
- `CompanionManager.set_suspended()` parks and restores the squad around under-reach dungeons.

**UI**

- **Deployment loading cinema**: a four-act drop feed (Threat Signature boss dossier, Rift Breach, Drop
  Descent, Touchdown) with a cinematic film overlay, deterministic code-drawn shots, a boss picked from
  the planet's roster by run seed, progress-aware act timing, skip and reduced-motion static briefing.
- Visual-first screens built on reusable code-drawn art (`UIIconMedallion`, `UIItemArt`,
  `UIPlanetPortrait`, `UIMapThumbnail`, `UIAllyPortrait`, `UIPetArt`, `UIModuleArt`, compact
  `UIWardenPreview`): Quick Deploy preflight with planet portraits/map thumbnails, image-first Loadout,
  Locker, Skills, Squad and Outpost, and a Codex with four new tabs (Planets, Weather, Operations,
  Dungeons).
- HUD additions: Reach Event banner, weather icon and local clock, Field Training card, under-reach
  banner and hazard screen tint.
- Display settings: window mode, resolution, V-Sync, render scale, anti-aliasing, frame-rate limit,
  quality preset and interface scale, applied live through `App.apply_display_settings()` and persisted.
- 29 new SVG line icons (17-icon frontier set plus a 12-icon expansion set of extreme-weather, faction and
  discipline sigils) and icon-tab glyphs.

**Tooling and tests**

- Four new headless suites: under-reach dungeons, Field Training, planet variants and the icon catalog
  (14 suites total).
- `tests/run_all.ps1` now fails on engine `ERROR:` lines as well as `SCRIPT ERROR`, redirects Godot's
  user data root when `%APPDATA%` is not writable, and supports a `-Quick` subset. Logs are written to
  `tests/artifacts/logs/`.
- `.gitignore` excludes test log artifacts, the redirected app-data root and local agent-team session
  state.

### Changed

- Project version is now `0.2.0` (`project.godot` `config/version`).
- The world is planet/preset driven instead of one biome set: generation consumes the enriched map preset
  (planet, weather definitions, merged fluid configuration) and mixes the preset seed salt into the world
  seed before terrain, POIs, scatter, sky and fluids are built.
- Content counts expanded: enemies 23 -> 37, weapons 10 -> 16, abilities 16 -> 24, perks 16 -> 24,
  contracts 6 -> 13, world events 12 -> 20 (2 -> 3 per run), modes 2 -> 5, maps 4 -> 12, planets 1 -> 5.
- Run identity and results carry map, planet, mode, mode clock, time scale and run duration alongside
  difficulty; `quick` mode compresses run clock, storm, exfil hold, event timings and director intervals.
- Player gains fluid handling (swim drag, `SWIM_SPEED`, lava heat damage scaled by `HAZARD_RESIST`, hazard
  tint signal) and a night headlamp; enemy behaviour gains weather perception and fluid/hazard reactions.
- Save schema advanced from v3 (0.1.0) to v5 with the versioned outpost layout; loading deep-fills new
  fields, validates `last_mode`/`last_map`, writes atomically and restores the `.bak` copy when the
  primary save is unreadable.
- Screens rebuilt around their objects (menu, hub, Quick Deploy, loadout, locker, skills, squad, outpost,
  codex, settings, results) and the paused inventory overlay kept its four weapon rows + satchel contract.
- Documentation rewritten for the expanded content and systems: README, FEATURES, DESIGN, TECHNICAL,
  QA_REPORT, BUILD_PLAN, GITHUB, ITCH_PAGE, STORE_PAGE, PLAYER_README and `features/world/WORLD_API.md`.
- `.gitignore` no longer treats test logs or local agent-team state as source.

### Fixed

- **Muzzle-flash crash on firing.** `WeaponController._muzzle_flash()` passed `get_tree().current_scene`
  (the plain-`Node` boot root) into `CombatVFX.muzzle_flash()`, which requires a `Node3D`; it now uses
  the player's effect parent (the Deployment actors root), matching the production scene graph rather than
  the test scene that masked the bug.
- **Projectile/grenade setup before entering the SceneTree.** `CombatProjectile.setup()` wrote
  `global_position` before `add_child()`, producing an `!is_inside_tree()` engine error and risking a
  grenade at the world origin; setup now stages the spawn origin and applies it in `_ready()`.
- Invalid or stale outpost layouts no longer risk an out-of-bounds overlap: `ensure_base_layout()` resets
  them to the authored v2 plan while preserving progression fields, and the save loader validates
  `last_mode`/`last_map` against authored ids with safe fallbacks.
- World-event paths null-check the player/world and cannot fire before the player exists; forced-weather
  events resolve against the preset's full weather definition set, so any authored state can be pinned on
  any map.

### Performance

- No regression in the world-generation budget on the reference machine (RTX 3060, D3D12): the completed
  world test reports about 1.3 s generation including a ~206 ms navigation bake, 3,144 nav polygons,
  5,802 MultiMesh scatter instances in 12 batches and a 5 ms validation pass, all well inside the suite
  timeout.
- The loading cinema is progress-aware with per-act minimum dwell and a hard cap, so a slow terrain bake
  never freezes the drop feed; the progress rail stays live throughout.
- Enemy weather/vision resolution runs on a 2 s timer and fluid/hazard resolution on a 1 s timer; minimap
  polling stays at 5 Hz and HUD snapshots at 10 Hz, so the new environmental systems add no per-frame
  scans to the enemy population.
- New player-facing performance controls: render scale, anti-aliasing, frame-rate limit and quality
  preset (shadow atlas/LOD/debanding), all applied live.
- Formal FPS profiling is still not automated; 60 FPS at 1080p remains the target and the windowed
  captures run comfortably.

### Documentation

- Added [docs/DEVLOG.md](docs/DEVLOG.md) (release-by-release engineering log), this
  [CHANGELOG.md](CHANGELOG.md) and [docs/releases/v0.2.0.md](docs/releases/v0.2.0.md) (GitHub Release
  body).
- Updated [README.md](README.md), [docs/FEATURES.md](docs/FEATURES.md), [docs/DESIGN.md](docs/DESIGN.md),
  [docs/TECHNICAL.md](docs/TECHNICAL.md), [docs/QA_REPORT.md](docs/QA_REPORT.md),
  [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md), [docs/GITHUB.md](docs/GITHUB.md),
  [docs/ITCH_PAGE.md](docs/ITCH_PAGE.md), [docs/STORE_PAGE.md](docs/STORE_PAGE.md),
  [docs/PLAYER_README.txt](docs/PLAYER_README.txt) and
  [features/world/WORLD_API.md](features/world/WORLD_API.md) for the new counts, content, systems and
  release version.
- Regenerated the capture set for the new UI: 21 images in `ui/_screenshots/` (17 numbered screen
  captures plus the four deployment drop-feed captures `18`–`21`), and 25 world-preview frames in
  `features/world/preview_shots/`.

### Testing

- **14/14 headless suites pass** (aggregate `powershell -ExecutionPolicy Bypass -File tests/run_all.ps1`,
  `All 14 test suites passed.`). Check counts: integration 118, death 9, dungeon 57, tutorial 20,
  world_variants 168, enemy AI 134, companions 78, progression/content 786, UI 130, icon catalog 148;
  boot, real-boot shooting/input, real-boot inventory and the world contract suite are marker/error-gated
  passes. Logs in `tests/artifacts/logs/`.
- New coverage in this release: all three dungeon themes and their encounter/nav/collision contracts,
  the five Field Training stages and persistence, planet/map/weather/day-night variants and fluid rules,
  the full icon catalog including the 12 expansion icons, outpost layout validation and the v4 -> v5
  migration, display-setting getters and headless application, the Reach Event banner, and the
  loading-cinema acts/boss brief/skip/reduced-motion paths.
- Protective real-boot regression coverage: `--shoot-smoke` and `--inventory-smoke` run through the
  production scene graph, and the aggregate runner fails on engine `ERROR:` lines.
- Windowed D3D12 pass captured 21 screen captures (17 numbered UI captures plus the four drop-feed acts)
  and 25 world-preview frames; the numbered UI captures were inspected, and no blocking script or runtime
  errors remain in the normal play path.
- Windows export rebuilt for the release and smoke-run (`README.txt` + `RIFTWARD.exe` + `RIFTWARD.pck`,
  checksummed in `release/SHA256SUMS.txt`).

## [0.1.0] - 2026-10-24

First public source release ("First Light"): a complete single-player extraction vertical slice.

### Added

- One seeded 1.8 km x 1.8 km Meridian-9 frontier with three blended biomes, 16–20 POIs, 16–22 roadside
  outbuildings, four sky/fog moods and an asynchronous navmesh bake over 8x8 terrain chunks.
- Two run modes (Normal 18 minutes; Quick 2x clock) and four difficulty presets
  (Patrol/Contact/Breach/Collapse) with featured maps, plus six contracts, 12 world events
  (two per run), a 75-second exfil hold with a descending Kestrel dropship, the Collapse storm, late-run
  reinforcement pressure and endgame events.
- Death, downed, bleedout and self-revive paths with a results screen for recovered items and profile
  rewards.
- 14 base enemies, 6 elites with affixes and 3 phased bosses across the Ashen, Bloom and Choir
  (23 entries); perception, cover/strafe behaviour, telegraphs, status effects and head health bars.
- 10 weapons across four slots (two primaries, sidearm, issued Combat Knife), 12 active abilities plus 4
  discipline ultimates, 16 passive perks, 12 Rift Mods, 8 mutators, loot caches, bounties and Rift
  Shrines.
- 4 recruitable Warden companions (2 active) and 3 Driftling pets with commands, downed/revive and
  ranks; 8 outpost modules over 3 tiers; eight equipment slots with rarities, affixes, sets and
  cosmetics; Warden levels 1–30.
- 13 data-driven UI screens plus HUD and a paused inventory overlay, icon-first theme and tooltips,
  minimap and M-key tactical map, FIELD OPS tracker, scope overlays, accessibility options and full key
  rebinding.
- Procedurally synthesised SFX with 2D/3D pools and a looping ambient music bed; no external audio
  assets.
- Save schema v3 (`user://riftward_profile.json`) and settings in `user://settings.cfg`.
- Ten headless test suites, windowed D3D12 capture pass and a standalone Windows export pipeline
  (`BUILD.cmd` / `tools/build_export.ps1`).

[Unreleased]: https://github.com/r48n34/riftward/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/r48n34/riftward/releases/tag/v0.2.0
[0.1.0]: https://github.com/r48n34/riftward/releases/tag/v0.1.0
