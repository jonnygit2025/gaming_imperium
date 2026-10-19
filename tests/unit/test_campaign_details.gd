extends GutTest
## Dettagli della mappa di campagna (tools/map/generate_details.py): stili delle città, strade,
## villaggi minori, porti e alberi.

var db: GameDatabase
var map: CampaignMapData
var det: CampaignDetails


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()
	map = CampaignMapData.load_default()
	det = CampaignDetails.load_default()


func test_details_load() -> void:
	assert_eq(det.load_error, "")
	assert_true(det.is_valid())
	assert_gt(det.tree_total, 10000, "i boschi hanno alberi")
	assert_gt(det.tree_chunks.size(), 100)


func test_every_province_has_a_style() -> void:
	for pid: String in db.province_ids():
		assert_true(det.styles.has(pid), "stile di %s" % pid)
		assert_true(det.style_of(pid) in CampaignDetails.STYLES)
	# qualche controllo storico-geografico
	assert_eq(det.style_of("roma"), "mediterraneo")
	assert_eq(det.style_of("thracia"), "orientale")
	assert_eq(det.style_of("parisii"), "settentrionale")
	assert_eq(det.style_of("asoristan"), "desertico")


func test_roads_join_neighbouring_cities() -> void:
	assert_gt(det.roads.size(), 60)
	for r: Dictionary in det.roads:
		var a: String = r["a"]
		var b: String = r["b"]
		var p: ProvinceDef = db.provinces[a]
		assert_true(b in p.neighbors, "strada fra province confinanti: %s-%s" % [a, b])
		var pts: PackedVector2Array = r["points"]
		assert_gt(pts.size(), 1)
		# parte da una città e arriva all'altra (a meno di qualche chilometro)
		var ends: Array = [pts[0], pts[pts.size() - 1]]
		var near_a: bool = ends.any(func(e: Vector2) -> bool: return e.distance_to(map.city_pos[a]) < 1.0)
		var near_b: bool = ends.any(func(e: Vector2) -> bool: return e.distance_to(map.city_pos[b]) < 1.0)
		assert_true(near_a and near_b, "estremi della strada %s-%s" % [a, b])
		# tutta sulla terraferma (tolleranza: punti a meno di 3 km dalla costa)
		var wet: int = 0
		for q: Vector2 in pts:
			if not map.is_land(q):
				wet += 1
		assert_lte(wet, 2, "la strada %s-%s non attraversa il mare" % [a, b])


func test_no_roads_across_straits() -> void:
	for pair: Array in [["apulia", "sicilia"], ["baetica", "tingitana"], ["galatia", "thracia"]]:
		for r: Dictionary in det.roads:
			var same: bool = (r["a"] == pair[0] and r["b"] == pair[1]) or (r["a"] == pair[1] and r["b"] == pair[0])
			assert_false(same, "lo stretto %s-%s si attraversa per mare" % pair)


func test_hamlets_inside_their_province() -> void:
	var total: int = 0
	for pid: String in det.hamlets:
		for h: Vector2 in det.hamlets[pid]:
			total += 1
			assert_eq(map.province_at(h), pid, "villaggio di %s nella sua provincia" % pid)
			assert_gt(h.distance_to(map.city_pos[pid]), 3.0, "lontano dalla città")
	assert_gt(total, 60)


func test_ports_in_the_sea_near_coastal_cities() -> void:
	assert_gt(det.ports.size(), 15)
	for pid: String in det.ports:
		var p: Vector3 = det.ports[pid]
		assert_true(db.provinces[pid].coastal, "%s ha la costa" % pid)
		assert_false(map.is_land(Vector2(p.x, p.y)), "il molo di %s è in acqua" % pid)
		assert_lt(Vector2(p.x, p.y).distance_to(map.city_pos[pid]), 4.5, "porto vicino alla città di %s" % pid)


func test_tree_chunks_are_consistent() -> void:
	var total: int = 0
	for c: Dictionary in det.tree_chunks:
		total += int(c["count"])
	assert_eq(total, det.tree_total)
	var c0: Dictionary = det.tree_chunks[det.tree_chunks.size() >> 1]
	var full: PackedFloat32Array = det.tree_chunk_buffer(c0, 1.0)
	assert_eq(full.size(), int(c0["count"]) * 20, "20 valori per istanza (trasformazione, colore, dati)")
	var half: PackedFloat32Array = det.tree_chunk_buffer(c0, 0.5)
	assert_eq(half.size(), ceili(int(c0["count"]) * 0.5) * 20, "meno vegetazione = meno alberi")
	var r: Rect2 = c0["rect"]
	for i: int in int(c0["count"]):
		var x: float = full[i * 20 + 3]
		var z: float = full[i * 20 + 11]
		assert_true(r.grow(0.01).has_point(Vector2(x, z)), "albero dentro il suo blocco")
		assert_gte(full[i * 20 + 7], -0.05, "albero appoggiato al terreno, non sott'acqua")
		var kind: float = full[i * 20 + 19]
		assert_true(kind in [0.0, 0.5, 1.0], "tipo di albero valido")
