class_name Prng
extends RefCounted
## MINSTD (Park–Miller) generator: state = 16807 * state mod (2^31 - 1).
##
## Integer-only so every platform gives the same stream (ADR-0001). The largest
## intermediate is 16807 * (2^31 - 2) < 2^46, far inside GDScript's 64-bit int.
## Serialisable with to_dict()/from_dict() so a MatchState carries its own stream.

const MODULUS: int = 2147483647
const MULTIPLIER: int = 16807

var state: int = 1


func _init(seed: int = 1) -> void:
	seed_with(seed)


## Any int seeds the generator; 0 (and multiples of the modulus) map to 1 because
## MINSTD has a fixed point at 0.
func seed_with(seed: int) -> void:
	var s := seed % MODULUS
	if s < 0:
		s += MODULUS
	state = s if s != 0 else 1


## Next value in 1 .. 2^31 - 2.
func next_int() -> int:
	state = (MULTIPLIER * state) % MODULUS
	return state


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_int() - 1) / float(MODULUS - 1)


## Uniform float in [a, b).
func uniform(a: float, b: float) -> float:
	return a + (b - a) * next_float()


## Uniform index in 0 .. n-1.
func next_index(n: int) -> int:
	return int(floor(next_float() * n))


func to_dict() -> Dictionary:
	return {"state": state}


static func from_dict(d: Dictionary) -> Prng:
	var p := Prng.new(1)
	p.state = int(d["state"])
	return p
