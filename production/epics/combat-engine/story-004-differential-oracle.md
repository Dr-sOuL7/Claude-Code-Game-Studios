# Story 004: Differential check against the Python reference model

> **Epic**: Combat Engine
> **Status**: Complete
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

- [x] `prototypes/combat-reference-model/oracle_v1.py` is a fresh implementation from the GDD and the data files (the old model's interleaved loops were seat-dependent), with MINSTD, the same stream mixing and `uniform` mapping; its first five outputs match `prng_golden_test.gd`.
- [x] `tools/sim/dump_match.gd` writes a JSON trace per case (per turn: actions, collision probability/outcome, burst and ring-out probabilities, both players' full state, finish record).
- [x] 200 seeded matches across random builds (random legal actions from the shared action stream) produce identical traces: 6,377 turns, 0 mismatches; the check was watched failing (108/200 and 199/200 on deliberate breaks).
- [x] The phase order and PRNG-stream contract the two sides share is now written into the GDD ("Resolution Order and Randomness"); no mismatch remained.

## Implementation Notes

- The Python side is a prototype (throwaway); do not import it from any production code.
- Record the comparison result in `production/qa/evidence/combat-engine-oracle.md` with the commit hashes compared.

## Out of Scope

- The full balance simulator and report (separate epic).

## Files

- `prototypes/combat-reference-model/oracle_v1.py`
- `tools/sim/match_trace.gd`, `tools/sim/dump_match.gd`, `tools/sim/compare_traces.py`
- `tests/integration/combat/oracle_agreement_test.gd` and `fixtures/oracle_traces.jsonl` (24 frozen oracle traces so CI needs no Python)
- `production/qa/evidence/combat-engine-oracle.md`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/oracle_agreement_test.gd` + evidence doc.
**Status**: [x] Created and passing (`tests/integration/combat/oracle_agreement_test.gd` + `production/qa/evidence/combat-engine-oracle.md`)

## Dependencies

- Depends on: `story-003-resolve-turn.md`
- Unlocks: Match Orchestrator / Local Versus epic; Balance Simulator epic
