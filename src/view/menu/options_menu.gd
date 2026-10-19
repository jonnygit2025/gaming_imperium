extends MenuScreen
## Opzioni grafiche: preset, renderer, finestra e singole voci; rilevamento automatico e test prestazioni.

const FPS_LIMITS: Array[int] = [30, 60, 75, 90, 120, 144, 0]

## Copia di lavoro: si applica solo con "Applica".
var g: GraphicsSettings = null
var _rows: VBoxContainer = null
var _preset_opt: OptionButton = null
var _soldier_hint: Label = null
var _renderer_hint: Label = null
var _updating: bool = false


func build() -> void:
	g = Settings.graphics.duplicate_settings()
	var root := UiKit.vbox(16)
	content.add_child(root)
	root.add_child(UiKit.title("Opzioni grafiche", 54))
	var cols := UiKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var sc := UiKit.scroll()
	left.add_child(sc)
	_rows = UiKit.vbox(10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_rows)

	var right := UiKit.panel()
	right.custom_minimum_size.x = 500
	cols.add_child(right)
	var rv := UiKit.vbox(12)
	right.add_child(rv)
	rv.add_child(UiKit.heading("Il tuo PC"))
	rv.add_child(UiKit.paragraph("\n".join(Settings.hardware.summary_lines()), UiTheme.SMALL_SIZE))
	var rec: Dictionary = PresetAdvisor.recommend(Settings.hardware)
	rv.add_child(UiKit.paragraph("Consigliato: %s, renderer %s." % [
		GraphicsSettings.PRESET_NAMES[rec["preset"]], _short_renderer(rec["renderer"])], UiTheme.SMALL_SIZE, UiTheme.GOLD))
	rv.add_child(UiKit.button("Rileva automaticamente", _auto_detect, 0.0))
	rv.add_child(HSeparator.new())
	rv.add_child(UiKit.heading("Test prestazioni"))
	rv.add_child(UiKit.paragraph("Due prove: una battaglia con migliaia di soldati (15 s) e un volo sulla mappa di campagna (20 s). Misurano gli FPS con le impostazioni applicate; i risultati vanno nel file benchmark_risultati.txt accanto al gioco.", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	var tests := UiKit.hbox(10)
	var b1 := UiKit.button("Battaglia", _run_benchmark, 0.0)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.tooltip_text = "2.000 soldati in battaglia (preset Alto)"
	var b2 := UiKit.button("Mappa di campagna", _run_map_benchmark, 0.0)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.tooltip_text = "Volo della telecamera sulla mappa di campagna per 20 secondi"
	tests.add_child(b1)
	tests.add_child(b2)
	rv.add_child(tests)
	rv.add_child(UiKit.spacer())
	rv.add_child(UiKit.paragraph("F3 mostra o nasconde il contatore FPS in qualunque momento.", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))

	root.add_child(bottom_bar([UiKit.button("Indietro", on_back, 180.0), UiKit.button("Applica", _apply, 200.0)]))
	_build_rows()


func _build_rows() -> void:
	for c: Node in _rows.get_children():
		c.queue_free()
	_updating = true
	var names := PackedStringArray()
	for p: String in GraphicsSettings.PRESETS:
		names.append(GraphicsSettings.PRESET_NAMES[p])
	names.append("Personalizzato")
	var preset_idx: int = g.preset_index() if g.preset_index() >= 0 else GraphicsSettings.PRESETS.size()
	_rows.add_child(UiKit.heading("Qualità", 22))
	_preset_opt = UiKit.option(names, preset_idx, _on_preset)
	_preset_opt.set_item_disabled(GraphicsSettings.PRESETS.size(), true)
	_row("Preset", _preset_opt)

	_rows.add_child(UiKit.heading("Schermo", 22))
	var r_items := PackedStringArray()
	for r: String in GraphicsSettings.RENDERERS:
		r_items.append(GraphicsSettings.RENDERER_NAMES[r])
	var r_opt := UiKit.option(r_items, GraphicsSettings.RENDERERS.find(g.renderer), func(i: int) -> void:
		g.renderer = GraphicsSettings.RENDERERS[i]
		_update_hints())
	r_opt.custom_minimum_size.x = 440
	_row("Renderer", r_opt)
	_renderer_hint = UiKit.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	_rows.add_child(_renderer_hint)
	_choice("Modalità", GraphicsSettings.WINDOW_MODES, GraphicsSettings.WINDOW_MODE_NAMES, "window_mode")
	var res_items := PackedStringArray()
	var res_idx: int = -1
	for i: int in GraphicsSettings.RESOLUTIONS.size():
		var r: Vector2i = GraphicsSettings.RESOLUTIONS[i]
		res_items.append("%d × %d" % [r.x, r.y])
		if r == g.resolution:
			res_idx = i
	if res_idx < 0:
		res_items.append("%d × %d" % [g.resolution.x, g.resolution.y])
		res_idx = res_items.size() - 1
	_row("Risoluzione (finestra)", UiKit.option(res_items, res_idx, func(i: int) -> void:
		if i < GraphicsSettings.RESOLUTIONS.size():
			g.resolution = GraphicsSettings.RESOLUTIONS[i]))
	_toggle("Sincronia verticale (VSync)", "vsync", false)
	var fps_items := PackedStringArray()
	for f: int in FPS_LIMITS:
		fps_items.append("%d FPS" % f if f > 0 else "Nessun limite")
	var fps_idx: int = maxi(0, FPS_LIMITS.find(g.max_fps))
	_row("Limite FPS", UiKit.option(fps_items, fps_idx, func(i: int) -> void: g.max_fps = FPS_LIMITS[i]))
	_toggle("Mostra FPS (F3)", "show_fps", false)

	_rows.add_child(UiKit.heading("Dettagli", 22))
	_slider("Scala di rendering", "render_scale", 0.5, 1.0, 0.05, "%d%%", 100.0)
	_choice("Antialiasing", GraphicsSettings.AA_MODES, GraphicsSettings.AA_NAMES, "antialiasing", true)
	_choice("Ombre", GraphicsSettings.SHADOW_LEVELS, GraphicsSettings.SHADOW_NAMES, "shadows", true)
	_slider("Distanza visiva", "view_distance", 300.0, 2500.0, 100.0, "%d m", 1.0)
	_slider("Densità dei soldati", "soldier_density", 0.2, 1.0, 0.05, "%d%%", 100.0)
	_soldier_hint = UiKit.label("", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	_rows.add_child(_soldier_hint)
	_slider("Vegetazione", "vegetation_density", 0.0, 1.0, 0.1, "%d%%", 100.0)
	_toggle("Occlusione ambientale (SSAO)", "ssao", true)
	_toggle("Bagliore (glow)", "glow", true)
	_toggle("Nebbia volumetrica", "volumetric_fog", true)
	_updating = false
	_update_hints()


func _row(text: String, control: Control) -> void:
	var h := UiKit.hbox(16)
	var l := UiKit.label(text)
	l.custom_minimum_size.x = 300
	h.add_child(l)
	h.add_child(control)
	_rows.add_child(h)


func _choice(text: String, values: PackedStringArray, names: Dictionary, prop: String, affects_preset: bool = false) -> void:
	var items := PackedStringArray()
	for v: String in values:
		items.append(names[v])
	_row(text, UiKit.option(items, maxi(0, values.find(g.get(prop))), func(i: int) -> void:
		g.set(prop, values[i])
		if affects_preset:
			_on_detail_changed()))


func _toggle(text: String, prop: String, affects_preset: bool) -> void:
	var c := CheckButton.new()
	c.button_pressed = g.get(prop)
	c.toggled.connect(func(on: bool) -> void:
		g.set(prop, on)
		if affects_preset:
			_on_detail_changed())
	_row(text, c)


func _slider(text: String, prop: String, min_v: float, max_v: float, step: float, fmt: String, mult: float) -> void:
	var h := UiKit.hbox(12)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = g.get(prop)
	s.custom_minimum_size = Vector2(300, 32)
	var val := UiKit.label(fmt % roundi(s.value * mult), UiTheme.BODY_SIZE, UiTheme.GOLD)
	val.custom_minimum_size.x = 90
	s.value_changed.connect(func(v: float) -> void:
		g.set(prop, v)
		val.text = fmt % roundi(v * mult)
		_on_detail_changed())
	h.add_child(s)
	h.add_child(val)
	_row(text, h)


func _on_preset(i: int) -> void:
	if _updating or i >= GraphicsSettings.PRESETS.size():
		return
	g.apply_preset(GraphicsSettings.PRESETS[i])
	_build_rows.call_deferred()


func _on_detail_changed() -> void:
	if _updating:
		return
	g.refresh_preset_name()
	var idx: int = g.preset_index()
	_preset_opt.select(idx if idx >= 0 else GraphicsSettings.PRESETS.size())
	_update_hints()


func _update_hints() -> void:
	if _soldier_hint != null:
		_soldier_hint.text = "Circa %d soldati visibili in una grande battaglia (%d per un reggimento da 100 uomini)." % [
			g.target_soldiers(), g.soldiers_for(100)]
	if _renderer_hint != null:
		var cur: String = Settings.current_renderer()
		var notes := PackedStringArray(["In uso ora: %s." % _short_renderer(cur)])
		if g.renderer != cur:
			notes.append("Il cambio richiede un riavvio.")
		if g.renderer == "gl_compatibility" and g.antialiasing in ["fxaa", "taa"]:
			notes.append("Con Compatibilità l'antialiasing %s diventa %s." % [
				GraphicsSettings.AA_NAMES[g.antialiasing].split(" ")[0],
				GraphicsSettings.AA_NAMES[g.effective_antialiasing("gl_compatibility")].to_lower()])
		_renderer_hint.text = " ".join(notes)


func _short_renderer(r: String) -> String:
	match r:
		"forward_plus": return "Forward+"
		"mobile": return "Mobile"
		"gl_compatibility": return "Compatibilità"
	return r


func _apply() -> void:
	var renderer_changed: bool = g.renderer != Settings.graphics.renderer
	Settings.graphics = g.duplicate_settings()
	if renderer_changed:
		Settings.set_renderer(g.renderer)
	Settings.save()
	Settings.apply()
	if Settings.restart_pending:
		show_message("Riavvio necessario", "Il nuovo renderer sarà attivo al prossimo avvio. Vuoi riavviare ora?",
			[{"text": "Più tardi", "action": Callable()}, {"text": "Riavvia ora", "action": Settings.restart_game}])
	else:
		show_message("Impostazioni applicate", "Le impostazioni sono state salvate.")


func _auto_detect() -> void:
	var rec: Dictionary = PresetAdvisor.recommend(Settings.hardware)
	g.apply_preset(rec["preset"])
	g.renderer = rec["renderer"]
	_build_rows()
	show_message("Rilevamento automatico", "Preset consigliato: %s.\nMotivo: %s.\nPremi \"Applica\" per confermare." % [
		GraphicsSettings.PRESET_NAMES[rec["preset"]], rec["reason"]])


func _run_benchmark() -> void:
	if not g.renderer == Settings.graphics.renderer or g.matching_preset() != Settings.graphics.matching_preset():
		show_message("Prima applica", "Il test usa le impostazioni applicate. Premi \"Applica\" e poi avvia il test.")
		return
	goto(Scenes.BENCHMARK)


func _run_map_benchmark() -> void:
	if not g.renderer == Settings.graphics.renderer or g.matching_preset() != Settings.graphics.matching_preset():
		show_message("Prima applica", "Il test usa le impostazioni applicate. Premi \"Applica\" e poi avvia il test.")
		return
	Session.start_map_benchmark()
	goto(Scenes.CAMPAIGN)


func on_back() -> void:
	# Se si è arrivati dal menu di pausa della campagna, si torna alla mappa.
	if Session.return_scene == Scenes.CAMPAIGN and Session.has_game():
		goto(Scenes.CAMPAIGN)
	else:
		goto(Scenes.MAIN_MENU)
