class_name CampaignDetails
extends RefCounted
## Dettagli della mappa di campagna, logica pura (nessun nodo): stile architettonico delle
## città, strade fra le città confinanti, villaggi minori, porti e alberi dei boschi.
## Tutto è generato offline da tools/map/generate_details.py.

const META_PATH: String = "res://data/map/campaign_details.json"
const STYLES: PackedStringArray = ["mediterraneo", "orientale", "settentrionale", "desertico"]
## Valori per albero nel file binario: x, y, z, scala, rotazione, tipo + tinta / 10.
const TREE_FLOATS: int = 6

enum TreeKind { BROADLEAF, CONIFER, PINE }

var styles: Dictionary[String, String] = {}
## Strade: [{a, b, points: PackedVector2Array}]
var roads: Array[Dictionary] = []
var hamlets: Dictionary[String, PackedVector2Array] = {}
## Porti: pid -> Vector3(x, z, angolo verso il mare in radianti)
var ports: Dictionary[String, Vector3] = {}
var road_scale: float = 16.0
var tree_chunk_size: float = 12.0
## Blocchi di alberi: [{rect: Rect2, offset: int, count: int, y_max: float}]
var tree_chunks: Array[Dictionary] = []
var tree_total: int = 0
var load_error: String = ""

var _tree_path: String = ""
var _trees: PackedFloat32Array = []


static func load_default() -> CampaignDetails:
	var d := CampaignDetails.new()
	d.load_file(META_PATH)
	return d


func is_valid() -> bool:
	return load_error.is_empty()


func load_file(path: String) -> bool:
	var res: Dictionary = JsonLoader.load_file(path)
	if not res["ok"] or not res["data"] is Dictionary:
		load_error = "Dettagli della mappa illeggibili: %s" % res.get("error", path)
		return false
	var d: Dictionary = res["data"]
	var st: Dictionary = DataUtil.to_dict(d, "styles")
	for pid: String in st:
		var s: String = str(st[pid])
		styles[pid] = s if s in STYLES else STYLES[0]
	road_scale = DataUtil.to_float(d, "road_scale", road_scale)
	for r: Variant in DataUtil.to_array(d, "roads"):
		if not r is Dictionary:
			continue
		var pts := PackedVector2Array()
		for p: Variant in DataUtil.to_array(r, "points"):
			pts.append(_vec2(p))
		roads.append({"a": DataUtil.to_str(r, "a"), "b": DataUtil.to_str(r, "b"), "points": pts})
	var hm: Dictionary = DataUtil.to_dict(d, "hamlets")
	for pid: String in hm:
		var pts := PackedVector2Array()
		for p: Variant in hm[pid] as Array:
			pts.append(_vec2(p))
		hamlets[pid] = pts
	var pt: Dictionary = DataUtil.to_dict(d, "ports")
	for pid: String in pt:
		var a: Array = pt[pid] as Array
		if a.size() == 3:
			ports[pid] = Vector3(float(a[0]), float(a[1]), float(a[2]))
	var trees_d: Dictionary = DataUtil.to_dict(d, "trees")
	_tree_path = DataUtil.to_str(trees_d, "file")
	tree_chunk_size = DataUtil.to_float(trees_d, "chunk_size", tree_chunk_size)
	tree_total = DataUtil.to_int(trees_d, "total")
	for c: Variant in DataUtil.to_array(trees_d, "chunks"):
		if c is Dictionary:
			tree_chunks.append({
				"rect": Rect2(DataUtil.to_float(c, "x"), DataUtil.to_float(c, "z"), tree_chunk_size, tree_chunk_size),
				"offset": DataUtil.to_int(c, "offset"),
				"count": DataUtil.to_int(c, "count"),
				"y_max": DataUtil.to_float(c, "y_max", 1.0),
			})
	if not _tree_path.is_empty():
		var f := FileAccess.open(_tree_path, FileAccess.READ)
		if f == null:
			load_error = "Alberi della mappa mancanti: %s" % _tree_path
			return false
		_trees = f.get_buffer(f.get_length()).to_float32_array()
		if _trees.size() != tree_total * TREE_FLOATS:
			load_error = "Alberi della mappa incoerenti (%d valori per %d alberi)" % [_trees.size(), tree_total]
			return false
	return true


func style_of(pid: String) -> String:
	return styles.get(pid, STYLES[0])


## Dati grezzi di un albero (vedi TREE_FLOATS).
func tree(i: int) -> PackedFloat32Array:
	return _trees.slice(i * TREE_FLOATS, (i + 1) * TREE_FLOATS)


## Trasformazioni e dati di un blocco nel formato del buffer di MultiMesh
## (TRANSFORM_3D + colori + dati personalizzati: 20 valori per istanza).
## `fraction` = parte degli alberi da usare (densità della vegetazione del preset).
func tree_chunk_buffer(chunk: Dictionary, fraction: float) -> PackedFloat32Array:
	var count: int = mini(int(chunk["count"]), ceili(int(chunk["count"]) * clampf(fraction, 0.0, 1.0)))
	var out := PackedFloat32Array()
	out.resize(count * 20)
	var base: int = int(chunk["offset"]) * TREE_FLOATS
	for i: int in count:
		var j: int = base + i * TREE_FLOATS
		var s: float = _trees[j + 3]
		var yaw: float = _trees[j + 4]
		var code: float = _trees[j + 5]
		var kind: float = floorf(code)
		var c: float = cos(yaw) * s
		var sn: float = sin(yaw) * s
		var o: int = i * 20
		out[o] = c
		out[o + 2] = sn
		out[o + 3] = _trees[j]
		out[o + 5] = s
		out[o + 7] = _trees[j + 1]
		out[o + 8] = -sn
		out[o + 10] = c
		out[o + 11] = _trees[j + 2]
		out[o + 12] = 1.0
		out[o + 13] = 1.0
		out[o + 14] = 1.0
		out[o + 15] = 1.0
		out[o + 16] = (code - kind) * 10.0   # tinta
		out[o + 17] = fposmod(_trees[j] * 7.31 + _trees[j + 2] * 3.17, 1.0)   # fase
		out[o + 19] = kind / 2.0
	return out


static func _vec2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO
