# RIFTWARD — itch.io paste-ready fields

Three fields, ready to copy. Each block matches the corresponding box on the itch.io project page.

| itch.io field | Block below |
|---|---|
| *Description — this will make up the content of your game page* | [1. Description](#1-description) |
| *Tags* | [2. Tags](#2-tags) |
| *Download & install instructions* | [3. Download & install instructions](#3-download--install-instructions) |

itch.io's editor is rich text with a Markdown/HTML toggle. Paste as plain text, or switch the editor to
Markdown, and the headings and bullets will format themselves.

---

## 1. Description

```markdown
**RIFTWARD** is a single-player, first-person extraction shooter set on a hostile alien frontier.

You drop into the Reach with a loadout you can afford to lose. Take contracts, loot what you can
carry, fight three hostile factions, and get back to the dropship before the Collapse swallows the map.
What you bring home rebuilds Waystation Kestrel. What you leave behind stays lost.

## The loop

Deployments run on a clock: 18 minutes on Normal, 9 on Quick. Contracts sit alongside optional caches,
bounties and Rift Shrines, so every run becomes the same question — one more detour, or get out?

Calling extraction doesn't end the run. A dropship has to arrive and hold the pad for 75 seconds while
the map closes in around you. Pick the wrong moment and the storm takes everything.

## The frontier

- A seeded 1.8 km x 1.8 km region, rebuilt on every drop
- Three blended biomes and four map moods, one per difficulty preset
- 16-20 points of interest — stockades, hives, listening posts, colony ruins — plus roads, roadside
  outbuildings and landmark structures
- Late-run pressure: a shrinking Collapse storm, a reinforcement director and timed endgame events

## Combat

- 10 weapons across four slots: two primaries, a sidearm and an issued Combat Knife
- Per-weapon ADS sights, a DMR and rail scope overlay, rarity variants and affixes
- 12 active abilities, 4 discipline ultimates, 16 passive perks and 12 run-only Rift Mods
- 14 enemy archetypes, 6 elites with affixes and 3 bosses with phases, across the Ashen, Bloom and Choir
- Weak points, status effects, cover use, strafing and telegraphed attacks

## A squad that fights with you

Recruit four Warden AI companions — medic, heavy, scout, engineer — with two active at once, plus three
Driftling pets. Issue follow, hold, focus and revive orders, and pick them up when they go down.

## A home that grows

Eight outpost modules with three tiers each, gated behind power and Nexus level. Every extraction feeds
the next deployment.

## Progression

Warden levels 1-30 across four disciplines, with gear in eight slots, five rarities, affixes and armor
sets to chase between runs.

## Good to know

- Single-player and offline only — no co-op, no PvP, no online play
- No mid-run save: quitting during a deployment abandons that run
- Keyboard and mouse, full gamepad support, every action rebindable
- Windows 10/11 64-bit, DirectX 12 GPU, 4 GB RAM (8 GB recommended), about 150 MB of disk space
- Built in Godot 4.7.2. All geometry, materials, effects and audio are generated procedurally in-engine,
  with no external models or paid assets

Install instructions, controls and troubleshooting are on the download page. Mind the storm.
```

**Tip:** put your two strongest screenshots directly under the first paragraph — most people decide in
the first screen of the page. Use `captures/qa_exfil_ship.png` first, then `tests/artifacts/deployment.png`.

---

## 2. Tags

itch.io allows **up to 10 tags**, lowercase with hyphens. Paste these:

```text
first-person, shooter, fps, sci-fi, singleplayer, 3d, procedural-generation, extraction-shooter, godot, atmospheric
```

| Tag | Why it earns a slot |
|---|---|
| `first-person` | Primary camera and gunplay |
| `shooter` | Broad discovery category |
| `fps` | How most people search for this |
| `sci-fi` | Setting and art direction |
| `singleplayer` | Filters out everyone looking for co-op — important, since there is none |
| `3d` | Dimension filter |
| `procedural-generation` | A real selling point of the world |
| `extraction-shooter` | The genre niche; use `extraction` if the picker doesn't offer the longer form |
| `godot` | Engine tag, a real discovery channel on itch.io |
| `atmospheric` | Matches the map moods and score |

**Reserve tags** if you want to swap any out: `roguelite` (runs are run-based with persistent meta
progression, so it is defensible), `survival`, `action`, `aliens`, `guns`.

**Avoid** `multiplayer`, `co-op`, `online`, `pvp`, `browser` — none of them are true, and wrong tags cost
you more in disappointed players than they gain in reach.

Also set **Genre: Shooter** (the dropdown), not just tags.

---

## 3. Download & install instructions

```markdown
## How to install

1. **Download** `RIFTWARD-win64.zip` (about 40 MB) with the button above.
2. **Unzip it** anywhere you like — for example `C:\Games\RIFTWARD`. Right-click the zip and choose
   *Extract All*.
3. **Keep `RIFTWARD.exe` and `RIFTWARD.pck` in the same folder.** Don't move one without the other, and
   don't run the .exe from inside the zip viewer.
4. **Run `RIFTWARD.exe`.**

There is no installer and no admin rights are needed. The first launch may take a few seconds while
shaders compile.

## Windows says it protected my PC

The build is not code-signed, so SmartScreen may show *"Windows protected your PC"* the first time you
run it. Choose **More info**, then **Run anyway**.

If your antivirus quarantines the executable, restore it and add an exclusion for the game folder.

## Requirements

- Windows 10 or 11, 64-bit
- DirectX 12 capable GPU (NVIDIA GTX 900 series / AMD RX 400 series or newer recommended)
- 4 GB RAM minimum, 8 GB recommended
- About 150 MB free disk space
- Keyboard and mouse (gamepad supported)

## Controls

WASD move · mouse look · **LMB** fire · **RMB** aim · **R** reload · **E** interact · **Q** / **F**
abilities · **X** ultimate · **Shift** sprint · **Ctrl** or **C** crouch · **Space** jump ·
**I** inventory · **M** map · **Esc** pause

Every action can be rebound in **Settings → Controls**.

## Where is my save?

`%APPDATA%\Godot\app_userdata\RIFTWARD`

Paste that path into the File Explorer address bar. Delete the folder to reset your progress and
settings. Updating the game does not touch it.

## The game won't start

- Check that `RIFTWARD.pck` sits next to `RIFTWARD.exe`. A missing pack is the most common cause.
- Update your GPU driver — the game renders with DirectX 12.
- A black window on first launch usually means shader compilation; give it a few seconds. If it stays
  black, open the `logs` folder inside the save path above and check the last log file.
- On a laptop with switchable graphics, force the game to use the dedicated GPU.

## Updating

Download the new zip and replace the whole game folder. Your save folder stays untouched.
```

---

## Other fields for the same page

| Field | Value |
|---|---|
| Title | `RIFTWARD` |
| Project URL | `riftward` |
| Short description / tagline | `Drop into the Reach. Build what survives.` |
| Classification | Game |
| Kind of project | **Downloadable** (not HTML) |
| Genre | Shooter |
| Pricing | No payment (or `$0 or donate`) |
| Platform | Windows |
| Cover image | `release/store/cover_630x500.png` |
| Version | `0.1.0` |
| Visibility | Draft until the page and download are tested |

---

## GPL note for the live page

The game is GPL-3.0, so once <https://github.com/r48n34/riftward> is pushed, add one line to the end of
the itch.io description:

```markdown
Source code (GPL-3.0): https://github.com/r48n34/riftward
```

That link satisfies the GPL source-availability requirement for the distributed build, as long as the
build matches a tagged commit.
