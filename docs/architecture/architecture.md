# SPINFORGE — Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-11-14
- Engine: Godot 4.7 (GDScript); installed in the dev container: 4.7.2
- Workflow tier: `standard` (system layer map + critical ADR list; module ownership, data flow and API boundaries are included because the project is multiplayer and they are cheap to state now)
- GDDs Covered: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `design/gdd/combat-system.md` (v0.2, approved rules R1–R7; v0.3 pending O8)
- ADRs Referenced: ADR-0001 … ADR-0006 (all Accepted 2026-11-14)
- TD-ARCHITECTURE: 2026-11-14 — skipped — Lean mode
- LP-FEASIBILITY: 2026-11-14 — skipped — Lean mode

## Engine Knowledge Gap Summary

Godot 4.5, 4.6 and 4.7 are all post-cutoff (`docs/engine-reference/godot/VERSION.md`: HIGH risk for each). Consequences for this architecture:

- **Networking (HIGH):** the Web export supports only HTTP client/requests, WebSocket *client* and WebRTC; `WebSocketPeer.accept_stream`, `handshake_headers`, `heartbeat_interval`, `get_connected_host/port` and `set_no_delay` are unavailable or inert in Web exports (Godot 4.7 class docs, fetched 2026-11-09). The server is therefore a native headless build (ADR-0002).
- **Rendering (HIGH):** Web = Compatibility renderer / WebGL 2 only; Safari has WebGL 2 issues; single-threaded export is the default (4.7 web-export docs). 4.6 changed glow and tonemapping; 4.7 changed `CanvasItem` line antialiasing and `LinearToSRGB` clamping — visual tuning done on 4.3 knowledge will look different.
- **UI/Input (HIGH):** 4.6 dual-focus (pointer vs keyboard focus separate); 4.7 `VirtualJoystick`, `Control.offset_transform_*`, mouse/keyboard no longer device `0`; new projects stretch by default (`canvas_items` / `expand`).
- **GDScript (HIGH):** `@abstract` (4.5), variadics (4.5), typed-return overrides need an explicit `return` (4.7), packed-array element writes no longer call setters (4.7). Lambdas capture by value (all 4.x).
- **Audio (MEDIUM for us):** Web exports play samples by default since 4.3; `AudioEffect`s, reverb and procedural audio are unavailable in that mode.
- **Physics:** Jolt is the 3D default (4.6); irrelevant to rules (combat is turn-based, physics is cosmetic) but affects any arena debris VFX.
- **Deprecated APIs to never emit:** `yield`, string `connect`, `instance()`, `OS.get_ticks_msec()`, `TileMap`, `duplicate()` for nested resources (use `duplicate_deep()`), `event.device == 0` checks, `width_in_percent` on `RichTextLabel` images (full table: `docs/engine-reference/godot/deprecated-apis.md`).

Every Core/Foundation module below that touches these domains is flagged **[HIGH]**; its first story includes a verification step against the reference docs or a running binary.

## Technical Requirements Baseline

Extracted from 3 design documents | 24 requirements | 0 registered, 24 provisional
(TR registry: read, 0 entries — `bash .claude/scripts/registry.sh next-id tr combat` → TR-combat-001; every ID below is **provisional** until `/architecture-review` registers it)

| Req ID | GDD | System | Requirement | Domain |
|--------|-----|--------|-------------|--------|
| TR-combat-001 (provisional) | combat-system.md | Combat Engine | Deterministic: same `(state, actions, seed)` → identical state and events (AC-4) | Core |
| TR-combat-002 (provisional) | combat-system.md | Combat Engine | Core never affects any output (AC-3) | Core |
| TR-combat-003 (provisional) | combat-system.md | Combat Engine | All probabilities bounded: collision 0.2–0.9, burst ≤ cap, ring-out ≤ 0.9, no NaN/inf (AC-1) | Core |
| TR-combat-004 (provisional) | combat-system.md | Combat Engine | Both actions resolved atomically; illegal SPECIAL rejected before mutation (Rule 3, E7) | Core |
| TR-combat-005 (provisional) | combat-system.md | Combat Engine | Hidden commit: pending action never visible before resolution (Rule 4, AC-7) | Networking |
| TR-combat-006 (provisional) | combat-system.md | Combat Engine | Termination bound (≤ 165 turns at v0.2 values) read from the ruleset (E10, AC-8) | Core |
| TR-combat-007 (provisional) | combat-system.md | Combat Engine | Seat symmetry: swapping seats with mirrored RNG gives identical outcome (AC-5) | Core |
| TR-combat-008 (provisional) | combat-system.md | Combat Ruleset | All tunables (Section 8) in external versioned data; published versions immutable | Core |
| TR-combat-009 (provisional) | combat-system.md | Combat Engine | Worked examples F2–F5 reproduce to ±0.01 (AC-9) | Core |
| TR-combat-010 (provisional) | combat-system.md | Combat Engine | Event list is the sole output consumed by UI/3D/network | Core |
| TR-combat-011 (provisional) | combat-system.md | Balance Simulator | No "balanced" claim without a report meeting declared bands (O4, ADR-0006) | Core |
| TR-construction-001 (provisional) | game-concept.md / combat F0 | Top Construction | Blade AP+LI=80, Disc MS+ST=100, Tip MB+SM=100; build total 280 (AC-2) | Core |
| TR-construction-002 (provisional) | combat-system.md F0 | Top Construction | Type classification via normalised scores with margin 0.15; spec examples classify A/D/S/B (AC-6) | Core |
| TR-construction-003 (provisional) | game-concept.md | Top Construction | 15 cores cosmetic only (name + two-tone palette) | Core |
| TR-online-001 (provisional) | game-concept.md, ADR-0003 | Match Server | Server-authoritative results; clients display only | Networking |
| TR-online-002 (provisional) | ADR-0003 | Match Server | One pending action per (match, turn, player); duplicates idempotent, conflicts rejected | Networking |
| TR-online-003 (provisional) | ADR-0003 | Match Server | Server-owned turn timer; timeout action from ruleset (E9/O5) | Networking |
| TR-online-004 (provisional) | ADR-0003 | Match Server | Reconnect with resume token; snapshot = public state + own pending flag + events since N | Networking |
| TR-online-005 (provisional) | ADR-0002 | Network Protocol | Versioned JSON envelope; unknown version → client refresh | Networking |
| TR-online-006 (provisional) | ADR-0003 | Spectator | Spectators receive post-resolution events only; no action permission | Networking |
| TR-persist-001 (provisional) | ADR-0004 | Persistence | Only the server writes matches, turns, ratings; RLS denies clients | Core |
| TR-persist-002 (provisional) | ADR-0004 | Persistence | Build = four part ids; no stat/progression/rarity columns anywhere | Core |
| TR-ui-001 (provisional) | game-concept.md | Workshop / HUD | Every control operable by tap or click; layouts work at 360 px and 1280 px | UI |
| TR-ui-002 (provisional) | game-concept.md (Pillar 4) | 3D Presentation | Visuals driven by events only; never obscure a needed number; colour never the only state cue | UI |

Narrative-only sections (Overview, Player Fantasy) contributed no requirements, as expected. No GDD was skipped.

## System Layer Map

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ PRESENTATION   Workshop UI (The Forge) · Battle HUD & Arena UI · 3D          │
│                Presentation & VFX · Audio · Shell & Navigation chrome        │
├──────────────────────────────────────────────────────────────────────────────┤
│ FEATURE        Local Versus · Practice AI · Matchmaking & Invitations ·      │
│                Spectator Mode · Match History & Replay · Rankings · Admin &  │
│                Ruleset Publication · Settings & Accessibility · Telemetry ·  │
│                Balance Simulator & Reports (tool)                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ CORE           Combat Engine [HIGH: GDScript] · Match Orchestrator ·         │
│                Network Protocol & Client [HIGH: Networking] ·                │
│                Authoritative Match Server [HIGH: Networking]                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Component Catalogue · Top Construction & Derived Stats ·      │
│                Combat Ruleset (data) · Persistence gateway (Supabase REST)   │
│                [HIGH: HTTP in Web] · Accounts & Profiles (auth client) ·     │
│                Scene/Screen Router · Event schema                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7 Web export (single-thread, Compatibility/WebGL 2),  │
│                Godot 4.7 Linux dedicated-server export, browser, Supabase    │
└──────────────────────────────────────────────────────────────────────────────┘
```

The two load-bearing modules are the **Combat Engine** (every mode, the server and the simulator call it; nothing else may contain a rule) and the **Match Orchestrator** (every mode and every presentation surface sit on it; online play replaces its action source, not its interface).

## Module Ownership

Code root is `src/` (Godot). Directory = module; the rules in `.claude/rules/` are scoped by these paths.

| Module (path) | Layer | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|---|
| `src/core/combat/` Combat Engine | Core | `MatchState`, `TurnResult`, event schema, PRNG | `CombatEngine.new_match / legal_actions / resolve_turn`, `MatchState.to_dict/from_dict` | `Ruleset`, `BuildStats` | None beyond `RefCounted`, `Dictionary`, `Array` (GDScript typed-return rule 4.7 **[HIGH]**) |
| `src/core/rules/` Combat Ruleset | Foundation | `Ruleset` value object; loader; version pin | `Ruleset.load(version)`, `Ruleset.get(key)` | `assets/data/combat/ruleset_v*.json` | `FileAccess`, `JSON` (4.4 `FileAccess` return-type change **[MEDIUM]**) |
| `src/core/parts/` Component Catalogue + Top Construction | Foundation | part tables, `Build`, `BuildStats`, `classify()` | `Catalogue.parts(kind)`, `BuildStats.from_build(build)` | `assets/data/parts/*.json` | `JSON` |
| `src/gameplay/match/` Match Orchestrator | Core | match flow state machine, action sources (local, AI, remote), event replay cursor | `MatchFlow` signals: `turn_opened`, `turn_resolved(events)`, `match_finished` | Combat Engine, Ruleset | `Node`, typed signals (`signal.connect(callable)`) |
| `src/gameplay/modes/` Local Versus, Practice | Feature | per-mode rules (handoff screen, AI difficulty) | mode scenes | Match Orchestrator | `SceneTree`, `Node` |
| `src/ai/` Practice AI | Feature | policies by difficulty | `Policy.choose(public_state, legal) -> int` | Combat Engine (`legal_actions` only) | none |
| `src/networking/protocol/` Network Protocol | Core | message schemas, `protocol_version`, validators | `encode/decode`, `validate(frame)` | event schema | `JSON`, `WebSocketPeer` client **[HIGH]** |
| `src/networking/client/` Online client | Core | socket lifecycle, resume token, ping/pong, version check | `RemoteActionSource` for the Orchestrator | Protocol | `WebSocketPeer` (no handshake headers, no heartbeat in Web) **[HIGH]** |
| `src/server/` Authoritative Match Server | Core | lobby, queue, invites, `MatchActor`s, timers, spectator lists | process entry (`--headless` / `dedicated_server`) | Combat Engine, Protocol, Persistence gateway | `TCPServer`, `WebSocketPeer.accept_stream` (native only) **[HIGH]**, `Timer`/main loop |
| `src/persistence/` Persistence gateway + Accounts | Foundation | Supabase REST/Auth calls, token cache, write-behind queue | `Store.save_turn(...)`, `Auth.sign_in(...)` | ADR-0004 schema | `HTTPRequest` (Web: same-origin, no chunked, host verification fixed) **[HIGH]** |
| `src/ui/` Workshop, HUD, Shell, Settings | Presentation | screens, layouts, accessibility options | scenes | Orchestrator signals, `BuildStats` | `Control` (dual focus 4.6, stretch defaults 4.7) **[HIGH]** |
| `src/presentation/` 3D & VFX, Audio | Presentation | procedural top mesh generator, arena scenes, event→animation mapping | `ArenaView.play(events)` | events, Catalogue palettes | `MeshInstance3D`, `ArrayMesh`, Compatibility renderer, Web Audio sample mode **[HIGH]** |
| `tools/sim/` Balance Simulator | Feature (tool) | tournament runner, policies, report writer | CLI (`godot --headless -s`) | Combat Engine, Ruleset | `OS.execute` for workers (verify) |

Dependency direction (arrows = "may call"):

```
ui/ presentation/ ──► gameplay/match ──► core/combat ──► core/rules, core/parts
ai/ ──► core/combat (legal_actions)        server/ ──► core/combat, networking/protocol, persistence/
networking/client ──► networking/protocol  tools/sim ──► core/combat, core/rules
Nothing in core/ may import gameplay/, ui/, presentation/, networking/, server/ or persistence/.
```

## Data Flow

**1. Local turn (Local Versus / Practice)**
```
UI commit(P1) ─┐
UI commit(P2) ─┴─► MatchFlow.submit(a, b) ─► CombatEngine.resolve_turn(state, a, b)   [sync call]
                                           ◄─ TurnResult{events, finished}
MatchFlow.turn_resolved(events) ──signal──► HUD (numbers)  ──► ArenaView.play(events) ──► Audio
                                            └─► ReplayLog.append(turn, a, b)
```
Hidden commit locally: the handoff screen covers the display between P1's and P2's commits; actions live only in `MatchFlow` until both are present.

**2. Online turn (client view)**
```
UI commit ─► RemoteActionSource.send(action{match,turn,a}) ─ws─► Server
Server ──ws──► opponent_committed (no payload)                  [async, network]
Server resolves (ADR-0003) ──ws──► turn_resolved{events, public_state}
RemoteActionSource ─► MatchFlow.apply_remote(events, public_state) ──signal──► HUD / ArenaView
```
The client never calls `resolve_turn` in online mode; `MatchFlow` runs in "follower" mode and only replays events.

**3. Server resolve path (ADR-0003)**: `MatchActor` holds both pending actions → `resolve_turn` (sync, no await) → broadcast → `Store.save_turn` queued (write-behind, retried). Crosses no thread boundary; `HTTPRequest` is asynchronous but non-blocking.

**4. Persistence/replay**: `matches(seed, builds, ruleset_version) + match_turns(actions, events)`; a replay plays stored events (never recomputes); a server restart recomputes `MatchState` from seed + actions.

**5. Initialisation order**: Ruleset → Catalogue → (client) Shell → Auth → socket `hello{JWT}`; (server) Ruleset → Catalogue → Persistence gateway → `TCPServer.listen` → accept loop. The engine itself has no init; it is pure functions over data.

## API Boundaries

```gdscript
# Combat Engine (src/core/combat/combat_engine.gd) — ADR-0001
class_name CombatEngine extends RefCounted
static func new_match(ruleset: Ruleset, a: BuildStats, b: BuildStats, seed: int) -> MatchState
static func legal_actions(state: MatchState, player: int) -> Array[int]      # Action enum values
static func resolve_turn(state: MatchState, action_a: int, action_b: int) -> TurnResult
# Invariants callers respect: actions ∈ legal_actions; state not FINISHED. Guarantees: atomic mutation,
# events describe every state change, no engine/Node/global access, deterministic for (state, actions).

# Top Construction (src/core/parts/) — TR-construction-*
static func BuildStats.from_build(build: Build) -> BuildStats   # AP, LI, MS, ST, MB, SM, type, domain; core ignored

# Match Orchestrator (src/gameplay/match/match_flow.gd)
signal turn_opened(turn: int, deadline_ms: int)
signal turn_resolved(events: Array[Dictionary], public_state: Dictionary)
signal match_finished(result: Dictionary)
func set_action_source(player: int, source: ActionSource) -> void   # LocalInput | AiPolicy | Remote

# Protocol (src/networking/protocol/) — ADR-0002
const PROTOCOL_VERSION := 1
static func encode(type: String, payload: Dictionary) -> String     # JSON text frame with "v", "t", "id"
static func validate(frame: Dictionary) -> int                      # OK or error code; size- and schema-checked
```
Engine types in interfaces: only `RefCounted`, `Dictionary`, `Array[...]`, `Signal`; no `Node` crosses a module boundary except scene instancing inside `ui/`, `gameplay/modes/` and `presentation/`.

## ADR Audit

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| ADR-0001 Combat engine architecture | ✅ | ✅ 4.7 | ✅ | None | ✅ |
| ADR-0002 Network topology & transport | ✅ | ✅ 4.7 | ✅ | None | ✅ (spike pending) |
| ADR-0003 Authoritative match lifecycle | ✅ | ✅ 4.7 | ✅ | None | ✅ (timer defaults = O5) |
| ADR-0004 Accounts & persistence | ✅ | ✅ 4.7 | ✅ | None | ⚠️ Supabase facts unverified |
| ADR-0005 Build, deploy & CI | ✅ | ✅ 4.7 | ✅ | None | ⚠️ hosting unverified |
| ADR-0006 Balance & verification | ✅ | ✅ 4.7 | ✅ | None | ✅ |

Traceability: TR-combat-001…011, TR-construction-001…003, TR-online-001…006, TR-persist-001…002 → covered by ADR-0001/0002/0003/0004/0006. **Gaps:** TR-ui-001, TR-ui-002 (no ADR governs presentation/event-to-animation or responsive UI).

## Required ADRs

**Must have before the relevant code starts:**
- `/architecture-decision "Event-driven presentation and procedural top geometry"` → covers TR-ui-002 (events-only rendering, quality tiers for mobile WebGL 2, procedural meshes from stats). Before the 3D story.
- `/architecture-decision "Screen shell, navigation and responsive layout"` → covers TR-ui-001 (scene routing, 360–1280 px layouts, 4.7 stretch defaults, dual focus). Before the first UI story.

**Should have before the relevant system:**
- `/architecture-decision "Practice AI policy interface and difficulty tiers"` (before Practice AI).
- `/architecture-decision "Rating system (Elo vs Glicko-2) and leaderboard views"` (before Rankings).

**Can defer to implementation:** audio bus layout; telemetry event list.

## Architecture Principles

1. **One engine, no rules elsewhere.** Every rule lives in `src/core/combat/`; UI, AI, server and simulator call it. A number that appears outside the ruleset data is a bug.
2. **Events are the interface.** Presentation, replay, spectating and history all consume the same typed event list; nothing recomputes.
3. **The server is the only authority online; the client is a projector.** Hidden information never leaves the server before resolution.
4. **Evidence before claims.** Rule changes ship as data + tests + a simulator report (ADR-0006).
5. **Browser-first constraints are design constraints.** Single-threaded WebAssembly, WebGL 2, Safari quirks, tab pausing and HTTP same-origin rules are read before each Core/Presentation story, not discovered after.
6. **Conservation of Power in the schema.** No table, field or message carries progression, rarity or paid power.

## Open Questions

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | Component-level imbalance (O8): which LI/MB/AP rule set ships in ruleset v1 | High | `combat-system.md` v0.3 after the current sweep; simulator report |
| QQ-02 | TLS WebSocket from a Godot Web client to a headless Godot server behind a real host | High | Spike story before any online epic (ADR-0002) |
| QQ-03 | GDScript engine throughput for the simulator | Low — measured 2026-11-14: ≈ 12,100 turns/s with full tracing (`production/qa/evidence/combat-engine-oracle.md`) | Re-measure without tracing in the simulator epic |
| QQ-04 | Supabase CORS/RLS/JWT-validation behaviour from the Web export | Medium | Spike from the staging origin (ADR-0004) |
| QQ-05 | Mobile WebGL 2 frame budget; Safari issues | Medium | Profile the first arena scene on real devices (ADR-0005) |
| QQ-06 | Turn timer and timeout action (O5) | Medium | Simulate timeout abuse; owner sets the value |
