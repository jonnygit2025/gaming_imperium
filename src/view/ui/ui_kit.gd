class_name UiKit
extends RefCounted
## Piccoli costruttori di controlli, per scrivere le schermate in modo compatto.


static func title(text: String, size: int = 56, color: Color = UiTheme.GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size: int = 26) -> Label:
	return title(text, size, UiTheme.BRONZE)


static func label(text: String, size: int = UiTheme.BODY_SIZE, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func paragraph(text: String, size: int = UiTheme.BODY_SIZE, color: Color = UiTheme.TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


static func button(text: String, on_pressed: Callable, min_width: float = 0.0, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_width, 48)
	b.pressed.connect(on_pressed)
	return b


static func menu_button(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed, 380.0, 26)
	b.add_theme_font_override("font", UiTheme.title_font())
	b.custom_minimum_size.y = 58
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


static func vbox(separation: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	return m


static func swatch(color: Color, size: Vector2 = Vector2(18, 18)) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = size
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


static func option(items: PackedStringArray, selected: int, on_selected: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.select(selected)
	o.custom_minimum_size = Vector2(300, 42)
	o.item_selected.connect(on_selected)
	return o


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func fill(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
