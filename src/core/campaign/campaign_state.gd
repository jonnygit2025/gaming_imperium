class_name CampaignState
extends RefCounted
## Stato completo di una partita di campagna. Logica pura, serializzabile.
## Data, fazioni, padroni delle province, risorse, guerre, relazioni ed eserciti.

const TURNS_PER_YEAR: int = 2

var scenario_id: String = ""
var player_faction: String = ""
var turn: int = 1
var start_year: int = 0
var start_season: int = 0
var end_year: int = 0
var factions: Dictionary[String, FactionState] = {}
## province_id -> faction_id
var province_owner: Dictionary[String, String] = {}
## "a|b" (in ordine alfabetico) -> relazione da -100 a 100
var relations: Dictionary[String, int] = {}
## "a|b" -> true se in guerra
var wars: Dictionary[String, bool] = {}
## army_id -> esercito
var armies: Dictionary[String, ArmyState] = {}


## Restituisce un messaggio di errore, oppure "" se la nuova partita si può creare.
static func check_new_game(db: GameDatabase, scen_id: String, player_faction_id: String) -> String:
	var s: ScenarioDef = db.scenarios.get(scen_id)
	if s == null:
		return "Scenario sconosciuto: %s" % scen_id
	if not player_faction_id in s.playable:
		return "La fazione %s non è giocabile in questo scenario" % player_faction_id
	return ""


## Crea la partita. Chiamare prima check_new_game().
static func new_game(db: GameDatabase, scen_id: String, player_faction_id: String) -> CampaignState:
	var s: ScenarioDef = db.scenarios[scen_id]
	var st := CampaignState.new()
	st.scenario_id = scen_id
	st.player_faction = player_faction_id
	st.turn = 1
	st.start_year = s.year
	st.start_season = Defs.SEASONS.find(s.season)
	st.end_year = s.end_year
	for sf: ScenarioFactionDef in s.factions.values():
		var fdef: FactionDef = db.factions[sf.faction_id]
		var fs := FactionState.new()
		fs.id = sf.faction_id
		fs.display_name = sf.name_override if not sf.name_override.is_empty() else fdef.name
		fs.religion = sf.religion_override if not sf.religion_override.is_empty() else fdef.religion
		fs.capital = sf.capital
		fs.leader = sf.leader
		fs.is_player = sf.faction_id == player_faction_id
		for key: String in ["gold", "food", "wood", "iron"]:
			fs.resources[key] = int(sf.resources.get(key, 0))
		st.factions[fs.id] = fs
		for pid: String in sf.provinces:
			st.province_owner[pid] = sf.faction_id
	for rel: Dictionary in s.relations:
		st.set_relation(rel["a"], rel["b"], rel["value"])
	for pair: PackedStringArray in s.wars:
		st.set_war(pair[0], pair[1], true)
	st.add_starting_armies(db)
	return st


## Aggiunge gli eserciti di partenza dello scenario (usato anche per i salvataggi della Fase 1).
func add_starting_armies(db: GameDatabase) -> void:
	var s: ScenarioDef = db.scenarios.get(scenario_id)
	if s == null:
		return
	for def: ArmyDef in s.armies:
		if factions.has(def.faction) and not armies.has(def.id):
			armies[def.id] = ArmyState.from_def(def, db)


static func pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func relation(a: String, b: String) -> int:
	return relations.get(pair_key(a, b), 0)


func set_relation(a: String, b: String, value: int) -> void:
	relations[pair_key(a, b)] = clampi(value, -100, 100)


func at_war(a: String, b: String) -> bool:
	return wars.get(pair_key(a, b), false)


func set_war(a: String, b: String, value: bool) -> void:
	var k: String = pair_key(a, b)
	if value:
		wars[k] = true
	else:
		wars.erase(k)


# ------------------------------------------------------------------ calendario

func year() -> int:
	return start_year + floori(float(start_season + turn - 1) / TURNS_PER_YEAR)


func season_index() -> int:
	return (start_season + turn - 1) % TURNS_PER_YEAR


func season_name() -> String:
	return Defs.SEASON_NAMES[Defs.SEASONS[season_index()]]


func date_label() -> String:
	return "%s %d d.C." % [season_name(), year()]


## Ultimo turno previsto dallo scenario (poi la partita può continuare, ma è "conclusa").
func last_turn() -> int:
	return maxi(1, (end_year - start_year) * TURNS_PER_YEAR - start_season)


func is_finished() -> bool:
	return turn > last_turn()


# ------------------------------------------------------------------ interrogazioni

func provinces_of(faction_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for pid: String in province_owner:
		if province_owner[pid] == faction_id:
			out.append(pid)
	return out


func player() -> FactionState:
	return factions.get(player_faction)


## Eserciti presenti in una provincia, in ordine di id.
func armies_in(province_id: String) -> Array[ArmyState]:
	var out: Array[ArmyState] = []
	for a: ArmyState in armies.values():
		if a.province == province_id:
			out.append(a)
	out.sort_custom(func(x: ArmyState, y: ArmyState) -> bool: return x.id < y.id)
	return out


func armies_of(faction_id: String) -> Array[ArmyState]:
	var out: Array[ArmyState] = []
	for a: ArmyState in armies.values():
		if a.faction == faction_id:
			out.append(a)
	return out


## Fazioni in guerra con quella indicata.
func enemies_of(faction_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for fid: String in factions:
		if fid != faction_id and at_war(faction_id, fid):
			out.append(fid)
	return out


# ------------------------------------------------------------------ serializzazione

func to_dict() -> Dictionary:
	var facs: Dictionary = {}
	for fid: String in factions:
		facs[fid] = factions[fid].to_dict()
	var army_list: Array = []
	var ids: Array = armies.keys()
	ids.sort()
	for aid: String in ids:
		army_list.append(armies[aid].to_dict())
	return {
		"scenario_id": scenario_id, "player_faction": player_faction, "turn": turn,
		"start_year": start_year, "start_season": start_season, "end_year": end_year,
		"factions": facs, "province_owner": province_owner.duplicate(),
		"relations": relations.duplicate(), "wars": wars.keys(), "armies": army_list,
	}


static func from_dict(d: Dictionary) -> CampaignState:
	var st := CampaignState.new()
	st.scenario_id = DataUtil.to_str(d, "scenario_id")
	st.player_faction = DataUtil.to_str(d, "player_faction")
	st.turn = DataUtil.to_int(d, "turn", 1)
	st.start_year = DataUtil.to_int(d, "start_year")
	st.start_season = DataUtil.to_int(d, "start_season")
	st.end_year = DataUtil.to_int(d, "end_year")
	var facs: Dictionary = DataUtil.to_dict(d, "factions")
	for fid: Variant in facs:
		if facs[fid] is Dictionary:
			var fs: FactionState = FactionState.from_dict(facs[fid])
			st.factions[fs.id] = fs
	var owners: Dictionary = DataUtil.to_dict(d, "province_owner")
	for pid: Variant in owners:
		st.province_owner[str(pid)] = str(owners[pid])
	var rels: Dictionary = DataUtil.to_dict(d, "relations")
	for k: Variant in rels:
		st.relations[str(k)] = int(rels[k])
	for k: Variant in DataUtil.to_array(d, "wars"):
		st.wars[str(k)] = true
	for item: Variant in DataUtil.to_array(d, "armies"):
		if item is Dictionary:
			var a: ArmyState = ArmyState.from_dict(item)
			st.armies[a.id] = a
	return st


## Controlla che lo stato caricato sia compatibile con i dati di gioco attuali.
func check_against(db: GameDatabase) -> String:
	if not db.scenarios.has(scenario_id):
		return "Lo scenario '%s' non esiste più" % scenario_id
	if not factions.has(player_faction):
		return "La fazione del giocatore '%s' manca nel salvataggio" % player_faction
	for pid: String in province_owner:
		if not db.provinces.has(pid):
			return "Provincia sconosciuta nel salvataggio: %s" % pid
		if not factions.has(province_owner[pid]):
			return "Padrone sconosciuto per %s" % pid
	for a: ArmyState in armies.values():
		var err: String = a.check(db, factions.keys())
		if not err.is_empty():
			return err
	return ""
