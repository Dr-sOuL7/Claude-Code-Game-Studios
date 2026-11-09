# ADR-0005: Build, Deployment and CI — Single-Threaded Web PWA, Container Server, GitHub Actions

## Status

Proposed

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09

## Last Verified

2026-11-09 — Godot export facts verified against the 4.7 web-export and dedicated-server pages fetched this run. **Hosting products, CI action versions and Godot export-template download size were NOT verified**; they are proposals to confirm.

## Decision Makers

Owner (delegated to Claude for a proposal); technical-director review pending.

## Summary

The client ships as a single-threaded Godot Web export with PWA enabled on static HTTPS hosting; the server ships as a Linux "dedicated server" export in a container behind a TLS-terminating proxy; GitHub Actions runs import, unit tests, the simulation smoke run, exports, migrations and deploys.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | Godot 4.7 "Exporting for the Web" and "Exporting for dedicated servers" pages |
| **Post-Cutoff APIs Used** | None in code; relies on export options documented for 4.7 |
| **Verification Required** | (1) Web export size and load time on a mid-range phone on cellular; (2) export templates are obtainable in CI; (3) iOS Safari runs the Compatibility (WebGL 2) build; (4) service-worker update behaviour on deploy |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002, ADR-0004 |
| **Enables** | Release |
| **Blocks** | First deployment; the Release phase |
| **Ordering Note** | A CI that exports the Web build and runs the unit tests is needed before the first gameplay story closes (the framework's CI rules) |

## Context

### Problem Statement
The owner requires a production-ready, installable web game with environment-variable configuration, database migrations and automated build and deployment.

### Constraints (sourced from the Godot 4.7 docs)
- Web export requires WebAssembly and WebGL 2.0, using the Compatibility renderer; Forward+/Mobile are not supported on the Web.
- Godot supports a **single-threaded Web export** (since 4.3); it is "the preferred and now default" way, needs no special headers, and works on iOS/macOS where multi-threaded exports had issues. The multi-threaded export needs `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, or the PWA option's workaround.
- PWA option: home-screen icons/display mode/orientation; offline loading after first load via a service worker; the browser may evict cached data. The docs warn the service worker "lacks an automated cache busting mechanism".
- Serve `.wasm` as `application/wasm`; use gzip or Brotli (`.wasm` compresses to about a quarter with gzip).
- Many browser features need a secure context (HTTPS).
- Safari "has several issues with WebGL 2.0 support"; the docs recommend a Chromium-based browser or Firefox where possible.
- Dedicated server: use an export-template binary (not the editor) in production; the "Export as dedicated server" mode adds the `dedicated_server` feature tag and strips textures/materials; `--headless` runs without a display.

## Decision

```
git push ─► GitHub Actions
   1. godot --headless --import                       (framework CI rule: tests block merge)
   2. gdUnit4 unit + integration tests
   3. engine golden/differential tests (ADR-0006)
   4. sim smoke (small tournament; no NaN, all terminate)
   5. export Web preset 'Web'   (single-thread, PWA on, Compatibility)
   6. export server preset 'Linux Server' (dedicated server mode)
   7. supabase migrations (staging, then prod)
   8. deploy: static host ← Web export ; container host ← server image
```

- **Client hosting**: static HTTPS hosting with compression and correct MIME types. Candidates (not evaluated): Vercel, Cloudflare Pages, GitHub Pages (docs note GitHub Pages provides on-the-fly gzip). Final choice is a story.
- **Server hosting**: a container host that supports long-lived WebSocket connections and terminates TLS. Candidates (not evaluated): Fly.io, Railway, Render. The image contains the Linux export-template binary plus the server PCK, started with `--headless` (or the `dedicated_server` tag).
- **Configuration**: environment variables only — `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (server only), `WS_PORT`, `RULESET_VERSION`, `ALLOWED_ORIGINS`, `LOG_LEVEL`. The Web build gets only public values (project URL, anon key, server `wss://` URL) injected at build time.
- **Versioning**: the Web build, server and protocol share a `protocol_version`; a mismatch makes the client show "update available" and hard-refresh (works around the service-worker cache-busting gap).
- **Environments**: `staging` and `production`, both with their own Supabase project.

### Implementation Guidelines
- CI **must** run `godot --headless --import` before tests (fresh clone has no class cache) and **must** fail the build on test failure; tests are never skipped to pass.
- Exports **must not** include editor-only or prototype files (`prototypes/` is never exported).
- Secrets **must** live in the CI/host secret store, never in the repo or in the Web export.
- The server **must** start from `--headless`/`dedicated_server` and log structured JSON to stdout.
- Deploys **must** be reproducible from a tagged commit.

## Alternatives Considered

### Alternative 1: Multi-threaded Web export
- **Pros**: Better performance potential.
- **Cons**: Needs cross-origin isolation headers or the PWA workaround; docs describe compatibility problems on iOS/macOS and with third-party content.
- **Rejection Reason**: Single-thread is the documented default and the combat is turn-based.

### Alternative 2: Serve client and server from one host
- **Pros**: One deploy.
- **Cons**: Static hosts rarely run WebSocket servers; couples scaling.
- **Rejection Reason**: Separate concerns.

### Alternative 3: Manual deploys
- **Pros**: Simple at first.
- **Cons**: Violates the owner's automation requirement and invites mistakes.
- **Rejection Reason**: Required automation.

## Consequences

### Positive
- No special server headers for the client; installable PWA.
- Reproducible, tested releases.

### Negative
- WebAssembly download size is a first-load cost; mitigated by compression and an optional trimmed export template (the docs say an optimized template can reduce the WebAssembly size).
- Two deploy targets to keep in step (protocol version check mitigates).

### Neutral
- Offline mode only helps Local Versus and Practice; online play needs the network.

## Risks
- iOS Safari WebGL 2 issues may force a reduced visual tier. *Mitigation*: test early; quality tiers in the first arena scene.
- Service-worker caching serves a stale build. *Mitigation*: protocol version check and versioned asset names.
- Export templates in CI are large. *Mitigation*: cache them.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | Browser game, installable, mobile-responsive | Web PWA export, Compatibility renderer |
| game-concept.md | Production deploy with migrations and env config | CI pipeline and env-var rules |
| combat-system.md | AC-4/AC-8 reproducibility in tests | CI gates run engine tests and sim smoke |

## Performance Implications
- **CPU**: single-thread WebAssembly on phones — the main risk; budget set by profiling the first arena scene.
- **Memory**: unmeasured; a ceiling is set after the first export.
- **Load Time**: dominated by `.wasm` and `.pck`; compressed delivery required.
- **Network**: negligible after load.

## Migration Plan
Greenfield. **Rollback plan**: tagged releases; redeploy the previous client artifact and server image; down-migrations for schema.

## Validation Criteria
- A fresh clone builds, tests, exports and deploys to staging by pushing one commit.
- Staging works end to end on desktop Chrome/Firefox, Android Chrome and iOS Safari.
- Lighthouse-style PWA installability check passes on staging.

## Related
- ADR-0002, ADR-0004, ADR-0006
- Sources: Godot 4.7 docs — `tutorials/export/exporting_for_web`, `tutorials/export/exporting_for_dedicated_servers`
