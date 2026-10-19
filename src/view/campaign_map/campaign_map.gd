class_name CampaignMapScene
extends Node3D
## Mappa di campagna 3D: terreno, mare, città, eserciti, telecamera, selezione delle province
## e interfaccia. Solo grafica e input: le regole stanno in src/core (TurnProcessor ecc.).

const TERRAIN_SHADER: String = "res://assets/shaders/campaign_terrain.gdshader"
const WATER_SHADER: String = "res://assets/shaders/campaign_water.gdshader"
const START_DISTANCE: float = 95.0
const FOCUS_DISTANCE: float = 32.0
## Ombre del sole solo da vicino: piene fino a SHADOW_FULL, sfumano fino a SHADOW_OFF, poi
## spente. Le proiettano solo città ed eserciti, che da lontano sono troppo piccoli per
## vederle, mentre leggere la mappa delle ombre su ogni pixel del terreno costa sempre.
const SHADOW_FULL: float = 30.0
const SHADOW_OFF: float = 55.0

var map: CampaignMapData = null
var state: CampaignState = null
var cam: CampaignCamera = null
var palette: PoliticalPalette = null
var terrain_material: ShaderMaterial = null
var water_material: ShaderMaterial = null
var settlements: SettlementLayer = null
var details: CampaignDetails = null
var detail_layer: DetailLayer = null
var army_layer: ArmyLayer = null
var hud: CampaignHud = null
var environment: Environment = null
var sun: DirectionalLight3D = null
var terrain_node: MeshInstance3D = null
var water_node: MeshInstance3D = null

var selected: String = ""
var hovered: String = ""
## Millisecondi impiegati a costruire la scena (mostrati con F3).
var load_ms: float = 0.0

var _last_zoom: float = -1.0
var _press_pos: Vector2 = Vector2.ZERO
var _press_valid: bool = false
var _last_mouse: Vector2 = Vector2(-1, -1)
var _last_cam: Vector3 = Vector3.ZERO
## Fotogrammi iniziali con le ombre accese: compilano subito le varianti degli shader con le
## ombre, così il primo zoom ravvicinato non scatta.
var _shadow_warmup: int = 2


func _ready() -> void:
	var t0: int = Time.get_ticks_usec()
	CampaignControls.ensure_actions()
	Session.return_scene = ""
	state = Session.state
	if state == null:
		Scenes.goto(get_tree(), Scenes.MAIN_MENU)
		return
	map = GameData.map_data()
	if map == null or not map.is_valid():
		push_error("Mappa di campagna non disponibile")
		Scenes.goto(get_tree(), Scenes.MAIN_MENU)
		return
	details = GameData.map_details()
	_build_environment()
	palette = PoliticalPalette.new()
	palette.rebuild(state, map)
	_build_terrain()
	_build_water()
	settlements = SettlementLayer.new()
	settlements.name = "Citta"
	add_child(settlements)
	settlements.setup(map, state, GameData.db, details)
	army_layer = ArmyLayer.new()
	army_layer.name = "Eserciti"
	add_child(army_layer)
	army_layer.setup(map, state)
	cam = CampaignCamera.new()
	cam.name = "Telecamera"
	add_child(cam)
	cam.setup(map)
	detail_layer = DetailLayer.new()
	detail_layer.name = "Dettagli"
	add_child(detail_layer)
	detail_layer.setup(map, details, cam.camera)
	var me: FactionState = state.player()
	var start: Vector2 = map.city_pos.get(me.capital if me != null else "", map.bounds.get_center())
	cam.look_at_point(start, START_DISTANCE, true)
	hud = CampaignHud.new()
	hud.name = "Interfaccia"
	add_child(hud)
	hud.setup(self)
	_apply_season()
	load_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if Session.map_benchmark:
		var bench := MapBenchmark.new()
		bench.name = "TestMappa"
		add_child(bench)
		bench.setup(self)
	elif Session.last_report != null:
		hud.show_turn_report(Session.last_report)
	Session.last_report = null  # il riepilogo si mostra una volta sola


# ------------------------------------------------------------------ costruzione

func _build_environment() -> void:
	environment = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3f6290")
	sky_mat.sky_horizon_color = Color("b9c6cc")
	sky_mat.ground_horizon_color = Color("8d9aa0")
	sky_mat.ground_bottom_color = Color("2a3640")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 2.2
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("9eb0bb")
	environment.fog_light_energy = 1.0
	environment.fog_sky_affect = 0.6
	environment.fog_depth_curve = 1.4
	Settings.configure_environment(environment)
	# Sulla mappa non c'è nulla che brilli (niente luci né materiali emissivi): il glow
	# costerebbe un passaggio a tutto schermo senza cambiare l'immagine.
	environment.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -42, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.1
	Settings.configure_sun(sun)
	# Sulla mappa le ombre coprono solo la zona vicina alla telecamera: bastano 2 suddivisioni.
	if sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _build_terrain() -> void:
	var mesh: Mesh = load("res://assets/map/terrain_mesh.res")
	terrain_node = MeshInstance3D.new()
	terrain_node.name = "Terreno"
	terrain_node.mesh = mesh
	terrain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load(TERRAIN_SHADER)
	terrain_material.set_shader_parameter("albedo_tex", load("res://assets/map/terrain_albedo.png"))
	terrain_material.set_shader_parameter("ids_tex", load("res://assets/map/province_ids.png"))
	terrain_material.set_shader_parameter("fields_tex", load("res://assets/map/province_fields.png"))
	terrain_material.set_shader_parameter("palette_tex", palette.texture)
	terrain_material.set_shader_parameter("detail_tex", load("res://assets/map/water_noise.png"))
	terrain_material.set_shader_parameter("details_tex", load("res://assets/map/details.png"))
	terrain_material.set_shader_parameter("road_scale", details.road_scale)
	terrain_material.set_shader_parameter("roads_tex", load("res://assets/map/roads.png"))
	terrain_material.set_shader_parameter("map_min", map.bounds.position)
	terrain_material.set_shader_parameter("map_size", map.bounds.size)
	terrain_material.set_shader_parameter("vertical_units_per_km", map.vertical_units_per_km)
	terrain_node.material_override = terrain_material
	add_child(terrain_node)


func _build_water() -> void:
	water_node = MeshInstance3D.new()
	water_node.name = "Mare"
	var plane := PlaneMesh.new()
	var size: Vector2 = map.bounds.size + Vector2(1400, 1400)
	plane.size = size
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	water_node.mesh = plane
	water_node.position = Vector3(map.bounds.get_center().x, 0.0, map.bounds.get_center().y)
	water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_material = ShaderMaterial.new()
	water_material.shader = load(WATER_SHADER)
	water_material.set_shader_parameter("fields_tex", load("res://assets/map/province_fields.png"))
	water_material.set_shader_parameter("noise_tex", load("res://assets/map/water_noise.png"))
	water_material.set_shader_parameter("map_min", map.bounds.position)
	water_material.set_shader_parameter("map_size", map.bounds.size)
	# Il mare si disegna dopo il terreno: dove c'è terra lo scarta il test di profondità
	# senza eseguire lo shader dell'acqua (meno lavoro per la scheda video).
	water_material.render_priority = 1
	water_node.material_override = water_material
	add_child(water_node)


func _apply_season() -> void:
	var w: float = 1.0 if state.season_index() == 1 else 0.0
	terrain_material.set_shader_parameter("winter", w)
	water_material.set_shader_parameter("winter", w)
	detail_layer.set_winter(w)
	sun.light_color = Color("fff0d6") if w < 0.5 else Color("e4ecf5")
	sun.light_energy = 1.1 if w < 0.5 else 0.95


# ------------------------------------------------------------------ ciclo

func _process(_delta: float) -> void:
	if cam == null:
		return
	cam.input_enabled = not hud.is_modal_open() and not Session.map_benchmark
	var z: float = cam.zoom_factor()
	if absf(z - _last_zoom) > 0.002:
		_last_zoom = z
		settlements.update_labels(z)
		terrain_material.set_shader_parameter("tint_strength", lerpf(0.2, 0.4, z))
		# Nebbia di distanza che segue lo zoom: lontano copre solo l'orizzonte.
		environment.fog_depth_begin = cam.distance * 1.3
		environment.fog_depth_end = cam.distance * 4.0 + 120.0
		detail_layer.update_zoom(cam.distance)
		if _shadow_warmup <= 0:
			update_shadows(cam.distance)
	if _shadow_warmup > 0:
		_shadow_warmup -= 1
		if _shadow_warmup == 0:
			update_shadows(cam.distance)
	_update_hover()


## Ombre del sole secondo la distanza della telecamera (vedi SHADOW_FULL e SHADOW_OFF).
func update_shadows(dist: float) -> void:
	var allowed: bool = Settings.graphics.shadows_enabled()
	var on: bool = allowed and dist < SHADOW_OFF
	if sun.shadow_enabled != on:
		sun.shadow_enabled = on
	if on:
		sun.shadow_opacity = 1.0 - smoothstep(SHADOW_FULL, SHADOW_OFF, dist)
		sun.directional_shadow_max_distance = clampf(dist * 2.5, 20.0, maxf(Settings.graphics.shadow_distance(), 20.0))


func _update_hover() -> void:
	var m: Vector2 = get_viewport().get_mouse_position()
	var cpos: Vector3 = cam.camera.global_position
	if m == _last_mouse and cpos.distance_squared_to(_last_cam) < 0.0001:
		return
	_last_mouse = m
	_last_cam = cpos
	var pid: String = ""
	if not hud.is_pointer_over_ui() and not hud.is_modal_open():
		pid = province_at_screen(m)
	if pid != hovered:
		hovered = pid
		terrain_material.set_shader_parameter("hover_index", float(map.index_of.get(pid, -1)))
	hud.update_tooltip(hovered, m)


## Provincia sotto un punto dello schermo ("" se mare, terre esterne o fuori mappa).
func province_at_screen(screen_pos: Vector2) -> String:
	var g: Variant = cam.ground_under(screen_pos)
	if g == null:
		return ""
	return map.province_at(g)


# ------------------------------------------------------------------ selezione e tasti

func _unhandled_input(event: InputEvent) -> void:
	if hud == null or hud.is_modal_open() or Session.map_benchmark:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_press_valid = true
				if mb.double_click:
					var pid: String = province_at_screen(mb.position)
					if not pid.is_empty():
						select_province(pid)
						focus_province(pid)
					_press_valid = false
			elif _press_valid and mb.position.distance_to(_press_pos) < 6.0:
				_press_valid = false
				select_province(province_at_screen(mb.position))
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			select_province("")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not selected.is_empty():
			select_province("")
		else:
			hud.open_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("end_turn"):
		end_turn()
		get_viewport().set_input_as_handled()


func select_province(pid: String) -> void:
	selected = pid
	terrain_material.set_shader_parameter("selected_index", float(map.index_of.get(pid, -1)))
	hud.show_province(pid)


## Centra la vista sulla provincia (doppio clic, pannello, minimappa).
func focus_province(pid: String) -> void:
	if not map.city_pos.has(pid):
		return
	var c: Vector2 = map.city_pos[pid]
	var l: Vector2 = map.label_pos.get(pid, c)
	cam.look_at_point(c.lerp(l, 0.3), minf(cam.goal_distance(), FOCUS_DISTANCE * 2.2))


func focus_point(p: Vector2) -> void:
	cam.look_at_point(p)


# ------------------------------------------------------------------ turni

func end_turn() -> void:
	if hud.is_modal_open():
		return
	var report: TurnReport = Session.end_turn()
	if report == null:
		return
	_apply_season()
	palette.refresh_all()
	settlements.refresh_all()
	hud.refresh()
	if not selected.is_empty():
		hud.show_province(selected)
	hud.show_turn_report(report)
	Session.last_report = null
