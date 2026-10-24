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

- **Deployment:** 18 minutes in Normal mode; Quick mode runs the same clock at 2x, so a normal drop lands around 9 real minutes. The Collapse storm begins at a difficulty-scaled point between roughly 12:00 and 9:45 of run time and consumes the map by the end.
- **Objectives:** contract site counts scale from 3 to 6 with difficulty, and every run also seeds side objectives: recoverable supply caches, marked elite bounties and a Rift Shrine. Completing objectives increases payout, XP and exfil security; side objectives are optional but rewarding.
- **Exfil:** call a beacon at any time. Survive a **75-second game-time hold** while the Reach sends a response. Loot in the satchel is banked only on extraction.
- **Death:** the player enters a 20-second downed state. Hold E to self-stabilize once per run, or let a Warden/Driftling revive you. If bleedout ends, the run ends and the satchel is lost. XP, equipped gear, and codex progress remain.
- **Difficulty:** four named, map-linked presets (Patrol on Verdant Verge, Contact on Ashen Shelf, Breach on Glass Expanse, Collapse on Rift Scar) set enemy density, elite chance, hostile cap, guard counts, mission count, side-cache count, enemy durability/damage, storm timing and reward. Up to 8 mutators stack further risk (Swarm, Early Storm, Low Gravity, Rich Reach, Ironhide, Hunter Season, No Second Chances, Overcharged).
- **Modes:** **Normal** (1x clock) and **Quick** (2x clock, half the real-time run, unchanged rewards). Quick mode also compresses the storm, exfil hold, world-event timings and reinforcement director; player movement and combat stay real-time.
- **Repeatability:** seeded maps and POIs, map-preset identity, random contract board, Rift Shrines granting run-only Rift Mods, elite affixes, boss hunts, weapon/gear builds, Warden and pet progression, outpost tiers, records and codex.

## 4. The world

**Scale:** a finite, dense **1.8 km × 1.8 km** region generated at deployment (not a seamless infinite world). The whole region is built behind a loading screen; navigation is baked asynchronously.

**Biomes** blend through a noise-driven weight field:

- **Verdant Basin** — teal coral growth, shallow water, alien ruins.
- **Ashen Canyons** — terraced ochre mesas, industrial bones, dust.
- **Glass Flats** — pale cracked plains, reflective shards, monoliths.

**POIs (16–20 per run):** a Warden outpost landmark, 2 faction camps, 2 relay spires, a crash site, a vault, an anomaly, a ruin field, an Ashen stockade, a Bloom hive, a Choir listening post, colony ruins, and 3 exfil pads, plus preset-specific survey camps, relays and ruins on harder maps. Sixteen to twenty-two small roadside outbuildings (checkpoints, relay boxes, ruined walls) make the road network feel inhabited. Each POI is a handcrafted modular kit assembled on a seeded pad, with a clear combat centre and cover ring. Roads with teal pylons connect the frontier. Roughly 5,000–9,000 MultiMesh scatter instances and 52 horizon spires carry the sense of scale.

**Map presets:** each difficulty owns a named map identity that selects a biome-emphasis rotation, sky/sun/fog mood, extra POIs, roadside density and scatter density:

| Preset | Difficulty | Mood |
|---|---|---|
| Verdant Verge | Patrol | warm late afternoon, teal growth |
| Ashen Shelf | Contact | burnt-orange dusk, low sun, heavy dust |
| Glass Expanse | Breach | pale overcast, high sun, thin bright fog |
| Rift Scar | Collapse | violet storm sky, dim sun, dense volumetric fog |

**Events and objectives:** salvage caches, relay sabotage, elite headhunts, rescue signals, anomaly surveys, and Vault breaches. Twelve world events (faction skirmishes, supply drops, convoys, wandering elites, rift surges/echoes, fog, jammers) create emergent opportunities, and four timed endgame pressure events escalate the final third of a run. Factions can fight each other if the player engineers it.

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
| Combat Knife | issued melee | fast, silent, no ammo, always in slot 4 |

The default loadout has two primary slots, one sidearm slot and a built-in knife. New Wardens start with the Sable Rail sniper, Lattice AR and Sidewinder; existing saves migrate non-destructively into the extra primary slot. ADS zoom is per weapon: assault rifles and SMGs zoom modestly, the DMR reaches 2×, and the Sable Rail reaches roughly 2.9× with a full scope overlay. Every other firearm adds a style-specific iron sight and HUD reticle. Loot variants add rarity and 1–3 affixes. Weapon skins tint the viewmodel. Status effects: **Shock**, **Burn**, **Corrode**, **Slow**. Weakpoints and critical hits reward precision.

### Disciplines and abilities

Four disciplines give identity through an ultimate and a passive tree:

- **Vanguard** — durability, crowd control, Aegis Wall.
- **Infiltrator** — mobility, stealth, critical aggression.
- **Engineer** — deployables, turrets, pet synergy.
- **Pathfinder** — recon, marksman handling, graviton control.

**12 actives:** Blink Step, Aegis Wall, Phase Cloak, Overclock, Arc Chain, Graviton Well, Seismic Slam, Deploy Turret, Pulse Scan, Mender Field, Havoc Barrage, Temporal Fold.
**4 ultimates:** Iron Tide, Ghost Protocol, Siegeworks, Hyperfocus.
**16 passives** across four discipline trees, with tier-level requirements (1 / 4 / 7 / 10). Ten field mechanics also unlock through levels. Loadout equips two actives plus the discipline ultimate. Respec at the Waystation.

**Rift Mods** are run-only build-shapers found at shrines or elite drops: Volatile Rounds, Conductor, Siphon, Tailwind, Drone Commander, Ricochet, Executioner, Overload Core, Scavenger, Phase Shift, Hardlight, Last Stand.

### Enemies

- **Ashen:** Scrapper, Marksman, Bulwark, Sapper (volatile death), Hound, Warlord (elite).
- **Bloom:** Stalker, Spitter, Burrower, Lasher, Seeder, Hydra (elite).
- **Choir:** Sentinel, Nullifier, Wisp, Weaver, Herald (elite).
- **Other elites:** Ash Reaver, Bloom Matriarch, Choir Prime — with armored/shielded/berserk/volatile affixes.
- **Bosses:** **The Warden**, **Bloomheart**, and the **Rift Colossus** (three phases each), encountered through Vault contracts or the high-difficulty final stand.

AI uses vision + LOS + hearing, alert propagation, ranged telegraphs, melee lunges, cover/strafe behavior, status reactions, boss phases and fair spawn rules. Every hostile carries a billboard health bar (plus a shield strip when shielded) above its head; elites and bosses get larger range and gold trim. Enemies drop salvage and gear.

## 6. Progression

- **Profile level 1–30.** Each level grants 1 skill point and 2 attribute points. Kills now feed run XP (with contract/objective bonuses and difficulty multipliers), and the results screen shows XP breakdown, level gains, points and newly unlocked mechanics/abilities.
- **Difficulty:** Patrol, Contact, Breach and Collapse presets set threat, enemy density, elite chance, hostile cap, guard counts, mission and side-cache counts, enemy durability/damage, storm timing and reward multipliers. Each is tied to its own map preset.
- **Attributes:** Power (damage), Resolve (health/shield/armor), Agility (speed/handling/reload), Tech (cooldowns/deployables/loot fortune).
- **Gear:** primary 1, primary 2, sidearm, helmet, chest, legs, cloak, charm. Five rarities, affixes, four armor sets with 3-piece bonuses. The combat knife is issued equipment and has no locker item.
- **Wear:** six suits, eight dyes, eight weapon skins, three pet shells. Cosmetics are previewed in the Locker; weapon skins also apply in first person.
- **Currency:** Salvage (common) and Rift Cores (rare). Sources: extraction, objectives, elite/boss kills, contracts. Sinks: crafting/upgrades, module tiers, squad/pet ranks, cosmetics.
- **Wardens:** Mara Voss (medic), Rook (heavy), Irie Sol (scout), Toma Nix (engineer). Two active; follow/hold/focus/revive commands; downed states; ranks.
- **Driftlings:** Mote (support shield), Cinder (combat bolt), Pip (scan/loot utility). Cosmetic shells, rank bonuses, self-repair.
- **Waystation Kestrel:** 8 modules × 3 tiers. Command Nexus, Foundry, Armory, Infirmary, Barracks, Drift Den, Reactor, Signal Array. Upgrades are persistent and affect future runs.

## 7. UI, art and audio direction

**UI:** a single dark-glass theme built from tokens: ink `#0B1114`, surface `#121A1D`, ivory `#F4EFE5`, muted `#93A5A8`, mint `#62E6C3`, amber `#FFB866`, danger `#FF6E6E`. Typography is Sora (display), Inter (body), JetBrains Mono (numbers). 8 px spacing rhythm, 12 px radii, thin borders, generous whitespace, one primary action per screen. The entry hierarchy is Quick Deploy first, Hub second. The interface is icon-first: the removed explanatory copy lives in tooltips, stats use line-icon + figure pairs, and tabs/cards/actions carry glyphs. All screens are container-driven and tested down to 1280×720.

**HUD:** minimap top-left with objectives and the FIELD OPS tracker below it, vitals bottom-left, ability tray bottom-centre, four-slot weapon/ammo block bottom-right, compass and Collapse timer top-centre (with map/difficulty/mode identity), squad top-right, radio subtitles centre-bottom, capped notification feed, boss bar, damage arcs, precision scope, style-specific ADS sight and crosshair. Pressing I pauses into the field inventory (loadout, gear, satchel loot, rift mods). Information is readable at a glance and never blocks combat.

**Art:** sunlit stylized low-poly, with four map moods. Warm low sun, volumetric dust, ringed gas giant, ivory brutalist ruins, rust and teal; Ashen Shelf runs orange dusk, Glass Expanse pale overcast, Rift Scar violet storm. Faction silhouettes and emissive weakpoints are designed for readability. Everything is generated from primitives and custom shaders; no external art assets.

**Audio:** original procedural SFX (layered weapons, impacts, abilities, UI, footsteps, storm) and a looping ambient music bed that shifts mood between the menu, hub and deployment. Radio dialogue is text with subtitles. No voice acting.

## 8. Session arc

A typical session: choose Quick Deploy (map/difficulty/mode) or check the contract board (2 min) → adjust loadout and squad (2 min) → deploy (18 min normal, ~9 min quick) → fight through 3–6 objective sites plus caches/bounties, loot elites, maybe take a Rift Shrine gamble → call the Kestrel dropship from an exfil pad and hold (75 sec game time) → results with recovered items and spend rewards (3–5 min) → one more run with a different build or map. A first-time player should have a complete run inside the first 20 minutes; a veteran should be chaining Threat 3 Vault hunts.

## 9. What "done" means for this version

A feature-complete single-player vertical slice with the systems and content above, polished enough to play end-to-end without developer intervention. It is not a live-service game and not a full commercial campaign. The roadmap beyond this build: a map overlay, full grenade selection, freeform outpost placement, daily seeds/leaderboards, co-op, more biome kits, more boss arenas, and a standalone export pipeline.
