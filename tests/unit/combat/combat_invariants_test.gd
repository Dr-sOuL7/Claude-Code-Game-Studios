# gdUnit4 test suite — TR-combat-001, 003, 004, 006, 007 (GDD acceptance criteria 1, 4, 5, 7, 8)
class_name CombatInvariantsTest
extends GdUnitTestSuite

const RANDOM_MATCHES := 300
const SYMMETRY_CASES := 150
const DETERMINISM_CASES := 100

var _p: CombatParams
var _cat: PartsCatalogue
var _builds: Array[BuildStats]


func before() -> void:
	_p = CombatFixtures.params()
	_cat = CombatFixtures.catalogue()
	_builds = CombatFixtures.all_builds(_cat, _p)
	assert_object(_p).is_not_null()
	assert_int(_builds.size()).is_equal(512)


func _pick(rng: Prng) -> BuildStats:
	return _builds[rng.next_index(_builds.size())]


func test_probabilities_bounded_and_state_finite_over_random_matches() -> void:
	var rng := Prng.new(20261114)
	var bad: Array[String] = []
	var turns_checked := 0
	for m in range(RANDOM_MATCHES):
		var state := CombatEngine.new_match(_p, _pick(rng), _pick(rng), rng.next_int())
		while not state.finished:
			var r := CombatEngine.resolve_turn(state, CombatFixtures.random_action(state, 0, rng), CombatFixtures.random_action(state, 1, rng))
			turns_checked += 1
			for e: Dictionary in r.events:
				if e.has("probability"):
					var pr: float = e["probability"]
					var hi := _p.col_max if e["type"] == "collision_roll" else (_p.burst_cap if e["type"] == "burst_check" else _p.ringout_cap)
					var lo := _p.col_min if e["type"] == "collision_roll" else 0.0
					if is_nan(pr) or pr < lo or pr > hi:
						bad.append("%s p=%s turn %d" % [e["type"], pr, state.turn])
			for pl in state.players:
				for v: float in [pl.energy, pl.stability, pl.position_pressure, pl.passive_pressure, pl.special_meter]:
					if is_nan(v) or is_inf(v):
						bad.append("non-finite state at turn %d" % state.turn)
				if pl.stability < 0.0 or pl.special_meter < 0.0 or pl.special_meter > _p.meter_max or pl.position_pressure < 0.0:
					bad.append("out-of-range state at turn %d" % state.turn)
	assert_int(turns_checked).is_greater(RANDOM_MATCHES)
	assert_array(bad).override_failure_message("violations: %s" % ", ".join(bad.slice(0, 5))).is_empty()


func test_same_seed_and_actions_give_identical_states_and_events() -> void:
	var rng := Prng.new(4242)
	for c in range(DETERMINISM_CASES):
		var a := _pick(rng)
		var b := _pick(rng)
		var seed := rng.next_int()
		var s1 := CombatEngine.new_match(_p, a, b, seed)
		var s2 := CombatEngine.new_match(_p, a, b, seed)
		while not s1.finished:
			var x := CombatFixtures.random_action(s1, 0, rng)
			var y := CombatFixtures.random_action(s1, 1, rng)
			var r1 := CombatEngine.resolve_turn(s1, x, y)
			var r2 := CombatEngine.resolve_turn(s2, x, y)
			if r1.events != r2.events or s1.to_dict() != s2.to_dict():
				fail("case %d diverged at turn %d" % [c, s1.turn])
				return
		assert_bool(s2.finished).is_true()


func test_serialised_state_resumes_identically() -> void:
	var rng := Prng.new(99)
	var s1 := CombatEngine.new_match(_p, _pick(rng), _pick(rng), 777)
	for i in range(3):
		if s1.finished:
			break
		CombatEngine.resolve_turn(s1, CombatFixtures.random_action(s1, 0, rng), CombatFixtures.random_action(s1, 1, rng))
	var s2 := MatchState.from_dict(s1.to_dict(), _p)
	assert_dict(s2.to_dict()).is_equal(s1.to_dict())
	while not s1.finished:
		var x := CombatFixtures.random_action(s1, 0, rng)
		var y := CombatFixtures.random_action(s1, 1, rng)
		var r1 := CombatEngine.resolve_turn(s1, x, y)
		var r2 := CombatEngine.resolve_turn(s2, x, y)
		assert_array(r2.events).is_equal(r1.events)
	assert_dict(s2.to_dict()).is_equal(s1.to_dict())


func test_swapping_seats_mirrors_the_outcome_exactly() -> void:
	var rng := Prng.new(31337)
	for c in range(SYMMETRY_CASES):
		var a := _pick(rng)
		var b := _pick(rng)
		var seed := rng.next_int()
		var s1 := CombatEngine.new_match(_p, a, b, seed)
		var s2 := CombatEngine.new_match(_p, b, a, seed)
		# Mirror the per-player streams so each build keeps its own randomness.
		s2.player_prng = [s2.player_prng[1], s2.player_prng[0]]
		while not s1.finished:
			var x := CombatFixtures.random_action(s1, 0, rng)
			var y := CombatFixtures.random_action(s1, 1, rng)
			CombatEngine.resolve_turn(s1, x, y)
			CombatEngine.resolve_turn(s2, y, x)
			if s1.players[0].to_dict() != s2.players[1].to_dict() or s1.players[1].to_dict() != s2.players[0].to_dict():
				fail("case %d: mirrored states differ at turn %d" % [c, s1.turn])
				return
		assert_bool(s2.finished).is_true()
		assert_int(s2.finish).is_equal(s1.finish)
		var mirrored_winner := -1 if s1.winner == -1 else 1 - s1.winner
		assert_int(s2.winner).is_equal(mirrored_winner)


func test_every_random_match_terminates_within_the_derived_bound() -> void:
	var bound := CombatEngine.termination_bound(_p, _builds)
	assert_int(bound).is_equal(194)   # GDD E10 at ruleset v1
	var rng := Prng.new(555)
	var longest := 0
	for m in range(RANDOM_MATCHES):
		var state := CombatEngine.new_match(_p, _pick(rng), _pick(rng), rng.next_int())
		while not state.finished and state.turn <= bound:
			CombatEngine.resolve_turn(state, CombatFixtures.random_action(state, 0, rng), CombatFixtures.random_action(state, 1, rng))
		assert_bool(state.finished).is_true()
		longest = maxi(longest, state.turn)
	assert_int(longest).is_less_equal(bound)


func test_most_passive_play_with_the_slowest_build_still_terminates() -> void:
	var slow := CombatFixtures.build(_cat, _p, "B01", "D01", "T05")
	var bound := CombatEngine.termination_bound(_p, _builds)
	for action in [MatchState.Action.DEFEND, MatchState.Action.DODGE]:
		var state := CombatEngine.new_match(_p, slow, slow, 1)
		while not state.finished and state.turn <= bound:
			CombatEngine.resolve_turn(state, action, action)
		assert_bool(state.finished).is_true()
		assert_int(state.turn).is_less_equal(bound)


func test_illegal_special_is_rejected_without_mutating_state() -> void:
	var state := CombatEngine.new_match(_p, _builds[0], _builds[1], 5)
	var before := state.to_dict()
	var r := CombatEngine.resolve_turn(state, MatchState.Action.SPECIAL, MatchState.Action.ATTACK)
	assert_bool(r.ok).is_false()
	assert_str(r.error).is_equal("illegal_action_player_0")
	assert_array(r.events).is_empty()
	assert_dict(state.to_dict()).is_equal(before)


func test_unknown_action_value_is_rejected() -> void:
	var state := CombatEngine.new_match(_p, _builds[0], _builds[1], 5)
	var before := state.to_dict()
	assert_bool(CombatEngine.resolve_turn(state, 0, 9).ok).is_false()
	assert_bool(CombatEngine.resolve_turn(state, -1, 0).ok).is_false()
	assert_dict(state.to_dict()).is_equal(before)


func test_special_becomes_legal_at_cost_and_resets_the_meter() -> void:
	var state := CombatEngine.new_match(_p, _builds[0], _builds[1], 5)
	assert_bool(MatchState.Action.SPECIAL in CombatEngine.legal_actions(state, 0)).is_false()
	state.players[0].special_meter = _p.special_cost
	assert_bool(MatchState.Action.SPECIAL in CombatEngine.legal_actions(state, 0)).is_true()
	var r := CombatEngine.resolve_turn(state, MatchState.Action.SPECIAL, MatchState.Action.DEFEND)
	assert_bool(r.ok).is_true()
	assert_float(state.players[0].special_meter).is_equal(0.0)


func test_finished_match_rejects_further_turns() -> void:
	var state := CombatEngine.new_match(_p, _builds[0], _builds[1], 5)
	state.players[0].energy = 0.0
	state.players[1].energy = 0.0
	CombatEngine.resolve_turn(state, MatchState.Action.DEFEND, MatchState.Action.DEFEND)
	assert_bool(state.finished).is_true()
	var r := CombatEngine.resolve_turn(state, MatchState.Action.ATTACK, MatchState.Action.ATTACK)
	assert_bool(r.ok).is_false()
	assert_array(CombatEngine.legal_actions(state, 0)).is_empty()


func test_public_view_exposes_no_seed_or_generator_state() -> void:
	var state := CombatEngine.new_match(_p, _builds[0], _builds[1], 5)
	var view := state.public_view()
	for key in ["seed", "shared_prng", "player_prng", "pending"]:
		assert_bool(view.has(key)).is_false()
