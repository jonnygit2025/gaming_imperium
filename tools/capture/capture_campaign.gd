extends Node
## Fotografie della mappa di campagna per la verifica visiva (non incluso nel gioco).
## Uso (Linux, senza schermo):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 \
##     --rendering-method gl_compatibility --resolution 1600x900 --write-movie /tmp/x.avi \
##     --fixed-fps 30 res://tools/capture/capture_campaign.tscn -- --out=/tmp/foto [--scenario=..:..]

var _out: String = "user://foto"
var _scene: CampaignMapScene = null
var _grey: bool = false


func _ready() -> void:
	var scen: String = "476_caduta_di_roma:odoacre"
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--scenario="):
			scen = a.trim_prefix("--scenario=")
		elif a.begins_with("--solo="):
			only = a.trim_prefix("--solo=")
		elif a == "--grigio":
			_grey = true
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.graphics.apply_preset("alto")
	Settings.graphics.window_mode = "finestra"
	Settings.graphics.resolution = Vector2i(1600, 900)
	Settings.apply()
	Session.autosave_enabled = false
	var parts: PackedStringArray = scen.split(":")
	var err: String = Session.start_new_game(parts[0], parts[1])
	if not err.is_empty():
		push_error(err)
		get_tree().quit(1)
		return
	_scene = load(Scenes.CAMPAIGN).instantiate()
	add_child(_scene)
	await _frames(5)
	_scene.cam.edge_scroll = false
	print("caricamento della mappa: %.0f ms" % _scene.load_ms)
	_scene.terrain_material.set_shader_parameter("debug_grey", _grey)
	var shots: Array = [
		["01_vista_insieme", func() -> void: _cam(_scene.map.bounds.get_center(), CampaignCamera.MAX_DISTANCE, 0.0)],
		["02_italia", func() -> void: _cam(_city("roma"), 95.0, 0.0)],
		["03_roma_vicino", func() -> void: _cam(_city("roma") + Vector2(0.5, 0.5), 9.0, 0.35)],
		["04_selezione_pannello", func() -> void:
			_cam(_city("ravenna"), 60.0, 0.0)
			_scene.select_province("ravenna")],
		["05_costantinopoli", func() -> void:
			_scene.select_province("")
			_cam(_city("thracia"), 22.0, -0.4)],
		["06_alpi", func() -> void: _cam(Vector2(-75, -88), 40.0, 0.5)],
		["07_oriente", func() -> void: _cam(_city("syria"), 120.0, 0.0)],
		["08_fine_turno", func() -> void:
			_cam(_city("ravenna"), 140.0, 0.0)
			_scene.end_turn()],
		["09_inverno_alpi", func() -> void:
			_scene.hud._close_modal()
			_cam(Vector2(-75, -88), 40.0, 0.5)],
		["10_pausa", func() -> void: _scene.hud.open_pause_menu()],
	]
	for s: Array in shots:
		if not only.is_empty() and not (s[0] as String).begins_with(only):
			continue
		(s[1] as Callable).call()
		await _frames(20)
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_out.path_join("%s.png" % s[0]))
		print("foto: %s · %d chiamate di disegno · %d triangoli · memoria video %.0f MB (texture %.0f MB)" % [s[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
	get_tree().quit()


func _city(pid: String) -> Vector2:
	return _scene.map.city_pos[pid]


func _cam(p: Vector2, dist: float, yaw: float) -> void:
	_scene.cam.set_yaw(yaw, true)
	_scene.cam.look_at_point(p, dist, true)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
