# Combat System

> **Status**: In Design — DRAFT v0.2 (audited spec + proposed rule changes R1–R7, Section 12). **Not approved.** No combat code may be written from this until the owner signs off on Sections 11 and 12. **Action-level balance is close to the proposed targets in simulation; build/component-level balance is NOT achieved (Section 12.3).**
> **Author**: owner (original spec) + Claude (audit, gap-filling, reference model, lever search)
> **Last Updated**: 2026-11-09
> **Last Verified**: 2026-11-09 (numbers reproduced by `prototypes/combat-reference-model/` — `results.txt` for v0.1, `results_v02.txt` and `results_v02_final.txt` for v0.2)
> **Implements Pillar**: Skill over randomness; stat conservation + nonlinear interaction = balance (pillars doc not yet written)

## Summary

Turn-based, simultaneous-commit duel between two tops built from CORE + BLADE + DISC + TIP. Each turn both players secretly choose one of five actions; the engine resolves engagement, collision, and system effects, then checks three finishes: Burst, Ring-Out, Spin Finish.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Top Construction (components, derived stats, type)`

## Overview

Two players each hold a top whose six stats (AP, LI, MS, ST, MB, SM) are fixed by its parts and sum to 280 for every build (Blade 80 + Disc 100 + Tip 100). There is no progression and no hard cap; extremes carry built-in penalties. Each turn both players commit one action (ATTACK, DEFEND, DODGE, CHARGE, SPECIAL). The engine rolls whether the two tops collide, computes impact both ways, applies stability damage, recoil, position pressure, burst checks and energy loss, then applies passive drains. The first player to burst, be rung out, or run out of energy loses.

The engine is a pure, deterministic, seeded GDScript library with no scene dependencies (`src/core/combat/`), shared by Practice, Local Versus, and the authoritative server. This document is its single source of truth.

## Player Fantasy

You read your opponent's build and habits, then out-think them: commit to a hit, bait a dodge, wear down a guard, or gamble a charged Special. Wins feel earned from reading and timing, not from stats or luck. Every build has a plan and a weakness; a skilled player with a "bad" build still has a path.

## Detailed Design

### Core Rules

Notation: stats `AP, LI, MS, ST, MB, SM` of the *acting* top are written bare; the opponent's carry an `opp_` prefix. Rules marked **[D#]** are gap-fills of the original spec; see Section 10.

1. **Match**: players choose builds, then loop turns until a finish. Turn number `t` starts at 1. Passive drain guarantees termination (Section 5, E10).
2. **Turn order**: (1) both commit an action; (2) roll collision; (3) if collided, resolve impact, stability, recoil, pressure, energy, burst; if not, apply passive pressure; (4) system effects (drain, charge, stacks); (5) check finishes; (6) update state.
3. **Actions**: ATTACK, DEFEND, DODGE, CHARGE are always legal. SPECIAL is legal only when `special_meter ≥ 100`. An illegal action is rejected, never substituted silently.
4. **Hidden commit**: neither player (nor any spectator) sees the opponent's action before both have committed and the turn has resolved.
5. **Finishes** (checked in this order each turn **[D13]**): Burst → Ring-Out → Spin Finish. A player who is hit by a burst loses immediately.

### States and Transitions

Static per top: `AP, LI, MS, ST, MB, SM`, `type ∈ {Attack, Defense, Stamina, Balance}`, `domain` (identity bonus, nullable).

Dynamic per player: `energy` (start `1.2 × SM`), `stability_level` (start 100) **[D1]**, `position_pressure` (start 0), `passive_pressure` (0), `special_meter` (0–100), `guard_stack`, `dodge_stack`, `combo_count`, `last_action`, `repeat_count`.

Match states: `COMMITTING` → `RESOLVING` → (`COMMITTING` | `FINISHED`). `RESOLVING` is atomic.

### Interactions with Other Systems

- **Top Construction**: supplies derived stats, type, domain (Section 4, F0).
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
initiative = 1.0 in v0.2 (R4: the spec's 1.08 impact bonus vs DODGE/CHARGE is removed; the +5% burst chance in F5 stays)
adaptation = 1.05 if repeat_count ≥ 2 and action ≠ last_action  [D10]
```
Base AP×(1+MB/120): 22.5..102.5. Example: B01D01T01 ATTACK: 40 × (1 + 50/120) = 56.67; × 1.5 = 85.0; × 1.05 (Balance) = 89.25.

**F3 — Incoming impact (target j)**
```
Impact_in = Impact_out(opp) × defend_mult × charge_mult × type_mult × spec_ST
defend_mult (action DEFEND) = 1 − max(0.05, 0.40 − 0.10 × guard_stack)   [D7]
        × 0.80 if Defense type, × 0.92 if domain == Defense
dodge_mult (action DODGE, collision still happened) = 0.65          (R3; spec has no DODGE mitigation)
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
position_pressure += Impact_in / (MS + pressure_st_share × ST) × pressure_scale + passive_pressure; passive_pressure = 0   [D5]
energy −= Impact_in / energy_div                       (target)  [D4]
```
Spec values: `pressure_st_share` 0 (divisor MS), `pressure_scale` 1, `energy_div` 20. **v0.2 proposes 1.0 / 3 / 120 (R6, R7). With share 1.0 the divisor is MS + ST = 100 for every disc, i.e. the disc no longer affects how easily a top is pushed. This replaces the spec's `Impact / MS` and is decision O9.**
Example (spec values): 84.8 / ST_eff 50 → stability −1.70; pressure +84.8/50 = 1.70; energy −84.8/20 = 4.24.

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
energy_start = energy_base + 1.2 × SM                       (spec: energy_base 0; v0.2: 20, R7)
drain/turn = (1 + MB/80) × (stamina_drain Stamina | 0.95 Balance) × (0.92 if domain==Stamina) × (1 − 0.004 × max(0, SM − 70)) × drain_scale
                                                             (spec: stamina_drain 0.80, drain_scale 1; v0.2: 0.90, 0.80, R7)
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

**F11 — DEFEND counter (R1)**: when the target's action is DEFEND and a collision occurred, `prevented = Impact_before_defend − Impact_in` (the DEFEND, Defense-type and Defense-identity multipliers only), `returned = defend_counter × prevented`; the hitter takes `returned / ST_eff_hitter` stability loss and `returned / (MS_hitter + pressure_st_share × ST_hitter) × pressure_scale` position pressure. `defend_counter` = 4. Worked example: 100 impact, fresh guard (40% reduction) → prevented 40 → returned 160 → hitter stability −3.2 (ST_eff 50) and pressure +4.8.

**F12 — Whiff cost (R2)**: a player whose action is ATTACK or SPECIAL and no collision occurred loses `whiff_cost` = 3 energy.

**F13 — Special economy (R5)**: SPECIAL is legal at `special_meter ≥ special_cost` = 50 (spec: 100). Each time a player is hit (collision, Impact_in > 0) their meter gains `hit_meter_gain` = 10 (cap 100). CHARGE gain is unchanged (15, ×1.25 Stamina).

**F14 — Dodge (R3)**: unchanged collision effect (−0.25 × dodge_eff, decay 0.10); added `dodge_mult` 0.65 in F3.

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
| E10 | Termination | v0.1 (spec values): slowest passive drain 0.8216/turn (B01D01T05) on 102 energy → no match past 125 turns; observed max 56 in 12,250 matches. **v0.2 values: 0.7394/turn on 122 energy → bound 165 turns** (computed over all 512 profiles); observed max 76 in 20,000 matches. No timeout path exists |

| E11 | Energy exactly 0 | Counts as ≤ 0 (loss) |
| E12 | Same seed, same actions | Identical result and event list (determinism is a test) |
| E13 | Core differs, parts identical | Identical result (cosmetic invariant is a test) |

## Dependencies

- **Upstream**: Top Construction (component data, derived stats). *That system's doc must mention Combat as a dependent when it is written.*
- **Downstream (depend on this)**: Practice AI, Local Versus, Online PvP/Server, Spectator, Battle UI, 3D presentation, Match history/replay, Balance simulator, Rankings.
- Both directions to be registered in `design/gdd/systems-index.md` by `/map-systems`.

## Tuning Knobs

All live in an external data file (no hardcoded gameplay values). Ranges below are what the reference model explored — **evidence-informed starting ranges, not approved values**.

| Knob | Spec value | v0.2 proposed | Tested range | Affects |
|------|-----------|---------------|--------------|---------|
| `burst_ref_p` | none (formula invalid) | 0.003 | 0.001–0.05 | Burst share of finishes (≈4% at 0.002, 56% at 0.05 with spec energy scale) |
| `burst_cap` | none | 0.75 | never reached (max observed 0.21) | Safety ceiling |
| `energy_div` | 20 | 120 | 20–480 | Match length; at 20 Spin is ~90% of finishes and ring-out vanishes |
| `energy_base` | 0 | 20 | 0–60 | Floor on lifetime of low-SM builds (T03) |
| `drain_scale` | 1.0 | 0.8 | 0.6–1.0 | Match length |
| `stamina_drain` | 0.8 | 0.9 | 0.8–0.9 | Stamina-type advantage |
| `pressure_scale` | 1 | 3 | 1–8 | Ring-out frequency (0% → 14–15% at 3; 18–25% at 6+ with disc-weighted divisor) |
| `pressure_st_share` | 0 | 1.0 | 0–1 | 1.0 makes pressure intake disc-neutral (Defense viability); see O9 |
| `defend_counter` | none | 4 | 0–4 (**top of tested range**) | DEFEND counterplay, Attack-spam |
| `whiff_cost` | none | 3 | 0–4 | Cost of attacking into a miss |
| `hit_meter_gain` | none | 10 | 0–15 | Special availability / comeback |
| `special_cost` | 100 | 50 | 50–100 | Special viability |
| `dodge_incoming` | none | 0.65 | 0.5–1.0 | Dodge viability |
| `dodge_collision`, `dodge_decay` | 0.25, 0.10 | unchanged | 0.25–0.55, 0–0.10 | Dodge collision effect |
| `init_mult` | 1.08 | 1.0 | 1.0–1.08 | Attack vs Dodge/Charge |
| `stab_max`, `ringout_*`, spec thresholds and rates | spec | unchanged | — | — |
| `type_margin` | 0.15 | 0.15 | 0.10–0.25 (not swept) | Type distribution |

## Acceptance Criteria

Logic tests (gdUnit4, `tests/unit/combat/`), all BLOCKING:

1. For every legal state and action pair sampled by property tests: `0.2 ≤ P_collision ≤ 0.9`, `0 ≤ P_burst ≤ burst_cap`, `0 ≤ P_ringout ≤ 0.9`, no NaN or infinity anywhere.
2. `ST+MS` and component sums equal their constants for all 24 parts; every build's stat total is 280.
3. Changing only the Core never changes any engine output.
4. Same `(state, actions, seed)` → identical new state and events (run 1,000 random cases).
5. Swapping seats of identical builds with mirrored RNG streams yields identical outcomes (no seat bias).
6. F0 classifies the four spec examples as Attack, Defense, Stamina, Balance and yields the 169/167/128/48 distribution (or the approved replacement).
7. Illegal SPECIAL is rejected; a hidden action is never present in any broadcast before resolution (integration test).
8. Every simulated match terminates within the proven bound (≤ 125 turns at spec values; ≤ 165 turns at the v0.2 values — the test reads the bound from the same data file as the engine).
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

**Status after the v0.2 search:** O1–O4 have a *proposed* answer in Section 12 (needs your approval); O5–O7 remain open; O8–O10 are new.

| ID | Question | Why it matters | Candidate levers (each must be simulated before adoption) |
|----|----------|----------------|-----------------------------------------------------------|
| O1 | Attack-spam dominates (F-5). How should Attack be countered? | Violates "meaningful decisions / no dominant strategy" | Defend returns a share of damage; Attack costs energy; Dodge → counter window; Initiative also rewards Defend |
| O2 | Special loses to plain Attack (F-6) | Special is a trap, so the 5th action is pointless | Charge builds meter on hit taken; Special ignores Defend; lower cost; guaranteed burst-check bonus |
| O3 | Dodge is weak (F-6, F-2) | One of five actions barely matters | Dodge reduces incoming (not only collision odds); smaller decay |
| O4 | Target numbers: median turns, finish mix, win-rate band | Needed to call anything balanced | Propose: median 22–26 turns; Burst 25–35%, Ring-out 15–25%, Spin 40–55%; profile win rate 40–60% |
| O5 | Turn timer and timeout default action | Stalling and fairness online | e.g. 30 s; timeout = DEFEND with fatigue already applied |
| O6 | Passive pressure recipient (D5) | Anti-stall strength | Both players; only the staller (draft) |
| O7 | Defense type is rare (48/512) and ring-out-prone | "Supports all playstyles" | Re-weight F0; give ST a ring-out role; adjust MS/pressure |
| O8 | Component-level imbalance (Section 12.3): B05/B04 weak, B03/B06 strong, T03 a trap tip | Violates "no dominant meta / no superior parts" in practice even though stat totals are equal | Give LI a second role every match (e.g. stability retention or recoil), reduce AP's linear impact, or add an energy/stability cost scaling with AP; must be simulated against all 512 profiles |
| O9 | v0.2 replaces `position_pressure += Impact/MS` with a constant divisor (MS+ST=100) | Changes a spec formula; MS loses its push-resistance role | Keep the spec formula and accept that Defense-type builds are ring-out victims, or give ST/LI a ring-out role instead |
| O10 | v0.2 changes spec energy numbers: `/20`→`/120`, reserve 0→20, drain ×0.8, Stamina 0.8→0.9 | These are the spec's own numbers; at the spec's energy scale the median match is 6–11 turns, and with burst tuned down Spin Finish is ~90% of finishes with no ring-outs | Accept, or redesign the energy model (e.g. fixed match-length clock) |

## 12. Proposed v0.2 Rule Changes and Evidence

Source: `prototypes/combat-reference-model/` (`lever_search*.py`, `validate_*.py`; outputs in `results_v02.txt`, `results_v02_final.txt`). Python reference model, fixed seeds, 7 policies (4 pure, ROT, ADP, RND) round-robin on random build pairs. **Policies are not optimal play, and the build pairs are samples, not all 131,328.** Nothing here claims the game is balanced.

### 12.1 What changes from the spec

| ID | Rule | Spec | v0.2 | Why |
|----|------|------|------|-----|
| R1 | DEFEND counter (F11) | none | hitter takes 4× the prevented damage as stability loss + pressure | The lever that moved the dominant policy most: at its maximum in every top-5 configuration of round 1, and 3–4 in all later rounds; **4 is the top of the tested range** |
| R2 | Whiff cost (F12) | none | −3 energy for ATTACK/SPECIAL with no collision | Makes missing costly; present (2–3) in most top sets, not all |
| R3 | Dodge mitigation (F3) | none | ×0.65 incoming when a collision still happens | Keeps your Dodge numbers (0.25 / 0.10) and gives Dodge a second effect |
| R4 | Initiative impact bonus | ×1.08 vs Dodge/Charge | ×1.0 (burst +5% kept) | The bonus punished the two actions that most needed help |
| R5 | Special economy (F13) | cost 100, charge only | cost 50, +10 meter per hit taken | Special was a seven-turn trap |
| R6 | Pressure divisor | `Impact / MS` | `Impact / (MS+ST)` = `/100`, scale 3 | Without it Defense-type builds are ring-out victims (win rate 0.00–0.15) |
| R7 | Energy scale | `/20`, reserve 0, drain ×1, Stamina ×0.8 | `/120`, reserve 20, drain ×0.8, Stamina ×0.9 | At spec values matches last 6–11 turns |

Plus the audit fixes already in v0.1: burst normalization (D2), type classification (D12), Dodge floor (D8).

### 12.2 Results (v0.2 final vs the same calibration without R1–R5)

| Measure | Target (O4 proposal) | No levers, calibrated | v0.2 final (4 fresh seeds × 300 pairs) |
|---|---|---|---|
| Median match length | 20–28 turns | 23 | 21–22 |
| Burst / Ring-out / Spin | 22–38% / 10–30% / 35–60% | 16% / 8% / 76% | 21–22% / 14–15% / 62–65% |
| Pure ATK policy mean win rate | ≤ 0.58 | 0.62–0.64 | 0.52–0.54 |
| Best counter to pure ATK | ≥ 0.56 | 0.43–0.47 | 0.64–0.65 |
| Pure DEF / DOD / CHG | each ≥ 0.36 | 0.50 / 0.38 / 0.43 | 0.41–0.44 / 0.37–0.39 / 0.44–0.46 |
| Type win-rate range (A, B, D, S) | spread ≤ 0.20 | 0.31–0.82 | 0.37–0.60 (spread 0.13–0.22) |
| Probabilities in range, no NaN, all terminate | yes | yes | yes — 20,000 matches, max 76 turns, burst P ≤ 0.21, 0 timeouts |

Honest reading: the dominant-policy problem is fixed in this model (Attack no longer wins everything and every pure policy now has a counter ≥ 0.64). **Dodge and Charge→Special are viable (≥ 0.36) but still below average (0.37–0.46); the levers did not make them good**, they stopped them being traps. The scoring penalties on the final seeds (0.27–0.72) come from burst share sitting just under the band (0.21 vs 0.22) and the type spread (up to 0.22 vs 0.20) just over its limit — close, not exact.

### 12.3 What is still wrong (not fixed by any rule set tried)

512 profiles × 60 opponents (skill-mixed policies, noise ≈ ±0.065):
- Profile win rate: min 0.02, p05 0.14, median 0.55, p95 0.73, max 0.86. **61 of 512 profiles win under 25%; 38 win over 70%.**
- Blades: B03 0.62, B06 0.60, B02 0.55 … B04 0.41, B05 0.34. Tips: T07 0.62, T01 0.61, T04 0.61 … T08 0.39, **T03 0.20**. Discs are flat (0.48–0.53).
- Raising burst frequency narrows the blade gap only at burst shares (≈59%) far outside the target band; a larger energy reserve moves the weakest tip from T03 to T05 and pushes ring-out out of band.
- Cause: AP multiplies every impact, while LI only matters when a burst is possible; T03's speed cannot compensate for SM 15.

This needs a rule (O8), not a number.

### 12.4 Limits of this evidence
- Fixed/heuristic policies, not optimal play (matrix-game analysis is Phase 6).
- Sampled build pairs; 40–300 pairs per measurement.
- Results depend on gap-fills D1–D17 and on R1–R7; all are in this document.
- `defend_counter` is at the edge of its tested range; the optimum may be higher.
- One reference model (mine). The GDScript engine must be validated against it and then against the simulator.
