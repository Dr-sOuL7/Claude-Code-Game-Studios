# Story 002: Versioned ruleset loader and deterministic PRNG

> **Epic**: Combat Engine
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: none — no control manifest yet
> **Last Updated**: 2026-11-14

## Context

**GDD**: `design/gdd/combat-system.md` (Tuning Knobs; Section 13 values = ruleset v1)
**Requirement**: `TR-combat-001`, `TR-combat-008`

**ADR Governing Implementation**: ADR-0001: Combat engine architecture
**ADR Decision Summary**: All tunables come from a versioned ruleset file; randomness comes from an injected integer-only PRNG stored in `MatchState`, with a golden-vector test.
**ADR Version**: 2026-11-09

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: 64-bit `int` arithmetic; keep every intermediate below 2^62 (MINSTD products < 2^46). 4.7: typed-return overrides need an explicit `return`.

**Control Manifest Rules (this layer)**: none yet; `.claude/rules/engine-code.md` applies.

## Acceptance Criteria

- [ ] `Ruleset.load_version("v1")` returns every knob in GDD Section 8/13 as typed values; a missing key is an error, never a silent default (TR-combat-008).
- [ ] `assets/data/combat/combat_ruleset_v1.json` holds the v0.3 values and a `_doc` pointer to the GDD section per group.
- [x] `Prng.new(seed)` is MINSTD (`state = 16807 * state mod 2147483647`, seed 0 mapped to 1); the first ten outputs and the 10,000th (1043618065) for seed 1 match the published Park–Miller values (first three: 16807, 282475249, 1622650073).
- [ ] `Prng.next_float()` is in [0, 1); `Prng.uniform(a, b)` = `a + (b − a) × next_float()`; `to_dict()`/`from_dict()` round-trip the state exactly (TR-combat-001).

## Implementation Notes

- `src/core/rules/ruleset.gd`: value object with typed getters; `Ruleset.from_dict(d)` for tests; loader `Ruleset.load_version(v)` reads `res://assets/data/combat/combat_ruleset_<v>.json`.
- `src/core/combat/prng.gd`: `class_name Prng extends RefCounted`; integer state only; no `RandomNumberGenerator`.
- Keep the Python oracle in step: story 004 swaps `random.Random` for the same MINSTD in the reference model.

## Out of Scope

- Story 003: using the ruleset in formulas.

## Files

- `assets/data/combat/combat_ruleset_v1.json`
- `src/core/rules/ruleset.gd`, `src/core/combat/prng.gd`
- `tests/unit/combat/prng_golden_test.gd`, `tests/unit/rules/ruleset_load_test.gd`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/prng_golden_test.gd`, `tests/unit/rules/ruleset_load_test.gd` — must exist and pass.
**Status**: [x] Created and passing (26 tests at story close; 58 with story 003's suites; see `production/qa/evidence/combat-engine-oracle.md` for 004)

## Dependencies

- Depends on: None
- Unlocks: `production/epics/combat-engine/story-003-resolve-turn.md`
