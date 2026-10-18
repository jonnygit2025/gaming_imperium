extends GutTest
## Eserciti di partenza degli scenari e loro stato.

var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func test_data_has_no_errors() -> void:
	assert_eq(db.validate(), PackedStringArray(), "dati coerenti, eserciti compresi")


func test_every_scenario_has_valid_starting_armies() -> void:
	for s: ScenarioDef in db.scenarios.values():
		assert_gte(s.armies.size(), 3, "%s: almeno 3 eserciti" % s.id)
		var owner_of: Dictionary = {}
		for sf: ScenarioFactionDef in s.factions.values():
			for pid: String in sf.provinces:
				owner_of[pid] = sf.faction_id
		var with_army: Dictionary = {}
		for a: ArmyDef in s.armies:
			assert_eq(owner_of.get(a.province, ""), a.faction, "%s parte in una sua provincia" % a.id)
			assert_false(a.general.is_empty())
			assert_between(a.units.size(), 1, ArmyState.MAX_UNITS)
			var culture: String = db.factions[a.faction].culture
			for uid: String in a.units:
				assert_true(db.units.has(uid), uid)
				assert_has(db.units[uid].cultures, culture, "%s adatta a %s" % [uid, a.faction])
			with_army[a.faction] = true
		for fid: String in s.playable:
			assert_true(with_army.has(fid), "%s: la fazione giocabile %s ha un esercito" % [s.id, fid])


func test_new_game_creates_armies() -> void:
	var st := CampaignState.new_game(db, "711_hispania_poitiers", "franchi")
	assert_eq(st.armies.size(), db.scenarios["711_hispania_poitiers"].armies.size())
	var martel: ArmyState = st.armies["franchi_1"]
	assert_eq(martel.general, "Carlo Martello")
	assert_eq(martel.province, "austrasia")
	assert_eq(martel.unit_count(), 7)
	assert_eq(martel.soldiers(), 100 + 100 + 100 + 100 + 100 + 50 + 60)
	assert_eq(st.armies_in("austrasia").size(), 1)
	assert_eq(st.armies_in("roma").size(), 0)
	assert_eq(st.armies_of("omayyadi").size(), 3)
	assert_eq(st.check_against(db), "")


func test_army_check_rejects_bad_data() -> void:
	var st := CampaignState.new_game(db, "476_caduta_di_roma", "odoacre")
	st.armies["odoacre_1"].units.append({"type": "carro_armato", "men": 10})
	assert_string_contains(st.check_against(db), "unità sconosciuta")
	st = CampaignState.new_game(db, "476_caduta_di_roma", "odoacre")
	st.armies["odoacre_1"].province = "atlantide"
	assert_string_contains(st.check_against(db), "provincia sconosciuta")


func test_army_round_trip() -> void:
	var st := CampaignState.new_game(db, "568_invasione_longobarda", "longobardi")
	st.armies["longobardi_1"].units[0]["men"] = 37
	var copy := CampaignState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_eq(copy.armies.size(), st.armies.size())
	for aid: String in st.armies:
		assert_eq(copy.armies[aid].to_dict(), st.armies[aid].to_dict())
	assert_eq(copy.armies["longobardi_1"].units[0]["men"], 37)
