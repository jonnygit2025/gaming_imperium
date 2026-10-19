class_name TurnProcessor
extends RefCounted
## Fine turno: logica pura, senza nodi (testabile e usata anche dalla simulazione headless).
##
## Ordine delle fasi. Quelle segnate "Fase N" sono punti già pronti in cui le fasi successive
## del piano aggiungeranno le loro regole, senza cambiare il resto:
##   1. entrate          — PROVVISORIE (vedi sotto); la Fase 3 le sostituisce con tasse,
##                         popolazione, ordine pubblico ed edifici
##   2. costruzioni      — Fase 3 (coda degli edifici)
##   3. eserciti         — Fase 4a (mantenimento, reclutamento, movimento, assedi)
##   4. intelligenza artificiale delle fazioni — Fase 4b
##   5. eventi storici e diplomazia            — Fase 4b
##   6. calendario       — avanza di una stagione (2 turni all'anno)
##   7. fine scenario    — segnala quando si supera l'anno finale
##
## Entrate provvisorie per ogni provincia posseduta (valori per turno):
##   oro     = 30 + 25 × ricchezza + popolazione / 8   (+60 nella capitale)
##   cibo    = 20 × fertilità + 15 se produce grano − popolazione / 20
##             ×1,5 in estate (raccolto) e ×0,5 in inverno
##   legname = 12 se produce legname, altrimenti 3
##   ferro   = 10 se produce ferro, +4 se il terreno è montagna
## Le risorse non scendono mai sotto zero.

const GOLD_BASE: int = 30
const GOLD_PER_WEALTH: int = 25
const GOLD_POP_DIVISOR: int = 8
const GOLD_CAPITAL_BONUS: int = 60
const FOOD_PER_FERTILITY: int = 20
const FOOD_GRAIN_BONUS: int = 15
const FOOD_POP_DIVISOR: int = 20
const FOOD_SUMMER_FACTOR: float = 1.5
const FOOD_WINTER_FACTOR: float = 0.5
const WOOD_WITH_TIMBER: int = 12
const WOOD_BASE: int = 3
const IRON_WITH_ORE: int = 10
const IRON_MOUNTAIN_BONUS: int = 4


## Esegue la fine del turno e restituisce il riepilogo.
static func end_turn(state: CampaignState, db: GameDatabase) -> TurnReport:
	var report := TurnReport.new()
	report.from_turn = state.turn
	_phase_income(state, db, report)
	_phase_construction(state, db, report)
	_phase_armies(state, db, report)
	_phase_ai(state, db, report)
	_phase_events(state, db, report)
	_phase_calendar(state, report)
	_phase_scenario_end(state, report)
	return report


## Entrate previste per una fazione nella stagione indicata (0 = estate, 1 = inverno).
static func estimate_income(state: CampaignState, db: GameDatabase, faction_id: String, season: int = -1) -> Dictionary:
	if season < 0:
		season = state.season_index()
	var out: Dictionary = {"gold": 0, "food": 0, "wood": 0, "iron": 0}
	var fs: FactionState = state.factions.get(faction_id)
	if fs == null or not fs.alive:
		return out
	for pid: String in state.provinces_of(faction_id):
		var p: ProvinceDef = db.provinces.get(pid)
		if p == null:
			continue
		var inc: Dictionary = province_income(p, pid == fs.capital, season)
		for k: String in out:
			out[k] = int(out[k]) + int(inc[k])
	return out


## Entrate provvisorie di una provincia (vedi la formula in cima al file).
static func province_income(p: ProvinceDef, is_capital: bool, season: int) -> Dictionary:
	var gold: int = GOLD_BASE + GOLD_PER_WEALTH * p.wealth + floori(float(p.population) / GOLD_POP_DIVISOR)
	if is_capital:
		gold += GOLD_CAPITAL_BONUS
	var food_f: float = FOOD_PER_FERTILITY * p.fertility - float(p.population) / FOOD_POP_DIVISOR
	if p.has_resource("grano"):
		food_f += FOOD_GRAIN_BONUS
	food_f *= FOOD_SUMMER_FACTOR if season == 0 else FOOD_WINTER_FACTOR
	var wood: int = WOOD_WITH_TIMBER if p.has_resource("legname") else WOOD_BASE
	var iron: int = IRON_WITH_ORE if p.has_resource("ferro") else 0
	if p.terrain == "montagna":
		iron += IRON_MOUNTAIN_BONUS
	return {"gold": gold, "food": roundi(food_f), "wood": wood, "iron": iron}


# ------------------------------------------------------------------ fasi

static func _phase_income(state: CampaignState, db: GameDatabase, report: TurnReport) -> void:
	for fid: String in state.factions:
		var fs: FactionState = state.factions[fid]
		if not fs.alive:
			continue
		var inc: Dictionary = estimate_income(state, db, fid)
		for k: String in inc:
			fs.resources[k] = maxi(0, fs.resource(k) + int(inc[k]))
		report.income[fid] = inc


static func _phase_construction(_state: CampaignState, _db: GameDatabase, _report: TurnReport) -> void:
	pass  # Fase 3: avanzamento della coda di costruzione.


static func _phase_armies(_state: CampaignState, _db: GameDatabase, _report: TurnReport) -> void:
	pass  # Fase 4a: mantenimento, reclutamento, movimento e assedi.


static func _phase_ai(_state: CampaignState, _db: GameDatabase, _report: TurnReport) -> void:
	pass  # Fase 4b: decisioni delle fazioni controllate dal computer.


static func _phase_events(_state: CampaignState, _db: GameDatabase, _report: TurnReport) -> void:
	pass  # Fase 4b: eventi storici, diplomazia, condizioni di vittoria.


static func _phase_calendar(state: CampaignState, report: TurnReport) -> void:
	state.turn += 1
	report.to_turn = state.turn
	report.date_label = state.date_label()


static func _phase_scenario_end(state: CampaignState, report: TurnReport) -> void:
	if state.turn == state.last_turn() + 1:
		report.scenario_ended = true
		report.messages.append("Lo scenario è giunto alla data finale (%d d.C.): puoi continuare a giocare." % state.end_year)
