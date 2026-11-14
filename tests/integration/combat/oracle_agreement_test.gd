# gdUnit4 integration suite — TR-combat-001, TR-combat-009 (story combat-engine/004)
# Replays golden traces produced by the independent Python oracle
# (prototypes/combat-reference-model/oracle_v1.py, frozen with
# `tools/sim/compare_traces.py freeze 24 ...`) through the GDScript engine, so CI checks
# agreement without needing Python. The live 200-match check is tools/sim/compare_traces.py.
class_name OracleAgreementTest
extends GdUnitTestSuite

const FIXTURE := "res://tests/integration/combat/fixtures/oracle_traces.jsonl"
const TOL := 1e-9

var _params: CombatParams
var _cat: PartsCatalogue
var _cases: Array = []


func before() -> void:
	_params = CombatFixtures.params()
	_cat = CombatFixtures.catalogue()
	var text := FileAccess.get_file_as_string(FIXTURE)
	assert_str(text).is_not_empty()
	for line in text.split("\n", false):
		_cases.append(JSON.parse_string(line))


func _close(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _close(a[i], b[i]):
				return false
		return true
	if a is bool or b is bool or a is String or b is String:
		return a == b
	return absf(float(a) - float(b)) <= TOL * maxf(1.0, maxf(absf(float(a)), absf(float(b))))


func test_fixture_covers_every_finish_type() -> void:
	var seen := {}
	for c: Dictionary in _cases:
		var turns: Array = c["turns"]
		seen[turns[turns.size() - 1]["fin"][2]] = true
	for finish in ["burst", "ringout", "spin"]:
		assert_bool(seen.has(finish)).override_failure_message("fixture has no %s finish" % finish).is_true()


func test_engine_reproduces_every_golden_turn() -> void:
	for c: Dictionary in _cases:
		var info: Dictionary = c["case"]
		var golden: Array = c["turns"]
		var trace := MatchTrace.run_case(_params, _cat, int(info["seed"]), String(info["a"]), String(info["b"]))
		assert_int(trace.size()).override_failure_message("%s: turn count" % info).is_equal(golden.size())
		for i in range(golden.size()):
			for key in ["t", "acts", "col", "fin", "pc", "pb", "pr", "p"]:
				if not _close(golden[i][key], trace[i][key]):
					fail("%s turn %d key %s: oracle=%s engine=%s" % [info, i + 1, key, golden[i][key], trace[i][key]])
					return
