extends GutTest

const DIR: String = "user://test_salvataggi"
var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func after_each() -> void:
	var dir := DirAccess.open(DIR)
	if dir != null:
		for f: String in dir.get_files():
			DirAccess.remove_absolute(DIR.path_join(f))
		DirAccess.remove_absolute(DIR)


func test_slot_file_name_is_safe() -> void:
	assert_eq(SaveSystem.slot_file_name("Partita di Belisario!"), "partita_di_belisario" + SaveSystem.EXTENSION)
	assert_eq(SaveSystem.slot_file_name("../../etc"), "etc" + SaveSystem.EXTENSION)
	assert_eq(SaveSystem.slot_file_name("   "), "partita" + SaveSystem.EXTENSION)


func test_save_and_load() -> void:
	var st := CampaignState.new_game(db, "535_guerra_gotica", "bizantini")
	st.turn = 5
	var err: String = SaveSystem.save_game(st, "Belisario", {"faction_name": "Bizantini"}, DIR)
	assert_eq(err, "")
	var saves: Array[Dictionary] = SaveSystem.list_saves(DIR)
	assert_eq(saves.size(), 1)
	assert_eq(saves[0]["name"], "Belisario")
	assert_eq(saves[0]["faction_name"], "Bizantini")
	assert_eq(saves[0]["date_label"], "Estate 537 d.C.")
	var res: Dictionary = SaveSystem.load_game(saves[0]["path"])
	assert_true(res["ok"], res["error"])
	var loaded: CampaignState = res["state"]
	assert_eq(loaded.turn, 5)
	assert_eq(loaded.province_owner, st.province_owner)
	assert_eq(loaded.check_against(db), "")


func test_overwrite_same_slot() -> void:
	var st := CampaignState.new_game(db, "535_guerra_gotica", "bizantini")
	SaveSystem.save_game(st, "slot", {}, DIR)
	st.turn = 9
	SaveSystem.save_game(st, "slot", {}, DIR)
	var saves: Array[Dictionary] = SaveSystem.list_saves(DIR)
	assert_eq(saves.size(), 1)
	assert_eq(int(saves[0]["turn"]), 9)


func test_corrupt_save_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR.path_join("rotto" + SaveSystem.EXTENSION)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ non è json")
	f.close()
	var res: Dictionary = SaveSystem.load_game(path)
	assert_false(res["ok"])
	assert_string_contains(res["error"], "illeggibile")
	var saves: Array[Dictionary] = SaveSystem.list_saves(DIR)
	assert_eq(saves.size(), 1)
	assert_false(saves[0]["valid"])


func test_future_version_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR.path_join("futuro" + SaveSystem.EXTENSION)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "state": {"turn": 1}}))
	f.close()
	var res: Dictionary = SaveSystem.load_game(path)
	assert_false(res["ok"])
	assert_string_contains(res["error"], "Versione")


func test_delete_save() -> void:
	var st := CampaignState.new_game(db, "535_guerra_gotica", "ostrogoti")
	SaveSystem.save_game(st, "da cancellare", {}, DIR)
	var path: String = SaveSystem.list_saves(DIR)[0]["path"]
	assert_true(SaveSystem.delete_save(path))
	assert_eq(SaveSystem.list_saves(DIR).size(), 0)
	assert_false(SaveSystem.delete_save("user://settings.cfg"), "non cancella file che non sono salvataggi")
