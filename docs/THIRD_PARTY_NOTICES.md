# Third-party notices

RIFTWARD is licensed under the **GNU General Public License v3.0** — see [LICENSE](../LICENSE).
This file lists the third-party components that ship with it and their own terms.

## Engine

**Godot Engine 4.7.2** — <https://godotengine.org>
Copyright (c) 2007-2026 Juan Linietsky, Ariel Manzur and the Godot community.
Licensed under the **MIT License**. The engine is not distributed in this repository; it is a build
dependency (see [docs/TECHNICAL.md](TECHNICAL.md#15-packaging)). Exported builds embed it under the
MIT License, whose notice is reproduced in the engine's own `COPYRIGHT.txt`.

## Fonts

All three UI typefaces ship under the **SIL Open Font License 1.1**. The full license text is bundled
next to each font and must stay with any redistribution of this project or its builds.

| Font | Files | License |
|---|---|---|
| Sora | `assets/fonts/Sora/Sora-Variable.ttf` | [OFL.txt](../assets/fonts/Sora/OFL.txt) |
| Inter | `assets/fonts/Inter/Inter-Variable.ttf` | [OFL.txt](../assets/fonts/Inter/OFL.txt) |
| JetBrains Mono | `assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf`, `.../JetBrainsMono-Bold.ttf` | [OFL.txt](../assets/fonts/JetBrainsMono/OFL.txt) |

## Procedural art and audio

All 3D geometry, materials, shaders, weapon and vehicle models, UI art and icons are generated
procedurally in-engine or authored for this project. Audio is *primarily* procedural: the 113 SFX ids and
eight music cues are synthesised from hand-written recipe tables at runtime.

That is no longer the whole story for texture and sound *art*: this release also ships **seven CC0
Kenney asset packs** (particle textures, prototype textures, interface/UI/sci-fi/impact sounds and music
jingles) that are used where curated art reads better than a synth — muzzle flashes, impacts,
explosions, engines, UI feedback and short music stings. The procedural synth remains the fallback for
every id, so the game still runs with the packs removed. See the next section for exact provenance.

No third-party 3D models, plugins, paid assets or vendored code are used. Font licensing is listed
above; the CC0 packs are listed below.

## CC0 asset packs

Seven **Kenney** packs ship under `assets/cc0/` (provenance and per-file sha256 in each
`MANIFEST.json`) and are curated into `assets/`:

| Pack | Godot Asset Library | License | Curated files | Curated into |
|---|---|---:|---:|---|
| Kenney Particle Pack | 784 | CC0 1.0 | 43 | `assets/textures/particles/` |
| Kenney Prototype Textures | 781 | CC0 1.0 | 20 | `assets/textures/prototype/` |
| Kenney Interface Sounds | 794 | CC0 1.0 | 18 | `assets/audio/cc0/kenney_interface/` |
| Kenney UI Audio | 796 | CC0 1.0 | 18 | `assets/audio/cc0/kenney_ui/` |
| Kenney Sci-Fi Sounds | 1834 | CC0 1.0 | 22 | `assets/audio/cc0/kenney_scifi/` |
| Kenney Impact Sounds | 1841 | CC0 1.0 | 130 | `assets/audio/cc0/kenney_impact/` |
| Kenney Music Jingles | 1839 | CC0 1.0 | 16 | `assets/music/kenney/` |

- **License:** all seven packs are **CC0 1.0 Universal** (public-domain dedication). Attribution is not
  required by CC0; **Kenney (kenney.nl)** is credited here anyway. Original `LICENSE.txt` files are kept
  beside the curated assets.
- **Source:** packs 784, 781, 794 and 796 were fetched from the immutable commit archives advertised by
  the Godot Asset Library. Asset Library entries **1834, 1841 and 1839** have dead download URLs (their
  GitHub archives return 404), so those three were fetched from **kenney.nl** instead — still CC0. Both
  URLs and the archive sha256 are recorded in each `MANIFEST.json` (`asset_library.listed_download_url`
  / `listed_download_status` vs `source_url`).
- **Total curated payload:** 267 files, 5.96 MiB (cap 18 MiB).
- **Full details:** [docs/ASSET_PACKS.md](ASSET_PACKS.md) — per-pack source URLs, commit hashes/archive
  sha256, curated file lists, re-fetch and offline verification commands
  (`tools/fetch_asset_packs.ps1`, `tools/fetch_asset_packs.ps1 -Offline`), and the consumption map
  (`ParticleLibrary`, `CombatVFX`, `AudioDirector` overrides).

If you add a dependency, asset pack or font, add it to this file with its license before committing.

## Python tooling (not part of the game)

`tools/make_store_assets.py` and `tools/make_promo_assets.py` use **Pillow** (MIT-CMU license) to
compose store and promo art. They are developer tooling, never executed by the game and not required
to play or build it.
