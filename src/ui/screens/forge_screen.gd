class_name ForgeScreen
extends VBoxContainer
## The Forge: one player picks Core (cosmetic), Blade, Disc and Tip and sees the derived
## stats and emergent type live. Emits `confirmed` with the chosen ids.

signal confirmed(build: Dictionary)
signal back_pressed

const STAT_MAX := 85.0
const STAT_ROWS := [
	["AP", "Attack Power", "ap"], ["LI", "Lock Integrity", "li"],
	["MS", "Mass", "ms"], ["ST", "Stability", "st"],
	["MB", "Mobility", "mb"], ["SM", "Stamina", "sm"],
]

var _title: String
var _cat: PartsCatalogue
var _params: CombatParams
var _build := {"core": "aetherion", "blade": "B01", "disc": "D01", "tip": "T01"}
var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _type_label: Label
var _identity_label: Label
var _core_label: Label
var _part_labels: Dictionary = {}
var _buttons: Dictionary = {}


func setup(title: String, cat: PartsCatalogue, params: CombatParams, start_build: Dictionary) -> void:
	_title = title
	_cat = cat
	_params = params
	_build = start_build.duplicate()


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	var back := UiKit.button(tr("Back"), 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(120, 64)
	back.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back)
	var t := UiKit.label(_title, 32, UiKit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(t)
	add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)

	body.add_child(_section(tr("CORE - looks only, no stats"), _core_grid()))
	_core_label = UiKit.label("", 22, UiKit.MUTED)
	body.add_child(_core_label)
	body.add_child(_section(tr("BLADE - Attack Power / Lock Integrity"), _part_grid("blade", _cat.blades, "ap", "li")))
	body.add_child(_section(tr("DISC - Mass / Stability"), _part_grid("disc", _cat.discs, "ms", "st")))
	body.add_child(_section(tr("TIP - Mobility / Stamina"), _part_grid("tip", _cat.tips, "mb", "sm")))

	var stats_panel := UiKit.panel()
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	_type_label = UiKit.label("", 28, UiKit.TEXT)
	_type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_type_label)
	_identity_label = UiKit.label("", 19, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_identity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_identity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_identity_label)
	stats.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 2)
	for row in STAT_ROWS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		var v := UiKit.label("", 19, UiKit.MUTED)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		cell.add_child(v)
		var b := UiKit.bar(STAT_MAX, UiKit.ACCENT, 12)
		cell.add_child(b)
		_stat_bars[row[2]] = b
		_stat_values[row[2]] = v
		grid.add_child(cell)
	stats.add_child(grid)
	stats_panel.add_child(stats)
	add_child(stats_panel)

	var row_btns := HBoxContainer.new()
	var rnd := UiKit.button(tr("Random"), 84)
	rnd.pressed.connect(_randomize)
	row_btns.add_child(rnd)
	var ok := UiKit.button(tr("Ready!"), 84)
	ok.add_theme_font_size_override("font_size", 32)
	ok.pressed.connect(func() -> void: confirmed.emit(_build.duplicate()))
	row_btns.add_child(ok)
	add_child(row_btns)
	_refresh()
	ok.grab_focus.call_deferred()


func _section(title: String, content: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.label(title, 22, UiKit.MUTED))
	box.add_child(content)
	return box


func _core_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	var group := ButtonGroup.new()
	_buttons["core"] = {}
	for id in _cat.core_ids():
		var c: Dictionary = _cat.cores[id]
		var b := UiKit.swatch(Color(c["primary"]), Color(c["secondary"]), 84)
		b.button_group = group
		b.tooltip_text = c["name"]
		b.pressed.connect(_pick.bind("core", id))
		_buttons["core"][id] = b
		g.add_child(b)
	return g


func _part_grid(kind: String, parts: Dictionary, a: String, b: String) -> VBoxContainer:
	var g := GridContainer.new()
	g.columns = 4
	var group := ButtonGroup.new()
	_buttons[kind] = {}
	var ids: Array = parts.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = parts[id]
		var btn := UiKit.button("%s\n%d / %d" % [id, int(p[a]), int(p[b])], 84)
		btn.toggle_mode = true
		btn.button_group = group
		btn.add_theme_font_size_override("font_size", 22)
		btn.tooltip_text = p.get("label", "")
		btn.pressed.connect(_pick.bind(kind, id))
		_buttons[kind][id] = btn
		g.add_child(btn)
	var lbl := UiKit.label("", 20, UiKit.MUTED)
	_part_labels[kind] = lbl
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(g)
	wrap.add_child(lbl)
	return wrap


func _pick(kind: String, id: String) -> void:
	_build[kind] = id
	_refresh()


func _randomize() -> void:
	_build = {
		"core": _cat.core_ids().pick_random(), "blade": _cat.blade_ids().pick_random(),
		"disc": _cat.disc_ids().pick_random(), "tip": _cat.tip_ids().pick_random(),
	}
	_refresh()


func _refresh() -> void:
	for kind in ["core", "blade", "disc", "tip"]:
		var btn: Button = _buttons[kind][_build[kind]]
		btn.set_pressed_no_signal(true)
	var s := BuildStats.from_catalogue(_cat, _build["blade"], _build["disc"], _build["tip"], _params.type_margin, _params.identity_ratio)
	for key in _stat_bars:
		var v: int = s.get(key)
		(_stat_bars[key] as ProgressBar).value = v
		var row: Array = STAT_ROWS.filter(func(r: Array) -> bool: return r[2] == key)[0]
		(_stat_values[key] as Label).text = "%s %s  %d" % [row[0], tr(row[1]), v]
	var tname := s.type_name()
	_type_label.text = tr("Type: %s") % tname
	_type_label.add_theme_color_override("font_color", UiKit.type_color(tname))
	var dom := "-" if s.domain == BuildStats.Domain.NONE else String(BuildStats.Type.keys()[s.domain])
	_identity_label.text = tr("Bonus: %s  |  Total %d") % [dom, s.total()]
	var core: Dictionary = _cat.cores[_build["core"]]
	_core_label.text = tr("Core: %s (%s)") % [core["name"], core["theme"]]
	for kind in ["blade", "disc", "tip"]:
		var parts: Dictionary = {"blade": _cat.blades, "disc": _cat.discs, "tip": _cat.tips}[kind]
		if _part_labels.has(kind):
			(_part_labels[kind] as Label).text = "%s: %s" % [_build[kind], parts[_build[kind]].get("label", "")]
