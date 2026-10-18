extends GutTest
## Mappa di campagna generata: proiezione, selezione dalla mappa degli id, quote e confini.

var db: GameDatabase
var map: CampaignMapData


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()
	map = CampaignMapData.load_default()


func test_map_resources_load() -> void:
	assert_eq(map.load_error, "")
	assert_true(map.is_valid())
	assert_eq(map.province_order, db.province_ids(), "stesso ordine di provinces.json")
	assert_lte(map.lookup_size().x, 2048, "texture al massimo 2048 px")
	assert_lte(map.lookup_size().y, 2048)


func test_projection_round_trip() -> void:
	for ll: Vector2 in [Vector2(12.5, 41.9), Vector2(-9.0, 38.7), Vector2(44.4, 33.3), Vector2(19.0, 38.0)]:
		var w: Vector2 = map.lonlat_to_world(ll.x, ll.y)
		var back: Vector2 = map.world_to_lonlat(w)
		assert_almost_eq(back.x, ll.x, 0.0001)
		assert_almost_eq(back.y, ll.y, 0.0001)
	# il nord è verso -Z, l'est verso +X
	assert_lt(map.lonlat_to_world(12.0, 50.0).y, map.lonlat_to_world(12.0, 30.0).y)
	assert_lt(map.lonlat_to_world(0.0, 40.0).x, map.lonlat_to_world(20.0, 40.0).x)


func test_every_city_is_inside_its_province() -> void:
	for pid: String in db.province_ids():
		assert_eq(map.province_at(map.city_pos[pid]), pid, "città di %s" % pid)
		assert_eq(map.province_at(map.label_pos[pid]), pid, "etichetta di %s" % pid)
		assert_true(map.is_land(map.city_pos[pid]), "%s è sulla terraferma" % pid)


func test_selection_from_id_map() -> void:
	# Mar Tirreno, mar Ionio e Atlantico: acqua
	for ll: Vector2 in [Vector2(11.5, 40.0), Vector2(19.0, 36.0), Vector2(-11.0, 45.0)]:
		var p: Vector2 = map.lonlat_to_world(ll.x, ll.y)
		assert_eq(map.province_at(p), "", "mare a %s" % ll)
		assert_eq(map.index_at(p), CampaignMapData.SEA)
	# Terre esterne (Russia centrale, Scandinavia meridionale): terra ma fuori dal gioco
	for ll: Vector2 in [Vector2(37.6, 55.5), Vector2(14.0, 55.8)]:
		var p: Vector2 = map.lonlat_to_world(ll.x, ll.y)
		assert_true(map.is_land(p))
		assert_eq(map.index_at(p), CampaignMapData.OUTER_LANDS)
		assert_eq(map.province_at(p), "")
	# Punti noti dentro le province
	var known: Dictionary = {"aegyptus": Vector2(31.2, 30.0), "baetica": Vector2(-5.9, 37.4),
		"thracia": Vector2(27.0, 41.6), "sicilia": Vector2(14.0, 37.5), "sardinia": Vector2(9.1, 42.2)}
	for pid: String in known:
		var ll: Vector2 = known[pid]
		assert_eq(map.province_at(map.lonlat_to_world(ll.x, ll.y)), pid)
	# Fuori dalla mappa
	assert_eq(map.province_at(Vector2(9999, 9999)), "")


func test_heights_and_ray() -> void:
	var rome: Vector2 = map.city_pos["roma"]
	var h: float = map.height_at(rome)
	assert_gt(h, 0.0, "Roma sopra il livello del mare")
	assert_lt(map.height_at(map.lonlat_to_world(18.0, 35.0)), 0.0, "fondale del mare")
	assert_gt(map.height_at(map.lonlat_to_world(7.8, 45.9)), 1.5, "le Alpi sono alte")
	var hit: Variant = map.intersect_ray(Vector3(rome.x, 200.0, rome.y), Vector3.DOWN)
	assert_not_null(hit)
	var p: Vector3 = hit
	assert_almost_eq(p.y, map.surface_at(rome), 0.01)
	# raggio obliquo
	var origin := Vector3(rome.x, 60.0, rome.y + 60.0)
	var dir: Vector3 = (Vector3(rome.x, h, rome.y) - origin).normalized()
	var hit2: Variant = map.intersect_ray(origin, dir)
	assert_not_null(hit2)
	assert_lt((hit2 as Vector3).distance_to(Vector3(rome.x, h, rome.y)), 1.0)
	assert_null(map.intersect_ray(Vector3(0, 50, 0), Vector3.UP), "un raggio verso il cielo non colpisce nulla")


func test_map_borders_match_neighbors() -> void:
	var pairs: Dictionary = map.touching_pairs()
	var straits: Dictionary = {}
	for s: Dictionary in db.straits:
		straits[CampaignState.pair_key(s["a"], s["b"])] = true
	for p: ProvinceDef in db.provinces.values():
		for n: String in p.neighbors:
			var k: String = CampaignState.pair_key(p.id, n)
			if straits.has(k):
				continue
			assert_gte(int(pairs.get(k, 0)), 3, "%s e %s devono toccarsi sulla mappa" % [p.id, n])
	for k: String in pairs:
		var ab: PackedStringArray = k.split("|")
		assert_true(ab[1] in db.provinces[ab[0]].neighbors, "%s e %s si toccano ma non sono confinanti" % [ab[0], ab[1]])
