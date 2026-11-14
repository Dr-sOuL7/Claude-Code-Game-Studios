class_name BattleScreen
extends VBoxContainer
## The duel. Shows both tops' public state, the arena, a turn log and the five actions.
## Two-player mode hides Player 1's choice behind a hand-off screen before Player 2
## picks (combat GDD Rule 4). All rules run in MatchFlow / CombatEngine; this screen
## only sends commits and displays results.

signal match_over(summary: Dictionary)
signal quit_pressed

const ACTION_HINTS := ["hard hit", "block + counter", "avoid the clash", "fill Special", "huge hit"]

var _flow: MatchFlow
var _vs_cpu: bool
var _names: Array[String] = []
var _start_energy: Array[float] = [1.0, 1.0]
var _player := 0
var _turn_label: Label
var _cards: Array[Dictionary] = []
var _arena: ArenaView
var _prompt: Label
var _log: RichTextLabel
var _action_buttons: Array[Button] = []
var _actions_box: VBoxContainer
var _continue: Button
var _handoff: Control
var _handoff_title: Label
var _handoff_button: Button
var _last_view: Dictionary = {}
var _setup_data: Dictionary = {}


func setup(flow: MatchFlow, vs_cpu: bool, names: Array[String], colors: Array, types: Array[String]) -> void:
	_flow = flow
	_vs_cpu = vs_cpu
	_names = names
	_setup_data = {"colors": colors, "types": types}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	_turn_label = UiKit.label("", 26, UiKit.MUTED)
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_turn_label)
	var quit := UiKit.button(tr("Quit"), 56)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit.custom_minimum_size = Vector2(110, 56)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	top.add_child(quit)
	add_child(top)

	var cards := HBoxContainer.new()
	for i in range(2):
		cards.add_child(_make_card(i))
	add_child(cards)

	_arena = ArenaView.new()
	add_child(_arena)
	var colors: Array = _setup_data["colors"]
	_arena.setup(colors[0], colors[1], _flow.params.ringout_threshold)

	var info := UiKit.panel()
	info.custom_minimum_size = Vector2(0, 190)
	var info_col := VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 4)
	_prompt = UiKit.label("", 26, UiKit.ACCENT)
	info_col.add_child(_prompt)
	_log = RichTextLabel.new()
	_log.fit_content = false
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 120)
	_log.add_theme_font_size_override("normal_font_size", 21)
	_log.add_theme_color_override("default_color", UiKit.TEXT)
	info_col.add_child(_log)
	info.add_child(info_col)
	add_child(info)

	_actions_box = VBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 8)
	var row1 := HBoxContainer.new()
	var row2 := HBoxContainer.new()
	for a in range(5):
		var b := UiKit.button("", 78)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_action.bind(a))
		_action_buttons.append(b)
		if a < 2:
			row1.add_child(b)
		elif a < 4:
			row2.add_child(b)
	_actions_box.add_child(row1)
	_actions_box.add_child(row2)
	_actions_box.add_child(_action_buttons[4])
	add_child(_actions_box)

	_continue = UiKit.button(tr("Next turn"), 84)
	_continue.add_theme_font_size_override("font_size", 30)
	_continue.pressed.connect(_on_continue)
	_continue.visible = false
	add_child(_continue)

	_build_handoff()
	_flow.turn_resolved.connect(_on_turn_resolved)
	for i in range(2):
		_start_energy[i] = _flow.state.players[i].energy
	_last_view = _flow.state.public_view()
	_refresh_cards(_last_view)
	_arena.show_state(_last_view, _start_energy)
	_log.text = tr("Both tops launch into the arena!")
	_begin_choice(0)


func _make_card(i: int) -> PanelContainer:
	var p := UiKit.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var colors: Array = _setup_data["colors"]
	var name_l := UiKit.label(_names[i], 26, (colors[i] as Array)[0])
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(name_l)
	var tname: String = _setup_data["types"][i]
	col.add_child(UiKit.label(tname, 20, UiKit.type_color(tname)))
	var bars := {}
	for spec in [["energy", tr("Energy"), UiKit.GOOD], ["stability", tr("Stability"), UiKit.ACCENT],
			["pressure", tr("Edge pressure"), UiKit.WARN], ["special", tr("Special"), Color("#a855f7")]]:
		var l := UiKit.label("", 18, UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(l)
		var b := UiKit.bar(100.0, spec[2], 14)
		col.add_child(b)
		bars[spec[0]] = {"bar": b, "label": l, "title": spec[1]}
	var stacks := UiKit.label("", 17, UiKit.MUTED)
	stacks.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(stacks)
	p.add_child(col)
	_cards.append({"bars": bars, "stacks": stacks})
	return p


func _refresh_cards(view: Dictionary) -> void:
	var prm := _flow.params
	_turn_label.text = tr("Turn %d") % (int(view["turn"]) + (0 if view["finished"] else 1))
	for i in range(2):
		var pv: Dictionary = view["players"][i]
		var bars: Dictionary = _cards[i]["bars"]
		_set_bar(bars["energy"], maxf(0.0, pv["energy"]), _start_energy[i], "%d")
		_set_bar(bars["stability"], pv["stability"], prm.stab_max, "%d")
		_set_bar(bars["pressure"], pv["position_pressure"], prm.ringout_threshold, "%d / " + str(int(prm.ringout_threshold)))
		_set_bar(bars["special"], pv["special_meter"], prm.meter_max, "%d" + (tr("  READY") if pv["special_meter"] >= prm.special_cost else " / " + str(int(prm.special_cost))))
		(_cards[i]["stacks"] as Label).text = tr("Guard %d  Dodge %d  Combo %d") % [pv["guard_stack"], pv["dodge_stack"], pv["combo_count"]]


func _set_bar(entry: Dictionary, value: float, max_value: float, fmt: String) -> void:
	var b: ProgressBar = entry["bar"]
	b.max_value = max_value
	b.value = clampf(value, 0.0, max_value)
	(entry["label"] as Label).text = "%s  %s" % [entry["title"], fmt % roundi(value)]


func _begin_choice(player: int) -> void:
	_player = player
	_continue.visible = false
	_actions_box.visible = true
	var legal := _flow.legal_actions(player)
	for a in range(5):
		var b := _action_buttons[a]
		var label := TurnNarrator.tr_action(a)
		if a == MatchState.Action.SPECIAL and not (a in legal):
			b.text = "%s  (%s)" % [label, tr("needs %d meter") % int(_flow.params.special_cost)]
		else:
			b.text = "%s\n%s" % [label, tr(ACTION_HINTS[a])] if a < 4 else "%s - %s" % [label, tr(ACTION_HINTS[a])]
		b.disabled = not (a in legal)
	if _vs_cpu:
		_prompt.text = tr("Choose your move")
	else:
		_prompt.text = tr("%s - choose your move (%s, look away!)") % [_names[player], _names[1 - player]]
	_action_buttons[0].grab_focus.call_deferred()


func _on_action(a: int) -> void:
	if not _flow.submit(_player, a):
		return
	if not _vs_cpu and _player == 0 and not _flow.has_committed(1):
		_show_handoff(1)


func _on_turn_resolved(result: TurnResult, actions: Array[int], view: Dictionary) -> void:
	_actions_box.visible = false
	_prompt.text = TurnNarrator.action_line(actions, _names)
	var lines := TurnNarrator.describe(result.events, _names)
	_log.text = "\n".join(lines)
	_last_view = view
	var length := _arena.play_turn(result.events, view, _start_energy)
	await get_tree().create_timer(minf(length, 0.6)).timeout
	_refresh_cards(view)
	await get_tree().create_timer(maxf(0.0, length - 0.6)).timeout
	_continue.text = tr("See result") if view["finished"] else tr("Next turn")
	_continue.visible = true
	_continue.grab_focus.call_deferred()


func _on_continue() -> void:
	if _flow.is_finished():
		var st := _flow.state
		match_over.emit({"winner": st.winner, "finish": MatchState.FINISH_NAMES[st.finish], "detail": st.finish_detail,
				"turns": st.turn, "view": st.public_view()})
	else:
		_begin_choice(0)


func _build_handoff() -> void:
	_handoff = ColorRect.new()
	(_handoff as ColorRect).color = UiKit.BG   # fully opaque: nothing of the board shows through
	_handoff.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	_handoff_title = UiKit.label("", 40, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_handoff_title)
	col.add_child(UiKit.label(tr("Your rival's move is locked in and hidden."), 26, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_handoff_button = UiKit.button("", 96)
	_handoff_button.add_theme_font_size_override("font_size", 30)
	_handoff_button.pressed.connect(func() -> void:
		_handoff.visible = false
		_begin_choice(_player))
	col.add_child(_handoff_button)
	_handoff.add_child(col)
	_handoff.visible = false
	# Added to the screen's parent frame on first show so it covers the whole screen.


func _show_handoff(next_player: int) -> void:
	_player = next_player
	_actions_box.visible = false
	if _handoff.get_parent() == null:
		get_parent().add_child(_handoff)
	_handoff_title.text = tr("Pass the phone to %s") % _names[next_player]
	_handoff_button.text = tr("I'm %s - show my moves") % _names[next_player]
	_handoff.visible = true
	_handoff_button.grab_focus.call_deferred()


func _exit_tree() -> void:
	if _handoff != null and _handoff.get_parent() != null and _handoff.get_parent() != self:
		_handoff.queue_free()
