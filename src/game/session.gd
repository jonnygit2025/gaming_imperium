extends Node
## Autoload "Session": la partita in corso e i salvataggi.

var state: CampaignState = null
var saves_dir: String = SaveSystem.DEFAULT_DIR
## Riepilogo dell'ultimo fine turno, mostrato all'inizio del turno seguente.
var last_report: TurnReport = null
## Schermata a cui tornare da Opzioni o Carica (es. la mappa, se ci si arriva dal menu di pausa).
var return_scene: String = ""
## Se falso, il fine turno non scrive salvataggi automatici (simulazioni e test).
var autosave_enabled: bool = true
## La mappa si apre per il test prestazioni (percorso fisso della telecamera).
var map_benchmark: bool = false
## true se la partita è stata creata solo per il test e va chiusa alla fine.
var benchmark_owns_game: bool = false


## Prepara il test prestazioni della mappa: usa la partita in corso o ne crea una di prova.
func start_map_benchmark() -> void:
	benchmark_owns_game = state == null
	if benchmark_owns_game:
		start_new_game("476_caduta_di_roma", "odoacre")
	map_benchmark = true


func _ready() -> void:
	# Opzione di avvio per le prove: Regna.exe -- --partita-prova=476_caduta_di_roma:odoacre
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--partita-prova="):
			var parts: PackedStringArray = arg.trim_prefix("--partita-prova=").split(":")
			if parts.size() == 2 and start_new_game(parts[0], parts[1]).is_empty():
				Scenes.goto(get_tree(), Scenes.CAMPAIGN)


func has_game() -> bool:
	return state != null


## Avvia una nuova partita. Restituisce "" oppure il messaggio d'errore.
func start_new_game(scenario_id: String, faction_id: String) -> String:
	var err: String = CampaignState.check_new_game(GameData.db, scenario_id, faction_id)
	if not err.is_empty():
		return err
	state = CampaignState.new_game(GameData.db, scenario_id, faction_id)
	last_report = null
	return ""


func _meta() -> Dictionary:
	var scen: ScenarioDef = GameData.db.scenarios.get(state.scenario_id)
	return {
		"scenario_id": state.scenario_id,
		"scenario_name": scen.name if scen != null else state.scenario_id,
		"faction_id": state.player_faction,
		"faction_name": state.player().display_name if state.player() != null else state.player_faction,
	}


func save_current(slot_name: String) -> String:
	if state == null:
		return "Nessuna partita in corso"
	return SaveSystem.save_game(state, slot_name, _meta(), saves_dir)


## Fine del turno del giocatore: regole, calendario e salvataggio automatico.
## Restituisce il riepilogo (con un avviso se il salvataggio automatico non è riuscito).
func end_turn() -> TurnReport:
	if state == null:
		return null
	var report: TurnReport = TurnProcessor.end_turn(state, GameData.db)
	if autosave_enabled:
		var err: String = SaveSystem.autosave(state, _meta(), saves_dir)
		if not err.is_empty():
			report.messages.append("Salvataggio automatico non riuscito: %s" % err)
			push_warning("Salvataggio automatico non riuscito: %s" % err)
	last_report = report
	return report


func load_from(path: String) -> String:
	var res: Dictionary = SaveSystem.load_game(path)
	if not res["ok"]:
		return res["error"]
	var loaded: CampaignState = res["state"]
	if int(res.get("version", SaveSystem.SAVE_VERSION)) < 2:
		loaded.add_starting_armies(GameData.db)  # i salvataggi della Fase 1 non avevano eserciti
	var err: String = loaded.check_against(GameData.db)
	if not err.is_empty():
		return err
	state = loaded
	last_report = null
	return ""


## Carica il salvataggio più recente (per "Continua"). "" se è andato bene.
func load_latest() -> String:
	for s: Dictionary in list_saves():
		if s.get("valid", false):
			return load_from(s["path"])
	return "Nessun salvataggio da continuare"


func has_saves() -> bool:
	for s: Dictionary in list_saves():
		if s.get("valid", false):
			return true
	return false


func list_saves() -> Array[Dictionary]:
	return SaveSystem.list_saves(saves_dir)


func end_game() -> void:
	state = null
	last_report = null
	return_scene = ""
