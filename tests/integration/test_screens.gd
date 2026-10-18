extends GutTest
## Apre ogni schermata in headless e la fa girare per qualche fotogramma:
## qualunque errore di script fa fallire il test.


func _open(path: String, frames: int = 5) -> Node:
	var scene: PackedScene = load(path)
	assert_not_null(scene, path)
	var node: Node = scene.instantiate()
	add_child_autofree(node)
	await wait_physics_frames(frames)
	return node


func _count_type(node: Node, type: String) -> int:
	var n: int = 1 if node.is_class(type) else 0
	for c: Node in node.get_children():
		n += _count_type(c, type)
	return n


func test_main_menu() -> void:
	var n: Node = await _open(Scenes.MAIN_MENU)
	assert_gte(_count_type(n, "Button"), 4, "Nuova partita, Carica, Opzioni, Esci")


func test_new_game_menu_lists_scenarios_and_factions() -> void:
	var n: Node = await _open(Scenes.NEW_GAME)
	# 5 scenari + 6 fazioni del primo scenario + Indietro + Inizia
	assert_gte(_count_type(n, "Button"), 13)


func test_new_game_starts_campaign_state() -> void:
	Session.end_game()
	var err: String = Session.start_new_game("711_hispania_poitiers", "franchi")
	assert_eq(err, "")
	assert_true(Session.has_game())
	assert_eq(Session.state.player().leader, "Carlo Martello")
	Session.end_game()


func test_load_menu_empty_and_with_saves() -> void:
	var old_dir: String = Session.saves_dir
	Session.saves_dir = "user://test_menu_saves"
	await _open(Scenes.LOAD_GAME)
	Session.start_new_game("535_guerra_gotica", "ostrogoti")
	assert_eq(Session.save_current("Prova menu"), "")
	var n: Node = await _open(Scenes.LOAD_GAME)
	assert_gte(_count_type(n, "ItemList"), 1)
	for s: Dictionary in Session.list_saves():
		SaveSystem.delete_save(s["path"])
	DirAccess.remove_absolute(Session.saves_dir)
	Session.saves_dir = old_dir
	Session.end_game()


func test_options_menu() -> void:
	var n: Node = await _open(Scenes.OPTIONS)
	assert_gte(_count_type(n, "OptionButton"), 6)
	assert_gte(_count_type(n, "HSlider"), 4)


func test_campaign_map_opens_and_ends_turn() -> void:
	var old_dir: String = Session.saves_dir
	Session.saves_dir = "user://test_campaign_saves"
	Session.start_new_game("476_caduta_di_roma", "vandali")
	var n: Node = await _open(Scenes.CAMPAIGN, 10)
	var scene := n as CampaignMapScene
	assert_not_null(scene)
	assert_gte(_count_type(n, "MultiMeshInstance3D"), 4, "città per tipo + eserciti")
	assert_eq(_count_type(n, "Label3D"), GameData.db.provinces.size(), "un nome per città")
	assert_eq(scene.army_layer.multimesh.instance_count, Session.state.armies.size())
	# selezione e pannello
	scene.select_province("africa")
	assert_eq(scene.selected, "africa")
	scene.select_province("")
	assert_eq(scene.selected, "")
	# fine turno: calendario, riepilogo, salvataggio automatico
	scene.end_turn()
	await wait_frames(2)
	assert_eq(Session.state.turn, 2)
	assert_true(scene.hud.is_modal_open(), "riepilogo di inizio turno")
	scene.end_turn()
	assert_eq(Session.state.turn, 2, "con una finestra aperta il turno non avanza")
	assert_eq(Session.list_saves().size(), 1)
	for s: Dictionary in Session.list_saves():
		SaveSystem.delete_save(s["path"])
	DirAccess.remove_absolute(Session.saves_dir)
	Session.saves_dir = old_dir
	Session.end_game()



func test_benchmark_runs() -> void:
	var n: Node = await _open(Scenes.BENCHMARK, 20)
	assert_gte(_count_type(n, "MultiMeshInstance3D"), 20, "un MultiMesh per reggimento")
	var soldiers: int = 0
	for c: Node in n.get_children():
		if c is RegimentView:
			soldiers += (c as RegimentView).soldier_count
	var expected: int = Settings.graphics.target_soldiers()
	assert_between(soldiers, int(expected * 0.7), int(expected * 1.1))


func test_soldier_meshes_are_low_poly() -> void:
	var inf: ArrayMesh = LowPolyBuilder.soldier_mesh()
	var cav: ArrayMesh = LowPolyBuilder.cavalry_mesh()
	var tri_inf: int = inf.surface_get_array_len(0)
	assert_gt(tri_inf, 0)
	var idx_inf: int = (inf.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	var idx_cav: int = (cav.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	assert_lt(idx_inf / 3.0, 400.0, "fante sotto i 400 triangoli")
	assert_lt(idx_cav / 3.0, 700.0, "cavaliere sotto i 700 triangoli")


func test_map_benchmark_flies_the_camera() -> void:
	Session.end_game()
	Session.start_map_benchmark()
	assert_true(Session.benchmark_owns_game, "senza partita il test ne crea una di prova")
	var n: Node = await _open(Scenes.CAMPAIGN, 5)
	var scene := n as CampaignMapScene
	assert_not_null(scene.get_node_or_null("TestMappa"))
	assert_false(scene.cam.input_enabled, "durante il test la telecamera non risponde ai comandi")
	var start: Vector3 = scene.cam.camera.global_position
	await wait_frames(30)
	assert_ne(scene.cam.camera.global_position, start, "la telecamera segue il percorso")
	Session.map_benchmark = false
	Session.benchmark_owns_game = false
	Session.end_game()
