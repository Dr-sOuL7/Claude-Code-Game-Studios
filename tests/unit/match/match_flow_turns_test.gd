# gdUnit4 test suite — first playable: MatchFlow orchestration and the practice CPU
class_name MatchFlowTurnsTest
extends GdUnitTestSuite

var _p: CombatParams
var _cat: PartsCatalogue


func before() -> void:
	_p = CombatFixtures.params()
	_cat = CombatFixtures.catalogue()


func _flow(cpu_seat: int = -1) -> MatchFlow:
	var f := MatchFlow.new()
	var cpu := CpuPolicy.load_version("v1", Prng.new(3)) if cpu_seat >= 0 else null
	f.start(_p, CombatFixtures.build(_cat, _p, "B01", "D01", "T01"), CombatFixtures.build(_cat, _p, "B03", "D02", "T02"), 42, cpu, cpu_seat)
	return f


func test_turn_resolves_only_when_both_players_committed() -> void:
	var f := _flow()
	var resolved := {"n": 0}
	f.turn_resolved.connect(func(_r, _a, _v): resolved.n += 1)
	assert_bool(f.submit(0, MatchState.Action.ATTACK)).is_true()
	assert_int(resolved.n).is_equal(0)
	assert_int(f.state.turn).is_equal(0)
	assert_bool(f.submit(1, MatchState.Action.DEFEND)).is_true()
	assert_int(resolved.n).is_equal(1)
	assert_int(f.state.turn).is_equal(1)


func test_second_commit_by_same_player_is_rejected() -> void:
	var f := _flow()
	assert_bool(f.submit(0, MatchState.Action.ATTACK)).is_true()
	assert_bool(f.submit(0, MatchState.Action.DEFEND)).is_false()
	assert_bool(f.has_committed(0)).is_true()


func test_illegal_special_is_rejected() -> void:
	var f := _flow()
	assert_bool(f.submit(0, MatchState.Action.SPECIAL)).is_false()
	assert_bool(f.has_committed(0)).is_false()


func test_action_locked_signal_never_carries_the_action() -> void:
	var f := _flow()
	var seen: Array = []
	f.action_locked.connect(func(player: int): seen.append(player))
	f.submit(1, MatchState.Action.DODGE)
	assert_array(seen).is_equal([1])


func test_cpu_answers_immediately_and_human_cannot_play_its_seat() -> void:
	var f := _flow(1)
	assert_bool(f.submit(1, MatchState.Action.ATTACK)).is_false()
	assert_bool(f.submit(0, MatchState.Action.ATTACK)).is_true()
	assert_int(f.state.turn).is_equal(1)


func test_cpu_match_always_finishes_with_legal_actions() -> void:
	for seed in range(1, 21):
		var f := MatchFlow.new()
		var cpu := CpuPolicy.load_version("v1", Prng.new(seed))
		var builds := CombatFixtures.all_builds(_cat, _p)
		f.start(_p, builds[(seed * 37) % 512], builds[(seed * 101) % 512], seed, cpu, 1)
		var human := Prng.new(seed + 1000)
		var guard := 0
		while not f.is_finished() and guard < 400:
			var legal := f.legal_actions(0)
			assert_bool(f.submit(0, legal[human.next_index(legal.size())])).is_true()
			guard += 1
		assert_bool(f.is_finished()).is_true()


func test_match_finished_signal_reports_the_engine_result() -> void:
	var f := _flow()
	var got := {}
	f.match_finished.connect(func(w: int, fin: String, d: String): got.merge({"w": w, "fin": fin, "d": d}))
	f.state.players[1].energy = 0.01
	f.submit(0, MatchState.Action.DEFEND)
	f.submit(1, MatchState.Action.DEFEND)
	assert_bool(f.is_finished()).is_true()
	assert_int(got["w"]).is_equal(0)
	assert_str(got["fin"]).is_equal("spin")


func test_cpu_weights_react_to_public_state() -> void:
	var cpu := CpuPolicy.load_version("v1", Prng.new(1))
	var f := _flow()
	var base := cpu._weights(f.state.public_view(), 1, _p)
	f.state.players[0].guard_stack = 3   # opponent turtling
	var turtle := cpu._weights(f.state.public_view(), 1, _p)
	assert_float(turtle[MatchState.Action.CHARGE]).is_greater(base[MatchState.Action.CHARGE])
	assert_float(turtle[MatchState.Action.ATTACK]).is_greater(base[MatchState.Action.ATTACK])
