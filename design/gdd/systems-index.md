# Systems Index: SPINFORGE

> **Status**: Draft (written under the owner's delegated approval of 2026-11-14; owner review pending)
> **Created**: 2026-11-14
> **Last Updated**: 2026-11-14
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

SPINFORGE is a two-player, turn-based duel with hidden simultaneous commits. Every system either feeds the duel (parts and derived stats), is the duel (the combat engine and its finishes), wraps the duel in a mode (local, practice, online, spectating), persists it (accounts, builds, history, ratings) or shows it (workshop, arena, HUD, results). The pillars shape the scope: *Conservation of Power* forbids progression, loot or paid-stat systems, so there is no economy, no XP and no unlock track — the usual "Progression" and "Economy" categories are intentionally empty. *Skill Over Luck* and *Counterplay Everywhere* make the combat engine and its balance tooling the centre of gravity; both are Foundation systems that everything else consumes read-only. *Spectacle That Explains* puts the 3D presentation downstream of a typed event stream, so visuals never compute rules.

Per-system notes (balanced density):

- **Component Catalogue** — the fixed data set: 15 cosmetic Cores, 8 Blades (AP+LI=80), 8 Discs (MS+ST=100), 8 Tips (MB+SM=100). Versioned data; the conservation sums are tests. Everything that names a part reads this.
- **Top Construction & Derived Stats** — a build is four part ids; derived stats, the emergent type (F0) and the identity domain are computed, never stored. Owns the 512-profile and 7,680-build facts.
- **Combat Ruleset (data)** — the versioned tunables file (ADR-0001). Separated from the engine so a balance change is data plus a report, never code.
- **Combat Engine** — pure GDScript resolution of one turn (`combat-system.md`). The only place rules exist.
- **Match Orchestrator (local)** — the client-side state machine that runs a match from two builds to a result, feeding actions to the engine and events to presentation. Local Versus, Practice and the online client all sit on it; online swaps its action source for the server.
- **Practice AI** — difficulty-tiered opponents that choose actions from public state; must call the same `legal_actions` the UI uses and may never read hidden commits.
- **Local Versus** — pass-the-device hidden commit with a handoff screen; the first playable milestone.
- **Network Protocol & Client** — versioned JSON over `WebSocketPeer` (ADR-0002); client-side reconnect and version check.
- **Authoritative Match Server** — headless Godot process: lobby, match actors, timers, resolution, spectating (ADR-0003).
- **Matchmaking & Invitations** — queue by rating, private codes, direct challenges; no criterion may touch power because none exists.
- **Accounts & Profiles** — Supabase Auth in the browser; display names; moderation (ADR-0004).
- **Persistence** — builds, matches, turns, ratings, rulesets via server-only writes (ADR-0004).
- **Match History & Replay** — stored seed + action log reproduces any match; replays play back the event stream.
- **Rankings** — outcome-based rating and leaderboard views; grants nothing but a number.
- **Spectator Mode** — read-only live event feed of an active match; no action permission.
- **Workshop UI (The Forge)** — pick parts, see live stats and type; the onboarding surface.
- **Battle HUD & Arena UI** — meters, action commit, reveal, timers, result screen; every number the engine emits is visible.
- **3D Presentation & VFX** — procedural top meshes from stats, core palettes, collision/burst/ring-out animations driven solely by events; mobile-web quality tiers.
- **Audio** — impact/burst/ring-out SFX and light music under Web Audio limits (no effects on samples in Web exports).
- **Shell & Navigation** — the 14 screens, routing, responsive layout, PWA install.
- **Settings & Accessibility** — colourblind-safe state cues, text scale, reduced motion, input options.
- **Admin & Ruleset Publication** — role-gated tools to publish a tested ruleset version and moderate names.
- **Balance Simulator & Reports** — headless tournaments on the real engine; the gate for any "balanced" claim (ADR-0006).
- **Telemetry (minimal)** — match outcome aggregates for balance; no personal tracking beyond what accounts need.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Component Catalogue | Core | MVP | Not Started | — | — |
| 2 | Top Construction & Derived Stats | Core | MVP | Not Started | — | Component Catalogue |
| 3 | Combat Ruleset (data) (inferred) | Core | MVP | Not Started | — | — |
| 4 | Combat Engine | Gameplay | MVP | In Design | design/gdd/combat-system.md | Top Construction & Derived Stats, Combat Ruleset |
| 5 | Match Orchestrator (local) (inferred) | Core | MVP | Not Started | — | Combat Engine |
| 6 | Local Versus | Gameplay | MVP | Not Started | — | Match Orchestrator |
| 7 | Workshop UI (The Forge) | UI | MVP | Not Started | — | Top Construction & Derived Stats |
| 8 | Battle HUD & Arena UI | UI | MVP | Not Started | — | Match Orchestrator |
| 9 | 3D Presentation & VFX | UI | Vertical Slice | Not Started | — | Match Orchestrator, Component Catalogue |
| 10 | Shell & Navigation (inferred) | UI | MVP | Not Started | — | — |
| 11 | Balance Simulator & Reports | Meta | MVP | Not Started | — | Combat Engine, Combat Ruleset |
| 12 | Practice AI | Gameplay | Vertical Slice | Not Started | — | Match Orchestrator |
| 13 | Audio | Audio | Vertical Slice | Not Started | — | Match Orchestrator |
| 14 | Network Protocol & Client (inferred) | Core | Alpha | Not Started | — | Combat Engine |
| 15 | Authoritative Match Server | Gameplay | Alpha | Not Started | — | Network Protocol, Combat Engine, Combat Ruleset |
| 16 | Accounts & Profiles | Persistence | Alpha | Not Started | — | Network Protocol |
| 17 | Persistence (builds, matches, ratings) (inferred) | Persistence | Alpha | Not Started | — | Accounts & Profiles, Authoritative Match Server |
| 18 | Matchmaking & Invitations | Gameplay | Alpha | Not Started | — | Authoritative Match Server, Accounts & Profiles |
| 19 | Match History & Replay | Persistence | Alpha | Not Started | — | Persistence, Match Orchestrator |
| 20 | Rankings | Meta | Full Vision | Not Started | — | Persistence |
| 21 | Spectator Mode | Gameplay | Full Vision | Not Started | — | Authoritative Match Server |
| 22 | Settings & Accessibility (inferred) | Meta | Vertical Slice | Not Started | — | Shell & Navigation |
| 23 | Admin & Ruleset Publication | Meta | Full Vision | Not Started | — | Persistence, Balance Simulator & Reports |
| 24 | Telemetry (minimal) (inferred) | Meta | Full Vision | Not Started | — | Persistence |

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Core** | Foundation systems everything depends on | Component catalogue, derived stats, ruleset data, match orchestrator, network protocol |
| **Gameplay** | The systems that make the game fun | Combat engine, modes (local, practice, online, spectator), matchmaking |
| **Persistence** | Save state and continuity | Accounts, builds, matches, ratings, history |
| **UI** | Player-facing information displays | Workshop, battle HUD, 3D presentation, shell |
| **Audio** | Sound and music systems | SFX and music |
| **Meta** | Systems outside the core game loop | Balance simulator, rankings, settings/accessibility, admin, telemetry |

Progression, Economy and Narrative are deliberately absent (pillar *Conservation of Power*; no story at launch).

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable: Workshop + Local Versus in a browser | Design FIRST |
| **Vertical Slice** | One complete, polished match experience with AI and visuals | Practice vs AI, 3D arena, mobile-web pass | Design SECOND |
| **Alpha** | Online play present in rough form | Accounts, online PvP, matchmaking, history | Design THIRD |
| **Full Vision** | Spectating, rankings, admin, polish | Public launch | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Component Catalogue — the fixed, versioned data every stat derives from
2. Combat Ruleset (data) — tunables, versioned independently of code
3. Shell & Navigation — screen routing and responsive frame everything renders inside

### Core Layer (depends on foundation)

1. Top Construction & Derived Stats — depends on: Component Catalogue
2. Combat Engine — depends on: Top Construction & Derived Stats, Combat Ruleset
3. Match Orchestrator (local) — depends on: Combat Engine
4. Network Protocol & Client — depends on: Combat Engine (shares event and state schemas)

### Feature Layer (depends on core)

1. Local Versus — depends on: Match Orchestrator
2. Practice AI — depends on: Match Orchestrator
3. Balance Simulator & Reports — depends on: Combat Engine, Combat Ruleset
4. Authoritative Match Server — depends on: Network Protocol, Combat Engine, Combat Ruleset
5. Accounts & Profiles — depends on: Network Protocol
6. Persistence — depends on: Accounts & Profiles, Authoritative Match Server
7. Matchmaking & Invitations — depends on: Authoritative Match Server, Accounts & Profiles
8. Match History & Replay — depends on: Persistence, Match Orchestrator
9. Spectator Mode — depends on: Authoritative Match Server
10. Rankings — depends on: Persistence
11. Admin & Ruleset Publication — depends on: Persistence, Balance Simulator & Reports

### Presentation Layer (depends on features)

1. Workshop UI (The Forge) — depends on: Top Construction & Derived Stats
2. Battle HUD & Arena UI — depends on: Match Orchestrator
3. 3D Presentation & VFX — depends on: Match Orchestrator (events), Component Catalogue (palettes, geometry params)
4. Audio — depends on: Match Orchestrator (events)

### Polish Layer (depends on everything)

1. Settings & Accessibility — depends on: Shell & Navigation
2. Telemetry (minimal) — depends on: Persistence

Bottlenecks: **Combat Engine** (11 systems depend on it directly or through the orchestrator) and **Match Orchestrator** (every mode and every presentation system). Leaves: Rankings, Spectator, Admin, Telemetry, Audio.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Component Catalogue + Top Construction & Derived Stats (one GDD: `top-construction.md`) | MVP | Foundation/Core | systems-designer | S |
| 2 | Combat Engine (`combat-system.md`, finish v0.3 and approve) | MVP | Core | systems-designer, game-designer | L (in progress) |
| 3 | Combat Ruleset (data) — documented inside `combat-system.md` Tuning Knobs; no separate GDD | MVP | Foundation | systems-designer | — |
| 4 | Match Orchestrator + Local Versus (`match-flow.md`) | MVP | Core/Feature | game-designer | M |
| 5 | Workshop UI (The Forge) — UX spec via `/ux-design` | MVP | Presentation | ux-designer | M |
| 6 | Battle HUD & Arena UI — UX spec via `/ux-design` | MVP | Presentation | ux-designer | M |
| 7 | Shell & Navigation — UX spec (player journey) | MVP | Foundation | ux-designer | S |
| 8 | Balance Simulator & Reports (`balance-simulator.md`) | MVP | Feature | systems-designer, qa-lead | M |
| 9 | Practice AI (`practice-ai.md`) | Vertical Slice | Feature | ai-programmer, game-designer | M |
| 10 | 3D Presentation & VFX (art bible first, then `presentation.md`) | Vertical Slice | Presentation | art-director, technical-artist | L |
| 11 | Audio (sound bible) | Vertical Slice | Presentation | audio-director | S |
| 12 | Settings & Accessibility (`accessibility-requirements.md`) | Vertical Slice | Polish | accessibility-specialist | S |
| 13 | Network Protocol & Client + Authoritative Match Server (`online-play.md`) | Alpha | Core/Feature | network-programmer, security-engineer | L |
| 14 | Accounts & Profiles + Persistence (`accounts-and-persistence.md`) | Alpha | Feature | security-engineer | M |
| 15 | Matchmaking & Invitations (`matchmaking.md`) | Alpha | Feature | game-designer, network-programmer | M |
| 16 | Match History & Replay (`history-and-replay.md`) | Alpha | Feature | game-designer | S |
| 17 | Rankings (`rankings.md`) | Full Vision | Feature | systems-designer | S |
| 18 | Spectator Mode (inside `online-play.md`) | Full Vision | Feature | network-programmer | S |
| 19 | Admin & Ruleset Publication (`admin.md`) | Full Vision | Feature | tools-programmer | S |
| 20 | Telemetry (minimal) (`telemetry.md`) | Full Vision | Polish | analytics-engineer | S |

---

## Circular Dependencies

- None found. The one near-cycle — Persistence ↔ Authoritative Match Server — is broken by ADR-0003's write-behind rule: the server runs matches in memory and persists afterwards, so the server depends on Persistence only for durability, never for play. Admin depends on the Simulator (a ruleset needs a report) and the Simulator never depends on Admin.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Combat Engine | Design | Build-level imbalance (combat GDD §12.3): win rates 0.02–0.86; O8 fix under simulation | Keep every rule change data-driven; simulator gate (ADR-0006); O8 sweep before implementation |
| Authoritative Match Server | Technical | Headless Godot WebSocket server over TLS to browser clients is unproven; tab-backgrounding disconnects | Spike before ADR-0002 is relied on in stories; reconnect-first design (ADR-0003) |
| 3D Presentation & VFX | Technical/Scope | Single-threaded WebAssembly + WebGL 2 on phones; Safari WebGL 2 issues (Godot 4.7 docs) | Quality tiers; profile the first arena scene on real devices; procedural meshes to cut asset work |
| Balance Simulator | Technical | GDScript throughput unknown; 131k pairs | Parallel processes, adaptive sampling; differential oracle |
| Accounts & Persistence | Technical | Supabase CORS/RLS behaviour not yet verified | First spike from the production origin |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 24 |
| Design docs started | 1 (combat-system.md) |
| Design docs reviewed | 0 |
| Design docs approved | 0 (combat rules R1–R7 approved; GDD still In Design pending O8) |
| MVP systems designed | 0/11 (combat in progress) |
| Vertical Slice systems designed | 0/5 |

---

## Next Steps

- [ ] Owner reviews this enumeration (anything missing, merged or unnecessary)
- [ ] `/design-system top-construction` — first MVP GDD (small)
- [ ] Finish `combat-system.md` v0.3 (O8) and `/design-review` it
- [ ] `/design-system match-flow`, then `/ux-design` for Forge and Battle HUD
- [ ] `/create-architecture` against ADR-0001..0006
- [ ] `/gate-check` before Production
