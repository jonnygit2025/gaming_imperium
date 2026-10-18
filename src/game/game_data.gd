extends Node
## Autoload "GameData": carica una sola volta i dati di gioco da res://data.

var db: GameDatabase = null
## Errori trovati nei dati (vuoto = tutto a posto). Mostrati nel menu principale.
var errors: PackedStringArray = []

var _map: CampaignMapData = null


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


## Geometria della mappa di campagna (caricata la prima volta che serve).
func map_data() -> CampaignMapData:
	if _map == null:
		_map = CampaignMapData.load_default()
		if not _map.load_error.is_empty():
			push_error(_map.load_error)
	return _map
