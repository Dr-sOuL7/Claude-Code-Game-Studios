# Technical Preferences

<!-- project.yaml at the repo root is the machine-readable source of truth for
     engine, specialists, naming, performance, platform, and testing.framework.
     This file is the human-readable LEGACY FALLBACK: agents and skills resolve
     each key from project.yaml first and fall back here only when the
     project.yaml key is absent. /setup-engine dual-writes both.
     Forbidden patterns and allowed libraries are NOT migrated — they live only
     in this file. Populated by /setup-engine; updated as decisions are made. -->

## Engine & Language

- **Engine**: Godot 4.7
- **Language**: GDScript
- **Rendering**: Compatibility (OpenGL 3.3 / WebGL 2 — required by the Web target)
- **Physics**: Jolt (Godot's 3D default; combat is turn-based, so physics is cosmetic only)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Web (desktop and mobile browsers, installable as a PWA); a headless Linux export serves as the authoritative multiplayer server
- **Input Methods**: Mouse, Touch (equal first-class); Keyboard shortcuts optional
- **Primary Input**: Pointer (touch and mouse equal)
- **Gamepad Support**: Partial
- **Touch Support**: Partial
- **Platform Notes**: No hover-only interactions. Every control is operable by tap or click. Layouts must work at 360 px and 1280 px widths. Godot 4 cannot export C# projects to the Web (Godot 4.7 docs, https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html), so all game code is GDScript. Web clients can use WebSocket client and HTTP only; the server must therefore be a separate headless build reached over WSS. TLS WebSocket server setup for web clients is NOT SOURCEABLE from the current reference docs and must be proven by a spike before it is relied on.

## Naming Conventions

- **Classes**: PascalCase (e.g., `MatchState`)
- **Variables**: snake_case (e.g., `special_meter`)
- **Signals/Events**: snake_case past tense (e.g., `turn_resolved`)
- **Files**: snake_case matching class (e.g., `match_state.gd`)
- **Scenes/Prefabs**: snake_case matching the file (e.g., `battle_arena.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_SPECIAL_METER`)

## Performance Budgets

- **Target Framerate**: 60 fps (desktop browsers); mobile-web tier to be set after profiling the first arena scene on a real phone
- **Frame Budget**: 16.6 ms
- **Draw Calls**: [TO BE CONFIGURED — set from the first measured arena scene; WebGL 2 on mobile is the constraint]
- **Memory Ceiling**: [TO BE CONFIGURED — set from the first measured Web export]

## Testing

- **Framework**: gdUnit4
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-0001 Combat engine: pure deterministic data-driven GDScript library — Accepted 2026-11-14
- ADR-0002 Network topology and transport: Web client, headless Godot server, WebSocket — Accepted 2026-11-14
- ADR-0003 Authoritative match lifecycle: commit, resolve, timers, reconnection — Accepted 2026-11-14
- ADR-0004 Accounts and persistence: Supabase Auth + Postgres, server-only writes — Accepted 2026-11-14
- ADR-0005 Build, deploy and CI: single-threaded Web PWA, container server, GitHub Actions — Accepted 2026-11-14
- ADR-0006 Balance and verification strategy: property tests, differential oracle, headless simulator — Accepted 2026-11-14
- Files: `docs/architecture/adr-000N-*.md`. All six accepted by the owner on 2026-11-14.

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
