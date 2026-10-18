class_name PresetAdvisor
extends RefCounted
## Sceglie il preset grafico adatto al PC. Logica pura, testabile.

const TIER_BASSO: int = 0
const TIER_MEDIO: int = 1
const TIER_ALTO: int = 2
const TIER_ULTRA: int = 3


## Livello della scheda video dal nome (0 = Basso ... 3 = Ultra).
static func gpu_tier(gpu_name: String, gpu_type: int = HardwareProfile.GPU_OTHER) -> int:
	var n: String = gpu_name.to_lower()
	if n.is_empty() or n.contains("llvmpipe") or n.contains("swiftshader") or n.contains("software") \
			or n.contains("basic render") or n.contains("dummy") or gpu_type == HardwareProfile.GPU_CPU:
		return TIER_BASSO
	if n.contains("nvidia") or n.contains("geforce") or n.contains("quadro") or n.contains("rtx") or n.contains("gtx"):
		return _nvidia_tier(n)
	if n.contains("radeon") or n.contains("amd") or n.contains("ati "):
		return _amd_tier(n, gpu_type)
	if n.contains("intel"):
		if n.contains("arc"):
			return TIER_ALTO if gpu_type == HardwareProfile.GPU_DISCRETE else TIER_MEDIO
		return TIER_BASSO
	return TIER_MEDIO if gpu_type == HardwareProfile.GPU_DISCRETE else TIER_BASSO


static func _first_number(text: String, pattern: String) -> int:
	var re := RegEx.new()
	re.compile(pattern)
	var m: RegExMatch = re.search(text)
	return int(m.get_string(1)) if m != null else -1


static func _nvidia_tier(n: String) -> int:
	var rtx: int = _first_number(n, "rtx\\s*a?(\\d{4})")
	if rtx > 0:
		return TIER_ALTO if rtx % 100 <= 50 else TIER_ULTRA
	var gtx: int = _first_number(n, "gtx\\s*(\\d{3,4})")
	if gtx >= 1000:
		var series: int = floori(gtx / 100.0)
		var model: int = gtx % 100
		if series == 16:
			return TIER_MEDIO if model <= 50 else TIER_ALTO
		return TIER_MEDIO if model <= 50 else TIER_ALTO
	if gtx >= 400:
		var series: int = floori(gtx / 100.0)
		var model: int = gtx % 100
		if series >= 9:
			return TIER_ALTO if model >= 70 else TIER_MEDIO
		if series >= 6:
			return TIER_MEDIO if model >= 70 else TIER_BASSO
		return TIER_BASSO
	return TIER_BASSO  # GT, MX e simili


static func _amd_tier(n: String, gpu_type: int) -> int:
	var rx: int = _first_number(n, "rx\\s*(\\d{3,4})")
	if rx >= 9000:
		return TIER_ULTRA
	if rx >= 1000:
		var hundreds: int = floori(rx / 100.0) % 10
		if hundreds >= 7:
			return TIER_ULTRA
		if hundreds >= 6:
			return TIER_ALTO
		return TIER_MEDIO
	if rx >= 400:
		var model: int = rx % 100
		if model >= 70:
			return TIER_ALTO
		return TIER_MEDIO if model >= 60 else TIER_BASSO
	if _first_number(n, "(\\d{3})m\\b") >= 680:
		return TIER_MEDIO  # grafica integrata RDNA recente (680M, 780M...)
	if n.contains("r9"):
		return TIER_MEDIO
	if gpu_type == HardwareProfile.GPU_DISCRETE and not (n.contains("r5") or n.contains("r7") or n.contains("hd ")):
		return TIER_MEDIO
	return TIER_BASSO


## Consiglio completo: { "preset", "renderer", "tier", "reason" }.
static func recommend(h: HardwareProfile) -> Dictionary:
	var tier: int = gpu_tier(h.gpu_name, h.gpu_type)
	var reasons := PackedStringArray()
	reasons.append("scheda video di fascia %s" % ["bassa", "media", "alta", "altissima"][tier])
	var renderer: String = "forward_plus"
	if tier == TIER_BASSO or prefers_compatibility(h.gpu_name, h.gpu_type):
		renderer = "gl_compatibility"
		reasons.append("renderer Compatibilità, più leggero per le schede meno recenti")
		# Misurato su GTX 650: con Compatibilità regge 1.800 soldati a 60 FPS, con Forward+
		# 1.080 soldati a 40 FPS. Su una scheda dedicata il renderer leggero vale un preset in più.
		if h.gpu_type == HardwareProfile.GPU_DISCRETE and tier < TIER_ALTO and not _is_software(h.gpu_name):
			tier += 1
	if h.rendering_method == "gl_compatibility" and h.gpu_type != HardwareProfile.GPU_CPU and not h.gpu_name.is_empty():
		# Il motore è già ripiegato su OpenGL: Vulkan/DirectX 12 non sono disponibili.
		renderer = "gl_compatibility"
	# Memoria e processore limitano per ultimi.
	if h.ram_gb > 0.0 and h.ram_gb < 6.0 and tier > TIER_BASSO:
		tier = TIER_BASSO
		reasons.append("poca memoria (%.0f GB)" % h.ram_gb)
	elif h.ram_gb > 0.0 and h.ram_gb < 8.0 and tier > TIER_MEDIO:
		tier = TIER_MEDIO
		reasons.append("memoria limitata (%.0f GB)" % h.ram_gb)
	if h.cpu_cores < 4 and tier > TIER_MEDIO:
		tier = TIER_MEDIO
		reasons.append("processore con pochi core")
	return {
		"preset": GraphicsSettings.PRESETS[tier],
		"renderer": renderer,
		"tier": tier,
		"reason": ", ".join(reasons),
	}


## Schede di vecchia generazione (2012-2015 circa) dove Forward+ costa troppo:
## NVIDIA GTX 400-900 e GT, AMD HD/R5/R7/R9, Intel integrate non Arc.
static func prefers_compatibility(gpu_name: String, gpu_type: int) -> bool:
	var n: String = gpu_name.to_lower()
	if _is_software(n) or gpu_type == HardwareProfile.GPU_CPU:
		return true
	if n.contains("geforce") or n.contains("nvidia") or n.contains("gtx") or n.contains("rtx"):
		if n.contains("rtx"):
			return false
		var gtx: int = _first_number(n, "gtx\\s*(\\d{3,4})")
		return gtx < 1000  # GTX 4xx-9xx e GT/MX (senza numero GTX)
	if n.contains("radeon") or n.contains("amd") or n.contains("ati "):
		if _first_number(n, "rx\\s*(\\d{3,4})") > 0 or _first_number(n, "(\\d{3})m\\b") >= 680:
			return false
		return n.contains("hd ") or n.contains("r5") or n.contains("r7") or n.contains("r9") \
				or gpu_type == HardwareProfile.GPU_INTEGRATED
	if n.contains("intel"):
		return not n.contains("arc")
	return false


static func _is_software(gpu_name: String) -> bool:
	var n: String = gpu_name.to_lower()
	return n.is_empty() or n.contains("llvmpipe") or n.contains("swiftshader") or n.contains("software") \
			or n.contains("basic render") or n.contains("dummy")


## Dopo un test di prestazioni: alza o abbassa il preset.
## avg_fps = media, low_fps = 1% dei fotogrammi più lenti.
static func adjust_after_benchmark(current_preset: String, avg_fps: float, low_fps: float) -> String:
	var idx: int = GraphicsSettings.PRESETS.find(current_preset)
	if idx < 0:
		idx = TIER_MEDIO
	if avg_fps < 30.0 or low_fps < 20.0:
		idx -= 1
	elif avg_fps >= 75.0 and low_fps >= 50.0:
		idx += 1
	return GraphicsSettings.PRESETS[clampi(idx, 0, GraphicsSettings.PRESETS.size() - 1)]
