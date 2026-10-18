class_name CultureDef
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""


static func from_dict(d: Dictionary) -> CultureDef:
	var c := CultureDef.new()
	c.id = DataUtil.to_str(d, "id")
	c.name = DataUtil.to_str(d, "name")
	c.description = DataUtil.to_str(d, "description")
	return c
