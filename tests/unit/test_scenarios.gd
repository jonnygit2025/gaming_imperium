extends GutTest
## Coerenza storica e di gioco degli scenari.

var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func test_playable_factions_match_design() -> void:
	var expected: Dictionary = {
		"476_caduta_di_roma": ["odoacre", "bizantini", "visigoti", "franchi", "vandali", "ostrogoti"],
		"535_guerra_gotica": ["bizantini", "ostrogoti"],
		"568_invasione_longobarda": ["longobardi", "bizantini", "franchi", "avari"],
		"636_espansione_islamica": ["califfato", "bizantini", "sasanidi"],
		"711_hispania_poitiers": ["omayyadi", "visigoti", "franchi", "aquitania"],
	}
	for sid: String in expected:
		assert_true(db.scenarios.has(sid), "manca lo scenario %s" % sid)
		var playable: PackedStringArray = db.scenarios[sid].playable
		for fid: String in expected[sid]:
			assert_has(playable, fid, "%s deve essere giocabile in %s" % [fid, sid])


func test_every_province_has_one_owner_in_every_scenario() -> void:
	for s: ScenarioDef in db.scenarios.values():
		var count: Dictionary = {}
		for sf: ScenarioFactionDef in s.factions.values():
			for pid: String in sf.provinces:
				count[pid] = int(count.get(pid, 0)) + 1
		for pid: String in db.province_ids():
			assert_eq(count.get(pid, 0), 1, "%s in %s" % [pid, s.id])


func test_historical_capitals() -> void:
	assert_eq(db.scenarios["476_caduta_di_roma"].factions["odoacre"].capital, "ravenna")
	assert_eq(db.scenarios["568_invasione_longobarda"].factions["avari"].capital, "pannonia")
	assert_eq(db.scenarios["711_hispania_poitiers"].factions["franchi"].leader, "Carlo Martello")


func test_scenario_overrides() -> void:
	var s: ScenarioDef = db.scenarios["476_caduta_di_roma"]
	assert_eq(s.factions["bizantini"].name_override, "Impero d'Oriente")
	assert_eq(db.scenarios["535_guerra_gotica"].factions["franchi"].religion_override, "cristiana_nicena")


func test_starting_wars() -> void:
	var s: ScenarioDef = db.scenarios["535_guerra_gotica"]
	var found := false
	for pair: PackedStringArray in s.wars:
		if "bizantini" in pair and "ostrogoti" in pair:
			found = true
	assert_true(found, "Bizantini e Ostrogoti iniziano in guerra")
