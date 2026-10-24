# RIFTWARD — full feature list

The README keeps the highlights; this is the complete inventory, verified against `ContentDB` and the
test suites. If you change content counts, update this file too.

---

## World

- Seeded **1.8 km x 1.8 km** frontier, rebuilt per drop from the run seed.
- **3 blended biomes** (Verdant Basin, Ashen Canyons, Glass Flats) with weighted blending.
- **16–20 points of interest** depending on the map preset: Warden outpost, faction camps, relay spires,
  crash site, vault, anomaly, ruin field, Ashen stockade, Bloom hive, Choir listening post, colony ruins,
  and three exfil pads.
- **16–22 roadside outbuildings** placed along road polylines: checkpoints, relay boxes, ruined walls.
- Roads, landmark structures, roughly **5,000–9,000 MultiMesh scatter instances**.
- **Four sky/fog moods**, one per difficulty preset (Verdant late afternoon, Ashen dusk, Glass
  overcast, Rift storm).
- Asynchronous navmesh bake over 8x8 terrain chunks (cell 2.0 m, agent height 1.9 m, radius 1.3 m).

## Run loop

- **Quick Deploy preflight** with four difficulty/map presets and **Normal (18 min) or Quick (9 min,
  2x clock)** mode.
- Six contracts plus side objectives: loot caches, bounties, Rift Shrines.
- **75-second exfil hold** with a visibly descending Kestrel dropship.
- Shrinking **Collapse storm**, late-run reinforcement director, timed endgame pressure events.
- Death, downed, bleedout and self-revive paths; results screen with recovered items and profile rewards.

## Enemies

- **14 base archetypes** across the Ashen, Bloom and Choir.
- **6 elites** with random affixes and **3 bosses** with phases.
- Perception, cover and strafing behaviour, telegraphed attacks, status effects, sapper volatile death.
- Billboard health/shield bars above every hostile; weak-point headshots.

## Weapons

- **10 weapons**: assault rifle, SMG, shotgun, DMR, rail sniper, LMG, sidearm, grenade launcher, arc
  rifle, corrosive carbine.
- **Four slots**: two primaries, a sidearm and the issued Combat Knife.
- Per-weapon ADS reticles, DMR/rail scope overlay, rarity variants and affixes.
- Procedurally built first-person viewmodels; weapon skins tint them.

## Skills and progression

- **12 active abilities**, **4 discipline ultimates**, **16 passive perks** with level requirements,
  **12 run-only Rift Mods**, **4 disciplines** (Vanguard, Infiltrator, Engineer, Pathfinder).
- **10 level-gated field mechanics** unlocked through play.
- Warden levels **1–30**, kill-sourced run XP, +1 skill point and +2 attribute points per level.
- Four attributes, derived stats, gear/perk/base modifiers, crits, armor, shields, status effects.

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
- Outpost diorama and persistent layout data.

## UI and HUD

- **13 data-driven screens** plus HUD and a paused inventory overlay.
- Icon-first menu language with tooltips; Sora, Inter and JetBrains Mono.
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

- 6 contracts, 8 mutators, 12 Rift Mods, **12 world events** (2 scheduled per run), Rift Shrines and
  random elite affixes.

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
