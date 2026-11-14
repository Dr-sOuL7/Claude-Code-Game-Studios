# Story 003: resolve_turn — the combat engine

> **Epic**: Combat Engine
> **Status**: Complete
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

- [x] AC-1 bounded probabilities over 300 random full matches (property test); no NaN/inf.
- [x] AC-3 core invariance (BuildStats has no core input; `test_core_is_not_an_input`); AC-4 determinism (100 cases) and serialise/resume; AC-5 seat symmetry (150 cases, mirrored player streams).
- [ ] AC-7 illegal SPECIAL rejected before mutation; `legal_actions` never includes it when meter < cost.
- [x] AC-8 300 random matches and the slowest build under passive play terminate within the bound computed from the ruleset (194 at v1).
- [x] AC-9 worked examples: neutral ATTACK = 89.25; B03D01T01 ATTACK = 142.7254 at `ap_exp` 0.6 (independent arithmetic); incoming/stability/pressure/energy ratios and upkeep drain for the neutral build.
- [x] E2–E5, E8, E11 (and E3 draw / tiebreak): finish ordering, simultaneous finishes, dodge floor, defend floor, no-collision turn, energy at or below zero.
- [x] Every energy and stability change appears in the event list (`test_events_account_for_every_energy_change`).

## Implementation Notes

- Follow `prototypes/combat-reference-model/ref_model_v02.py` `play()` **operation for operation** so story 004's differential check can be exact; where the Python and the GDD differ, the GDD wins and the Python is corrected.
- `MatchState.to_dict()` / `from_dict()` include the PRNG state and all dynamic per-player fields.
- Events: `{"type": String, "turn": int, ...}`; document the schema in `src/core/combat/README.md`.

## Out of Scope

- Story 004: oracle comparison; any UI, AI or network.

## Files

- `src/core/combat/combat_engine.gd`, `src/core/combat/match_state.gd`, `src/core/combat/combat_events.gd`, `src/core/combat/README.md`
- `src/core/combat/combat_params.gd`, `player_state.gd`, `turn_result.gd`, `prng.gd` (stream seeding added)
- `tests/unit/combat/combat_invariants_test.gd`, `combat_examples_test.gd`, `combat_edge_cases_test.gd`, `fixtures/combat_fixtures.gd`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/*_test.gd` — must exist and pass.
**Status**: [x] Created and passing (58 tests across parts, rules, PRNG and combat suites; three deliberate breaks of the engine were caught; see `production/qa/evidence/combat-engine-oracle.md` for 004)

## Dependencies

- Depends on: `story-001-parts-and-derived-stats.md`, `story-002-ruleset-and-prng.md`
- Unlocks: `story-004-differential-oracle.md`
