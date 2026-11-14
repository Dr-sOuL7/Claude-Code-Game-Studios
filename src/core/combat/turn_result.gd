class_name TurnResult
extends RefCounted
## What CombatEngine.resolve_turn returns: validation outcome plus the typed event list.
##
## `events` is the only output presentation, network and replay consume (TR-combat-010).
## When `ok` is false nothing was mutated and `error` names the rejected input.

var ok: bool = true
var error: String = ""
var events: Array[Dictionary] = []
var finished: bool = false
var winner: int = -1
var finish: MatchState.Finish = MatchState.Finish.NONE


static func rejected(reason: String) -> TurnResult:
	var r := TurnResult.new()
	r.ok = false
	r.error = reason
	return r
