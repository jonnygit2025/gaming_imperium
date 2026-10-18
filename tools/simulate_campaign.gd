extends SceneTree
## Simulazione headless: per ogni scenario gioca N turni (200 di default) con il TurnProcessor,
## salvando e ricaricando la partita a intervalli, e controlla che lo stato resti coerente.
## Uso: godot --headless -s tools/simulate_campaign.gd [-- --turni=200]
## (tools/simulate_campaign.sh lo esegue e fallisce se nel log compaiono errori o warning)

const SAVE_DIR: String = "user://simulazione"
const SAVE_EVERY: int = 25


func _init() -> void:
	var turns: int = 200
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--turni="):
			turns = int(a.trim_prefix("--turni="))
	var db := GameDatabase.new()
	db.load_all()
	var errors: PackedStringArray = db.validate()
	for e: String in errors:
		push_error("Dati: %s" % e)
	var failures: int = errors.size()
	var t0: int = Time.get_ticks_msec()
	for s: ScenarioDef in db.scenarios_sorted():
		failures += _simulate(db, s, turns)
	_cleanup()
	print("Simulazione completata in %.1f s: %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		"nessun problema" if failures == 0 else "%d problemi" % failures])
	quit(0 if failures == 0 else 1)


func _simulate(db: GameDatabase, s: ScenarioDef, turns: int) -> int:
	var problems: int = 0
	var st := CampaignState.new_game(db, s.id, s.playable[0])
	var ended_at: int = -1
	for i: int in turns:
		var report: TurnReport = TurnProcessor.end_turn(st, db)
		if report.to_turn != report.from_turn + 1:
			push_error("%s: il turno non avanza di uno" % s.id)
			problems += 1
		if report.scenario_ended:
			ended_at = report.to_turn
		for fs: FactionState in st.factions.values():
			for k: String in ["gold", "food", "wood", "iron"]:
				if fs.resource(k) < 0:
					push_error("%s turno %d: %s ha %s negativo" % [s.id, st.turn, fs.id, k])
					problems += 1
		if (i + 1) % SAVE_EVERY == 0:
			var err: String = SaveSystem.save_game(st, "sim_%s" % s.id, {}, SAVE_DIR)
			if not err.is_empty():
				push_error("%s: salvataggio non riuscito: %s" % [s.id, err])
				problems += 1
				continue
			var res: Dictionary = SaveSystem.load_game(SAVE_DIR.path_join(SaveSystem.slot_file_name("sim_%s" % s.id)))
			if not res["ok"]:
				push_error("%s: caricamento non riuscito: %s" % [s.id, res["error"]])
				problems += 1
				continue
			var loaded: CampaignState = res["state"]
			var check: String = loaded.check_against(db)
			if not check.is_empty() or JSON.stringify(loaded.to_dict()) != JSON.stringify(st.to_dict()):
				push_error("%s turno %d: lo stato ricaricato è diverso (%s)" % [s.id, st.turn, check])
				problems += 1
			st = loaded
	var me: FactionState = st.player()
	print("%-26s %3d turni → %s · %s: oro %d, cibo %d · eserciti %d · fine scenario al turno %d" % [
		s.id, turns, st.date_label(), me.id, me.resource("gold"), me.resource("food"),
		st.armies.size(), ended_at])
	return problems


func _cleanup() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		DirAccess.remove_absolute(SAVE_DIR.path_join(f))
	DirAccess.remove_absolute(SAVE_DIR)
