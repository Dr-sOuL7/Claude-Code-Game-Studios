class_name BuildStats
extends RefCounted
## The six derived stats of a top plus its emergent type and identity domain.
##
## Formula F0 of design/gdd/combat-system.md. The core is cosmetic and is not an
## input here (TR-construction-003): nothing downstream can depend on it.
## Scores are computed in the order Attack, Defense, Stamina and ties resolve in
## that order, matching the reference model exactly.

enum Type { ATTACK, DEFENSE, STAMINA, BALANCE }
## Identity domain for the +8% bonus; NONE when no axis dominates by identity_ratio.
enum Domain { NONE = -1, ATTACK = 0, DEFENSE = 1, STAMINA = 2 }

var ap: int
var li: int
var ms: int
var st: int
var mb: int
var sm: int
var type: Type = Type.BALANCE
var domain: Domain = Domain.NONE
## F0 scores, each nominally 0..1 over the shipped content set.
var score_offense: float
var score_defense: float
var score_stamina: float


## Derives stats from three part records ({"ap","li"}, {"ms","st"}, {"mb","sm"}).
static func from_parts(blade: Dictionary, disc: Dictionary, tip: Dictionary,
		type_margin: float = 0.15, identity_ratio: float = 1.25) -> BuildStats:
	var s := BuildStats.new()
	s.ap = int(blade["ap"])
	s.li = int(blade["li"])
	s.ms = int(disc["ms"])
	s.st = int(disc["st"])
	s.mb = int(tip["mb"])
	s.sm = int(tip["sm"])
	s._classify(type_margin, identity_ratio)
	return s


## Convenience: look the three ids up in a catalogue.
static func from_catalogue(cat: PartsCatalogue, blade_id: String, disc_id: String,
		tip_id: String, type_margin: float = 0.15, identity_ratio: float = 1.25) -> BuildStats:
	return from_parts(cat.blades[blade_id], cat.discs[disc_id], cat.tips[tip_id],
			type_margin, identity_ratio)


## Sum of the six stats; 280 for every legal build (TR-construction-001).
func total() -> int:
	return ap + li + ms + st + mb + sm


func type_name() -> String:
	return Type.keys()[type]


func _classify(type_margin: float, identity_ratio: float) -> void:
	# Same arithmetic, same order, as prototypes/combat-reference-model classify().
	score_offense = (ap + mb - 35) / 110.0
	score_defense = (st + li - 40) / 100.0
	score_stamina = (sm - 15) / 70.0
	var scores: Array[float] = [score_offense, score_defense, score_stamina]
	var top := 0
	for i in range(1, 3):
		if scores[i] > scores[top]:
			top = i
	var second := -INF
	for i in range(3):
		if i != top and scores[i] > second:
			second = scores[i]
	type = (top as Type) if scores[top] - second >= type_margin else Type.BALANCE
	var mean_others := 0.0
	for i in range(3):
		if i != top:
			mean_others += scores[i]
	mean_others /= 2.0
	if scores[top] >= identity_ratio * mean_others and mean_others > 0.0:
		domain = top as Domain
	else:
		domain = Domain.NONE
