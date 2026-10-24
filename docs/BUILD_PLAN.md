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
| Seeded world | 1.8 km2, 3 biomes, 16+ POIs | DONE | 64 terrain chunks, 4 map presets, 16–20 POIs, 16–22 roadside outbuildings, 3 exfil pads, 2 drop zones, 5k–9k scatter instances, async navmesh |
| Extraction loop | 18 min, Collapse storm, exfil hold | DONE | Normal 18 min / Quick 9 min real time; 75 s game-time hold; death/downed/revive; result and profile rewards |
| Randomness | Seeded layouts, contracts, loot, Rift Mods, events | DONE | 6 contracts, 8 mutators, 12 Rift Mods, 12 world events with 2 scheduled per run; side caches/bounties |
| Weapons | 10 distinct weapons | DONE | AR, SMG, shotgun, DMR, rail, LMG, sidearm, launcher, arc, carbine; rarity/affix variants |
| Active abilities | 12 | DONE | All effects implemented and exercised headlessly |
| Ultimates | 4 | DONE | Iron Tide, Ghost Protocol, Siegeworks, Hyperfocus |
| Passives | 16 | DONE | Four discipline trees, spendable points, respec through UI |
| Disciplines / playstyles | 4 | DONE | Vanguard, Infiltrator, Engineer, Pathfinder |
| Enemies | 14 base + 6 elites + 3 bosses | DONE | Three factions; sapper volatile death; perception, cover/strafe, telegraphs, affixes, boss phases; staged garrisons and distant-hostile pruning |
| Difficulty | 4 named presets linked to 4 maps | DONE | Patrol/Verdant Verge, Contact/Ashen Shelf, Breach/Glass Expanse, Collapse/Rift Scar; density, elites, hostile caps, mission counts, storm timing and reward scaling |
| Minimap | Tactical minimap + M overlay | DONE | Top-left live map, full map, objective/building/cache/bounty markers, enemies/allies, scope overlay, FIELD OPS tracker |
| Friendly members | 4 Wardens, 2 active | DONE | Medic/heavy/scout/engineer; commands, downed/revive, barks, ranks |
| Pets | 3 Driftlings | DONE | Mote/Cinder/Pip; follow, abilities, shells, self-repair |
| Gear / wear | 8 slots, rarities, affixes, sets, cosmetics | DONE | 2 primaries + sidearm + 5 armor; issued knife; 5 rarities, 4 sets, 10 templates, 6 suits, 8 dyes, 8 weapon skins, 3 pet shells |
| Stats | Levels, attributes, derived stats | DONE | Level 1-30, 4 attributes, gear/perk/base modifiers, crit/armor/shield/status |
| Outpost / buildings | 8 modules x 3 tiers | DONE | Upgrades, power, Nexus gating, outpost diorama; persistent |
| Modern UI | 10+ screens, HUD, accessibility | DONE | 13 screens + HUD + field inventory; Quick Deploy preflight; icon-first language; Sora/Inter/JetBrains Mono; 65 icons; responsive; full rebinding with reset |
| Procedural audio | SFX + music | DONE | Layered synthesized SFX, 2D/3D pools, looping ambient bed |
| Tests / QA | Automated and visual | DONE | 10 suites pass; 17 UI screenshots + deployment captures + 4 new-feature captures |
| Standalone export | Optional | DONE | `export_presets.cfg` (Windows Desktop, x86_64) + `tools/build_export.ps1` / `BUILD.cmd`; produces `build/RIFTWARD.exe` (104 MB) + `build/RIFTWARD.pck` (4 MB); boot-verified headless with clean exit and profile save |
| Daily seed / map overlay | Stretch | DONE (map) | Topographic minimap and M-key overlay delivered; daily seeds remain future work |
| Grenade selection | 3 types | PARTIAL | Content authored for frag/shock/veil; quick-throw currently uses frag only |
| Freeform base placement | Grid build mode | PARTIAL | Layout data and 8 modules exist; UI upgrades modules instead of drag-placement |
| Weapon mastery | 5 ranks per weapon | NOT DELIVERED | Data supports variants/affixes; mastery tracks were cut |
| Random weather / time-of-day | 3 presets | DONE | Four map-preset environment moods (Verdant late afternoon, Ashen dusk, Glass overcast, Rift storm) |

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

- Boot: project launches to UIRoot main menu with no script errors; Quick Deploy preflight opens from the dominant CTA.
- Gameplay: world -> player -> fire -> ability -> objective -> H or beacon exfil -> dropship -> result; 73/73 checks, including four weapon slots, knife, enemy head health bars, map/mode identity, side objectives, loot caches, HUD trackers, tactical map, crouch and endgame-event exercise.
- Mortality: lethal damage -> downed -> bleedout -> permanent death -> result; 9/9 checks.
- Content: all 16 ability effects and all 12 world event paths execute without runtime errors.
- Factions: enemy AI contract and combat test 134/134.
- Companions: Warden/pet contract, commands, revive and manager test 78/78.
- Progression: four-slot starter kit and v2 migration, viewmodel coverage, bindings, map presets, quick-mode clock, enemy catalog, zoom values, mechanic/perk gates, XP math and pressure curve; 143/143 checks.
- UI: navigation (including Quick Deploy), screens, HUD (minimap/map/scope/aim sight/tracker), paused inventory overlay, accessibility and profile mutations 47/47; 17 screen captures + 4 new-feature captures.
- World: 16 default POIs + roadside, 3 exfils, 2 spawns, navmesh, collision and map texture; generation about 1.1 s.

## 6. Future backlog

1. Windows installer (Inno Setup or MSIX) and Authenticode code signing on top of the delivered export.
2. Daily seed contract and local leaderboards.
3. Full grenade selection and three distinct grenade behaviors.
4. Freeform outpost grid placement with rotation/refund and power adjacency.
5. Weapon mastery tracks, more weapon mods and attachment visuals.
6. Co-op support (server-authoritative) as a separate architecture track.
7. More POI kits, boss arenas and narrative codex entries.
8. Performance profiling at 1440p/ultrawide and formal 1% low capture.
