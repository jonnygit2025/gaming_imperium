class_name ScenarioDef
extends RefCounted

var id: String = ""
var order: int = 0
var year: int = 0
var season: String = "estate"
var end_year: int = 0
var name: String = ""
var description: String = ""
var playable: PackedStringArray = []
## faction_id -> ScenarioFactionDef
var factions: Dictionary[String, ScenarioFactionDef] = {}
## Coppie di fazioni in guerra all'inizio.
var wars: Array[PackedStringArray] = []
## [{"a": String, "b": String, "value": int}]
var relations: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> ScenarioDef:
	var s := ScenarioDef.new()
	s.id = DataUtil.to_str(d, "id")
	s.order = DataUtil.to_int(d, "order")
	s.year = DataUtil.to_int(d, "year")
	s.season = DataUtil.to_str(d, "season", "estate")
	s.end_year = DataUtil.to_int(d, "end_year")
	s.name = DataUtil.to_str(d, "name")
	s.description = DataUtil.to_str(d, "description")
	s.playable = DataUtil.to_strings(d, "playable")
	var facs: Dictionary = DataUtil.to_dict(d, "factions")
	for fid: Variant in facs:
		if fid is String and facs[fid] is Dictionary:
			s.factions[fid] = ScenarioFactionDef.from_dict(fid, facs[fid])
	for pair: Variant in DataUtil.to_array(d, "wars"):
		if pair is Array and pair.size() == 2:
			s.wars.append(PackedStringArray([str(pair[0]), str(pair[1])]))
	for rel: Variant in DataUtil.to_array(d, "relations"):
		if rel is Array and rel.size() == 3:
			s.relations.append({"a": str(rel[0]), "b": str(rel[1]), "value": int(rel[2])})
	return s


## Numero totale di turni (2 per anno: estate e inverno).
func total_turns() -> int:
	var turns: int = (end_year - year) * 2
	if season == "inverno":
		turns -= 1
	return turns
