# gdUnit4 test suite — TR-combat-008 (versioned ruleset data)
class_name RulesetLoadTest
extends GdUnitTestSuite

# Knobs the GDD names in §8/§13 that every engine formula reads.
const REQUIRED_KNOBS := [
	"classification.type_margin", "classification.identity_ratio",
	"collision.base", "collision.aggressive_bonus", "collision.dodge_reduction", "collision.dodge_decay", "collision.min", "collision.max",
	"impact.ap_exp", "impact.action_mult.attack", "impact.action_mult.special", "impact.random_min", "impact.random_max",
	"incoming.defend_fresh", "incoming.defend_floor", "incoming.dodge_incoming", "incoming.charge_mult", "incoming.mb_evade",
	"stability.max", "stability.li_stab", "stability.li_recoil",
	"pressure.scale", "pressure.st_share", "pressure.ringout_threshold",
	"burst.ref_x", "burst.ref_p", "burst.cap",
	"energy.base", "energy.per_sm", "energy.impact_divisor", "energy.mb_drain_divisor", "energy.drain_scale", "energy.whiff_cost", "energy.ap_cost",
	"defend_counter.ratio", "special.cost", "special.hit_meter_gain",
]


func test_v1_loads_with_every_required_knob() -> void:
	var r := Ruleset.load_version("v1")
	assert_object(r).is_not_null()
	assert_str(r.version).is_equal("v1")
	for path in REQUIRED_KNOBS:
		assert_bool(r.has(path)).override_failure_message("missing knob %s" % path).is_true()


func test_v1_holds_the_gdd_v03_values() -> void:
	var r := Ruleset.load_version("v1")
	assert_float(r.num("impact.ap_exp")).is_equal(0.6)
	assert_float(r.num("defend_counter.ratio")).is_equal(4.0)
	assert_float(r.num("special.cost")).is_equal(50.0)
	assert_float(r.num("energy.impact_divisor")).is_equal(120.0)
	assert_float(r.num("burst.ref_p")).is_equal(0.003)
	assert_float(r.num("pressure.scale")).is_equal(3.0)


func test_missing_knob_is_nan_not_a_default() -> void:
	var r := Ruleset.from_dict({"version": "test", "energy": {"base": 30}})
	assert_bool(r.has("energy.base")).is_true()
	assert_bool(r.has("energy.nonexistent")).is_false()
	assert_bool(is_nan(r.num("energy.nonexistent"))).is_true()


func test_unknown_version_returns_null() -> void:
	assert_object(Ruleset.load_version("v999")).is_null()


func test_finish_order_is_burst_ringout_spin() -> void:
	var r := Ruleset.load_version("v1")
	assert_array(r.strings("match.finish_order")).is_equal(["burst", "ringout", "spin"])
