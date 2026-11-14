# gdUnit4 test suite — TR-construction-002 (F0 type classification and identity domain)
class_name BuildStatsClassificationTest
extends GdUnitTestSuite

# Fixtures are the spec's own worked examples (design/gdd/combat-system.md F0 / AC-6).
const B01 := {"ap": 40, "li": 40}
const B03 := {"ap": 60, "li": 20}
const B04 := {"ap": 30, "li": 50}
const B05 := {"ap": 20, "li": 60}
const D01 := {"ms": 50, "st": 50}
const D02 := {"ms": 65, "st": 35}
const D04 := {"ms": 35, "st": 65}
const D05 := {"ms": 20, "st": 80}
const T01 := {"mb": 50, "sm": 50}
const T02 := {"mb": 70, "sm": 30}
const T05 := {"mb": 15, "sm": 85}
const T07 := {"mb": 40, "sm": 60}

# Reference-model distribution over the 512 profiles (results.txt, 2026-11-09).
const EXPECTED_TYPES := {"ATTACK": 169, "BALANCE": 167, "STAMINA": 128, "DEFENSE": 48}
const EXPECTED_DOMAINS := {"ATTACK": 223, "STAMINA": 168, "DEFENSE": 89, "NONE": 32}


func test_spec_example_b03_d02_t02_is_attack() -> void:
	assert_int(BuildStats.from_parts(B03, D02, T02).type).is_equal(BuildStats.Type.ATTACK)


func test_spec_example_b05_d05_t07_is_defense() -> void:
	assert_int(BuildStats.from_parts(B05, D05, T07).type).is_equal(BuildStats.Type.DEFENSE)


func test_spec_example_b04_d04_t05_is_stamina() -> void:
	assert_int(BuildStats.from_parts(B04, D04, T05).type).is_equal(BuildStats.Type.STAMINA)


func test_spec_example_b01_d01_t01_is_balance() -> void:
	var s := BuildStats.from_parts(B01, D01, T01)
	assert_int(s.type).is_equal(BuildStats.Type.BALANCE)
	assert_int(s.total()).is_equal(280)


func test_neutral_build_scores_match_formula() -> void:
	var s := BuildStats.from_parts(B01, D01, T01)
	assert_float(s.score_offense).is_equal_approx((40 + 50 - 35) / 110.0, 1e-12)
	assert_float(s.score_defense).is_equal_approx((50 + 40 - 40) / 100.0, 1e-12)
	assert_float(s.score_stamina).is_equal_approx((50 - 15) / 70.0, 1e-12)


func test_type_and_domain_distribution_over_all_512_profiles() -> void:
	var cat := PartsCatalogue.load_default()
	assert_object(cat).is_not_null()
	var types := {"ATTACK": 0, "DEFENSE": 0, "STAMINA": 0, "BALANCE": 0}
	var domains := {"ATTACK": 0, "DEFENSE": 0, "STAMINA": 0, "NONE": 0}
	for tr in cat.all_part_triples():
		var s := BuildStats.from_catalogue(cat, tr[0], tr[1], tr[2])
		types[s.type_name()] += 1
		var dname: String = "NONE" if s.domain == BuildStats.Domain.NONE else BuildStats.Type.keys()[s.domain]
		domains[dname] += 1
	assert_dict(types).is_equal(EXPECTED_TYPES)
	assert_dict(domains).is_equal(EXPECTED_DOMAINS)


func test_core_is_not_an_input() -> void:
	# BuildStats exposes no core property at all (TR-construction-003).
	var s := BuildStats.from_parts(B01, D01, T01)
	assert_bool("core" in s).is_false()
