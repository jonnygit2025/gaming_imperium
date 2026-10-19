extends Node
## Prove A/B delle prestazioni della mappa di campagna (non incluso nel gioco).
## Per tre inquadrature misura il tempo per fotogramma togliendo una voce alla volta
## (ombre, MSAA, glow, mare, nomi, nebbia). Con llvmpipe i valori assoluti non contano:
## conta quanto pesa ogni voce rispetto alle altre.
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 \
##   --rendering-method gl_compatibility --resolution 1600x900 res://tools/capture/perf_ab.tscn

var _scene: CampaignMapScene = null


func _ready() -> void:
	Settings.graphics.apply_preset("alto")
	Settings.graphics.window_mode = "finestra"
	Settings.graphics.resolution = Vector2i(1600, 900)
	Settings.graphics.vsync = false
	Settings.graphics.max_fps = 0
	Settings.apply()
	Session.autosave_enabled = false
	var err: String = Session.start_new_game("476_caduta_di_roma", "odoacre")
	if not err.is_empty():
		push_error(err)
		get_tree().quit(1)
		return
	_scene = load(Scenes.CAMPAIGN).instantiate()
	add_child(_scene)
	await _frames(5)
	_scene.cam.edge_scroll = false
	_scene.cam.input_enabled = false
	var views: Array = [
		["insieme", _scene.map.bounds.get_center(), CampaignCamera.MAX_DISTANCE],
		["italia", _scene.map.city_pos["roma"], 95.0],
		["roma", _scene.map.city_pos["roma"], 12.0],
	]
	var variants: Array = ["base", "senza_ombre", "senza_msaa", "senza_glow", "senza_mare", "senza_nomi", "senza_nebbia", "tutto_via"]
	for v: Array in views:
		_scene.cam.set_yaw(0.0, true)
		_scene.cam.look_at_point(v[1], v[2], true)
		var line: String = "%-8s" % v[0]
		var base_ms: float = 0.0
		for variant: String in variants:
			_set_variant(variant)
			await _frames(3)
			var t0: int = Time.get_ticks_usec()
			await _frames(4)
			var ms: float = (Time.get_ticks_usec() - t0) / 4000.0
			if variant == "base":
				base_ms = ms
				line += " base %.0f ms |" % ms
			else:
				line += " %s %+.0f%% |" % [variant, (ms - base_ms) / base_ms * 100.0]
			line += " [%d dc, %d tri]" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)]
		_set_variant("base")
		print(line)
	get_tree().quit()


func _set_variant(v: String) -> void:
	var all_off: bool = v == "tutto_via"
	var vp: Viewport = get_viewport()
	if v == "senza_ombre" or all_off:
		_scene.sun.shadow_enabled = false
	else:
		_scene.update_shadows(_scene.cam.distance)
	vp.msaa_3d = Viewport.MSAA_DISABLED if (v == "senza_msaa" or all_off) else Viewport.MSAA_2X
	_scene.environment.glow_enabled = not (v == "senza_glow" or all_off)
	_scene.water_node.visible = not (v == "senza_mare" or all_off)
	_scene.settlements.visible = not (v == "senza_nomi" or all_off)
	_scene.environment.fog_enabled = not (v == "senza_nebbia" or all_off)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
