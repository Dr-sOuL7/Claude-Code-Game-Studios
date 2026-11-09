# Combat System

> **Status**: In Design — DRAFT v0.1 (audited spec). **Not approved.** No combat code may be written from this until the owner signs off on Section 11 (open decisions).
> **Author**: owner (original spec) + Claude (audit, gap-filling, reference model)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09 (numbers below reproduced by `prototypes/combat-reference-model/`)
> **Implements Pillar**: Skill over randomness; stat conservation + nonlinear interaction = balance (pillars doc not yet written)

## Summary

Turn-based, simultaneous-commit duel between two Beyblades built from CORE + BLADE + DISC + TIP. Each turn both players secretly choose one of five actions; the engine resolves engagement, collision, and system effects, then checks three finishes: Burst, Ring-Out, Spin Finish.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Beyblade Construction (components, derived stats, type)`

## Overview

Two players each hold a Beyblade whose six stats (AP, LI, MS, ST, MB, SM) are fixed by its parts and sum to 280 for every build (Blade 80 + Disc 100 + Tip 100). There is no progression and no hard cap; extremes carry built-in penalties. Each turn both players commit one action (ATTACK, DEFEND, DODGE, CHARGE, SPECIAL). The engine rolls whether the two Beyblades collide, computes impact both ways, applies stability damage, recoil, position pressure, burst checks and energy loss, then applies passive drains. The first player to burst, be rung out, or run out of energy loses.

The engine is a pure, deterministic, seeded GDScript library with no scene dependencies (`src/core/combat/`), shared by Practice, Local Versus, and the authoritative server. This document is its single source of truth.

## Player Fantasy

You read your opponent's build and habits, then out-think them: commit to a hit, bait a dodge, wear down a guard, or gamble a charged Special. Wins feel earned from reading and timing, not from stats or luck. Every build has a plan and a weakness; a skilled player with a "bad" build still has a path.

## Detailed Design

### Core Rules

Notation: stats `AP, LI, MS, ST, MB, SM` of the *acting* Beyblade are written bare; the opponent's carry an `opp_` prefix. Rules marked **[D#]** are gap-fills of the original spec; see Section 10.

1. **Match**: players choose builds, then loop turns until a finish. Turn number `t` starts at 1. Passive drain guarantees termination (Section 5, E10).
2. **Turn order**: (1) both commit an action; (2) roll collision; (3) if collided, resolve impact, stability, recoil, pressure, energy, burst; if not, apply passive pressure; (4) system effects (drain, charge, stacks); (5) check finishes; (6) update state.
3. **Actions**: ATTACK, DEFEND, DODGE, CHARGE are always legal. SPECIAL is legal only when `special_meter ≥ 100`. An illegal action is rejected, never substituted silently.
4. **Hidden commit**: neither player (nor any spectator) sees the opponent's action before both have committed and the turn has resolved.
5. **Finishes** (checked in this order each turn **[D13]**): Burst → Ring-Out → Spin Finish. A player who is hit by a burst loses immediately.

### States and Transitions

Static per Beyblade: `AP, LI, MS, ST, MB, SM`, `type ∈ {Attack, Defense, Stamina, Balance}`, `domain` (identity bonus, nullable).

Dynamic per player: `energy` (start `1.2 × SM`), `stability_level` (start 100) **[D1]**, `position_pressure` (start 0), `passive_pressure` (0), `special_meter` (0–100), `guard_stack`, `dodge_stack`, `combo_count`, `last_action`, `repeat_count`.

Match states: `COMMITTING` → `RESOLVING` → (`COMMITTING` | `FINISHED`). `RESOLVING` is atomic.

### Interactions with Other Systems

- **Beyblade Construction**: supplies derived stats, type, domain (Section 4, F0).
- **Practice AI / Online / Local / Spectator**: all call `resolve_turn(state, action_a, action_b, rng)`; none reimplement combat. Online uses server-held actions and broadcasts events after resolution.
- **Battle UI / 3D**: render the event list the engine returns; they never compute combat.
- **Simulation tool**: runs the same engine headless for balance (Phase 6).

## Formulas

All constants named below are tuning knobs (Section 8). Ranges are over the 512 distinct stat profiles. Core is cosmetic and never enters any formula.

**F0 — Type classification** *(replaces the spec's "AP+MB / ST+MS / SM dominant", which cannot work: ST+MS = 100 for every build)* **[D12]**
```
off = (AP + MB − 35) / 110        range 0..1
def = (ST + LI − 40) / 100        range 0..1
sta = (SM − 15) / 70              range 0..1
top = max(off, def, sta); second = next highest
type = argmax if top − second ≥ 0.15 else Balance
```
Result over 512 profiles: Attack 169, Balance 167, Stamina 128, Defense 48. The spec's four examples classify as the spec intends (B03D02T02→Attack, B05D05T07→Defense, B04D04T05→Stamina, B01D01T01→Balance). Defense is rare by construction; see O7.

**F1 — Collision probability** (spec numbers kept) **[D14]**
```
P = 0.4 + (MB + opp_MB)/200
    + 0.005 × max(0, MB − 70) + 0.005 × max(0, opp_MB − 70)        (MB>70 specialization)
    + 0.15 for each player whose action is ATTACK or SPECIAL
    − 0.25 × dodge_eff for each player whose action is DODGE
P = clamp(P, 0.2, 0.9)
dodge_eff = max(0, 1 − 0.10 × dodge_stack)   (dodge_stack = consecutive previous DODGEs) [D8]
```
Range before clamp 0.55..1.25. Note: neutral vs neutral is already 0.90.

**F2 — Base impact**
```
Impact_out = AP × (1 + MB/120) × action_mult × synergy × spec_AP × identity × momentum × initiative × adaptation × rand(0.9, 1.1)
action_mult: ATTACK 1.5, DEFEND 1.0, DODGE 0.7, CHARGE 0.5, SPECIAL 5.0
synergy: Attack type ×1.15; Balance ×1.05
spec_AP = 1 + 0.006 × max(0, AP − 50)
identity = 1.08 if domain == Attack
momentum = 1 + 0.05 × min(3, combo_count − 1) if combo_count ≥ 2 and action ∈ {ATTACK, SPECIAL}  [D9]
initiative = 1.08 if action ∈ {ATTACK, SPECIAL} and opp action ∈ {DODGE, CHARGE}
adaptation = 1.05 if repeat_count ≥ 2 and action ≠ last_action  [D10]
```
Base AP×(1+MB/120): 22.5..102.5. Example: B01D01T01 ATTACK: 40 × (1 + 50/120) = 56.67; × 1.5 = 85.0; × 1.05 (Balance) = 89.25.

**F3 — Incoming impact (target j)**
```
Impact_in = Impact_out(opp) × defend_mult × charge_mult × type_mult × spec_ST
defend_mult (action DEFEND) = 1 − max(0.05, 0.40 − 0.10 × guard_stack)   [D7]
        × 0.80 if Defense type, × 0.92 if domain == Defense
charge_mult (action CHARGE) = 1.25
type_mult = 0.95 if Balance
spec_ST = 1 − 0.005 × max(0, ST − 70)
```
Example (Balance vs Balance, neutral builds, target not defending): 89.25 × 0.95 = 84.8.

**F4 — Stability, recoil, pressure, energy** (spec forms kept)
```
ST_eff = ST × max(0.25, 1 − 0.005 × (t − 1))          arena destabilization
stability_level −= Impact_in / ST_eff                  floor 0   [D1]
recoil (hitter, own stability) = Impact_out / ST_eff_self × (0.85 if Defense type) × (1 + 0.05×min(3,combo_count−1) if momentum)  [D3]
position_pressure += Impact_in / MS × pressure_scale + passive_pressure; passive_pressure = 0   [D5]
energy −= Impact_in / energy_div                       (target)  [D4]
```
Example: 84.8 / ST_eff 50 → stability −1.70; pressure +1.70; energy −4.24 (energy_div 20).

**F5 — Burst probability** *(the spec's `Impact × MS/LI` ranges 15–615 per Attack hit and is not a probability)* **[D2]**
```
x = Impact_in × (opp_MS / LI) × (1 + (100 − stability_level)/100)
    × 1.2 if target action CHARGE   (counted once; the spec lists it twice)
    × 1.05 if opp action ∈ {ATTACK, SPECIAL} and target action ∈ {DODGE, CHARGE}
    × (1 − 0.007 × max(0, LI − 50))
P_burst = min(burst_cap, 1 − exp(−k × x)),   k = −ln(1 − burst_ref_p) / burst_ref_x
```
`burst_ref_x = 106`, `burst_ref_p` is a knob. Worked example: neutral vs neutral, ATTACK hit, full stability: x = 84.8 × (50/40) = 106.0 → P = burst_ref_p (that is the calibration point). Observed x range 1.6..3108; P_burst range 0.0008..0.75 at burst_ref_p = 0.05, cap 0.75.

**F6 — Energy drain and charge**
```
drain/turn = (1 + MB/80) × (0.80 Stamina | 0.95 Balance) × (0.92 if domain==Stamina) × (1 − 0.004 × max(0, SM − 70))
if position_pressure > 70: energy −= position_pressure / 50
CHARGE: special_meter += 15 × (1.25 Stamina | 1.05 Balance), cap 100.   SPECIAL: special_meter = 0
```
Passive-only lifetime: SM 15 → 8.7 turns; SM 50 → 36.9; SM 85 → 85.9 (×1/0.8 for Stamina type).

**F7 — Ring-out** (per turn while `position_pressure > 120`) **[D6]**
```
P_ringout = min(0.90, 0.25 + (position_pressure − 120)/100) × (1 − 0.005 × max(0, MS − 70))
```
**F8 — Stacks**: `guard_stack` +1 per consecutive DEFEND else 0; `dodge_stack` +1 per consecutive DODGE else 0; `combo_count` +1 per collided turn with ATTACK/SPECIAL else 0.

**F9 — Passive pressure**: on a turn with no collision, each player whose action is not ATTACK/SPECIAL gets `passive_pressure += 3`; it is added to that player's own `position_pressure` at their next collision and then reset. **[D5]**

**F10 — Identity bonus** (spec: "dominant stat ≥ 1.25× others → +8% domain efficiency"): the highest F0 score ≥ 1.25 × the mean of the other two sets `domain` to that axis; +8% applied as in F2 (Attack), F3 (Defense), F6 (Stamina). **[D11]**

## Edge Cases

| # | Case | Resolution |
|---|------|-----------|
| E1 | Both players burst in one turn | Draw by default; tie-break by higher remaining `stability_level`; equal → draw |
| E2 | Burst and energy ≤ 0 in the same turn | Burst takes precedence (Section 3 rule 5) |
| E3 | Both energy ≤ 0 in the same turn | Higher `stability_level` wins; equal → draw **[D13]** |
| E4 | Ring-out and spin finish same turn | Ring-out resolved first |
| E5 | DODGE stack ≥ 10 | `dodge_eff` = 0; DODGE no longer lowers collision chance (never negative) |
| E6 | DEFEND stack ≥ 4 | Reduction floors at 5% |
| E7 | SPECIAL committed with meter < 100 | Rejected with an error; server asks again, never substitutes |
| E8 | No collision this turn | Impact, stability, burst, energy-from-impact are all skipped; passive drain and passive pressure still apply |
| E9 | Turn timer expires (online) | **OPEN — O5.** Must not be exploitable for stalling |
| E10 | Termination | Slowest passive drain over all 512 profiles is 0.8216/turn (B01D01T05: Stamina type, Stamina identity, SM 85) on 102 energy, so no match can last past 125 turns. Observed max in 12,250 simulated matches: 56. No timeout path exists |

| E11 | Energy exactly 0 | Counts as ≤ 0 (loss) |
| E12 | Same seed, same actions | Identical result and event list (determinism is a test) |
| E13 | Core differs, parts identical | Identical result (cosmetic invariant is a test) |

## Dependencies

- **Upstream**: Beyblade Construction (component data, derived stats). *That system's doc must mention Combat as a dependent when it is written.*
- **Downstream (depend on this)**: Practice AI, Local Versus, Online PvP/Server, Spectator, Battle UI, 3D presentation, Match history/replay, Balance simulator, Rankings.
- Both directions to be registered in `design/gdd/systems-index.md` by `/map-systems`.

## Tuning Knobs

All live in an external data file (no hardcoded gameplay values). Ranges below are what the reference model explored — **evidence-informed starting ranges, not approved values**.

| Knob | Spec / default | Explored range | Affects |
|------|---------------|----------------|---------|
| `burst_ref_p` | (none in spec) 0.05 | 0.002–0.05 | Burst frequency (4% of matches at 0.002, 56% at 0.05; energy_div 20) |
| `burst_cap` | 0.75 | — | Max single-hit burst chance |
| `energy_div` | 20 | 20–320 | Match length, Spin Finish frequency |
| `pressure_scale` | 1.0 | 1–6 | Ring-out frequency (0% → 18–25%), Defense viability |
| `stab_max` | 100 | — | How much stability matters to burst |
| `ringout_threshold` / `base` / `cap` | 120 / 0.25 / 0.90 | — | Ring-out odds |
| `collision` base and modifiers | 0.4, +0.15, −0.25 | — | Dodge/Attack value |
| `special_cost` / `charge_gain` | 100 / 15 | — | Special viability |
| `dodge_decay`, `defend_fresh`, `defend_step`, `defend_floor` | 0.10, 0.40, 0.10, 0.05 | — | Dodge/Defend value |
| `identity_bonus`, `type synergy %`, `spec rates` | spec values | — | Build identity strength |
| `type_margin` | 0.15 | 0.10–0.25 | Type distribution |

## Acceptance Criteria

Logic tests (gdUnit4, `tests/unit/combat/`), all BLOCKING:

1. For every legal state and action pair sampled by property tests: `0.2 ≤ P_collision ≤ 0.9`, `0 ≤ P_burst ≤ burst_cap`, `0 ≤ P_ringout ≤ 0.9`, no NaN or infinity anywhere.
2. `ST+MS` and component sums equal their constants for all 24 parts; every build's stat total is 280.
3. Changing only the Core never changes any engine output.
4. Same `(state, actions, seed)` → identical new state and events (run 1,000 random cases).
5. Swapping seats of identical builds with mirrored RNG streams yields identical outcomes (no seat bias).
6. F0 classifies the four spec examples as Attack, Defense, Stamina, Balance and yields the 169/167/128/48 distribution (or the approved replacement).
7. Illegal SPECIAL is rejected; a hidden action is never present in any broadcast before resolution (integration test).
8. Every simulated match terminates within the proven bound (≤ 125 turns).
9. Every worked example in Section 4 reproduces to ±0.01.

Balance gate (Phase 6; **no "balanced" claim before it passes**), thresholds to be set by the owner (O4): per-profile win rate band, no strictly dominant action, finish-mix and match-length bands, stalling metric below threshold, no dominant component.

## 10. Spec Audit Log — gap-fills used by this draft

The original spec did not define these. Each is a choice, not a fact; the reference model's results depend on all of them.

| ID | Gap | Choice in this draft |
|----|-----|----------------------|
| D1 | `stability_level` had no scale or effect | Starts 100; reduced by F4; floors 0; amplifies burst (F5). No standalone finish |
| D2 | Burst chance not a probability; whose MS/LI | Hitter's MS over target's LI; exponential normalization with a calibration point |
| D3 | Whose impact drives recoil | The hitter's own outgoing impact over own ST |
| D4 | Who loses energy to impacts | The target |
| D5 | Who receives passive pressure | Each non-attacking player, onto their own pressure |
| D6 | Ring-out "probability roll" undefined | F7 |
| D7 | DEFEND ×0.6 vs "20% − 5%×stack" | 40% fresh reduction (= ×0.6), −10 pts per consecutive DEFEND, floor 5% |
| D8 | Dodge decay can go negative | Floor 0; first DODGE in a row is full strength |
| D9 | "combo_count ≥ 2" stacks | Stacks = min(3, combo−1); +5% impact each (max 15%) |
| D10 | "Break repetition" | After ≥ 2 repeats, the first different action gets +5% impact |
| D11 | "Dominant stat ≥ 1.25× others" across different scales | Compared on normalized F0 scores |
| D12 | Classification unusable (ST+MS constant) | F0 |
| D13 | Simultaneous finishes | Burst > Ring-out > Spin; ties by stability |
| D14 | Do modifiers apply per player; does SPECIAL count as ATTACK | Per player; yes |
| D15 | Spec thresholds read as percentage-points per stat point over threshold | As written in F1–F7 |
| D16 | Timeout behaviour | OPEN (O5) |
| D17 | Turn cap | None; termination bounded by drain (E10) |

### Findings from the reference model (reproduce: `prototypes/combat-reference-model/results.txt`)

- **F-1** Probabilities are bounded and all 12,250 matches terminated (max 56 turns) — *once the burst formula is normalized*.
- **F-2** 64.1% of build pairings start at the 0.9 collision cap, so ATTACK's +0.15 is inert there; collision is nearly guaranteed unless someone dodges.
- **F-3** Matches are too short: median 6–9 turns (target 20–30); best of 17 calibrations: 14.
- **F-4** Ring-out essentially never occurs at pressure_scale 1.0 (position pressure peaks at ≈119 in the main run vs threshold 120). At scale 6 it reaches 18–25% of matches but Defense-type builds collapse (win rate 0.04–0.15).
- **F-5** Attack-spam is the highest-scoring fixed policy in all 17 calibrations (mean win rate 0.62–0.67). The heuristic ADP, which attacks whenever it is ahead on energy, is close behind (0.58–0.64); the non-attacking policies DEFEND, DODGE and CHARGE score 0.32–0.54. Aggression is rewarded everywhere; this is structural, not a calibration artefact.
- **F-6** Charge→Special loses (0.32–0.41); Dodge is weak (0.33–0.38).
- **F-7** Stamina type wins most (0.66–0.84) when matches run long; T03 (SM 15) builds win 25% under random play.

## 11. Open Decisions for the Owner

| ID | Question | Why it matters | Candidate levers (each must be simulated before adoption) |
|----|----------|----------------|-----------------------------------------------------------|
| O1 | Attack-spam dominates (F-5). How should Attack be countered? | Violates "meaningful decisions / no dominant strategy" | Defend returns a share of damage; Attack costs energy; Dodge → counter window; Initiative also rewards Defend |
| O2 | Special loses to plain Attack (F-6) | Special is a trap, so the 5th action is pointless | Charge builds meter on hit taken; Special ignores Defend; lower cost; guaranteed burst-check bonus |
| O3 | Dodge is weak (F-6, F-2) | One of five actions barely matters | Dodge reduces incoming (not only collision odds); smaller decay |
| O4 | Target numbers: median turns, finish mix, win-rate band | Needed to call anything balanced | Propose: median 22–26 turns; Burst 25–35%, Ring-out 15–25%, Spin 40–55%; profile win rate 40–60% |
| O5 | Turn timer and timeout default action | Stalling and fairness online | e.g. 30 s; timeout = DEFEND with fatigue already applied |
| O6 | Passive pressure recipient (D5) | Anti-stall strength | Both players; only the staller (draft) |
| O7 | Defense type is rare (48/512) and ring-out-prone | "Supports all playstyles" | Re-weight F0; give ST a ring-out role; adjust MS/pressure |
