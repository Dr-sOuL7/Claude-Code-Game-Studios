class_name MatchState
extends RefCounted
## The whole state of one match: two players, the turn counter, three PRNG streams and
## the result.
##
## Serialisable (to_dict/from_dict) so a server can rebuild a match from storage and a
## client can be sent a snapshot (ADR-0001, ADR-0003). It never holds a pending action.
##
## Randomness: `shared_prng` decides collisions; `player_prng[i]` decides player i's
## impact variance, the burst roll against player i and player i's ring-out roll.
## Per-player streams are what make seat symmetry exact and testable (TR-combat-007).

enum Action { ATTACK = 0, DEFEND = 1, DODGE = 2, CHARGE = 3, SPECIAL = 4 }
enum Finish { NONE = 0, BURST = 1, RINGOUT = 2, SPIN = 3, DRAW = 4 }

const ACTION_NAMES: Array[String] = ["attack", "defend", "dodge", "charge", "special"]
const FINISH_NAMES: Array[String] = ["none", "burst", "ringout", "spin", "draw"]
const STREAM_SHARED := 0
const STREAM_PLAYER_BASE := 1

## Not serialised: the caller supplies the same ruleset version on load.
var params: CombatParams
var seed: int
var turn: int = 0
var finished: bool = false
## 0 or 1 when someone won; -1 for a draw or an unfinished match.
var winner: int = -1
var finish: Finish = Finish.NONE
## "" normally; "tiebreak" when both players met a finish on the same turn and the
## higher remaining stability decided it.
var finish_detail: String = ""
var shared_prng: Prng
var player_prng: Array[Prng] = []
var players: Array[PlayerState] = []


static func create(match_params: CombatParams, build_a: BuildStats, build_b: BuildStats, seed_value: int) -> MatchState:
	var s := MatchState.new()
	s.params = match_params
	s.seed = seed_value
	s.shared_prng = Prng.for_stream(seed_value, STREAM_SHARED)
	s.player_prng = [Prng.for_stream(seed_value, STREAM_PLAYER_BASE), Prng.for_stream(seed_value, STREAM_PLAYER_BASE + 1)]
	s.players = [PlayerState.create(build_a, match_params), PlayerState.create(build_b, match_params)]
	return s


func to_dict() -> Dictionary:
	return {
		"ruleset_version": params.version, "seed": seed, "turn": turn, "finished": finished,
		"winner": winner, "finish": finish, "finish_detail": finish_detail,
		"shared_prng": shared_prng.to_dict(),
		"player_prng": [player_prng[0].to_dict(), player_prng[1].to_dict()],
		"players": [players[0].to_dict(), players[1].to_dict()],
	}


## Returns null (with an error) when the stored ruleset version is not the one supplied.
static func from_dict(d: Dictionary, match_params: CombatParams) -> MatchState:
	if String(d["ruleset_version"]) != match_params.version:
		push_error("MatchState: stored ruleset %s, supplied %s" % [d["ruleset_version"], match_params.version])
		return null
	var s := MatchState.new()
	s.params = match_params
	s.seed = int(d["seed"])
	s.turn = int(d["turn"])
	s.finished = bool(d["finished"])
	s.winner = int(d["winner"])
	s.finish = int(d["finish"]) as Finish
	s.finish_detail = String(d["finish_detail"])
	s.shared_prng = Prng.from_dict(d["shared_prng"])
	s.player_prng = [Prng.from_dict(d["player_prng"][0]), Prng.from_dict(d["player_prng"][1])]
	s.players = [PlayerState.from_dict(d["players"][0], match_params), PlayerState.from_dict(d["players"][1], match_params)]
	return s


## Snapshot safe to send to both players and spectators (no PRNG state, no seed).
func public_view() -> Dictionary:
	return {
		"ruleset_version": params.version, "turn": turn, "finished": finished, "winner": winner,
		"finish": FINISH_NAMES[finish], "finish_detail": finish_detail,
		"players": [players[0].public_view(), players[1].public_view()],
	}
