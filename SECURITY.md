# Security policy

## What this project is

RIFTWARD is an offline, single-player game. It runs no servers, has no accounts, no telemetry and no
network features of any kind. It reads and writes local files only:

- `%APPDATA%\Godot\app_userdata\RIFTWARD\riftward_profile.json` — the player profile
- `%APPDATA%\Godot\app_userdata\RIFTWARD\logs\` — logs
- the `.pck` next to the executable — game data

Because of that, the realistic security surface is small.

## In scope

- Crashes or code execution triggered by a **malformed or hand-edited profile save**.
- A path-traversal or unexpected-file-write bug in save/load handling.
- Vulnerabilities in an exported build that let a downloaded save do more than corrupt itself.
- Supply-chain problems in the build tooling under `tools/`.
- A committed secret or credential (report immediately; the history may need rewriting).

## Out of scope

- Cheating, editing your own save, or modifying the build — it is a single-player game you own.
- Crashes caused by an unsupported GPU driver or an unsupported OS version.
- Missing code signing / SmartScreen warnings. The release is intentionally unsigned and documented as
  such.
- Vulnerabilities in Godot itself. Report those upstream to
  [godotengine/godot](https://github.com/godotengine/godot/security) — they affect every Godot game.

## Reporting

Please **do not open a public issue** for a security problem. Use GitHub's private reporting:

> Repository → **Security** tab → **Report a vulnerability**

If that is unavailable, contact the repository owner through their GitHub profile.

Include: affected version or commit, what happens, the minimal steps or file needed to reproduce, and
whether it affects the exported build or only the source project. Expect a best-effort response rather
than a service-level commitment.

## Supported versions

Only the latest tagged release and `main` receive fixes. There are no security backports to older
builds.
