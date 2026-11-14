extends Control
## SPINFORGE first-playable shell: theme, centred frame and screen flow
## Title -> Forge (P1) -> Forge (P2) or CPU pick -> Battle -> Result.
## Holds only session choices (mode, chosen part ids); every rule lives in
## src/core/ and every match in a MatchFlow.

const RULESET_VERSION := "v1"
const CPU_VERSION := "v1"
const MAX_FRAME_WIDTH := 760.0
const MARGIN := 24.0

var _params: CombatParams
var _cat: PartsCatalogue
var _frame: Control
var _screen: Control
var _vs_cpu := true
var _builds: Array[Dictionary] = [{}, {}]


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_frame = Control.new()
	add_child(_frame)
	resized.connect(_layout)
	_params = CombatParams.load_version(RULESET_VERSION)
	_cat = PartsCatalogue.load_default()
	if _params == null or _cat == null:
		_show(UiKit.label(tr("Could not load game data."), 32, UiKit.DANGER))
		return
	_layout()
	_show_title()


func _layout() -> void:
	var w := minf(size.x - 2.0 * MARGIN, MAX_FRAME_WIDTH)
	_frame.position = Vector2((size.x - w) / 2.0, MARGIN)
	_frame.size = Vector2(w, size.y - 2.0 * MARGIN)


func _show(screen: Control) -> void:
	_set_web_title(screen)
	for child in _frame.get_children():
		child.queue_free()
	_screen = screen
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(screen)


func _show_title() -> void:
	var t := TitleScreen.new()
	t.mode_chosen.connect(_on_mode)
	_show(t)


func _on_mode(vs_cpu: bool) -> void:
	_vs_cpu = vs_cpu
	_builds = [_random_build(), _random_build()]
	_show_forge(0)


func _names() -> Array[String]:
	if _vs_cpu:
		return [tr("You"), tr("CPU")]
	return [tr("Player 1"), tr("Player 2")]


func _show_forge(player: int) -> void:
	var f := ForgeScreen.new()
	var title := tr("Forge your top") if _vs_cpu else tr("%s - forge your top") % _names()[player]
	f.setup(title, _cat, _params, _builds[player])
	f.confirmed.connect(_on_forged.bind(player))
	f.back_pressed.connect(func() -> void:
		if player == 0:
			_show_title()
		else:
			_show_forge(0))
	_show(f)


func _on_forged(build: Dictionary, player: int) -> void:
	_builds[player] = build
	if player == 0 and not _vs_cpu:
		_show_forge(1)
		return
	if _vs_cpu:
		_builds[1] = _random_build()
	_start_battle()


func _random_build() -> Dictionary:
	return {"core": _cat.core_ids().pick_random(), "blade": _cat.blade_ids().pick_random(),
			"disc": _cat.disc_ids().pick_random(), "tip": _cat.tip_ids().pick_random()}


func _stats(b: Dictionary) -> BuildStats:
	return BuildStats.from_catalogue(_cat, b["blade"], b["disc"], b["tip"], _params.type_margin, _params.identity_ratio)


func _colors(b: Dictionary) -> Array[Color]:
	var c: Dictionary = _cat.cores[b["core"]]
	return [Color(c["primary"]), Color(c["secondary"])]


func _start_battle() -> void:
	var flow := MatchFlow.new()
	var cpu: CpuPolicy = CpuPolicy.load_version(CPU_VERSION, Prng.new(randi())) if _vs_cpu else null
	var a := _stats(_builds[0])
	var b := _stats(_builds[1])
	flow.start(_params, a, b, randi(), cpu, 1 if _vs_cpu else -1)
	var screen := BattleScreen.new()
	var types: Array[String] = [a.type_name(), b.type_name()]
	screen.setup(flow, _vs_cpu, _names(), [_colors(_builds[0]), _colors(_builds[1])], types)
	screen.match_over.connect(_on_match_over)
	screen.quit_pressed.connect(_show_title)
	_show(screen)


func _on_match_over(summary: Dictionary) -> void:
	var r := ResultScreen.new()
	r.setup(summary, _names(), [_colors(_builds[0]), _colors(_builds[1])])
	r.rematch_pressed.connect(_start_battle)
	r.change_tops_pressed.connect(func() -> void: _show_forge(0))
	r.menu_pressed.connect(_show_title)
	_show(r)


## On the Web export the tab title names the screen ("SPINFORGE - Battle"); browser
## smoke tests read it to know where they are. No effect on other platforms.
func _set_web_title(screen: Control) -> void:
	if not OS.has_feature("web"):
		return
	var name := "Menu"
	if screen is ForgeScreen:
		name = "Forge"
	elif screen is BattleScreen:
		name = "Battle"
	elif screen is ResultScreen:
		name = "Result"
	JavaScriptBridge.eval("document.title = 'SPINFORGE - %s'" % name)
