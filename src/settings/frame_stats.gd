class_name FrameStats
extends RefCounted
## Raccoglie i tempi dei fotogrammi e calcola FPS medi e minimi.

var _times: PackedFloat32Array = []
var _total: float = 0.0


func add(frame_time: float) -> void:
	if frame_time <= 0.0:
		return
	_times.append(frame_time)
	_total += frame_time


func count() -> int:
	return _times.size()


func average_fps() -> float:
	return _times.size() / _total if _total > 0.0 else 0.0


## FPS calcolati sull'1% dei fotogrammi più lenti (indica gli scatti).
func low_fps(fraction: float = 0.01) -> float:
	if _times.is_empty():
		return 0.0
	var sorted_times: PackedFloat32Array = _times.duplicate()
	sorted_times.sort()
	var n: int = maxi(1, ceili(sorted_times.size() * fraction))
	var sum: float = 0.0
	for i: int in n:
		sum += sorted_times[sorted_times.size() - 1 - i]
	return n / sum


func worst_frame_ms() -> float:
	if _times.is_empty():
		return 0.0
	var worst: float = 0.0
	for t: float in _times:
		worst = maxf(worst, t)
	return worst * 1000.0
