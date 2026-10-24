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

## Everything else

All 3D geometry, materials, shaders, particle effects, sound effects and the music bed are generated
procedurally in-engine or written for this project. No external models, textures, audio packs, plugins
or paid assets are used, and no third-party code is vendored into `res://`.

If you add a dependency, asset pack or font, add it to this file with its license before committing.

## Python tooling (not part of the game)

`tools/make_store_assets.py` and `tools/make_promo_assets.py` use **Pillow** (MIT-CMU license) to
compose store and promo art. They are developer tooling, never executed by the game and not required
to play or build it.
