class_name ArmyState
extends RefCounted
## Un esercito sulla mappa di campagna. Nella Fase 2 è fermo: movimento, reclutamento e
## combattimento arrivano nella Fase 4a, ma i dati sono già nello stato e nei salvataggi.

const MAX_UNITS: int = 20

var id: String = ""
var faction: String = ""
var province: String = ""
var general: String = ""
## Reggimenti: [{"type": id dell'unità, "men": soldati presenti}]
var units: Array[Dictionary] = []


static func from_def(def: ArmyDef, db: GameDatabase) -> ArmyState:
	var a := ArmyState.new()
	a.id = def.id
	a.faction = def.faction
	a.province = def.province
	a.general = def.general
	for uid: String in def.units:
		var u: UnitDef = db.units.get(uid)
		a.units.append({"type": uid, "men": u.men if u != null else 0})
	return a


func soldiers() -> int:
	var n: int = 0
	for u: Dictionary in units:
		n += int(u.get("men", 0))
	return n


func unit_count() -> int:
	return units.size()


func to_dict() -> Dictionary:
	var list: Array = []
	for u: Dictionary in units:
		list.append({"type": str(u.get("type", "")), "men": int(u.get("men", 0))})
	return {"id": id, "faction": faction, "province": province, "general": general, "units": list}


static func from_dict(d: Dictionary) -> ArmyState:
	var a := ArmyState.new()
	a.id = DataUtil.to_str(d, "id")
	a.faction = DataUtil.to_str(d, "faction")
	a.province = DataUtil.to_str(d, "province")
	a.general = DataUtil.to_str(d, "general")
	for item: Variant in DataUtil.to_array(d, "units"):
		if item is Dictionary:
			a.units.append({"type": DataUtil.to_str(item, "type"), "men": DataUtil.to_int(item, "men")})
	return a


## "" se l'esercito è coerente con i dati di gioco, altrimenti il problema.
func check(db: GameDatabase, faction_ids: Array) -> String:
	if id.is_empty():
		return "Esercito senza id"
	if not faction in faction_ids:
		return "Esercito %s: fazione sconosciuta '%s'" % [id, faction]
	if not db.provinces.has(province):
		return "Esercito %s: provincia sconosciuta '%s'" % [id, province]
	if units.is_empty() or units.size() > MAX_UNITS:
		return "Esercito %s: da 1 a %d reggimenti" % [id, MAX_UNITS]
	for u: Dictionary in units:
		if not db.units.has(str(u.get("type", ""))):
			return "Esercito %s: unità sconosciuta '%s'" % [id, u.get("type", "")]
		if int(u.get("men", 0)) <= 0:
			return "Esercito %s: reggimento senza soldati" % id
	return ""
