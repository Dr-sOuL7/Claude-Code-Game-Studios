class_name UiKit
extends RefCounted
## Shared look for the first-playable screens: palette, theme and small widget factories.
## Display only; no game state lives here.

const BG := Color("#0b0e14")
const PANEL := Color("#151a23")
const PANEL_HI := Color("#1d2430")
const TEXT := Color("#e6eaf2")
const MUTED := Color("#8a93a6")
const ACCENT := Color("#22d3ee")
const DANGER := Color("#f43f5e")
const WARN := Color("#f59e0b")
const GOOD := Color("#22c55e")
const TYPE_COLORS := {"ATTACK": Color("#f43f5e"), "DEFENSE": Color("#3b82f6"), "STAMINA": Color("#22c55e"), "BALANCE": Color("#eab308")}


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_hover_pressed_color", "Button", BG)
	t.set_stylebox("normal", "Button", _box(PANEL_HI, 14, Color("#2a3242"), 2))
	t.set_stylebox("hover", "Button", _box(Color("#253041"), 14, ACCENT.darkened(0.3), 2))
	t.set_stylebox("pressed", "Button", _box(ACCENT, 14, ACCENT, 2))
	t.set_stylebox("hover_pressed", "Button", _box(ACCENT.lightened(0.1), 14, ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(Color("#12161e"), 14, Color("#1f2633"), 2))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 14, Color.WHITE, 3))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 18, Color("#222a38"), 1))
	t.set_stylebox("background", "ProgressBar", _box(Color("#0f131b"), 6, Color("#222a38"), 1))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, 6, Color(0, 0, 0, 0), 0))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func _box(color: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size: int = 0, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


static func button(text: String, min_height: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


static func bar(max_value: float, color: Color, height: int = 16) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", _box(color, 6, Color(0, 0, 0, 0), 0))
	return b


## A solid swatch button for a core (toggle), primary fill and secondary border.
static func swatch(primary: Color, secondary: Color, size: int = 92) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := _box(primary, 18, secondary, 5)
	var pressed := _box(primary, 18, Color.WHITE, 8)
	pressed.shadow_color = ACCENT
	pressed.shadow_size = 10
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	return b


static func type_color(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, TEXT)
