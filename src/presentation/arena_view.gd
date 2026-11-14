class_name ArenaView
extends Control
## 2D top-down arena for the first playable. Draws two spinning tops and animates one
## resolved turn from its engine events (collision, burst, ring-out, spin finish).
## Display only: it never computes a rule; every number comes from events or the
## public match view (architecture principle "events are the interface").

const ARENA := Color("#10151e")
const RIM := Color("#2a3242")
const EDGE := Color("#f43f5e")
const SPIN_RATE := 14.0

var _primary: Array[Color] = [Color.CYAN, Color.RED]
var _secondary: Array[Color] = [Color.WHITE, Color.BLACK]
var _angle: Array[float] = [0.0, 1.0]
var _spin: Array[float] = [SPIN_RATE, SPIN_RATE]
var _pressure: Array[float] = [0.0, 0.0]
var _approach := 0.0
var _flash := 0.0
var _burst: Array[float] = [-1.0, -1.0]
var _ring: Array[float] = [0.0, 0.0]
var _stopped: Array[bool] = [false, false]
var _ringout_threshold := 120.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 360)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(colors_a: Array[Color], colors_b: Array[Color], ringout_threshold: float) -> void:
	_primary = [colors_a[0], colors_b[0]]
	_secondary = [colors_a[1], colors_b[1]]
	_ringout_threshold = ringout_threshold
	_burst = [-1.0, -1.0]
	_ring = [0.0, 0.0]
	_stopped = [false, false]
	_pressure = [0.0, 0.0]
	_spin = [SPIN_RATE, SPIN_RATE]
	_approach = 0.0
	queue_redraw()


## Updates spin speed and edge distance from the public view, without animation.
func show_state(view: Dictionary, start_energy: Array[float]) -> void:
	for i in range(2):
		var p: Dictionary = view["players"][i]
		_pressure[i] = float(p["position_pressure"]) / _ringout_threshold
		if not _stopped[i]:
			_spin[i] = SPIN_RATE * clampf(float(p["energy"]) / maxf(1.0, start_energy[i]), 0.2, 1.0)
	queue_redraw()


## Animates one turn. Returns the animation length in seconds.
func play_turn(events: Array[Dictionary], view: Dictionary, start_energy: Array[float]) -> float:
	var collided := false
	var burst: Array[bool] = [false, false]
	var ringout: Array[bool] = [false, false]
	var finish := ""
	var winner := -1
	for e in events:
		match e["type"]:
			"collision_roll":
				collided = e["collided"]
			"burst_check":
				if e["burst"]:
					burst[e["target"]] = true
			"ringout_check":
				if e["ringout"]:
					ringout[e["player"]] = true
			"match_finished":
				finish = e["finish"]
				winner = e["winner"]
	var tw := create_tween()
	var length := 0.0
	if collided:
		tw.tween_method(_set_approach, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _flash = 1.0)
		tw.tween_method(_set_approach, 1.0, 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		length += 0.54
	else:
		tw.tween_method(_set_approach, 0.0, 0.45, 0.2)
		tw.tween_method(_set_approach, 0.45, 0.0, 0.25)
		length += 0.45
	tw.tween_callback(show_state.bind(view, start_energy))
	for j in range(2):
		if burst[j]:
			tw.tween_method(_set_burst.bind(j), 0.0, 1.0, 0.9)
			length += 0.9
		elif ringout[j]:
			tw.tween_method(_set_ring.bind(j), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			length += 0.8
	if finish == "spin" or finish == "draw":
		for j in range(2):
			if j != winner and float(view["players"][j]["energy"]) <= 0.0:
				_stopped[j] = true
				tw.tween_method(_set_spin.bind(j), _spin[j], 0.0, 0.8)
				length += 0.8
	return length


func _set_approach(v: float) -> void:
	_approach = v


func _set_burst(v: float, j: int) -> void:
	_burst[j] = v


func _set_ring(v: float, j: int) -> void:
	_ring[j] = v


func _set_spin(v: float, j: int) -> void:
	_spin[j] = v


func _process(delta: float) -> void:
	for i in range(2):
		_angle[i] += _spin[i] * delta * (1.0 if i == 0 else -1.0)
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r_arena := minf(size.x, size.y) * 0.46
	draw_circle(c, r_arena + 10.0, RIM)
	draw_circle(c, r_arena, ARENA)
	draw_arc(c, r_arena * 0.5, 0.0, TAU, 64, Color(RIM, 0.8), 2.0)
	draw_arc(c, r_arena * 0.93, 0.0, TAU, 96, Color(EDGE, 0.45), 5.0)
	var r_top := r_arena * 0.17
	var positions: Array[Vector2] = []
	for i in range(2):
		var dir := -1.0 if i == 0 else 1.0
		var dist := r_arena * 0.2 + r_arena * 0.62 * clampf(_pressure[i], 0.0, 1.1)
		dist = lerpf(dist, r_top * 1.02, _approach)
		dist += r_arena * 1.4 * _ring[i]
		positions.append(c + Vector2(dir * dist, 0.0))
	for i in range(2):
		if _burst[i] >= 0.0:
			_draw_fragments(positions[i], r_top, i)
		else:
			_draw_top(positions[i], r_top, i)
	if _flash > 0.0:
		var mid := (positions[0] + positions[1]) / 2.0
		draw_circle(mid, r_top * (0.6 + 0.8 * (1.0 - _flash)), Color(1, 1, 1, _flash * 0.85))


func _draw_top(pos: Vector2, r: float, i: int) -> void:
	draw_circle(pos, r * 1.08, Color(0, 0, 0, 0.35))
	draw_circle(pos, r, _primary[i])
	draw_arc(pos, r * 0.72, 0.0, TAU, 48, _secondary[i], r * 0.14)
	for k in range(3):
		var a := _angle[i] + k * TAU / 3.0
		var d := Vector2(cos(a), sin(a))
		draw_line(pos + d * r * 0.28, pos + d * r * 1.12, _secondary[i], r * 0.16)
	draw_circle(pos, r * 0.24, Color("#0b0e14"))
	if _stopped[i] and _spin[i] < 0.5:
		draw_circle(pos, r, Color(0.1, 0.1, 0.12, 0.55))


func _draw_fragments(pos: Vector2, r: float, i: int) -> void:
	var t := _burst[i]
	for k in range(7):
		var a := _angle[i] + k * TAU / 7.0
		var d := Vector2(cos(a), sin(a)) * r * (0.3 + 2.6 * t)
		var col := _primary[i] if k % 2 == 0 else _secondary[i]
		draw_circle(pos + d, r * 0.3 * (1.0 - 0.5 * t), Color(col, 1.0 - 0.6 * t))
