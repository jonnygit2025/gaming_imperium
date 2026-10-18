class_name FactionState
extends RefCounted
## Stato di una fazione durante la partita.

var id: String = ""
var display_name: String = ""
var religion: String = ""
var capital: String = ""
var leader: String = ""
var is_player: bool = false
var alive: bool = true
## {"gold": int, "food": int, "wood": int, "iron": int}
var resources: Dictionary = {}


func resource(key: String) -> int:
	return int(resources.get(key, 0))


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "religion": religion, "capital": capital,
		"leader": leader, "is_player": is_player, "alive": alive, "resources": resources.duplicate(),
	}


static func from_dict(d: Dictionary) -> FactionState:
	var f := FactionState.new()
	f.id = DataUtil.to_str(d, "id")
	f.display_name = DataUtil.to_str(d, "display_name")
	f.religion = DataUtil.to_str(d, "religion")
	f.capital = DataUtil.to_str(d, "capital")
	f.leader = DataUtil.to_str(d, "leader")
	f.is_player = DataUtil.to_bool(d, "is_player")
	f.alive = DataUtil.to_bool(d, "alive", true)
	f.resources = DataUtil.int_map(d, "resources")
	return f
