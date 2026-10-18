extends GutTest


func test_missing_file_reports_error() -> void:
	var res: Dictionary = JsonLoader.load_file("res://non_esiste.json")
	assert_false(res["ok"])
	assert_string_contains(res["error"], "non trovato")


func test_invalid_json_reports_line() -> void:
	var res: Dictionary = JsonLoader.parse_text("{\n \"a\": 1,\n oops }", "prova.json")
	assert_false(res["ok"])
	assert_string_contains(res["error"], "prova.json")
	assert_string_contains(res["error"], "riga")


func test_valid_json() -> void:
	var res: Dictionary = JsonLoader.parse_text("{\"a\": [1, 2]}")
	assert_true(res["ok"])
	assert_eq(res["data"]["a"].size(), 2)


func test_list_json_files_sorted() -> void:
	var files: PackedStringArray = JsonLoader.list_json_files("res://data/scenarios")
	assert_eq(files.size(), 5)
	var sorted_files: PackedStringArray = files.duplicate()
	sorted_files.sort()
	assert_eq(files, sorted_files)
