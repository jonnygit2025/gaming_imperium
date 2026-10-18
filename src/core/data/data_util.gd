class_name DataUtil
extends RefCounted
## Conversioni sicure dai valori JSON (dove tutti i numeri sono float).


static func to_int(d: Dictionary, key: String, default: int = 0) -> int:
	var v: Variant = d.get(key, default)
	if v is float or v is int:
		return int(v)
	return default


static func to_float(d: Dictionary, key: String, default: float = 0.0) -> float:
	var v: Variant = d.get(key, default)
	if v is float or v is int:
		return float(v)
	return default


static func to_str(d: Dictionary, key: String, default: String = "") -> String:
	var v: Variant = d.get(key, default)
	return v if v is String else default


static func to_bool(d: Dictionary, key: String, default: bool = false) -> bool:
	var v: Variant = d.get(key, default)
	return v if v is bool else default


static func to_strings(d: Dictionary, key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var v: Variant = d.get(key, [])
	if v is Array:
		for item: Variant in v:
			if item is String:
				out.append(item)
	return out


static func to_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return v if v is Dictionary else {}


static func to_array(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	return v if v is Array else []


## Dizionario di costi/effetti con valori interi.
static func int_map(d: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	var src: Dictionary = to_dict(d, key)
	for k: Variant in src:
		var v: Variant = src[k]
		if (v is float or v is int) and k is String:
			out[k] = int(v)
	return out


## Dizionario di effetti con valori decimali.
static func float_map(d: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	var src: Dictionary = to_dict(d, key)
	for k: Variant in src:
		var v: Variant = src[k]
		if (v is float or v is int) and k is String:
			out[k] = float(v)
	return out


## Elenco di requisiti [{building, level}].
static func requirements(d: Dictionary, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in to_array(d, key):
		if item is Dictionary:
			out.append({"building": to_str(item, "building"), "level": to_int(item, "level", 1)})
	return out
