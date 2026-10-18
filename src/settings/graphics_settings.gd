class_name GraphicsSettings
extends RefCounted
## Impostazioni grafiche. Solo dati: l'applicazione al motore è in SettingsService.

const PRESETS: PackedStringArray = ["basso", "medio", "alto", "ultra"]
const PRESET_NAMES: Dictionary = {
	"basso": "Basso", "medio": "Medio", "alto": "Alto", "ultra": "Ultra", "personalizzato": "Personalizzato",
}
const RENDERERS: PackedStringArray = ["forward_plus", "mobile", "gl_compatibility"]
const RENDERER_NAMES: Dictionary = {
	"forward_plus": "Forward+ (Vulkan/DirectX 12, qualità piena)",
	"mobile": "Mobile (Vulkan, più leggero)",
	"gl_compatibility": "Compatibilità (OpenGL 3.3, per schede vecchie)",
}
const WINDOW_MODES: PackedStringArray = ["finestra", "schermo_intero", "esclusivo"]
const WINDOW_MODE_NAMES: Dictionary = {
	"finestra": "Finestra", "schermo_intero": "Schermo intero (senza bordi)",
	"esclusivo": "Schermo intero esclusivo (più veloce)",
}
const AA_MODES: PackedStringArray = ["nessuno", "fxaa", "msaa_2x", "msaa_4x", "taa"]
const AA_NAMES: Dictionary = {
	"nessuno": "Nessuno", "fxaa": "FXAA (leggero)", "msaa_2x": "MSAA 2x", "msaa_4x": "MSAA 4x", "taa": "TAA",
}
const SHADOW_LEVELS: PackedStringArray = ["disattivate", "basse", "medie", "alte", "ultra"]
const SHADOW_NAMES: Dictionary = {
	"disattivate": "Disattivate", "basse": "Basse", "medie": "Medie", "alte": "Alte", "ultra": "Ultra",
}
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]
## Soldati di riferimento in una grande battaglia (preset Alto = 100%).
const REFERENCE_SOLDIERS: int = 2000

# Valori decisi dal preset.
var preset: String = "medio"
var antialiasing: String = "fxaa"
var shadows: String = "medie"
var render_scale: float = 1.0
var view_distance: float = 1000.0
var soldier_density: float = 0.6
var vegetation_density: float = 0.6
var ssao: bool = false
var glow: bool = true
var volumetric_fog: bool = false
# Valori indipendenti dal preset.
var renderer: String = "forward_plus"
var window_mode: String = "schermo_intero"
var resolution: Vector2i = Vector2i(1600, 900)
var vsync: bool = true
var max_fps: int = 60
var show_fps: bool = false

const _PRESET_VALUES: Dictionary = {
	"basso": {
		"antialiasing": "fxaa", "shadows": "basse", "render_scale": 0.85, "view_distance": 600.0,
		"soldier_density": 0.35, "vegetation_density": 0.3, "ssao": false, "glow": false, "volumetric_fog": false,
	},
	"medio": {
		"antialiasing": "fxaa", "shadows": "medie", "render_scale": 1.0, "view_distance": 1000.0,
		"soldier_density": 0.6, "vegetation_density": 0.6, "ssao": false, "glow": true, "volumetric_fog": false,
	},
	"alto": {
		"antialiasing": "msaa_2x", "shadows": "alte", "render_scale": 1.0, "view_distance": 1600.0,
		"soldier_density": 1.0, "vegetation_density": 1.0, "ssao": true, "glow": true, "volumetric_fog": false,
	},
	"ultra": {
		"antialiasing": "msaa_4x", "shadows": "ultra", "render_scale": 1.0, "view_distance": 2500.0,
		"soldier_density": 1.0, "vegetation_density": 1.0, "ssao": true, "glow": true, "volumetric_fog": true,
	},
}


static func from_preset(preset_name: String) -> GraphicsSettings:
	var g := GraphicsSettings.new()
	g.apply_preset(preset_name)
	return g


static func preset_keys() -> PackedStringArray:
	return PackedStringArray(_PRESET_VALUES["medio"].keys())


## Applica i valori di un preset (non tocca renderer, finestra, risoluzione, vsync, FPS).
func apply_preset(preset_name: String) -> void:
	if not _PRESET_VALUES.has(preset_name):
		return
	var values: Dictionary = _PRESET_VALUES[preset_name]
	for key: String in values:
		set(key, values[key])
	preset = preset_name


## Il preset che corrisponde esattamente ai valori attuali, oppure "personalizzato".
func matching_preset() -> String:
	for p: String in PRESETS:
		var values: Dictionary = _PRESET_VALUES[p]
		var same := true
		for key: String in values:
			var a: Variant = get(key)
			var b: Variant = values[key]
			if a is float:
				same = same and is_equal_approx(a, b)
			else:
				same = same and a == b
		if same:
			return p
	return "personalizzato"


func refresh_preset_name() -> void:
	preset = matching_preset()


func preset_index() -> int:
	return PRESETS.find(preset)


# ------------------------------------------------------------------ valori derivati

## Antialiasing realmente usabile con un renderer: Compatibilità non ha FXAA né TAA.
func effective_antialiasing(rendering_method: String) -> String:
	if rendering_method == "gl_compatibility":
		match antialiasing:
			"fxaa": return "nessuno"
			"taa": return "msaa_2x"
	return antialiasing


func shadows_enabled() -> bool:
	return shadows != "disattivate"


## Dimensione della mappa delle ombre del sole.
func shadow_atlas_size() -> int:
	match shadows:
		"basse": return 1024
		"medie": return 2048
		"alte": return 4096
		"ultra": return 8192
	return 0


## Distanza massima a cui il sole proietta ombre (metri).
func shadow_distance() -> float:
	match shadows:
		"basse": return 80.0
		"medie": return 150.0
		"alte": return 250.0
		"ultra": return 400.0
	return 0.0


## Soldati effettivi per un reggimento da `men` uomini (minimo 12).
func soldiers_for(men: int) -> int:
	return maxi(12, roundi(men * soldier_density))


func target_soldiers() -> int:
	return roundi(REFERENCE_SOLDIERS * soldier_density)


# ------------------------------------------------------------------ salvataggio

const SECTION: String = "grafica"


func save_to(cfg: ConfigFile) -> void:
	for key: String in ["preset", "antialiasing", "shadows", "render_scale", "view_distance",
			"soldier_density", "vegetation_density", "ssao", "glow", "volumetric_fog",
			"renderer", "window_mode", "resolution", "vsync", "max_fps", "show_fps"]:
		cfg.set_value(SECTION, key, get(key))


func load_from(cfg: ConfigFile) -> void:
	preset = _pick(cfg.get_value(SECTION, "preset", preset), PRESETS + PackedStringArray(["personalizzato"]), preset)
	antialiasing = _pick(cfg.get_value(SECTION, "antialiasing", antialiasing), AA_MODES, antialiasing)
	shadows = _pick(cfg.get_value(SECTION, "shadows", shadows), SHADOW_LEVELS, shadows)
	render_scale = clampf(_num(cfg.get_value(SECTION, "render_scale", render_scale), render_scale), 0.5, 1.0)
	view_distance = clampf(_num(cfg.get_value(SECTION, "view_distance", view_distance), view_distance), 300.0, 4000.0)
	soldier_density = clampf(_num(cfg.get_value(SECTION, "soldier_density", soldier_density), soldier_density), 0.2, 1.0)
	vegetation_density = clampf(_num(cfg.get_value(SECTION, "vegetation_density", vegetation_density), vegetation_density), 0.0, 1.0)
	ssao = _flag(cfg.get_value(SECTION, "ssao", ssao), ssao)
	glow = _flag(cfg.get_value(SECTION, "glow", glow), glow)
	volumetric_fog = _flag(cfg.get_value(SECTION, "volumetric_fog", volumetric_fog), volumetric_fog)
	renderer = _pick(cfg.get_value(SECTION, "renderer", renderer), RENDERERS, renderer)
	window_mode = _pick(cfg.get_value(SECTION, "window_mode", window_mode), WINDOW_MODES, window_mode)
	var res: Variant = cfg.get_value(SECTION, "resolution", resolution)
	if res is Vector2i and res.x >= 640 and res.y >= 480:
		resolution = res
	vsync = _flag(cfg.get_value(SECTION, "vsync", vsync), vsync)
	max_fps = clampi(int(_num(cfg.get_value(SECTION, "max_fps", max_fps), max_fps)), 0, 300)
	show_fps = _flag(cfg.get_value(SECTION, "show_fps", show_fps), show_fps)


func duplicate_settings() -> GraphicsSettings:
	var cfg := ConfigFile.new()
	save_to(cfg)
	var g := GraphicsSettings.new()
	g.load_from(cfg)
	return g


static func _pick(v: Variant, allowed: PackedStringArray, fallback: String) -> String:
	return v if v is String and v in allowed else fallback


static func _num(v: Variant, fallback: float) -> float:
	return float(v) if v is float or v is int else fallback


static func _flag(v: Variant, fallback: bool) -> bool:
	return v if v is bool else fallback
