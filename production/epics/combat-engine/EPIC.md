# Epic: Combat Engine

> **Layer**: Core
> **GDD**: design/gdd/combat-system.md
> **Architecture Module**: `src/core/combat/` (+ `src/core/rules/`, `src/core/parts/` — the Foundation data it consumes)
> **Status**: Complete (2026-11-14)
> **Stories**: 4 — see table

## Overview

Implements the pure, deterministic, data-driven combat library every mode, the server and the simulator call (ADR-0001), together with the two Foundation data modules it depends on: the component catalogue with derived stats and type classification (`src/core/parts/`), and the versioned ruleset loader (`src/core/rules/`). The epic ends when a headless script can run a full match from two builds and a seed to a finish, the GDD's acceptance criteria pass in gdUnit4, and the GDScript engine agrees with the Python reference model on seeded matches. No scene, UI or network code belongs here.

## Governing ADRs

| ADR | Status | Decides |
|---|---|---|
| ADR-0001 Combat engine architecture | Accepted | Pure RefCounted library, injected integer PRNG, versioned ruleset, events as the only output |
| ADR-0006 Balance and verification strategy | Accepted | Property tests, differential oracle against the Python model, simulator later |

## GDD Requirements

TR-combat-001 … TR-combat-010, TR-construction-001 … TR-construction-003 (`docs/architecture/tr-registry.yaml`). TR-combat-011 (the balance gate) belongs to the simulator epic.

## Stories

| # | Story | Type | Status | Depends on |
|---|---|---|---|---|
| 001 | `story-001-parts-and-derived-stats.md` | Logic | Complete | — |
| 002 | `story-002-ruleset-and-prng.md` | Logic | Complete | — |
| 003 | `story-003-resolve-turn.md` | Logic | Complete | 001, 002 |
| 004 | `story-004-differential-oracle.md` | Integration | Complete | 003 |

## Definition of Done

- All four stories Done; `tests/unit/combat/` and `tests/unit/parts/` pass headless.
- `godot --headless -s res://tools/sim/dump_match.gd -- <cases> <out>` plays seeded matches to a finish (verified: 200 matches).
- Differential check: 200 seeded matches identical between GDScript and the independent oracle `prototypes/combat-reference-model/oracle_v1.py` at ruleset v1 (done: 0 mismatches).
- No file under `src/core/` references `Node`, `SceneTree`, `OS`, `Time`, `Engine`, `randf`, `randi`, or `RandomNumberGenerator`.
