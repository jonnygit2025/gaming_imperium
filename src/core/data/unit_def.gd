class_name UnitDef
extends RefCounted
## Tipo di reggimento (statistiche per soldato e per unità).

var id: String = ""
var name: String = ""
var description: String = ""
var cultures: PackedStringArray = []
var unit_class: String = ""
var tier: int = 1
var men: int = 0
var attack: int = 0
var defense: int = 0
var armor: int = 0
var charge: int = 0
var morale: int = 0
## Velocità di corsa in metri al secondo.
var speed: float = 0.0
var stamina: int = 0
var bonus_vs_cavalry: int = 0
var ammo: int = 0
## Gittata in metri.
var range_m: float = 0.0
var missile_damage: int = 0
## Costo: {"gold": int, "iron": int, "manpower": int}
var cost: Dictionary = {}
var upkeep: int = 0
var recruit_turns: int = 1
## [{"building": String, "level": int}]
var requires: Array[Dictionary] = []
var abilities: PackedStringArray = []
## Indicazioni per la grafica (scudo, arma, elmo, a cavallo...).
var look: Dictionary = {}


static func from_dict(d: Dictionary) -> UnitDef:
	var u := UnitDef.new()
	u.id = DataUtil.to_str(d, "id")
	u.name = DataUtil.to_str(d, "name")
	u.description = DataUtil.to_str(d, "description")
	u.cultures = DataUtil.to_strings(d, "cultures")
	u.unit_class = DataUtil.to_str(d, "class")
	u.tier = DataUtil.to_int(d, "tier", 1)
	u.men = DataUtil.to_int(d, "men")
	u.attack = DataUtil.to_int(d, "attack")
	u.defense = DataUtil.to_int(d, "defense")
	u.armor = DataUtil.to_int(d, "armor")
	u.charge = DataUtil.to_int(d, "charge")
	u.morale = DataUtil.to_int(d, "morale")
	u.speed = DataUtil.to_float(d, "speed")
	u.stamina = DataUtil.to_int(d, "stamina")
	u.bonus_vs_cavalry = DataUtil.to_int(d, "bonus_vs_cavalry")
	u.ammo = DataUtil.to_int(d, "ammo")
	u.range_m = DataUtil.to_float(d, "range")
	u.missile_damage = DataUtil.to_int(d, "missile_damage")
	u.cost = DataUtil.int_map(d, "cost")
	u.upkeep = DataUtil.to_int(d, "upkeep")
	u.recruit_turns = DataUtil.to_int(d, "recruit_turns", 1)
	u.requires = DataUtil.requirements(d, "requires")
	u.abilities = DataUtil.to_strings(d, "abilities")
	u.look = DataUtil.to_dict(d, "look")
	return u


func is_ranged() -> bool:
	return unit_class in Defs.RANGED_CLASSES


func is_mounted() -> bool:
	return unit_class in Defs.MOUNTED_CLASSES


func class_name_it() -> String:
	return Defs.UNIT_CLASS_NAMES.get(unit_class, unit_class)
