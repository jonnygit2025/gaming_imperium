class_name TurnReport
extends RefCounted
## Cosa è successo alla fine di un turno: lo mostra il riepilogo di inizio turno.

var from_turn: int = 0
var to_turn: int = 0
var date_label: String = ""
## faction_id -> {"gold": int, "food": int, "wood": int, "iron": int} (entrate del turno)
var income: Dictionary = {}
## Frasi da mostrare al giocatore (eventi, avvisi). Le fasi successive ne aggiungeranno.
var messages: PackedStringArray = []
## true se con questo turno lo scenario ha raggiunto la data di fine.
var scenario_ended: bool = false


func income_of(faction_id: String) -> Dictionary:
	return income.get(faction_id, {"gold": 0, "food": 0, "wood": 0, "iron": 0})
