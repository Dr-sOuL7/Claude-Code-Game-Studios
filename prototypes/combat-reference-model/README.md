<!-- PROTOTYPE - NOT FOR PRODUCTION -->
# Combat Reference Model (audit tool)

**Status**: concluded (findings below). Throwaway — never extended, never shipped.

## Hypothesis

The combat rules in the owner's original spec, with its gaps filled by the most
literal reading (decisions D1–D17 in `design/gdd/combat-system.md`), are
numerically well-behaved: every probability stays in [0,1], every match
terminates, matches last 20–30 turns, all three finishes occur, and no single
action policy dominates.

## How to run

Plain Python 3, no dependencies. Run from this directory:

```
python3 -I run_audit.py              # 12,250 policy-pair matches + 512-profile baseline
python3 -I sweep_burst_pressure.py   # burst calibration x pressure scale
python3 -I sweep_energy.py           # collision energy-loss divisor
```

Seeds are fixed; `results.txt` holds the output of all three.

Python is used only because this was written before a Godot binary was
available. The shipping engine is GDScript (`src/`) and must be rewritten from the
GDD, not ported from this file.

## Findings (see `results.txt`)

Valid: no NaN/inf, collision P stays in [0.2, 0.9], burst P in [0.0008, 0.75]
(with the exponential normalisation), all matches terminate (max 56 turns).

Not valid / not yet healthy, as specified:

1. **Literal burst formula is not a probability** (15–615 per Attack hit); a
   normalisation is mandatory (D2).
2. **Collision probability saturates**: 64.1% of 512x512 pairings sit at the 0.9
   cap before any action modifier, so ATTACK's +0.15 changes nothing there.
3. **Matches are far too short**: median 6–9 turns against the 20–30 target. This
   holds across 17 calibration settings; the best median reached was 14.
4. **Ring-out essentially never happens** with pressure scale 1.0 (position pressure
   peaks at ~119 in the main run against a threshold of 120). At scale 6.0 it appears
   (18–25% of matches) but Defense-type builds collapse (win rate 0.04–0.15), because
   the MS/ST trade-off makes high-ST discs light.
5. **Attack-spam is the highest-scoring fixed policy in every configuration** (mean
   win rate 0.62–0.67 across all 17 settings). The heuristic ADP, which attacks
   whenever it is ahead on energy, is close behind (0.58–0.64); DEFEND, DODGE and
   CHARGE policies score 0.32–0.54. Structural, not a calibration artefact.
6. **Charge→Special loop loses** (0.32–0.41): seven exposed turns for one hit.
   **Dodge is weak** (0.33–0.38).
7. **Stamina type wins most matches** (0.66–0.84) when matches run long.

None of this says the game cannot be balanced. It says the spec as written is
not yet balanced, and that the fixes are rule changes (counterplay to Attack,
a reason to Special), not only number changes. Nothing here may be quoted as
evidence that the game IS balanced.

## Limits

- Fixed policies and a few heuristics, not optimal play; a real balance claim
  needs the matrix-game analysis planned for Phase 6.
- Random sample of build pairs (250/80 pairs), not all 131,328 pairings.
- Every number depends on the gap-filling decisions D1–D17; changing one changes
  the results.
