# RIFTWARD — full feature list

The README keeps the highlights; this is the complete inventory, verified against `ContentDB` and the
test suites. If you change content counts, update this file too.

---

## World

- Seeded **1.8 km x 1.8 km** frontier, rebuilt per drop from the run seed.
- **5 planets** — Meridian-9 (Verdant Basin / Ashen Canyons / Glass Flats), Cinder-4 (Basalt Shelf /
  Ember Canyon / Ash Flats), Thalassa-2 (Tidal Shelf / Kelp Basin / Salt Flats), Frost-9 (Glacier Shelf /
  Frozen Canyon / White Expanse) and Nyx-12 (Rift Steppe / Null Basin / Echo Flats) — each with its own
  palette, sky keyframes, weather pool and fluid configuration.
- **12 selectable map presets** — eight core frontier maps plus Frost-9 and Nyx-12 additions; a
  difficulty still picks the featured map, and Quick Deploy/Hub let you override it. Preset weather
  pools override the planet pool so one planet can drop under different conditions.
- **17–21 points of interest** plus a derelict freighter: Warden outpost, faction camps, relay spires,
  crash site, vault, anomaly, ruin field, Ashen stockade, Bloom hive, Choir listening post, colony
  ruins, a landed freighter and three exfil pads.
- **16–22 roadside outbuildings** placed along road polylines: checkpoints, relay boxes, ruined walls.
- **Enterable interiors** in the faction camp command hab, Vault bunker, crash-site hull, colony hab,
  Choir bunker, Ashen command hall and the derelict freighter; interiors are real geometry with
  loot/enemy anchors, not scene transitions.
- **Water and lava basins** carved into low ground, with animated surfaces, shoreline props, map
  tinting and analytic gameplay queries (wading, swimming, heat damage).
- **Seeded weather** (18 states across the planets: clear, overcast, rain, squall, dust, ashfall,
  ember storm, heat haze, rift storm, fog front, spore drift, rift winds, ion tempest, meteor shower,
  toxic squall, glacier front, whiteout and rift cyclone) with fog/sky/sun transitions, particles,
  lightning and a vision-range modifier for enemies. The HUD shows the active weather and local clock.
- **Day/night cycle** with per-planet day length, four sky keyframes, a moving sun, stars and a
  night headlamp; Blackout inserts runs late in the night cycle.
- Roads, landmark structures, roughly **5,000–9,000 MultiMesh scatter instances**.
- Asynchronous navmesh bake over 8x8 terrain chunks (cell 2.0 m, agent height 1.9 m, radius 1.3 m).

## Under-reach dungeons

- **3 themed kits** — Rift Vault (Choir), Ashen Mine (lava-lit tunnels) and Choir Catacomb — with
  seeded 3x3 room layouts, 5–9 rooms, corridors, bulkheads and a boss chamber.
- **2–3 entrances per run** at vault/choir/stockade/colony/freighter POIs; entrances are pre-baked
  during the loading screen and entered by interaction.
- Each instance spawns room packs, an elite guard, a theme boss, 2–4 loot caches and its own baked
  navmesh; the storm pauses inside, the run clock does not, and exfil is unavailable underground.
- Guardian kills bank dungeon clears in records and can satisfy staged contract objectives.

## Field Training

- A **five-stage guided onboarding run** for new profiles: move/look, aim/fire, ability, loot, exfil.
- HUD training card with stage title, copy, key hints and a live progress bar; pause → **Skip
  Training**, replay from the main menu at any time.
- Completion persists `tutorial_done`, grants a small starter reward and never counts as a
  deployment/death record.

## Run loop

- **Quick Deploy preflight** with four difficulty presets, 5 planets and 12 maps to inspect, image-first
  planet portraits/map thumbnails, and **5 game modes**:
  - **Normal** — 18-minute run clock, 1x time, standard density and rewards.
  - **Quick** — the same 18-minute run clock at **2x**, so a run lasts about 9 real minutes.
  - **Blackout** — night insertion (clock starts near midnight), 1.15x reward and 10% loot bonus.
  - **Gauntlet** — a 14-minute run clock with the Collapse starting earlier (45% storm fraction),
    higher density and elite odds, 1.35x reward.
  - **Onslaught** — 1.35x density, +20% elite odds, 1.5x reward, +12 hostile budget, +5% loot.
- **13 contracts** (7 classic + 6 staged, including Beacon Hunt, Whiteout Run and Sovereign Hunt) and
  side objectives: loot caches, bounties, Rift Shrines.
- **75-second exfil hold** with a visibly descending Kestrel dropship.
- Shrinking **Collapse storm**, late-run reinforcement director, timed endgame pressure events.
- **20 weighted world events**; three fire per run and drive weather, waves, loot and the storm clock.
  The HUD shows each as a **Reach Event** banner (icon, title, description) and the Codex documents them.
- Death, downed, bleedout and self-revive paths; results screen with recovered items and profile rewards.

## Enemies

- **20 base archetypes** across the Ashen, Bloom and Choir, including Cinder-4, Thalassa-2 and the new
  frontier natives (Cinder Husk, Magma Brute, Brine Lurker, Reef Stalker, Tide Sentinel, Void Wisp).
- **11 elites** with random affixes — Ash Reaver, Bloom Matriarch, Choir Prime, Ashen Warlord, Bloom Hydra,
  Choir Herald, Caldera Warlord, Abyss Matriarch, Ashen Ironjaw, Bloom Thornmatron and Choir Signal
  Warden — and **6 bosses** with phases (The Warden, Bloomheart, Rift Colossus, Cinder Titan, Leviathan,
  Hollow Sovereign).
- Perception, cover and strafing behaviour, telegraphed attacks, status effects, sapper volatile death.
- Habitat-aware spawns: water natives avoid dry POIs, lava natives avoid the surface, weather reduces
  enemy vision range.
- Billboard health/shield bars above every hostile; weak-point headshots.

## Weapons

- **16 weapons**: assault rifle, SMG, shotgun, DMR, rail sniper, LMG, sidearm, grenade launcher, arc
  rifle, corrosive carbine, Ember Thrower, Tide Carbine, Quarry HMG, Mirage DMR, Scatter Arc and
  Ripper SMG.
- **Four slots**: two primaries, a sidearm and the issued Combat Knife.
- Per-weapon ADS reticles, DMR/rail scope overlay, rarity variants and affixes.
- Procedurally built first-person viewmodels; weapon skins tint them.

## Skills and progression

- **24 abilities** (20 active + 4 ultimates) including Ember Ward, Tide Step, Bulwark Stance, Quake
  Step, Smoke Veil, Repair Drone, Mine Layer and Zip Line.
- **24 passive perks** across four disciplines, **12 run-only Rift Mods**, **4 disciplines**
  (Vanguard, Infiltrator, Engineer, Pathfinder).
- **10 level-gated field mechanics** unlocked through play.
- Warden levels **1–30**, kill-sourced run XP, +1 skill point and +2 attribute points per level.
- Four attributes, derived stats, gear/perk/base modifiers, crits, armor, shields, status effects,
  hazard resistance and swim speed.

## Wardens and pets

- **4 recruitable Warden AI** companions — medic, heavy, scout, engineer — **2 active** at a time.
- Commands: follow, hold, focus, revive; downed and revive behaviour; barks and ranks.
- **3 Driftlings** (Mote, Cinder, Pip) with support/combat/utility abilities and cosmetic shells.

## Gear and cosmetics

- **8 equipment slots**: two primaries, sidearm, five armor.
- **5 rarities**, affixes, **4 armor sets**, **6 suits**, **8 dyes**, **8 weapon skins**, **3 pet shells**.
- New Warden profiles start with a sniper, a rifle, a sidearm and the issued knife.

## Outpost

- **8 buildable/upgradable modules**, **3 tiers** each, gated by power and Nexus level.
- Visual-first bay: an **8×8 outpost diorama (layout v2)** with one code-drawn isometric structure per
  module, tier pips, built/planned/road legend, module icons in the list/detail cards and click-to-select
  hit rects. Invalid or pre-v5 layouts are rebuilt safely without touching module tiers or currency.
- Save format **v5** adds the versioned layout payload (`base_layout_version` 2) beside the existing
  module tiers and currencies; older saves migrate in place.

## UI and HUD

- **13 data-driven screens** plus HUD and a paused inventory overlay, all icon-first with tooltips;
  bundled Sora, Inter and JetBrains Mono fonts.
- **Deployment loading cinema** — a four-act drop feed replacing the old progress page:
  **Threat Signature** (code-drawn boss dossier with weak points, phases, integrity/shield bars and
  counter-intel), **Rift Breach**, **Drop Descent** (first-person pod footage with telemetry and
  altitude tape) and **Touchdown**. Shots are deterministic, asset-free and tinted by the selected
  map/planet, the boss is drawn from that planet's roster and run seed, and the live progress bar,
  step label and field notes stay visible throughout. Space/Enter skips to a static briefing;
  reduced-motion uses the same static boss card.
- **Visual-first expansion screens**: Loadout/Locker item art (weapon and gear silhouettes), compact
  Warden previews for cosmetics, skills medallions, squad Warden portraits and Driftling art, and the
  outpost diorama. Quick Deploy uses planet portraits and map thumbnails; the Codex adds Weather and
  Operations tabs with portraits, thumbnails, medallions and target rosters.
- **12 new line icons** (weather snow/ion/void/meteor/toxic, Ashen/Bloom/Choir faction sigils and four
  discipline sigils) on top of the existing bundled set; reusable code-drawn components
  (`UIIconMedallion`, `UIItemArt`, `UIPlanetPortrait`, `UIMapThumbnail`, `UIAllyPortrait`, `UIPetArt`).
- **Reach Event HUD banner** with queued, reduce-motion-aware world-event notifications.
- **Display settings** — window mode, resolution, V-Sync, render scale, anti-aliasing, frame-rate cap,
  quality preset and interface scale, applied live and persisted.
- Top-left tactical minimap and **M-key full map** with building, cache and bounty markers.
- FIELD OPS distance/direction tracker, per-weapon ADS aim sights, precision scope.
- Toast/subtitle system; accessibility options (UI scale, high contrast, reduced motion, subtitles,
  damage numbers, separate mouse/ADS sensitivity).
- Full key rebinding with duplicate-binding protection and one-click reset; keyboard, mouse and gamepad
  focus navigation.

## Audio

- Procedurally synthesised SFX with 2D/3D pools and a looping ambient music bed. No external audio
  assets.

## Randomisation

- 13 contracts (7 classic + 6 staged), 8 mutators, 12 Rift Mods, **20 world events** (3 scheduled per
  run), Rift Shrines and random elite affixes. World events are documented in the Codex and announced by
  the HUD Reach Event banner.

---

## Controls

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Sprint | Shift | L3 |
| Crouch / slide | Ctrl or C | B |
| Jump | Space | A |
| Fire | LMB | RT |
| Aim down sights | RMB | LT |
| Reload | R | X |
| Interact / revive | E | Y |
| Ability 1 / Ability 2 | Q / F | LB / RB |
| Ultimate | X | D-pad Up |
| Melee shove / quick knife | V | R3 |
| Frag grenade | G | D-pad Down |
| Weapon slots | 1 / 2 / 3 / 4 | - |
| Cycle weapon | Mouse wheel | - |
| Inventory and satchel | I | - |
| Call extraction ship (at an exfil pad) | E or H | Y |
| Squad command | Z | D-pad Left |
| Pet command | B | D-pad Right |
| Minimap / tactical map | M (overlay unlocks at level 2) | Back |
| Pause | Esc | Start |
| Self-revive (when downed) | Hold E | Hold Y |
