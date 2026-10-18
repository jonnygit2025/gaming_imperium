class_name ReligionDef
extends RefCounted

var id: String = ""
var name: String = ""
## Nome del luogo di culto per livello (1..3).
var temple_names: PackedStringArray = []


static func from_dict(d: Dictionary) -> ReligionDef:
	var r := ReligionDef.new()
	r.id = DataUtil.to_str(d, "id")
	r.name = DataUtil.to_str(d, "name")
	r.temple_names = DataUtil.to_strings(d, "temple_names")
	return r
