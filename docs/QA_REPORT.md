# RIFTWARD - QA Report

**Build:** 0.1.0 "First Light"  
**Engine:** Godot 4.7.2 stable, Forward+, Jolt Physics, D3D12  
**Reference machine:** Windows, NVIDIA GeForce RTX 3060  
**Date:** 2026-10-24

## 1. Summary

The playable build passes all ten automated suites: boot, real-boot shooting/input, real-boot inventory, gameplay integration, death/downed/results, procedural world, enemy AI, companions, progression/content and UI. It was also exercised windowed on D3D12 to capture the main menu, Quick Deploy preflight, hub, skills, results and in-deployment HUD plus the scope and tactical-map views. No blocking script or runtime errors remain in the normal play path.

| Suite | Command | Result |
|---|---|---|
| Boot | `--headless --path . --quit-after 240` | PASS - no script errors |
| Shooting/input | `--headless --path . --quit-after 4000 -- --shoot-smoke` | PASS - real App boot, sniper charge fire, all four weapon slots, knife swing, abilities, grenade, reload, squad/pet commands; no runtime errors |
| Inventory | `--headless --path . --quit-after 4000 -- --inventory-smoke` | PASS - real App boot, I-key path pauses, presents four weapon rows and satchel, closes cleanly |
| Gameplay integration | `--headless --path . --quit-after 4000 res://tests/integration_test.tscn` | PASS - 73/73 checks |
| Death/downed/results | `--headless --path . --quit-after 4000 res://tests/death_test.tscn` | PASS - 9/9 checks |
| World | `--headless --path . --quit-after 4000 res://features/world/world_test.tscn` | PASS - 16 default POIs + 14 roadside, 3 exfils, nav, collision, map texture |
| Enemy AI | `--headless --path . --script res://features/ai/ai_test.gd` | PASS - 134/134 checks |
| Companions | `--headless --path . --script res://features/companions/companions_test.gd` | PASS - 78/78 checks |
| Progression/content | `--headless --path . --script res://tests/progression_test.gd` | PASS - 143/143 checks |
| UI | `--headless --path . --quit-after 2400 res://ui/ui_demo.tscn` | PASS - 47/47 checks |

Aggregate runner: `powershell -ExecutionPolicy Bypass -File tests/run_all.ps1` -> **All 10 test suites passed.** The runner fails on either `SCRIPT ERROR` or engine `ERROR:` lines, so scripting and physics regressions are caught automatically.

Logs are saved to `tests/artifacts/logs/`.

## 2. Gameplay integration coverage

The integration test launches a real Deployment with seed 98765 and verifies:

- ContentDB initialized with all expected counts and no validation errors (23 enemies, 4 difficulties, 4 map presets).
- Profile loads.
- World generation completes and exposes 16+ POIs with a map preset; tactical map data exposes the texture, map/mode identity, objective/building/cache/bounty markers and live hostiles.
- Run identity carries difficulty, map preset, mode and hardened enemy density.
- Deployment seeds the contract plus side objectives; loot caches and HUD mission trackers exist.
- Crouch works through the C alternate action; the equipped weapon exposes an ADS zoom factor.
- All four endgame pressure event definitions execute without script errors.
- Player, health, weapon controller, ability manager and HUD snapshot exist.
- Weapon controller owns four slots (two primaries, sidearm, issued knife); slot 4 reports `is_melee`, the HUD snapshot carries four slot entries, and the inventory snapshot exposes loadout plus satchel.
- Enemy agents, two Wardens and a Driftling spawn; hostiles expose a head-mounted health bar that tracks real damage.
- Real weapon fire (Sable Rail charge shot under ADS) consumes ammo and damages a real enemy through the hitscan/weakpoint pipeline.
- Weapon slot 4 equips the knife, swings without consuming ammo, and slot 1 returns to the firearm.
- Ability input starts a cooldown.
- All 16 ability effects execute without script errors (Blink Step through Hyperfocus).
- All 12 world event paths execute without script errors (supply drops, elites, skirmishes, surges, jammers, fog, Bloom waves, convoys, rift echoes).
- Player interaction ray sees objective sites and exfil beacons; pressing E advances the contract and starts the exfil hold.
- Objective interaction advances the contract.
- The H call-exfil action requests extraction from the pad, spawns the Kestrel dropship, and can be cancelled before the final E interaction starts the successful hold.
- Exfil hold starts through the actual player beacon interaction, spawns the Kestrel dropship, completes, and produces an extracted result with salvage, map, mode and recovered item count.

## 3. Death test coverage

- Player spawns alive.
- Lethal damage enters the 20-second downed state.
- Revive charges initialize.
- Bleedout ends in permanent death.
- Player died signal fires.
- Deployment produces a non-extraction result with a reason.
- This is the same result path used by App/ProfileState on the UI side.

## 4. World QA

Generation metrics from the world test:

- Generation time: about 1.13 s total, including about 186 ms nav bake.
- 16 default POIs, 14 roadside outbuildings, 3 exfil pads, 2 drop zones (map presets add 2–4 optional POIs and raise roadside/scatter budgets).
- 64 terrain chunks, 204,800 terrain triangles.
- 3,165 navigation polygons.
- 5,106 MultiMesh scatter instances across 10 batches on the default frontier.
- 478 nodes at generation.
- Physics raycast from above hits terrain.
- Topographic map texture generated.

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

The 47-check UI suite covers Quick Deploy registration/preflight/back navigation, hub navigation, HUD binding (minimap, tactical map, precision scope, style aim sight, mission trackers), M-key map toggling, non-scoped ADS aim-sight activation and scope exclusivity, deployment transitions, inventory overlay presentation with four weapon rows and satchel loot plus clean dismissal, gear equip, perk purchase, squad/pet assignment, high-contrast rebuild, accessibility application, content availability, font loading, old/new icon import and icon-tab glyph assignment.

The 143-check progression/content suite covers the 4 difficulty presets and 4 map presets, hardened difficulty fields, quick-mode 2x clock math, map→difficulty mapping, 23 enemy entries, per-weapon ADS zoom, all 10 weapon viewmodels plus the knife viewmodel, mechanical level gates, new default and rebindable actions (weapon slots 3/4, inventory I, call exfil H), duplicate-binding detection, four-slot starter kit (Sable Rail sniper + Lattice AR + Sidewinder), v2 save migration to the sniper and second primary, primary-slot swap/equip rules, XP thresholds and point grants, perk level gates, kill-sourced run XP, difficulty reward and result map/mode/time-scale/XP breakdown math, recovered item count, and the late-run pressure curve.

Screen captures (1600x900) are in `ui/_screenshots/`:

- 01_main_menu, 02_hub, 03_loadout, 04_locker, 05_skills, 06_squad, 07_outpost, 08_codex, 09_settings, 10_loading, 11_results, 12_hud, 13_pause, 14_hud_down, 15_hud_scope, 16_tactical_map, 17_quick_deploy.

Visual review notes:

- Main menu now leads with the oversized Quick Deploy CTA and a compact Enter Hub secondary action.
- Quick Deploy preflight presents four map-linked difficulty cards, Normal/Quick mode cards and an icon-only deployment summary.
- Hub, loadout, codex and locker read as a coherent icon-first field terminal; explanatory copy lives in tooltips.
- HUD notifications no longer obscure ammo; radio traffic is a single subtitle line.
- Compass objective/exfil/Rift Shrine/cache/bounty markers are live and update every 0.5 s; the FIELD OPS tracker shows direction, progress and distance.
- Outpost module list is scrollable; at 900 logical height the right list extends slightly past the fold, which is expected but worth tightening.
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

## 9. Windowed render smoke

- D3D12 initializes on the RTX 3060 and renders the menu, hub, deployment and HUD.
- Windowed QA also verified the new enemy head health bars, the Lattice AR aim-sight reticle at ADS, the full-screen paused inventory, and the Kestrel dropship hovering over a called exfil pad (captures listed above).
- World generation and loading complete without renderer errors.
- Mouse capture and pause paths were exercised by UI harness logic; no crash.
- No formal average/1% low FPS capture was automated. The build targets 60 FPS at 1080p and runs comfortably in the windowed captures; formal profiling is on the backlog.

## 10. Known issues / limitations

1. No standalone executable - export templates were not installed. The project and launcher are the delivered run path.
2. The minimap/tactical map is north-up and shows live hostiles in range; it has no fog-of-war or permanent discovery history, and POI icons appear after discovery.
3. Frag-only quick throw - shock and veil grenade definitions exist; selection/behavior is not exposed in play.
4. Upgrade-based outpost - eight modules and three tiers work; freeform drag placement is not exposed.
5. No weapon mastery tracks - weapons have rarity/affixes but no per-weapon XP/mastery progression.
6. Fixed environment time - warm late-afternoon lighting across all biomes; no random weather/time-of-day.
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
- Save migration test with an older schema version.
- 30-minute soak and five consecutive deployments checking node/memory counts.
- Vault contract boss encounter end-to-end with HUD bar and phase transitions.
- Difficulty/mutator balance telemetry over 50 simulated runs.
