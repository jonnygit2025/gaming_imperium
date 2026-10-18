extends Node
## Autoload "GameData": carica una sola volta i dati di gioco da res://data.

var db: GameDatabase = null
## Errori trovati nei dati (vuoto = tutto a posto). Mostrati nel menu principale.
var errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	db = GameDatabase.new()
	db.load_all()
	errors = db.validate()
	for e: String in errors:
		push_error("Dati di gioco: %s" % e)


func faction_name(faction_id: String) -> String:
	var f: FactionDef = db.factions.get(faction_id)
	return f.name if f != null else faction_id


func faction_color(faction_id: String) -> Color:
	var f: FactionDef = db.factions.get(faction_id)
	return f.color if f != null else Color.GRAY
