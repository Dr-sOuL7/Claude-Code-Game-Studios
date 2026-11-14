extends SceneTree
## Headless click-through of the first playable: title -> forge -> battle (to the end)
## -> result, in CPU mode and in 2-player mode (with the hand-off screen).
## godot --headless --path . -s res://tools/smoke/ui_flow_smoke.gd
## Prints one line per milestone and exits 0 when every flow reached the result screen.

var _app: Control
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _find(node: Node, cls: Variant) -> Node:
	for c in node.get_children():
		if is_instance_of(c, cls):
			return c
		var deep := _find(c, cls)
		if deep != null:
			return deep
	return null


func _run() -> void:
	seed(12345)
	for vs_cpu in [true, false]:
		_app = (load("res://src/ui/app.tscn") as PackedScene).instantiate()
		root.add_child(_app)
		await _frames(3)
		var title := _find(_app, TitleScreen) as TitleScreen
		if title == null:
			_fail("no title screen"); continue
		title.mode_chosen.emit(vs_cpu)
		await _frames(3)
		var forges := 1 if vs_cpu else 2
		for k in range(forges):
			var forge := _find(_app, ForgeScreen) as ForgeScreen
			if forge == null:
				_fail("no forge screen %d" % k); break
			forge._randomize()
			forge.confirmed.emit(forge._build.duplicate())
			await _frames(3)
		var battle := _find(_app, BattleScreen) as BattleScreen
		if battle == null:
			_fail("no battle screen"); continue
		print("[%s] battle started: %s" % ["cpu" if vs_cpu else "2p", battle._names])
		var turns := 0
		var handoffs := 0
		while _find(_app, ResultScreen) == null and turns < 400:
			var legal := battle._flow.legal_actions(battle._player)
			battle._on_action(legal.pick_random())
			await _frames(2)
			if not vs_cpu and battle._handoff != null and battle._handoff.visible:
				handoffs += 1
				battle._handoff_button.pressed.emit()
				await _frames(2)
				var legal2 := battle._flow.legal_actions(battle._player)
				battle._on_action(legal2.pick_random())
			# wait for the reveal animation to offer "Next turn" / "See result"
			var waited := 0
			while not battle._continue.visible and waited < 600:
				await _frames(1)
				waited += 1
			turns += 1
			battle._continue.pressed.emit()
			await _frames(2)
		var result := _find(_app, ResultScreen) as ResultScreen
		if result == null:
			_fail("no result screen after %d turns" % turns); continue
		print("[%s] result screen after %d turns (handoffs %d): winner=%s finish=%s" % [
				"cpu" if vs_cpu else "2p", turns, handoffs, result._summary["winner"], result._summary["finish"]])
		if not vs_cpu and handoffs != turns:
			_fail("2p mode: expected a hand-off every turn, got %d of %d" % [handoffs, turns])
		result.rematch_pressed.emit()
		await _frames(3)
		if _find(_app, BattleScreen) == null:
			_fail("rematch did not open a battle")
		else:
			print("[%s] rematch opens a new battle" % ("cpu" if vs_cpu else "2p"))
		_app.queue_free()
		await _frames(2)
	print("SMOKE %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _fail(msg: String) -> void:
	_failures += 1
	printerr("SMOKE FAIL: ", msg)
