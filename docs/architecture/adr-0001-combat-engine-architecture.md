# ADR-0001: Combat Engine — Pure, Deterministic, Data-Driven GDScript Library

## Status

Accepted

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09 (proposed); accepted 2026-11-14

## Last Verified

2026-11-09 (against `design/gdd/combat-system.md` v0.2 and Godot 4.7 docs fetched this run; GDScript float width and `exp()` cross-platform determinism are NOT SOURCED this run — see Verification Required)

## Decision Makers

Owner (accepted 2026-11-14, on Claude's recommendation); authored by Claude.

## Summary

All combat rules live in one Godot-independent GDScript library that runs identically in the browser client (Practice, Local Versus), the authoritative server, and the balance simulator. It is deterministic (injected integer PRNG), data-driven (versioned ruleset file) and emits a typed event list that presentation only displays.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (GDScript) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (4.5–4.7 are beyond the model's reliable knowledge) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; Godot 4.7 "Exporting for the Web" (C# cannot export to Web) |
| **Post-Cutoff APIs Used** | None. Only `RefCounted`, `Dictionary`, `Array`, typed GDScript — all pre-4.5 |
| **Verification Required** | (1) bit-exact integer PRNG on Linux server vs Web build (golden vector test); (2) float width and `exp()` behaviour across platforms — a probability threshold flipping by 1 ulp must not change a result between server and client for online play (online results are server-computed only; clients display events); (3) turns/second benchmark in GDScript |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002, ADR-0003, ADR-0006 |
| **Blocks** | Every combat story; Practice AI; Local Versus; Simulator |
| **Ordering Note** | Must be Accepted before any engine code is written |

## Context

### Problem Statement
The combat system is the product. It must run in three very different hosts (browser, headless server, headless batch simulator), be reproducible for replays, bug reports and balance analysis, and be changeable only through tested, versioned rules.

### Current State
`design/gdd/combat-system.md` (v0.2 draft) specifies the rules; `prototypes/combat-reference-model/` is a throwaway Python model of them.

### Constraints
- Godot 4 cannot export C# projects to the Web, so the engine is GDScript (Godot 4.7 export docs).
- Presentation (3D, UI) must never compute combat (project pillar "Spectacle That Explains"; `.claude/rules/gameplay-code.md`).
- Gameplay values must be external data (`.claude/docs/coding-standards.md`).

### Requirements
- Same inputs ⇒ same outputs (GDD AC-4, AC-5).
- No dependence on `Node`, scenes, autoloads, `Input`, `Time`, `OS`, or global RNG.
- State serializable to JSON-compatible data for persistence and reconnection.
- Hidden information: resolving a turn takes both actions at once; the engine never exposes one player's pending action.

## Decision

Location: `src/core/combat/` (code root for Godot is `src/`).

```
Ruleset (JSON data, versioned)  ─┐
BuildStats  (from parts)         ├─►  CombatEngine.resolve_turn(state, action_a, action_b) ─► TurnResult
MatchState (plain data, + PRNG)  ─┘                                                       { state, events[], finished, winner, finish_type }
```

### Key Interfaces
```gdscript
class_name CombatEngine extends RefCounted
static func new_match(ruleset: Ruleset, build_a: BuildStats, build_b: BuildStats, seed: int) -> MatchState
static func legal_actions(state: MatchState, player: int) -> Array[int]
static func resolve_turn(state: MatchState, action_a: int, action_b: int) -> TurnResult   # mutates state, returns events
# MatchState.to_dict() / MatchState.from_dict(d)  — includes PRNG state, turn, per-player dynamic state
# Event = Dictionary { "type": String, "turn": int, ... }  — documented schema, versioned with ruleset
```

### Implementation Guidelines
- Engine classes **must** extend `RefCounted` (or be static) and **must never** reference `Node`, `SceneTree`, `Engine`, `OS`, `Time`, `randf*`, `RandomNumberGenerator`, or autoloads.
- Randomness **must** come from an injected PRNG stored in `MatchState`. The PRNG **must** be integer-only with every intermediate provably inside GDScript's 64-bit signed `int` (candidate: Park–Miller MINSTD, `16807 × state mod (2^31−1)`, products < 2^46). A golden-vector test fixes its first 1,000 outputs.
- All tunables **must** come from the `Ruleset` (`assets/data/combat/ruleset_vN.json`); the loader lives outside `src/core/combat/`. A match record stores `ruleset_version`; a published version **must never** be edited (new file instead).
- `resolve_turn` **must** be atomic: validate both actions first, then mutate. Illegal action ⇒ error before any mutation.
- Events are the only output the UI/3D/network may use. Adding rules **must** add events, not hidden side channels.
- Probabilities **must** pass through one clamp helper, and tests assert 0 ≤ p ≤ 1 for sampled states (GDD AC-1).
- Core **must not** appear in any formula (GDD AC-3).

## Alternatives Considered

### Alternative 1: Combat inside scene scripts / Node-based
- **Pros**: Fast to prototype; direct signals to UI.
- **Cons**: Needs a SceneTree to test; couples rules to rendering; unusable for batch simulation.
- **Rejection Reason**: Violates the owner's "combat engine independent of frontend".

### Alternative 2: C# or a GDExtension (native) engine
- **Pros**: Faster simulation.
- **Cons**: C# cannot export to Web (sourced); GDExtension needs a separate Web build and adds toolchain risk.
- **Rejection Reason**: Breaks the browser requirement or adds large risk for a performance need not yet measured.

### Alternative 3: Server-side engine in another language with a client port
- **Pros**: Could use mature server tooling.
- **Cons**: Two implementations will drift; every rule change is made twice.
- **Rejection Reason**: One engine, one language.

## Consequences

### Positive
- One implementation for practice, local, online, replays and simulation.
- Rules are testable headless; rule changes are data + tests + sim evidence.

### Negative
- GDScript is slower than native for million-match tournaments (mitigated in ADR-0006).
- Discipline needed: nothing may leak Node dependencies into `src/core/combat/`.

### Neutral
- Practice and Local Versus run client-side with no authority; only online results are authoritative.

## Risks
- Float behaviour differs between platforms ⇒ replays recomputed on another platform diverge. *Mitigation*: replays play back the stored event list, never recompute; cross-platform float checks are a story.
- Custom PRNG quality. *Mitigation*: statistical test in the golden-vector story; algorithm can be replaced under a new ruleset version.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | AC-3 Core never affects output | Engine API takes `BuildStats`, which has no core field |
| combat-system.md | AC-4 determinism | Injected integer PRNG inside serializable `MatchState` |
| combat-system.md | AC-1/AC-7 bounded probabilities, hidden actions | Single clamp helper; `resolve_turn` takes both actions atomically |
| combat-system.md | Tuning Knobs are data | Versioned ruleset file |

## Performance Implications
- **CPU**: per-turn cost small (tens of operations); GDScript throughput unmeasured — benchmark in the first engine story.
- **Memory**: negligible; `MatchState` is a few hundred bytes.
- **Load Time**: ruleset JSON parsed once.
- **Network**: events are small dictionaries (< 2 KB per turn expected).

## Migration Plan
Greenfield. The Python reference model is a differential-test oracle (ADR-0006), not ported code.

**Rollback plan**: none needed before code exists; afterwards, a ruleset version pin allows reverting rules without code change.

## Validation Criteria
- GDD acceptance criteria 1–9 pass in gdUnit4 on Linux headless.
- Golden PRNG vector identical in Linux headless and a Web build run in Chromium.
- Importing `src/core/combat/` into a bare headless script (no scene) works.

## Related
- `design/gdd/combat-system.md`; `prototypes/combat-reference-model/`
- ADR-0003, ADR-0006
