# Story 004: Differential check against the Python reference model

> **Epic**: Combat Engine
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: none — no control manifest yet
> **Last Updated**: 2026-11-14

## Context

**GDD**: `design/gdd/combat-system.md` Section 13 (v0.3 parameters)
**Requirement**: `TR-combat-001`, `TR-combat-009`

**ADR Governing Implementation**: ADR-0006: Balance and verification strategy
**ADR Decision Summary**: One-time differential match of the GDScript engine against the Python reference model with the same integer PRNG; then the model is frozen as an oracle.
**ADR Version**: 2026-11-09

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: float formatting differences are not failures; compare numbers with a 1e-9 relative tolerance, integers and finish types exactly.

## Acceptance Criteria

- [ ] `prototypes/combat-reference-model/oracle_minstd.py` replaces `random.Random` with MINSTD and the same `uniform` mapping; its golden vector matches `prng_golden_test.gd`.
- [ ] `tools/sim/dump_match.gd` prints a JSON trace (per turn: actions, collision, impacts, state) for `(build_a, build_b, seed, policy pair)`.
- [ ] 200 seeded matches across random builds and the 7 policies produce identical traces (finish type, turn count, every integer field, floats within 1e-9) between GDScript and Python.
- [ ] Any mismatch is resolved by changing the implementation that disagrees with the GDD, and the GDD wins.

## Implementation Notes

- The Python side is a prototype (throwaway); do not import it from any production code.
- Record the comparison result in `production/qa/evidence/combat-engine-oracle.md` with the commit hashes compared.

## Out of Scope

- The full balance simulator and report (separate epic).

## Files

- `prototypes/combat-reference-model/oracle_minstd.py`, `prototypes/combat-reference-model/dump_trace.py`
- `tools/sim/dump_match.gd`, `tools/sim/compare_traces.py`
- `tests/integration/combat/oracle_agreement_test.gd` (runs a small embedded subset so CI needs no Python)
- `production/qa/evidence/combat-engine-oracle.md`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/oracle_agreement_test.gd` + evidence doc.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: `story-003-resolve-turn.md`
- Unlocks: Match Orchestrator / Local Versus epic; Balance Simulator epic
