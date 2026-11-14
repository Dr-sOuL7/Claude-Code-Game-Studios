# Evidence: first playable (2026-11-14)

**Build**: Godot 4.7.2 Web export (single-threaded, PWA, Compatibility/WebGL 2), commit 550a7c8.
**Live**: https://spinforge-five.vercel.app (Vercel project `spinforge`, production target, served from `web/`).

## What was run and observed
| Check | How | Result |
|---|---|---|
| Logic | gdUnit4: 68 tests (engine, parts, rules, match flow, CPU) | pass |
| Screens, both modes | `tools/smoke/ui_flow_smoke.gd` headless: title → forge → battle to the end → result → rematch | pass (CPU: 6 turns, burst; 2P: 42 turns, ring-out, 42 hand-offs) |
| Real browser, phone size | Playwright Chromium, iPhone 13 profile, WebGL 2 via SwiftShader, local copy of the build; full CPU match by touch taps | Result screen after 32 turns, no page errors (`cpu-*.png`) |
| Real browser, 2 players | same, with the hand-off screen every turn | Result screen reached, no page errors (`2p-*.png`) |
| Live link public | anonymous third-party fetch of `index.manifest.json` | real manifest returned (no login wall) |

## Found and fixed during the run
- Forge stats were below the fold → pinned stat panel above the buttons (`cpu-02-forge.png`).
- Selected core unclear → white border + cyan glow.
- Narration said "You hits CPU" / "You WINS" → name-neutral phrasing; result headline "YOU WIN!".
- Hand-off screen at 98% opacity let the board show faintly → fully opaque.
- Result screen showed negative energy → clamped at 0.

## Not verified (stated, not hidden)
- The live URL was not played end to end in a browser from this sandbox (the sandbox cannot reach vercel.app); the identical files were played locally.
- No real phone, iOS Safari or Android Chrome test yet; Godot's docs warn Safari has WebGL 2 issues.
- No audio, no 3D, no reduced-motion option, no localisation tables yet (strings go through `tr()`).
