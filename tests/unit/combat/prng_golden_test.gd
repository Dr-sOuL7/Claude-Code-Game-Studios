# gdUnit4 test suite — TR-combat-001 (deterministic PRNG, ADR-0001)
class_name PrngGoldenTest
extends GdUnitTestSuite

# Park–Miller MINSTD, seed 1: the published first values of the sequence.
const GOLDEN_SEED_1 := [16807, 282475249, 1622650073, 984943658, 1144108930, 470211272, 101027544, 1457850878, 1458777923, 2007237709]
# Value after 10,000 steps from seed 1, from Park & Miller (1988).
const TEN_THOUSANDTH := 1043618065


func test_first_ten_values_match_golden_vector() -> void:
	var p := Prng.new(1)
	for expected in GOLDEN_SEED_1:
		assert_int(p.next_int()).is_equal(expected)


func test_ten_thousandth_value_matches_park_miller() -> void:
	var p := Prng.new(1)
	var v := 0
	for i in range(10000):
		v = p.next_int()
	assert_int(v).is_equal(TEN_THOUSANDTH)


func test_zero_seed_is_not_a_fixed_point() -> void:
	var p := Prng.new(0)
	assert_int(p.next_int()).is_equal(16807)


func test_negative_seed_is_valid() -> void:
	var p := Prng.new(-5)
	var v := p.next_int()
	assert_int(v).is_greater(0)
	assert_int(v).is_less(Prng.MODULUS)


func test_next_float_is_in_unit_interval() -> void:
	var p := Prng.new(12345)
	for i in range(10000):
		var f := p.next_float()
		assert_float(f).is_greater_equal(0.0)
		assert_float(f).is_less(1.0)


func test_uniform_maps_into_range() -> void:
	var p := Prng.new(7)
	for i in range(1000):
		var f := p.uniform(0.9, 1.1)
		assert_float(f).is_greater_equal(0.9)
		assert_float(f).is_less(1.1)


func test_same_seed_same_stream() -> void:
	var a := Prng.new(99)
	var b := Prng.new(99)
	for i in range(100):
		assert_int(a.next_int()).is_equal(b.next_int())


func test_serialisation_round_trip_continues_the_stream() -> void:
	var a := Prng.new(2024)
	for i in range(37):
		a.next_int()
	var b := Prng.from_dict(a.to_dict())
	for i in range(50):
		assert_int(b.next_int()).is_equal(a.next_int())
