extends GutTest
## I dati veri del gioco devono caricarsi e superare tutti i controlli.

var db: GameDatabase


func before_all() -> void:
	db = GameDatabase.new()
	db.load_all()


func test_loads_without_errors() -> void:
	assert_eq(db.load_errors.size(), 0, "\n".join(db.load_errors))


func test_validation_passes() -> void:
	var errors: PackedStringArray = db.validate()
	assert_eq(errors.size(), 0, "Errori nei dati:\n" + "\n".join(errors))


func test_counts() -> void:
	assert_eq(db.scenarios.size(), 5)
	assert_between(db.provinces.size(), 40, 50)
	assert_gte(db.units.size(), 50)
	assert_gte(db.factions.size(), 15)
	assert_eq(db.cultures.size(), 9)


func test_required_buildings_exist() -> void:
	for bid: String in ["quartieri", "fattoria", "mercato", "caserma", "scuderia", "arceria",
			"fabbro", "mura", "luogo_culto", "porto"]:
		assert_true(db.buildings.has(bid), "manca l'edificio %s" % bid)
	assert_eq(db.buildings["mura"].max_level(), 3, "le mura hanno 3 livelli")


func test_port_only_on_coast() -> void:
	assert_true(db.buildings["porto"].requires_coastal)


func test_unit_types_per_culture() -> void:
	assert_eq(db.units["guerrieri_franchi"].look.get("weapon"), "francisca")
	assert_true(db.units["kataphraktoi"].is_mounted())
	assert_true(db.units["toxotai"].is_ranged())
	var arab: Array[UnitDef] = db.units_for_culture("araba")
	var ids: Array = arab.map(func(u: UnitDef) -> String: return u.id)
	assert_has(ids, "fanteria_berbera", "gli Arabi reclutano fanteria berbera")


func test_scenarios_sorted_by_order() -> void:
	var list: Array[ScenarioDef] = db.scenarios_sorted()
	assert_eq(list[0].year, 476)
	assert_eq(list[4].year, 711)
	for i: int in range(1, list.size()):
		assert_gt(list[i].year, list[i - 1].year)


func test_temple_names_follow_religion() -> void:
	assert_eq(db.temple_name("islamica", 1), "Moschea")
	assert_eq(db.temple_name("cristiana_nicena", 3), "Cattedrale")
	assert_eq(db.temple_name("sconosciuta", 1), "Luogo di culto")


func test_straits() -> void:
	assert_true(db.is_strait("baetica", "tingitana"))
	assert_true(db.is_strait("tingitana", "baetica"))
	assert_false(db.is_strait("roma", "neapolis"))


func test_total_turns() -> void:
	var s: ScenarioDef = db.scenarios["476_caduta_di_roma"]
	assert_eq(s.total_turns(), (s.end_year - s.year) * 2)
