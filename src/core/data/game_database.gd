class_name GameDatabase
extends RefCounted
## Tutti i dati statici del gioco, caricati dai JSON in data/.
## Logica pura: nessun nodo, testabile in headless.

const DEFAULT_ROOT: String = "res://data"

var root: String = DEFAULT_ROOT
var religions: Dictionary[String, ReligionDef] = {}
var cultures: Dictionary[String, CultureDef] = {}
var factions: Dictionary[String, FactionDef] = {}
var units: Dictionary[String, UnitDef] = {}
var buildings: Dictionary[String, BuildingDef] = {}
var provinces: Dictionary[String, ProvinceDef] = {}
## [{"a": String, "b": String, "name": String}]
var straits: Array[Dictionary] = []
var scenarios: Dictionary[String, ScenarioDef] = {}
## Errori di lettura (file mancanti, JSON non valido, id duplicati).
var load_errors: PackedStringArray = []

# Ordine di inserimento, per elenchi stabili nell'interfaccia.
var _province_order: PackedStringArray = []
var _unit_order: PackedStringArray = []
var _building_order: PackedStringArray = []


## Carica tutti i file. Restituisce true se non ci sono errori di lettura.
func load_all(data_root: String = DEFAULT_ROOT) -> bool:
	root = data_root
	load_errors.clear()
	_load_list("religions.json", "religions", func(d: Dictionary) -> void: _add(religions, ReligionDef.from_dict(d), "religione"))
	_load_list("cultures.json", "cultures", func(d: Dictionary) -> void: _add(cultures, CultureDef.from_dict(d), "cultura"))
	_load_list("factions.json", "factions", func(d: Dictionary) -> void: _add(factions, FactionDef.from_dict(d), "fazione"))
	_load_list("units.json", "units", func(d: Dictionary) -> void:
		var u := UnitDef.from_dict(d)
		if _add(units, u, "unità"):
			_unit_order.append(u.id))
	_load_list("buildings.json", "buildings", func(d: Dictionary) -> void:
		var b := BuildingDef.from_dict(d)
		if _add(buildings, b, "edificio"):
			_building_order.append(b.id))
	_load_list("map/provinces.json", "provinces", func(d: Dictionary) -> void:
		var p := ProvinceDef.from_dict(d)
		if _add(provinces, p, "provincia"):
			_province_order.append(p.id))
	_load_list("map/provinces.json", "straits", func(d: Dictionary) -> void:
		straits.append({"a": DataUtil.to_str(d, "a"), "b": DataUtil.to_str(d, "b"), "name": DataUtil.to_str(d, "name")}))
	var scen_dir: String = root.path_join("scenarios")
	var files: PackedStringArray = JsonLoader.list_json_files(scen_dir)
	if files.is_empty():
		load_errors.append("Nessuno scenario trovato in %s" % scen_dir)
	for path: String in files:
		var res: Dictionary = JsonLoader.load_file(path)
		if not res["ok"]:
			load_errors.append(res["error"])
			continue
		if not res["data"] is Dictionary:
			load_errors.append("%s: lo scenario deve essere un oggetto JSON" % path)
			continue
		_add(scenarios, ScenarioDef.from_dict(res["data"]), "scenario")
	return load_errors.is_empty()


func _load_list(rel_path: String, key: String, add: Callable) -> void:
	var path: String = root.path_join(rel_path)
	var res: Dictionary = JsonLoader.load_file(path)
	if not res["ok"]:
		load_errors.append(res["error"])
		return
	var data: Variant = res["data"]
	if not data is Dictionary or not (data as Dictionary).get(key) is Array:
		load_errors.append("%s: manca l'elenco \"%s\"" % [path, key])
		return
	for item: Variant in data[key]:
		if item is Dictionary:
			add.call(item)
		else:
			load_errors.append("%s: elemento non valido in \"%s\"" % [path, key])


func _add(target: Dictionary, def: RefCounted, kind: String) -> bool:
	var def_id: String = def.get("id")
	if def_id.is_empty():
		load_errors.append("Un elemento di tipo %s non ha id" % kind)
		return false
	if target.has(def_id):
		load_errors.append("Id duplicato per %s: %s" % [kind, def_id])
		return false
	target[def_id] = def
	return true


# ------------------------------------------------------------------ interrogazioni

func province_ids() -> PackedStringArray:
	return _province_order


func unit_ids() -> PackedStringArray:
	return _unit_order


func building_ids() -> PackedStringArray:
	return _building_order


func scenarios_sorted() -> Array[ScenarioDef]:
	var out: Array[ScenarioDef] = []
	for s: ScenarioDef in scenarios.values():
		out.append(s)
	out.sort_custom(func(a: ScenarioDef, b: ScenarioDef) -> bool: return a.order < b.order)
	return out


func units_for_culture(culture_id: String) -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for uid: String in _unit_order:
		var u: UnitDef = units[uid]
		if culture_id in u.cultures:
			out.append(u)
	return out


func is_strait(a: String, b: String) -> bool:
	for s: Dictionary in straits:
		if (s["a"] == a and s["b"] == b) or (s["a"] == b and s["b"] == a):
			return true
	return false


## Nome del luogo di culto per una religione e un livello.
func temple_name(religion_id: String, level: int) -> String:
	var r: ReligionDef = religions.get(religion_id)
	if r == null or level < 1 or level > r.temple_names.size():
		return "Luogo di culto"
	return r.temple_names[level - 1]


# ------------------------------------------------------------------ validazione

## Controlla la coerenza di tutti i dati. Restituisce l'elenco degli errori (vuoto = tutto ok).
func validate() -> PackedStringArray:
	var e := PackedStringArray()
	e.append_array(load_errors)
	_validate_factions(e)
	_validate_units(e)
	_validate_buildings(e)
	_validate_provinces(e)
	_validate_scenarios(e)
	return e


func _validate_factions(e: PackedStringArray) -> void:
	for f: FactionDef in factions.values():
		if f.name.is_empty():
			e.append("Fazione %s senza nome" % f.id)
		if not cultures.has(f.culture):
			e.append("Fazione %s: cultura sconosciuta '%s'" % [f.id, f.culture])
		if not religions.has(f.religion):
			e.append("Fazione %s: religione sconosciuta '%s'" % [f.id, f.religion])
		if not f.has_valid_color():
			e.append("Fazione %s: colore non valido '%s'" % [f.id, f.color_text])
	# Ogni cultura usata da una fazione deve avere un esercito completo.
	for c: CultureDef in cultures.values():
		var list: Array[UnitDef] = units_for_culture(c.id)
		if list.size() < 5:
			e.append("Cultura %s: servono almeno 5 tipi di unità (trovati %d)" % [c.id, list.size()])
		var has_melee := false
		var has_ranged := false
		var has_cavalry := false
		for u: UnitDef in list:
			has_ranged = has_ranged or u.is_ranged()
			has_cavalry = has_cavalry or u.is_mounted()
			has_melee = has_melee or (not u.is_ranged() and not u.is_mounted())
		if not (has_melee and has_ranged and has_cavalry):
			e.append("Cultura %s: servono fanteria, unità a distanza e cavalleria" % c.id)


func _validate_units(e: PackedStringArray) -> void:
	for u: UnitDef in units.values():
		var tag: String = "Unità %s" % u.id
		if u.name.is_empty():
			e.append("%s senza nome" % tag)
		if u.cultures.is_empty():
			e.append("%s senza cultura" % tag)
		for c: String in u.cultures:
			if not cultures.has(c):
				e.append("%s: cultura sconosciuta '%s'" % [tag, c])
		if not u.unit_class in Defs.UNIT_CLASSES:
			e.append("%s: classe sconosciuta '%s'" % [tag, u.unit_class])
		if u.men < 20 or u.men > 160:
			e.append("%s: numero di soldati fuori scala (%d)" % [tag, u.men])
		if u.tier < 1 or u.tier > 3:
			e.append("%s: livello fuori scala (%d)" % [tag, u.tier])
		for stat: String in ["attack", "defense", "armor", "charge", "morale", "stamina"]:
			var v: int = u.get(stat)
			if v < 1 or v > 40:
				e.append("%s: %s fuori scala (%d)" % [tag, stat, v])
		if u.speed <= 0.0 or u.speed > 15.0:
			e.append("%s: velocità fuori scala (%.1f)" % [tag, u.speed])
		if u.is_ranged() and (u.ammo <= 0 or u.range_m <= 0.0 or u.missile_damage <= 0):
			e.append("%s: unità a distanza senza munizioni o gittata" % tag)
		if u.ammo > 0 and u.range_m <= 0.0:
			e.append("%s: munizioni senza gittata" % tag)
		if DataUtil.to_int(u.cost, "gold") <= 0:
			e.append("%s: costo in oro mancante" % tag)
		if DataUtil.to_int(u.cost, "manpower") != u.men:
			e.append("%s: il costo in uomini deve essere uguale ai soldati" % tag)
		if u.upkeep <= 0 or u.recruit_turns < 1:
			e.append("%s: mantenimento o turni di reclutamento non validi" % tag)
		_check_requirements(e, tag, u.requires)


func _validate_buildings(e: PackedStringArray) -> void:
	for b: BuildingDef in buildings.values():
		var tag: String = "Edificio %s" % b.id
		if b.levels.is_empty() or b.levels.size() > 5:
			e.append("%s: deve avere da 1 a 5 livelli" % tag)
		var prev_gold: int = 0
		for l: BuildingLevelDef in b.levels:
			var lt: String = "%s livello %d" % [tag, l.level]
			if l.name.is_empty():
				e.append("%s senza nome" % lt)
			var gold: int = DataUtil.to_int(l.cost, "gold")
			if gold <= 0:
				e.append("%s: costo in oro mancante" % lt)
			if gold < prev_gold:
				e.append("%s: costa meno del livello precedente" % lt)
			prev_gold = gold
			for k: String in l.cost:
				if not k in ["gold", "wood", "iron"] or int(l.cost[k]) < 0:
					e.append("%s: costo non valido '%s'" % [lt, k])
			if l.turns < 1 or l.turns > 10:
				e.append("%s: tempo di costruzione non valido (%d)" % [lt, l.turns])
			for k: String in l.effects:
				if not k in Defs.BUILDING_EFFECTS:
					e.append("%s: effetto sconosciuto '%s'" % [lt, k])
			_check_requirements(e, lt, l.requires)


func _check_requirements(e: PackedStringArray, tag: String, reqs: Array[Dictionary]) -> void:
	for r: Dictionary in reqs:
		var bid: String = r["building"]
		var lvl: int = r["level"]
		var b: BuildingDef = buildings.get(bid)
		if b == null:
			e.append("%s: richiede l'edificio sconosciuto '%s'" % [tag, bid])
		elif lvl < 1 or lvl > b.max_level():
			e.append("%s: richiede %s di livello %d che non esiste" % [tag, bid, lvl])


func _validate_provinces(e: PackedStringArray) -> void:
	if provinces.size() < 35:
		e.append("La mappa ha troppe poche province (%d)" % provinces.size())
	var cities: Dictionary = {}
	for p: ProvinceDef in provinces.values():
		var tag: String = "Provincia %s" % p.id
		if p.name.is_empty() or p.city.is_empty():
			e.append("%s senza nome o città" % tag)
		if cities.has(p.city):
			e.append("%s: città '%s' già usata da %s" % [tag, p.city, cities[p.city]])
		cities[p.city] = p.id
		if not p.terrain in Defs.TERRAINS:
			e.append("%s: terreno sconosciuto '%s'" % [tag, p.terrain])
		if p.lat < Defs.MAP_LAT_MIN or p.lat > Defs.MAP_LAT_MAX or p.lon < Defs.MAP_LON_MIN or p.lon > Defs.MAP_LON_MAX:
			e.append("%s: coordinate fuori mappa" % tag)
		if p.population <= 0 or p.fertility < 1 or p.fertility > 5 or p.wealth < 1 or p.wealth > 5:
			e.append("%s: popolazione, fertilità o ricchezza fuori scala" % tag)
		if p.island and not p.coastal:
			e.append("%s: un'isola deve essere costiera" % tag)
		if p.neighbors.is_empty() and not p.island:
			e.append("%s: nessun confine (solo le isole possono non averne)" % tag)
		for n: String in p.neighbors:
			if n == p.id:
				e.append("%s: confina con se stessa" % tag)
			elif not provinces.has(n):
				e.append("%s: confine con provincia sconosciuta '%s'" % [tag, n])
			elif not p.id in provinces[n].neighbors:
				e.append("%s: il confine con %s non è reciproco" % [tag, n])
	for s: Dictionary in straits:
		var a: String = s["a"]
		var b: String = s["b"]
		if not provinces.has(a) or not provinces.has(b):
			e.append("Stretto %s: provincia sconosciuta" % s["name"])
		elif not b in provinces[a].neighbors:
			e.append("Stretto %s: %s e %s devono essere confinanti" % [s["name"], a, b])
	# Tutte le province non isolane devono essere raggiungibili via terra.
	var unreachable: PackedStringArray = _unreachable_provinces()
	for pid: String in unreachable:
		e.append("Provincia %s non raggiungibile via terra" % pid)


func _unreachable_provinces() -> PackedStringArray:
	var out := PackedStringArray()
	if _province_order.is_empty():
		return out
	var seen: Dictionary = {}
	var queue: Array[String] = [_province_order[0]]
	seen[_province_order[0]] = true
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		var p: ProvinceDef = provinces.get(cur)
		if p == null:
			continue
		for n: String in p.neighbors:
			if not seen.has(n) and provinces.has(n):
				seen[n] = true
				queue.append(n)
	for pid: String in _province_order:
		var p: ProvinceDef = provinces[pid]
		if not seen.has(pid) and not (p.island and p.neighbors.is_empty()):
			out.append(pid)
	return out


func _validate_scenarios(e: PackedStringArray) -> void:
	if scenarios.size() < 5:
		e.append("Servono 5 scenari (trovati %d)" % scenarios.size())
	for s: ScenarioDef in scenarios.values():
		var tag: String = "Scenario %s" % s.id
		if s.name.is_empty() or s.description.is_empty():
			e.append("%s: manca nome o descrizione" % tag)
		if not s.season in Defs.SEASONS:
			e.append("%s: stagione sconosciuta '%s'" % [tag, s.season])
		if s.end_year <= s.year:
			e.append("%s: l'anno finale deve seguire quello iniziale" % tag)
		if s.playable.is_empty():
			e.append("%s: nessuna fazione giocabile" % tag)
		var owner: Dictionary = {}
		for sf: ScenarioFactionDef in s.factions.values():
			var ft: String = "%s, fazione %s" % [tag, sf.faction_id]
			if not factions.has(sf.faction_id):
				e.append("%s: fazione sconosciuta" % ft)
			if sf.provinces.is_empty():
				e.append("%s: nessuna provincia" % ft)
			if not sf.capital in sf.provinces:
				e.append("%s: la capitale '%s' non è tra le sue province" % [ft, sf.capital])
			if not sf.religion_override.is_empty() and not religions.has(sf.religion_override):
				e.append("%s: religione sconosciuta '%s'" % [ft, sf.religion_override])
			if not Defs.DIFFICULTIES.has(sf.difficulty):
				e.append("%s: difficoltà sconosciuta '%s'" % [ft, sf.difficulty])
			if DataUtil.to_int(sf.resources, "gold") <= 0:
				e.append("%s: oro iniziale mancante" % ft)
			for pid: String in sf.provinces:
				if not provinces.has(pid):
					e.append("%s: provincia sconosciuta '%s'" % [ft, pid])
				elif owner.has(pid):
					e.append("%s: la provincia %s è già di %s" % [ft, pid, owner[pid]])
				else:
					owner[pid] = sf.faction_id
			for pid: String in sf.victory_provinces:
				if not provinces.has(pid):
					e.append("%s: provincia di vittoria sconosciuta '%s'" % [ft, pid])
			if sf.victory_min_provinces > provinces.size():
				e.append("%s: obiettivo di province impossibile" % ft)
		for pid: String in _province_order:
			if not owner.has(pid):
				e.append("%s: la provincia %s non ha padrone" % [tag, pid])
		for fid: String in s.playable:
			if not s.factions.has(fid):
				e.append("%s: la fazione giocabile %s non è nello scenario" % [tag, fid])
			else:
				var sf: ScenarioFactionDef = s.factions[fid]
				if sf.victory_description.is_empty() or (sf.victory_provinces.is_empty() and sf.victory_min_provinces <= 0):
					e.append("%s: la fazione giocabile %s non ha condizioni di vittoria" % [tag, fid])
		for pair: PackedStringArray in s.wars:
			for fid: String in pair:
				if not s.factions.has(fid):
					e.append("%s: guerra con fazione assente '%s'" % [tag, fid])
		for rel: Dictionary in s.relations:
			if not s.factions.has(rel["a"]) or not s.factions.has(rel["b"]):
				e.append("%s: relazione con fazione assente" % tag)
			if absi(int(rel["value"])) > 100:
				e.append("%s: relazione fuori scala (-100..100)" % tag)
