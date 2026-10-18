extends Node3D
## Test prestazioni: due eserciti avanzano e si scontrano mentre la telecamera gira.
## Misura FPS medi e minimi con le impostazioni applicate, poi consiglia un preset.

const WARMUP: float = 3.0
const MEASURE: float = 12.0
const REGIMENTS_PER_SIDE: int = 10
const CAVALRY_PER_SIDE: int = 2
const START_Z: float = 45.0
const STOP_Z: float = 7.0
const MARCH_SPEED: float = 3.2
const RESULT_FILE: String = "benchmark_risultati.txt"

var _time: float = 0.0
var _stats := FrameStats.new()
var _regiments: Array[RegimentView] = []
var _directions: Array[float] = []
var _speeds: Array[float] = []
var _camera: Camera3D = null
var _hud: Label = null
var _ui: Control = null
var _done: bool = false
var _total_soldiers: int = 0
var _result_text: String = ""
var _advice: String = ""


func _ready() -> void:
	_uncap_fps()
	_build_world()
	_build_army(-1.0, Color("b23a3a"))
	_build_army(1.0, Color("3a6fb2"))
	_build_hud()


## Durante la misura VSync e limite FPS vanno tolti, altrimenti il risultato
## si ferma a 60 e non dice quanto margine resta alla scheda video.
func _uncap_fps() -> void:
	Engine.max_fps = 0
	if not Settings.is_headless():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _restore_fps_cap() -> void:
	Settings.apply()


func _exit_tree() -> void:
	_restore_fps_cap()


# ------------------------------------------------------------------ scena

func _build_world() -> void:
	var g: GraphicsSettings = Settings.graphics
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4d6f96")
	sky_mat.sky_horizon_color = Color("c9b79a")
	sky_mat.ground_horizon_color = Color("8a7a60")
	sky_mat.ground_bottom_color = Color("3a3226")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("9aa08a")
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.2
	env.volumetric_fog_density = 0.01
	env.glow_intensity = 0.4
	Settings.configure_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("ffe9c4")
	sun.light_energy = 1.25
	Settings.configure_sun(sun)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.WHITE
	gm.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.015
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color("4c5a2a"))
	ramp.set_color(1, Color("74723f"))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	gm.albedo_texture = tex
	gm.uv1_scale = Vector3(24, 24, 1)
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	# Colline lontane per dare profondità
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color("46532c")
	hill_mat.roughness = 1.0
	for i: int in 14:
		var h := MeshInstance3D.new()
		h.mesh = LowPolyBuilder.sphere(1.0, 10, 5)
		h.material_override = hill_mat
		var ang: float = TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var dist: float = rng.randf_range(380, 560)
		h.position = Vector3(cos(ang) * dist, -10.0, sin(ang) * dist)
		h.scale = Vector3(rng.randf_range(90, 170), rng.randf_range(30, 70), rng.randf_range(90, 170))
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)

	# Boschi
	var trees: int = roundi(1400 * g.vegetation_density)
	if trees > 0:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = LowPolyBuilder.tree_mesh()
		mm.instance_count = trees
		for i: int in trees:
			var pos := Vector3(rng.randf_range(-320, 320), 0, rng.randf_range(-320, 320))
			if absf(pos.x) < 90 and absf(pos.z) < 110:
				pos.x += 180.0 * signf(pos.x if pos.x != 0.0 else 1.0)
			var s: float = rng.randf_range(0.8, 1.5)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), pos))
		var trees_node := MultiMeshInstance3D.new()
		trees_node.multimesh = mm
		var tm := StandardMaterial3D.new()
		tm.vertex_color_use_as_albedo = true
		tm.roughness = 1.0
		trees_node.material_override = tm
		add_child(trees_node)

	_camera = Camera3D.new()
	_camera.fov = 55
	Settings.configure_camera(_camera)
	add_child(_camera)
	_update_camera()


func _build_army(side: float, color: Color) -> void:
	var g: GraphicsSettings = Settings.graphics
	var per_regiment: int = maxi(12, roundi(float(g.target_soldiers()) / (REGIMENTS_PER_SIDE * 2)))
	var shader: Shader = load("res://assets/shaders/soldier.gdshader")
	var inf_mat := ShaderMaterial.new()
	inf_mat.shader = shader
	var cav_mat := ShaderMaterial.new()
	cav_mat.shader = shader
	cav_mat.set_shader_parameter("quadruped", true)
	cav_mat.set_shader_parameter("leg_top", 0.95)
	cav_mat.set_shader_parameter("step_rate", 9.0)
	var inf_mesh: ArrayMesh = LowPolyBuilder.soldier_mesh()
	var cav_mesh: ArrayMesh = LowPolyBuilder.cavalry_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1 if side < 0 else 2
	var infantry: int = REGIMENTS_PER_SIDE - CAVALRY_PER_SIDE
	var front_width: float = 26.0
	for i: int in REGIMENTS_PER_SIDE:
		var mounted: bool = i >= infantry
		var r := RegimentView.new()
		var count: int = maxi(12, roundi(per_regiment * (0.5 if mounted else 1.0)))
		var ranks: int = 3 if mounted else 5
		r.setup(cav_mesh if mounted else inf_mesh, cav_mat if mounted else inf_mat, count, ranks, color, mounted, rng)
		var x: float
		var z: float = START_Z
		if mounted:
			x = (front_width * infantry * 0.5 + 18.0) * (1.0 if i == infantry else -1.0)
			z += 10.0
		else:
			x = (i - (infantry - 1) * 0.5) * front_width
		r.position = Vector3(x, 0, z * side)
		# L'esercito a z negativa guarda verso +Z.
		r.rotation.y = PI if side < 0 else 0.0
		r.marching = true
		add_child(r)
		_regiments.append(r)
		_directions.append(-side)
		_speeds.append(MARCH_SPEED * (1.8 if mounted else 1.0))
		_total_soldiers += count


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.get_theme()
	layer.add_child(UiKit.fill(_ui))
	var p := UiKit.panel()
	p.position = Vector2(24, 24)
	_ui.add_child(p)
	_hud = UiKit.label("", UiTheme.SMALL_SIZE)
	p.add_child(_hud)


# ------------------------------------------------------------------ ciclo

func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time > WARMUP:
		_stats.add(delta)
	for i: int in _regiments.size():
		var r: RegimentView = _regiments[i]
		var dir: float = _directions[i]
		if absf(r.position.z) > STOP_Z:
			r.position.z += dir * _speeds[i] * delta
			if absf(r.position.z) <= STOP_Z:
				r.position.z = STOP_Z * -dir
		else:
			r.marching = fmod(_time, 1.2) < 0.6  # mischia: passi avanti e indietro
	_update_camera()
	var left: float = maxf(0.0, WARMUP + MEASURE - _time)
	_hud.text = "TEST PRESTAZIONI — %s\n%d FPS · %d soldati · preset %s · %s\n%s · Esc per uscire" % [
		"riscaldamento" if _time < WARMUP else "misura: %d s" % ceili(left),
		Engine.get_frames_per_second(), _total_soldiers,
		GraphicsSettings.PRESET_NAMES.get(Settings.graphics.preset, Settings.graphics.preset),
		Settings.current_renderer(), Settings.hardware.gpu_name]
	if _time >= WARMUP + MEASURE:
		_finish()


func _update_camera() -> void:
	var t: float = _time / (WARMUP + MEASURE)
	var ang: float = 0.6 + t * 2.2
	var radius: float = lerpf(120.0, 55.0, t)
	var height: float = lerpf(55.0, 14.0, t)
	_camera.position = Vector3(cos(ang) * radius, height, sin(ang) * radius)
	_camera.look_at(Vector3(0, 2, 0))


func _finish() -> void:
	_done = true
	_restore_fps_cap()
	var avg: float = _stats.average_fps()
	var low: float = _stats.low_fps()
	var g: GraphicsSettings = Settings.graphics
	var current: String = g.matching_preset()
	_advice = PresetAdvisor.adjust_after_benchmark(current, avg, low)
	var verdict: String
	if avg >= 75.0 and low >= 50.0:
		verdict = "Fluido e con margine: la scheda video regge anche di più."
	elif avg >= 55.0 and low >= 40.0:
		verdict = "Fluido: le impostazioni attuali vanno bene."
	elif avg >= 30.0:
		verdict = "Giocabile, con qualche rallentamento."
	else:
		verdict = "Troppo lento: conviene abbassare la qualità."
	var adv_text: String = "Consiglio: resta su %s." % GraphicsSettings.PRESET_NAMES.get(current, current)
	if _advice != current:
		adv_text = "Consiglio: passa al preset %s." % GraphicsSettings.PRESET_NAMES[_advice]
	var size: Vector2i = get_viewport().get_visible_rect().size
	_result_text = "\n".join(PackedStringArray([
		"Data: %s" % Time.get_datetime_string_from_system(false, true),
		"Scheda video: %s · %s" % [Settings.hardware.gpu_name, Settings.hardware.graphics_api],
		"Processore: %s (%d core) · RAM %.1f GB" % [Settings.hardware.cpu_name, Settings.hardware.cpu_cores, Settings.hardware.ram_gb],
		"Renderer: %s · preset %s · finestra %d×%d · scala %d%% · AA %s · ombre %s" % [
			Settings.current_renderer(), GraphicsSettings.PRESET_NAMES.get(current, current), size.x, size.y,
			roundi(g.render_scale * 100), g.effective_antialiasing(Settings.current_renderer()), g.shadows],
		"Soldati: %d · alberi: %d%% · VSync e limite FPS disattivati durante la misura" % [
			_total_soldiers, roundi(g.vegetation_density * 100)],
		"FPS medi: %.1f · FPS minimi (1%%): %.1f · fotogramma peggiore: %.1f ms" % [avg, low, _stats.worst_frame_ms()],
		verdict, adv_text,
	]))
	_write_results()
	_show_results(avg, low, verdict, adv_text)


func _write_results() -> void:
	var paths: PackedStringArray = ["user://" + RESULT_FILE]
	if OS.has_feature("template"):
		paths.append(OS.get_executable_path().get_base_dir().path_join(RESULT_FILE))
	for path: String in paths:
		var f: FileAccess
		if FileAccess.file_exists(path):
			f = FileAccess.open(path, FileAccess.READ_WRITE)
			if f != null:
				f.seek_end()
		else:
			f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string("==== Test prestazioni Regna ====\n%s\n\n" % _result_text)
		f.close()


func _show_results(avg: float, low: float, verdict: String, adv_text: String) -> void:
	_hud.get_parent().visible = false
	var center := CenterContainer.new()
	_ui.add_child(UiKit.fill(center))
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(720, 0)
	center.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	v.add_child(UiKit.heading("Risultato del test", 30))
	var big := UiKit.title("%d FPS medi · %d minimi" % [roundi(avg), roundi(low)], 34)
	v.add_child(big)
	v.add_child(UiKit.label("%d soldati in campo · %s" % [_total_soldiers, Settings.current_renderer()], UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	v.add_child(UiKit.paragraph(verdict))
	v.add_child(UiKit.paragraph(adv_text, UiTheme.BODY_SIZE, UiTheme.GOLD))
	var where: String = "accanto al gioco (benchmark_risultati.txt)" if OS.has_feature("template") else "nella cartella dei dati utente"
	v.add_child(UiKit.paragraph("Risultati salvati %s." % where, UiTheme.SMALL_SIZE, UiTheme.TEXT_DIM))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.spacer(false))
	row.add_child(UiKit.button("Ripeti", func() -> void: get_tree().reload_current_scene(), 140.0))
	if _advice != Settings.graphics.matching_preset():
		row.add_child(UiKit.button("Applica il consiglio", _apply_advice, 220.0))
	row.add_child(UiKit.button("Torna alle opzioni", _back, 220.0))
	v.add_child(row)


func _apply_advice() -> void:
	Settings.graphics.apply_preset(_advice)
	Settings.save()
	Settings.apply()
	get_tree().reload_current_scene()


func _back() -> void:
	Scenes.goto(get_tree(), Scenes.OPTIONS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
