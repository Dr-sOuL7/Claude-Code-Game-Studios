# gdUnit4 test suite — TR-combat-009 (GDD worked examples, AC-9) and TR-combat-010 (events)
class_name CombatExamplesTest
extends GdUnitTestSuite

const TOL := 0.01
# Independent arithmetic (computed outside the engine, see story-003 notes):
#   neutral ATTACK: 40 x (1 + 50/120) x 1.5 x 1.05 = 89.25
#   B03D01T01 ATTACK at ap_exp 0.6: 40 x 1.5^0.6 x (1 + 50/120) x 1.5 x 1.15 x 1.06 x 1.08 = 142.7254
const NEUTRAL_ATTACK_IMPACT := 89.25
const GLASS_CANNON_ATTACK_IMPACT := 142.7254
const NEUTRAL_INCOMING_RATIO := 0.76          # 0.95 Balance x (1 - 0.4 x (50-15)/70)
const NEUTRAL_STAB_PER_INCOMING := 0.013      # (1/50) x (1 - 0.7 x (40-20)/40) at turn 1
const NEUTRAL_PUSH_PER_INCOMING := 0.03       # 3 / (50 + 50)
const NEUTRAL_ENERGY_PER_INCOMING := 1.0 / 120.0
const NEUTRAL_START_ENERGY := 90.0            # 30 + 1.2 x 50
const NEUTRAL_UPKEEP_DRAIN := 0.9975          # (1 + 50/160) x 0.95 x 0.8

var _p: CombatParams
var _cat: PartsCatalogue
var _neutral: BuildStats


func before() -> void:
	_p = CombatFixtures.params()
	_cat = CombatFixtures.catalogue()
	_neutral = CombatFixtures.build(_cat, _p, "B01", "D01", "T01")


## First seed (from 1) whose opening turn collides / does not collide for these actions.
func _state_where_first_turn(collides: bool, a: BuildStats, b: BuildStats, act_a: int, act_b: int) -> Array:
	for seed in range(1, 400):
		var s := CombatEngine.new_match(_p, a, b, seed)
		var r := CombatEngine.resolve_turn(s, act_a, act_b)
		if r.events[1]["collided"] == collides:
			return [s, r]
	return []


func test_neutral_attack_outgoing_impact_is_89_25() -> void:
	var me := PlayerState.create(_neutral, _p)
	var v := CombatEngine._outgoing_impact(_p, me, MatchState.Action.ATTACK, MatchState.Action.ATTACK, true)
	assert_float(v).is_equal_approx(NEUTRAL_ATTACK_IMPACT, TOL)


func test_high_ap_attack_uses_diminishing_returns() -> void:
	var cannon := CombatFixtures.build(_cat, _p, "B03", "D01", "T01")
	assert_int(cannon.type).is_equal(BuildStats.Type.ATTACK)
	var me := PlayerState.create(cannon, _p)
	var v := CombatEngine._outgoing_impact(_p, me, MatchState.Action.ATTACK, MatchState.Action.ATTACK, true)
	assert_float(v).is_equal_approx(GLASS_CANNON_ATTACK_IMPACT, TOL)


func test_burst_calibration_point_gives_reference_probability() -> void:
	assert_float(1.0 - exp(-_p.burst_k * _p.burst_ref_x)).is_equal_approx(_p.burst_ref_p, 1e-12)


func test_starting_energy_and_stability() -> void:
	var s := CombatEngine.new_match(_p, _neutral, _neutral, 1)
	assert_float(s.players[0].energy).is_equal_approx(NEUTRAL_START_ENERGY, 1e-9)
	assert_float(s.players[0].stability).is_equal(_p.stab_max)


func test_neutral_mirror_collision_applies_documented_ratios() -> void:
	var found := _state_where_first_turn(true, _neutral, _neutral, MatchState.Action.ATTACK, MatchState.Action.ATTACK)
	assert_array(found).is_not_empty()
	var r: TurnResult = found[1]
	var impacts := r.events.filter(func(e: Dictionary) -> bool: return e["type"] == "impact")
	assert_int(impacts.size()).is_equal(2)
	for e: Dictionary in impacts:
		var out: float = e["outgoing"]
		var inc: float = e["incoming"]
		# random factor is 0.9..1.1 around the 89.25 worked example
		assert_float(out).is_between(NEUTRAL_ATTACK_IMPACT * 0.9 - TOL, NEUTRAL_ATTACK_IMPACT * 1.1 + TOL)
		assert_float(inc / out).is_equal_approx(NEUTRAL_INCOMING_RATIO, 1e-9)
		assert_float(e["stability_loss"] / inc).is_equal_approx(NEUTRAL_STAB_PER_INCOMING, 1e-9)
		assert_float(e["pressure_gain"] / inc).is_equal_approx(NEUTRAL_PUSH_PER_INCOMING, 1e-9)
		assert_float(e["energy_loss"] / inc).is_equal_approx(NEUTRAL_ENERGY_PER_INCOMING, 1e-9)
		assert_float(e["prevented"]).is_equal(0.0)


func test_upkeep_drain_for_neutral_build() -> void:
	var found := _state_where_first_turn(false, _neutral, _neutral, MatchState.Action.DEFEND, MatchState.Action.DEFEND)
	assert_array(found).is_not_empty()
	var s: MatchState = found[0]
	var r: TurnResult = found[1]
	var upkeeps := r.events.filter(func(e: Dictionary) -> bool: return e["type"] == "upkeep")
	assert_int(upkeeps.size()).is_equal(2)
	assert_float(upkeeps[0]["drain"]).is_equal_approx(NEUTRAL_UPKEEP_DRAIN, 1e-9)
	assert_float(s.players[0].energy).is_equal_approx(NEUTRAL_START_ENERGY - NEUTRAL_UPKEEP_DRAIN, 1e-9)


func test_events_account_for_every_energy_change() -> void:
	# TR-combat-010: replaying the event numbers reproduces the state.
	var rng := Prng.new(8)
	var a := CombatFixtures.build(_cat, _p, "B06", "D03", "T02")
	var b := CombatFixtures.build(_cat, _p, "B04", "D05", "T07")
	var s := CombatEngine.new_match(_p, a, b, 2024)
	var energy: Array[float] = [s.players[0].energy, s.players[1].energy]
	var stab: Array[float] = [s.players[0].stability, s.players[1].stability]
	while not s.finished:
		var r := CombatEngine.resolve_turn(s, CombatFixtures.random_action(s, 0, rng), CombatFixtures.random_action(s, 1, rng))
		for e: Dictionary in r.events:
			match e["type"]:
				"impact":
					energy[e["target"]] -= e["energy_loss"]
					stab[e["target"]] = maxf(0.0, stab[e["target"]] - e["stability_loss"])
				"defend_counter":
					stab[e["hitter"]] = maxf(0.0, stab[e["hitter"]] - e["stability_loss"])
				"recoil":
					stab[e["player"]] = maxf(0.0, stab[e["player"]] - e["stability_loss"])
				"upkeep":
					energy[e["player"]] -= e["drain"] + e["attack_cost"] + e["whiff_cost"] + e["pressure_drain"]
		for i in range(2):
			assert_float(energy[i]).is_equal_approx(s.players[i].energy, 1e-6)
			assert_float(stab[i]).is_equal_approx(s.players[i].stability, 1e-6)
