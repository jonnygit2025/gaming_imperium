class_name ScenarioFactionDef
extends RefCounted
## Situazione di partenza di una fazione in uno scenario.

var faction_id: String = ""
var provinces: PackedStringArray = []
var capital: String = ""
var leader: String = ""
var difficulty: String = "media"
var resources: Dictionary = {}
## Nome e religione possono cambiare da uno scenario all'altro.
var name_override: String = ""
var religion_override: String = ""
var victory_description: String = ""
var victory_provinces: PackedStringArray = []
var victory_min_provinces: int = 0


static func from_dict(fid: String, d: Dictionary) -> ScenarioFactionDef:
	var f := ScenarioFactionDef.new()
	f.faction_id = fid
	f.provinces = DataUtil.to_strings(d, "provinces")
	f.capital = DataUtil.to_str(d, "capital")
	f.leader = DataUtil.to_str(d, "leader")
	f.difficulty = DataUtil.to_str(d, "difficulty", "media")
	f.resources = DataUtil.int_map(d, "resources")
	f.name_override = DataUtil.to_str(d, "name")
	f.religion_override = DataUtil.to_str(d, "religion")
	var v: Dictionary = DataUtil.to_dict(d, "victory")
	f.victory_description = DataUtil.to_str(v, "description")
	f.victory_provinces = DataUtil.to_strings(v, "provinces")
	f.victory_min_provinces = DataUtil.to_int(v, "min_provinces")
	return f
