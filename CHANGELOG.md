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

## [0.3.0] - 2026-10-26

Third public source release: **Sound & Motion**. Procedural audio grows into a full sound-and-music
system, the frontier doubles its authored landmark vocabulary, rideables put the player on the ground and
in the air, authored cut-scenes carry the run from insertion to exfil, and seven CC0 Kenney packs give
impacts, UI, engines and particle effects real recorded/curated art — while all 3D geometry, materials
and shaders remain procedural. Full engineering notes:
[docs/DEVLOG.md#030--2026-10-26](docs/DEVLOG.md#030--2026-10-26).

### Added

**Audio Director 2.0**

- `autoload/audio_director.gd` is now a slim facade over three new feature modules:
  `features/audio/sfx_catalog.gd` (recipe table + PCM synthesis), `features/audio/music_director.gd`
  (cues, stems, crossfade, worker generation) and `features/audio/audio_packs.gd` (CC0 override
  resolver). Every pre-existing call site (`play_ui`, `play_sfx`, `play_3d`, `set_music_mood`,
  `set_bus_volume`, `get_stream`, `get_ui_sound_ids`) keeps working.
- **113 procedural SFX ids** (`AudioDirector.get_catalog().size() == 113`, recipes == 113 in the headless
  audio suite) covering UI, ten weapon families plus tails, reload stages, hits/headshots/kills,
  explosions, impacts, shields/armor, movement, ability/status effects, enemy vocals, bosses, weather,
  ambience beds, vehicles, doors, pickups, build/upgrade, storms, extraction and cut-scene stings.
- **Eight music cues plus `silent`** — `menu`, `hub`, `deploy`, `combat`, `boss`, `exfil`, `storm`,
  `results` — each an authored chord-progression/tempo/stem mix rendered procedurally, with layered
  pad/bass/pulse/percussion/texture stems, sample-continuous loop seams, a **two-player crossfade**
  (`AudioDirector.set_music_track(track, fade := 1.6)`) and a `music_track_changed` signal. Music and
  SFX sample generation runs on `WorkerThreadPool` tasks so the first frame only pays for bus/pool setup;
  headless runs skip background batches and generate ids on demand.
- **Bus routing**: `Music`, `SFX`, `UI`, `Ambience`, `Vehicles` plus an `AudioEffectLimiter` on `Master`
  (threshold -3 dB, ceiling -0.3 dB). 2D/3D one-shot pools, an ambience bed with crossfade
  (`set_ambience`), deterministic pitch/volume variation (`play_varied`), looped positional emitters
  (`play_loop_3d`), and a `get_stats()` diagnostics snapshot.
- Deployment owns a **music state machine** — exfil > boss > storm > combat > deploy — polled at 1 Hz;
  menus/hub/loading keep their moods and cut-scene beats can override the bed for a beat.
- **CC0 audio overrides**: `features/audio/audio_packs.gd` scans `res://assets/audio/cc0/**`, maps vendor
  filename stems onto the logical ids (25 ids mapped across 188 curated files), and silently falls back
  to the procedural synth for every missing/unimported file.

**World: 20 POI types and a detail pass**

- Seven new POI kits — `foundry_hall` (two-storey catwalk interior), `hab_cluster` (three enterable
  modules), `comms_array` (dish farm), `fuel_depot` (tank farm), `clinic_shelter`, `research_lab` and
  `water_works` — for **20 authored POI types** (13 original + 7 new). Each new kit authors 203–381
  primitives (measured by the world suite; gate is >= 60) and at least one enterable interior.
- Detail pass on all 13 original kits: interior furnishing, roof kits, pipes, cable trays, ladders,
  railings, vents, signage, awnings, solar panels, water tanks and tarps.
- **`POI_LAYOUT` grew to 21 authored entries** — 14 original layout entries plus the 7 new kits — and with
  the **3 exfil pads** a default run now holds **24 base POIs**, up to **28** with preset extras.
- **Enterable interiors**: 15 POIs on the base 24-POI layout (14 interior types, faction_camp twice); the
  world-test preset reports **16** (its extra faction camp) and four preset extras can reach 17. Interior
  spawn markers, `get_interior_pois()` and dungeon anchors are unchanged contracts.
- **POI-local MultiMesh clutter**: barrels, crates, pallets, cable spools and debris in 5 batches,
  20 pieces per POI (about **480 instances** at default density; 598 on the world-test preset), seeded
  per POI and kept out of road lanes via the new path-weight query.
- New `features/world/poi_specs.gd` (`class_name POISpecs`): a thread-safe, static **20-row data table**
  (`all()`, `has_spec()`, `get_spec()`, `validate()`, `TYPE_IDS`, `VEHICLES`, `HAZARDS`) with
  id/title/blurb/radius/pad/interior/loot_tier/garrison/hazard/biomes/vehicle/map_bias/codex_icon per
  type. Consumers (loot, rideables, Codex, tactical UI) read the table instead of hard-coding kit names.
- New public world getters: `get_loot_props()` (52 clutter anchors on the world-test preset),
  `get_clutter_piece_count()`, `get_path_weight_at()`, and `get_pois()` now carries `pad_radius`.
- World generation remains deterministic per seed (the world suite replays the seed and compares the
  complete POI layout).

**Content: cargo, loot tables and Codex**

- **10 new salvage cargo items** in `ContentLibrary._items()`: Field Ration (Common, 18), Beacon Flare
  (Common, 22), Alloy Plate (Uncommon, 28), Stim Injector (Uncommon, 32), Ammo Crate (Uncommon, 34),
  Repair Kit (Rare, 52), Fuel Cell (Rare, 56), Map Intel (Rare, 68), Relic Shard (Epic, 84) and Trophy
  Core (Prototype, 120), with heal/ammo/vehicle/salvage/relic effects and stack limits.
- **3 loot tables** — `poi_common`, `poi_rare`, `vehicle_stash` — authored in `ContentLibrary` and rolled
  by new `features/loot/loot_tables.gd`; `ContentDB` exposes `get_loot_table()`,
  `get_loot_table_ids()`, `get_loot_tables()`, `get_loot_table_item_ids()`, `roll_loot_table()`,
  `get_loot_table_for_poi()`, `get_loot_table_for_poi_dict()` and `build_loot_cache_payload()`.
  POI `loot_tier` from `POISpecs` selects the table (tiers 3–4 roll `poi_rare`), `vehicle_stash` is only
  selected explicitly, and unknown tables fall back to `poi_common`.
- **7 POI Codex records** (the new second-wave sites) and **5 rideable Codex records**, surfaced through
  `ContentDB.get_poi_codex()`/`get_poi_codex_entries()` and
  `get_rideable_codex()`/`get_rideable_codex_entries()`, plus new Codex tabs **Sites** and **Rideables**.
- Save format stays **v5** — the new content is catalog data, not new persistent fields.

**Rideables**

- Five rideable archetypes, all `CharacterBody3D` with a shared hand-rolled `VehiclePhysics` raycast
  suspension/steering/thrust model (no `VehicleBody3D`, no imported vehicle physics):
  - `rig` — Rift Rig: 2-seat ground car, 30 m/s, 340 hull, handbrake drift.
  - `hoverbike` — Vale Hoverbike: single-seat hover, 38 m/s, 180 hull, leans into turns.
  - `airplane` — Kestrel Wing: winged aircraft, 90 m/s with stall/takeoff airspeed.
  - `spaceship` — Void Skiff: VTOL, 60 m/s, altitude clamp and auto-dock.
  - `horse` — Warden Steed: gaits idle/walk/trot/canter/gallop with stamina and a bone-less gallop rig.
- Mount/dismount on **E** (interact), `KEY_T` whistles the nearest steed (`Player._try_summon_ride()`),
  weapons/abilities are locked while riding, the player keeps its own camera (reparented to the seat,
  yaw/pitch local) and a vehicle HUD panel shows speed dial, name/kind, hull bar, boost or stamina and
  gear/gait.
- `features/vehicles/vehicle_sites.gd` (`VehicleSites.build()`) places rideables deterministically per
  seed: one rig and one hoverbike at the drop zone, airplane/spaceship at their thematic POIs
  (`comms_array`/`foundry_hall`/`derelict_ship`), horse at `warden_outpost`, with seed-derived fallback
  placement if a POI is missing.
- New physics layer **11 "Vehicle"**; engine/wind loops through `AudioDirector.play_loop_3d`, gait-timed
  hoof/whinny audio for the horse, plus boost/brake/horn/impact/explosion SFX. Dungeon entry is blocked
  while riding and the exfil cut-scene force-dismounts first.

**Cut-scenes**

- New `features/cutscene/cutscene_director.gd` (`CutsceneDirector`) and
  `ui/screens/cinematic_overlay.gd` (`CinematicOverlay`) with **four registered cut-scenes**:
  - `deployment` — 6 s drop-feed recap card (the live feed remains the upgraded LoadingScreen).
  - `insertion` — 4 s in-world ramp-down / first-person rise / first radio traffic at run start.
  - `exfil` — 6 s pad approach, Kestrel ramp, lift-off and fade, played **before** the run ends.
  - `boss` — 4 s dossier + orbit confrontation shot, once per boss instance, skipped in training.
- Data-driven beat timelines (duration/camera rail-orbit-fixed/caption/radio/sfx/music/hud), a **12 s
  hard cap**, skip via Esc/Space/Enter and an on-screen button, a **1.2 s reduce-motion static card**
  that carries every caption, HUD chrome strip/restore, `EventBus.cinematic_state_changed`, and
  `App.play_cinematic()` / `App.is_cinematic()` ownership with a safe abort on teardown.
- The deployment loading cinema gains a fifth act — `ui/components/cinema_insertion_shot.gd`
  (`CinemaInsertionShot`) — and per-act audio stingers; the existing drop-feed acts are unchanged.

**CC0 art and FX**

- **Seven CC0 Kenney packs**, 267 curated files / 5.96 MiB, fetched and hashed by the new
  `tools/fetch_asset_packs.ps1`: Particle Pack (43), Prototype Textures (20), Interface Sounds (18),
  UI Audio (18), Sci-Fi Sounds (22), Impact Sounds (130) and Music Jingles (16), with per-pack
  `LICENSE.txt` + `MANIFEST.json` under `assets/cc0/<pack>/`. Provenance: [docs/ASSET_PACKS.md](docs/ASSET_PACKS.md).
- New `features/fx/particle_library.gd` (`ParticleLibrary`) with **14 logical effect ids** — `muzzle`,
  `impact_metal`, `impact_dirt`, `explosion`, `dust`, `exhaust`, `sparks`, `splash`, `smoke`, `rain`,
  `portal`, `scorch`, `flare`, `trail` — and a procedural soft-dot fallback when the pack is absent.
- `features/combat/combat_vfx.gd` now spawns real particle art for muzzle flashes, impacts and
  explosions (additive layer; primitives still render without the pack).

**Tests**

- `tests/suites.json` now lists **18 suites** — the 14 previous plus **audio**, **vehicles**,
  **cutscenes** and **assets**. New suites cover the 113-id catalog/bus routing/track switching/CC0
  fallback (280 checks), all five rideables/mount-dismount/sites/HUD (244 checks), the four cut-scene ids,
  beats, skip, cap, reduce-motion and no-3D fallback (78 checks), and manifest/sha256/fallback/particle
  behaviour for the CC0 packs (2,110 checks).

### Changed

- Project version is now `0.3.0` (`project.godot` `config/version`).
- `AudioDirector` keeps its public signatures but now delegates to `features/audio/`; new IDs are
  append-only and `has_stream()` should guard optional ids in gameplay code.
- World counts move from 17–21 POIs to **24 base POIs (21 authored + 3 exfil pads), up to 28 with preset
  extras**; `features/world/WORLD_API.md` and the docs now describe 20 POI types.
- `get_pois()` dictionaries gain `pad_radius`; interior and dungeon-anchor contracts are unchanged.
- Codex now has **Sites** and **Rideables** tabs in addition to the existing tabs.
- README credits and `docs/THIRD_PARTY_NOTICES.md` now state the CC0 pack provenance honestly: all 3D
  geometry/materials/shaders remain procedural, audio and particle/prototype textures include seven CC0
  Kenney packs.

### Fixed

- **Real-boot inventory smoke blocked by the insertion cut-scene.** The `--inventory-smoke` harness
  injected `I` while the new 4 s `insertion` shot owned gameplay input. `App._wait_for_gameplay()` now
  waits out any running cinematic (14 s cap) before smoke input; the inventory and shooting smoke suites
  both pass.
- **Audio-resource leaks at exit.** AudioDirector now stops pooled/ambient voices and drops stream
  references in `_exit_tree`, and teardown flushes the audio mix step for ~60 ms before freeing voices
  (`AudioServer` only erases a stopped playback on the next mix step). This cleared the
  `AudioStreamWAV`/`scratch_001.wav`, assets-RID and `ai`-suite Ogg leaks — all suites exit clean.
- Audio and particle feedback no longer has to be synthesised at runtime for impacts/UI/engines: missing
  CC0 files still degrade silently to the procedural fallback with no `push_error`/warning spam.
- Vehicle placement never leaves a run without rideables: if a POI is missing, the specialist archetypes
  fall back to deterministic drop-zone offsets; positions snap with a downward raycast and then
  `WorldBuilder.sample_height()`.
- Cut-scenes cannot soft-lock: every exit path (natural end, skip, abort, freed boss/player, scene
  teardown) restores HUD/mouse/input, the director never dereferences a freed node, and the exfil shot
  runs before `RunState.tick_extraction(0.0)` ends the run.

### Testing

- Suite manifest: **18 headless suites** (boot, shooting, inventory, integration, death, dungeon,
  tutorial, world, world_variants, ai, companions, progression, ui, ui_icons, audio, vehicles, cutscenes,
  assets). **The final 0.3.0 gate passes 18/18 (aggregate exit 0, 2026-10-26).** Check counts in this
  release: audio 280, vehicles 244, cutscenes 78, assets 2,110, progression 975, ui 130, ui_icons 148,
  integration 118, world (contract pass with 26 POIs / 16 interiors / 52 loot anchors / 598 clutter).
- CLI/automation evidence and the per-suite table are recorded in [docs/QA_REPORT.md](docs/QA_REPORT.md).
- `tests/run_all.ps1` still fails on `SCRIPT ERROR` and engine `ERROR:` lines, reads the suite list from
  `tests/suites.json`, and writes logs to `tests/artifacts/logs/`.

### Documentation

- New [docs/ASSET_PACKS.md](docs/ASSET_PACKS.md) (pack provenance, dead Asset Library links, curation and
  verification), plus the honest CC0 section in
  [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) and in the README credits.
- Rewritten/updated: [README.md](README.md), [docs/FEATURES.md](docs/FEATURES.md),
  [docs/TECHNICAL.md](docs/TECHNICAL.md), [docs/DESIGN.md](docs/DESIGN.md),
  [docs/QA_REPORT.md](docs/QA_REPORT.md), [docs/DEVLOG.md](docs/DEVLOG.md) and
  [features/world/WORLD_API.md](features/world/WORLD_API.md).

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
