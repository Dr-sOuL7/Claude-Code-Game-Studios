class_name MatchFlow
extends RefCounted
## Runs one match for the local modes (Local Versus, Practice vs CPU).
##
## Collects one hidden action per player, resolves the turn through CombatEngine when
## both are in, and announces results through signals. Owns no rules (all in
## src/core/combat/) and no UI. Implements design/gdd/systems-index.md "Match
## Orchestrator (local)" for the first playable.
##
## States: COMMITTING (waiting for actions) -> resolved turn -> COMMITTING | FINISHED.

## A player's hidden action was accepted; the action itself is never emitted.
signal action_locked(player: int)
## Both actions were in and the turn resolved.
signal turn_resolved(result: TurnResult, actions: Array[int], view: Dictionary)
signal match_finished(winner: int, finish: String, detail: String)

const NO_ACTION := -1

var params: CombatParams
var state: MatchState
## -1 when both seats are human; otherwise the seat the CPU plays.
var cpu_seat: int = -1
var _cpu: CpuPolicy
var _pending: Array[int] = [NO_ACTION, NO_ACTION]


func start(match_params: CombatParams, build_a: BuildStats, build_b: BuildStats, seed: int,
		cpu: CpuPolicy = null, cpu_player: int = -1) -> void:
	params = match_params
	state = CombatEngine.new_match(params, build_a, build_b, seed)
	_cpu = cpu
	cpu_seat = cpu_player if cpu != null else -1
	_pending = [NO_ACTION, NO_ACTION]


func is_finished() -> bool:
	return state != null and state.finished


func legal_actions(player: int) -> Array[int]:
	return CombatEngine.legal_actions(state, player)


func has_committed(player: int) -> bool:
	return _pending[player] != NO_ACTION


## Human input. Returns false (and changes nothing) for an illegal or repeated commit.
func submit(player: int, action: int) -> bool:
	if state == null or state.finished or player == cpu_seat or has_committed(player):
		return false
	if not (action in legal_actions(player)):
		return false
	_pending[player] = action
	action_locked.emit(player)
	if cpu_seat >= 0 and not has_committed(cpu_seat):
		# The CPU decides from public state only; it never sees _pending.
		_pending[cpu_seat] = _cpu.choose(state.public_view(), cpu_seat, legal_actions(cpu_seat), params)
		action_locked.emit(cpu_seat)
	if has_committed(0) and has_committed(1):
		_resolve()
	return true


func _resolve() -> void:
	var acts: Array[int] = [_pending[0], _pending[1]]
	_pending = [NO_ACTION, NO_ACTION]
	var r := CombatEngine.resolve_turn(state, acts[0], acts[1])
	turn_resolved.emit(r, acts, state.public_view())
	if state.finished:
		match_finished.emit(state.winner, MatchState.FINISH_NAMES[state.finish], state.finish_detail)
