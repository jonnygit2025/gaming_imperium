class_name ArmyDef
extends RefCounted
## Esercito di partenza di uno scenario.

var id: String = ""
var faction: String = ""
var province: String = ""
var general: String = ""
## Id delle unità (data/units.json), una voce per reggimento.
var units: PackedStringArray = []


static func from_dict(d: Dictionary) -> ArmyDef:
	var a := ArmyDef.new()
	a.id = DataUtil.to_str(d, "id")
	a.faction = DataUtil.to_str(d, "faction")
	a.province = DataUtil.to_str(d, "province")
	a.general = DataUtil.to_str(d, "general")
	a.units = DataUtil.to_strings(d, "units")
	return a
