extends Node
## Autoload "Settings": carica, salva e applica le impostazioni grafiche.
## Al primo avvio rileva il PC e sceglie il preset adatto.

signal changed

const CONFIG_PATH: String = "user://settings.cfg"
const OVERRIDE_PATH: String = "user://override.cfg"

var graphics: GraphicsSettings = GraphicsSettings.from_preset("medio")
var hardware: HardwareProfile = null
## true se è il primo avvio (nessun file di impostazioni).
var first_run: bool = false
## Messaggio da mostrare nel menu principale dopo il rilevamento automatico.
var first_run_report: String = ""
## true se è stato scelto un renderer diverso da quello in uso: serve un riavvio.
var restart_pending: bool = false

var _fps_layer: CanvasLayer = null
var _fps_label: Label = null
var _fps_timer: float = 0.0
## Le scene con un proprio pannello delle misure (es. la mappa di campagna) nascondono il contatore.
var _fps_suppressed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hardware = HardwareProfile.detect()
	if is_headless():
		return  # test automatici: nessun file scritto, nessuna finestra
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		graphics.load_from(cfg)
		# Se il renderer salvato non è quello in uso, il file di override manca o
		# il motore è ripiegato su OpenGL: lo riscriviamo per il prossimo avvio.
		if _override_renderer() != graphics.renderer:
			_write_override(graphics.renderer)
			restart_pending = graphics.renderer != current_renderer()
	else:
		first_run = true
		auto_configure()
	apply()
	_build_fps_overlay()


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func current_renderer() -> String:
	return RenderingServer.get_current_rendering_method()


## true se il renderer scelto non è quello in uso e non c'è un riavvio in sospeso:
## significa che il motore è ripiegato su un altro renderer (es. Vulkan non disponibile).
func renderer_fallback_active() -> bool:
	return not restart_pending and graphics.renderer != current_renderer()


## Rileva il PC e imposta preset e renderer consigliati.
func auto_configure() -> Dictionary:
	var rec: Dictionary = PresetAdvisor.recommend(hardware)
	graphics.apply_preset(rec["preset"])
	var preset_name: String = GraphicsSettings.PRESET_NAMES[rec["preset"]]
	first_run_report = "Scheda video: %s. Preset consigliato: %s (%s)." % [
		hardware.gpu_name if not hardware.gpu_name.is_empty() else "non rilevata", preset_name, rec["reason"]]
	set_renderer(rec["renderer"])
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x >= 640 and screen.y >= 480:
		graphics.resolution = screen
	save()
	return rec


func set_renderer(renderer: String) -> void:
	graphics.renderer = renderer
	_write_override(renderer)
	restart_pending = renderer != current_renderer()


func _write_override(renderer: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rendering", "renderer/rendering_method", renderer)
	var err: Error = cfg.save(OVERRIDE_PATH)
	if err != OK:
		push_warning("Impossibile scrivere %s (%s)" % [OVERRIDE_PATH, error_string(err)])


func _override_renderer() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(OVERRIDE_PATH) != OK:
		return ""
	return str(cfg.get_value("rendering", "renderer/rendering_method", ""))


func save() -> void:
	if is_headless():
		return
	var cfg := ConfigFile.new()
	graphics.save_to(cfg)
	var err: Error = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Impossibile salvare le impostazioni (%s)" % error_string(err))


## Riavvia il gioco (serve dopo il cambio di renderer).
func restart_game() -> void:
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


# ------------------------------------------------------------------ applicazione

func apply() -> void:
	if is_headless():
		return
	var g: GraphicsSettings = graphics
	var compat: bool = current_renderer() == "gl_compatibility"
	_apply_window(g)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = g.max_fps
	var vp: Viewport = get_tree().root
	vp.scaling_3d_scale = g.render_scale
	if g.render_scale < 0.999 and not compat:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var aa: String = g.effective_antialiasing(current_renderer())
	vp.msaa_3d = Viewport.MSAA_DISABLED
	if not compat:
		# FXAA e TAA esistono solo con Forward+ e Mobile.
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = aa == "taa"
	match aa:
		"msaa_2x":
			vp.msaa_3d = Viewport.MSAA_2X
		"msaa_4x":
			vp.msaa_3d = Viewport.MSAA_4X
	if g.shadows_enabled():
		RenderingServer.directional_shadow_atlas_set_size(g.shadow_atlas_size(), true)
		apply_shadow_filter()
		vp.positional_shadow_atlas_size = mini(g.shadow_atlas_size(), 4096)
	else:
		vp.positional_shadow_atlas_size = 0
	match g.preset_index():
		0: vp.mesh_lod_threshold = 4.0
		1: vp.mesh_lod_threshold = 2.0
		_: vp.mesh_lod_threshold = 1.0
	if _fps_layer != null:
		_fps_layer.visible = g.show_fps and not _fps_suppressed
	changed.emit()


## Filtro delle ombre secondo il preset (la mappa di campagna lo cambia e lo ripristina).
func apply_shadow_filter() -> void:
	var q: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
	match graphics.shadows:
		"basse": q = RenderingServer.SHADOW_QUALITY_HARD
		"medie": q = RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
		"alte": q = RenderingServer.SHADOW_QUALITY_SOFT_LOW
		"ultra": q = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	RenderingServer.directional_soft_shadow_filter_set_quality(q)
	RenderingServer.positional_soft_shadow_filter_set_quality(q)


func _apply_window(g: GraphicsSettings) -> void:
	match g.window_mode:
		"schermo_intero":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"esclusivo":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen: Vector2i = DisplayServer.screen_get_size()
			var size: Vector2i = g.resolution
			if screen.x > 0 and screen.y > 0:
				size = Vector2i(mini(size.x, screen.x), mini(size.y, screen.y - 60))
			DisplayServer.window_set_size(size)
			var origin: Vector2i = DisplayServer.screen_get_position()
			DisplayServer.window_set_position(origin + Vector2i(floori((screen.x - size.x) / 2.0), floori((screen.y - size.y) / 2.0)))


## Da chiamare nelle scene 3D: adatta ambiente, sole e telecamera alle impostazioni.
func configure_environment(env: Environment) -> void:
	var method: String = current_renderer()
	env.ssao_enabled = graphics.ssao and method != "gl_compatibility"
	env.glow_enabled = graphics.glow
	env.volumetric_fog_enabled = graphics.volumetric_fog and method == "forward_plus"
	env.sdfgi_enabled = false
	env.ssr_enabled = false


func configure_sun(light: DirectionalLight3D) -> void:
	light.shadow_enabled = graphics.shadows_enabled()
	light.directional_shadow_max_distance = graphics.shadow_distance()
	if graphics.shadows in ["basse", "medie"]:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if graphics.shadows == "basse" \
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func configure_camera(cam: Camera3D) -> void:
	cam.far = graphics.view_distance


# ------------------------------------------------------------------ contatore FPS (F3)

func _build_fps_overlay() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 100
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 8)
	_fps_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_layer.add_child(_fps_label)
	_fps_layer.visible = graphics.show_fps and not _fps_suppressed
	add_child(_fps_layer)


## Nasconde il contatore generale finché una scena mostra le sue misure (F3 resta attivo).
func set_fps_overlay_suppressed(value: bool) -> void:
	_fps_suppressed = value
	if _fps_layer != null:
		_fps_layer.visible = graphics.show_fps and not _fps_suppressed


func _process(delta: float) -> void:
	if _fps_layer == null or not _fps_layer.visible:
		return
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.25
	var fps: float = Engine.get_frames_per_second()
	_fps_label.text = "%d FPS · %.1f ms · %s" % [fps, 1000.0 / maxf(fps, 1.0), current_renderer()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fps"):
		graphics.show_fps = not graphics.show_fps
		if _fps_layer != null:
			_fps_layer.visible = graphics.show_fps and not _fps_suppressed
		save()
