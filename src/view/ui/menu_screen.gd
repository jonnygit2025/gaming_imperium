class_name MenuScreen
extends Control
## Base comune delle schermate dei menu: tema, sfondo animato, tasto Esc.

var content: Control = null


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/menu_background.gdshader")
	bg.material = mat
	add_child(UiKit.fill(bg))
	var m := UiKit.margin(48)
	add_child(UiKit.fill(m))
	content = m
	build()


## Da implementare: costruisce i controlli dentro `content`.
func build() -> void:
	pass


## Da implementare: cosa fare con Esc (di solito tornare indietro).
func on_back() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		on_back()


## Dà il fuoco a un controllo dopo la costruzione, solo se la schermata è ancora attiva.
func focus_later(c: Control) -> void:
	(func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()).call_deferred()


func goto(path: String) -> void:
	Scenes.goto(get_tree(), path)


## Barra in basso con pulsanti allineati a destra.
func bottom_bar(buttons: Array[Button]) -> HBoxContainer:
	var bar := UiKit.hbox(14)
	bar.add_child(UiKit.spacer(false))
	for b: Button in buttons:
		bar.add_child(b)
	return bar


## Finestra di messaggio semplice (sostituisce i dialoghi di sistema).
func show_message(title_text: String, body: String, buttons: Array[Dictionary] = []) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	add_child(UiKit.fill(overlay))
	var center := CenterContainer.new()
	overlay.add_child(UiKit.fill(center))
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var v := UiKit.vbox(16)
	p.add_child(v)
	v.add_child(UiKit.heading(title_text, 28))
	v.add_child(UiKit.paragraph(body))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	if buttons.is_empty():
		buttons = [{"text": "Chiudi", "action": Callable()}]
	for spec: Dictionary in buttons:
		var action: Callable = spec.get("action", Callable())
		var b := UiKit.button(spec["text"], func() -> void:
			overlay.queue_free()
			if action.is_valid():
				action.call(), 140.0)
		row.add_child(b)
	v.add_child(row)
	return overlay
