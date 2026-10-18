extends GutTest


func test_empty() -> void:
	var s := FrameStats.new()
	assert_eq(s.average_fps(), 0.0)
	assert_eq(s.low_fps(), 0.0)


func test_steady_60() -> void:
	var s := FrameStats.new()
	for i: int in 120:
		s.add(1.0 / 60.0)
	assert_almost_eq(s.average_fps(), 60.0, 0.01)
	assert_almost_eq(s.low_fps(), 60.0, 0.01)


func test_stutter_lowers_1_percent() -> void:
	var s := FrameStats.new()
	for i: int in 99:
		s.add(1.0 / 60.0)
	s.add(0.1)  # uno scatto da 100 ms
	assert_almost_eq(s.low_fps(), 10.0, 0.01)
	assert_gt(s.average_fps(), 50.0)
	assert_almost_eq(s.worst_frame_ms(), 100.0, 0.01)


func test_ignores_invalid_frames() -> void:
	var s := FrameStats.new()
	s.add(0.0)
	s.add(-1.0)
	assert_eq(s.count(), 0)
