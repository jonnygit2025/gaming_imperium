extends MenuScreen
## Elenco dei salvataggi: carica o elimina.

var _list: ItemList = null
var _saves: Array[Dictionary] = []
var _info: Label = null
var _load_btn: Button = null
var _delete_btn: Button = null


func build() -> void:
	var root := UiKit.vbox(18)
	content.add_child(root)
	root.add_child(UiKit.title("Carica partita", 54))
	var cols := UiKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 22)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(func(_i: int) -> void: _load_selected())
	cols.add_child(_list)
	var side := UiKit.panel()
	side.custom_minimum_size.x = 480
	cols.add_child(side)
	var sv := UiKit.vbox(10)
	side.add_child(sv)
	sv.add_child(UiKit.heading("Dettagli"))
	_info = UiKit.paragraph("")
	sv.add_child(_info)
	_load_btn = UiKit.button("Carica", _load_selected, 180.0)
	_delete_btn = UiKit.button("Elimina", _ask_delete, 160.0)
	root.add_child(bottom_bar([UiKit.button("Indietro", on_back, 180.0), _delete_btn, _load_btn]))
	_refresh()


func _refresh() -> void:
	_saves = Session.list_saves()
	_list.clear()
	for s: Dictionary in _saves:
		var text: String = "%s — %s, %s" % [s.get("name", "?"), s.get("faction_name", "?"), s.get("date_label", "?")]
		if not s.get("valid", false):
			text = "%s — salvataggio danneggiato" % s.get("name", "?")
		_list.add_item(text)
	var empty: bool = _saves.is_empty()
	_load_btn.disabled = true
	_delete_btn.disabled = true
	_info.text = "Nessun salvataggio. Inizia una nuova partita e salvala dalla campagna." if empty else "Seleziona un salvataggio."
	if not empty:
		_list.select(0)
		_on_selected(0)
		focus_later(_list)


func _on_selected(i: int) -> void:
	var s: Dictionary = _saves[i]
	_load_btn.disabled = not s.get("valid", false)
	_delete_btn.disabled = false
	if not s.get("valid", false):
		_info.text = "Questo file non si può leggere. Puoi eliminarlo."
		return
	_info.text = "Nome: %s\nScenario: %s\nFazione: %s\nData in gioco: %s (turno %d)\nSalvato il: %s" % [
		s.get("name", ""), s.get("scenario_name", ""), s.get("faction_name", ""),
		s.get("date_label", ""), int(s.get("turn", 1)), str(s.get("saved_at", "")).replace("T", " ")]


func _selected() -> Dictionary:
	var sel: PackedInt32Array = _list.get_selected_items()
	return _saves[sel[0]] if not sel.is_empty() else {}


func _load_selected() -> void:
	var s: Dictionary = _selected()
	if s.is_empty() or not s.get("valid", false):
		return
	var err: String = Session.load_from(s["path"])
	if not err.is_empty():
		show_message("Impossibile caricare", err)
		return
	goto(Scenes.CAMPAIGN)


func _ask_delete() -> void:
	var s: Dictionary = _selected()
	if s.is_empty():
		return
	show_message("Eliminare il salvataggio?", "\"%s\" verrà cancellato definitivamente." % s.get("name", ""),
		[{"text": "Annulla", "action": Callable()},
		 {"text": "Elimina", "action": func() -> void:
			SaveSystem.delete_save(s["path"])
			_refresh()}])


func on_back() -> void:
	# Se si è arrivati dal menu di pausa della campagna, si torna alla mappa.
	if Session.return_scene == Scenes.CAMPAIGN and Session.has_game():
		goto(Scenes.CAMPAIGN)
	else:
		goto(Scenes.MAIN_MENU)
