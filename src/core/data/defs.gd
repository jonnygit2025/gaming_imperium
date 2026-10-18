class_name Defs
extends RefCounted
## Costanti condivise dalle definizioni di gioco.

const UNIT_CLASSES: PackedStringArray = [
	"fanteria_leggera", "fanteria_pesante", "lancieri", "arcieri",
	"schermagliatori", "cavalleria_leggera", "cavalleria_pesante", "arcieri_cavallo",
]
const UNIT_CLASS_NAMES: Dictionary = {
	"fanteria_leggera": "Fanteria leggera",
	"fanteria_pesante": "Fanteria pesante",
	"lancieri": "Lancieri",
	"arcieri": "Arcieri",
	"schermagliatori": "Schermagliatori",
	"cavalleria_leggera": "Cavalleria leggera",
	"cavalleria_pesante": "Cavalleria pesante",
	"arcieri_cavallo": "Arcieri a cavallo",
}
const RANGED_CLASSES: PackedStringArray = ["arcieri", "schermagliatori", "arcieri_cavallo"]
const MOUNTED_CLASSES: PackedStringArray = ["cavalleria_leggera", "cavalleria_pesante", "arcieri_cavallo"]

const TERRAINS: PackedStringArray = ["pianura", "colline", "montagna", "bosco", "paludi", "deserto"]
const TERRAIN_NAMES: Dictionary = {
	"pianura": "Pianura", "colline": "Colline", "montagna": "Montagna",
	"bosco": "Bosco", "paludi": "Paludi", "deserto": "Deserto",
}
const SEASONS: PackedStringArray = ["estate", "inverno"]
const SEASON_NAMES: Dictionary = {"estate": "Estate", "inverno": "Inverno"}

const RESOURCES: PackedStringArray = ["gold", "food", "wood", "iron", "manpower"]
const RESOURCE_NAMES: Dictionary = {
	"gold": "Oro", "food": "Cibo", "wood": "Legname", "iron": "Ferro",
	"manpower": "Uomini", "public_order": "Ordine pubblico", "faith": "Fede",
}

const BUILDING_EFFECTS: PackedStringArray = [
	"pop_growth", "tax_bonus", "building_slots", "public_order", "food", "gold", "wood", "iron",
	"recruit_slots", "unit_experience", "unit_armor_bonus", "wall_level", "garrison", "faith",
	"sea_transport",
]
const DIFFICULTIES: Dictionary = {"facile": "Facile", "media": "Media", "difficile": "Difficile"}

## Limiti della mappa (gradi) entro cui devono stare le città.
const MAP_LAT_MIN: float = 20.0
const MAP_LAT_MAX: float = 56.0
const MAP_LON_MIN: float = -12.0
const MAP_LON_MAX: float = 50.0
