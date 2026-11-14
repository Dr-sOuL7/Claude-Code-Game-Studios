class_name CpuPolicy
extends RefCounted
## Practice-mode opponent: a weighted random choice over legal actions.
##
## Reads only public information (MatchState.public_view()), never the human's pending
## action, so it plays fairly under the hidden-commit rule (combat GDD Rule 4). Weights
## come from assets/data/ai/ai_cpu_v<N>.json. Randomness comes from an injected Prng so
## tests are deterministic.

const DATA_PATH := "res://assets/data/ai/ai_cpu_%s.json"
const ACTION_KEYS: Array[String] = ["attack", "defend", "dodge", "charge", "special"]

var _cfg: Dictionary = {}
var _rng: Prng


static func load_version(ver: String, rng: Prng) -> CpuPolicy:
	var path := DATA_PATH % ver
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (parsed is Dictionary):
		push_error("CpuPolicy: cannot load %s" % path)
		return null
	return from_dict(parsed, rng)


static func from_dict(cfg: Dictionary, rng: Prng) -> CpuPolicy:
	var c := CpuPolicy.new()
	c._cfg = cfg
	c._rng = rng
	return c


## Picks an action for `me` (0 or 1). `legal` comes from CombatEngine.legal_actions.
func choose(view: Dictionary, me: int, legal: Array[int], params: CombatParams) -> int:
	var w := _weights(view, me, params)
	var total := 0.0
	for a in legal:
		total += maxf(0.0, w[a])
	if total <= 0.0:
		return legal[_rng.next_index(legal.size())]
	var roll := _rng.next_float() * total
	for a in legal:
		roll -= maxf(0.0, w[a])
		if roll < 0.0:
			return a
	return legal[legal.size() - 1]


## Relative weight per action index; exposed for tests.
func _weights(view: Dictionary, me: int, params: CombatParams) -> Array[float]:
	var w: Array[float] = []
	var base: Dictionary = _cfg["base_weights"]
	for k in ACTION_KEYS:
		w.append(float(base[k]))
	var mine: Dictionary = view["players"][me]
	var opp: Dictionary = view["players"][1 - me]
	if mine["energy"] < opp["energy"]:
		_add(w, _cfg["behind_on_energy"])
	var rep: Dictionary = _cfg["opponent_repeats_attack"]
	if opp["last_action"] == MatchState.Action.ATTACK and opp["repeat_count"] >= rep["repeats"]:
		_add(w, rep)
	var turtle: Dictionary = _cfg["opponent_turtling"]
	if opp["guard_stack"] >= turtle["guard_stack"]:
		_add(w, turtle)
	var ready: Dictionary = _cfg["meter_nearly_ready"]
	if mine["special_meter"] >= ready["fraction_of_cost"] * params.special_cost and mine["special_meter"] < params.special_cost:
		_add(w, ready)
	var low: Dictionary = _cfg["low_stability"]
	if mine["stability"] < low["threshold"]:
		_add(w, low)
	var hp: Dictionary = _cfg["high_pressure"]
	if mine["position_pressure"] >= hp["fraction_of_ringout"] * params.ringout_threshold:
		_add(w, hp)
	return w


static func _add(w: Array[float], adj: Dictionary) -> void:
	for i in range(ACTION_KEYS.size()):
		if adj.has(ACTION_KEYS[i]):
			w[i] += float(adj[ACTION_KEYS[i]])
