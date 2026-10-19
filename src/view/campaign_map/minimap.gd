class_name CampaignMinimap
extends Control
## Minimappa 2D cliccabile: colori delle fazioni, riquadro della vista, clic o trascinamento
## per spostare la telecamera.

signal point_clicked(world: Vector2)

var map: CampaignMapData = null
var camera_rig: CampaignCamera = null
var _tex: TextureRect = null
var _mat: ShaderMaterial = null
var _dragging: bool = false
var _footprint := PackedVector2Array()


func setup(map_data: CampaignMapData, rig: CampaignCamera, palette: PoliticalPalette, width: float) -> void:
	map = map_data
	camera_rig = rig
	var aspect: float = map.bounds.size.y / map.bounds.size.x
	custom_minimum_size = Vector2(width, roundf(width * aspect))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex = TextureRect.new()
	_tex.texture = load("res://assets/map/minimap_base.png")
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/campaign_minimap.gdshader")
	_mat.set_shader_parameter("ids_tex", load("res://assets/map/province_ids.png"))
	_mat.set_shader_parameter("palette_tex", palette.texture)
	_tex.material = _mat
	add_child(UiKit.fill(_tex))
	tooltip_text = ""


func set_selected(index: int) -> void:
	if _mat != null:
		_mat.set_shader_parameter("selected_index", float(index))


func world_to_local(p: Vector2) -> Vector2:
	return map.world_to_uv(p) * size


func local_to_world(p: Vector2) -> Vector2:
	return map.uv_to_world(p / size)


func _process(_delta: float) -> void:
	if camera_rig == null or camera_rig.camera == null:
		return
	# Riquadro della vista: i quattro angoli dello schermo proiettati sul livello del mare.
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var cam: Camera3D = camera_rig.camera
	var pts := PackedVector2Array()
	for c: Vector2 in [Vector2(0, 0), Vector2(vp_size.x, 0), vp_size, Vector2(0, vp_size.y)]:
		var o: Vector3 = cam.project_ray_origin(c)
		var d: Vector3 = cam.project_ray_normal(c)
		var t: float = 4000.0
		if d.y < -0.01:
			t = minf(t, -o.y / d.y)
		var hit: Vector3 = o + d * t
		pts.append(world_to_local(Vector2(hit.x, hit.z)))
	_footprint = pts
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BORDER, false, 1.0)
	if _footprint.size() == 4:
		var clipped := PackedVector2Array()
		for p: Vector2 in _footprint:
			clipped.append(p.clamp(Vector2.ZERO, size))
		clipped.append(clipped[0])
		draw_polyline(clipped, Color(1.0, 0.92, 0.7, 0.95), 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				point_clicked.emit(local_to_world(mb.position))
			accept_event()
		elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed:
			if camera_rig != null:
				camera_rig.zoom(1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		point_clicked.emit(local_to_world((event as InputEventMouseMotion).position))
		accept_event()
