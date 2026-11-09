# ADR-0006: Balance and Verification Strategy — Property Tests, Differential Oracle, Headless Simulator

## Status

Proposed

> Only the user (or `technical-director` on the user's explicit confirmation) may set `Accepted`.

## Date

2026-11-09

## Last Verified

2026-11-09 (throughput numbers come from this session's Python reference model; GDScript throughput is NOT measured)

## Decision Makers

Owner (delegated to Claude for a proposal); technical-director review pending.

## Summary

Combat correctness and balance are established by three layers: invariant/property tests in gdUnit4, a one-time differential match of the GDScript engine against the Python reference model, and a headless Godot simulator that runs tournaments on the same engine and writes versioned reports. No ruleset change ships, and nothing is called "balanced", without a report.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md` (gdUnit4 6.2.x lists Godot 4.5–4.7.1 as compatible); Godot 4.7 dedicated-server page (`--headless`) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | GDScript turns/second; parallel headless processes on the CI/dev machine; gdUnit4 runs headless in CI |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 |
| **Enables** | Balance gate (Phase 6), live rule changes |
| **Blocks** | Any "balanced" claim; rule-change stories |
| **Ordering Note** | Needs the first working engine story; the Python model already exists |

## Context

### Problem Statement
The owner requires: all 7,680 builds tested (512 distinct profiles), no balance claim without simulation evidence, and conservation laws preserved. This session's Python model already shows action-level balance is reachable but build-level balance is not (combat GDD §12.3), so this process is where most of the remaining design work happens.

### Constraints
- The shipping engine is GDScript (ADR-0001). The Python model is throwaway (`.claude/rules/prototype-code.md`: prototypes are rewritten, never extended).
- The pair space is 512×513/2 = 131,328 unordered profile pairs (cores are cosmetic).
- Measured baseline (Python model, this session): 20,000 mixed-policy matches in about 7 s on this machine, i.e. a few tens of thousands of turns per second per process; GDScript speed unknown.

### Requirements
Track build and archetype win rates, action effectiveness, match length, finish mix, stalling, dominant strategies and exploitable combinations; cross-check the engine against an independent implementation.

## Decision

1. **Property/invariant tests** (gdUnit4, `tests/unit/combat/`, BLOCKING): GDD acceptance criteria AC-1..AC-9, determinism, seat symmetry, core invariance, termination bound, worked-example reproduction.
2. **Differential oracle (one-time per major ruleset)**: run N seeded matches through the GDScript engine and the Python reference model with the same integer PRNG; event-by-event equality, with a small tolerance only for floating-point values. After a match the Python model is frozen as a documented oracle, not a dependency.
3. **Simulator** (`tools/sim/`, headless Godot): runs scripted policies (pure, rotating, heuristic, and an optimal-play solver for sampled pairs), parallel across OS processes, deterministic by seed. Outputs JSON/CSV to `production/qa/balance/<ruleset>/`:
   - per-profile win rate vs the field, per-part and per-type marginals,
   - action effectiveness and the 5×5 payoff matrix per sampled pair, solved as a zero-sum matrix game (strictly dominated actions, game value),
   - finish mix, length distribution, stalling metric,
   - exploit candidates (profiles beyond declared bands).
4. **Gate**: a ruleset version may be marked `balanced` only when its report meets bands declared in the GDD (owner-approved targets, GDD O4). Reports are committed with the ruleset change. A smaller sim smoke run is part of CI (ADR-0005).
5. **Sampling plan**: stratified/adaptive sampling with confidence intervals; exhaustive coverage is claimed only if the measured throughput allows it, and the report states what was sampled.

### Implementation Guidelines
- Simulator and tests **must** call `CombatEngine` exactly as the server does; **must not** reimplement rules.
- Every report **must** record `ruleset_version`, engine commit, seeds, sample sizes and policies used.
- A report **must** state what it did not cover.
- Changes to combat rules **must** be data (ruleset) plus tests plus a report in the same change.

## Alternatives Considered

### Alternative 1: Simulate only in GDScript
- **Pros**: One language.
- **Cons**: No independent check of the engine; slow for deep analysis.
- **Rejection Reason**: The oracle step catches implementation errors cheaply.

### Alternative 2: Native or C# simulator
- **Pros**: Fast.
- **Cons**: Can't use the same engine code (C# excluded from Web; native port duplicates rules).
- **Rejection Reason**: Same-engine rule.

### Alternative 3: Manual playtesting only
- **Pros**: Finds feel problems.
- **Cons**: Cannot cover 131k pairs or detect dominance reliably.
- **Rejection Reason**: Insufficient for the owner's evidence requirement. Playtests complement, not replace.

## Consequences

### Positive
- Rule changes are cheap to evaluate and auditable.
- Engine bugs are caught by an independent implementation.

### Negative
- Maintaining reports and bands is ongoing work.
- Optimal-play analysis may need offline tooling (LP solver); that tooling is analysis-only and never shipped.

### Neutral
- The Python model remains in `prototypes/` as a historical oracle.

## Risks
- GDScript too slow for the needed sampling. *Mitigation*: parallel processes, adaptive sampling; fall back to a faster analysis harness operating on engine-exported payoff tables.
- Policies are not human play. *Mitigation*: playtest reports; learn from real match logs once online.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | Acceptance Criteria 1–9 | Layer 1 tests |
| combat-system.md | Balance gate (O4), O8 component imbalance | Layer 3 reports and band gate |
| game-concept.md | "Do not declare the game balanced without simulation evidence" | Gate rule |

## Performance Implications
- **CPU**: CI sim smoke must stay within a few minutes; full tournaments run on demand.
- **Memory**: low.
- **Load Time**: none.
- **Network**: none.

## Migration Plan
Greenfield. **Rollback plan**: a ruleset version that fails its report is not published; the previous version stays live.

## Validation Criteria
- GDScript engine matches the Python oracle on a declared sample of seeded matches.
- A full report for the current ruleset exists and states coverage.
- A deliberately broken rule (e.g. burst formula unclamped) is caught by the tests or the report.

## Related
- ADR-0001, ADR-0005; `design/gdd/combat-system.md`; `prototypes/combat-reference-model/`
