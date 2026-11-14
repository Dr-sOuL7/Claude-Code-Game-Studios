class_name PlayerState
extends RefCounted
## Per-player dynamic combat state (design/gdd/combat-system.md, States and Transitions).
##
## Plain data: every field is serialisable through to_dict()/from_dict(). The static
## stats live in `stats`; the core never appears here (TR-combat-002).

var stats: BuildStats
var energy: float
var stability: float
var position_pressure: float = 0.0
var passive_pressure: float = 0.0
var special_meter: float = 0.0
var guard_stack: int = 0
var dodge_stack: int = 0
var combo_count: int = 0
## -1 before the first turn, else a MatchState.Action value.
var last_action: int = -1
var repeat_count: int = 0


static func create(build: BuildStats, params: CombatParams) -> PlayerState:
	var p := PlayerState.new()
	p.stats = build
	p.energy = params.energy_base + params.energy_per_sm * build.sm
	p.stability = params.stab_max
	return p


func to_dict() -> Dictionary:
	return {
		"ap": stats.ap, "li": stats.li, "ms": stats.ms, "st": stats.st, "mb": stats.mb, "sm": stats.sm,
		"energy": energy, "stability": stability, "position_pressure": position_pressure,
		"passive_pressure": passive_pressure, "special_meter": special_meter,
		"guard_stack": guard_stack, "dodge_stack": dodge_stack, "combo_count": combo_count,
		"last_action": last_action, "repeat_count": repeat_count,
	}


static func from_dict(d: Dictionary, params: CombatParams) -> PlayerState:
	var p := PlayerState.new()
	p.stats = BuildStats.from_parts(
			{"ap": d["ap"], "li": d["li"]}, {"ms": d["ms"], "st": d["st"]}, {"mb": d["mb"], "sm": d["sm"]},
			params.type_margin, params.identity_ratio)
	p.energy = float(d["energy"])
	p.stability = float(d["stability"])
	p.position_pressure = float(d["position_pressure"])
	p.passive_pressure = float(d["passive_pressure"])
	p.special_meter = float(d["special_meter"])
	p.guard_stack = int(d["guard_stack"])
	p.dodge_stack = int(d["dodge_stack"])
	p.combo_count = int(d["combo_count"])
	p.last_action = int(d["last_action"])
	p.repeat_count = int(d["repeat_count"])
	return p


## What the opponent and spectators may see. Everything in this object is public by
## design; pending (uncommitted) actions are never stored here at all.
func public_view() -> Dictionary:
	return {
		"type": stats.type_name(), "ap": stats.ap, "li": stats.li, "ms": stats.ms, "st": stats.st, "mb": stats.mb, "sm": stats.sm,
		"energy": energy, "stability": stability, "position_pressure": position_pressure,
		"passive_pressure": passive_pressure, "special_meter": special_meter,
		"guard_stack": guard_stack, "dodge_stack": dodge_stack, "combo_count": combo_count,
		"last_action": last_action, "repeat_count": repeat_count,
	}
