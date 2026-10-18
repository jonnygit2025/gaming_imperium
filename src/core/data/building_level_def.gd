class_name BuildingLevelDef
extends RefCounted

var level: int = 1
var name: String = ""
## {"gold": int, "wood": int, "iron": int}
var cost: Dictionary = {}
var turns: int = 1
## {"gold": 60.0, "public_order": 1.0, ...}
var effects: Dictionary = {}
var requires: Array[Dictionary] = []


static func from_dict(d: Dictionary, level_number: int) -> BuildingLevelDef:
	var l := BuildingLevelDef.new()
	l.level = level_number
	l.name = DataUtil.to_str(d, "name")
	l.cost = DataUtil.int_map(d, "cost")
	l.turns = DataUtil.to_int(d, "turns", 1)
	l.effects = DataUtil.float_map(d, "effects")
	l.requires = DataUtil.requirements(d, "requires")
	return l
