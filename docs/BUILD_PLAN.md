# RIFTWARD - Build Plan and Delivery Status

## 1. Approved direction

RIFTWARD is a single-player, offline, first-person sci-fi extraction shooter built in Godot 4.7.2. The player deploys into a seeded 1.8 km x 1.8 km alien frontier, completes contracts, fights Ashen/Bloom/Choir enemies, recruits Wardens and Driftlings, extracts before the Collapse, and rebuilds Waystation Kestrel.

Approved pillars:

1. Expressive combat.
2. A dense, landmark-driven frontier.
3. Greed versus extraction.
4. A home that grows.
5. A clean, modern UI and sunlit stylized art direction.

## 2. Scope status

| Plan item | Target | Delivered | Notes |
|---|---|---|---|
| Seeded world | 1.8 km2, 3 biomes, 16+ POIs | DONE | 64 terrain chunks, 12 map presets across 5 planets, 17+ POIs, 16–22 roadside outbuildings, 3 exfil pads, 2 drop zones, 5k–9k scatter instances, async navmesh |
| Planets / maps | 5 planets, 12 maps | DONE | Meridian-9, Cinder-4, Thalassa-2, Frost-9, Nyx-12; 12 selectable presets with difficulty default and explicit override |
| Weather / day-night | seeded weather + cycle | DONE | 18 weather states, preset-level weather pools, particles/lightning/vision modifier, per-planet day length and 4 sky keyframes, HUD clock |
| Display settings | window/resolution/AA/quality | DONE | Window mode, resolution, V-Sync, render scale, anti-aliasing, FPS cap, quality preset and interface scale; applied live, headless-guarded |
| Enterable interiors | buildings + ship | DONE | 7 enterable POIs incl. derelict freighter; 4.2 m doorways, interior spawns, navmesh inside |
| Water / lava | basins + hazards | DONE | seeded carved basins, water/lava shaders, map tint, swim/heat rules, enemy reactions |
| Dungeons | 3 themes, 2–3 per run | DONE | procedural 5–9-room under-reach instances, private navmesh, boss/loot, storm paused inside |
| Field Training | first-time stages | DONE | 5 guided stages, HUD card, skip/replay, persistent completion |
| Extraction loop | 18 min, Collapse storm, exfil hold | DONE | Normal 18 min / Quick 9 min real time; 75 s game-time hold; death/downed/revive; result and profile rewards |
| Game modes | 5 selectable modes | DONE | Normal, Quick, Blackout, Gauntlet, Onslaught; mode math drives duration, storm, start time, density, elites, rewards, hostile budget and loot |
| Randomness | Seeded layouts, contracts, loot, Rift Mods, events | DONE | 13 contracts (7 classic + 6 staged), 8 mutators, 12 Rift Mods, 20 world events with 3 scheduled per run; side caches/bounties |
| Weapons | 16 distinct weapons | DONE | 16 weapons; rarity/affix variants; flamer viewmodel style |
| Active abilities | 24 (20 active + 4 ultimates) | DONE | All effects implemented and exercised headlessly |
| Ultimates | 4 | DONE | Iron Tide, Ghost Protocol, Siegeworks, Hyperfocus |
| Passives | 24 | DONE | Four discipline trees, spendable points, respec through UI |
| Disciplines / playstyles | 4 | DONE | Vanguard, Infiltrator, Engineer, Pathfinder |
| Enemies | 20 base + 11 elites + 6 bosses | DONE | Three factions; habitat-aware; sapper volatile death; perception, cover/strafe, telegraphs, affixes, boss phases; staged garrisons |
| Difficulty | 4 named presets | DONE | Patrol/Contact/Breach/Collapse; density, elites, hostile caps, mission counts, storm timing and reward scaling |
| Minimap | Tactical minimap + M overlay | DONE | Top-left live map, full map, objective/building/cache/bounty/dungeon markers, enemies/allies, scope overlay, FIELD OPS tracker |
| Friendly members | 4 Wardens, 2 active | DONE | Medic/heavy/scout/engineer; commands, downed/revive, barks, ranks |
| Pets | 3 Driftlings | DONE | Mote/Cinder/Pip; follow, abilities, shells, self-repair |
| Gear / wear | 8 slots, rarities, affixes, sets, cosmetics | DONE | 2 primaries + sidearm + 5 armor; issued knife; 5 rarities, 4 sets, 10 templates, 6 suits, 8 dyes, 8 weapon skins, 3 pet shells |
| Stats | Levels, attributes, derived stats | DONE | Level 1-30, 4 attributes, gear/perk/base modifiers, crit/armor/shield/status, hazard resist and swim speed |
| Outpost / buildings | 8 modules x 3 tiers | DONE | Upgrades, power, Nexus gating, 8×8 isometric diorama with layout v2 + save v5 migration; persistent |
| Visual-first UI | Image-first armory, preflight, outpost, codex | DONE | UIIconMedallion/UIItemArt/UIPlanetPortrait/UIMapThumbnail/UIAllyPortrait/UIPetArt/UIModuleArt, compact Warden previews, 12 new SVG icons |
| Modern UI | 10+ screens, HUD, accessibility | DONE | 13 screens + HUD + field inventory; display settings, map/planet/mode selection, Codex weather/operations, Reach Event banner, weather/clock/hazard/dungeon/training HUD |
| Procedural audio | SFX + music | DONE | Layered synthesized SFX, 2D/3D pools, looping ambient bed |
| Tests / QA | Automated and visual | DONE | 14 suites pass; UI screenshots + deployment captures |
| Standalone export | Optional | DONE | `export_presets.cfg` (Windows Desktop, x86_64) + `tools/build_export.ps1` / `BUILD.cmd`; boot-verified headless |
| Daily seed / map overlay | Stretch | DONE (map) | Topographic minimap and M-key overlay delivered; daily seeds remain future work |
| Grenade selection | 3 types | PARTIAL | Content authored for frag/shock/veil; quick-throw currently uses frag only |
| Freeform base placement | Grid build mode | PARTIAL | Layout data and 8 modules exist; UI upgrades modules instead of drag-placement |
| Weapon mastery | 5 ranks per weapon | NOT DELIVERED | Data supports variants/affixes; mastery tracks were cut |

## 3. Milestones

| Phase | Scope | Status |
|---|---|---|
| M0 Foundation | Project config, feature folders, core Resource schema, autoloads, save skeleton, boot, theme/font/icon pipeline | COMPLETE |
| M1 Combat slice | Player controller, camera, damage pipeline, weapons, procedural viewmodels, HUD snapshot, pause/settings | COMPLETE |
| M2 World + run loop | Terrain/biomes/POIs, navigation, objectives, exfil, Collapse, encounter population, results | COMPLETE |
| M3 Progression/loadout | All content data, stats, gear/loot, abilities/perks, inventory/loadout/locker/skills screens | COMPLETE |
| M4 Factions, squad, outpost | Enemies/elites/bosses, Wardens/Driftlings, outpost modules, world events, boss HUD | COMPLETE |
| M5 Look/feel polish | Procedural environment, VFX, audio, 12-screen UI, HUD feedback, accessibility, onboarding messaging | COMPLETE |
| M6 QA/delivery | Headless tests, death/extraction paths, visual captures, docs, launcher | COMPLETE |
| M7 Frontier Update | Planets/maps, weather/day-night, interiors, fluids, dungeons, staged contracts, Field Training, expanded content | COMPLETE |
| M8 UI/content expansion | Display settings, visual-first Loadout/Locker/Skills/Squad/Outpost/Quick Deploy, outpost layout v2, extreme weather, modes, planets/maps, events, targets, missions, 12 icons, docs/tests/screenshots | COMPLETE |
| M9 0.2.0 release | Versioning across configs and docs, changelog and dev log, rebuilt Windows export, tagged GitHub release | COMPLETE |

## 4. Architecture decisions that survived implementation

- Data-driven Resources plus save-friendly runtime dictionaries.
- Signals up, calls down: UI listens, gameplay owns state.
- Scene-scoped combat state: ability cooldowns and weapon ammo live on the player.
- Physics-ticked movement, cooldowns and hitscan; mouse look stays in input.
- Deterministic seeds feed world, POIs, enemy composition, loot and events.
- Async world generation and navigation behind a loading screen.
- One player damage pipeline: DamageData -> HealthComponent, with weakpoints and statuses on the same contract.
- Theme-first UI with one token system, reusable factory and screens.

## 5. Verification gates

- Boot: project launches to UIRoot main menu with no script errors; Quick Deploy preflight opens from the dominant CTA and offers 5 planets, 12 maps, 5 modes and 4 difficulties.
- Gameplay: world -> player -> fire -> ability -> objective -> H or beacon exfil -> dropship -> result, including four weapon slots, knife, enemy head health bars, map/mode identity, side objectives, loot caches, HUD trackers, tactical map, crouch and endgame-event exercise.
- Mortality: lethal damage -> downed -> bleedout -> permanent death -> result; 9/9 checks.
- Content: all 24 ability effects and all 20 world event paths execute without runtime errors, including forced-weather, convoy, bounty and storm-clock events.
- Factions: enemy AI contract and combat test 134/134; enemy content totals 37 (20 base + 11 elites + 6 bosses).
- Companions: Warden/pet contract, commands, revive and manager test 78/78.
- Progression: counts and new ids, four-slot starter kit, v2 and v4→v5 save migration, outpost layout validation, viewmodel coverage, bindings, map presets, five-mode math (quick 2x, gauntlet 14-minute/storm, onslaught density/reward/elite, blackout start), enemy catalog, zoom values, mechanic/perk gates, XP math, display setting options and pressure curve.
- UI: navigation (including Quick Deploy), all screens, visual-first art components, settings display controls, outpost diorama geometry, HUD (minimap/map/scope/aim sight/tracker/Reach Event banner), paused inventory overlay, accessibility, profile mutations and the four-act deployment drop-feed cinema; 130 checks, 21 screen captures + feature captures.
- World: 17+ POIs, 12 presets across 5 planets, 3 exfils, 2 spawns, navmesh, collision and map texture; generation about 1.1 s.

## 6. Future backlog

1. Windows installer (Inno Setup or MSIX) and Authenticode code signing on top of the delivered export.
2. Daily seed contract and local leaderboards.
3. Full grenade selection and three distinct grenade behaviors.
4. Freeform outpost grid placement with rotation/refund and power adjacency.
5. Weapon mastery tracks, more weapon mods and attachment visuals.
6. Co-op support (server-authoritative) as a separate architecture track.
7. More POI kits, boss arenas and narrative codex entries.
8. Performance profiling at 1440p/ultrawide and formal 1% low capture.
9. More dungeon themes/floors and a dungeon map overlay.
10. Deeper weather gameplay (lightning hazards, heat/cold exposure gear).
