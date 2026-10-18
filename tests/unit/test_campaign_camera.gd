extends GutTest
## Limiti e comportamento della telecamera di campagna.

var map: CampaignMapData
var cam: CampaignCamera


func before_all() -> void:
	map = CampaignMapData.load_default()


func before_each() -> void:
	cam = CampaignCamera.new()
	add_child_autofree(cam)
	cam.setup(map)
	cam.edge_scroll = false


func test_zoom_is_clamped() -> void:
	cam.look_at_point(Vector2.ZERO, 100.0, true)
	cam.zoom(100.0)
	assert_eq(cam.goal_distance(), CampaignCamera.MIN_DISTANCE)
	cam.zoom(-100.0)
	assert_eq(cam.goal_distance(), CampaignCamera.MAX_DISTANCE)


func test_target_stays_inside_map() -> void:
	for d: float in [CampaignCamera.MIN_DISTANCE, 60.0, 200.0, CampaignCamera.MAX_DISTANCE]:
		for p: Vector2 in [Vector2(-5000, -5000), Vector2(5000, 5000), Vector2(5000, -3000), Vector2(-9000, 10)]:
			cam.look_at_point(p, d, true)
			var t: Vector2 = cam.goal_target()
			assert_true(map.bounds.has_point(t), "target %s dentro la mappa (distanza %d)" % [t, d])
	# da lontano il margine è più grande: il centro della vista resta lontano dai bordi
	cam.look_at_point(Vector2(-5000, 0), CampaignCamera.MAX_DISTANCE, true)
	var far_x: float = cam.goal_target().x
	cam.look_at_point(Vector2(-5000, 0), CampaignCamera.MIN_DISTANCE, true)
	assert_gt(far_x, cam.goal_target().x)


func test_pan_moves_and_respects_limits() -> void:
	cam.look_at_point(Vector2.ZERO, 50.0, true)
	cam.pan(Vector2(10, 0))
	assert_gt(cam.goal_target().x, 0.0, "a destra = verso est con rotazione zero")
	cam.pan(Vector2(0, -10))
	assert_lt(cam.goal_target().y, 0.0, "in alto = verso nord")
	cam.pan(Vector2(100000, 100000))
	assert_true(map.bounds.has_point(cam.goal_target()))


func test_pitch_changes_with_zoom() -> void:
	var near: float = CampaignCamera.pitch_for(CampaignCamera.MIN_DISTANCE)
	var far: float = CampaignCamera.pitch_for(CampaignCamera.MAX_DISTANCE)
	assert_almost_eq(rad_to_deg(near), CampaignCamera.PITCH_NEAR, 0.01)
	assert_almost_eq(rad_to_deg(far), CampaignCamera.PITCH_FAR, 0.01)
	assert_gt(far, CampaignCamera.pitch_for(100.0))


func test_camera_never_below_terrain() -> void:
	for pid: String in ["roma", "dalmatia", "cappadocia", "gallaecia", "tingitana"]:
		for y: float in [0.0, 1.5, 3.0]:
			cam.set_yaw(y, true)
			cam.look_at_point(map.city_pos[pid], CampaignCamera.MIN_DISTANCE, true)
			var pos: Vector3 = cam.camera.global_position
			assert_gte(pos.y, map.surface_at(Vector2(pos.x, pos.z)) + CampaignCamera.CLEARANCE - 0.001, pid)


func test_ground_under_screen_center() -> void:
	cam.look_at_point(map.city_pos["roma"], 40.0, true)
	await wait_frames(2)
	var center: Vector2 = cam.get_viewport().get_visible_rect().size * 0.5
	var g: Variant = cam.ground_under(center)
	assert_not_null(g)
	if g != null:
		assert_lt((g as Vector2).distance_to(map.city_pos["roma"]), 3.0, "il centro dello schermo guarda Roma")
