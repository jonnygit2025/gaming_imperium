extends GutTest

const D: int = HardwareProfile.GPU_DISCRETE
const I: int = HardwareProfile.GPU_INTEGRATED


func test_gpu_tiers() -> void:
	var cases: Array = [
		["NVIDIA GeForce GTX 650", D, PresetAdvisor.TIER_BASSO],
		["NVIDIA GeForce GTX 770", D, PresetAdvisor.TIER_MEDIO],
		["NVIDIA GeForce GTX 960", D, PresetAdvisor.TIER_MEDIO],
		["NVIDIA GeForce GTX 1050 Ti", D, PresetAdvisor.TIER_MEDIO],
		["NVIDIA GeForce GTX 1060 6GB", D, PresetAdvisor.TIER_ALTO],
		["NVIDIA GeForce GTX 1660 SUPER", D, PresetAdvisor.TIER_ALTO],
		["NVIDIA GeForce RTX 3050", D, PresetAdvisor.TIER_ALTO],
		["NVIDIA GeForce RTX 4070", D, PresetAdvisor.TIER_ULTRA],
		["NVIDIA GeForce GT 730", D, PresetAdvisor.TIER_BASSO],
		["AMD Radeon RX 580", D, PresetAdvisor.TIER_ALTO],
		["AMD Radeon RX 560", D, PresetAdvisor.TIER_MEDIO],
		["AMD Radeon RX 6600", D, PresetAdvisor.TIER_ALTO],
		["AMD Radeon RX 7900 XTX", D, PresetAdvisor.TIER_ULTRA],
		["AMD Radeon(TM) Graphics", I, PresetAdvisor.TIER_BASSO],
		["AMD Radeon 780M", I, PresetAdvisor.TIER_MEDIO],
		["Intel(R) HD Graphics 4600", I, PresetAdvisor.TIER_BASSO],
		["Intel(R) UHD Graphics 630", I, PresetAdvisor.TIER_BASSO],
		["Intel(R) Arc(TM) A750 Graphics", D, PresetAdvisor.TIER_ALTO],
		["llvmpipe (LLVM 19.1.1, 256 bits)", HardwareProfile.GPU_CPU, PresetAdvisor.TIER_BASSO],
		["", HardwareProfile.GPU_OTHER, PresetAdvisor.TIER_BASSO],
		["Scheda Misteriosa 9000", D, PresetAdvisor.TIER_MEDIO],
	]
	for c: Array in cases:
		assert_eq(PresetAdvisor.gpu_tier(c[0], c[1]), c[2], c[0])


func test_recommend_for_this_pc() -> void:
	# Il PC di sviluppo: i5-4440, 4 core, 16 GB, GTX 650.
	var h := HardwareProfile.make("NVIDIA GeForce GTX 650", D, 4, 15.9)
	var rec: Dictionary = PresetAdvisor.recommend(h)
	assert_eq(rec["preset"], "basso")
	assert_eq(rec["renderer"], "gl_compatibility")


func test_recommend_strong_pc() -> void:
	var h := HardwareProfile.make("NVIDIA GeForce RTX 4070", D, 12, 32.0)
	var rec: Dictionary = PresetAdvisor.recommend(h)
	assert_eq(rec["preset"], "ultra")
	assert_eq(rec["renderer"], "forward_plus")


func test_low_ram_caps_preset() -> void:
	var h := HardwareProfile.make("NVIDIA GeForce RTX 4070", D, 12, 7.5)
	assert_eq(PresetAdvisor.recommend(h)["preset"], "medio")
	h.ram_gb = 4.0
	assert_eq(PresetAdvisor.recommend(h)["preset"], "basso")


func test_few_cores_caps_preset() -> void:
	var h := HardwareProfile.make("NVIDIA GeForce RTX 4070", D, 2, 16.0)
	assert_eq(PresetAdvisor.recommend(h)["preset"], "medio")


func test_engine_fallback_keeps_compatibility() -> void:
	var h := HardwareProfile.make("NVIDIA GeForce GTX 1060", D, 4, 16.0)
	h.rendering_method = "gl_compatibility"
	assert_eq(PresetAdvisor.recommend(h)["renderer"], "gl_compatibility")


func test_benchmark_adjustment() -> void:
	assert_eq(PresetAdvisor.adjust_after_benchmark("medio", 25.0, 18.0), "basso")
	assert_eq(PresetAdvisor.adjust_after_benchmark("medio", 50.0, 35.0), "medio")
	assert_eq(PresetAdvisor.adjust_after_benchmark("medio", 90.0, 60.0), "alto")
	assert_eq(PresetAdvisor.adjust_after_benchmark("basso", 10.0, 5.0), "basso")
	assert_eq(PresetAdvisor.adjust_after_benchmark("ultra", 200.0, 150.0), "ultra")
	assert_eq(PresetAdvisor.adjust_after_benchmark("personalizzato", 60.0, 45.0), "medio")
