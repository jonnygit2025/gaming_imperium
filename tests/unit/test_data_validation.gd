extends GutTest
## Il validatore deve accorgersi degli errori nei dati.
## Copia i dati veri in una cartella temporanea e li rompe apposta.

const TMP: String = "user://test_dati"


func before_each() -> void:
	_copy_dir("res://data", TMP)


func after_each() -> void:
	_remove_dir(TMP)


func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var dir := DirAccess.open(from)
	for f: String in dir.get_files():
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for d: String in dir.get_directories():
		_copy_dir(from.path_join(d), to.path_join(d))


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for d: String in dir.get_directories():
		_remove_dir(path.path_join(d))
	DirAccess.remove_absolute(path)


func _edit_json(rel: String, edit: Callable) -> void:
	var path: String = TMP.path_join(rel)
	var data: Dictionary = JsonLoader.load_file(path)["data"]
	edit.call(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _errors() -> String:
	var db := GameDatabase.new()
	db.load_all(TMP)
	return "\n".join(db.validate())


func test_copy_is_valid() -> void:
	assert_eq(_errors(), "")


func test_asymmetric_border_detected() -> void:
	_edit_json("map/provinces.json", func(d: Dictionary) -> void:
		for p: Dictionary in d["provinces"]:
			if p["id"] == "roma":
				p["neighbors"].append("achaea"))
	assert_string_contains(_errors(), "non è reciproco")


func test_unknown_neighbor_detected() -> void:
	_edit_json("map/provinces.json", func(d: Dictionary) -> void:
		d["provinces"][0]["neighbors"].append("atlantide"))
	assert_string_contains(_errors(), "atlantide")


func test_duplicate_id_detected() -> void:
	_edit_json("units.json", func(d: Dictionary) -> void:
		d["units"].append(d["units"][0].duplicate(true)))
	assert_string_contains(_errors(), "duplicato")


func test_province_without_owner_detected() -> void:
	_edit_json("scenarios/1_476.json", func(d: Dictionary) -> void:
		var provs: Array = d["factions"]["odoacre"]["provinces"]
		provs.erase("tuscia"))
	assert_string_contains(_errors(), "tuscia non ha padrone")


func test_province_owned_twice_detected() -> void:
	_edit_json("scenarios/1_476.json", func(d: Dictionary) -> void:
		d["factions"]["franchi"]["provinces"].append("roma"))
	assert_string_contains(_errors(), "è già di")


func test_ranged_unit_without_ammo_detected() -> void:
	_edit_json("units.json", func(d: Dictionary) -> void:
		for u: Dictionary in d["units"]:
			if u["id"] == "toxotai":
				u["ammo"] = 0)
	assert_string_contains(_errors(), "senza munizioni")


func test_unknown_building_requirement_detected() -> void:
	_edit_json("units.json", func(d: Dictionary) -> void:
		d["units"][0]["requires"] = [{"building": "torre_magica", "level": 1}])
	assert_string_contains(_errors(), "torre_magica")


func test_capital_outside_provinces_detected() -> void:
	_edit_json("scenarios/2_535.json", func(d: Dictionary) -> void:
		d["factions"]["ostrogoti"]["capital"] = "aegyptus")
	assert_string_contains(_errors(), "capitale")


func test_broken_json_reported() -> void:
	var f := FileAccess.open(TMP.path_join("cultures.json"), FileAccess.WRITE)
	f.store_string("{ rotto ")
	f.close()
	assert_string_contains(_errors(), "cultures.json")
