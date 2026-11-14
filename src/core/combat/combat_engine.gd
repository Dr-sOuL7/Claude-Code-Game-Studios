class_name CombatEngine
extends RefCounted
## The SPINFORGE combat rules: one pure function per turn.
##
## Implements design/gdd/combat-system.md v0.3 (formulas F1-F14, edge cases E1-E13).
## No Node, scene, clock, global RNG or I/O: everything comes from MatchState and its
## CombatParams (ADR-0001). The same code runs in the browser, on the authoritative
## server and in the balance simulator.
##
## Resolution order inside a collision is seat-symmetric by construction:
##   1 impacts (both)  2 incoming after mitigation (both)  3 damage applied (both)
##   4 Defend counters (both)  5 burst rolls (both)  6 recoil (both)
## so swapping the two seats (and their PRNG streams) mirrors the outcome exactly.
## Single-threaded: a MatchState must not be resolved from two threads at once.

const A_ATTACK := MatchState.Action.ATTACK
const A_DEFEND := MatchState.Action.DEFEND
const A_DODGE := MatchState.Action.DODGE
const A_CHARGE := MatchState.Action.CHARGE
const A_SPECIAL := MatchState.Action.SPECIAL
const TIE_EPSILON := 1e-9


## Starts a match. `seed` selects the three PRNG streams (see MatchState).
static func new_match(params: CombatParams, build_a: BuildStats, build_b: BuildStats, seed: int) -> MatchState:
	return MatchState.create(params, build_a, build_b, seed)


## Actions `player` (0 or 1) may commit this turn. SPECIAL needs a full enough meter.
static func legal_actions(state: MatchState, player: int) -> Array[int]:
	var out: Array[int] = []
	if state.finished:
		return out
	out.assign([A_ATTACK, A_DEFEND, A_DODGE, A_CHARGE])
	if state.players[player].special_meter >= state.params.special_cost:
		out.append(A_SPECIAL)
	return out


## Resolves one turn from both committed actions. Validates first: on any illegal
## input nothing is mutated and the result has ok == false (TR-combat-004).
static func resolve_turn(state: MatchState, action_a: int, action_b: int) -> TurnResult:
	if state.finished:
		return TurnResult.rejected("match_finished")
	var acts: Array[int] = [action_a, action_b]
	for i in range(2):
		if not (acts[i] in legal_actions(state, i)):
			return TurnResult.rejected("illegal_action_player_%d" % i)

	var p := state.params
	var pl := state.players
	var result := TurnResult.new()
	var ev := result.events
	state.turn += 1
	var t := state.turn
	ev.append({"type": "turn_started", "turn": t, "actions": [acts[0], acts[1]]})

	var aggressive: Array[bool] = [_is_aggressive(acts[0]), _is_aggressive(acts[1])]
	# Arena destabilisation scales every ST this turn.
	var st_factor := maxf(p.arena_floor, 1.0 - p.arena_decay_per_turn * (t - 1))

	# ---- F1 collision probability (per-player terms summed symmetrically) ----------
	var col_terms: Array[float] = [0.0, 0.0]
	for i in range(2):
		var mb := pl[i].stats.mb
		var c := p.col_mb_spec_rate * maxf(0.0, mb - p.col_mb_spec_threshold)
		if aggressive[i]:
			c += p.col_aggressive_bonus
		if acts[i] == A_DODGE:
			var dodge_eff := maxf(0.0, 1.0 - p.col_dodge_decay * pl[i].dodge_stack)
			c -= p.col_dodge_reduction * dodge_eff
		col_terms[i] = c
	var p_raw := p.col_base + (pl[0].stats.mb + pl[1].stats.mb) / p.col_mobility_divisor + (col_terms[0] + col_terms[1])
	var p_col := clampf(p_raw, p.col_min, p.col_max)
	var collided := state.shared_prng.next_float() < p_col
	ev.append({"type": "collision_roll", "turn": t, "probability": p_col, "collided": collided})

	var burst: Array[bool] = [false, false]
	if collided:
		# 1 ---- F2 outgoing impact --------------------------------------------------
		var imp: Array[float] = [0.0, 0.0]
		for i in range(2):
			imp[i] = _outgoing_impact(p, pl[i], acts[i], acts[1 - i], aggressive[i]) \
					* state.player_prng[i].uniform(p.random_min, p.random_max)
		# 2 ---- F3 incoming impact after the target's mitigation ---------------------
		var inc: Array[float] = [0.0, 0.0]
		var prevented: Array[float] = [0.0, 0.0]
		for j in range(2):
			var tgt := pl[j]
			var v := imp[1 - j]
			if acts[j] == A_DEFEND:
				var before := v
				v *= 1.0 - maxf(p.defend_floor, p.defend_fresh - p.defend_step * tgt.guard_stack)
				if tgt.stats.type == BuildStats.Type.DEFENSE:
					v *= p.defense_type_mult
				if tgt.stats.domain == BuildStats.Domain.DEFENSE:
					v *= p.defense_identity_mult
				prevented[j] = before - v
			if acts[j] == A_DODGE:
				v *= p.dodge_incoming
			if acts[j] == A_CHARGE:
				v *= p.charge_incoming_mult
			if tgt.stats.type == BuildStats.Type.BALANCE:
				v *= p.balance_incoming_mult
			v *= 1.0 - p.st_spec_rate * maxf(0.0, tgt.stats.st - p.st_spec_threshold)
			v *= 1.0 - p.mb_evade * (tgt.stats.mb - p.mb_evade_offset) / p.mb_evade_range
			inc[j] = v
		# 3 ---- F4 damage to each target ---------------------------------------------
		for j in range(2):
			var tgt := pl[j]
			var st_eff := tgt.stats.st * st_factor
			var stab_loss := (inc[j] / st_eff) * (1.0 - p.li_stab * (tgt.stats.li - p.li_offset) / p.li_range)
			var push := (inc[j] / (tgt.stats.ms + p.pressure_st_share * tgt.stats.st)) * p.pressure_scale
			var released := tgt.passive_pressure
			var energy_loss := inc[j] / p.energy_impact_divisor
			tgt.stability = maxf(0.0, tgt.stability - stab_loss)
			tgt.position_pressure += push + released
			tgt.passive_pressure = 0.0
			tgt.energy -= energy_loss
			tgt.special_meter = minf(p.meter_max, tgt.special_meter + p.hit_meter_gain)
			ev.append({"type": "impact", "turn": t, "hitter": 1 - j, "target": j, "outgoing": imp[1 - j],
					"incoming": inc[j], "prevented": prevented[j], "stability_loss": stab_loss,
					"pressure_gain": push, "passive_released": released, "energy_loss": energy_loss})
		# 4 ---- F11 Defend counter against each hitter --------------------------------
		for j in range(2):
			if prevented[j] > 0.0 and p.defend_counter_ratio > 0.0:
				var hitter := pl[1 - j]
				var returned := p.defend_counter_ratio * prevented[j]
				var c_stab := returned / (hitter.stats.st * st_factor)
				var c_push := returned / (hitter.stats.ms + p.pressure_st_share * hitter.stats.st) * p.pressure_scale
				hitter.stability = maxf(0.0, hitter.stability - c_stab)
				hitter.position_pressure += c_push
				ev.append({"type": "defend_counter", "turn": t, "defender": j, "hitter": 1 - j,
						"returned": returned, "stability_loss": c_stab, "pressure_gain": c_push})
		# 5 ---- F5 burst roll against each target -------------------------------------
		for j in range(2):
			var tgt := pl[j]
			var hit := pl[1 - j]
			var x := inc[j] * (float(hit.stats.ms) / float(tgt.stats.li)) \
					* (1.0 + (p.stab_max - tgt.stability) / p.stab_max)
			if acts[j] == A_CHARGE:
				x *= p.burst_charge_mult
			if aggressive[1 - j] and (acts[j] == A_DODGE or acts[j] == A_CHARGE):
				x *= p.burst_initiative_mult
			x *= 1.0 - p.li_spec_rate * maxf(0.0, tgt.stats.li - p.li_spec_threshold)
			var p_burst := clampf(1.0 - exp(-p.burst_k * x), 0.0, p.burst_cap)
			burst[j] = state.player_prng[j].next_float() < p_burst
			ev.append({"type": "burst_check", "turn": t, "target": j, "probability": p_burst, "burst": burst[j]})
		# 6 ---- F4 recoil on each hitter ----------------------------------------------
		for i in range(2):
			var me := pl[i]
			var rec := imp[i] / (me.stats.st * st_factor)
			rec *= 1.0 - p.li_recoil * (me.stats.li - p.li_offset) / p.li_range
			if me.stats.type == BuildStats.Type.DEFENSE:
				rec *= p.defense_recoil_mult
			if aggressive[i] and me.combo_count >= 2:
				rec *= 1.0 + p.momentum_per_stack * mini(p.momentum_max_stacks, me.combo_count - 1)
			me.stability = maxf(0.0, me.stability - rec)
			ev.append({"type": "recoil", "turn": t, "player": i, "stability_loss": rec})
	else:
		# F9 passive pressure: only players who did not press the attack accumulate it.
		for i in range(2):
			if not aggressive[i]:
				pl[i].passive_pressure += p.passive_gain
				ev.append({"type": "passive_pressure", "turn": t, "player": i,
						"gain": p.passive_gain, "total": pl[i].passive_pressure})

	# ---- F6 / F12 / F13 upkeep ---------------------------------------------------------
	for i in range(2):
		var me := pl[i]
		var s := me.stats
		var drain := p.drain_base + s.mb / p.mb_drain_divisor
		if s.type == BuildStats.Type.STAMINA:
			drain *= p.stamina_drain_mult
		if s.type == BuildStats.Type.BALANCE:
			drain *= p.balance_drain_mult
		if s.domain == BuildStats.Domain.STAMINA:
			drain *= p.stamina_identity_drain_mult
		drain *= 1.0 - p.sm_spec_rate * maxf(0.0, s.sm - p.sm_spec_threshold)
		drain *= p.drain_scale
		me.energy -= drain
		var attack_cost := 0.0
		var whiff := 0.0
		if aggressive[i]:
			attack_cost = p.ap_cost * (s.ap - p.ap_cost_offset) / p.ap_cost_range
			me.energy -= attack_cost
			if not collided:
				whiff = p.whiff_cost
				me.energy -= whiff
		var pressure_drain := 0.0
		if me.position_pressure > p.pressure_drain_threshold:
			pressure_drain = me.position_pressure / p.pressure_drain_divisor
			me.energy -= pressure_drain
		if acts[i] == A_CHARGE:
			var gain := p.charge_gain
			if s.type == BuildStats.Type.STAMINA:
				gain *= p.stamina_charge_mult
			if s.type == BuildStats.Type.BALANCE:
				gain *= p.balance_charge_mult
			me.special_meter = minf(p.meter_max, me.special_meter + gain)
		if acts[i] == A_SPECIAL:
			me.special_meter = 0.0
		me.guard_stack = me.guard_stack + 1 if acts[i] == A_DEFEND else 0
		me.dodge_stack = me.dodge_stack + 1 if acts[i] == A_DODGE else 0
		me.combo_count = me.combo_count + 1 if (collided and aggressive[i]) else 0
		me.repeat_count = me.repeat_count + 1 if acts[i] == me.last_action else 1
		me.last_action = acts[i]
		ev.append({"type": "upkeep", "turn": t, "player": i, "drain": drain, "attack_cost": attack_cost,
				"whiff_cost": whiff, "pressure_drain": pressure_drain, "energy": me.energy,
				"special_meter": me.special_meter})

	# ---- finishes, in order: Burst > Ring-Out > Spin Finish (Rule 5, E1-E4, E11) --------
	var lost: Array[int] = [MatchState.Finish.NONE, MatchState.Finish.NONE]
	for j in range(2):
		if burst[j]:
			lost[j] = MatchState.Finish.BURST
	if lost[0] == MatchState.Finish.NONE and lost[1] == MatchState.Finish.NONE:
		for j in range(2):
			var me := pl[j]
			if me.position_pressure > p.ringout_threshold:
				var p_ring := minf(p.ringout_cap, p.ringout_base + (me.position_pressure - p.ringout_threshold) / p.ringout_slope_divisor)
				p_ring *= 1.0 - p.ms_spec_rate * maxf(0.0, me.stats.ms - p.ms_spec_threshold)
				p_ring = clampf(p_ring, 0.0, p.ringout_cap)
				var out := state.player_prng[j].next_float() < p_ring
				ev.append({"type": "ringout_check", "turn": t, "player": j, "probability": p_ring, "ringout": out})
				if out:
					lost[j] = MatchState.Finish.RINGOUT
	if lost[0] == MatchState.Finish.NONE and lost[1] == MatchState.Finish.NONE:
		for j in range(2):
			if pl[j].energy <= 0.0:
				lost[j] = MatchState.Finish.SPIN

	if lost[0] != MatchState.Finish.NONE or lost[1] != MatchState.Finish.NONE:
		state.finished = true
		if lost[0] != MatchState.Finish.NONE and lost[1] != MatchState.Finish.NONE:
			if absf(pl[0].stability - pl[1].stability) < TIE_EPSILON:
				state.winner = -1
				state.finish = MatchState.Finish.DRAW
				state.finish_detail = "simultaneous"
			else:
				state.winner = 0 if pl[0].stability > pl[1].stability else 1
				state.finish = lost[1 - state.winner] as MatchState.Finish
				state.finish_detail = "tiebreak"
		else:
			var loser := 0 if lost[0] != MatchState.Finish.NONE else 1
			state.winner = 1 - loser
			state.finish = lost[loser] as MatchState.Finish
			state.finish_detail = ""
		ev.append({"type": "match_finished", "turn": t, "winner": state.winner,
				"finish": MatchState.FINISH_NAMES[state.finish], "detail": state.finish_detail})

	result.finished = state.finished
	result.winner = state.winner
	result.finish = state.finish
	return result


## Largest number of turns any match can last under `params`: the slowest passive
## drain must exhaust the largest energy pool (E10). Used by tests and the simulator.
static func termination_bound(params: CombatParams, builds: Array[BuildStats]) -> int:
	var worst := 0.0
	for s in builds:
		var drain := params.drain_base + s.mb / params.mb_drain_divisor
		if s.type == BuildStats.Type.STAMINA:
			drain *= params.stamina_drain_mult
		if s.type == BuildStats.Type.BALANCE:
			drain *= params.balance_drain_mult
		if s.domain == BuildStats.Domain.STAMINA:
			drain *= params.stamina_identity_drain_mult
		drain *= 1.0 - params.sm_spec_rate * maxf(0.0, s.sm - params.sm_spec_threshold)
		drain *= params.drain_scale
		var life := (params.energy_base + params.energy_per_sm * s.sm) / drain
		worst = maxf(worst, life)
	return int(ceil(worst))


static func _is_aggressive(action: int) -> bool:
	return action == A_ATTACK or action == A_SPECIAL


## F2 without the random factor.
static func _outgoing_impact(p: CombatParams, me: PlayerState, action: int, opp_action: int, aggressive: bool) -> float:
	var s := me.stats
	var v := p.ap_ref * pow(s.ap / p.ap_ref, p.ap_exp) * (1.0 + s.mb / p.imp_mobility_divisor)
	v *= p.action_mult[action]
	if s.type == BuildStats.Type.ATTACK:
		v *= p.attack_type_synergy
	if s.type == BuildStats.Type.BALANCE:
		v *= p.balance_type_synergy
	v *= 1.0 + p.ap_spec_rate * maxf(0.0, s.ap - p.ap_spec_threshold)
	if s.domain == BuildStats.Domain.ATTACK:
		v *= p.attack_identity
	if aggressive:
		if me.combo_count >= 2:
			v *= 1.0 + p.momentum_per_stack * mini(p.momentum_max_stacks, me.combo_count - 1)
		if opp_action == A_DODGE or opp_action == A_CHARGE:
			v *= p.initiative_mult
	if me.repeat_count >= p.adaptation_repeats and action != me.last_action:
		v *= p.adaptation_mult
	return v
