# Story 003: resolve_turn — the combat engine

> **Epic**: Combat Engine
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: none — no control manifest yet
> **Last Updated**: 2026-11-14

## Context

**GDD**: `design/gdd/combat-system.md` v0.3 — Detailed Design, Formulas F1–F14, Edge Cases E1–E13, Acceptance Criteria 1–9
**Requirement**: `TR-combat-001` … `TR-combat-007`, `TR-combat-009`, `TR-combat-010`

**ADR Governing Implementation**: ADR-0001: Combat engine architecture
**ADR Decision Summary**: `CombatEngine.resolve_turn(state, a, b)` is pure over `MatchState` + injected PRNG, validates both actions before mutating, and returns a typed event list that is the only output.
**ADR Version**: 2026-11-09

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: `exp()`/float behaviour cross-platform is NOT SOURCED — online results are server-only, replays play events; typed-return overrides need `return`.

**Control Manifest Rules (this layer)**: none yet; `.claude/rules/engine-code.md` applies (pre-size arrays where cheap; document single-thread).

## Acceptance Criteria

- [ ] AC-1 bounded probabilities over 1,000 random states (property test); no NaN/inf.
- [ ] AC-3 core invariance; AC-4 determinism (1,000 cases); AC-5 seat symmetry with mirrored RNG.
- [ ] AC-7 illegal SPECIAL rejected before mutation; `legal_actions` never includes it when meter < cost.
- [ ] AC-8 all 1,000 random matches terminate within the bound computed from the ruleset (194 at v1).
- [ ] AC-9 worked examples: neutral vs neutral ATTACK → base 56.67, ×1.5 = 85.0, ×1.05 (Balance) = 89.25 at spec `ap_exp` 1 — test both `ap_exp` 1.0 and the v1 0.6 value (40 × (40/40)^0.6 = 40 → identical for AP 40).
- [ ] E1–E4, E8, E11: simultaneous finishes, ordering and the energy-exactly-zero loss.
- [ ] Every state change appears in the event list (TR-combat-010).

## Implementation Notes

- Follow `prototypes/combat-reference-model/ref_model_v02.py` `play()` **operation for operation** so story 004's differential check can be exact; where the Python and the GDD differ, the GDD wins and the Python is corrected.
- `MatchState.to_dict()` / `from_dict()` include the PRNG state and all dynamic per-player fields.
- Events: `{"type": String, "turn": int, ...}`; document the schema in `src/core/combat/README.md`.

## Out of Scope

- Story 004: oracle comparison; any UI, AI or network.

## Files

- `src/core/combat/combat_engine.gd`, `src/core/combat/match_state.gd`, `src/core/combat/combat_events.gd`, `src/core/combat/README.md`
- `tests/unit/combat/combat_invariants_test.gd`, `tests/unit/combat/combat_examples_test.gd`, `tests/unit/combat/combat_edge_cases_test.gd`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/*_test.gd` — must exist and pass.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: `story-001-parts-and-derived-stats.md`, `story-002-ruleset-and-prng.md`
- Unlocks: `story-004-differential-oracle.md`
