class_name CampaignHud
extends CanvasLayer
## Interfaccia della mappa di campagna: barra delle risorse, pannello della provincia, tooltip,
## minimappa, fine turno, menu di pausa, riepilogo del turno e misure (F3).
## Stile coerente con i menu (UiTheme, UiKit).

const RES_KEYS: PackedStringArray = ["gold", "food", "wood", "iron"]
const RES_COLORS: Dictionary = {
	"gold": Color("e8c25a"), "food": Color("9fbf5a"), "wood": Color("9a6b3e"), "iron": Color("9aa3ad"),
}
const PANEL_WIDTH: float = 400.0
const MINIMAP_WIDTH: float = 330.0

var scene: CampaignMapScene = null
var root: Control = null
var minimap: CampaignMinimap = null

var _faction_swatch: ColorRect = null
var _faction_label: Label = null
var _res_labels: Dictionary = {}
var _date_label: Label = null
var _turn_label: Label = null
var _province_panel: PanelContainer = null
var _province_box: VBoxContainer = null
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null
var _end_turn_btn: Button = null
var _perf_panel: PanelContainer = null
var _perf_label: Label = null
var _perf_stats := FrameStats.new()
var _perf_window: float = 0.0
var _perf_timer: float = 0.0
var _perf_last: String = ""
var _modal: Control = null
var _pause: Control = null


func setup(owner_scene: CampaignMapScene) -> void:
	scene = owner_scene
	layer = 10
	root = Control.new()
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(root))
	_build_top_bar()
	_build_province_panel()
	_build_bottom_right()
	_build_hints()
	_build_tooltip()
	_build_perf_panel()
	refresh()
	Settings.set_fps_overlay_suppressed(true)


func _exit_tree() -> void:
	Settings.set_fps_overlay_suppressed(false)


static func fmt_int(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if neg else "") + s + out


static func fmt_signed(n: int) -> String:
	return ("+" if n >= 0 else "") + fmt_int(n)


func _coin(color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(9)
	sb.border_color = color.darkened(0.45)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(18, 18)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ------------------------------------------------------------------ barra in alto

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.95), UiTheme.BORDER, 1, 0, 10))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 54
	root.add_child(bar)
	var h := UiKit.hbox(22)
	bar.add_child(h)
	_faction_swatch = UiKit.swatch(Color.WHITE, Vector2(12, 32))
	h.add_child(_faction_swatch)
	_faction_label = UiKit.title("", 24)
	h.add_child(_faction_label)
	h.add_child(UiKit.spacer(false))
	for key: String in RES_KEYS:
		var box := UiKit.hbox(7)
		box.add_child(_coin(RES_COLORS[key]))
		var l := UiKit.label("", 21, UiTheme.TEXT)
		l.tooltip_text = Defs.RESOURCE_NAMES[key]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(l)
		_res_labels[key] = l
		h.add_child(box)
	h.add_child(VSeparator.new())
	var dv := UiKit.vbox(0)
	_date_label = UiKit.label("", 20, UiTheme.GOLD)
	_date_label.add_theme_font_override("font", UiTheme.bold_font())
	_turn_label = UiKit.label("", 15, UiTheme.TEXT_DIM)
	dv.add_child(_date_label)
	dv.add_child(_turn_label)
	h.add_child(dv)
	var menu := UiKit.button("Menu", open_pause_menu, 96.0, 19)
	menu.custom_minimum_size.y = 36
	menu.tooltip_text = "Menu di pausa (Esc)"
	h.add_child(menu)


## Aggiorna barra, data e pannello dopo un cambiamento dello stato.
func refresh() -> void:
	var st: CampaignState = scene.state
	var me: FactionState = st.player()
	_faction_swatch.color = GameData.faction_color(me.id)
	_faction_label.text = me.display_name
	var inc: Dictionary = TurnProcessor.estimate_income(st, GameData.db, me.id)
	for key: String in RES_KEYS:
		var l: Label = _res_labels[key]
		l.text = "%s  %s" % [fmt_int(me.resource(key)), fmt_signed(int(inc[key]))]
		l.tooltip_text = "%s: %s (prossimo turno %s)" % [Defs.RESOURCE_NAMES[key], fmt_int(me.resource(key)), fmt_signed(int(inc[key]))]
	_date_label.text = st.date_label()
	_turn_label.text = "Turno %d di %d" % [st.turn, st.last_turn()] if not st.is_finished() else "Turno %d · scenario concluso" % st.turn


# ------------------------------------------------------------------ pannello della provincia

func _build_province_panel() -> void:
	_province_panel = UiKit.panel()
	_province_panel.position = Vector2(14, 68)
	_province_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_province_panel.size = Vector2(PANEL_WIDTH, 0)
	_province_panel.visible = false
	root.add_child(_province_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(PANEL_WIDTH - 36, 0)
	_province_panel.add_child(sc)
	_province_box = UiKit.vbox(8)
	_province_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_province_box)


func show_province(pid: String) -> void:
	if minimap != null:
		minimap.set_selected(scene.map.index_of.get(pid, -1))
	for c: Node in _province_box.get_children():
		c.queue_free()
	if pid.is_empty():
		_province_panel.visible = false
		return
	var db: GameDatabase = GameData.db
	var st: CampaignState = scene.state
	var p: ProvinceDef = db.provinces[pid]
	var owner_id: String = st.province_owner.get(pid, "")
	var fs: FactionState = st.factions.get(owner_id)
	var head := UiKit.hbox(8)
	var tv := UiKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiKit.title(p.city, 30))
	tv.add_child(UiKit.label("Provincia: %s · %s" % [p.name, p.region], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	head.add_child(tv)
	var close := UiKit.button("×", func() -> void: scene.select_province(""), 0.0, 22)
	close.custom_minimum_size = Vector2(38, 38)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Chiudi (clic destro o Esc)"
	head.add_child(close)
	_province_box.add_child(head)

	var orow := UiKit.hbox(10)
	orow.add_child(UiKit.swatch(GameData.faction_color(owner_id), Vector2(16, 22)))
	var oname := UiKit.label(fs.display_name if fs != null else "—", UiTheme.BODY_SIZE, UiTheme.TEXT)
	oname.add_theme_font_override("font", UiTheme.bold_font())
	orow.add_child(oname)
	if owner_id == st.player_faction:
		orow.add_child(UiKit.label("· tua", UiTheme.SMALL_SIZE, UiTheme.OK))
	elif st.at_war(st.player_faction, owner_id):
		orow.add_child(UiKit.label("· in guerra con te", UiTheme.SMALL_SIZE, UiTheme.DANGER))
	if fs != null and fs.capital == pid:
		orow.add_child(UiKit.label("· capitale", UiTheme.SMALL_SIZE, UiTheme.GOLD))
	_province_box.add_child(orow)
	_province_box.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	var res_names := PackedStringArray()
	for r: String in p.resources:
		res_names.append(r.capitalize())
	var inc: Dictionary = TurnProcessor.province_income(p, fs != null and fs.capital == pid, st.season_index())
	var rows: Array = [
		["Terreno", Defs.TERRAIN_NAMES.get(p.terrain, p.terrain) + (" · costiera" if p.coastal else "") + (" · isola" if p.island else "")],
		["Popolazione", "%s abitanti" % fmt_int(p.population * 1000)],
		["Fertilità", "%d su 5 · ricchezza %d su 5" % [p.fertility, p.wealth]],
		["Risorse", ", ".join(res_names)],
		["Rende a turno", "oro %s · cibo %s" % [fmt_signed(int(inc["gold"])), fmt_signed(int(inc["food"]))]],
	]
	for row: Array in rows:
		grid.add_child(UiKit.label(row[0], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
		var v := UiKit.paragraph(row[1], UiTheme.SMALL_SIZE)
		v.custom_minimum_size.x = 230
		grid.add_child(v)
	_province_box.add_child(grid)

	_province_box.add_child(HSeparator.new())
	var armies: Array[ArmyState] = st.armies_in(pid)
	_province_box.add_child(UiKit.heading("Eserciti (%d)" % armies.size(), 20))
	if armies.is_empty():
		_province_box.add_child(UiKit.label("Nessun esercito.", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	for a: ArmyState in armies:
		_province_box.add_child(_army_row(a))

	_province_box.add_child(HSeparator.new())
	_province_box.add_child(UiKit.heading("Confini", 20))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for n: String in p.neighbors:
		var np: ProvinceDef = db.provinces[n]
		var label: String = np.name
		if db.is_strait(pid, n):
			label += " (stretto)"
		var b := UiKit.button(label, func() -> void:
			scene.select_province(n)
			scene.focus_province(n), 0.0, 16)
		b.custom_minimum_size = Vector2(0, 32)
		var nowner: String = st.province_owner.get(n, "")
		b.tooltip_text = "%s — %s" % [np.city, st.factions[nowner].display_name if st.factions.has(nowner) else ""]
		b.add_theme_color_override("font_color", GameData.faction_color(nowner).lightened(0.35))
		flow.add_child(b)
	if p.neighbors.is_empty():
		flow.add_child(UiKit.label("Solo via mare.", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	_province_box.add_child(flow)
	_province_panel.visible = true
	_province_panel.reset_size()
	_fit_province_panel.call_deferred()


func _fit_province_panel() -> void:
	if _province_panel == null or not _province_panel.visible:
		return
	var vp: Vector2 = root.get_viewport_rect().size
	var max_h: float = vp.y - 68.0 - 300.0
	var sc: ScrollContainer = _province_panel.get_child(0)
	var want: float = _province_box.get_combined_minimum_size().y
	sc.custom_minimum_size.y = minf(want, maxf(200.0, max_h))
	_province_panel.reset_size()


func _army_row(a: ArmyState) -> Control:
	var v := UiKit.vbox(2)
	var h := UiKit.hbox(8)
	h.add_child(UiKit.swatch(GameData.faction_color(a.faction), Vector2(10, 18)))
	var gl := UiKit.label(a.general, UiTheme.BODY_SIZE, UiTheme.TEXT)
	gl.add_theme_font_override("font", UiTheme.bold_font())
	h.add_child(gl)
	h.add_child(UiKit.label("%d reggimenti · %s soldati" % [a.unit_count(), fmt_int(a.soldiers())], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	v.add_child(h)
	var counts: Dictionary = {}
	var order := PackedStringArray()
	for u: Dictionary in a.units:
		var t: String = str(u.get("type", ""))
		if not counts.has(t):
			counts[t] = 0
			order.append(t)
		counts[t] = int(counts[t]) + 1
	var parts := PackedStringArray()
	for t: String in order:
		var ud: UnitDef = GameData.db.units.get(t)
		var n: String = ud.name if ud != null else t
		parts.append(("%d× %s" % [counts[t], n]) if int(counts[t]) > 1 else n)
	v.add_child(UiKit.paragraph(", ".join(parts), 15, UiTheme.TEXT_DIM))
	return v


# ------------------------------------------------------------------ minimappa e fine turno

func _build_bottom_right() -> void:
	var box := UiKit.vbox(8)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -14
	box.offset_bottom = -14
	root.add_child(box)
	var frame := UiKit.panel()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.95), UiTheme.BORDER, 1, 3, 5))
	box.add_child(frame)
	minimap = CampaignMinimap.new()
	minimap.setup(scene.map, scene.cam, scene.palette, MINIMAP_WIDTH)
	minimap.point_clicked.connect(scene.focus_point)
	frame.add_child(minimap)
	_end_turn_btn = UiKit.button("Fine turno", scene.end_turn, MINIMAP_WIDTH + 10.0, 26)
	_end_turn_btn.add_theme_font_override("font", UiTheme.title_font())
	_end_turn_btn.custom_minimum_size.y = 56
	_end_turn_btn.tooltip_text = "Termina il turno (Invio)"
	box.add_child(_end_turn_btn)


func _build_hints() -> void:
	var l := UiKit.label("WASD/frecce: muovi · rotella: zoom · Q/E o tasto centrale: ruota · clic: seleziona · doppio clic: centra · Invio: fine turno · F3: misure",
			14, Color(UiTheme.TEXT_DIM, 0.85))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_left = 16
	l.offset_bottom = -10
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)


# ------------------------------------------------------------------ tooltip

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.96), UiTheme.BRONZE, 1, 3, 9))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip_label = UiKit.label("", UiTheme.SMALL_SIZE)
	_tooltip.add_child(_tooltip_label)
	root.add_child(_tooltip)


func update_tooltip(pid: String, mouse: Vector2) -> void:
	if pid.is_empty() or is_modal_open():
		_tooltip.visible = false
		return
	var st: CampaignState = scene.state
	var p: ProvinceDef = GameData.db.provinces[pid]
	var owner_id: String = st.province_owner.get(pid, "")
	var fs: FactionState = st.factions.get(owner_id)
	var lines := PackedStringArray([
		"%s — %s" % [p.city, p.name],
		fs.display_name if fs != null else "",
	])
	var n: int = st.armies_in(pid).size()
	if n > 0:
		lines.append("%d %s" % [n, "esercito" if n == 1 else "eserciti"])
	if owner_id != st.player_faction and st.at_war(st.player_faction, owner_id):
		lines.append("In guerra con te")
	_tooltip_label.text = "\n".join(lines)
	_tooltip.reset_size()
	var vp: Vector2 = root.get_viewport_rect().size
	var pos: Vector2 = mouse + Vector2(18, 20)
	pos.x = minf(pos.x, vp.x - _tooltip.size.x - 8)
	pos.y = minf(pos.y, vp.y - _tooltip.size.y - 8)
	_tooltip.position = pos
	_tooltip.visible = true


func is_pointer_over_ui() -> bool:
	var c: Control = root.get_viewport().gui_get_hovered_control()
	return c != null and c != root


func is_modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal)


# ------------------------------------------------------------------ finestre

func _open_modal(panel_width: float) -> VBoxContainer:
	_close_modal()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(UiKit.fill(overlay))
	var center := CenterContainer.new()
	overlay.add_child(UiKit.fill(center))
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(panel_width, 0)
	center.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	_modal = overlay
	_tooltip.visible = false
	return v


func _close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_pause = null


func show_message(title_text: String, body: String, then: Callable = Callable()) -> void:
	var v := _open_modal(560.0)
	v.add_child(UiKit.heading(title_text, 26))
	v.add_child(UiKit.paragraph(body))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	var ok := UiKit.button("Va bene", func() -> void:
		_close_modal()
		if then.is_valid():
			then.call(), 140.0)
	row.add_child(ok)
	v.add_child(row)
	ok.grab_focus.call_deferred()


func show_turn_report(report: TurnReport) -> void:
	var st: CampaignState = scene.state
	var v := _open_modal(600.0)
	v.add_child(UiKit.title(report.date_label, 34))
	v.add_child(UiKit.label("Inizia il turno %d" % report.to_turn, UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	v.add_child(HSeparator.new())
	var inc: Dictionary = report.income_of(st.player_faction)
	v.add_child(UiKit.heading("Entrate della stagione", 20))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	for key: String in RES_KEYS:
		var cell := UiKit.hbox(8)
		cell.add_child(_coin(RES_COLORS[key]))
		cell.add_child(UiKit.label("%s %s" % [Defs.RESOURCE_NAMES[key], fmt_signed(int(inc.get(key, 0)))], UiTheme.BODY_SIZE))
		grid.add_child(cell)
	v.add_child(grid)
	v.add_child(UiKit.paragraph("Le entrate sono provvisorie: tasse, edifici e mantenimento degli eserciti arrivano nelle prossime fasi.", 15, UiTheme.TEXT_DIM))
	for m: String in report.messages:
		v.add_child(UiKit.paragraph(m, UiTheme.BODY_SIZE, UiTheme.GOLD))
	if Session.autosave_enabled:
		v.add_child(UiKit.label("Partita salvata automaticamente.", 15, UiTheme.TEXT_DIM))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	var ok := UiKit.button("Continua", _close_modal, 180.0)
	row.add_child(ok)
	v.add_child(row)
	ok.grab_focus.call_deferred()


func open_pause_menu() -> void:
	if is_modal_open():
		return
	var v := _open_modal(460.0)
	_pause = _modal
	v.add_child(UiKit.title("Pausa", 40))
	v.add_child(UiKit.label("%s · %s" % [scene.state.player().display_name, scene.state.date_label()], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	v.add_child(HSeparator.new())
	var resume := UiKit.menu_button("Riprendi", _close_modal)
	v.add_child(resume)
	v.add_child(UiKit.menu_button("Salva partita", _open_save))
	v.add_child(UiKit.menu_button("Carica partita", func() -> void: _leave_to(Scenes.LOAD_GAME)))
	v.add_child(UiKit.menu_button("Opzioni", func() -> void: _leave_to(Scenes.OPTIONS)))
	v.add_child(UiKit.menu_button("Menu principale", _confirm_main_menu))
	for c: Node in v.get_children():
		if c is Button:
			(c as Button).custom_minimum_size.x = 0
	resume.grab_focus.call_deferred()


func _open_save() -> void:
	var st: CampaignState = scene.state
	var v := _open_modal(520.0)
	v.add_child(UiKit.heading("Salva la partita", 26))
	var name_edit := LineEdit.new()
	name_edit.text = "%s %s" % [st.player().display_name, st.date_label()]
	name_edit.max_length = 40
	v.add_child(name_edit)
	var do_save := func() -> void:
		var err: String = Session.save_current(name_edit.text)
		if err.is_empty():
			show_message("Partita salvata", "Salvataggio \"%s\" completato." % name_edit.text)
		else:
			show_message("Errore di salvataggio", err)
	name_edit.text_submitted.connect(func(_t: String) -> void: do_save.call())
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	row.add_child(UiKit.button("Annulla", func() -> void:
		_close_modal()
		open_pause_menu(), 140.0))
	row.add_child(UiKit.button("Salva", do_save, 140.0))
	v.add_child(row)
	name_edit.grab_focus.call_deferred()
	name_edit.select_all.call_deferred()


func _leave_to(path: String) -> void:
	Session.return_scene = Scenes.CAMPAIGN
	Scenes.goto(scene.get_tree(), path)


func _confirm_main_menu() -> void:
	var v := _open_modal(560.0)
	v.add_child(UiKit.heading("Tornare al menu principale?", 26))
	v.add_child(UiKit.paragraph("La partita resta aperta: puoi riprenderla con \"Continua la partita\". I progressi dall'ultimo salvataggio automatico sono comunque al sicuro."))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	row.add_child(UiKit.button("Annulla", func() -> void:
		_close_modal()
		open_pause_menu(), 140.0))
	row.add_child(UiKit.button("Menu principale", func() -> void:
		Session.return_scene = ""
		Scenes.goto(scene.get_tree(), Scenes.MAIN_MENU), 220.0))
	v.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if event.is_action_pressed("ui_cancel"):
		if _pause != null and _modal == _pause:
			_close_modal()
		elif _pause == null:
			_close_modal()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ misure (F3)

func _build_perf_panel() -> void:
	_perf_panel = PanelContainer.new()
	_perf_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.04, 0.03, 0.82), UiTheme.BORDER, 1, 3, 10))
	_perf_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_perf_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_perf_panel.offset_right = -14
	_perf_panel.offset_top = 66
	_perf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_label = UiKit.label("", 15, Color(1.0, 0.95, 0.7))
	_perf_panel.add_child(_perf_label)
	root.add_child(_perf_panel)


func _process(delta: float) -> void:
	_perf_panel.visible = Settings.graphics.show_fps
	if not _perf_panel.visible:
		return
	_perf_stats.add(delta)
	_perf_window += delta
	_perf_timer -= delta
	if _perf_window >= 5.0:
		_perf_last = "ultimi 5 s: %.1f FPS medi · %.1f minimi (1%%)" % [_perf_stats.average_fps(), _perf_stats.low_fps()]
		_perf_stats = FrameStats.new()
		_perf_window = 0.0
	if _perf_timer > 0.0:
		return
	_perf_timer = 0.25
	var fps: float = Engine.get_frames_per_second()
	var lines := PackedStringArray([
		"%d FPS · %.1f ms · %s" % [fps, 1000.0 / maxf(fps, 1.0), Settings.current_renderer()],
		_perf_last if not _perf_last.is_empty() else "misura in corso…",
		"chiamate di disegno: %d · triangoli: %s" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			fmt_int(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))],
		"memoria video: %.0f MB (texture %.0f MB)" % [
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0],
		"caricamento della mappa: %.2f s · preset %s" % [scene.load_ms / 1000.0,
			GraphicsSettings.PRESET_NAMES.get(Settings.graphics.preset, Settings.graphics.preset)],
	])
	_perf_label.text = "\n".join(lines)
