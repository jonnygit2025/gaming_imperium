class_name CampaignCamera
extends Node3D
## Telecamera della mappa di campagna, stile strategico:
## - WASD/frecce e bordo dello schermo per spostarsi (più veloce quando si è lontani);
## - rotella per lo zoom verso il punto sotto il mouse;
## - Q/E o tasto centrale trascinato per ruotare;
## - inclinazione che cambia con lo zoom (quasi dall'alto da lontano, più radente da vicino);
## - limiti ai bordi della mappa e movimenti smorzati.
## Lo stato "desiderato" (target, distanza, rotazione) è separato da quello mostrato, che lo
## insegue con uno smorzamento esponenziale: i limiti si applicano allo stato desiderato.

const MIN_DISTANCE: float = 5.0
const MAX_DISTANCE: float = 430.0
const PITCH_NEAR: float = 36.0
const PITCH_FAR: float = 66.0
const ZOOM_STEP: float = 0.84
const PAN_SPEED: float = 1.15        # frazione della distanza al secondo
const ROTATE_SPEED: float = 1.6      # radianti al secondo
const EDGE_PIXELS: float = 6.0
const SMOOTHING: float = 9.0
const CLEARANCE: float = 1.2         # quota minima della telecamera sopra il terreno

var camera: Camera3D = null
var map: CampaignMapData = null
## Bordi entro cui può stare il punto osservato (x, z).
var limits: Rect2 = Rect2(-270, -200, 540, 400)
var edge_scroll: bool = true
var input_enabled: bool = true

var target: Vector2 = Vector2.ZERO
var distance: float = 300.0
var yaw: float = 0.0
var _goal_target: Vector2 = Vector2.ZERO
var _goal_distance: float = 300.0
var _goal_yaw: float = 0.0
var _ground: float = 0.0
var _rotating: bool = false
var _preset_far: float = 1000.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.3
	Settings.configure_camera(camera)
	_preset_far = camera.far
	add_child(camera)
	camera.current = true
	_apply(true)


func setup(map_data: CampaignMapData) -> void:
	map = map_data
	if map != null and map.is_valid():
		limits = map.bounds


## Sposta subito (o con animazione) la vista su un punto.
func look_at_point(p: Vector2, dist: float = -1.0, instant: bool = false) -> void:
	_goal_target = p
	if dist > 0.0:
		_goal_distance = dist
	_clamp_goals()
	if instant:
		target = _goal_target
		distance = _goal_distance
		yaw = _goal_yaw
		_apply(true)


func set_yaw(value: float, instant: bool = false) -> void:
	_goal_yaw = value
	if instant:
		yaw = value


func goal_target() -> Vector2:
	return _goal_target


func goal_distance() -> float:
	return _goal_distance


## 0 = vicinissimo, 1 = vista d'insieme.
func zoom_factor() -> float:
	return clampf((distance - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE), 0.0, 1.0)


static func pitch_for(dist: float) -> float:
	var t: float = clampf((dist - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE), 0.0, 1.0)
	return deg_to_rad(lerpf(PITCH_NEAR, PITCH_FAR, pow(t, 0.55)))


## Limita lo stato desiderato: distanza fra minimo e massimo, punto osservato dentro la mappa
## (con un margine che cresce con lo zoom, così da lontano non si vede oltre il bordo).
func _clamp_goals() -> void:
	_goal_distance = clampf(_goal_distance, MIN_DISTANCE, MAX_DISTANCE)
	var t: float = clampf((_goal_distance - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE), 0.0, 1.0)
	var margin_x: float = minf(limits.size.x * 0.5 - 1.0, lerpf(4.0, 215.0, t))
	var margin_z: float = minf(limits.size.y * 0.5 - 1.0, lerpf(4.0, 150.0, t))
	var r := Rect2(limits.position + Vector2(margin_x, margin_z), limits.size - Vector2(margin_x, margin_z) * 2.0)
	_goal_target.x = clampf(_goal_target.x, r.position.x, r.end.x)
	_goal_target.y = clampf(_goal_target.y, r.position.y, r.end.y)


func _process(delta: float) -> void:
	if input_enabled:
		_keyboard_and_edges(delta)
	_clamp_goals()
	var k: float = 1.0 - exp(-SMOOTHING * delta)
	target = target.lerp(_goal_target, k)
	distance = lerpf(distance, _goal_distance, k)
	yaw = lerp_angle(yaw, _goal_yaw, k)
	_apply(false, delta)


func _keyboard_and_edges(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("cam_forward"):
		move.y -= 1.0
	if Input.is_action_pressed("cam_back"):
		move.y += 1.0
	if Input.is_action_pressed("cam_left"):
		move.x -= 1.0
	if Input.is_action_pressed("cam_right"):
		move.x += 1.0
	if edge_scroll and DisplayServer.window_is_focused():
		var vp: Viewport = get_viewport()
		var size: Vector2 = vp.get_visible_rect().size
		var m: Vector2 = vp.get_mouse_position()
		if m.x >= 0.0 and m.y >= 0.0 and m.x <= size.x and m.y <= size.y:
			if m.x < EDGE_PIXELS:
				move.x -= 1.0
			elif m.x > size.x - EDGE_PIXELS:
				move.x += 1.0
			if m.y < EDGE_PIXELS:
				move.y -= 1.0
			elif m.y > size.y - EDGE_PIXELS:
				move.y += 1.0
	if move != Vector2.ZERO:
		pan(move.limit_length(1.0) * PAN_SPEED * _goal_distance * delta)
	if Input.is_action_pressed("cam_rotate_left"):
		_goal_yaw -= ROTATE_SPEED * delta
	if Input.is_action_pressed("cam_rotate_right"):
		_goal_yaw += ROTATE_SPEED * delta


## Sposta il punto osservato in coordinate dello schermo (x a destra, y in basso).
func pan(screen_delta: Vector2) -> void:
	var right := Vector2(cos(_goal_yaw), -sin(_goal_yaw))
	var forward := Vector2(sin(_goal_yaw), cos(_goal_yaw))   # verso il basso dello schermo
	_goal_target += right * screen_delta.x + forward * screen_delta.y
	_clamp_goals()


## Zoom di `steps` scatti (positivi = avvicina) verso un punto del mondo, se indicato.
func zoom(steps: float, toward: Variant = null) -> void:
	var old: float = _goal_distance
	_goal_distance = clampf(_goal_distance * pow(ZOOM_STEP, steps), MIN_DISTANCE, MAX_DISTANCE)
	if toward is Vector2 and steps > 0.0:
		var f: float = 1.0 - _goal_distance / old
		_goal_target = _goal_target.lerp(toward, f)
	_clamp_goals()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mb.pressed
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var steps: float = (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * maxf(mb.factor, 1.0)
			zoom(steps, ground_under(mb.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _rotating:
		_goal_yaw -= (event as InputEventMouseMotion).relative.x * 0.006
	elif event is InputEventPanGesture:
		pan((event as InputEventPanGesture).delta * 0.02 * _goal_distance)
	elif event is InputEventMagnifyGesture:
		zoom(((event as InputEventMagnifyGesture).factor - 1.0) * 4.0)


## Punto del terreno (x, z) sotto una posizione dello schermo, oppure null.
func ground_under(screen_pos: Vector2) -> Variant:
	if camera == null or map == null or not map.is_valid():
		return null
	var o: Vector3 = camera.project_ray_origin(screen_pos)
	var d: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = map.intersect_ray(o, d)
	if hit == null:
		return null
	var h: Vector3 = hit
	return Vector2(h.x, h.z)


## Posizione della telecamera per uno stato dato (usata anche dai test).
static func camera_position(t: Vector2, ground: float, dist: float, yaw_angle: float) -> Vector3:
	var pitch: float = pitch_for(dist)
	var horiz: float = cos(pitch) * dist
	return Vector3(t.x + sin(yaw_angle) * horiz, ground + sin(pitch) * dist, t.y + cos(yaw_angle) * horiz)


func _apply(instant: bool, delta: float = 0.0) -> void:
	if camera == null:
		return
	var g: float = 0.0
	if map != null and map.is_valid():
		g = map.surface_at(target)
	_ground = g if instant else lerpf(_ground, g, 1.0 - exp(-6.0 * delta))
	var pos: Vector3 = camera_position(target, _ground, distance, yaw)
	if map != null and map.is_valid():
		pos.y = maxf(pos.y, map.surface_at(Vector2(pos.x, pos.z)) + CLEARANCE)
	camera.global_position = pos
	camera.look_at(Vector3(target.x, _ground, target.y), Vector3.UP)
	# Vicino serve più precisione, lontano bisogna vedere tutta la mappa.
	camera.near = clampf(distance * 0.02, 0.1, 4.0)
	var need_far: float = distance * 3.0 + 150.0
	camera.far = maxf(_preset_far, need_far)
