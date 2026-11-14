class_name ResultScreen
extends VBoxContainer
## End of match: who won, how, and the way back in.

signal rematch_pressed
signal change_tops_pressed
signal menu_pressed

var _summary: Dictionary
var _names: Array[String] = []
var _colors: Array = []


func setup(summary: Dictionary, names: Array[String], colors: Array) -> void:
	_summary = summary
	_names = names
	_colors = colors


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 20)
	var w: int = _summary["winner"]
	var headline := tr("DRAW") if w < 0 else (tr("YOU WIN!") if _names[w] == tr("You") else (tr("CPU WINS") if _names[w] == tr("CPU") else tr("%s WINS") % _names[w].to_upper()))
	var col: Color = UiKit.TEXT if w < 0 else (_colors[w] as Array)[0]
	add_child(UiKit.label(headline, 64, col, HORIZONTAL_ALIGNMENT_CENTER))
	var how := {"burst": tr("by BURST FINISH"), "ringout": tr("by RING-OUT"), "spin": tr("by SPIN FINISH"), "draw": tr("both tops fell at once")}
	var sub: String = how.get(_summary["finish"], "")
	if _summary["detail"] == "tiebreak":
		sub += tr(" - both fell, more stability left")
	add_child(UiKit.label(sub, 32, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UiKit.label(tr("after %d turns") % _summary["turns"], 26, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var p := UiKit.panel()
	var stats := VBoxContainer.new()
	var view: Dictionary = _summary["view"]
	for i in range(2):
		var pv: Dictionary = view["players"][i]
		stats.add_child(UiKit.label("%s (%s): %s %d   %s %d   %s %d" % [
				_names[i], pv["type"], tr("energy"), roundi(maxf(0.0, pv["energy"])), tr("stability"), roundi(pv["stability"]),
				tr("edge"), roundi(pv["position_pressure"])], 22, UiKit.TEXT))
	p.add_child(stats)
	add_child(p)
	var again := UiKit.button(tr("Rematch - same tops"), 92)
	again.add_theme_font_size_override("font_size", 30)
	again.pressed.connect(func() -> void: rematch_pressed.emit())
	add_child(again)
	var change := UiKit.button(tr("Change tops"), 80)
	change.pressed.connect(func() -> void: change_tops_pressed.emit())
	add_child(change)
	var menu := UiKit.button(tr("Main menu"), 72)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(menu)
	again.grab_focus.call_deferred()
