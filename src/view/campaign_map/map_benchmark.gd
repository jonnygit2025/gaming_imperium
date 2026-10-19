class_name MapBenchmark
extends Node
## Test prestazioni della mappa di campagna: la telecamera segue un percorso fisso (vista
## d'insieme, zoom sull'Italia, Roma da vicino, Costantinopoli, di nuovo la vista d'insieme)
## e misura FPS medi e minimi. Poi una fase di analisi: su quattro inquadrature fisse misura
## il costo di ogni parte della scena togliendola una alla volta (sulla scheda video vera, non
## nell'emulazione del cloud). Si avvia da Opzioni; scrive i risultati in benchmark_risultati.txt.

const WARMUP: float = 3.0
const MEASURE: float = 24.0
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
## Per tratto del percorso: [nome, fotogrammi, somma ms, fotogramma peggiore ms, fotogrammi > 20 ms]
var _segments: Array = []
var _frame_ms: float = 0.0
var _cpu_render_ms: float = 0.0
var _gpu_ms: float = 0.0
var _timed_frames: int = 0
var _vp_rid: RID
## Orologio reale: con fotogrammi molto lenti il delta di Godot viene limitato e non basta.
var _last_us: int = 0

const ANALYSIS_VARIANTS: PackedStringArray = ["completo", "terreno_completo", "shader_senza_dettagli", "senza_alberi",
		"senza_citta_dettagliate", "senza_ombre", "senza_mare"]
const ANALYSIS_NAMES: Dictionary = {
	"completo": "completo", "terreno_completo": "terreno con tutti i triangoli",
	"shader_senza_dettagli": "shader del terreno senza dettagli",
	"senza_alberi": "senza alberi", "senza_citta_dettagliate": "città semplici e senza villaggi/porti",
	"senza_ombre": "senza ombre", "senza_mare": "senza mare",
}
const ANALYSIS_SETTLE: float = 0.35
const ANALYSIS_MEASURE: float = 1.0
const ANALYSIS_VIEW_SETTLE: float = 1.2
var _analysis: bool = false
var _steps: Array = []          # [vista, variante (o "" per spostare la telecamera)]
var _step: int = -1
var _step_time: float = 0.0
var _step_sum: float = 0.0
var _step_gpu: float = 0.0
var _step_n: int = 0
var _views: Array = []          # [nome, punto, distanza, rotazione]
var _results: Dictionary = {}   # vista -> {variante: [ms, ms scheda video]}


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
		[m.city_pos["austrasia"] + Vector2(-6.0, 4.0), 16.0, 0.8],
		[m.bounds.get_center(), CampaignCamera.MAX_DISTANCE, 0.0],
	]
	for seg_name: String in ["vista d'insieme → Italia", "Italia → Roma da vicino", "Roma → Neapolis",
			"Neapolis → Costantinopoli", "Costantinopoli da vicino", "Costantinopoli → Siria",
			"Siria → boschi della Gallia", "boschi della Gallia → vista d'insieme"]:
		_segments.append([seg_name, 0, 0.0, 0.0, 0])
	_views = [
		["vista d'insieme", m.bounds.get_center(), CampaignCamera.MAX_DISTANCE, 0.0],
		["Italia", m.city_pos["roma"], 95.0, 0.0],
		["Roma da vicino", m.city_pos["roma"], 12.0, 0.6],
		["bosco della Gallia", m.city_pos["austrasia"] + Vector2(-6.0, 4.0), 16.0, 0.8],
	]
	for v: Array in _views:
		_steps.append([v, ""])
		for variant: String in ANALYSIS_VARIANTS:
			_steps.append([v, variant])
	_vp_rid = scene.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
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
	if _vp_rid.is_valid():
		RenderingServer.viewport_set_measure_render_time(_vp_rid, false)
	Settings.apply()


func _process(_delta: float) -> void:
	if _done or scene == null:
		return
	var now: int = Time.get_ticks_usec()
	var delta: float = 0.0 if _last_us == 0 else (now - _last_us) / 1000000.0
	_last_us = now
	if _analysis:
		_analysis_step(delta)
		return
	_time += delta
	var total: float = WARMUP + MEASURE
	if _time > WARMUP:
		_stats.add(delta)
		_peak_draw_calls = maxi(_peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_peak_triangles = maxi(_peak_triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		_peak_vram = maxf(_peak_vram, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		_frame_ms += delta * 1000.0
		_cpu_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		_timed_frames += 1
	var t: float = clampf(_time / total, 0.0, 1.0) * (_keys.size() - 1)
	var i: int = mini(floori(t), _keys.size() - 2)
	if _time > WARMUP:
		var seg: Array = _segments[i]
		var ms: float = delta * 1000.0
		seg[1] += 1
		seg[2] += ms
		seg[3] = maxf(seg[3], ms)
		if ms > 20.0:
			seg[4] += 1
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
		_analysis = true


func _analysis_step(delta: float) -> void:
	if _step < 0 or _step_time >= _step_length():
		if _step >= 0:
			_record_step()
		_step += 1
		if _step >= _steps.size():
			scene.apply_analysis_variant("completo")
			_finish()
			return
		_step_time = 0.0
		_step_sum = 0.0
		_step_gpu = 0.0
		_step_n = 0
		var st: Array = _steps[_step]
		var v: Array = st[0]
		if st[1] == "":
			scene.apply_analysis_variant("completo")
			scene.cam.set_yaw(float(v[3]), true)
			scene.cam.look_at_point(v[1], float(v[2]), true)
		else:
			scene.apply_analysis_variant(st[1])
		_label.text = "TEST MAPPA DI CAMPAGNA — analisi\n%s · %s" % [v[0], ANALYSIS_NAMES.get(st[1], "preparazione")]
		return
	_step_time += delta
	if _step_time > ANALYSIS_SETTLE and str(_steps[_step][1]) != "":
		_step_sum += delta * 1000.0
		_step_gpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		_step_n += 1


func _step_length() -> float:
	return ANALYSIS_VIEW_SETTLE if str(_steps[_step][1]) == "" else ANALYSIS_SETTLE + ANALYSIS_MEASURE


func _record_step() -> void:
	var st: Array = _steps[_step]
	if str(st[1]) == "" or _step_n == 0:
		return
	var view: String = st[0][0]
	if not _results.has(view):
		_results[view] = {}
	(_results[view] as Dictionary)[st[1]] = [_step_sum / _step_n, _step_gpu / _step_n]


func _analysis_lines() -> PackedStringArray:
	var out := PackedStringArray(["Analisi (costo di ogni parte; negativo = quanto si risparmia togliendola):"])
	for v: Array in _views:
		var r: Dictionary = _results.get(v[0], {})
		if not r.has("completo"):
			continue
		var base: float = float(r["completo"][0])
		var parts := PackedStringArray()
		for variant: String in ANALYSIS_VARIANTS:
			if variant == "completo" or not r.has(variant):
				continue
			parts.append("%s %+.1f" % [ANALYSIS_NAMES[variant], float(r[variant][0]) - base])
		out.append("  %s: %.1f ms (scheda video %.1f) · %s" % [v[0], base, float(r["completo"][1]), " · ".join(parts)])
	return out


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
	var n: float = maxf(_timed_frames, 1)
	var gpu_avg: float = _gpu_ms / n
	var frame_avg: float = _frame_ms / n
	var gpu_text: String = "%.1f ms" % gpu_avg if _gpu_ms > 0.0 else "n/d"
	var bound: String = "non misurabile (la scheda non dà i tempi)"
	if _gpu_ms > 0.0:
		bound = "scheda video" if gpu_avg >= frame_avg * 0.8 else "processore (la scheda video aspetta)"
	var seg_lines := PackedStringArray()
	for seg: Array in _segments:
		if int(seg[1]) > 0:
			seg_lines.append("  %s: %.1f ms medi · peggiore %.1f ms · %d fotogrammi oltre 20 ms" % [
				seg[0], float(seg[2]) / int(seg[1]), float(seg[3]), int(seg[4])])
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
		"Tempi medi: fotogramma %.1f ms · lavoro della scheda video %s · preparazione del disegno sul processore %.1f ms · limite: %s" % [
			frame_avg, gpu_text, _cpu_render_ms / n, bound],
		"Per tratto del percorso:",
		"\n".join(seg_lines),
		"\n".join(_analysis_lines()),
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
