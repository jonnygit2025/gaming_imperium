extends GutTest


func test_presets_scale_up() -> void:
	var prev: GraphicsSettings = null
	for p: String in GraphicsSettings.PRESETS:
		var g := GraphicsSettings.from_preset(p)
		assert_eq(g.preset, p)
		assert_eq(g.matching_preset(), p)
		if prev != null:
			assert_gte(g.soldier_density, prev.soldier_density)
			assert_gte(g.view_distance, prev.view_distance)
			assert_gte(g.shadow_atlas_size(), prev.shadow_atlas_size())
		prev = g


func test_alto_targets_2000_soldiers() -> void:
	assert_eq(GraphicsSettings.from_preset("alto").target_soldiers(), 2000)
	assert_lt(GraphicsSettings.from_preset("basso").target_soldiers(), 1000)


func test_soldiers_for_regiment() -> void:
	var g := GraphicsSettings.from_preset("basso")
	assert_eq(g.soldiers_for(100), 35)
	assert_eq(g.soldiers_for(20), 12, "minimo 12 soldati visibili")


func test_custom_change_becomes_personalizzato() -> void:
	var g := GraphicsSettings.from_preset("medio")
	g.ssao = true
	assert_eq(g.matching_preset(), "personalizzato")
	g.ssao = false
	assert_eq(g.matching_preset(), "medio")


func test_preset_does_not_touch_window_settings() -> void:
	var g := GraphicsSettings.from_preset("medio")
	g.renderer = "gl_compatibility"
	g.resolution = Vector2i(1280, 720)
	g.apply_preset("ultra")
	assert_eq(g.renderer, "gl_compatibility")
	assert_eq(g.resolution, Vector2i(1280, 720))


func test_round_trip_config() -> void:
	var g := GraphicsSettings.from_preset("alto")
	g.renderer = "mobile"
	g.resolution = Vector2i(1366, 768)
	g.max_fps = 90
	g.show_fps = true
	var cfg := ConfigFile.new()
	g.save_to(cfg)
	var g2 := GraphicsSettings.new()
	g2.load_from(cfg)
	assert_eq(g2.preset, "alto")
	assert_eq(g2.renderer, "mobile")
	assert_eq(g2.resolution, Vector2i(1366, 768))
	assert_eq(g2.max_fps, 90)
	assert_true(g2.show_fps)
	assert_eq(g2.matching_preset(), "alto")


func test_invalid_config_values_are_ignored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(GraphicsSettings.SECTION, "renderer", "directx9")
	cfg.set_value(GraphicsSettings.SECTION, "render_scale", 7.0)
	cfg.set_value(GraphicsSettings.SECTION, "shadows", 42)
	var g := GraphicsSettings.from_preset("medio")
	g.load_from(cfg)
	assert_eq(g.renderer, "forward_plus")
	assert_eq(g.render_scale, 1.0)
	assert_eq(g.shadows, "medie")


func test_compatibility_antialiasing_fallback() -> void:
	var g := GraphicsSettings.from_preset("basso")
	assert_eq(g.antialiasing, "fxaa")
	assert_eq(g.effective_antialiasing("gl_compatibility"), "nessuno")
	assert_eq(g.effective_antialiasing("forward_plus"), "fxaa")
	g.antialiasing = "taa"
	assert_eq(g.effective_antialiasing("gl_compatibility"), "msaa_2x")
	g.antialiasing = "msaa_4x"
	assert_eq(g.effective_antialiasing("gl_compatibility"), "msaa_4x")
