class_name JsonLoader
extends RefCounted
## Lettura di file JSON con messaggi di errore chiari (in italiano).


## Restituisce { "ok": bool, "data": Variant, "error": String }.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "error": "File non trovato: %s" % path}
	var text: String = FileAccess.get_file_as_string(path)
	return parse_text(text, path)


static func parse_text(text: String, source: String = "<testo>") -> Dictionary:
	var json := JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return {
			"ok": false,
			"data": null,
			"error": "%s, riga %d: %s" % [source, json.get_error_line(), json.get_error_message()],
		}
	return {"ok": true, "data": json.data, "error": ""}


## Elenca i file .json di una cartella (ordinati per nome).
static func list_json_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			out.append(dir_path.path_join(file_name))
	out.sort()
	return out
