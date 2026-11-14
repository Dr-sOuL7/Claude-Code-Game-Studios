class_name CombatParams
extends RefCounted
## Typed, cached view of a Ruleset for the combat hot path.
##
## Built once per ruleset so resolve_turn never does string lookups. Every field maps
## to one knob in assets/data/combat/combat_ruleset_<version>.json, which documents it
## against design/gdd/combat-system.md. `from_ruleset` returns null if any knob is
## missing: the engine never runs on a default it invented (TR-combat-008).

var version: String
# classification (F0)
var type_margin: float
var identity_ratio: float
# collision (F1)
var col_base: float
var col_mobility_divisor: float
var col_aggressive_bonus: float
var col_dodge_reduction: float
var col_dodge_decay: float
var col_mb_spec_threshold: float
var col_mb_spec_rate: float
var col_min: float
var col_max: float
# impact (F2)
var ap_ref: float
var ap_exp: float
var imp_mobility_divisor: float
var action_mult: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var attack_type_synergy: float
var balance_type_synergy: float
var ap_spec_threshold: float
var ap_spec_rate: float
var attack_identity: float
var momentum_per_stack: float
var momentum_max_stacks: int
var initiative_mult: float
var adaptation_mult: float
var adaptation_repeats: int
var random_min: float
var random_max: float
# incoming (F3)
var defend_fresh: float
var defend_step: float
var defend_floor: float
var defense_type_mult: float
var defense_identity_mult: float
var dodge_incoming: float
var charge_incoming_mult: float
var balance_incoming_mult: float
var st_spec_threshold: float
var st_spec_rate: float
var mb_evade: float
var mb_evade_offset: float
var mb_evade_range: float
# stability (F4)
var stab_max: float
var arena_decay_per_turn: float
var arena_floor: float
var li_stab: float
var li_recoil: float
var li_offset: float
var li_range: float
var defense_recoil_mult: float
# pressure (F4, F7, F9)
var pressure_scale: float
var pressure_st_share: float
var passive_gain: float
var ringout_threshold: float
var ringout_base: float
var ringout_slope_divisor: float
var ringout_cap: float
var ms_spec_threshold: float
var ms_spec_rate: float
var pressure_drain_threshold: float
var pressure_drain_divisor: float
# burst (F5)
var burst_ref_x: float
var burst_ref_p: float
var burst_cap: float
var burst_charge_mult: float
var burst_initiative_mult: float
var li_spec_threshold: float
var li_spec_rate: float
## Derived: -ln(1 - ref_p) / ref_x.
var burst_k: float
# energy (F6, F12)
var energy_base: float
var energy_per_sm: float
var energy_impact_divisor: float
var drain_base: float
var mb_drain_divisor: float
var stamina_drain_mult: float
var balance_drain_mult: float
var stamina_identity_drain_mult: float
var sm_spec_threshold: float
var sm_spec_rate: float
var drain_scale: float
var whiff_cost: float
var ap_cost: float
var ap_cost_offset: float
var ap_cost_range: float
# defend counter (F11) and special (F13)
var defend_counter_ratio: float
var special_cost: float
var charge_gain: float
var stamina_charge_mult: float
var balance_charge_mult: float
var hit_meter_gain: float
var meter_max: float
var max_turns_safety: int

# knob path -> property name; the single list both the loader and the tests use.
const NUMERIC_KNOBS := {
	"classification.type_margin": "type_margin", "classification.identity_ratio": "identity_ratio",
	"collision.base": "col_base", "collision.mobility_divisor": "col_mobility_divisor",
	"collision.aggressive_bonus": "col_aggressive_bonus", "collision.dodge_reduction": "col_dodge_reduction",
	"collision.dodge_decay": "col_dodge_decay", "collision.mb_spec_threshold": "col_mb_spec_threshold",
	"collision.mb_spec_rate": "col_mb_spec_rate", "collision.min": "col_min", "collision.max": "col_max",
	"impact.ap_ref": "ap_ref", "impact.ap_exp": "ap_exp", "impact.mobility_divisor": "imp_mobility_divisor",
	"impact.attack_type_synergy": "attack_type_synergy", "impact.balance_type_synergy": "balance_type_synergy",
	"impact.ap_spec_threshold": "ap_spec_threshold", "impact.ap_spec_rate": "ap_spec_rate",
	"impact.attack_identity": "attack_identity", "impact.momentum_per_stack": "momentum_per_stack",
	"impact.momentum_max_stacks": "momentum_max_stacks", "impact.initiative_mult": "initiative_mult",
	"impact.adaptation_mult": "adaptation_mult", "impact.adaptation_repeats": "adaptation_repeats",
	"impact.random_min": "random_min", "impact.random_max": "random_max",
	"incoming.defend_fresh": "defend_fresh", "incoming.defend_step": "defend_step", "incoming.defend_floor": "defend_floor",
	"incoming.defense_type_mult": "defense_type_mult", "incoming.defense_identity_mult": "defense_identity_mult",
	"incoming.dodge_incoming": "dodge_incoming", "incoming.charge_mult": "charge_incoming_mult",
	"incoming.balance_type_mult": "balance_incoming_mult", "incoming.st_spec_threshold": "st_spec_threshold",
	"incoming.st_spec_rate": "st_spec_rate", "incoming.mb_evade": "mb_evade",
	"incoming.mb_evade_offset": "mb_evade_offset", "incoming.mb_evade_range": "mb_evade_range",
	"stability.max": "stab_max", "stability.arena_decay_per_turn": "arena_decay_per_turn", "stability.arena_floor": "arena_floor",
	"stability.li_stab": "li_stab", "stability.li_recoil": "li_recoil", "stability.li_offset": "li_offset",
	"stability.li_range": "li_range", "stability.defense_recoil_mult": "defense_recoil_mult",
	"pressure.scale": "pressure_scale", "pressure.st_share": "pressure_st_share", "pressure.passive_gain": "passive_gain",
	"pressure.ringout_threshold": "ringout_threshold", "pressure.ringout_base": "ringout_base",
	"pressure.ringout_slope_divisor": "ringout_slope_divisor", "pressure.ringout_cap": "ringout_cap",
	"pressure.ms_spec_threshold": "ms_spec_threshold", "pressure.ms_spec_rate": "ms_spec_rate",
	"pressure.drain_threshold": "pressure_drain_threshold", "pressure.drain_divisor": "pressure_drain_divisor",
	"burst.ref_x": "burst_ref_x", "burst.ref_p": "burst_ref_p", "burst.cap": "burst_cap",
	"burst.charge_mult": "burst_charge_mult", "burst.initiative_mult": "burst_initiative_mult",
	"burst.li_spec_threshold": "li_spec_threshold", "burst.li_spec_rate": "li_spec_rate",
	"energy.base": "energy_base", "energy.per_sm": "energy_per_sm", "energy.impact_divisor": "energy_impact_divisor",
	"energy.drain_base": "drain_base", "energy.mb_drain_divisor": "mb_drain_divisor",
	"energy.stamina_type_mult": "stamina_drain_mult", "energy.balance_type_mult": "balance_drain_mult",
	"energy.stamina_identity_mult": "stamina_identity_drain_mult", "energy.sm_spec_threshold": "sm_spec_threshold",
	"energy.sm_spec_rate": "sm_spec_rate", "energy.drain_scale": "drain_scale", "energy.whiff_cost": "whiff_cost",
	"energy.ap_cost": "ap_cost", "energy.ap_cost_offset": "ap_cost_offset", "energy.ap_cost_range": "ap_cost_range",
	"defend_counter.ratio": "defend_counter_ratio",
	"special.cost": "special_cost", "special.charge_gain": "charge_gain", "special.stamina_charge_mult": "stamina_charge_mult",
	"special.balance_charge_mult": "balance_charge_mult", "special.hit_meter_gain": "hit_meter_gain", "special.meter_max": "meter_max",
	"match.max_turns_safety": "max_turns_safety",
}
const ACTION_KEYS: Array[String] = ["attack", "defend", "dodge", "charge", "special"]


static func from_ruleset(rules: Ruleset) -> CombatParams:
	var p := CombatParams.new()
	p.version = rules.version
	var missing: Array[String] = []
	for path: String in NUMERIC_KNOBS:
		if not rules.has(path):
			missing.append(path)
			continue
		p.set(NUMERIC_KNOBS[path], rules.num(path))
	for i in range(ACTION_KEYS.size()):
		var path := "impact.action_mult." + ACTION_KEYS[i]
		if rules.has(path):
			p.action_mult[i] = rules.num(path)
		else:
			missing.append(path)
	if not missing.is_empty():
		push_error("CombatParams: ruleset %s is missing knobs: %s" % [rules.version, ", ".join(missing)])
		return null
	if p.burst_ref_p <= 0.0 or p.burst_ref_p >= 1.0 or p.burst_ref_x <= 0.0:
		push_error("CombatParams: burst.ref_p must be in (0,1) and burst.ref_x > 0")
		return null
	p.burst_k = -log(1.0 - p.burst_ref_p) / p.burst_ref_x
	return p


## Loads and caches nothing: callers keep the returned object for the life of a ruleset.
static func load_version(ver: String) -> CombatParams:
	var rules := Ruleset.load_version(ver)
	return from_ruleset(rules) if rules != null else null
