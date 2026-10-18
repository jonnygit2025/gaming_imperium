extends Node
## Autoload "Session": la partita in corso e i salvataggi.

var state: CampaignState = null
var saves_dir: String = SaveSystem.DEFAULT_DIR


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
	return ""


func save_current(slot_name: String) -> String:
	if state == null:
		return "Nessuna partita in corso"
	var scen: ScenarioDef = GameData.db.scenarios.get(state.scenario_id)
	var meta: Dictionary = {
		"scenario_id": state.scenario_id,
		"scenario_name": scen.name if scen != null else state.scenario_id,
		"faction_id": state.player_faction,
		"faction_name": state.player().display_name if state.player() != null else state.player_faction,
	}
	return SaveSystem.save_game(state, slot_name, meta, saves_dir)


func load_from(path: String) -> String:
	var res: Dictionary = SaveSystem.load_game(path)
	if not res["ok"]:
		return res["error"]
	var loaded: CampaignState = res["state"]
	var err: String = loaded.check_against(GameData.db)
	if not err.is_empty():
		return err
	state = loaded
	return ""


func list_saves() -> Array[Dictionary]:
	return SaveSystem.list_saves(saves_dir)


func end_game() -> void:
	state = null
