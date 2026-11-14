class_name TitleScreen
extends VBoxContainer
## First screen: mode choice and a short rules card.

signal mode_chosen(vs_cpu: bool)

const RULES := [
	"Build your top from a Blade, a Disc and a Tip. Every part trades one strength for another - every top has exactly the same total power (280).",
	"Each turn both players secretly pick a move, then both are revealed at once.",
	"ATTACK hits hard. DEFEND blocks part of a hit and throws the attacker back. DODGE makes a clash less likely and softens it. CHARGE fills your Special meter. SPECIAL is a huge hit once your meter reaches 50.",
	"Win by BURST (your opponent breaks apart), RING-OUT (they are pushed off the arena) or SPIN FINISH (they run out of energy).",
]

var _rules_panel: PanelContainer


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 22)
	add_child(UiKit.label("SPINFORGE", 76, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UiKit.label(tr("Forge a top. Read your rival. Win the clash."), 28, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UiKit.label(tr("First playable prototype - 2D arena"), 22, Color(UiKit.MUTED, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	add_child(spacer)
	var cpu := UiKit.button(tr("Play vs CPU"), 96)
	cpu.add_theme_font_size_override("font_size", 32)
	cpu.pressed.connect(func() -> void: mode_chosen.emit(true))
	add_child(cpu)
	var duo := UiKit.button(tr("2 Players - pass the phone"), 96)
	duo.add_theme_font_size_override("font_size", 32)
	duo.pressed.connect(func() -> void: mode_chosen.emit(false))
	add_child(duo)
	var how := UiKit.button(tr("How to play"), 72)
	how.pressed.connect(func() -> void: _rules_panel.visible = not _rules_panel.visible)
	add_child(how)
	_rules_panel = UiKit.panel()
	var col := VBoxContainer.new()
	for line in RULES:
		col.add_child(UiKit.label(tr(line), 24))
	_rules_panel.add_child(col)
	_rules_panel.visible = false
	add_child(_rules_panel)
	cpu.grab_focus.call_deferred()
