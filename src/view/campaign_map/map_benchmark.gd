class_name MapBenchmark
extends Node
## Test prestazioni della mappa di campagna: la telecamera segue un percorso fisso (vista
## d'insieme, zoom sull'Italia, Roma da vicino, Costantinopoli, di nuovo la vista d'insieme)
## e misura FPS medi e minimi. Si avvia da Opzioni; scrive i risultati in benchmark_risultati.txt.

const WARMUP: float = 3.0
const MEASURE: float = 20.0
const RESULT_FILE: String = "benchmark_risultati.txt"
const TARGET_MS: float = 12.0

var scene: CampaignMapScene = null
var _time: float = 0.0
var _stats := FrameStats.new()
var _done: bool = false
var _keys: Array = []
var _label: Label = null
var _peak_draw_calls: int = 0
var _peak_triangles: int = 0
var _peak_vram: float = 0.0


func setup(owner_scene: CampaignMapScene) -> void:
	scene = owner_scene
	var m: CampaignMapData = scene.map
	# (punto osservato, distanza, rotazione)
	_keys = [
		[m.bounds.get_center(), CampaignCamera.MAX_DISTANCE, 0.0],
		[m.city_pos["roma"], 120.0, 0.0],
		[m.city_pos["roma"], 12.0, 0.6],
		[m.city_pos["neapolis"], 30.0, 1.2],
		[m.city_pos["thracia"], 60.0, 0.4],
		[m.city_pos["thracia"], 14.0, -0.3],
		[m.city_pos["syria"], 160.0, 0.0],
		[m.bounds.get_center(), CampaignCamera.MAX_DISTANCE, 0.0],
	]
	scene.cam.input_enabled = false
	scene.cam.edge_scroll = false
	Engine.max_fps = 0
	if not Settings.is_headless():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var p := UiKit.panel()
	p.position = Vector2(24, 70)
	_label = UiKit.label("", UiTheme.SMALL_SIZE)
	p.add_child(_label)
	scene.hud.root.add_child(p)


func _exit_tree() -> void:
	Settings.apply()


func _process(delta: float) -> void:
	if _done or scene == null:
		return
	_time += delta
	var total: float = WARMUP + MEASURE
	if _time > WARMUP:
		_stats.add(delta)
		_peak_draw_calls = maxi(_peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_peak_triangles = maxi(_peak_triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		_peak_vram = maxf(_peak_vram, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	var t: float = clampf(_time / total, 0.0, 1.0) * (_keys.size() - 1)
	var i: int = mini(floori(t), _keys.size() - 2)
	var f: float = smoothstep(0.0, 1.0, t - i)
	var a: Array = _keys[i]
	var b: Array = _keys[i + 1]
	var dist: float = exp(lerpf(log(float(a[1])), log(float(b[1])), f))
	scene.cam.set_yaw(lerpf(float(a[2]), float(b[2]), f), true)
	scene.cam.look_at_point((a[0] as Vector2).lerp(b[0], f), dist, true)
	_label.text = "TEST MAPPA DI CAMPAGNA — %s\n%d FPS · %s" % [
		"riscaldamento" if _time < WARMUP else "misura: %d s" % ceili(maxf(0.0, total - _time)),
		Engine.get_frames_per_second(), Settings.current_renderer()]
	if _time >= total:
		_finish()


func _finish() -> void:
	_done = true
	Settings.apply()
	var avg: float = _stats.average_fps()
	var low: float = _stats.low_fps()
	var avg_ms: float = 1000.0 / maxf(avg, 0.001)
	var g: GraphicsSettings = Settings.graphics
	var verdict: String
	if avg_ms <= TARGET_MS and low >= 60.0:
		verdict = "Obiettivo raggiunto: meno di %d ms per fotogramma e almeno 60 FPS stabili." % TARGET_MS
	elif avg >= 60.0:
		verdict = "Fluido, ma con poco margine: qualche scatto possibile."
	elif avg >= 40.0:
		verdict = "Giocabile; con un preset più basso andrebbe meglio."
	else:
		verdict = "Troppo lento: abbassa il preset grafico."
	var size: Vector2i = scene.get_viewport().get_visible_rect().size
	var text: String = "\n".join(PackedStringArray([
		"Data: %s" % Time.get_datetime_string_from_system(false, true),
		"Scheda video: %s · %s" % [Settings.hardware.gpu_name, Settings.hardware.graphics_api],
		"Renderer: %s · preset %s · finestra %d×%d · AA %s · ombre %s" % [
			Settings.current_renderer(), GraphicsSettings.PRESET_NAMES.get(g.matching_preset(), g.preset),
			size.x, size.y, g.effective_antialiasing(Settings.current_renderer()), g.shadows],
		"FPS medi: %.1f (%.1f ms) · FPS minimi (1%%): %.1f · fotogramma peggiore: %.1f ms" % [
			avg, avg_ms, low, _stats.worst_frame_ms()],
		"Picchi: %d chiamate di disegno · %d triangoli · memoria video %.0f MB · caricamento mappa %.2f s" % [
			_peak_draw_calls, _peak_triangles, _peak_vram, scene.load_ms / 1000.0],
		verdict,
	]))
	_write(text)
	scene.hud.show_message("Test della mappa completato", "%d FPS medi (%.1f ms) · %d minimi\n\n%s\n\nRisultati salvati in %s." % [
		roundi(avg), avg_ms, roundi(low), verdict,
		"benchmark_risultati.txt accanto al gioco" if OS.has_feature("template") else "user://benchmark_risultati.txt"], _back)


func _write(text: String) -> void:
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
		f.store_string("==== Test mappa di campagna Regna ====\n%s\n\n" % text)
		f.close()


func _back() -> void:
	Session.map_benchmark = false
	if Session.benchmark_owns_game:
		Session.end_game()
	Session.benchmark_owns_game = false
	Scenes.goto(scene.get_tree(), Scenes.OPTIONS)
