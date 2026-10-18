extends MenuScreen
## Menu principale: Nuova partita, Carica, Opzioni, Esci.


func build() -> void:
	var row := UiKit.hbox(60)
	content.add_child(row)

	# Colonna sinistra: titolo e pulsanti
	var left := UiKit.vbox(10)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UiKit.spacer())
	left.add_child(UiKit.title("REGNA", 128))
	var sub := UiKit.title("L'Ombra di Roma · 476–732 d.C.", 30, UiTheme.BRONZE)
	left.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	left.add_child(gap)
	var resume := UiKit.menu_button("Continua la partita", func() -> void: goto(Scenes.CAMPAIGN))
	resume.visible = Session.has_game()
	left.add_child(resume)
	var first := UiKit.menu_button("Nuova partita", func() -> void: goto(Scenes.NEW_GAME))
	left.add_child(first)
	left.add_child(UiKit.menu_button("Carica partita", func() -> void: goto(Scenes.LOAD_GAME)))
	left.add_child(UiKit.menu_button("Opzioni", func() -> void: goto(Scenes.OPTIONS)))
	left.add_child(UiKit.menu_button("Esci", _quit))
	left.add_child(UiKit.spacer())
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	left.add_child(UiKit.label("Versione %s · Fase 1 (base e menu)" % version, UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	focus_later(resume if resume.visible else first)

	row.add_child(UiKit.spacer(false))

	# Colonna destra: avvisi (dati, rilevamento PC, riavvio)
	var right := UiKit.vbox(16)
	right.custom_minimum_size.x = 560
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(right)
	if not GameData.errors.is_empty():
		right.add_child(_notice("Errori nei dati di gioco",
			"Alcuni file in data/ non sono coerenti:\n• " + "\n• ".join(GameData.errors.slice(0, 6)), UiTheme.DANGER))
	if Settings.first_run and not Settings.first_run_report.is_empty():
		right.add_child(_notice("Impostazioni grafiche rilevate", Settings.first_run_report +
			"\nPuoi cambiarle in Opzioni, dove trovi anche il test prestazioni.", UiTheme.BRONZE))
	elif Settings.renderer_fallback_active():
		right.add_child(_notice("Renderer di riserva",
			"Il renderer scelto non è disponibile su questo PC: il gioco usa \"%s\"." % Settings.current_renderer(), UiTheme.BRONZE))
	right.add_child(_quote())

	if Settings.restart_pending:
		_ask_restart.call_deferred()


func _notice(title_text: String, body: String, accent: Color) -> PanelContainer:
	var p := UiKit.panel()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.92), accent, 1, 4, 18))
	var v := UiKit.vbox(8)
	p.add_child(v)
	v.add_child(UiKit.heading(title_text, 22))
	v.add_child(UiKit.paragraph(body, UiTheme.SMALL_SIZE))
	return p


func _quote() -> Control:
	var v := UiKit.vbox(4)
	var q := UiKit.paragraph("«Il mondo romano crolla, eppure la nostra testa resta alta, non si piega.»", 22, UiTheme.TEXT)
	q.add_theme_font_override("font", load("res://assets/fonts/AlegreyaSans-Italic.ttf"))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(q)
	var a := UiKit.label("— San Girolamo, Lettera 60", UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(a)
	return v


func _ask_restart() -> void:
	var names: Dictionary = GraphicsSettings.RENDERER_NAMES
	show_message("Riavvio consigliato",
		"Per usare il renderer \"%s\" il gioco deve riavviarsi. Vuoi riavviarlo ora?" % names.get(Settings.graphics.renderer, Settings.graphics.renderer),
		[{"text": "Più tardi", "action": Callable()},
		 {"text": "Riavvia ora", "action": Settings.restart_game}])


func _quit() -> void:
	get_tree().quit()


func on_back() -> void:
	pass
