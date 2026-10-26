# RIFTWARD - QA Report

**Build:** 0.3.0 "Sound & Motion"
**Engine:** Godot 4.7.2 stable (`ed1daf0bf`), Forward+, Jolt Physics, D3D12  
**Reference machine:** Windows, NVIDIA GeForce RTX 3060  
**Date:** 2026-10-26  
**Gate command:** `$env:APPDATA="D:\godotGa\game\tests\.appdata"; powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\godotGa\game\tests\run_all.ps1"`

## 1. Summary

The 0.3.0 release grows the gate from 14 to **18 suites** and adds systems coverage for audio, rideables,
cut-scenes and the CC0 asset pipeline on top of the existing boot, shooting, inventory, integration, death,
dungeon, tutorial, world, variants, AI, companions, progression, UI and icon suites.

**The final authoritative full-gate run on 2026-10-26 passed all 18 suites (aggregate exit code 0):
`All 18 test suites passed.`** Command:

```powershell
$env:APPDATA="D:\godotGa\game\tests\.appdata"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\godotGa\game\tests\run_all.ps1"
```

Two fixes closed the last reds found during the release cycle:

- **`inventory`** — the real-boot smoke injected `I` while the new 4 s `insertion` cut-scene owned gameplay
  input. `App._wait_for_gameplay()` now waits out any running cinematic (14 s cap) before smoke input.
- **`ai`** — the standalone `--script` suite leaked one CC0 Ogg stream at exit
  (`kenney_impact/impactGeneric_light_000.ogg`). Root cause: `AudioServer` erases a stopped playback only
  on the next mix step. Audio teardown now flushes for ~60 ms before freeing voices; the final run's
  `ai.err.txt` contains only the filtered certificate-store sandbox line.

`ui`, `audio`, `assets`, `inventory`, `shooting` and `ai` are clean in the final run; the earlier
`AudioStreamWAV`/`scratch_001.wav`, assets RID, inventory-timing and AI Ogg findings are all fixed.

Non-failures: `ERROR: Failed to read the root certificate store.` appears in every suite's stderr on this
sandbox; `tests/run_all.ps1` filters it as engine/sandbox noise. Recast/navmesh precision warnings are
benign.

## 2. Gate evidence

Final run, 18/18, exit code 0 (verbatim runner summary):

```
=== SUMMARY ===

Name           Passed Detail
----           ------ ------
boot             True finished
shooting         True finished
inventory        True finished
integration      True finished
death            True finished
dungeon          True finished
tutorial         True finished
world            True finished
world_variants   True finished
ai               True finished
companions       True finished
progression      True finished
ui               True finished
ui_icons         True finished
audio            True finished
vehicles         True finished
cutscenes        True finished
assets           True finished

All 18 test suites passed.
```

| # | Suite | Command args | Result | Evidence / checks |
|---:|---|---|---|---|
| 1 | boot | `--quit-after 240` | PASS | exit 0, no `SCRIPT ERROR` |
| 2 | shooting | `--quit-after 4000 -- --shoot-smoke` | PASS | real-boot fire/slots/knife/abilities/grenade/reload; `RESULT: PASS` |
| 3 | inventory | `--quit-after 4000 -- --inventory-smoke` | PASS | overlay opens, pauses, 4 weapon rows, satchel, clean close |
| 4 | integration | `res://tests/integration_test.tscn` | PASS | 118/118 checks |
| 5 | death | `res://tests/death_test.tscn` | PASS | 9/9 checks |
| 6 | dungeon | `res://tests/dungeon_test.tscn` | PASS | 57/57 checks |
| 7 | tutorial | `res://tests/tutorial_test.tscn` | PASS | 20/20 checks |
| 8 | world | `res://features/world/world_test.tscn` | PASS | 26 POIs / 16 interiors / 52 loot anchors / 598 clutter; `[world-test] PASS` |
| 9 | world_variants | `res://tests/world_variants_test.tscn` | PASS | 168/168 checks |
| 10 | ai | `--script res://features/ai/ai_test.gd` | PASS | 134/134 checks; clean exit (teardown flush) |
| 11 | companions | `--script res://features/companions/companions_test.gd` | PASS | 78/78 checks |
| 12 | progression | `--script res://tests/progression_test.gd` | PASS | 975/975 checks |
| 13 | ui | `res://ui/ui_demo.tscn --quit-after 2400` | PASS | 130/130 checks |
| 14 | ui_icons | `--script res://tests/ui_icons_test.gd` | PASS | 148/148 checks |
| 15 | audio | `--script res://tests/audio_test.gd` | PASS | 280/280 checks |
| 16 | vehicles | `res://tests/vehicles_test.tscn` | PASS | 244/244 checks |
| 17 | cutscenes | `res://tests/cutscene_test.tscn` | PASS | 78/78 checks |
| 18 | assets | `--script res://tests/assets_test.gd` | PASS | 2,110/2,110 checks |

Logs: `tests/artifacts/logs/<suite>.out.txt` (stdout incl. results) and `<suite>.err.txt` (engine
errors/warnings). The runner fails a suite on `SCRIPT ERROR`, any unfiltered engine `ERROR:` line, or a
missing pass marker (`RESULT: PASS` or the suite-specific marker).

## 2b. Render smoke captures (2026-10-26)

Fresh D3D12 captures were taken against the 0.3.0 build (RTX 3060, 1600x900) and are tracked in
`tests/artifacts/`, with curated copies in `captures/0.3.0-sound-and-motion/`. Both runs exit 0 with no
renderer errors:

- `tests/artifacts/main_menu.png` / `captures/0.3.0-sound-and-motion/main-menu.png` — the menu footer
  renders **"RIFTWARD v0.3.0 · Godot 4.7 · Frontier Ops"**, direct evidence of the version bump.
- `tests/artifacts/deployment.png` / `captures/0.3.0-sound-and-motion/insertion-cutscene.png` — the
  **insertion cut-scene** live: letterbox, `CUTSCENE // INSERTION`, `BEAT 02/03`, caption
  `KESTREL — FIRST CONTACT / Boots on the ground. HUD is live. Weapon hot.`, the **SKIP CINEMATIC**
  affordance, world and planet behind. Captured 2 s after `ready_to_play`, i.e. by design inside the shot.
- `tests/artifacts/deployment_clear.png` / `captures/0.3.0-sound-and-motion/drop-zone-rideable.png` —
  HUD-hidden gameplay at the drop zone: pod pillar, crates and a spawned ground `rig` rideable on the pad
  (new vehicle + clutter content visible).

Capture commands:

```powershell
& "C:\Users\devre\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godotGa\game" --rendering-driver d3d12 -- --capture-menu
& "C:\Users\devre\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\godotGa\game" --rendering-driver d3d12 -- --smoke-capture
```

No other screenshots were regenerated this cycle; the existing `media/`, `ui/_screenshots/` and
`features/world/preview_shots/` art is unchanged and still valid for screens that did not change.

## 3. World QA

Generation metrics from the world contract test (Verdant Verge preset, seed 12345, headless):

- **1,365 ms** total generation (phase A 134 ms, phase B 393 ms) including a **245 ms** nav bake.
- **26 POIs** (24 base = 21 authored `POI_LAYOUT` entries + 3 exfil pads, plus 2 preset extras; up to 28 on
  a four-extra preset), **16 enterable interiors**, minimum POI centre spacing 173.1 m.
- **20 POI types** all present: the 13 original kits plus `foundry_hall`, `hab_cluster`, `comms_array`,
  `fuel_depot`, `clinic_shelter`, `research_lab`, `water_works`; every type has a `POISpecs` row and
  `POISpecs.validate()` is empty.
- Second-wave kit primitives (authored budget, gate >= 60): foundry_hall 256, hab_cluster 381,
  comms_array 203, fuel_depot 281, clinic_shelter 228, research_lab 216, water_works 334.
- 64 terrain chunks / 204,800 terrain triangles, 3,252 navmesh polygons, 656 nodes.
- 17 scatter MultiMesh batches / 6,449 instances, plus **5 POI-clutter batches / 598 instances**
  (about 480 at default density) and **52 loot-prop anchors**.
- 3 fluid basins / 3 surface meshes / 2 lava glow lights; physics raycast from above hits terrain;
  interior floor/ceiling rays hit.
- Determinism replay: identical POI layout for the same seed (26 POIs, first at
  `(-393.8027, -15.34973, 320.0919)`), 1,148 ms without nav/env.

Known benign console noise: Recast emits precision warnings for `agent_height`, `agent_max_climb` and
`agent_radius` because they snap to voxel units; a nav region synchronization warning (4 edge errors) is
also harmless. They do not affect play.

## 4. Content, loot and Codex QA

The 975-check progression/content suite covers:

- All content counts including the new **10 loot items** (rarity/value/stack/effects), **3 loot tables**
  (`poi_common`, `poi_rare`, `vehicle_stash`) with weighted entries, salvage bands, core chances and rarity
  floors, **7 POI Codex records** and **5 rideable Codex records**.
- `ContentDB.roll_loot_table()` / `get_loot_table*()` / `get_loot_table_for_poi(_dict)` /
  `build_loot_cache_payload()` and the POI `loot_tier` -> table mapping (tiers 3–4 -> `poi_rare`,
  `vehicle_stash` opt-in only, unknown -> `poi_common`).
- Save schema still **v5** (`SAVE_VERSION == 5`, base layout v2); no new persistent fields, so no
  migration is required for 0.3.0.
- Existing checks retained: planets/maps/weather/dungeons, modes and their math, contracts, world events,
  enemies, weapons/abilities/perks, outpost layout validation, display-settings getters, XP/result math.

## 5. Rideable QA

The 244-check vehicles suite builds and exercises all five archetypes:

- `rig` (Rift Rig), `hoverbike` (Vale Hoverbike), `airplane` (Kestrel Wing), `spaceship` (Void Skiff),
  `horse` (Warden Steed): spec fields (id/name/kind/seats/max_speed/accel/turn_rate/health/mass/icon/
  hud_color), collision layer 11 "Vehicle" and group membership.
- Mount/dismount round-trip through the real `Player` hook, seat/exit nodes, forced-dismount path.
- Forward displacement after a run of physics frames for all five; horse gait transitions (idle -> walk ->
  trot -> canter -> gallop) with stamina; weapon lock while riding; dungeon entry guard.
- HUD snapshot keys (speed_kph/health/boost/gear/...) and the `UIVehiclePanel` visibility contract.
- `VehicleSites.build()` deterministic placement: guaranteed rig + hoverbike at the drop zone, airplane /
  spaceship / horse routed by POI type and `POISpecs.vehicle` tags, fallback placement when a POI is
  missing (`PASS: VehicleSites spawns five with spec-tagged POIs`).

## 6. Cut-scene QA

The 78-check cutscene suite covers:

- All four ids registered (`deployment`, `insertion`, `exfil`, `boss`); beat timelines and durations;
  beat advance/skip/finish exactly once; the 12 s hard cap; reduce-motion 1.2 s card carrying every
  caption; `cinematic_state_changed` emission (opt-in) and App ownership semantics.
- Full playback without a rendered 3D world (2D-card fallback), including the exfil camera anchor when no
  dropship exists and the boss shot aborting when the boss is freed.
- Loading-screen integration: `CinemaInsertionShot` exists and hands back to the Touchdown act; skip still
  collapses the loading cinema.

## 7. Audio QA

The 280-check audio suite covers:

- Catalog size/uniqueness — **113 ids / 113 recipes** (`[AUDIO TEST] catalog=113 recipes=113`), every
  required gameplay/cut-scene/vehicle call-site id present, `has_stream()` semantics.
- Every catalog id resolves to a stream (CC0 override or procedural fallback); fallback count and caching.
- Bus layout (`Music`, `SFX`, `UI`, `Ambience`, `Vehicles`), the `AudioEffectLimiter` on `Master`, and
  volume/mute routing.
- Music: all eight cues + `silent`, crossfade switching, repeat is a no-op, `set_music_mood` legacy mapping,
  `get_music_tracks()`, headless-safe logical state.
- Ambience: `set_ambience` selects/switches/stops beds, unknown ids ignored, headless-safe.
- Varied playback, looped positional players, UI sound id list, `get_stats()` fields.

## 8. Assets and FX QA

The 2,110-check assets suite covers:

- Every `MANIFEST.json` parses with required provenance fields; every listed file exists, matches the
  recorded byte size and sha256; per-pack `LICENSE.txt` present; curated payload under the 18 MB cap and no
  single file over 2 MB.
- Particle Pack `logical_names` matches `ParticleLibrary.TEXTURE_FILES`; `ParticleLibrary` builds a valid
  materialised `GPUParticles3D` for every one of the **14 effect ids** and falls back cleanly for unknown
  ids/missing textures.
- `CombatVFX` still runs headless and creates primitive feedback with the particle layer present or
  simulated-absent, then restores it.

## 9. UI QA

The 130-check UI suite covers the existing image-first screens plus this release's additions:

- The five-act loading cinema (threat signature with boss dossier, rift breach, drop descent, insertion,
  touchdown, skill/act rail, radio traffic, skip/static-briefing paths).
- Codex **Sites** and **Rideables** tabs and their entries.
- Vehicle HUD panel wiring (`show/update/hide_vehicle`, snapshot rendering), HUD binding (minimap, tactical
  map, scope, aim sight, trackers, weather/clock chip, training card, dungeon banner, hazard overlay,
  Reach Event banner).
- Display settings, accessibility, fonts/icons and the preflight/hub navigation flows.

## 10. Known issues / outstanding

No gate failures remain — the final run is 18/18. The remaining notes are limitations and deferred scope:

1. **Deliberately deferred docs** (historical/store-specific, not part of the 0.3.0 refresh): `docs/STORE_PAGE.md`,
   `docs/WEB_PORT.md` and the historical release bodies `docs/releases/v0.1.0.md` / `v0.2.0.md` still
   describe earlier builds. `docs/ITCH_PAGE.md`, `docs/BUILD_PLAN.md` and the new
   `docs/releases/v0.3.0.md` were refreshed for 0.3.0.
2. No formal FPS/frame-time capture was automated this pass; 60 FPS at 1080p remains the target.
3. Save format stays v5 and there is still no mid-run save (by design).
4. The `run_all.ps1` `Start-Process` wrapper still reports null process exit codes on this machine, so the
   runner gates on pass markers + absence of `SCRIPT ERROR`/`ERROR:` lines; individual suites still call
   `quit(0/1)`.
5. Navmesh/Recast precision and certificate-store console lines are benign sandbox noise (see §3/§1).
6. Scope limitations shared with the release notes: single-player/offline only, no mid-run save, partial
   grenade selection, UI-driven outpost upgrades, no free-cam cut-scene replay.

## 11. Regression fixes in this pass

- **Inventory smoke blocked by the insertion cut-scene.** The real-boot `--inventory-smoke` injected `I`
  1.2 s after boot while the new 4 s `insertion` shot owned input, so the overlay never opened
  (`opened=false paused=false overlay=false weapon_rows=0 snapshot_weapons=4`). `App._wait_for_gameplay()`
  (waits out any running cinematic, 14 s cap) now runs before both the inventory and shooting smoke input;
  re-verified `opened=true paused=true overlay=true weapon_rows=4 ... RESULT: PASS`.
- **Audio-resource leaks at exit fixed.** The `ui` suite previously failed with
  `Leaked instance: AudioStreamWAV` / `Resource still in use: .../scratch_001.wav`, `audio`/`assets` with
  leftover pool resources, and `ai` with an unreleased `kenney_impact/impactGeneric_light_000.ogg` Ogg
  playback. AudioDirector now stops pooled and ambient voices, drops stream references and clears the CC0
  pack cache in `_exit_tree`, and the debug `[AUDIOTRACE]`/`[AUDIONOTIFY]` prints are gone. The last
  `ai` leak was fixed at the engine-cause level: `AudioServer` erases a stopped playback on the next mix
  step, so teardown flushes ~60 ms before freeing voices. All four suites exit clean.
- **Cut-scene input ownership hardened** beyond the smoke fix: every cut-scene exit path restores HUD,
  mouse and input, and `App.abort_cinematic()` covers scene changes/teardown.
- The gate keeps the 0.2.0 protections: engine `ERROR:` lines fail the suite, `%APPDATA%` is redirected
  when not writable, and logs are written to `tests/artifacts/logs/`.

## 12. Recommended next QA pass

- Windowed D3D12 captures beyond the three render-smoke frames: all four cut-scenes, the vehicle HUD and a
  mounted horse/hoverbike in motion.
- A 30-minute soak with repeated mount/dismount and music/cue churn to prove no audio-resource growth.
- Automated frame-time capture during a 20-enemy fight with a vehicle in frame.
- Full gamepad pass including vehicle verbs (boost/brake/ascend) and cut-scene skip.
- Difficulty/mode balance telemetry with the new cargo economy and loot tables over 50 simulated runs.
