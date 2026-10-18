class_name FactionDef
extends RefCounted

var id: String = ""
var name: String = ""
var culture: String = ""
var religion: String = ""
var color: Color = Color.WHITE
var color_text: String = ""
var description: String = ""


static func from_dict(d: Dictionary) -> FactionDef:
	var f := FactionDef.new()
	f.id = DataUtil.to_str(d, "id")
	f.name = DataUtil.to_str(d, "name")
	f.culture = DataUtil.to_str(d, "culture")
	f.religion = DataUtil.to_str(d, "religion")
	f.color_text = DataUtil.to_str(d, "color")
	f.color = Color.from_string(f.color_text, Color.WHITE)
	f.description = DataUtil.to_str(d, "description")
	return f


func has_valid_color() -> bool:
	return Color.html_is_valid(color_text)
