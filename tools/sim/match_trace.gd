class_name MatchTrace
extends RefCounted
## Plays one seeded match with a deterministic action stream and returns a per-turn trace.
##
## Used by tools/sim/dump_match.gd (differential check against the Python oracle) and
## by tests/integration/combat/oracle_agreement_test.gd (frozen-trace regression in CI).
## The action stream is Prng.for_stream(seed, ACTION_STREAM): each turn, player 0 then
## player 1 pick uniformly from CombatEngine.legal_actions via next_index. The oracle
## uses the identical rule (prototypes/combat-reference-model/oracle_v1.py).

const ACTION_STREAM := 99
const MAX_TURNS := 400


## `blade_disc_tip` ids are concatenated, e.g. "B05D07T08".
static func run_case(params: CombatParams, cat: PartsCatalogue, seed: int, build_a: String, build_b: String) -> Array[Dictionary]:
	var a := _build(cat, params, build_a)
	var b := _build(cat, params, build_b)
	var state := CombatEngine.new_match(params, a, b, seed)
	var chooser := Prng.for_stream(seed, ACTION_STREAM)
	var trace: Array[Dictionary] = []
	while not state.finished and state.turn < MAX_TURNS:
		var acts: Array[int] = []
		for i in range(2):
			var legal := CombatEngine.legal_actions(state, i)
			acts.append(legal[chooser.next_index(legal.size())])
		var r := CombatEngine.resolve_turn(state, acts[0], acts[1])
		trace.append(_turn_record(state, r, acts))
	return trace


static func _build(cat: PartsCatalogue, params: CombatParams, ids: String) -> BuildStats:
	return BuildStats.from_catalogue(cat, ids.substr(0, 3), ids.substr(3, 3), ids.substr(6, 3), params.type_margin, params.identity_ratio)


static func _snapshot(p: PlayerState) -> Array:
	return [p.energy, p.stability, p.position_pressure, p.passive_pressure, p.special_meter,
			p.guard_stack, p.dodge_stack, p.combo_count, p.repeat_count, p.last_action]


static func _turn_record(state: MatchState, r: TurnResult, acts: Array[int]) -> Dictionary:
	var pc := 0.0
	var collided := false
	var pb: Array = [-1.0, -1.0]
	var pr: Array = [-1.0, -1.0]
	for e: Dictionary in r.events:
		match e["type"]:
			"collision_roll":
				pc = e["probability"]
				collided = e["collided"]
			"burst_check":
				pb[e["target"]] = e["probability"]
			"ringout_check":
				pr[e["player"]] = e["probability"]
	return {
		"t": state.turn, "acts": [acts[0], acts[1]], "pc": pc, "col": collided, "pb": pb, "pr": pr,
		"p": [_snapshot(state.players[0]), _snapshot(state.players[1])],
		"fin": [state.finished, state.winner, MatchState.FINISH_NAMES[state.finish], state.finish_detail],
	}
