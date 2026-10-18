class_name HardwareProfile
extends RefCounted
## Descrizione del PC su cui gira il gioco.

## Valori come RenderingDevice.DeviceType: 0 altro, 1 integrata, 2 dedicata, 3 virtuale, 4 CPU.
const GPU_OTHER: int = 0
const GPU_INTEGRATED: int = 1
const GPU_DISCRETE: int = 2
const GPU_VIRTUAL: int = 3
const GPU_CPU: int = 4

var gpu_name: String = ""
var gpu_vendor: String = ""
var gpu_type: int = GPU_OTHER
var graphics_api: String = ""
var rendering_method: String = ""
var cpu_name: String = ""
var cpu_cores: int = 1
var ram_gb: float = 0.0
var os_name: String = ""


## Legge le informazioni dal motore. In modalità headless la GPU risulta vuota.
static func detect() -> HardwareProfile:
	var h := HardwareProfile.new()
	h.gpu_name = RenderingServer.get_video_adapter_name()
	h.gpu_vendor = RenderingServer.get_video_adapter_vendor()
	h.gpu_type = int(RenderingServer.get_video_adapter_type())
	h.graphics_api = RenderingServer.get_video_adapter_api_version()
	h.rendering_method = RenderingServer.get_current_rendering_method()
	h.cpu_name = OS.get_processor_name()
	h.cpu_cores = OS.get_processor_count()
	var mem: Dictionary = OS.get_memory_info()
	h.ram_gb = float(mem.get("physical", 0)) / (1024.0 * 1024.0 * 1024.0)
	h.os_name = OS.get_name()
	return h


static func make(gpu: String, type: int, cores: int, ram: float) -> HardwareProfile:
	var h := HardwareProfile.new()
	h.gpu_name = gpu
	h.gpu_type = type
	h.cpu_cores = cores
	h.ram_gb = ram
	return h


func gpu_type_name() -> String:
	match gpu_type:
		GPU_INTEGRATED: return "integrata"
		GPU_DISCRETE: return "dedicata"
		GPU_VIRTUAL: return "virtuale"
		GPU_CPU: return "software"
	return "sconosciuta"


func summary_lines() -> PackedStringArray:
	return PackedStringArray([
		"Scheda video: %s (%s)" % [gpu_name if not gpu_name.is_empty() else "non rilevata", gpu_type_name()],
		"API grafica: %s · renderer attuale: %s" % [graphics_api if not graphics_api.is_empty() else "-", rendering_method],
		"Processore: %s · %d core logici" % [cpu_name if not cpu_name.is_empty() else "sconosciuto", cpu_cores],
		"Memoria: %.1f GB · Sistema: %s" % [ram_gb, os_name],
	])
