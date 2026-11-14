# Combat engine (`src/core/combat/`)

Pure GDScript implementation of `design/gdd/combat-system.md` (ruleset v1 = GDD v0.3).
Governing ADR: `docs/architecture/adr-0001-combat-engine-architecture.md`.

**Rules for this folder** — nothing here may reference `Node`, `SceneTree`, `Engine`, `OS`,
`Time`, `randf*`/`randi*`, `RandomNumberGenerator`, autoloads or the filesystem. The only data
entering from outside is a `CombatParams` (built from a `Ruleset`), two `BuildStats` and a seed.
(`ruleset.gd` and `parts_catalogue.gd` do read files; they live in `src/core/rules` and
`src/core/parts` on purpose.)

## Use

```gdscript
var params := CombatParams.load_version("v1")
var state := CombatEngine.new_match(params, build_a, build_b, seed)
var legal := CombatEngine.legal_actions(state, 0)      # Array[int] of MatchState.Action
var result := CombatEngine.resolve_turn(state, action_a, action_b)
if not result.ok: ...                                   # nothing was mutated
for e in result.events: ...                             # the only output presentation may use
```

`MatchState.to_dict()` / `from_dict(d, params)` round-trip a match exactly (PRNG streams included).
`public_view()` is the only thing safe to send to opponents and spectators.

## Events (`Dictionary`, every one has `type` and `turn`)

| type | fields |
|---|---|
| `turn_started` | `actions` [int, int] |
| `collision_roll` | `probability`, `collided` |
| `impact` | `hitter`, `target`, `outgoing`, `incoming`, `prevented`, `stability_loss`, `pressure_gain`, `passive_released`, `energy_loss` |
| `defend_counter` | `defender`, `hitter`, `returned`, `stability_loss`, `pressure_gain` |
| `burst_check` | `target`, `probability`, `burst` |
| `recoil` | `player`, `stability_loss` |
| `passive_pressure` | `player`, `gain`, `total` |
| `upkeep` | `player`, `drain`, `attack_cost`, `whiff_cost`, `pressure_drain`, `energy`, `special_meter` |
| `ringout_check` | `player`, `probability`, `ringout` |
| `match_finished` | `winner` (-1 = draw), `finish` (`burst`/`ringout`/`spin`/`draw`), `detail` (`""`, `tiebreak`, `simultaneous`) |

The event numbers account for every change to energy and stability (tested in
`tests/unit/combat/combat_examples_test.gd`), so a replay can animate from events alone.

## Verification

- `tests/unit/combat/` — invariants, worked examples, edge cases (58 tests with the parts and ruleset suites).
- `tests/integration/combat/oracle_agreement_test.gd` — 24 frozen traces from the independent Python oracle.
- `python3 -I tools/sim/compare_traces.py compare 200` — live differential check (needs `godot` on PATH).
