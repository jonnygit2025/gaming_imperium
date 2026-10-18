class_name SaveSystem
extends RefCounted
## Salvataggio e caricamento delle partite in JSON (leggibile e robusto).

const SAVE_VERSION: int = 1
const EXTENSION: String = ".regna.json"
const DEFAULT_DIR: String = "user://saves"


## Trasforma un nome libero in un nome di file sicuro.
static func slot_file_name(slot_name: String) -> String:
	var clean: String = ""
	for ch: String in slot_name.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			clean += ch
		elif ch in [" ", "-", "_"]:
			clean += "_"
	if clean.is_empty():
		clean = "partita"
	return clean.left(40) + EXTENSION


## Salva la partita. Restituisce "" se è andato tutto bene, altrimenti l'errore.
static func save_game(state: CampaignState, slot_name: String, meta: Dictionary = {}, dir_path: String = DEFAULT_DIR) -> String:
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return "Impossibile creare la cartella dei salvataggi (%s)" % error_string(err)
	var info: Dictionary = meta.duplicate()
	info["name"] = slot_name
	info["saved_at"] = Time.get_datetime_string_from_system(false, true)
	info["unix_time"] = Time.get_unix_time_from_system()
	info["date_label"] = state.date_label()
	info["turn"] = state.turn
	var payload: Dictionary = {"version": SAVE_VERSION, "meta": info, "state": state.to_dict()}
	var path: String = dir_path.path_join(slot_file_name(slot_name))
	# Scrittura sicura: prima un file temporaneo, poi lo si rinomina.
	var tmp_path: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return "Impossibile scrivere il salvataggio (%s)" % error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		return "Impossibile completare il salvataggio (%s)" % error_string(err)
	return ""


## Restituisce { "ok": bool, "state": CampaignState, "meta": Dictionary, "error": String }.
static func load_game(path: String) -> Dictionary:
	var res: Dictionary = JsonLoader.load_file(path)
	if not res["ok"]:
		return {"ok": false, "state": null, "meta": {}, "error": "Salvataggio illeggibile: %s" % res["error"]}
	var data: Variant = res["data"]
	if not data is Dictionary:
		return {"ok": false, "state": null, "meta": {}, "error": "Salvataggio non valido"}
	var version: int = DataUtil.to_int(data, "version", -1)
	if version < 1 or version > SAVE_VERSION:
		return {"ok": false, "state": null, "meta": {}, "error": "Versione del salvataggio non supportata (%d)" % version}
	var state_dict: Dictionary = DataUtil.to_dict(data, "state")
	if state_dict.is_empty():
		return {"ok": false, "state": null, "meta": {}, "error": "Il salvataggio non contiene una partita"}
	var state: CampaignState = CampaignState.from_dict(state_dict)
	return {"ok": true, "state": state, "meta": DataUtil.to_dict(data, "meta"), "error": ""}


## Elenco dei salvataggi, dal più recente: [{ "path", "name", "saved_at", "date_label", ... }]
static func list_saves(dir_path: String = DEFAULT_DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if not file_name.ends_with(EXTENSION):
			continue
		var path: String = dir_path.path_join(file_name)
		var res: Dictionary = JsonLoader.load_file(path)
		var meta: Dictionary = {}
		if res["ok"] and res["data"] is Dictionary:
			meta = DataUtil.to_dict(res["data"], "meta")
		var entry: Dictionary = meta.duplicate()
		entry["path"] = path
		entry["valid"] = not meta.is_empty()
		if not entry.has("name"):
			entry["name"] = file_name.trim_suffix(EXTENSION)
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("unix_time", 0.0)) > float(b.get("unix_time", 0.0)))
	return out


static func delete_save(path: String) -> bool:
	if not path.ends_with(EXTENSION) or not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK
