# Evidence: combat engine vs independent oracle (story combat-engine/004)

**Date**: 2026-11-14 · **Engine**: Godot 4.7.2 · **Ruleset**: v1 (GDD v0.3)

## What was compared
The GDScript engine (`src/core/combat/`) against `prototypes/combat-reference-model/oracle_v1.py`, a
separate Python implementation written from the GDD and the same JSON data files. Both use the
same MINSTD streams, the stream-seed mixing and the action-selection stream documented in GDD
"Resolution Order and Randomness". Per turn they compare: actions, collision probability and
outcome, burst and ring-out probabilities, both players' energy, stability, position pressure,
passive pressure, special meter, guard/dodge/combo/repeat stacks, last action, and the finish
record. Integers, booleans and strings must be identical; floats must agree to 1e-9.

## Result
`python3 -I tools/sim/compare_traces.py compare 200`:
**200 matches, 6,377 turns, finishes ring-out 35 / burst 38 / spin 127, 0 mismatching matches.**

## The check was watched failing
- Engine mutated so momentum stacks never apply: **108 of 200 matches mismatched**.
- Oracle knob `defend_counter.ratio` changed from 4.0 to 3.9: **199 of 200 mismatched**.
- Both sides restored: 0 of 200.

## Caveats (stated, not hidden)
- The oracle and the engine were written by the same author from the same GDD, so a *misreading* of
  the GDD would be shared; the check proves the two implementations agree, not that the GDD is right.
- Float equality is checked at 1e-9; probability thresholds are compared by draw outcome, so a
  1-ulp difference could in principle flip a roll. None did in 6,377 turns.
- The comparison ran on Linux x86_64 only. Web-export behaviour of `exp()`/`pow()` is not yet checked
  (ADR-0001 Verification Required).

## CI coverage
`tests/integration/combat/oracle_agreement_test.gd` replays 24 frozen oracle traces (742 turns:
14 spin, 6 burst, 4 ring-out) on every push.

## Throughput measurement (answers architecture QQ-03)
2,000 random matches (61,749 turns) through `tools/sim/dump_match.gd` on Godot 4.7.2, Linux, single process,
**including** building a trace dictionary per turn and writing 17 MB of JSON: **5.1 s, ≈ 12,100 turns/s,
≈ 390 matches/s**. The Python oracle did ≈ 65,000 turns/s on the same machine. The GDScript figure is a
conservative lower bound for a simulator that skips tracing. At 390 matches/s, 131,328 profile pairs × 100
matches ≈ 13 M matches ≈ 9 hours on one core, ≈ 2–3 hours on 4 cores, before any speed-up from dropping the
trace. A stratified/adaptive sample (ADR-0006) is still the plan; exhaustive coverage is plausible, not assumed.
