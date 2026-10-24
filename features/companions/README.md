# RIFTWARD — Companions (friendly Wardens + Driftling pets)

Runtime, fully procedural low-poly squadmates. No external assets or addons.

## Files

| File | Purpose |
| --- | --- |
| `ally_agent.gd` | `class_name AllyAgent extends CharacterBody3D` — friendly Warden: formation follow, ranged combat, role support, downed/revive, commands. Group `allies`, layer 8 (Friendly), mask 1 (World). |
| `pet_agent.gd` | `class_name PetAgent extends Node3D` — floating Driftling: spring follow, role effects, disable/self-repair, cloak. Group `pets`, no collision. |
| `companion_manager.gd` | `class_name CompanionManager extends Node` — spawns/owns the squad from `ProfileState` (2 active Wardens + active pet). Group `companion_manager`. |
| `companion_visuals.gd` | `class_name CompanionVisuals` — primitive mesh kits for Warden roles and Driftlings. |
| `shock_turret.gd` | `class_name ShockTurret` — temporary engineer turret (enemy-only pulses). Group `companion_deployable`. |
| `companions_test.gd` | Headless self-test (78 checks). |
| `companions_sandbox.tscn` | Visual QA sandbox with cinematic camera + `-- --capture` screenshots in `preview/`. |

## Integration (deployment)

```gdscript
var companions := CompanionManager.new()
companions.name = "Companions"
deployment.add_child(companions)
companions.setup(player)               # after the Player is in the tree
```

UI / player commands:

```gdscript
companions.issue_squad_command(&"follow")            # follow | hold | focus | revive
companions.issue_squad_command(&"focus", enemy_node)
companions.get_squad_status()                        # HUD squad widget payload
```

Per-Warden API: `setup(data, player, rank)`, `issue_command(command, target)`,
`get_status()`, `get_interact_prompt()` / `interact(player)` (player's E
interaction ray hits the downed Warden because its body temporarily joins
layer 32 "Interactable"), `force_ability()` (debug/test hook),
`get_health_component()`, `heal_from_ally()`.

Pet API: `setup(data, player, rank)`, `force_ability()`, `heal(amount)`,
`disable(duration)`, `set_cloaked(duration)`, `get_health_component()`,
`get_status()`.

## Test / QA commands

```
Godot_v4.7.2-stable_win64_console.exe --headless --path D:\godotGa\game \
  --script res://features/companions/companions_test.gd

Godot_v4.7.2-stable_win64_console.exe --path D:\godotGa\game \
  res://features/companions/companions_sandbox.tscn -- --capture
```

## Known upstream issues (not owned here)

- `features/weapons/weapon_model_builder.gd` does not compile: lines 61/71 pass
  a `Color` (`accent`) where `_add_box()` expects a `Material`. Companions build
  their own weapons in `companion_visuals.gd` to stay independent.
- `features/player/player.gd` does not compile: `_update_history()` called with
  no args in `_ready()` (line 86) while the function requires `delta`; also a
  type-inference error around line 204. The sandbox falls back to a stub player
  and a visible player stand-in body until fixed.
