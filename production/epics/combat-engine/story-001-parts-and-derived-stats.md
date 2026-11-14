# Story 001: Component catalogue and derived stats

> **Epic**: Combat Engine
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: none — no control manifest yet (`/create-control-manifest` not run)
> **Last Updated**: 2026-11-14

## Context

**GDD**: `design/gdd/combat-system.md` (F0, AC-2, AC-3, AC-6) and `design/gdd/game-concept.md`
**Requirement**: `TR-construction-001`, `TR-construction-002`, `TR-construction-003`

**ADR Governing Implementation**: ADR-0001: Combat engine architecture
**ADR Decision Summary**: Engine inputs are plain data; `BuildStats` carries the six stats, the type and the identity domain and has no core field.
**ADR Version**: 2026-11-09

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: typed GDScript only; `FileAccess`/`JSON` for the loader (4.4 changed `FileAccess` return types — verify on the installed 4.7.2).

**Control Manifest Rules (this layer)**: none yet. Apply `.claude/rules/engine-code.md` (code under `src/core/`): no allocations in hot paths — derivation runs once per build, not per frame; document single-thread use.

## Acceptance Criteria

- [ ] Every Blade has AP+LI = 80, every Disc MS+ST = 100, every Tip MB+SM = 100; all 512 part combinations total 280 (AC-2).
- [ ] F0 classifies B03D02T02 → Attack, B05D05T07 → Defense, B04D04T05 → Stamina, B01D01T01 → Balance, and the 512-profile distribution is Attack 169, Balance 167, Stamina 128, Defense 48 (AC-6).
- [ ] Identity domain: 223 Attack, 168 Stamina, 89 Defense, 32 none over the 512 profiles (reference model output).
- [ ] The 15 cores load with a name and two palette colours; `BuildStats` has no core field (AC-3 precondition).
- [ ] Data files are valid JSON, `snake_case` keys, named `parts_*.json` (`.claude/rules/data-files.md`).

## Implementation Notes

- `src/core/parts/parts_catalogue.gd`: loads `assets/data/parts/parts_catalogue.json` and `parts_cores.json`; also constructible from a `Dictionary` so unit tests need no file I/O.
- `src/core/parts/build_stats.gd`: `static func from_parts(blade, disc, tip, type_margin)`; F0 exactly as the GDD (scores `off`, `def`, `sta`; ties resolve in the order Attack, Defense, Stamina as the reference model does).
- No `Node`, autoload or scene reference anywhere under `src/core/`.

## Out of Scope

- Story 002: ruleset loading and the PRNG.
- Story 003: any combat formula.

## Files

- `assets/data/parts/parts_catalogue.json`, `assets/data/parts/parts_cores.json`
- `src/core/parts/parts_catalogue.gd`, `src/core/parts/build_stats.gd`
- `tests/unit/parts/parts_conservation_test.gd`, `tests/unit/parts/build_stats_classification_test.gd`

## QA Test Cases

N/A — no qa-lead specs at this tier (lean); implement against the Acceptance Criteria above.

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/parts/*_test.gd` — must exist and pass.
**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: `production/epics/combat-engine/story-003-resolve-turn.md`
