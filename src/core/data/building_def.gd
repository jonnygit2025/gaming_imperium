class_name BuildingDef
extends RefCounted
## Catena di edifici con più livelli (es. Palizzata → Mura di pietra → Mura possenti).

var id: String = ""
var name: String = ""
var category: String = ""
var description: String = ""
## Se non vuoto, si può costruire solo nelle province con questa risorsa.
var province_resource: String = ""
var requires_coastal: bool = false
var levels: Array[BuildingLevelDef] = []


static func from_dict(d: Dictionary) -> BuildingDef:
	var b := BuildingDef.new()
	b.id = DataUtil.to_str(d, "id")
	b.name = DataUtil.to_str(d, "name")
	b.category = DataUtil.to_str(d, "category")
	b.description = DataUtil.to_str(d, "description")
	b.province_resource = DataUtil.to_str(d, "province_resource")
	b.requires_coastal = DataUtil.to_bool(d, "requires_coastal")
	var n: int = 0
	for item: Variant in DataUtil.to_array(d, "levels"):
		if item is Dictionary:
			n += 1
			b.levels.append(BuildingLevelDef.from_dict(item, n))
	return b


func max_level() -> int:
	return levels.size()


## Livello 1-based; null se non esiste.
func level(n: int) -> BuildingLevelDef:
	if n < 1 or n > levels.size():
		return null
	return levels[n - 1]
