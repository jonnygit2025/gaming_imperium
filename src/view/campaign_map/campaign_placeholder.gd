extends MenuScreen
## Schermata provvisoria della campagna (Fase 1): riepilogo della fazione e salvataggio.
## Nella Fase 2 sarà sostituita dalla mappa 3D.

var _save_name: LineEdit = null


func build() -> void:
	var st: CampaignState = Session.state
	if st == null:
		goto.call_deferred(Scenes.MAIN_MENU)
		return
	var me: FactionState = st.player()
	var root := UiKit.vbox(16)
	content.add_child(root)

	# Barra delle risorse
	var bar := UiKit.panel()
	root.add_child(bar)
	var bh := UiKit.hbox(28)
	bar.add_child(bh)
	bh.add_child(UiKit.swatch(GameData.faction_color(me.id), Vector2(14, 34)))
	var fname := UiKit.title(me.display_name, 28)
	bh.add_child(fname)
	bh.add_child(UiKit.spacer(false))
	for key: String in ["gold", "food", "wood", "iron"]:
		bh.add_child(UiKit.label("%s: %d" % [Defs.RESOURCE_NAMES[key], me.resource(key)], 22, UiTheme.GOLD))
	bh.add_child(UiKit.label(st.date_label(), 22, UiTheme.TEXT))

	var cols := UiKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	var scen: ScenarioDef = GameData.db.scenarios[st.scenario_id]
	lv.add_child(UiKit.heading(scen.name, 28))
	var religion: ReligionDef = GameData.db.religions.get(me.religion)
	lv.add_child(UiKit.label("Sovrano: %s · Religione: %s · Capitale: %s" % [
		me.leader, religion.name if religion else me.religion, GameData.db.provinces[me.capital].city], UiTheme.BODY_SIZE, UiTheme.TEXT_DIM))
	lv.add_child(HSeparator.new())
	var mine: PackedStringArray = st.provinces_of(me.id)
	lv.add_child(UiKit.heading("Le tue province (%d)" % mine.size(), 22))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	for pid: String in mine:
		var p: ProvinceDef = GameData.db.provinces[pid]
		grid.add_child(UiKit.label("%s (%s)" % [p.city, p.name]))
		grid.add_child(UiKit.label("%s · %d mila abitanti" % [Defs.TERRAIN_NAMES[p.terrain], p.population], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	var sc := UiKit.scroll()
	sc.add_child(grid)
	lv.add_child(sc)
	var note := UiKit.paragraph("La mappa di campagna 3D arriva nella Fase 2. Per ora puoi verificare lo scenario e provare il salvataggio.", UiTheme.SMALL_SIZE, UiTheme.BRONZE)
	lv.add_child(note)

	var right := UiKit.panel()
	right.custom_minimum_size.x = 500
	cols.add_child(right)
	var rv := UiKit.vbox(10)
	right.add_child(rv)
	rv.add_child(UiKit.heading("Diplomazia", 22))
	var wars := PackedStringArray()
	var friends := PackedStringArray()
	for fid: String in st.factions:
		if fid == me.id:
			continue
		if st.at_war(me.id, fid):
			wars.append(st.factions[fid].display_name)
		elif st.relation(me.id, fid) > 0:
			friends.append("%s (+%d)" % [st.factions[fid].display_name, st.relation(me.id, fid)])
	rv.add_child(UiKit.paragraph("In guerra con: %s" % (", ".join(wars) if not wars.is_empty() else "nessuno")))
	rv.add_child(UiKit.paragraph("Rapporti buoni: %s" % (", ".join(friends) if not friends.is_empty() else "nessuno")))
	rv.add_child(HSeparator.new())
	rv.add_child(UiKit.heading("Salva la partita", 22))
	_save_name = LineEdit.new()
	_save_name.text = "%s %s" % [me.display_name, st.date_label()]
	_save_name.max_length = 40
	rv.add_child(_save_name)
	rv.add_child(UiKit.button("Salva", _save, 0.0))

	root.add_child(bottom_bar([UiKit.button("Menu principale", on_back, 240.0)]))


func _save() -> void:
	var err: String = Session.save_current(_save_name.text)
	if err.is_empty():
		show_message("Partita salvata", "Salvataggio \"%s\" completato." % _save_name.text)
	else:
		show_message("Errore di salvataggio", err)


func on_back() -> void:
	goto(Scenes.MAIN_MENU)
