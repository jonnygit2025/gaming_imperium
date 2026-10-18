extends GutTest

var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func test_rejects_unknown_scenario_and_faction() -> void:
	assert_ne(CampaignState.check_new_game(db, "999_fantasia", "franchi"), "")
	assert_ne(CampaignState.check_new_game(db, "636_espansione_islamica", "franchi"), "", "Franchi non giocabili nel 636")
	assert_eq(CampaignState.check_new_game(db, "636_espansione_islamica", "califfato"), "")


func test_new_game_setup() -> void:
	var st := CampaignState.new_game(db, "476_caduta_di_roma", "odoacre")
	assert_eq(st.player_faction, "odoacre")
	assert_true(st.player().is_player)
	assert_eq(st.player().display_name, "Regno di Odoacre")
	assert_eq(st.factions["bizantini"].display_name, "Impero d'Oriente")
	assert_eq(st.province_owner["ravenna"], "odoacre")
	assert_eq(st.province_owner.size(), db.provinces.size())
	assert_eq(st.player().resource("gold"), 4000)
	assert_has(st.provinces_of("odoacre"), "roma")
	assert_true(st.at_war("odoacre", "vandali"))
	assert_true(st.at_war("vandali", "odoacre"), "la guerra vale nei due sensi")
	assert_false(st.at_war("odoacre", "bizantini"))
	assert_eq(st.relation("bizantini", "ostrogoti"), 20)


func test_religion_override() -> void:
	var st := CampaignState.new_game(db, "535_guerra_gotica", "franchi")
	assert_eq(st.factions["franchi"].religion, "cristiana_nicena")
	var st2 := CampaignState.new_game(db, "476_caduta_di_roma", "franchi")
	assert_eq(st2.factions["franchi"].religion, "pagana")


func test_calendar_two_turns_per_year() -> void:
	var st := CampaignState.new_game(db, "711_hispania_poitiers", "franchi")
	assert_eq(st.date_label(), "Estate 711 d.C.")
	st.turn = 2
	assert_eq(st.date_label(), "Inverno 711 d.C.")
	st.turn = 3
	assert_eq(st.date_label(), "Estate 712 d.C.")
	st.turn = 1 + 2 * 21
	assert_eq(st.year(), 732)


func test_relation_is_clamped() -> void:
	var st := CampaignState.new()
	st.set_relation("a", "b", 500)
	assert_eq(st.relation("b", "a"), 100)
	st.set_war("a", "b", true)
	st.set_war("b", "a", false)
	assert_false(st.at_war("a", "b"))


func test_dict_round_trip() -> void:
	var st := CampaignState.new_game(db, "568_invasione_longobarda", "longobardi")
	st.turn = 7
	st.player().resources["gold"] = 1234
	var copy := CampaignState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_eq(copy.turn, 7)
	assert_eq(copy.player_faction, "longobardi")
	assert_eq(copy.player().resource("gold"), 1234)
	assert_eq(copy.province_owner, st.province_owner)
	assert_true(copy.at_war("longobardi", "bizantini"))
	assert_eq(copy.relation("longobardi", "avari"), 20)
	assert_eq(copy.date_label(), st.date_label())
	assert_eq(copy.check_against(db), "")
