# Contributing to RIFTWARD

Thanks for taking a look. RIFTWARD is a complete single-player game released as source; bug reports,
fixes and focused improvements are welcome.

## Ground rules

- **Licensing.** The project is GPL-3.0-or-later. By contributing you agree your contribution is
  licensed under the same terms.
- **Keep the suites green.** All ten headless suites must pass before a PR is ready — see *Before you
  open a pull request*.
- **One concern per PR.** A fix that also reformats three unrelated files will be sent back.
- **Never commit generated output.** `build/`, `release/`, `.build/` and `.godot/` are ignored on
  purpose; `git add -f` on any of them will get the commit rejected.
- **No new third-party assets** (models, textures, audio, fonts) unless you add them to
  [docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) with their license. The project currently
  uses zero paid or externally authored art.

## Development setup

1. Install **Godot 4.7.2** (standard build, not .NET).
2. Run the game from source:

   ```powershell
   RIFTWARD.cmd
   # or
   & "C:\path\to\Godot_v4.7.2-stable_win64.exe" --path .
   ```

3. Run the tests (headless, no editor needed):

   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/run_all.ps1
   ```

4. Build a standalone Windows package:

   ```powershell
   BUILD.cmd
   ```

Prerequisites for export are in [docs/TECHNICAL.md](docs/TECHNICAL.md#15-packaging).

## Before you open a pull request

- [ ] `tests/run_all.ps1` passes locally (all ten suites).
- [ ] The game boots from `scenes/boot.tscn` with no script errors in the console.
- [ ] If you changed gameplay, the relevant capture scripts still run
      (`-- --smoke-capture`, `-- --shoot-smoke`, `-- --inventory-smoke`).
- [ ] If you changed content counts (weapons, enemies, abilities, POIs, map presets), you updated the
      validators in `autoload/content_db.gd` **and** the expected numbers in the tests. ContentDB
      fails loudly on a mismatch by design.
- [ ] If you changed anything user-visible, README tables and `docs/BUILD_PLAN.md` against reality.

## Code conventions

The project follows a deliberate architecture; matching it matters more than personal style:

- **Feature folders.** Code lives under `features/<domain>/`, not by class type. A new system gets a
  folder with its scene, script, tests and notes.
- **Signals up, calls down.** UI listens to signals and never mutates gameplay state directly.
  Gameplay never reaches into UI nodes.
- **Data-driven content.** New weapons, enemies, perks, items and map presets are entries in
  `features/content/content_library.gd` materialized as typed `Resource`s — not hard-coded branches.
- **Physics on the physics tick.** Movement, hitscan and cooldowns belong in `_physics_process`;
  mouse look stays in input handling.
- **No absolute `res://` paths in logic.** Use `@export_file`/`@export_dir` or preloads so assets can
  move without breaking scripts.
- **Typed GDScript.** Prefer `var x: int = 0`, `-> void`, `Array[Thing]`; the project enables the
  untyped-declaration warning.
- **Determinism.** Anything procedural must take its seed from the run state, never from wall-clock
  time or an unseeded RNG.

[features/world/WORLD_API.md](features/world/WORLD_API.md) and
[features/companions/README.md](features/companions/README.md) document the two systems most likely to
need extension.

## Commit messages

Imperative subject under ~72 characters, then a body explaining **why**:

```
Clamp storm timer to run length

The Collapse storm could outlive the deployment clock on Quiet mode,
leaving the exfil beacon ringing with no way to reach it.
```

## Opening the pull request

1. Fork, then branch from `main`: `git checkout -b fix/exfil-beacon-timer`.
2. Push and open a PR against `main`. Fill in the template.
3. CI runs the headless suites on Linux. A red run must be fixed before review.
4. Describe *how you tested it*, not just what changed.

## Reporting bugs

Use the issue template. Include the build version (or commit), the seed and contract if the bug is in a
deployment, and the last lines of `%APPDATA%\Godot\app_userdata\RIFTWARD\logs\godot.log`.

## License

By contributing, you agree that your contributions are licensed under the **GNU General Public
License v3.0 or later**, the same license as the project. See [LICENSE](LICENSE).
