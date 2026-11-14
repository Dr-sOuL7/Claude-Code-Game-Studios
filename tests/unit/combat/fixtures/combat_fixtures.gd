class_name CombatFixtures
extends RefCounted
## Shared factories for combat tests. The committed ruleset file is the fixture: tests
## must exercise the numbers the game ships, so they load it rather than copy it.

const RULESET_VERSION := "v1"


static func params() -> CombatParams:
	return CombatParams.load_version(RULESET_VERSION)


## A fresh, independently mutable copy for tests that bend a knob.
static func params_copy() -> CombatParams:
	return CombatParams.load_version(RULESET_VERSION)


static func catalogue() -> PartsCatalogue:
	return PartsCatalogue.load_default()


static func build(cat: PartsCatalogue, p: CombatParams, blade: String, disc: String, tip: String) -> BuildStats:
	return BuildStats.from_catalogue(cat, blade, disc, tip, p.type_margin, p.identity_ratio)


static func all_builds(cat: PartsCatalogue, p: CombatParams) -> Array[BuildStats]:
	var out: Array[BuildStats] = []
	for tr in cat.all_part_triples():
		out.append(build(cat, p, tr[0], tr[1], tr[2]))
	return out


## Uniformly random legal action for `player`, drawn from the test's own generator.
static func random_action(state: MatchState, player: int, rng: Prng) -> int:
	var legal := CombatEngine.legal_actions(state, player)
	return legal[rng.next_index(legal.size())]
