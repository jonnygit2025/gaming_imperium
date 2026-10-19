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


func test_campaign_shadows_only_up_close() -> void:
	Session.start_new_game("476_caduta_di_roma", "odoacre")
	var scene := await _open(Scenes.CAMPAIGN, 5) as CampaignMapScene
	var saved: String = Settings.graphics.shadows
	Settings.graphics.shadows = "alte"
	scene.update_shadows(10.0)
	assert_true(scene.sun.shadow_enabled, "da vicino le ombre ci sono")
	assert_almost_eq(scene.sun.shadow_opacity, 1.0, 0.001)
	assert_lte(scene.sun.directional_shadow_max_distance, Settings.graphics.shadow_distance())
	scene.update_shadows((CampaignMapScene.SHADOW_FULL + CampaignMapScene.SHADOW_OFF) * 0.5)
	assert_between(scene.sun.shadow_opacity, 0.01, 0.99, "sfumano")
	scene.update_shadows(CampaignMapScene.SHADOW_OFF + 1.0)
	assert_false(scene.sun.shadow_enabled, "da lontano niente ombre")
	Settings.graphics.shadows = "disattivate"
	scene.update_shadows(10.0)
	assert_false(scene.sun.shadow_enabled, "il preset senza ombre vale anche da vicino")
	assert_ne(scene.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
			"sulla mappa bastano 2 suddivisioni")
	assert_false(scene.environment.glow_enabled, "niente glow sulla mappa")
	Settings.graphics.shadows = saved
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


func test_campaign_details_trees_and_city_lod() -> void:
	Session.start_new_game("476_caduta_di_roma", "franchi")
	var scene := await _open(Scenes.CAMPAIGN, 5) as CampaignMapScene
	var layer: DetailLayer = scene.detail_layer
	assert_not_null(layer)
	# alberi: preparati su altri thread, poi messi in scena vicino alla telecamera
	var forest: Vector2 = scene.map.city_pos["austrasia"] + Vector2(-6.0, 4.0)
	var cam_pos := Vector3(forest.x, 8.0, forest.y + 6.0)
	var before: int = layer.tree_chunks_built()
	for _i: int in 40:
		layer.update_trees(cam_pos)
		await wait_process_frames(1)
		if layer.tree_chunks_built() > before + 2:
			break
	assert_gt(layer.tree_chunks_built(), before, "blocchi di alberi costruiti vicino alla telecamera")
	# città: modello semplice da lontano, dettagliato da vicino
	scene.settlements.update_labels(0.9)
	assert_true(scene.settlements.lod_active, "da lontano le città semplici")
	scene.settlements.update_labels(0.05)
	assert_false(scene.settlements.lod_active, "da vicino le città dettagliate")
	# villaggi e porti nascosti da lontano
	layer.update_zoom(400.0)
	assert_false((layer.get_node("Porti") as Node3D).visible)
	layer.update_zoom(40.0)
	assert_true((layer.get_node("Porti") as Node3D).visible)
	Session.end_game()


func test_campaign_terrain_tiers() -> void:
	Session.start_new_game("476_caduta_di_roma", "odoacre")
	var scene := await _open(Scenes.CAMPAIGN, 6) as CampaignMapScene
	scene.update_terrain_material(20.0)
	assert_eq(scene.terrain_node.material_override, scene.terrain_material, "da vicino: shader completo")
	assert_eq(scene.terrain_node.mesh, scene.terrain_mesh_full)
	scene.update_terrain_material(100.0)
	assert_eq(scene.terrain_node.material_override, scene.terrain_mid_material, "media distanza: solo strade")
	assert_eq(scene.terrain_node.mesh, scene.terrain_mesh_full)
	scene.update_terrain_material(300.0)
	assert_eq(scene.terrain_node.material_override, scene.terrain_far_material, "da lontano: niente dettagli")
	assert_eq(scene.terrain_node.mesh, scene.terrain_mesh_far, "da lontano: terreno semplificato")
	# isteresi: appena sotto il confine resta lontano, ben sotto torna medio
	scene.update_terrain_material(CampaignMapScene.TERRAIN_MID_MAX - 1.0)
	assert_eq(scene.terrain_node.material_override, scene.terrain_far_material)
	scene.update_terrain_material(CampaignMapScene.TERRAIN_MID_MAX - 10.0)
	assert_eq(scene.terrain_node.material_override, scene.terrain_mid_material)
	var far_tris: int = (scene.terrain_mesh_far.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >> 0
	assert_lt(far_tris, 300000, "terreno lontano semplificato (indici: meno di 100.000 triangoli)")
	Session.end_game()
