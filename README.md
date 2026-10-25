<div align="center">

# RIFTWARD

**Drop into the Reach. Build what survives.**

A single-player, first-person extraction shooter built in **Godot 4.7.2**.

[**Play free on itch.io**](https://r48n34.itch.io/riftward) · [Features](docs/FEATURES.md) · [Build from source](#build-from-source) · [License](#license)

[![headless-tests](https://github.com/r48n34/riftward/actions/workflows/tests.yml/badge.svg)](https://github.com/r48n34/riftward/actions/workflows/tests.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

[![RIFTWARD](media/hero.png)](https://r48n34.itch.io/riftward)

</div>

## The game

Drop into a seeded alien frontier with a loadout you can afford to lose. Take contracts, loot what you
can carry, fight three hostile factions, and get back to the dropship before the Collapse swallows the
map. What you bring home rebuilds Waystation Kestrel. What you leave behind stays lost.

- **One clock, one dropship.** Standard runs are 18 minutes of run time; extraction means holding an
  open pad for 75 seconds while the map closes in around you.
- **Five ways to drop.** Normal, Quick (2x clock), Blackout (night insertion), Gauntlet (early
  Collapse on a 14-minute clock) and Onslaught (elite surge) share the same contract board.
- **A frontier that reshuffles.** Five planets, twelve maps, 18 weather states and a day/night cycle,
  roads, outposts and enterable buildings rebuilt from a seed on every drop.
- **Three factions to fight.** 20 enemy archetypes, 11 elites and 6 bosses — weak points, cover,
  strafes and telegraphed attacks.
- **Readable under pressure.** Image-first armory, skills, squad and outpost screens, a Reach Event
  banner in the HUD, and full display settings (window mode, resolution, render scale, AA, frame cap).
- **A squad and a home.** Recruit four Warden companions and three Driftling pets, then spend what
  you extract on an eight-module outpost that persists between runs.
- **Under the Reach.** Find themed dungeons, descend into procedural interiors, break the guardian
  and carry the loot back to the surface.
- **Water and lava.** Wade, swim and burn: basins, shorelines and hazards are part of every map.
- **First drop.** A five-stage Field Training run teaches movement, combat, abilities, looting and
  extraction before the Reach is allowed to kill you.

## Play

### itch.io (easiest)

**[r48n34.itch.io/riftward](https://r48n34.itch.io/riftward)** — free Windows download, about 40 MB.

Unzip it anywhere, keep `RIFTWARD.exe` and `RIFTWARD.pck` together, and run the executable.

*Windows 10/11 64-bit · DirectX 12 GPU · 4 GB RAM · ~150 MB disk*

### Build from source

You need **Godot 4.7.2** (standard build, not .NET).

```powershell
# one click
RIFTWARD.cmd

# or from a terminal
& "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path .
```

The launcher finds Godot via `GODOT_BIN`, common install folders, or `Downloads`. You can also open
`project.godot` in the editor and press **F5**.

### Package a standalone .exe

```powershell
BUILD.cmd
```

Writes `release/windows/RIFTWARD.exe` + `RIFTWARD.pck` and a checksummed zip. This needs Godot's export
templates — see [packaging notes](docs/TECHNICAL.md#15-packaging).

## Screenshots

![Extraction under a 75-second clock](media/gameplay.png)

![The Reach, seeded per drop](media/world.png)

![What is in the build](media/grid.png)

## Features

| | |
|---|---|
| **World** | 5 planets, 12 maps, seeded 1.8 km frontier, 18 weather states + day/night, enterable interiors, water and lava |
| **Run modes** | 5 modes — Normal, Quick (2x clock), Blackout, Gauntlet, Onslaught — plus 13 contracts and 20 world events |
| **Combat** | 16 weapons, 4 weapon slots, 24 abilities, 4 ultimates, 24 perks |
| **Enemies** | 20 archetypes, 11 elites, 6 bosses across 3 factions |
| **Dungeons** | 3 themed under-reach kits, 2–3 entrances per run, procedural rooms, guardians and loot |
| **Squad** | 4 Warden companions (2 active), 3 Driftling pets |
| **Progression** | Levels 1–30, 4 disciplines, gear with rarities and affixes |
| **Outpost** | 8 modules × 3 tiers on a persistent 8×8 diorama layout (layout v2), between runs |
| **Onboarding** | 5-stage Field Training with HUD guidance, replay and skip |
| **Options** | Display, audio, gameplay, accessibility and full key rebinding; save format v5 |

Full inventory: [docs/FEATURES.md](docs/FEATURES.md).

## Controls

| Action | Key | Action | Key |
|---|---|---|---|
| Move | `WASD` | Fire / aim | `LMB` / `RMB` |
| Look | Mouse | Reload | `R` |
| Sprint | `Shift` | Interact | `E` |
| Crouch | `Ctrl` / `C` | Abilities | `Q` / `F` |
| Jump | `Space` | Ultimate | `X` |
| Melee | `V` | Grenade | `G` |
| Inventory | `I` | Map | `M` |
| Call extraction | `E` / `H` | Pause | `Esc` |

Gamepad is supported and every action is rebindable in **Settings → Controls**. Full table:
[docs/FEATURES.md#controls](docs/FEATURES.md#controls).

## Development

```powershell
tests\run_all.ps1     # all 14 headless suites
```

The same suites run on Linux in CI (`.github/workflows/tests.yml`) on every push and pull request —
that is what the **headless-tests** badge reports. The suite list lives in `tests/suites.json`, so the local
runner and CI stay in sync.

```
autoload/    App, ContentDB, ProfileState, RunState, EventBus, AudioDirector
features/    content, player, weapons, abilities, combat, world, dungeon, tutorial, ai, companions, run, loot
ui/          theme, factory, reusable art components, HUD, 13 screens
assets/      fonts (OFL), SVG icons, world shaders
tools/       launcher, export, packaging, store and promo art
tests/       14 headless suites and artifacts
docs/        design, technical, QA, publishing
```

More: [design](docs/DESIGN.md) · [architecture](docs/TECHNICAL.md) · [QA report](docs/QA_REPORT.md) ·
[build plan and status](docs/BUILD_PLAN.md) · [changelog](CHANGELOG.md) · [dev log](docs/DEVLOG.md) ·
[world API](features/world/WORLD_API.md) · [contributing](CONTRIBUTING.md)

## Status

**v0.2.0** (2026-10-25) — in development, single-player and offline.

- No co-op, PvP or online play.
- No mid-run save — quitting during a deployment abandons that run.
- The build is unsigned, so Windows SmartScreen may warn on first launch
  (*More info → Run anyway*).
- A browser version would need a port, not an export: see [docs/WEB_PORT.md](docs/WEB_PORT.md).

What is done and what is planned: [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md).

## License

RIFTWARD is free software under the **GNU General Public License v3.0** (or later). See
[LICENSE](LICENSE). Third-party components — Godot Engine (MIT) and the Sora, Inter and JetBrains Mono
typefaces (SIL OFL 1.1) — are listed in [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md).

If you redistribute a build, GPL-3.0 requires the corresponding source; link back to this repository.

## Credits

All geometry, materials, effects and audio are generated procedurally — no external models, textures or
paid assets. Screenshots and promo art are composed from live in-engine captures.

## Built with

This game was built heavily with AI assistance:

- **DeepSeek Harness** — the agentic development environment used to write, test, review and package the
  project.
- **DeepSeek V4.1 Flash** — the model behind that work: gameplay systems, UI, procedural content, tooling
  and documentation.
- **Godot 4.7.2** — engine, Forward+ renderer, Jolt physics and the Windows export pipeline.

Design direction and final judgement were human; the implementation, test suites and documentation were
produced in that collaboration. The same disclosure appears on the
[itch.io page](https://r48n34.itch.io/riftward).
