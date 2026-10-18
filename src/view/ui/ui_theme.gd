class_name UiTheme
extends RefCounted
## Stile grafico unico per tutte le schermate: bronzo, porpora e pergamena scura.

const BG: Color = Color("14110e")
const PANEL: Color = Color("1f1a15")
const PANEL_LIGHT: Color = Color("2a231c")
const BORDER: Color = Color("8a6d43")
const BRONZE: Color = Color("c9a45c")
const GOLD: Color = Color("e8c77a")
const TEXT: Color = Color("eadfc6")
const TEXT_DIM: Color = Color("a89a7e")
const PURPLE: Color = Color("6e1f2b")
const PURPLE_LIGHT: Color = Color("8c2b3a")
const DANGER: Color = Color("c0533f")
const OK: Color = Color("8fb36a")

const BODY_SIZE: int = 20
const SMALL_SIZE: int = 17

static var _theme: Theme = null
static var _title_font: Font = null
static var _body_font: Font = null
static var _bold_font: Font = null


static func title_font() -> Font:
	if _title_font == null:
		var base: FontFile = load("res://assets/fonts/Cinzel-Variable.ttf")
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		_title_font = v
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://assets/fonts/AlegreyaSans-Regular.ttf")
	return _body_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	return _bold_font


static func box(bg: Color, border: Color, border_width: int = 1, radius: int = 3, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = BODY_SIZE

	for type: String in ["Label", "RichTextLabel", "CheckBox", "CheckButton", "LineEdit", "OptionButton", "Button", "ItemList"]:
		t.set_color("font_color", type, TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", bold_font())

	# Pulsanti
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, BORDER, 1, 3, 16))
	t.set_stylebox("hover", "Button", box(Color("3a2e22"), BRONZE, 1, 3, 16))
	t.set_stylebox("pressed", "Button", box(PURPLE, GOLD, 1, 3, 16))
	t.set_stylebox("hover_pressed", "Button", box(PURPLE_LIGHT, GOLD, 1, 3, 16))
	t.set_stylebox("disabled", "Button", box(Color("1a1612"), Color("4a3d2c"), 1, 3, 16))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 1, 3, 16))
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("6f6553"))
	t.set_color("font_focus_color", "Button", GOLD)

	# Menu a tendina
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, BRONZE, 1, 3, 6))
	t.set_stylebox("hover", "PopupMenu", box(PURPLE, PURPLE, 0, 2, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)

	# Pannelli
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.94), BORDER, 1, 4, 18))
	t.set_stylebox("panel", "Panel", box(Color(PANEL, 0.94), BORDER, 1, 4, 18))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, BRONZE, 1, 3, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)

	# Campi di testo
	t.set_stylebox("normal", "LineEdit", box(Color("0f0d0a"), BORDER, 1, 3, 10))
	t.set_stylebox("focus", "LineEdit", box(Color("0f0d0a"), GOLD, 1, 3, 10))
	t.set_color("caret_color", "LineEdit", GOLD)

	# Cursori e barre
	t.set_stylebox("slider", "HSlider", box(Color("0f0d0a"), BORDER, 1, 3, 3))
	t.set_stylebox("grabber_area", "HSlider", box(PURPLE, PURPLE, 0, 3, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(PURPLE_LIGHT, PURPLE_LIGHT, 0, 3, 3))
	t.set_stylebox("scroll", "VScrollBar", box(Color("120f0c"), Color("120f0c"), 0, 3, 4))
	t.set_stylebox("grabber", "VScrollBar", box(BORDER, BORDER, 0, 3, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(BRONZE, BRONZE, 0, 3, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, GOLD, 0, 3, 4))

	# Elenchi
	t.set_stylebox("panel", "ItemList", box(Color("120f0c"), BORDER, 1, 3, 6))
	t.set_stylebox("selected", "ItemList", box(PURPLE, PURPLE, 0, 2, 6))
	t.set_stylebox("selected_focus", "ItemList", box(PURPLE_LIGHT, GOLD, 1, 2, 6))
	t.set_stylebox("hovered", "ItemList", box(Color("2a231c"), Color("2a231c"), 0, 2, 6))
	t.set_color("font_selected_color", "ItemList", GOLD)

	# Separatori
	var sep := StyleBoxLine.new()
	sep.color = Color(BORDER, 0.6)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)

	_theme = t
	return _theme
