extends MenuScreen
## Scelta dello scenario e della fazione.

var _scenarios: Array[ScenarioDef] = []
var _scenario: ScenarioDef = null
var _faction_id: String = ""
var _scenario_buttons: Array[Button] = []
var _faction_box: VBoxContainer = null
var _desc_title: Label = null
var _desc_text: Label = null
var _desc_info: Label = null
var _detail: Label = null
var _start: Button = null
var _group_scen := ButtonGroup.new()
var _group_fac := ButtonGroup.new()


func build() -> void:
	_scenarios = GameData.db.scenarios_sorted()
	var root := UiKit.vbox(18)
	content.add_child(root)
	root.add_child(UiKit.title("Nuova partita", 54))

	var cols := UiKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Scenari
	var left := UiKit.panel()
	left.custom_minimum_size.x = 400
	cols.add_child(left)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	lv.add_child(UiKit.heading("Scenario"))
	for s: ScenarioDef in _scenarios:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group_scen
		b.text = s.name
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(_select_scenario.bind(s))
		lv.add_child(b)
		_scenario_buttons.append(b)

	# Descrizione e fazioni
	var mid := UiKit.panel()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var mv := UiKit.vbox(12)
	mid.add_child(mv)
	_desc_title = UiKit.heading("", 30)
	mv.add_child(_desc_title)
	_desc_info = UiKit.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	mv.add_child(_desc_info)
	_desc_text = UiKit.paragraph("")
	mv.add_child(_desc_text)
	mv.add_child(HSeparator.new())
	mv.add_child(UiKit.heading("Scegli la tua fazione", 22))
	var sc := UiKit.scroll()
	mv.add_child(sc)
	_faction_box = UiKit.vbox(8)
	_faction_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_faction_box)

	# Dettaglio fazione
	var right := UiKit.panel()
	right.custom_minimum_size.x = 430
	cols.add_child(right)
	var rv := UiKit.vbox(10)
	right.add_child(rv)
	rv.add_child(UiKit.heading("Obiettivi"))
	_detail = UiKit.paragraph("Seleziona una fazione.")
	rv.add_child(_detail)

	_start = UiKit.button("Inizia la campagna", _start_game, 260.0)
	_start.disabled = true
	root.add_child(bottom_bar([UiKit.button("Indietro", on_back, 180.0), _start]))

	if not _scenarios.is_empty():
		_scenario_buttons[0].button_pressed = true
		_select_scenario(_scenarios[0])
		focus_later(_scenario_buttons[0])


func _select_scenario(s: ScenarioDef) -> void:
	_scenario = s
	_faction_id = ""
	_start.disabled = true
	_desc_title.text = s.name
	_desc_info.text = "Dal %s %d al %d · %d turni (estate e inverno)" % [
		Defs.SEASON_NAMES[s.season].to_lower(), s.year, s.end_year, s.total_turns()]
	_desc_text.text = s.description
	_detail.text = "Seleziona una fazione."
	for c: Node in _faction_box.get_children():
		c.queue_free()
	for fid: String in s.playable:
		_faction_box.add_child(_faction_row(s, fid))


func _faction_row(s: ScenarioDef, fid: String) -> Button:
	var sf: ScenarioFactionDef = s.factions[fid]
	var fdef: FactionDef = GameData.db.factions[fid]
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group_fac
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UiKit.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(UiKit.fill(h))
	var m := UiKit.margin(10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(m)
	var sw := UiKit.swatch(fdef.color, Vector2(26, 40))
	m.add_child(sw)
	var v := UiKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var display: String = sf.name_override if not sf.name_override.is_empty() else fdef.name
	var name_l := UiKit.label(display, 22, UiTheme.TEXT)
	name_l.add_theme_font_override("font", UiTheme.bold_font())
	v.add_child(name_l)
	var culture: CultureDef = GameData.db.cultures.get(fdef.culture)
	v.add_child(UiKit.label("%s · cultura %s · %d province · difficoltà %s" % [
		sf.leader, culture.name.to_lower() if culture else "", sf.provinces.size(),
		Defs.DIFFICULTIES.get(sf.difficulty, sf.difficulty).to_lower()], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	for c: Node in [name_l, sw]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_select_faction.bind(fid))
	return b


func _select_faction(fid: String) -> void:
	_faction_id = fid
	_start.disabled = false
	var sf: ScenarioFactionDef = _scenario.factions[fid]
	var fdef: FactionDef = GameData.db.factions[fid]
	var religion_id: String = sf.religion_override if not sf.religion_override.is_empty() else fdef.religion
	var religion: ReligionDef = GameData.db.religions.get(religion_id)
	var lines := PackedStringArray()
	lines.append(fdef.description)
	lines.append("")
	lines.append("Sovrano: %s" % sf.leader)
	lines.append("Religione: %s" % (religion.name if religion else religion_id))
	lines.append("Capitale: %s" % GameData.db.provinces[sf.capital].city)
	lines.append("Oro iniziale: %d" % int(sf.resources.get("gold", 0)))
	var enemies := PackedStringArray()
	for pair: PackedStringArray in _scenario.wars:
		if fid in pair:
			var other: String = pair[1] if pair[0] == fid else pair[0]
			enemies.append(GameData.faction_name(other))
	lines.append("In guerra con: %s" % (", ".join(enemies) if not enemies.is_empty() else "nessuno"))
	lines.append("")
	lines.append("Vittoria: %s" % sf.victory_description)
	if not sf.victory_provinces.is_empty():
		var cities := PackedStringArray()
		for pid: String in sf.victory_provinces:
			cities.append(GameData.db.provinces[pid].city)
		lines.append("Città da possedere: %s" % ", ".join(cities))
	_detail.text = "\n".join(lines)


func _start_game() -> void:
	if _scenario == null or _faction_id.is_empty():
		return
	var err: String = Session.start_new_game(_scenario.id, _faction_id)
	if not err.is_empty():
		show_message("Impossibile iniziare", err)
		return
	goto(Scenes.CAMPAIGN)


func on_back() -> void:
	goto(Scenes.MAIN_MENU)
