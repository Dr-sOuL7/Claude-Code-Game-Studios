# gdUnit4 test suite — TR-construction-001, TR-construction-003
# The committed data files are the system under test here, which is why this
# suite reads them (the one sanctioned file read under tests/unit/).
class_name PartsConservationTest
extends GdUnitTestSuite

const BLADE_SUM := 80
const DISC_SUM := 100
const TIP_SUM := 100
const BUILD_TOTAL := 280
const PARTS_PER_KIND := 8
const CORE_COUNT := 15
const PROFILE_COUNT := 512

var _cat: PartsCatalogue


func before() -> void:
	_cat = PartsCatalogue.load_default()
	assert_object(_cat).is_not_null()


func test_shipped_set_has_eight_of_each_part_and_fifteen_cores() -> void:
	assert_int(_cat.blades.size()).is_equal(PARTS_PER_KIND)
	assert_int(_cat.discs.size()).is_equal(PARTS_PER_KIND)
	assert_int(_cat.tips.size()).is_equal(PARTS_PER_KIND)
	assert_int(_cat.cores.size()).is_equal(CORE_COUNT)


func test_every_blade_conserves_ap_plus_li() -> void:
	for id in _cat.blade_ids():
		var b: Dictionary = _cat.blades[id]
		assert_int(int(b["ap"]) + int(b["li"])).override_failure_message("blade %s" % id).is_equal(BLADE_SUM)


func test_every_disc_conserves_ms_plus_st() -> void:
	for id in _cat.disc_ids():
		var d: Dictionary = _cat.discs[id]
		assert_int(int(d["ms"]) + int(d["st"])).override_failure_message("disc %s" % id).is_equal(DISC_SUM)


func test_every_tip_conserves_mb_plus_sm() -> void:
	for id in _cat.tip_ids():
		var t: Dictionary = _cat.tips[id]
		assert_int(int(t["mb"]) + int(t["sm"])).override_failure_message("tip %s" % id).is_equal(TIP_SUM)


func test_all_512_builds_total_280() -> void:
	var triples := _cat.all_part_triples()
	assert_int(triples.size()).is_equal(PROFILE_COUNT)
	for tr in triples:
		var s := BuildStats.from_catalogue(_cat, tr[0], tr[1], tr[2])
		assert_int(s.total()).override_failure_message("%s%s%s" % [tr[0], tr[1], tr[2]]).is_equal(BUILD_TOTAL)


func test_cores_carry_only_cosmetic_fields() -> void:
	for id in _cat.core_ids():
		var c: Dictionary = _cat.cores[id]
		for key in c.keys():
			assert_bool(key in ["name", "primary", "secondary", "theme"]) \
				.override_failure_message("core %s has non-cosmetic field '%s'" % [id, key]).is_true()
