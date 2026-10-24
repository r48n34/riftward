# Browser (HTML5) build — feasibility

**Verdict: not available today, and not a checkbox.** RIFTWARD is a Forward+ desktop game with a
genuinely multi-threaded world generator. A browser version is a port with a visual downgrade, not
an export preset away. The desktop download is ready now — publish that first.

This document records what would have to change and what it would cost, so the decision is informed
rather than optimistic.

---

## The three real blockers

### 1. Renderer: Forward+ cannot run in a browser

`project.godot` targets **Forward+** on a D3D12 device (`config/features=("4.7", "Forward Plus")`,
`rendering_device/driver.windows="d3d12"`). Web exports only have the **Compatibility** renderer
(WebGL 2.0 / OpenGL ES 3.0).

The switch itself is cheap because Godot supports per-platform renderer overrides — the desktop build
can keep Forward+ while the web build runs Compatibility:

```ini
[rendering]
renderer/rendering_method.web="gl_compatibility"
```

The cost is what disappears. `features/world/world_environment.gd` turns on:

- **volumetric fog** (`volumetric_fog_enabled`, density/albedo/anisotropy/length ~90 m, lines 83–89) — *not supported* in Compatibility;
- **SSAO** (lines 64–68) — *not supported*;
- glow, emission and fog stay (glow and standard fog do work in Compatibility).

Result: the four map moods would lose their depth haze and contact shading. The game would still look
like RIFTWARD, but flatter — and the screenshots on the store page would no longer match the product.

### 2. Threads: the world generator is genuinely multi-threaded

`features/world/world_builder.gd` starts real threads:

| Where | What |
|---|---|
| line 205 | landform + biome field generation on a `Thread` |
| line 258 | pads, roads and map overlay on a second `Thread` |
| lines 934–961 | chunk vertex building across `clampi(OS.get_processor_count() - 1, 2, 8)` threads |

On the web there are only two options, and both cost something:

- **Threaded export** — needs `SharedArrayBuffer`, which browsers only expose under cross-origin
  isolation (`Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`).
  You control that on Netlify/Cloudflare Pages/Vercel, but **itch.io does not guarantee those headers
  for HTML5 games**, so a threaded build must be test-uploaded before you promise anything. GitHub
  Pages cannot set headers at all.
- **Non-threaded export** — `Thread` is unavailable, so generation must be rewritten to run
  synchronously. World generation currently takes ~1.1 s plus node creation; on the main thread that is
  a frozen tab, which browsers may flag as unresponsive.

### 3. Performance headroom

The frontier is 64 terrain chunks, 16–20 POIs, 16–22 roadside builds and **5,000–9,000 MultiMesh scatter
instances**, rendered in Forward+ on a discrete GPU. WebGL 2's draw-call and shader budgets are far
below that. A browser build needs a `web` feature-tag branch that cuts scatter density, shadow range,
view distance and post-processing — i.e. the game stops matching its own screenshots.

---

## Smaller things that still must be handled

| Item | Detail |
|---|---|
| **Click to start** | Mouse capture (`Input.set_mouse_mode(MOUSE_MODE_CAPTURED)`, `autoload/app.gd` lines 441/492/531) and the procedural music bed (`AudioDirector`) both need a user gesture first. A start gate is mandatory. |
| **Saves** | `ProfileState` writes `user://riftward_profile.json` (`autoload/profile_state.gd` lines 11–12). Godot maps `user://` to IndexedDB in browsers, so it works — but clearing site data silently wipes a player's profile. Needs export/import or a cloud fallback. |
| **Shaders** | Only one custom shader exists (`assets/shaders/world/sky.gdshader`), so WebGL compile risk is contained — but it must be verified in Compatibility. |
| **Tab lifecycle** | Pause engine/audio on `visibilitychange`, and guard `beforeunload` so players do not lose a run by closing the tab. |
| **Download size** | Good news: the whole pack is 3.96 MB and media is 12.6 MB — comfortably under the ~50 MB practical web budget. Size is *not* the problem. |

---

## What a spike looks like (1–2 days, timeboxed)

1. Add the `.web` renderer override and a **Web** export preset with **thread support off**.
2. Add `OS.has_feature("web")` branches: serialised world generation, reduced scatter, start gate,
   visibility pause.
3. Export, serve locally, and play one full 18-minute deployment in Chrome and Edge. Measure frame time.
4. Fix whatever the sky shader reports in Compatibility.
5. Decide: ship as a separate "browser demo" with cut-down visuals, or abandon.

Then, if it survives: **1–3 weeks** of visual and performance work before it is something you would
show next to the desktop build.

## Hosting, if you go ahead

| Host | Headers | Verdict |
|---|---|---|
| Cloudflare Pages / Netlify / Vercel | COOP/COEP settable via config | Best; keeps the threaded build viable |
| itch.io HTML5 | Not guaranteed | Easiest; ship the non-threaded build and test |
| GitHub Pages | Cannot set headers | Non-threaded build only |

## Decision checklist

- [ ] You accept losing volumetric fog and SSAO in the browser build.
- [ ] You accept serialised generation or a host that sets isolation headers.
- [ ] You accept that browser screenshots will differ from desktop.
- [ ] You have 1–2 days for a spike before committing further.

If any of those is a "no", publish the **Windows download** ([UPLOAD.md](UPLOAD.md)) and revisit this
only if people ask for it.
