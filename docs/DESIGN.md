# RIFTWARD — Game Design

> **Drop into the Reach. Build what survives.**

## 1. Fantasy and setting

**RIFTWARD** is a solo sci-fi extraction FPS about a freelancer working the edge of a collapsing colony world. The **Reach** rewrites itself every time it folds: canyons become coral basins, relay spires surface in glass flats, and the dead do not stay where you left them. You are a **Riftwarden** operating from **Waystation Kestrel**, the last place on Meridian-9 that still takes contracts.

Three factions make the frontier legible and dangerous:

- **The Ashen** — human scavengers who strip the colony for parts and grudges.
- **The Bloom** — a luminous alien ecology that treats the Reach as a body and the player as an infection.
- **The Choir** — caretaker machines that survived their makers and now disagree with everyone about what "care" means.

The tone is **sunlit, strange and hopeful**, not grimdark. The world is beautiful; the people in it are tired; the player is the reason both might survive.

## 2. Design pillars

1. **Expressive combat.** Precise gunplay, readable recoil, movement, abilities and build synergies. Every fight should allow a smart or stylish solution.
2. **A frontier worth crossing.** Landmarks every 30–45 seconds, three biomes in one map, secrets and events that reward curiosity. Density over raw map size.
3. **Greed versus extraction.** Loot has to be carried out. Exfil is a decision, not a button. Death costs the satchel, not the save.
4. **A home that grows.** The Waystation visibly and mechanically improves; Wardens and Driftlings become part of the fantasy.
5. **Clean, modern identity.** Warm light, bold geometry, restrained HUD, generous spacing, and a UI that feels like a premium field terminal.

## 3. Core loop

`Main Menu → Quick Deploy (difficulty + map + mode) or Waystation → Contract Board → Loadout → Deploy → Explore / Fight / Loot → Secure Objectives → Call Exfil → Hold → Results → Upgrade → Repeat`

- **Deployment:** 18 minutes in Normal mode; Quick mode runs the same clock at 2x, so a normal drop lands around 9 real minutes. Gauntlet shortens the authored clock to 14 minutes and starts the Collapse significantly earlier; Blackout inserts the run late in the night cycle; Onslaught raises density, elite odds and rewards. The Collapse storm begins at a difficulty/mode-scaled point and consumes the map by the end.
- **Objectives:** contract site counts scale from 3 to 6 with difficulty, and every run also seeds side objectives: recoverable supply caches, marked elite bounties and a Rift Shrine. Completing objectives increases payout, XP and exfil security; side objectives are optional but rewarding.
- **Exfil:** call a beacon at any time. Survive a **75-second game-time hold** while the Reach sends a response. Loot in the satchel is banked only on extraction.
- **Death:** the player enters a 20-second downed state. Hold E to self-stabilize once per run, or let a Warden/Driftling revive you. If bleedout ends, the run ends and the satchel is lost. XP, equipped gear, and codex progress remain.
- **Difficulty:** four named presets (Patrol, Contact, Breach, Collapse) set enemy density, elite chance, hostile cap, guard counts, mission count, side-cache count, enemy durability/damage, storm timing and reward. Each has a featured map but the map is independently selectable in Quick Deploy and the Hub. Up to 8 mutators stack further risk (Swarm, Early Storm, Low Gravity, Rich Reach, Ironhide, Hunter Season, No Second Chances, Overcharged).
- **Modes:** **Normal** (1x clock), **Quick** (2x clock, half the real-time run, unchanged rewards), **Blackout** (night insertion, 1.15x reward, +10% loot), **Gauntlet** (14-minute run clock, early Collapse at 45% storm fraction, 1.2x density, +10% elites, 1.35x reward, +8 hostile budget) and **Onslaught** (1.35x density, +20% elites, 1.5x reward, +12 hostile budget, +5% loot), plus **Field Training** (guided onboarding, relaxed clock, no Collapse). Quick mode also compresses the storm, exfil hold, world-event timings and reinforcement director; player movement and combat stay real-time. Modes are authored data (`ContentDB.get_game_modes()`) and their math is covered by the progression suite.
- **Repeatability:** seeded maps and POIs, planet and map identity, weather/day-night seeds, random contract board, staged operations, Rift Shrines granting run-only Rift Mods, elite affixes, boss hunts, dungeon clears, weapon/gear builds, Warden and pet progression, outpost tiers, records and codex.

## 4. The world

**Scale:** a finite, dense **1.8 km × 1.8 km** region generated at deployment (not a seamless infinite world). The whole region is built behind a loading screen; navigation is baked asynchronously.

**Biomes** blend through a noise-driven weight field; each planet remaps the three biome identities:

- **Meridian-9** — Verdant Basin (teal coral, shallow water), Ashen Canyons (ochre mesas, dust), Glass Flats (pale cracked plains).
- **Cinder-4** — Basalt Shelf, Ember Canyon and Ash Flats, with lava basins, ember storms and heat haze.
- **Thalassa-2** — Tidal Shelf, Kelp Basin and Salt Flats, with deep water, rain, squalls and fog fronts.

**POIs (17–21 per run):** a Warden outpost landmark, 2 faction camps, 2 relay spires, a crash site, a vault, an anomaly, a ruin field, an Ashen stockade, a Bloom hive, a Choir listening post, colony ruins, a landed derelict freighter, and 3 exfil pads, plus preset-specific survey camps, relays, ruins and wrecks. Sixteen to twenty-two small roadside outbuildings (checkpoints, relay boxes, ruined walls) make the road network feel inhabited. Several POIs are **enterable** (camp hab, Vault bunker, crash hull, colony hab, Choir bunker, Ashen command hall and the freighter) with interiors, loot and garrison anchors. Roads with teal pylons connect the frontier. Roughly 5,000–9,000 MultiMesh scatter instances and 52 horizon spires carry the sense of scale.

**Map presets:** twelve named maps across five planets. A difficulty keeps a featured map, but Quick Deploy and the Hub let the player override it. Each preset selects a biome-emphasis rotation, sky/sun/fog mood, extra POIs, roadside density, scatter density, fluid budget, a preset-level weather pool and start time of day.

| Planet | Maps | Mood |
|---|---|---|
| Meridian-9 | Verdant Verge, Ashen Shelf, Glass Expanse, Rift Scar | warm late afternoon → dusk → pale overcast → violet storm |
| Cinder-4 | Cinder Caldera, Ember Reach | basalt shelves, lava basins, burnt-orange skies, ember storms, meteor showers |
| Thalassa-2 | Tidal Shelf, Brine Expanse | drowned shelves, kelp basins, salt flats, rain, toxic squalls and fog fronts |
| Frost-9 | Glacier Shelf, White Expanse | pale ice shelves, frozen canyons, glacier fronts and whiteouts |
| Nyx-12 | Null Steppe, Echo Basin | rift steppes, null basins, ion tempests, rift cyclones and violet skies |

**Weather and time:** every planet has a seeded weather pool (18 states total) that changes fog, sky, sun energy, particles, lightning and enemy vision range, and a day/night cycle with four sky keyframes, a moving sun, stars and a night headlamp. Preset weather pools override the planet pool, so an expedition can force conditions such as an ion tempest, meteor shower, toxic squall, glacier front, whiteout or rift cyclone. The HUD shows the local clock, active weather and a **Reach Event** banner for world events. Water and lava basins are carved into low ground: water grants buoyancy and swim speed, lava deals heat damage and slows movement.

**Under-reach dungeons:** three themed kits (Rift Vault, Ashen Mine, Choir Catacomb) generate 5–9-room interiors with corridors, bulkheads, a boss chamber, elites, loot and a private navmesh. Two to three hatches spawn per run at vault/choir/stockade/colony/freighter POIs. The storm pauses underground; the run clock and extraction pressure do not. Dungeon clears can satisfy staged contract objectives.

**Field Training:** a five-stage guided run (move/look, aim/fire, ability, loot, exfil) with a HUD training card, skip and replay. It is the first drop for a new profile and persists completion.

**Events and objectives:** salvage caches, relay sabotage, elite headhunts, rescue signals, anomaly surveys, Vault breaches and Black Box recovery, with six staged operations (Vault Descent, Relay Chain, Tidal Survey, Beacon Hunt, Whiteout Run and Sovereign Hunt). **Twenty world events** (faction skirmishes, supply drops, convoys, wandering elites, rift surges/echoes, fog, jammers, meteor strikes, rift cyclones, toxic drift, whiteouts, scavenger convoys, bounty brokers, distress beacons and collapse tremors) create emergent opportunities; **three weighted events fire per run** and four timed endgame pressure events escalate the final third of a run. Factions can fight each other if the player engineers it.

**Navigation:** compass waypoints, world-space beacons over buildings and objectives, plus a top-left tactical minimap and a HUD FIELD OPS tracker with distance/direction. The M-key overlay shows the full Reach map, objectives, exfils, buildings, caches, bounties, live hostiles and allies. The minimap is north-up and does not pause the game.

## 5. Combat

### Player verbs

Sprint, slide, jump, crouch (Ctrl or C), ADS with per-weapon style reticles and DMR/rail scopes, mantle-friendly terrain, four-slot weapon switching (two primaries, sidearm, issued knife), quick knife melee, frag grenade, two active abilities, one ultimate, squad commands, pet assistance, interaction, paused inventory/satchel and self-revive. Slide, melee, grenade, full map, and squad/pet commands unlock by Warden level. Movement is physics-ticked; camera recoil is separate from aim and recovers predictably.

### Weapons

| Weapon | Role | Signature |
|---|---|---|
| Lattice AR | balanced assault rifle | learnable recoil |
| Wisp SMG | close-range | fast handling, heavy bloom |
| Breakline | pump shotgun | 8 pellets, devastating inside 8 m |
| Longview DMR | precision semi-auto | 2× scope, weakpoint damage |
| Sable Rail | charge sniper | pierces one target |
| Cantor LMG | suppression | big belt, movement penalty |
| Sidewinder | sidearm | 3-round burst, quick swap |
| Havoc GL | launcher | arcing blast |
| Tesla Arc | chain rifle | shock chains to 3 targets |
| Bloom Carbine | corrosive burst | armor shred |
| Ember Thrower | flamer | short-range burn, melts shields |
| Tide Carbine | burst rifle | slows targets in wet terrain |
| Quarry HMG | heavy LMG | huge belt, punishing fire |
| Mirage DMR | precision DMR | long-range weak points |
| Scatter Arc | shock shotgun | arcing pellets in corridors |
| Ripper SMG | high-rate SMG | belt-fed pocket blender |
| Combat Knife | issued melee | fast, silent, no ammo, always in slot 4 |

The default loadout has two primary slots, one sidearm slot and a built-in knife. New Wardens start with the Sable Rail sniper, Lattice AR and Sidewinder; existing saves migrate non-destructively into the extra primary slot. ADS zoom is per weapon: assault rifles and SMGs zoom modestly, the DMR reaches 2×, and the Sable Rail reaches roughly 2.9× with a full scope overlay. Every other firearm adds a style-specific iron sight and HUD reticle. Loot variants add rarity and 1–3 affixes. Weapon skins tint the viewmodel. Status effects: **Shock**, **Burn**, **Corrode**, **Slow**. Weakpoints and critical hits reward precision.

### Disciplines and abilities

Four disciplines give identity through an ultimate and a passive tree:

- **Vanguard** — durability, crowd control, Aegis Wall.
- **Infiltrator** — mobility, stealth, critical aggression.
- **Engineer** — deployables, turrets, pet synergy.
- **Pathfinder** — recon, marksman handling, graviton control.

**20 actives:** Blink Step, Aegis Wall, Phase Cloak, Overclock, Arc Chain, Graviton Well, Seismic Slam, Deploy Turret, Pulse Scan, Mender Field, Havoc Barrage, Temporal Fold, Ember Ward, Tide Step, Bulwark Stance, Quake Step, Smoke Veil, Repair Drone, Mine Layer, Zip Line.
**4 ultimates:** Iron Tide, Ghost Protocol, Siegeworks, Hyperfocus.
**24 passives** across four discipline trees, with tier-level requirements (1 / 4 / 7 / 10 / 13 / 22). Ten field mechanics also unlock through levels. Loadout equips two actives plus the discipline ultimate. Respec at the Waystation.

**Rift Mods** are run-only build-shapers found at shrines or elite drops: Volatile Rounds, Conductor, Siphon, Tailwind, Drone Commander, Ricochet, Executioner, Overload Core, Scavenger, Phase Shift, Hardlight, Last Stand.

### Enemies

- **Ashen:** Scrapper, Marksman, Bulwark, Sapper (volatile death), Hound, Warlord (elite), Cinder Husk, Magma Brute, Caldera Warlord (elite), Ashen Ironjaw (elite).
- **Bloom:** Stalker, Spitter, Burrower, Lasher, Seeder, Hydra (elite), Brine Lurker, Reef Stalker, Abyss Matriarch (elite), Bloom Thornmatron (elite).
- **Choir:** Sentinel, Nullifier, Wisp, Weaver, Herald (elite), Tide Sentinel, Void Wisp, Choir Signal Warden (elite).
- **Other elites:** Ash Reaver, Bloom Matriarch, Choir Prime — with armored/shielded/berserk/volatile affixes.
- **Bosses:** **The Warden**, **Bloomheart**, **Rift Colossus**, **Cinder Titan**, **Leviathan** and **Hollow Sovereign** (three phases each), encountered through Vault contracts, under-reach guardians or the high-difficulty final stand.

AI uses vision + LOS + hearing, alert propagation, ranged telegraphs, melee lunges, cover/strafe behavior, status reactions, boss phases and fair spawn rules. Habitat-aware spawning keeps water natives near basins and lava natives near ember ground; weather reduces vision range; lava and deep water slow or damage enemies. Every hostile carries a billboard health bar (plus a shield strip when shielded) above its head; elites and bosses get larger range and gold trim. Enemies drop salvage and gear.

## 6. Progression

- **Profile level 1–30.** Each level grants 1 skill point and 2 attribute points. Kills now feed run XP (with contract/objective bonuses and difficulty multipliers), and the results screen shows XP breakdown, level gains, points and newly unlocked mechanics/abilities.
- **Difficulty:** Patrol, Contact, Breach and Collapse presets set threat, enemy density, elite chance, hostile cap, guard counts, mission and side-cache counts, enemy durability/damage, storm timing and reward multipliers. Each is tied to its own map preset.
- **Attributes:** Power (damage), Resolve (health/shield/armor), Agility (speed/handling/reload), Tech (cooldowns/deployables/loot fortune).
- **Gear:** primary 1, primary 2, sidearm, helmet, chest, legs, cloak, charm. Five rarities, affixes, four armor sets with 3-piece bonuses. The combat knife is issued equipment and has no locker item.
- **Wear:** six suits, eight dyes, eight weapon skins, three pet shells. Cosmetics are previewed in the Locker; weapon skins also apply in first person.
- **Currency:** Salvage (common) and Rift Cores (rare). Sources: extraction, objectives, elite/boss kills, contracts. Sinks: crafting/upgrades, module tiers, squad/pet ranks, cosmetics.
- **Wardens:** Mara Voss (medic), Rook (heavy), Irie Sol (scout), Toma Nix (engineer). Two active; follow/hold/focus/revive commands; downed states; ranks.
- **Driftlings:** Mote (support shield), Cinder (combat bolt), Pip (scan/loot utility). Cosmetic shells, rank bonuses, self-repair.
- **Waystation Kestrel:** 8 modules × 3 tiers on a versioned **8×8 outpost layout (layout v2, save v5)**. Command Nexus, Foundry, Armory, Infirmary, Barracks, Drift Den, Reactor, Signal Array. Upgrades are persistent and affect future runs; the outpost screen renders the bay as a clickable isometric diorama with built/planned/road states.

## 7. UI, art and audio direction

**UI:** a single dark-glass theme built from tokens: ink `#0B1114`, surface `#121A1D`, ivory `#F4EFE5`, muted `#93A5A8`, mint `#62E6C3`, amber `#FFB866`, danger `#FF6E6E`. Typography is Sora (display), Inter (body), JetBrains Mono (numbers). 8 px spacing rhythm, 12 px radii, thin borders, generous whitespace, one primary action per screen. The entry hierarchy is Quick Deploy first, Hub second. The interface is image-first: reusable code-drawn art components (`UIIconMedallion`, `UIItemArt`, `UIPlanetPortrait`, `UIMapThumbnail`, `UIAllyPortrait`, `UIPetArt`, outpost module art, compact Warden previews) show weapons, gear, planets, maps, people and structures directly; tools, stats and explanations live in icon+figure pairs and tooltips. Quick Deploy presents portraits, thumbnails and mode cards, the Codex gained Weather and Operations tabs, and the Locker, Skills, Squad, Loadout and Outpost screens were rebuilt around their objects. All screens are container-driven and tested down to 1280×720.

**HUD:** minimap top-left with objectives and the FIELD OPS tracker below it, vitals bottom-left, ability tray bottom-centre, four-slot weapon/ammo block bottom-right, compass and Collapse timer top-centre (with map/difficulty/mode identity), weather icon and local clock top-right, squad top-right, radio subtitles centre-bottom, capped notification feed, boss bar, damage arcs, precision scope, style-specific ADS sight and crosshair. A **Reach Event banner** (icon, title, colour, wrapped copy, queued, auto-hide ~7 s, reduce-motion aware) announces world events. The training card replaces the objective stack during Field Training; the dungeon banner replaces the minimap underground; water/lava tint the screen edges. Pressing I pauses into the field inventory (loadout, gear, satchel loot, rift mods). Information is readable at a glance and never blocks combat.

**Art:** sunlit stylized low-poly, with per-planet map moods. Warm low sun, volumetric dust, ringed gas giant, ivory brutalist ruins, rust and teal; Ashen Shelf runs orange dusk, Glass Expanse pale overcast, Rift Scar violet storm; Frost-9 turns the palette to pale ice and blue shadow, Nyx-12 to violet rift light over black basins. Faction silhouettes and emissive weakpoints are designed for readability. Everything is generated from primitives and custom shaders; no external art assets (the 12 new SVG line icons are authored in-repo).

**Audio:** original procedural SFX (layered weapons, impacts, abilities, UI, footsteps, storm) and a looping ambient music bed that shifts mood between the menu, hub and deployment. Radio dialogue is text with subtitles. No voice acting.

## 8. Session arc

A typical session: choose Quick Deploy (planet/map/difficulty/mode) or check the contract board (2 min) → adjust loadout, locker, skills and squad (2 min) → deploy (18 min run clock in Normal; ~9 real minutes in Quick; 14 in Gauntlet) → fight through 3–6 objective sites plus caches/bounties, loot elites, maybe take a Rift Shrine gamble → call the Kestrel dropship from an exfil pad and hold (75 sec game time) → results with recovered items and spend rewards (3–5 min) → one more run with a different build, planet or mode. A first-time player should have a complete run inside the first 20 minutes; a veteran should be chaining Threat 3 Vault hunts or Onslaught elite surges.

## 9. What "done" means for this version

A feature-complete single-player vertical slice with the systems and content above, polished enough to play end-to-end without developer intervention. It is not a live-service game and not a full commercial campaign. The roadmap beyond this build: a map overlay, full grenade selection, freeform outpost placement, daily seeds/leaderboards, co-op, more biome kits, more boss arenas, and a standalone export pipeline.
