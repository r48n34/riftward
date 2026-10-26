# CC0 asset packs

RIFTWARD's world, weapons, UI and audio beds are generated procedurally, but the game
ships a small, curated set of **CC0** (public-domain-dedication) particle textures,
prototype textures, sound effects and music stings so authored feedback does not have to
be synthesised at runtime. Everything in this document is fetched, curated and hashed by
[`tools/fetch_asset_packs.ps1`](../tools/fetch_asset_packs.ps1); the per-pack
`MANIFEST.json` files under [`assets/cc0/`](../assets/cc0/) are the source of truth for
provenance and per-file sha256 hashes.

| | |
|---|---|
| Packs | 7 |
| Curated files | 267 |
| Curated payload | 5.96 MB (cap 18 MB) |
| Licenses | CC0 1.0 (public domain dedication) on all seven packs |
| Attribution | Not required by CC0; Kenney is credited anyway |
| Manifests | `assets/cc0/<pack>/MANIFEST.json` (sha256 + byte size per file) |

## At a glance

| Pack | Godot Asset Library | Author / uploader | License | Pinned source | Files | Size | Curated into |
|---|---|---|---|---|---:|---:|---|
| Kenney Particle Pack | [784](https://godotengine.org/asset-library/asset/784) v1.0.2 | Kenney (kenney.nl) / Calinou | CC0 | `7e801dc538` | 43 | 2.65 MB | `res://assets/textures/particles` |
| Kenney Prototype Textures | [781](https://godotengine.org/asset-library/asset/781) v1.0.2 | Kenney (kenney.nl) / Calinou | CC0 | `db6622fbe9` | 20 | 0.08 MB | `res://assets/textures/prototype` |
| Kenney Interface Sounds | [794](https://godotengine.org/asset-library/asset/794) v1.0.0 | Kenney (kenney.nl) / Calinou | CC0 | `ad144fc2dd` | 18 | 0.37 MB | `res://assets/audio/cc0/kenney_interface` |
| Kenney UI Audio | [796](https://godotengine.org/asset-library/asset/796) v1.0.0 | Kenney (kenney.nl) / Calinou | CC0 | `b80d045f07` | 18 | 0.51 MB | `res://assets/audio/cc0/kenney_ui` |
| Kenney Sci-Fi Sounds | [1834](https://godotengine.org/asset-library/asset/1834) v1.0.2 | Kenney (kenney.nl) / Lopano | CC0 | kenney.nl archive | 22 | 1.10 MB | `res://assets/audio/cc0/kenney_scifi` |
| Kenney Impact Sounds | [1841](https://godotengine.org/asset-library/asset/1841) v1.0.2 | Kenney (kenney.nl) / Lopano | CC0 | kenney.nl archive | 130 | 0.99 MB | `res://assets/audio/cc0/kenney_impact` |
| Kenney Music Jingles | [1839](https://godotengine.org/asset-library/asset/1839) v1.0.2 | Kenney (kenney.nl) / Lopano | CC0 | kenney.nl archive | 16 | 0.26 MB | `res://assets/music/kenney` |

The **author** column is the original creator (Kenney); **uploader** is whoever published
the Godot Asset Library entry. For the seven Kenney packs that entry was uploaded by
Calinou (four packs) or Lopano (three sound/music packs), always with `cost = CC0`.

## Dead Asset Library download links

Three Godot Asset Library entries point their `download_url` at GitHub repositories that no
longer exist. The URLs were re-checked while curating (HTTP **404** on all three), so those
packs were downloaded from kenney.nl instead. Both URLs are recorded in the manifests:
`asset_library.listed_download_url` / `listed_download_status = "dead"` versus
`source_url` / `fetched_download_url` (kenney.nl, `archive_sha256` recorded because there is
no commit hash).

| Asset Library entry | Advertised (dead) download URL | Actually fetched from |
|---|---|---|
| [1834](https://godotengine.org/asset-library/asset/1834) Kenney Sci-Fi Sounds | `https://github.com/Loppansson/kenney-sci-fi-sounds-for-godot/archive/c094967fe930c57ddb376f67c75f8aa0296690b7.zip` | `https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip` |
| [1841](https://godotengine.org/asset-library/asset/1841) Kenney Impact Sounds | `https://github.com/Loppansson/kenney-impact-sounds-for-godot/archive/999dd1684873f8b020a3aa5b26e713da21688924.zip` | `https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip` |
| [1839](https://godotengine.org/asset-library/asset/1839) Kenney Music Jingles | `https://github.com/Loppansson/kenney-music-jingles-for-godot/archive/1312c1a8ab2b5830136a5f53ea8c570389bd0808.zip` | `https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip` |

The other four entries are alive and were fetched from the exact **immutable commit archive**
the Asset Library API advertises (`asset-library/api/asset/<id>` -> `download_url`), which is
why those manifests record a 40-character commit hash. Pinning the commit instead of
`master` keeps a re-download byte-identical; if a manifest ever fails verification, the
hash check in `tools/fetch_asset_packs.ps1 -Offline` will say exactly which file drifted.

## Re-fetching / verifying

```powershell
# Fetch missing packs, curate them into assets/, write LICENSE.txt + MANIFEST.json.
# Already-verified packs are skipped, so this is safe to run at any time.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/fetch_asset_packs.ps1

# Integrity gate: no network, no writes. Re-hashes every committed file.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/fetch_asset_packs.ps1 -Offline

# Force a full refresh from upstream (re-downloads all seven archives).
powershell -NoProfile -ExecutionPolicy Bypass -File tools/fetch_asset_packs.ps1 -Force

# Explicit interpreter when auto-detection cannot find Python 3.
$env:PYTHON_BIN = "C:\Python312\python.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/fetch_asset_packs.ps1
```

`-ExecutionPolicy Bypass` is required on stock Windows because the repo is not code-signed
(the same reason `tests/run_all.ps1` is invoked that way).

### Why Python does the downloading

Network access in this project's build sandbox only works through Python's OpenSSL stack:
PowerShell `Invoke-WebRequest` / `WebClient` and `curl.exe` fail here with schannel
`SEC_E_NO_CREDENTIALS`. The script therefore shells out to a Python 3 interpreter for the
seven HTTPS downloads (with a browser-like `User-Agent`, which `godotengine.org` requires).
Everything else — unzip, curation, copying, sha256 hashing, manifest writing, verification —
is native PowerShell and works fully offline.

Python 3 auto-detection order:

1. `-PythonBin <path>` parameter
2. `$env:PYTHON_BIN`
3. the DSH bundled runtime (`C:\Users\devre\.dsh\dsh-runtimes\...\python\python.exe`)
4. `python` on `PATH`
5. `py -3`

If none is found the script exits non-zero with an explicit message. Archives are cached in
`%TEMP%\riftward_cc0\`; a cached archive is only reused for the exact source URL that
produced it, so changing a pinned commit cannot silently reuse stale bytes.

## Verifying the committed tree

```powershell
$env:APPDATA = "D:\godotGa\game\tests\.appdata"  # sandbox-friendly Godot user dir
& "Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
& "Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/assets_test.gd
# -> [ASSETS] checks=... failures=0
# -> [ASSETS] RESULT: PASS
```

`tests/assets_test.gd` is registered in `tests/suites.json` as the `assets` suite and checks:

* every `MANIFEST.json` parses and carries the required provenance fields,
* every listed file exists, has the recorded byte size and a matching sha256,
* every pack ships its CC0 `LICENSE.txt` (canonical copy + one beside the assets),
* the curated payload stays under the 18 MB cap and no single file exceeds 2 MB
  (this is what keeps multi-minute music loops out of the repo),
* the particle pack's `logical_names` map matches `ParticleLibrary`'s table,
* `ParticleLibrary` returns a valid, materialised `GPUParticles3D` for every effect id and
  falls back cleanly for unknown ids / missing texture paths,
* `CombatVFX` still runs headless and creates its primitive feedback, with the particle layer
  present or absent.

## What other systems consume

| Tree | Contents | Consumer |
|---|---|---|
| `assets/textures/particles/` | 43 PNG alpha masks (512x512, white -> tinted by material) | `features/fx/particle_library.gd`, `features/combat/combat_vfx.gd` |
| `assets/textures/prototype/` | `dark/` 13 + `light/` 7 prototype panels (grid, hatch, checker, hazard, door frame) | interior floors, walls and decals |
| `assets/audio/cc0/kenney_interface/` | 18 WAV | menus, settlement/objective UI |
| `assets/audio/cc0/kenney_ui/` | 18 WAV | button click / rollover / switch |
| `assets/audio/cc0/kenney_scifi/` | 22 OGG | weapons, engines, doors, force fields |
| `assets/audio/cc0/kenney_impact/` | 130 OGG (footsteps + material impacts) | weapon/body impacts, movement |
| `assets/music/kenney/` | 16 short OGG stings (< 40 KB each) | extraction/victory/defeat cues |

Audio files keep their **original Kenney filename stems** (`click1.wav`, `impactMetal_heavy_000.ogg`,
`jingles_HIT07.ogg`, ...) because `autoload/audio_director.gd` indexes the CC0 tree by stem.
Do not rename curated files by hand: the manifests are keyed by path, and the fetcher would
restore the original names on the next run.

## ParticleLibrary API

`features/fx/particle_library.gd` (`class_name ParticleLibrary extends RefCounted`) maps
stable logical ids to the curated PNGs and builds configured particles. All functions are
static and cache their textures/materials, so repeated calls are cheap.

```gdscript
ParticleLibrary.has(&"explosion")              # -> true (known logical id)
ParticleLibrary.get_effect_ids()                # -> Array[StringName] (14 ids)
ParticleLibrary.make(&"explosion", 28)         # -> unparented, not-yet-emitting GPUParticles3D
ParticleLibrary.spawn(parent, &"muzzle", pos, 12)   # parented + emitting + auto-freed
ParticleLibrary.spawn_transformed(parent, &"exhaust", xform, 10, false)
ParticleLibrary.get_texture(&"smoke")          # -> Texture2D (CC0 PNG, or procedural fallback)
ParticleLibrary.get_texture_path(&"smoke")     # -> "res://assets/textures/particles/smoke_05.png"
ParticleLibrary.get_material(&"smoke")         # -> cached StandardMaterial3D (billboard + alpha)
ParticleLibrary.get_effect_color(&"portal")    # -> Color, also used by the fallback texture
ParticleLibrary.load_texture_or_null(path)      # -> Texture2D or null (no missing-resource spam)
ParticleLibrary.get_texture_or_fallback(path)   # -> Texture2D, always
```

| Logical id | Curated PNG | Intended use |
|---|---|---|
| `muzzle` | [`muzzle_01.png`](../assets/textures/particles/muzzle_01.png) | muzzle flash puff (CombatVFX.muzzle_flash) |
| `impact_metal` | [`spark_02.png`](../assets/textures/particles/spark_02.png) | metal/armor impacts (CombatVFX.impact surface=&"metal") |
| `impact_dirt` | [`dirt_01.png`](../assets/textures/particles/dirt_01.png) | sand/soil/concrete impacts |
| `explosion` | [`fire_01.png`](../assets/textures/particles/fire_01.png) | fireball burst (CombatVFX.explosion) |
| `dust` | [`smoke_01.png`](../assets/textures/particles/smoke_01.png) | generic dust puffs, debris, tyre dust |
| `exhaust` | [`smoke_03.png`](../assets/textures/particles/smoke_03.png) | vehicle exhaust / engine wash (one_shot = false) |
| `sparks` | [`spark_05.png`](../assets/textures/particles/spark_05.png) | grinding/glass sparks |
| `splash` | [`circle_02.png`](../assets/textures/particles/circle_02.png) | water/puddle impacts |
| `smoke` | [`smoke_05.png`](../assets/textures/particles/smoke_05.png) | rising smoke columns / aftermath |
| `rain` | [`trace_01.png`](../assets/textures/particles/trace_01.png) | weather rain (box emission, streamed) |
| `portal` | [`twirl_01.png`](../assets/textures/particles/twirl_01.png) | rift/portal swirls |
| `scorch` | [`scorch_01.png`](../assets/textures/particles/scorch_01.png) | scorch marks / dark debris burst |
| `flare` | [`flare_01.png`](../assets/textures/particles/flare_01.png) | bright flash accents |
| `trail` | [`trace_03.png`](../assets/textures/particles/trace_03.png) | projectile/beam trails |

Failure behaviour is deliberate and total: a missing pack (trimmed checkout, export without
assets, broken manifest) makes `get_texture()` fall back to a procedurally generated
`GradientTexture2D` soft dot tinted with the effect colour, and an unknown id returns a valid
dust-like node. `CombatVFX` additionally degrades to its original primitive meshes/lights if
the whole library is absent, so combat never errors and never goes silent.

## Licenses

All seven packs are **CC0 1.0 Universal** (public domain dedication); attribution is not
required, but Kenney is credited here and in `docs/THIRD_PARTY_NOTICES.md`. Each pack keeps
the upstream CC0 text in two places:

* `assets/cc0/<pack>/LICENSE.txt` (canonical copy recorded by the manifest),
* a second copy beside the curated files, e.g. `assets/textures/particles/LICENSE.txt`,
  `assets/music/kenney/LICENSE.txt`.

The manifests also record the original archive sha256, so the licensing provenance can be
audited without network access.

## Pack details

### Kenney Particle Pack

* pack id: `kenney_particle_pack`
* Godot Asset Library: [asset 784](https://godotengine.org/asset-library/asset/784) (version 1.0.2, listed license CC0)
* author: Kenney (kenney.nl); Asset Library uploader: Calinou
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_particle_pack/LICENSE.txt)
* source: <https://codeload.github.com/Calinou/kenney-particle-pack/zip/7e801dc538996622a91327bb1dd5879cf977aa09>
* commit: `7e801dc538996622a91327bb1dd5879cf977aa09`
* archive bytes: 5029543
* curated: **43 files, 2.65 MB** -> `res://assets/textures/particles`
* consumers: `features/fx/particle_library.gd` (muzzle, impacts, explosions, dust/exhaust, rain, portal)
* manifest: [MANIFEST.json](../assets/cc0/kenney_particle_pack/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/textures/particles/circle_01.png` | 66234 | `10e757a4b46893fc` |
| `assets/textures/particles/circle_02.png` | 41442 | `71b208a2aa392f4c` |
| `assets/textures/particles/circle_03.png` | 69716 | `5c0d9704ed222df8` |
| `assets/textures/particles/circle_04.png` | 56681 | `210aaed68de75133` |
| `assets/textures/particles/dirt_01.png` | 46129 | `5dc794d1cde78d48` |
| `assets/textures/particles/dirt_02.png` | 52813 | `ffd9d893775a42fa` |
| `assets/textures/particles/dirt_03.png` | 112585 | `b69e01c333504240` |
| `assets/textures/particles/fire_01.png` | 95429 | `258f4fcbf20b20af` |
| `assets/textures/particles/fire_02.png` | 84307 | `6b95e193b302d509` |
| `assets/textures/particles/flame_01.png` | 51191 | `e9a3b7f44defc342` |
| `assets/textures/particles/flame_02.png` | 64804 | `42ccd379f7730d29` |
| `assets/textures/particles/flame_03.png` | 47727 | `d129aca9b22600f2` |
| `assets/textures/particles/flame_04.png` | 67316 | `4ca5e6a8693849ed` |
| `assets/textures/particles/flare_01.png` | 39143 | `7ec33b6648f555b9` |
| `assets/textures/particles/magic_01.png` | 77122 | `4530b084d541351c` |
| `assets/textures/particles/magic_02.png` | 82611 | `8f3594c9a8efdd89` |
| `assets/textures/particles/muzzle_01.png` | 77833 | `1e7da51836e4d703` |
| `assets/textures/particles/muzzle_02.png` | 53879 | `8bc460888f4be1b2` |
| `assets/textures/particles/muzzle_03.png` | 53994 | `878f9e23a11427ca` |
| `assets/textures/particles/muzzle_04.png` | 59586 | `2353b4b16c26f512` |
| `assets/textures/particles/muzzle_05.png` | 51350 | `3695ee37398cd825` |
| `assets/textures/particles/scorch_01.png` | 57261 | `f2247ba0feeb084b` |
| `assets/textures/particles/scorch_02.png` | 70510 | `7408707eb3cd1aac` |
| `assets/textures/particles/scorch_03.png` | 87486 | `9eec4d5b9e9c3ea4` |
| `assets/textures/particles/smoke_01.png` | 91637 | `89df665bb2e9a021` |
| `assets/textures/particles/smoke_02.png` | 91493 | `c1959ff3ae2f0749` |
| `assets/textures/particles/smoke_03.png` | 38182 | `03c219c438420617` |
| `assets/textures/particles/smoke_04.png` | 92360 | `be2579db131de274` |
| `assets/textures/particles/smoke_05.png` | 79571 | `4c6607566fba4cb3` |
| `assets/textures/particles/smoke_06.png` | 58581 | `74968cd44ba5c72b` |
| `assets/textures/particles/spark_01.png` | 89628 | `ca5e7eac772d5af1` |
| `assets/textures/particles/spark_02.png` | 96325 | `7e6272d9ac71494b` |
| `assets/textures/particles/spark_03.png` | 74008 | `72c4b00dd517c0cb` |
| `assets/textures/particles/spark_04.png` | 78726 | `e3fac37e94127b3b` |
| `assets/textures/particles/spark_05.png` | 61925 | `31a0138d1c26c811` |
| `assets/textures/particles/star_01.png` | 39485 | `4cd179dbc319bfbe` |
| `assets/textures/particles/star_02.png` | 47233 | `75f4e34f3f0d8ab1` |
| `assets/textures/particles/trace_01.png` | 35209 | `83744f00d8f19837` |
| `assets/textures/particles/trace_02.png` | 36995 | `1dca7e131bd013a8` |
| `assets/textures/particles/trace_03.png` | 39767 | `0a08ccc56dcb9376` |
| `assets/textures/particles/trace_04.png` | 43180 | `515731b83110a2ef` |
| `assets/textures/particles/twirl_01.png` | 47461 | `a7031a2250cb2b98` |
| `assets/textures/particles/twirl_02.png` | 70196 | `70ec8ca0dac74ae7` |

### Kenney Prototype Textures

* pack id: `kenney_prototype_textures`
* Godot Asset Library: [asset 781](https://godotengine.org/asset-library/asset/781) (version 1.0.2, listed license CC0)
* author: Kenney (kenney.nl); Asset Library uploader: Calinou
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_prototype_textures/LICENSE.txt)
* source: <https://codeload.github.com/Calinou/kenney-prototype-textures/zip/db6622fbe90621eed70a0b417ae8d97281f45e6c>
* commit: `db6622fbe90621eed70a0b417ae8d97281f45e6c`
* archive bytes: 168479
* curated: **20 files, 0.08 MB** -> `res://assets/textures/prototype`
* consumers: interior panel/floor materials and decals (world/mesh kit owners)
* manifest: [MANIFEST.json](../assets/cc0/kenney_prototype_textures/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/textures/prototype/dark/texture_01.png` | 2004 | `60a6f0a0b5e59796` |
| `assets/textures/prototype/dark/texture_02.png` | 1333 | `c1031088472a5b0f` |
| `assets/textures/prototype/dark/texture_03.png` | 1954 | `830f1c808c7786a5` |
| `assets/textures/prototype/dark/texture_04.png` | 7015 | `9b56fcbead5b3709` |
| `assets/textures/prototype/dark/texture_05.png` | 8833 | `21af37abfca38156` |
| `assets/textures/prototype/dark/texture_06.png` | 2092 | `2d980790a6c956a3` |
| `assets/textures/prototype/dark/texture_07.png` | 1912 | `0e96c5434260dfc0` |
| `assets/textures/prototype/dark/texture_08.png` | 635 | `ab80f2fd0209fb87` |
| `assets/textures/prototype/dark/texture_09.png` | 2039 | `46e1233f862fb4da` |
| `assets/textures/prototype/dark/texture_10.png` | 6154 | `84b467f3e135ea82` |
| `assets/textures/prototype/dark/texture_11.png` | 6051 | `d965ceab2c2f4ee9` |
| `assets/textures/prototype/dark/texture_12.png` | 6411 | `7b05f2a01ba7e8ee` |
| `assets/textures/prototype/dark/texture_13.png` | 6635 | `9b1f482f45f00bae` |
| `assets/textures/prototype/light/texture_01.png` | 1333 | `4aae886c87b41c48` |
| `assets/textures/prototype/light/texture_02.png` | 1954 | `42faf3cb8f2169e2` |
| `assets/textures/prototype/light/texture_03.png` | 7015 | `f4bd31987e85d8ef` |
| `assets/textures/prototype/light/texture_04.png` | 7498 | `af3ed6a6e1376f5a` |
| `assets/textures/prototype/light/texture_07.png` | 635 | `1c1dd4fd06950827` |
| `assets/textures/prototype/light/texture_09.png` | 6072 | `2156b8eae883b979` |
| `assets/textures/prototype/light/texture_12.png` | 6194 | `0e156b16cda47ecc` |

### Kenney Interface Sounds

* pack id: `kenney_interface_sounds`
* Godot Asset Library: [asset 794](https://godotengine.org/asset-library/asset/794) (version 1.0.0, listed license CC0)
* author: Kenney (kenney.nl); Asset Library uploader: Calinou
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_interface_sounds/LICENSE.txt)
* source: <https://codeload.github.com/Calinou/kenney-interface-sounds/zip/ad144fc2dd079cdd728bc8c7fcf9c4e64a7a7f83>
* commit: `ad144fc2dd079cdd728bc8c7fcf9c4e64a7a7f83`
* archive bytes: 1734131
* curated: **18 files, 0.37 MB** -> `res://assets/audio/cc0/kenney_interface`
* consumers: menu/settlement UI feedback via `AudioDirector`
* manifest: [MANIFEST.json](../assets/cc0/kenney_interface_sounds/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/audio/cc0/kenney_interface/back_001.wav` | 6094 | `6fb44d6dc1fd0bbc` |
| `assets/audio/cc0/kenney_interface/click_001.wav` | 10190 | `ea67c9d78750e5a3` |
| `assets/audio/cc0/kenney_interface/click_002.wav` | 1102 | `3ebdb096e13b11d2` |
| `assets/audio/cc0/kenney_interface/click_003.wav` | 1742 | `b035afe3fe08b0fd` |
| `assets/audio/cc0/kenney_interface/close_001.wav` | 13134 | `423ae3dd29810456` |
| `assets/audio/cc0/kenney_interface/confirmation_001.wav` | 26062 | `f9d0ef5a5c740c2a` |
| `assets/audio/cc0/kenney_interface/confirmation_002.wav` | 49614 | `b23339f3fdcd9f54` |
| `assets/audio/cc0/kenney_interface/drop_001.wav` | 23374 | `0aa0b07692c5d371` |
| `assets/audio/cc0/kenney_interface/error_001.wav` | 30542 | `d77546b0baa89f37` |
| `assets/audio/cc0/kenney_interface/glass_001.wav` | 25806 | `39182b395a30b34e` |
| `assets/audio/cc0/kenney_interface/open_001.wav` | 13134 | `c69aab75d09d9836` |
| `assets/audio/cc0/kenney_interface/pluck_001.wav` | 19790 | `7d676b0b09b56f7e` |
| `assets/audio/cc0/kenney_interface/scratch_001.wav` | 14286 | `8db53f023af34105` |
| `assets/audio/cc0/kenney_interface/select_001.wav` | 11086 | `3d9e86003f8ebd1a` |
| `assets/audio/cc0/kenney_interface/select_002.wav` | 11086 | `9f15b5f93716a3ff` |
| `assets/audio/cc0/kenney_interface/switch_001.wav` | 109390 | `56a1dd5278d06b4c` |
| `assets/audio/cc0/kenney_interface/tick_001.wav` | 4046 | `fee217e21731da4b` |
| `assets/audio/cc0/kenney_interface/toggle_001.wav` | 14030 | `100585c697b2b25a` |

### Kenney UI Audio

* pack id: `kenney_ui_audio`
* Godot Asset Library: [asset 796](https://godotengine.org/asset-library/asset/796) (version 1.0.0, listed license CC0)
* author: Kenney (kenney.nl); Asset Library uploader: Calinou
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_ui_audio/LICENSE.txt)
* source: <https://codeload.github.com/Calinou/kenney-ui-audio/zip/b80d045f07d782cd9068f7071fb1e7873a0de04d>
* commit: `b80d045f07d782cd9068f7071fb1e7873a0de04d`
* archive bytes: 1700875
* curated: **18 files, 0.51 MB** -> `res://assets/audio/cc0/kenney_ui`
* consumers: button click/rollover/switch feedback via `AudioDirector`
* manifest: [MANIFEST.json](../assets/cc0/kenney_ui_audio/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/audio/cc0/kenney_ui/click1.wav` | 18254 | `dd90b97f38b0ec7d` |
| `assets/audio/cc0/kenney_ui/click2.wav` | 10062 | `a8b35cb35ff45738` |
| `assets/audio/cc0/kenney_ui/click3.wav` | 15694 | `8d0676a5bcbfedad` |
| `assets/audio/cc0/kenney_ui/click4.wav` | 6734 | `0d80e2c82426316b` |
| `assets/audio/cc0/kenney_ui/click5.wav` | 6222 | `8a6f69fef5d24179` |
| `assets/audio/cc0/kenney_ui/mouseclick1.wav` | 13646 | `9f2a6efb18f36bcb` |
| `assets/audio/cc0/kenney_ui/mouserelease1.wav` | 15182 | `2841f77228c7956b` |
| `assets/audio/cc0/kenney_ui/rollover1.wav` | 41806 | `97de1348d2299001` |
| `assets/audio/cc0/kenney_ui/rollover2.wav` | 11086 | `c0c10c006967920e` |
| `assets/audio/cc0/kenney_ui/rollover3.wav` | 15182 | `f3a9e0cf97fd20c9` |
| `assets/audio/cc0/kenney_ui/rollover4.wav` | 21838 | `7f00105fea3df85a` |
| `assets/audio/cc0/kenney_ui/rollover5.wav` | 22862 | `12da6d7c42d0e6bf` |
| `assets/audio/cc0/kenney_ui/rollover6.wav` | 31054 | `83456798fb2dc81c` |
| `assets/audio/cc0/kenney_ui/switch1.wav` | 57166 | `e48f397e7dffafab` |
| `assets/audio/cc0/kenney_ui/switch2.wav` | 56142 | `b0f7b256b9baa6ff` |
| `assets/audio/cc0/kenney_ui/switch3.wav` | 64846 | `2c04718535a175af` |
| `assets/audio/cc0/kenney_ui/switch4.wav` | 76110 | `83956adf4ac68a44` |
| `assets/audio/cc0/kenney_ui/switch5.wav` | 55630 | `824feeb7f534127a` |

### Kenney Sci-Fi Sounds

* pack id: `kenney_scifi_sounds`
* Godot Asset Library: [asset 1834](https://godotengine.org/asset-library/asset/1834) (version 1.0.2, listed license CC0, download link dead - see above)
* author: Kenney (kenney.nl); Asset Library uploader: Lopano
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_scifi_sounds/LICENSE.txt)
* source: <https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip>
* archive sha256: `119340f351a5098ad814f78719438c0da355a9ce8a4c8a3af6a8d48aa3d49e04` (kenney.nl URL is content-addressed; no commit hash exists)
* archive bytes: 5875104
* curated: **22 files, 1.10 MB** -> `res://assets/audio/cc0/kenney_scifi`
* consumers: weapons, engines, doors, force fields, explosions
* manifest: [MANIFEST.json](../assets/cc0/kenney_scifi_sounds/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/audio/cc0/kenney_scifi/doorClose_000.ogg` | 20369 | `c9134651ebbd7c01` |
| `assets/audio/cc0/kenney_scifi/doorOpen_000.ogg` | 19616 | `5b7e07eccd4413ad` |
| `assets/audio/cc0/kenney_scifi/engineCircular_000.ogg` | 177470 | `8ab85f9fa85e9e69` |
| `assets/audio/cc0/kenney_scifi/engineCircular_001.ogg` | 199100 | `e1df3a942842a24f` |
| `assets/audio/cc0/kenney_scifi/explosionCrunch_000.ogg` | 28274 | `4b597d658d0ae101` |
| `assets/audio/cc0/kenney_scifi/explosionCrunch_001.ogg` | 47916 | `fdd04d6f0032d4d5` |
| `assets/audio/cc0/kenney_scifi/explosionCrunch_002.ogg` | 47907 | `be2b8ddc62e4a24c` |
| `assets/audio/cc0/kenney_scifi/forceField_000.ogg` | 25672 | `c2916f2a062c8ddd` |
| `assets/audio/cc0/kenney_scifi/impactMetal_000.ogg` | 15491 | `956c6612a256aa1a` |
| `assets/audio/cc0/kenney_scifi/impactMetal_001.ogg` | 15305 | `4a2b76f20052819c` |
| `assets/audio/cc0/kenney_scifi/impactMetal_002.ogg` | 12708 | `0c1bb4db8a4d48b2` |
| `assets/audio/cc0/kenney_scifi/laserLarge_000.ogg` | 25566 | `a56d95794cd732d6` |
| `assets/audio/cc0/kenney_scifi/laserLarge_001.ogg` | 26220 | `e678aca631495b7d` |
| `assets/audio/cc0/kenney_scifi/laserLarge_002.ogg` | 27440 | `e5e0b6ccc4d5720c` |
| `assets/audio/cc0/kenney_scifi/laserRetro_000.ogg` | 12588 | `2a203a007d24cc7e` |
| `assets/audio/cc0/kenney_scifi/laserSmall_000.ogg` | 7286 | `72b589eadd417812` |
| `assets/audio/cc0/kenney_scifi/laserSmall_001.ogg` | 7448 | `ab87913aba9790a0` |
| `assets/audio/cc0/kenney_scifi/laserSmall_002.ogg` | 8973 | `e70139466c3e8013` |
| `assets/audio/cc0/kenney_scifi/lowFrequency_explosion_000.ogg` | 14317 | `3cb48d86dab63140` |
| `assets/audio/cc0/kenney_scifi/lowFrequency_explosion_001.ogg` | 9408 | `cdda50600a4928f2` |
| `assets/audio/cc0/kenney_scifi/thrusterFire_000.ogg` | 201216 | `0fdc474d93f209de` |
| `assets/audio/cc0/kenney_scifi/thrusterFire_001.ogg` | 204218 | `924636edc923fe4a` |

### Kenney Impact Sounds

* pack id: `kenney_impact_sounds`
* Godot Asset Library: [asset 1841](https://godotengine.org/asset-library/asset/1841) (version 1.0.2, listed license CC0, download link dead - see above)
* author: Kenney (kenney.nl); Asset Library uploader: Lopano
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_impact_sounds/LICENSE.txt)
* source: <https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip>
* archive sha256: `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8` (kenney.nl URL is content-addressed; no commit hash exists)
* archive bytes: 800850
* curated: **130 files, 0.99 MB** -> `res://assets/audio/cc0/kenney_impact`
* consumers: footsteps and material-specific impact sounds
* manifest: [MANIFEST.json](../assets/cc0/kenney_impact_sounds/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/audio/cc0/kenney_impact/footstep_carpet_000.ogg` | 6353 | `b9524658b52a99a2` |
| `assets/audio/cc0/kenney_impact/footstep_carpet_001.ogg` | 6411 | `9af3c3f767051073` |
| `assets/audio/cc0/kenney_impact/footstep_carpet_002.ogg` | 6411 | `9af3c3f767051073` |
| `assets/audio/cc0/kenney_impact/footstep_carpet_003.ogg` | 6301 | `4ae7454338d57c7d` |
| `assets/audio/cc0/kenney_impact/footstep_carpet_004.ogg` | 6301 | `4ae7454338d57c7d` |
| `assets/audio/cc0/kenney_impact/footstep_concrete_000.ogg` | 5808 | `d7267e183067757c` |
| `assets/audio/cc0/kenney_impact/footstep_concrete_001.ogg` | 6308 | `507a75eb19b89708` |
| `assets/audio/cc0/kenney_impact/footstep_concrete_002.ogg` | 6255 | `b21fa546d7494119` |
| `assets/audio/cc0/kenney_impact/footstep_concrete_003.ogg` | 5805 | `8b513c2f03163240` |
| `assets/audio/cc0/kenney_impact/footstep_concrete_004.ogg` | 5912 | `24dd8db2413e5b81` |
| `assets/audio/cc0/kenney_impact/footstep_grass_000.ogg` | 8290 | `9d49497777405d78` |
| `assets/audio/cc0/kenney_impact/footstep_grass_001.ogg` | 8313 | `fb28781bd22b2eef` |
| `assets/audio/cc0/kenney_impact/footstep_grass_002.ogg` | 8278 | `73a520139f5be716` |
| `assets/audio/cc0/kenney_impact/footstep_grass_003.ogg` | 8129 | `0546e1d8ab2def71` |
| `assets/audio/cc0/kenney_impact/footstep_grass_004.ogg` | 7800 | `086fd4ab3546a507` |
| `assets/audio/cc0/kenney_impact/footstep_snow_000.ogg` | 7880 | `c05fa4a9dc9a7aab` |
| `assets/audio/cc0/kenney_impact/footstep_snow_001.ogg` | 7794 | `980fb9a1c9227aed` |
| `assets/audio/cc0/kenney_impact/footstep_snow_002.ogg` | 7694 | `db52bafdc66304f3` |
| `assets/audio/cc0/kenney_impact/footstep_snow_003.ogg` | 7860 | `68272e3f1cabcabd` |
| `assets/audio/cc0/kenney_impact/footstep_snow_004.ogg` | 7630 | `7fe9ce5f5732aaa0` |
| `assets/audio/cc0/kenney_impact/footstep_wood_000.ogg` | 5949 | `5f1c252942a220d6` |
| `assets/audio/cc0/kenney_impact/footstep_wood_001.ogg` | 5929 | `e4f68e1c9fd55b4d` |
| `assets/audio/cc0/kenney_impact/footstep_wood_002.ogg` | 5895 | `9ff095b05cee5eec` |
| `assets/audio/cc0/kenney_impact/footstep_wood_003.ogg` | 6207 | `2a68a083daa9eda0` |
| `assets/audio/cc0/kenney_impact/footstep_wood_004.ogg` | 5799 | `b33e0854e2b3f6b6` |
| `assets/audio/cc0/kenney_impact/impactBell_heavy_000.ogg` | 13915 | `94b8bb5f2d43ab65` |
| `assets/audio/cc0/kenney_impact/impactBell_heavy_001.ogg` | 15577 | `9df61e3ae9a83dc6` |
| `assets/audio/cc0/kenney_impact/impactBell_heavy_002.ogg` | 9252 | `a4171ed1a4a17fb8` |
| `assets/audio/cc0/kenney_impact/impactBell_heavy_003.ogg` | 9429 | `5572ccdeb3b62373` |
| `assets/audio/cc0/kenney_impact/impactBell_heavy_004.ogg` | 6529 | `49fe4fafa2001bd0` |
| `assets/audio/cc0/kenney_impact/impactGeneric_light_000.ogg` | 5827 | `f0e982611e97512f` |
| `assets/audio/cc0/kenney_impact/impactGeneric_light_001.ogg` | 5636 | `c3cd1c073d186ae8` |
| `assets/audio/cc0/kenney_impact/impactGeneric_light_002.ogg` | 5795 | `d0bf60905b59ff63` |
| `assets/audio/cc0/kenney_impact/impactGeneric_light_003.ogg` | 5792 | `0e8896706130f6bc` |
| `assets/audio/cc0/kenney_impact/impactGeneric_light_004.ogg` | 5747 | `f906fa3a37acc437` |
| `assets/audio/cc0/kenney_impact/impactGlass_heavy_000.ogg` | 7403 | `b44b39a940e8948e` |
| `assets/audio/cc0/kenney_impact/impactGlass_heavy_001.ogg` | 8946 | `58686e0e562612cc` |
| `assets/audio/cc0/kenney_impact/impactGlass_heavy_002.ogg` | 7661 | `4978654ac840ad51` |
| `assets/audio/cc0/kenney_impact/impactGlass_heavy_003.ogg` | 6956 | `aed07b154f24410c` |
| `assets/audio/cc0/kenney_impact/impactGlass_heavy_004.ogg` | 8300 | `c7742b0e33c1733d` |
| `assets/audio/cc0/kenney_impact/impactGlass_light_000.ogg` | 6526 | `d750cf88097d0c3e` |
| `assets/audio/cc0/kenney_impact/impactGlass_light_001.ogg` | 6544 | `05e513fbd4282906` |
| `assets/audio/cc0/kenney_impact/impactGlass_light_002.ogg` | 6562 | `710db7451bb7857b` |
| `assets/audio/cc0/kenney_impact/impactGlass_light_003.ogg` | 6618 | `765290ce32fa108c` |
| `assets/audio/cc0/kenney_impact/impactGlass_light_004.ogg` | 6641 | `f535b7cb7835400d` |
| `assets/audio/cc0/kenney_impact/impactGlass_medium_000.ogg` | 8400 | `9252d50bfb85edb1` |
| `assets/audio/cc0/kenney_impact/impactGlass_medium_001.ogg` | 8605 | `d3d806cb3012c9dd` |
| `assets/audio/cc0/kenney_impact/impactGlass_medium_002.ogg` | 8341 | `48616f22c95589ed` |
| `assets/audio/cc0/kenney_impact/impactGlass_medium_003.ogg` | 8596 | `dccea1ecc3d942ee` |
| `assets/audio/cc0/kenney_impact/impactGlass_medium_004.ogg` | 8397 | `853fe77ad46bd0cf` |
| `assets/audio/cc0/kenney_impact/impactMetal_heavy_000.ogg` | 6110 | `e07045693e4a2b3d` |
| `assets/audio/cc0/kenney_impact/impactMetal_heavy_001.ogg` | 7279 | `83554049f81f4db9` |
| `assets/audio/cc0/kenney_impact/impactMetal_heavy_002.ogg` | 5634 | `b914c8f1eb7c0f34` |
| `assets/audio/cc0/kenney_impact/impactMetal_heavy_003.ogg` | 6209 | `b0f2ba4dabde9a87` |
| `assets/audio/cc0/kenney_impact/impactMetal_heavy_004.ogg` | 5788 | `6d65b463c0555dd5` |
| `assets/audio/cc0/kenney_impact/impactMetal_light_000.ogg` | 7651 | `33b5e6e37c6e9d54` |
| `assets/audio/cc0/kenney_impact/impactMetal_light_001.ogg` | 6967 | `fba69c467ddd85da` |
| `assets/audio/cc0/kenney_impact/impactMetal_light_002.ogg` | 6804 | `25a96f90a9a1f88a` |
| `assets/audio/cc0/kenney_impact/impactMetal_light_003.ogg` | 9023 | `92d5db6bfc672d9d` |
| `assets/audio/cc0/kenney_impact/impactMetal_light_004.ogg` | 6675 | `9b1c35820fba5070` |
| `assets/audio/cc0/kenney_impact/impactMetal_medium_000.ogg` | 7117 | `a96f879fec0864a8` |
| `assets/audio/cc0/kenney_impact/impactMetal_medium_001.ogg` | 6151 | `e8a9eaba7c4d2742` |
| `assets/audio/cc0/kenney_impact/impactMetal_medium_002.ogg` | 5857 | `7e89ce2ca0dbda95` |
| `assets/audio/cc0/kenney_impact/impactMetal_medium_003.ogg` | 6964 | `2a185e2e57211d02` |
| `assets/audio/cc0/kenney_impact/impactMetal_medium_004.ogg` | 5744 | `03e10f800199c716` |
| `assets/audio/cc0/kenney_impact/impactMining_000.ogg` | 12035 | `36b4ea107222d073` |
| `assets/audio/cc0/kenney_impact/impactMining_001.ogg` | 11481 | `61235a18de3f3d92` |
| `assets/audio/cc0/kenney_impact/impactMining_002.ogg` | 11235 | `059558ec751115ca` |
| `assets/audio/cc0/kenney_impact/impactMining_003.ogg` | 12160 | `4237fa2cd80364ad` |
| `assets/audio/cc0/kenney_impact/impactMining_004.ogg` | 11668 | `8ca3a99d85d84575` |
| `assets/audio/cc0/kenney_impact/impactPlank_medium_000.ogg` | 12016 | `8403cd7a043f0391` |
| `assets/audio/cc0/kenney_impact/impactPlank_medium_001.ogg` | 12082 | `d7c304319f8beac6` |
| `assets/audio/cc0/kenney_impact/impactPlank_medium_002.ogg` | 12313 | `f6a14da459942296` |
| `assets/audio/cc0/kenney_impact/impactPlank_medium_003.ogg` | 12138 | `0602a7b3eab5f534` |
| `assets/audio/cc0/kenney_impact/impactPlank_medium_004.ogg` | 12084 | `6a51318c1c63821e` |
| `assets/audio/cc0/kenney_impact/impactPlate_heavy_000.ogg` | 10032 | `112d4f93ddcc370b` |
| `assets/audio/cc0/kenney_impact/impactPlate_heavy_001.ogg` | 8713 | `142fd6c77f13d25f` |
| `assets/audio/cc0/kenney_impact/impactPlate_heavy_002.ogg` | 10188 | `b0cab75d1befa32b` |
| `assets/audio/cc0/kenney_impact/impactPlate_heavy_003.ogg` | 8490 | `59775f8979a396c8` |
| `assets/audio/cc0/kenney_impact/impactPlate_heavy_004.ogg` | 11092 | `e31bfec90630155b` |
| `assets/audio/cc0/kenney_impact/impactPlate_light_000.ogg` | 10474 | `6e797cf8a5bfc52d` |
| `assets/audio/cc0/kenney_impact/impactPlate_light_001.ogg` | 11730 | `947915c2eb6ac57e` |
| `assets/audio/cc0/kenney_impact/impactPlate_light_002.ogg` | 9932 | `8ac5869ea434cf0d` |
| `assets/audio/cc0/kenney_impact/impactPlate_light_003.ogg` | 10626 | `dbfb7c1d00257669` |
| `assets/audio/cc0/kenney_impact/impactPlate_light_004.ogg` | 11928 | `9cb33b0c0cce9483` |
| `assets/audio/cc0/kenney_impact/impactPlate_medium_000.ogg` | 10921 | `b670d30452983369` |
| `assets/audio/cc0/kenney_impact/impactPlate_medium_001.ogg` | 11491 | `68ba7701b71ef620` |
| `assets/audio/cc0/kenney_impact/impactPlate_medium_002.ogg` | 10250 | `68762e1ed49bb59a` |
| `assets/audio/cc0/kenney_impact/impactPlate_medium_003.ogg` | 11616 | `964c5fcfb91e7710` |
| `assets/audio/cc0/kenney_impact/impactPlate_medium_004.ogg` | 10803 | `f0e8164081190839` |
| `assets/audio/cc0/kenney_impact/impactPunch_heavy_000.ogg` | 11617 | `b33a8f14068aec24` |
| `assets/audio/cc0/kenney_impact/impactPunch_heavy_001.ogg` | 10861 | `f92f5cb6ba4ff276` |
| `assets/audio/cc0/kenney_impact/impactPunch_heavy_002.ogg` | 9025 | `7993dd4c156b9979` |
| `assets/audio/cc0/kenney_impact/impactPunch_heavy_003.ogg` | 10029 | `4ab53b26f4ea5751` |
| `assets/audio/cc0/kenney_impact/impactPunch_heavy_004.ogg` | 10452 | `f4c0c3eb8ab65175` |
| `assets/audio/cc0/kenney_impact/impactPunch_medium_000.ogg` | 8800 | `486988aa2d6440ff` |
| `assets/audio/cc0/kenney_impact/impactPunch_medium_001.ogg` | 8701 | `e71d23abcc3f10d9` |
| `assets/audio/cc0/kenney_impact/impactPunch_medium_002.ogg` | 10399 | `6492f9ccbc8d24dc` |
| `assets/audio/cc0/kenney_impact/impactPunch_medium_003.ogg` | 9509 | `2d7c719c05999e05` |
| `assets/audio/cc0/kenney_impact/impactPunch_medium_004.ogg` | 10032 | `4a256878a3afb994` |
| `assets/audio/cc0/kenney_impact/impactSoft_heavy_000.ogg` | 6570 | `49e7ca88743fca97` |
| `assets/audio/cc0/kenney_impact/impactSoft_heavy_001.ogg` | 6689 | `4d0096364ba9e461` |
| `assets/audio/cc0/kenney_impact/impactSoft_heavy_002.ogg` | 6749 | `d130ae541951243d` |
| `assets/audio/cc0/kenney_impact/impactSoft_heavy_003.ogg` | 6665 | `d00286a2dc62ee5c` |
| `assets/audio/cc0/kenney_impact/impactSoft_heavy_004.ogg` | 6478 | `e008f0b6b14f6233` |
| `assets/audio/cc0/kenney_impact/impactSoft_medium_000.ogg` | 5351 | `7d3ba0bb5e60a11b` |
| `assets/audio/cc0/kenney_impact/impactSoft_medium_001.ogg` | 5506 | `7642a4fd43e547af` |
| `assets/audio/cc0/kenney_impact/impactSoft_medium_002.ogg` | 5358 | `5069e3571a77d7f7` |
| `assets/audio/cc0/kenney_impact/impactSoft_medium_003.ogg` | 5392 | `5c4a1f35fde7e140` |
| `assets/audio/cc0/kenney_impact/impactSoft_medium_004.ogg` | 5438 | `b0a4dea90eed47ac` |
| `assets/audio/cc0/kenney_impact/impactTin_medium_000.ogg` | 6509 | `f4bbee66ca191ec7` |
| `assets/audio/cc0/kenney_impact/impactTin_medium_001.ogg` | 6603 | `84253095543c094d` |
| `assets/audio/cc0/kenney_impact/impactTin_medium_002.ogg` | 6156 | `c1d2c4f9910d4529` |
| `assets/audio/cc0/kenney_impact/impactTin_medium_003.ogg` | 6541 | `0d18737d93ba7aa0` |
| `assets/audio/cc0/kenney_impact/impactTin_medium_004.ogg` | 6362 | `fd53e24efec3d5c1` |
| `assets/audio/cc0/kenney_impact/impactWood_heavy_000.ogg` | 6233 | `15ff82332f342c30` |
| `assets/audio/cc0/kenney_impact/impactWood_heavy_001.ogg` | 6239 | `f1b07a53ac10c615` |
| `assets/audio/cc0/kenney_impact/impactWood_heavy_002.ogg` | 6146 | `ce1e06f2a05f2634` |
| `assets/audio/cc0/kenney_impact/impactWood_heavy_003.ogg` | 6181 | `af07511902b309b3` |
| `assets/audio/cc0/kenney_impact/impactWood_heavy_004.ogg` | 6253 | `2c647ae6bd29c72a` |
| `assets/audio/cc0/kenney_impact/impactWood_light_000.ogg` | 6343 | `eb45e35b4bed784d` |
| `assets/audio/cc0/kenney_impact/impactWood_light_001.ogg` | 6373 | `4b76bf3ccc8e60d1` |
| `assets/audio/cc0/kenney_impact/impactWood_light_002.ogg` | 6366 | `b183cf7a5bd78381` |
| `assets/audio/cc0/kenney_impact/impactWood_light_003.ogg` | 6381 | `cdfbe8af2fe7ff9e` |
| `assets/audio/cc0/kenney_impact/impactWood_light_004.ogg` | 6395 | `e10009f67ddaeb3a` |
| `assets/audio/cc0/kenney_impact/impactWood_medium_000.ogg` | 6575 | `1723a9fd25103ed4` |
| `assets/audio/cc0/kenney_impact/impactWood_medium_001.ogg` | 6555 | `15271dbe8e2872db` |
| `assets/audio/cc0/kenney_impact/impactWood_medium_002.ogg` | 6607 | `3f3f1917428b828f` |
| `assets/audio/cc0/kenney_impact/impactWood_medium_003.ogg` | 6598 | `635c37cfcd854b18` |
| `assets/audio/cc0/kenney_impact/impactWood_medium_004.ogg` | 6481 | `7ba48f2f99c91c71` |

### Kenney Music Jingles

* pack id: `kenney_music_jingles`
* Godot Asset Library: [asset 1839](https://godotengine.org/asset-library/asset/1839) (version 1.0.2, listed license CC0, download link dead - see above)
* author: Kenney (kenney.nl); Asset Library uploader: Lopano
* license: `CC0-1.0` - [LICENSE.txt](../assets/cc0/kenney_music_jingles/LICENSE.txt)
* source: <https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip>
* archive sha256: `b729ba57959bd58793d2c5cafa348aaf2655d354f3da35ec4729e03ec77197b8` (kenney.nl URL is content-addressed; no commit hash exists)
* archive bytes: 1239525
* curated: **16 files, 0.26 MB** -> `res://assets/music/kenney`
* consumers: short extraction/victory/defeat stings
* manifest: [MANIFEST.json](../assets/cc0/kenney_music_jingles/MANIFEST.json)

| file | bytes | sha256 (first 16) |
|---|---:|---|
| `assets/music/kenney/jingles_HIT00.ogg` | 8650 | `e23d8c9e971a4e34` |
| `assets/music/kenney/jingles_HIT07.ogg` | 8707 | `b35d7bea586f6412` |
| `assets/music/kenney/jingles_HIT15.ogg` | 19626 | `e2929ad1acb0ff92` |
| `assets/music/kenney/jingles_NES00.ogg` | 39948 | `1010c9b566d6c090` |
| `assets/music/kenney/jingles_NES03.ogg` | 16573 | `64b146c4b737d4a7` |
| `assets/music/kenney/jingles_NES05.ogg` | 21439 | `f488e856ca7e01df` |
| `assets/music/kenney/jingles_NES07.ogg` | 18971 | `eac9e04c7ccdf10c` |
| `assets/music/kenney/jingles_PIZZI00.ogg` | 10382 | `b442ade3308a2bbd` |
| `assets/music/kenney/jingles_PIZZI04.ogg` | 11052 | `f98fa4af012d443d` |
| `assets/music/kenney/jingles_PIZZI12.ogg` | 15969 | `f5fc4c01b106e631` |
| `assets/music/kenney/jingles_SAX00.ogg` | 10335 | `f87605d2a3c717e6` |
| `assets/music/kenney/jingles_SAX04.ogg` | 9786 | `94eeaa26800f6a04` |
| `assets/music/kenney/jingles_SAX07.ogg` | 30900 | `241c8570fbded819` |
| `assets/music/kenney/jingles_STEEL00.ogg` | 15691 | `8799eb726d784ae0` |
| `assets/music/kenney/jingles_STEEL03.ogg` | 19117 | `21233e95b5e2c167` |
| `assets/music/kenney/jingles_STEEL14.ogg` | 20532 | `a24f6f6f76063d8e` |

## Maintenance

1. Add or change files in the `$Packs` table at the top of
   [`tools/fetch_asset_packs.ps1`](../tools/fetch_asset_packs.ps1) (explicit filenames, or a
   `Glob` for a whole subdirectory). Curation is a whitelist: nothing lands in `assets/`
   unless it is listed.
2. Run the fetcher **without** `-Offline`; it re-downloads only packs whose manifest is
   missing/drifted, rewrites `MANIFEST.json` + `LICENSE.txt`, and prints the new total.
3. Run it with `-Offline` to prove the committed tree re-hashes cleanly.
4. Update this document (the per-pack tables are mechanical) and
   [`docs/THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
5. If you add a new texture root under `assets/`, extend `ALLOWED_ROOTS` in
   `tests/assets_test.gd`; for a new pack extend `PACK_IDS` there too.
6. Run `Godot --headless --path . --script res://tests/assets_test.gd` - it must print
   `[ASSETS] RESULT: PASS`.

Do **not** commit a pack without its `LICENSE.txt`, and do not add packs whose license is not
CC0/MIT-compatible with GPL-3.0 redistribution. The curated total is capped at 18 MB.

