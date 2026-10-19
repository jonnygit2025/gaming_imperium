class_name CampaignMapData
extends RefCounted
## Geometria della mappa di campagna, logica pura (nessun nodo): proiezione, ricerca della
## provincia nella "mappa degli id", quote del terreno e intersezione di un raggio col terreno.
## I file sono generati offline da tools/map/ (vedi assets/map/README.md).
##
## Coordinate del mondo: 1 unità = 10 km; X verso est, Z verso sud, Y in alto (0 = mare).

const META_PATH: String = "res://data/map/campaign_map.json"
const LOOKUP_PATH: String = "res://assets/map/province_lookup.res"
const HEIGHTS_PATH: String = "res://assets/map/heights.res"
## Valori speciali della mappa degli id.
const SEA: int = 0
const OUTER_LANDS: int = 255

var lon0: float = 19.0
var lat0: float = 38.0
var km_per_degree: float = 111.19
var unit_km: float = 10.0
var cos_lat0: float = 1.0
var vertical_units_per_km: float = 0.6
## Rettangolo del mondo in (x, z).
var bounds: Rect2 = Rect2()
var province_order: PackedStringArray = []
var index_of: Dictionary[String, int] = {}
var city_pos: Dictionary[String, Vector2] = {}
var label_pos: Dictionary[String, Vector2] = {}
var province_rect: Dictionary[String, Rect2] = {}
var area_km2: Dictionary[String, int] = {}
var load_error: String = ""

var _lookup_w: int = 0
var _lookup_h: int = 0
var _lookup: PackedByteArray = []
var _heights_w: int = 0
var _heights_h: int = 0
var _heights: PackedFloat32Array = []
var max_height: float = 0.0


static func load_default() -> CampaignMapData:
	var m := CampaignMapData.new()
	m.load_files(META_PATH, LOOKUP_PATH, HEIGHTS_PATH)
	return m


func is_valid() -> bool:
	return load_error.is_empty() and not _lookup.is_empty() and not _heights.is_empty()


func load_files(meta_path: String, lookup_path: String, heights_path: String) -> bool:
	var res: Dictionary = JsonLoader.load_file(meta_path)
	if not res["ok"] or not res["data"] is Dictionary:
		load_error = "Dati della mappa illeggibili: %s" % res.get("error", meta_path)
		return false
	var d: Dictionary = res["data"]
	var proj: Dictionary = DataUtil.to_dict(d, "projection")
	lon0 = DataUtil.to_float(proj, "lon0", lon0)
	lat0 = DataUtil.to_float(proj, "lat0", lat0)
	km_per_degree = DataUtil.to_float(proj, "km_per_degree", km_per_degree)
	unit_km = DataUtil.to_float(proj, "unit_km", unit_km)
	cos_lat0 = DataUtil.to_float(proj, "cos_lat0", cos(deg_to_rad(lat0)))
	vertical_units_per_km = DataUtil.to_float(proj, "vertical_units_per_km", vertical_units_per_km)
	var w: Dictionary = DataUtil.to_dict(d, "world")
	var x0: float = DataUtil.to_float(w, "x_min")
	var z0: float = DataUtil.to_float(w, "z_min")
	bounds = Rect2(x0, z0, DataUtil.to_float(w, "x_max") - x0, DataUtil.to_float(w, "z_max") - z0)
	province_order = DataUtil.to_strings(d, "province_order")
	var provs: Dictionary = DataUtil.to_dict(d, "provinces")
	for pid: String in province_order:
		var p: Dictionary = DataUtil.to_dict(provs, pid)
		index_of[pid] = DataUtil.to_int(p, "index")
		city_pos[pid] = _vec2(DataUtil.to_array(p, "city"))
		label_pos[pid] = _vec2(DataUtil.to_array(p, "label"))
		var b: Array = DataUtil.to_array(p, "bounds")
		if b.size() == 4:
			province_rect[pid] = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
		area_km2[pid] = DataUtil.to_int(p, "area_km2")
	var lookup: Image = load(lookup_path) as Image
	var heights: Image = load(heights_path) as Image
	if lookup == null or heights == null:
		load_error = "Mancano le risorse della mappa (esegui tools/map/build_map.sh)"
		return false
	if lookup.get_format() != Image.FORMAT_RG8 or heights.get_format() != Image.FORMAT_RF:
		load_error = "Formato delle risorse della mappa non valido"
		return false
	_lookup_w = lookup.get_width()
	_lookup_h = lookup.get_height()
	_lookup = lookup.get_data()
	_heights_w = heights.get_width()
	_heights_h = heights.get_height()
	_heights = heights.get_data().to_float32_array()
	for v: float in _heights:
		max_height = maxf(max_height, v)
	return true


static func _vec2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO


# ------------------------------------------------------------------ proiezione

func lonlat_to_world(lon: float, lat: float) -> Vector2:
	return Vector2((lon - lon0) * km_per_degree * cos_lat0 / unit_km, (lat0 - lat) * km_per_degree / unit_km)


func world_to_lonlat(p: Vector2) -> Vector2:
	return Vector2(lon0 + p.x * unit_km / (km_per_degree * cos_lat0), lat0 - p.y * unit_km / km_per_degree)


## (0,0) = angolo nord-ovest della mappa, (1,1) = angolo sud-est.
func world_to_uv(p: Vector2) -> Vector2:
	return (p - bounds.position) / bounds.size


func uv_to_world(uv: Vector2) -> Vector2:
	return bounds.position + uv * bounds.size


func lookup_size() -> Vector2i:
	return Vector2i(_lookup_w, _lookup_h)


## Coppie di province che si toccano sulla mappa (4 direzioni, solo terra):
## { "a|b" (ordine alfabetico): numero di pixel di contatto }. Serve ai test di coerenza.
func touching_pairs() -> Dictionary:
	var counts: Dictionary = {}
	var w: int = _lookup_w
	var data: PackedByteArray = _lookup
	for y: int in _lookup_h:
		var row: int = y * w
		for x: int in w:
			var i: int = (row + x) * 2
			if data[i + 1] == 0:
				continue
			var a: int = data[i]
			if a == SEA or a == OUTER_LANDS:
				continue
			if x + 1 < w:
				var j: int = i + 2
				if data[j + 1] != 0:
					var b: int = data[j]
					if b != a and b != SEA and b != OUTER_LANDS:
						var k: int = mini(a, b) * 256 + maxi(a, b)
						counts[k] = int(counts.get(k, 0)) + 1
			if y + 1 < _lookup_h:
				var j2: int = i + w * 2
				if data[j2 + 1] != 0:
					var b2: int = data[j2]
					if b2 != a and b2 != SEA and b2 != OUTER_LANDS:
						var k2: int = mini(a, b2) * 256 + maxi(a, b2)
						counts[k2] = int(counts.get(k2, 0)) + 1
	var out: Dictionary = {}
	for k: int in counts:
		var pa: String = id_for_index(floori(k / 256.0))
		var pb: String = id_for_index(k % 256)
		out[CampaignState.pair_key(pa, pb)] = counts[k]
	return out


# ------------------------------------------------------------------ province

## Indice della provincia nel pixel (0 = mare, 255 = terre esterne, 1..N = province).
func index_at_pixel(px: int, py: int) -> int:
	if px < 0 or py < 0 or px >= _lookup_w or py >= _lookup_h:
		return SEA
	var i: int = (py * _lookup_w + px) * 2
	if _lookup[i + 1] == 0:
		return SEA
	return _lookup[i]


func index_at(p: Vector2) -> int:
	var uv: Vector2 = world_to_uv(p)
	return index_at_pixel(floori(uv.x * _lookup_w), floori(uv.y * _lookup_h))


func id_for_index(index: int) -> String:
	if index < 1 or index > province_order.size():
		return ""
	return province_order[index - 1]


## Id della provincia nel punto del mondo, "" per mare e terre esterne.
func province_at(p: Vector2) -> String:
	return id_for_index(index_at(p))


func is_land(p: Vector2) -> bool:
	var uv: Vector2 = world_to_uv(p)
	var px: int = floori(uv.x * _lookup_w)
	var py: int = floori(uv.y * _lookup_h)
	if px < 0 or py < 0 or px >= _lookup_w or py >= _lookup_h:
		return false
	return _lookup[(py * _lookup_w + px) * 2 + 1] != 0


# ------------------------------------------------------------------ quote

## Quota del terreno (interpolata); sotto zero in mare.
func height_at(p: Vector2) -> float:
	if _heights.is_empty():
		return 0.0
	var uv: Vector2 = world_to_uv(p)
	var fx: float = clampf(uv.x * _heights_w - 0.5, 0.0, _heights_w - 1.001)
	var fy: float = clampf(uv.y * _heights_h - 0.5, 0.0, _heights_h - 1.001)
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var tx: float = fx - x0
	var ty: float = fy - y0
	var i: int = y0 * _heights_w + x0
	var a: float = lerpf(_heights[i], _heights[i + 1], tx)
	var b: float = lerpf(_heights[i + _heights_w], _heights[i + _heights_w + 1], tx)
	return lerpf(a, b, ty)


## Quota della superficie visibile: terreno o acqua (il mare è a quota 0).
func surface_at(p: Vector2) -> float:
	return maxf(height_at(p), 0.0)


## Punto in cui un raggio colpisce terreno o mare, oppure null.
## Avanza a piccoli passi nello strato che contiene il rilievo, poi affina per bisezione.
func intersect_ray(origin: Vector3, dir: Vector3, max_dist: float = 5000.0) -> Variant:
	if dir.y >= -0.0001:
		return null
	var top: float = max_height + 0.05
	var t: float = 0.0
	if origin.y > top:
		t = (top - origin.y) / dir.y
	var step: float = 0.15
	var prev_t: float = t
	var area: Rect2 = bounds.grow(50.0)
	while t < max_dist:
		var q: Vector3 = origin + dir * t
		if not area.has_point(Vector2(q.x, q.z)) and t > 0.0 and q.y < top:
			return null
		if q.y <= surface_at(Vector2(q.x, q.z)):
			var lo: float = prev_t
			var hi: float = t
			for _i: int in 12:
				var mid: float = (lo + hi) * 0.5
				var m: Vector3 = origin + dir * mid
				if m.y <= surface_at(Vector2(m.x, m.z)):
					hi = mid
				else:
					lo = mid
			return origin + dir * hi
		prev_t = t
		t += step
	return null
