# gdUnit4 test suite — GDD edge cases E1-E8, E11 and rules R1-R5
class_name CombatEdgeCasesTest
extends GdUnitTestSuite

const ATTACK := MatchState.Action.ATTACK
const DEFEND := MatchState.Action.DEFEND
const DODGE := MatchState.Action.DODGE
const CHARGE := MatchState.Action.CHARGE

var _p: CombatParams
var _cat: PartsCatalogue
var _neutral: BuildStats


func before() -> void:
	_p = CombatFixtures.params()
	_cat = CombatFixtures.catalogue()
	_neutral = CombatFixtures.build(_cat, _p, "B01", "D01", "T01")


func _first(events: Array[Dictionary], type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


## Resolves turn 1 on fresh states for seeds 1.. until `wanted_collision` happens.
func _turn_one(params: CombatParams, a: BuildStats, b: BuildStats, act_a: int, act_b: int,
		wanted_collision: bool, setup: Callable = Callable()) -> Array:
	for seed in range(1, 600):
		var s := CombatEngine.new_match(params, a, b, seed)
		if setup.is_valid():
			setup.call(s)
		var r := CombatEngine.resolve_turn(s, act_a, act_b)
		if _first(r.events, "collision_roll")["collided"] == wanted_collision:
			return [s, r]
	return []


func test_e5_dodge_stack_beyond_ten_never_raises_collision_chance() -> void:
	var probs: Array[float] = []
	for stack in [10, 12, 50]:
		var s := CombatEngine.new_match(_p, _neutral, _neutral, 3)
		s.players[0].dodge_stack = stack
		var r := CombatEngine.resolve_turn(s, DODGE, DEFEND)
		probs.append(_first(r.events, "collision_roll")["probability"])
	assert_float(probs[1]).is_equal(probs[0])
	assert_float(probs[2]).is_equal(probs[0])


func test_fresh_dodge_lowers_collision_chance_by_the_spec_amount() -> void:
	var slow := CombatFixtures.build(_cat, _p, "B01", "D01", "T05")   # MB 15: base 0.4 + 30/200 = 0.55
	var s1 := CombatEngine.new_match(_p, slow, slow, 3)
	var none: float = _first(CombatEngine.resolve_turn(s1, DEFEND, DEFEND).events, "collision_roll")["probability"]
	var s2 := CombatEngine.new_match(_p, slow, slow, 3)
	var dodged: float = _first(CombatEngine.resolve_turn(s2, DODGE, DEFEND).events, "collision_roll")["probability"]
	assert_float(none).is_equal_approx(0.55, 1e-9)
	assert_float(none - dodged).is_equal_approx(_p.col_dodge_reduction, 1e-9)


func test_e6_defend_reduction_floors_at_five_percent() -> void:
	var found := _turn_one(_p, _neutral, _neutral, ATTACK, DEFEND, true,
			func(s: MatchState) -> void: s.players[1].guard_stack = 10)
	assert_array(found).is_not_empty()
	var r: TurnResult = found[1]
	for e: Dictionary in r.events:
		if e["type"] == "impact" and e["target"] == 1:
			assert_float(e["prevented"] / e["outgoing"]).is_equal_approx(_p.defend_floor, 1e-9)


func test_fresh_defend_prevents_forty_percent_and_counters_the_hitter() -> void:
	var found := _turn_one(_p, _neutral, _neutral, ATTACK, DEFEND, true)
	assert_array(found).is_not_empty()
	var r: TurnResult = found[1]
	var prevented := 0.0
	for e: Dictionary in r.events:
		if e["type"] == "impact" and e["target"] == 1:
			prevented = e["prevented"]
			assert_float(prevented / e["outgoing"]).is_equal_approx(_p.defend_fresh, 1e-9)
	var counter := _first(r.events, "defend_counter")
	assert_dict(counter).is_not_empty()
	assert_int(counter["hitter"]).is_equal(0)
	assert_float(counter["returned"]).is_equal_approx(_p.defend_counter_ratio * prevented, 1e-9)
	assert_float(counter["stability_loss"]).is_equal_approx(counter["returned"] / 50.0, 1e-9)


func test_e8_no_collision_skips_impacts_and_charges_a_whiff() -> void:
	var found := _turn_one(_p, _neutral, _neutral, ATTACK, DODGE, false)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	var r: TurnResult = found[1]
	for e: Dictionary in r.events:
		assert_bool(e["type"] in ["impact", "burst_check", "recoil", "defend_counter"]).is_false()
	var attacker_upkeep := r.events.filter(func(e: Dictionary) -> bool: return e["type"] == "upkeep" and e["player"] == 0)[0] as Dictionary
	assert_float(attacker_upkeep["whiff_cost"]).is_equal(_p.whiff_cost)
	# only the non-attacking player accumulates passive pressure
	assert_float(s.players[0].passive_pressure).is_equal(0.0)
	assert_float(s.players[1].passive_pressure).is_equal(_p.passive_gain)
	assert_float(s.players[0].stability).is_equal(_p.stab_max)


func test_passive_pressure_is_released_onto_its_owner_at_next_collision() -> void:
	var found := _turn_one(_p, _neutral, _neutral, ATTACK, DEFEND, true,
			func(s: MatchState) -> void: s.players[1].passive_pressure = 9.0)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	var r: TurnResult = found[1]
	for e: Dictionary in r.events:
		if e["type"] == "impact" and e["target"] == 1:
			assert_float(e["passive_released"]).is_equal(9.0)
			assert_float(s.players[1].position_pressure).is_equal_approx(e["pressure_gain"] + 9.0, 1e-9)
	assert_float(s.players[1].passive_pressure).is_equal(0.0)


func test_e3_both_out_of_energy_higher_stability_wins_by_spin() -> void:
	var found := _turn_one(_p, _neutral, _neutral, DEFEND, DEFEND, false, func(s: MatchState) -> void:
		s.players[0].energy = 0.01
		s.players[1].energy = 0.01
		s.players[0].stability = 40.0
		s.players[1].stability = 60.0)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	assert_bool(s.finished).is_true()
	assert_int(s.winner).is_equal(1)
	assert_int(s.finish).is_equal(MatchState.Finish.SPIN)
	assert_str(s.finish_detail).is_equal("tiebreak")


func test_e3_both_out_of_energy_equal_stability_is_a_draw() -> void:
	var found := _turn_one(_p, _neutral, _neutral, DEFEND, DEFEND, false, func(s: MatchState) -> void:
		s.players[0].energy = 0.01
		s.players[1].energy = 0.01)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	assert_int(s.winner).is_equal(-1)
	assert_int(s.finish).is_equal(MatchState.Finish.DRAW)


func test_e11_energy_at_or_below_zero_loses_by_spin_finish() -> void:
	var found := _turn_one(_p, _neutral, _neutral, DEFEND, DEFEND, false,
			func(s: MatchState) -> void: s.players[0].energy = 0.5)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	assert_float(s.players[0].energy).is_less_equal(0.0)
	assert_int(s.winner).is_equal(1)
	assert_int(s.finish).is_equal(MatchState.Finish.SPIN)
	assert_str(s.finish_detail).is_equal("")


func test_e2_burst_takes_precedence_over_spin_finish() -> void:
	var certain := CombatFixtures.params_copy()
	certain.burst_cap = 1.0
	certain.burst_k = 1000.0          # every hit bursts
	var found := _turn_one(certain, _neutral, _neutral, ATTACK, CHARGE, true,
			func(s: MatchState) -> void: s.players[0].energy = 0.01)   # attacker would also spin out
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	# both are hit, both burst: decided by remaining stability, and the finish is BURST not SPIN
	assert_int(s.finish).is_equal(MatchState.Finish.BURST)
	assert_str(s.finish_detail).is_equal("tiebreak")


func test_e4_ring_out_is_resolved_before_spin_finish() -> void:
	var certain := CombatFixtures.params_copy()
	certain.ringout_base = 1.0
	certain.ringout_cap = 1.0
	var found := _turn_one(certain, _neutral, _neutral, DEFEND, DEFEND, false, func(s: MatchState) -> void:
		s.players[0].position_pressure = 500.0
		s.players[1].energy = 0.01)        # opponent would spin out the same turn
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	assert_int(s.finish).is_equal(MatchState.Finish.RINGOUT)
	assert_int(s.winner).is_equal(1)


func test_ring_out_is_not_rolled_at_or_below_the_threshold() -> void:
	var found := _turn_one(_p, _neutral, _neutral, DEFEND, DEFEND, false,
			func(s: MatchState) -> void: s.players[0].position_pressure = _p.ringout_threshold)
	assert_array(found).is_not_empty()
	var r: TurnResult = found[1]
	assert_dict(_first(r.events, "ringout_check")).is_empty()


func test_charge_fills_the_meter_and_being_hit_adds_to_it() -> void:
	var found := _turn_one(_p, _neutral, _neutral, CHARGE, ATTACK, true)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	# Balance type: 15 x 1.05 charge + 10 for the hit taken
	assert_float(s.players[0].special_meter).is_equal_approx(15.0 * 1.05 + _p.hit_meter_gain, 1e-9)
	assert_float(s.players[1].special_meter).is_equal_approx(_p.hit_meter_gain, 1e-9)


func test_stacks_count_consecutive_uses_and_reset() -> void:
	var s := CombatEngine.new_match(_p, _neutral, _neutral, 11)
	CombatEngine.resolve_turn(s, DEFEND, DODGE)
	CombatEngine.resolve_turn(s, DEFEND, DODGE)
	assert_int(s.players[0].guard_stack).is_equal(2)
	assert_int(s.players[1].dodge_stack).is_equal(2)
	assert_int(s.players[0].repeat_count).is_equal(2)
	CombatEngine.resolve_turn(s, CHARGE, DEFEND)
	assert_int(s.players[0].guard_stack).is_equal(0)
	assert_int(s.players[1].dodge_stack).is_equal(0)
	assert_int(s.players[0].repeat_count).is_equal(1)
