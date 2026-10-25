# RIFTWARD - QA Report

**Build:** 0.2.0
**Engine:** Godot 4.7.2 stable, Forward+, Jolt Physics, D3D12  
**Reference machine:** Windows, NVIDIA GeForce RTX 3060  
**Date:** 2026-10-25

## 1. Summary

The playable build passes all fourteen automated suites: boot, real-boot shooting/input, real-boot inventory, gameplay integration, death/downed/results, under-reach dungeons, Field Training, procedural world, planet variants, enemy AI, companions, progression/content, UI and the icon catalog. The UI/content expansion also added display settings, visual-first Loadout/Locker/Skills/Squad/Outpost/Quick Deploy screens, the outpost layout v2 diorama, extreme weather and five run modes, 12 new icons, a Reach Event HUD banner, the four-act deployment drop-feed cinema and save v5/layout migration; the UI and progression suites cover each of those additions. It was exercised windowed on D3D12 to capture the main menu, Quick Deploy preflight, hub, Loadout, Locker, Skills, Squad, Outpost, Codex, Settings, results and in-deployment HUD plus the scope and tactical-map views; all **21 captures** (17 screen captures plus the 4 drop-feed acts) were regenerated at 1600x900 and visually inspected. No blocking script or runtime errors remain in the normal play path.

| Suite | Command | Result |
|---|---|---|
| Boot | `--headless --path . --quit-after 240` | PASS - no script errors |
| Shooting/input | `--headless --path . --quit-after 4000 -- --shoot-smoke` | PASS - real App boot, sniper charge fire, all four weapon slots, knife swing, abilities, grenade, reload, squad/pet commands; no runtime errors |
| Inventory | `--headless --path . --quit-after 4000 -- --inventory-smoke` | PASS - real App boot, I-key path pauses, presents four weapon rows and satchel, closes cleanly |
| Gameplay integration | `--headless --path . --quit-after 4000 res://tests/integration_test.tscn` | PASS - 118/118 checks: expanded content counts, all 20 world-event paths, dungeon entry/exit and exfil |
| Death/downed/results | `--headless --path . --quit-after 4000 res://tests/death_test.tscn` | PASS - 9/9 checks |
| Under-reach dungeons | `--headless --path . --quit-after 6000 res://tests/dungeon_test.tscn` | PASS - 57/57 checks |
| Field Training | `--headless --path . --quit-after 9000 res://tests/tutorial_test.tscn` | PASS - 20/20 checks |
| World | `--headless --path . --quit-after 4000 res://features/world/world_test.tscn` | PASS - 17+ POIs, interiors, fluids, nav, collision, map texture |
| Planet variants | `--headless --path . --quit-after 12000 res://tests/world_variants_test.tscn` | PASS - 168/168 checks: original and new planet/map presets, fluid rules, weather, day/night |
| Enemy AI | `--headless --path . --script res://features/ai/ai_test.gd` | PASS - 134/134 checks |
| Companions | `--headless --path . --script res://features/companions/companions_test.gd` | PASS - 78/78 checks |
| Progression/content | `--headless --path . --script res://tests/progression_test.gd` | PASS - 786/786 checks: counts, modes, new content, save v5/layout v2, display options |
| UI | `--headless --path . --quit-after 2400 res://ui/ui_demo.tscn` | PASS - 130/130 checks: visual-first screens, settings display, outpost diorama, four-act loading cinema, Reach Event HUD |
| Icon catalog | `--headless --path . --script res://tests/ui_icons_test.gd` | PASS - 148/148 checks: every referenced icon, including the 12 new SVGs, resolves |

Aggregate runner: `powershell -ExecutionPolicy Bypass -File tests/run_all.ps1` -> **All 14 test suites passed.** The runner fails on either `SCRIPT ERROR` or engine `ERROR:` lines, so scripting and physics regressions are caught automatically.

Logs are saved to `tests/artifacts/logs/`.

## 2. Gameplay integration coverage

The integration test launches a real Deployment with seed 98765 and verifies:

- ContentDB initialized with all expected counts and no validation errors (37 enemies, 16 weapons, 24 abilities, 24 perks, 13 contracts, 12 maps, 5 planets, 18 weather states, 5 game modes, 20 world events, 3 dungeon themes).
- Profile loads; save version and layout version are current.
- World generation completes and exposes 17+ POIs with a planet/map preset; tactical data exposes the texture, map/mode/planet/weather/clock identity, objective/building/cache/bounty/dungeon markers and live hostiles.
- Fluid basins exist and `sample_fluid()` resolves them; enterable interiors are exposed.
- Run identity carries difficulty, map preset, planet, mode and hardened enemy density.
- Deployment seeds the contract plus side objectives; loot caches and HUD mission trackers exist.
- Deployment pre-bakes under-reach entrances; entering one moves the player off the frontier, spawns hostiles/boss/loot, and exiting restores the surface position.
- Crouch works through the C alternate action; the equipped weapon exposes an ADS zoom factor.
- All four endgame pressure event definitions execute without script errors.
- Player, health, weapon controller, ability manager and HUD snapshot exist.
- Weapon controller owns four slots (two primaries, sidearm, issued knife); slot 4 reports `is_melee`, the HUD snapshot carries four slot entries, and the inventory snapshot exposes loadout plus satchel.
- Enemy agents, two Wardens and a Driftling spawn; hostiles expose a head-mounted health bar that tracks real damage.
- Real weapon fire (Sable Rail charge shot under ADS) consumes ammo and damages a real enemy through the hitscan/weakpoint pipeline.
- Weapon slot 4 equips the knife, swings without consuming ammo, and slot 1 returns to the firearm.
- Ability input starts a cooldown; all eight expansion ability effects (Ember Ward through Zip Line) execute through the real dispatcher.
- All 20 world event paths execute through the real deployment effect path without script errors (supply drops, elites, skirmishes, surges, jammers, fog, Bloom waves, convoys, rift echoes, meteor strikes, rift cyclones, toxic drift, whiteouts, scavenger convoys, bounty brokers, distress beacons, collapse tremors).
- Player interaction ray sees objective sites and exfil beacons; pressing E advances the contract and starts the exfil hold.
- Objective interaction advances the contract.
- The H call-exfil action requests extraction from the pad, spawns the Kestrel dropship, and can be cancelled before the final E interaction starts the successful hold.
- Exfil hold starts through the actual player beacon interaction, spawns the Kestrel dropship, completes, and produces an extracted result with salvage, map, mode and recovered item count.

## 2b. Dungeon and tutorial coverage

The dungeon suite builds all three themes and verifies 5–9 rooms, navmesh polygons, floor/ceiling collision, start/exit/boss anchors, loot anchors, a spawned encounter with hostiles/boss/loot, boss registration and despawn. The tutorial suite starts the real tutorial deployment and verifies no hostiles/squad, the five stages (move, three target hits, ability, cache, exfil), the tutorial result flag, profile completion and reward path.

## 3. Death test coverage

- Player spawns alive.
- Lethal damage enters the 20-second downed state.
- Revive charges initialize.
- Bleedout ends in permanent death.
- Player died signal fires.
- Deployment produces a non-extraction result with a reason.
- This is the same result path used by App/ProfileState on the UI side.

## 4. World QA

Generation metrics from the world test (Verdant Verge preset, seed 12345):

- Generation time: about 1.42 s total, including about 237 ms nav bake.
- 19 POIs (17 authored + 2 preset extras), 16 roadside outbuildings, 3 exfil pads, 2 drop zones, 9 enterable interiors.
- 64 terrain chunks, 204,800 terrain triangles.
- 3,144 navigation polygons.
- 5,802 MultiMesh scatter instances across 12 batches.
- 3 fluid basins with 3 surface meshes and 2 lava glow lights.
- Physics raycast from above hits terrain; interior floor/ceiling rays hit.
- Topographic map texture generated with water/lava tinting.
- Planet variants test: the 168-check suite generates the original and expanded preset list with planet biome names and correct fluid types (Cinder lava-only, Thalassa water-only, Frost water, Nyx lava-only), interiors, weather and day/night systems.

Known benign console noise: Recast emits precision warnings for agent_height, agent_max_climb and agent_radius because they snap to voxel units. These do not affect play.

## 5. AI QA

The 134-check AI suite covers:

- Spawn contract, collision layers/masks, group membership, health meta and weakpoint metadata.
- Vision + LOS + hearing, FSM transitions, ranged telegraphs and melee.
- Real CombatUtils damage into the player, enemy death, defeat signal, EventBus and RunState kill recording.
- Loot drops, auto-collect and E interaction.
- Shock/burn/corrode/slow statuses.
- Elite affix and guaranteed item drops.
- Boss phase transition and boss kill event.
- Deployment does not end on enemy death.

A separate sandbox test with the real Player confirms six agents engage and navigate once the world navmesh is baked. A deployment smoke confirms 23 EnemyAgents across 10 archetypes, a live enemy damaging the real Player, and a player-pipeline kill that leaves the run active.

## 6. Companion QA

The 78-check companion suite covers all four Warden roles and all three Driftling roles:

- Visual construction and friendly collision/team setup.
- Follow/hold/focus/revive commands and teleport catch-up.
- Medic heal, heavy taunt/armor, scout marking, engineer shock turret.
- Warden downed -> E prompt -> revive; automatic player revive.
- Mote shield/heal, Cinder damage, Pip scan.
- Pet damage, heal, disable/self-repair, cloak support.
- CompanionManager spawning from ProfileState and squad-status HUD payload.

## 7. UI QA

The 130-check UI suite now covers the visual-first expansion as well as the previous flows: Quick Deploy registration/preflight/back navigation with 5 planets, 12 maps, 5 modes and planet portraits/map thumbnails; hub navigation; Loadout item-art cards; Locker compact Warden previews and pet/weapon-skin previews; Skills discipline/ability/attribute/perk medallions; Squad Warden portraits and Driftling art; outpost `get_diorama()` geometry (8 module rects inside the board, hit selection); settings display controls/options (window mode, resolution, V-Sync, render scale, AA, FPS cap, quality, interface scale); the four-act deployment drop-feed cinema (threat signature with boss dossier, rift breach, drop descent and touchdown, skill/act rail, radio traffic and skip/static-briefing paths); HUD binding (minimap, tactical map, precision scope, style aim sight, mission trackers, weather/clock chip, training card, dungeon banner, hazard overlay) plus the Reach Event banner after `EventBus.world_event`; M-key map toggling, non-scoped ADS aim-sight activation and scope exclusivity, deployment transitions, inventory overlay presentation with four weapon rows and satchel loot plus clean dismissal, gear equip, perk purchase, squad/pet assignment, high-contrast rebuild, accessibility application, content availability, font loading, old/new icon import and icon-tab glyph assignment.

The 786-check progression/content suite now covers the expanded catalog: 4 difficulty presets, 12 map presets, 5 planets, 18 weather states, 5 game modes and 20 world events, 13 contracts, 37 enemy entries, 3 dungeon themes; new planet/map/enemy/contract ids and fields; mode math (Normal 1080 s/1x, Quick 1080 s at 2x, Blackout start_time 0.94 and reward/loot bonuses, Gauntlet 840 s with 0.45 storm fraction, Onslaught density 1.35 / elite +0.20 / reward 1.5 / hostile +12); App display option getters and `apply_display_settings()` under headless with settings restored; `ProfileState.validate_base_layout()` empty for all 8 modules with in-bounds/non-overlapping footprints, the v4→v5 stale-layout migration preserving module tiers/currency/inventory, and SAVE_VERSION 5. Existing checks were kept: planet/map/difficulty integrity, staged contracts, hardened difficulty fields, quick-mode 2x clock math, explicit map override and planet resolution, tutorial mode clock/exfil/storm behaviour, per-weapon ADS zoom, all 16 weapon viewmodels plus the knife viewmodel, mechanical level gates, default and rebindable actions, duplicate-binding detection, four-slot starter kit, v2 save migration, primary-slot swap/equip rules, XP thresholds and point grants, perk level gates, kill-sourced run XP, difficulty reward and result map/mode/time-scale/mode clock/run duration/XP breakdown math, recovered item count, and the late-run pressure curve.

21 screen captures (1600x900) are in `ui/_screenshots/`:

- 01_main_menu, 02_hub, 03_loadout, 04_locker, 05_skills, 06_squad, 07_outpost, 08_codex, 09_settings, 10_loading, 11_results, 12_hud, 13_pause, 14_hud_down, 15_hud_scope, 16_tactical_map, 17_quick_deploy.
- Deployment drop feed: 18_loading_breach (act 2), 19_loading_descent (act 3), 20_loading_touchdown (act 4), 21_loading_leviathan (act 1 on Thalassa-2 with the Leviathan dossier).

Planet/world captures (1600x900) are in `features/world/preview_shots/`:

- Default frontier: overview, dropzone, Warden outpost, relay spire, exfil pad, Ashen canyon, planet sky.
- `cinder_caldera/` and `tidal_shelf/`: nine framed shots each, including overview, dropzone, POIs, sky, fluid basin and interior. These were captured through the real windowed D3D12 renderer with `world_preview.tscn -- --capture --preset <id>`.

Visual review notes:

- Main menu now leads with the oversized Quick Deploy CTA, a compact Enter Hub secondary action and a Field Training entry; the remembered drop strip carries a map thumbnail, planet medallion and mode clock.
- Quick Deploy preflight presents planet portraits, map thumbnails, four difficulty cards, five mode cards, a weather forecast strip and a deployment panel with contract/target intel.
- Cinder-4 reads as a hot basalt/ember world with visible lava basins; Thalassa-2 reads as a pale tidal shelf with water basins and teal kelp growth; Frost-9 reads as pale ice shelves and blue shadow; Nyx-12 reads as violet rift light over black basins.
- Interiors are enclosed, lit and walkable; the derelict freighter adds a full ship interior.
- Hub, Loadout, Locker, Skills, Squad, Codex and Settings read as a coherent image-first field terminal: item art, Warden/pet portraits, discipline medallions, compact cosmetic previews and tooltip-only explanations. The Codex includes Planets, Dungeons, Weather and Operations tabs.
- The Outpost screen renders the 8×8 diorama with distinct module structures, built/planned/road legend and a LAYOUT v2 badge; module rows carry icons and miniatures.
- HUD notifications no longer obscure ammo; radio traffic is a single subtitle line; the weather/clock chip, training card, dungeon banner, hazard tint and Reach Event banner sit outside the combat sightline.
- Compass objective/exfil/Rift Shrine/cache/bounty markers are live and update every 0.5 s; the FIELD OPS tracker shows direction, progress and distance.
- Outpost module list scrolls; the diorama and side column stay inside 1600x900 and reflow at 1280x720.
- The first-person viewmodel is intentionally stylized/blocky; at the default aspect it can obscure the lower-right edge of the world. It reads as a sci-fi rifle but is the least polished visual element.

## 8. Visual captures

- Main menu: `ui/_screenshots/01_main_menu.png` and `tests/artifacts/main_menu.png`
- Deployment HUD (with minimap): `tests/artifacts/deployment.png`
- HUD without overlays: `tests/artifacts/deployment_clear.png`
- Hub, loadout, locker, skills, squad, outpost, codex, settings, loading, results, pause, scope: `ui/_screenshots/`
- New-feature visual QA (this pass): `captures/qa_enemy_health_bar.png`, `captures/qa_hud_aim_sight.png`, `captures/qa_inventory.png`, `captures/qa_exfil_ship.png`
- World: `features/world/preview_shots/` (7 frames)
- Enemy sandbox: `features/ai/preview_shots/` (4 frames)
- Companion sandbox: `features/companions/preview/` (3 frames)
- Expanded UI pass (this pass): all 21 `ui/_screenshots/` PNGs were regenerated at 1600x900 and inspected for settings display, Quick Deploy, Outpost, Loadout, Locker, Skills, Squad and the deployment drop-feed acts.

## 9. Windowed render smoke

- D3D12 initializes on the RTX 3060 and renders the menu, hub, Quick Deploy, Loadout, Locker, Skills, Squad, Outpost, Codex, Settings and deployment HUD.
- Windowed QA also verified the display settings card, the outpost diorama, the Reach Event banner, enemy head health bars, the Lattice AR aim-sight reticle at ADS, the full-screen paused inventory, and the Kestrel dropship hovering over a called exfil pad (captures listed above).
- World generation and loading complete without renderer errors.
- Mouse capture and pause paths were exercised by UI harness logic; no crash.
- No formal average/1% low FPS capture was automated. The build targets 60 FPS at 1080p and runs comfortably in the windowed captures; formal profiling is on the backlog.

## 10. Known issues / limitations

1. Standalone export is delivered as `release/RIFTWARD-win64.zip` (exe + pck, checksummed); rebuilding it needs Godot 4.7.2 export templates installed on the build machine.
2. The minimap/tactical map is north-up and shows live hostiles in range; it has no fog-of-war or permanent discovery history, and POI icons appear after discovery.
3. Frag-only quick throw - shock and veil grenade definitions exist; selection/behavior is not exposed in play.
4. Upgrade-based outpost - eight modules, three tiers and the versioned 8×8 layout work; freeform drag placement is not exposed.
5. No weapon mastery tracks - weapons have rarity/affixes but no per-weapon XP/mastery progression.
6. Weather is seeded by planet/preset and can be forced by events and modes; there is no manual weather picker in Quick Deploy.
7. No mid-run save - quitting a deployment abandons the run (by design), but there is no resume.
8. Test-process exit codes - Godot's Start-Process wrapper reports null exit codes on this machine, so `tests/run_all.ps1` gates on explicit PASS markers plus absence of `SCRIPT ERROR` and engine `ERROR:` lines. Individual suites still call quit(0/1) correctly.
9. Benign exit leaks - a few ObjectDB instances are reported when tests force-quit with active async effects. These are test-harness shutdown artifacts, not runtime gameplay leaks observed during normal runs.
10. No voice acting / localization - English text only; radio is subtitles.

## 11. Regression fixes in the current pass

- **Muzzle-flash crash on firing.** `WeaponController._muzzle_flash()` passed `get_tree().current_scene` (the `boot.tscn` root, a plain `Node`) into `CombatVFX.muzzle_flash()`, which requires a `Node3D`. The test scene happened to be a `Node3D`, masking it. Fixed by using the player's effect parent, the Deployment actors root.
- **Projectile/grenade setup before entering the SceneTree.** `CombatProjectile.setup()` wrote `global_position` before `add_child()`, producing an `!is_inside_tree()` engine error and risking a grenade at the world origin. Setup now stages the spawn origin and applies it in `_ready()`.
- **Protective regression coverage.** A new real-boot `--shoot-smoke` suite launches through `boot.tscn`/App with the exact production scene graph, fires the starting weapon, then exercises abilities, grenade, reload, weapon swaps, squad and pet commands. `tests/run_all.ps1` now fails on engine `ERROR:` lines as well as `SCRIPT ERROR`, so this class of bug is caught automatically.

## 12. Recommended next QA pass

- Automated FPS/frame-time capture during a 20-enemy fight at 1080p and 1440p.
- Full gamepad pass on physical hardware (UI focus and all combat actions).
- 30-minute soak and five consecutive deployments checking node/memory counts.
- Vault contract boss encounter end-to-end with HUD bar and phase transitions.
- Difficulty/mutator/mode balance telemetry over 50 simulated runs.
- Long-run verify of the v5 layout migration with real pre-expansion save backups.
