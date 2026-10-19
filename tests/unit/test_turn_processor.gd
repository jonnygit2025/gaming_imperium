extends GutTest
## Fine turno: calendario, entrate provvisorie, fine dello scenario.

var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func test_calendar_advances_one_season() -> void:
	var st := CampaignState.new_game(db, "476_caduta_di_roma", "odoacre")
	assert_eq(st.date_label(), "Estate 476 d.C.")
	var r1: TurnReport = TurnProcessor.end_turn(st, db)
	assert_eq(r1.from_turn, 1)
	assert_eq(r1.to_turn, 2)
	assert_eq(st.date_label(), "Inverno 476 d.C.")
	assert_eq(r1.date_label, "Inverno 476 d.C.")
	TurnProcessor.end_turn(st, db)
	assert_eq(st.date_label(), "Estate 477 d.C.")
	assert_eq(st.turn, 3)


func test_province_income_formula() -> void:
	var roma: ProvinceDef = db.provinces["roma"]  # ricchezza 5, popolazione 320, fertilità 3, grano
	var summer: Dictionary = TurnProcessor.province_income(roma, false, 0)
	assert_eq(summer["gold"], 30 + 25 * 5 + 40)
	assert_eq(summer["food"], roundi((20 * 3 + 15 - 16) * 1.5))
	assert_eq(summer["wood"], 3, "Roma non produce legname")
	assert_eq(summer["iron"], 0)
	var winter: Dictionary = TurnProcessor.province_income(roma, true, 1)
	assert_eq(winter["gold"], summer["gold"] + 60, "bonus della capitale")
	assert_eq(winter["food"], roundi((20 * 3 + 15 - 16) * 0.5))
	var dalmatia: Dictionary = TurnProcessor.province_income(db.provinces["dalmatia"], false, 0)
	assert_eq(dalmatia["iron"], 10 + 4, "ferro e montagna")
	assert_eq(dalmatia["wood"], 12)


func test_income_is_applied_to_every_faction() -> void:
	var st := CampaignState.new_game(db, "535_guerra_gotica", "ostrogoti")
	var before: Dictionary = {}
	var expected: Dictionary = {}
	for fid: String in st.factions:
		before[fid] = st.factions[fid].resources.duplicate()
		expected[fid] = TurnProcessor.estimate_income(st, db, fid)
	var report: TurnReport = TurnProcessor.end_turn(st, db)
	for fid: String in st.factions:
		var inc: Dictionary = report.income_of(fid)
		assert_eq(inc, expected[fid], "stima uguale all'incasso per %s" % fid)
		for k: String in ["gold", "food", "wood", "iron"]:
			assert_eq(st.factions[fid].resource(k), maxi(0, int(before[fid][k]) + int(inc[k])))
	assert_gt(report.income_of("ostrogoti")["gold"], 0)


func test_resources_never_negative() -> void:
	var st := CampaignState.new_game(db, "636_espansione_islamica", "califfato")
	for fs: FactionState in st.factions.values():
		fs.resources["food"] = 0
	for i: int in 6:
		TurnProcessor.end_turn(st, db)
	for fs: FactionState in st.factions.values():
		for k: String in fs.resources:
			assert_gte(fs.resource(k), 0, "%s %s" % [fs.id, k])


func test_scenario_end_is_reported_once() -> void:
	var st := CampaignState.new_game(db, "711_hispania_poitiers", "franchi")
	assert_eq(st.last_turn(), db.scenarios["711_hispania_poitiers"].total_turns())
	st.turn = st.last_turn()
	assert_false(st.is_finished())
	var r: TurnReport = TurnProcessor.end_turn(st, db)
	assert_true(r.scenario_ended)
	assert_true(st.is_finished())
	assert_eq(r.messages.size(), 1)
	var r2: TurnReport = TurnProcessor.end_turn(st, db)
	assert_false(r2.scenario_ended, "l'avviso compare una volta sola")


func test_dead_factions_get_nothing() -> void:
	var st := CampaignState.new_game(db, "476_caduta_di_roma", "odoacre")
	st.factions["vandali"].alive = false
	var gold: int = st.factions["vandali"].resource("gold")
	TurnProcessor.end_turn(st, db)
	assert_eq(st.factions["vandali"].resource("gold"), gold)
