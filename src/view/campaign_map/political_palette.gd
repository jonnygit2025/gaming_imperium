class_name PoliticalPalette
extends RefCounted
## Piccola texture 256×2 letta dallo shader del terreno e dalla minimappa.
## Riga 0: colore del padrone di ogni provincia (indice = colonna) e indice del padrone in A.
## Riga 1: R = provincia di una fazione in guerra col giocatore, G = provincia del giocatore.
## Cambiare il padrone di una provincia costa la scrittura di due pixel: nessuna mesh si ricostruisce.

const WIDTH: int = 256

var image: Image = null
var texture: ImageTexture = null
## faction_id -> 1..N (per distinguere fazioni con colori simili)
var faction_index: Dictionary[String, int] = {}

var _map: CampaignMapData = null
var _state: CampaignState = null


func _init() -> void:
	image = Image.create_empty(WIDTH, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(image)


func rebuild(state: CampaignState, map: CampaignMapData) -> void:
	_state = state
	_map = map
	faction_index.clear()
	var ids: Array = state.factions.keys()
	ids.sort()
	for i: int in ids.size():
		faction_index[ids[i]] = i + 1
	image.fill(Color(0, 0, 0, 0))
	for pid: String in map.province_order:
		_write(pid)
	texture.update(image)


## Aggiorna il padrone di una provincia (già scritto nello stato).
func refresh_province(pid: String) -> void:
	if _state == null:
		return
	_write(pid)
	texture.update(image)


## Aggiorna le province nemiche/amiche (es. dopo una dichiarazione di guerra).
func refresh_all() -> void:
	if _state != null:
		rebuild(_state, _map)


func _write(pid: String) -> void:
	var idx: int = _map.index_of.get(pid, 0)
	if idx <= 0 or idx >= WIDTH:
		return
	var owner_id: String = _state.province_owner.get(pid, "")
	var c: Color = GameData.faction_color(owner_id)
	var fi: int = faction_index.get(owner_id, 0)
	image.set_pixel(idx, 0, Color(c.r, c.g, c.b, fi / 255.0))
	var enemy: bool = _state.at_war(_state.player_faction, owner_id)
	var mine: bool = owner_id == _state.player_faction
	image.set_pixel(idx, 1, Color(1.0 if enemy else 0.0, 1.0 if mine else 0.0, 0.0, 1.0))
