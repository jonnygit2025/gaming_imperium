class_name DetailLayer
extends Node3D
## Dettagli della mappa che appaiono avvicinandosi: alberi dei boschi, villaggi minori e porti.
## (Strade e campi coltivati sono disegnati dallo shader del terreno.)
##
## Alberi: un MultiMesh per blocco di 12×12 unità, costruito solo quando la telecamera ci arriva
## vicino (pochi blocchi per fotogramma). Ogni blocco ha una distanza di visibilità, così il motore
## non disegna quelli lontani; lo shader rimpicciolisce gli alberi verso il limite.
## La quantità segue la densità della vegetazione del preset grafico.

const TREE_SHADER: String = "res://assets/shaders/campaign_trees.gdshader"
const PROPS_SHADER: String = "res://assets/shaders/campaign_props.gdshader"
const HAMLET_SCALE: float = 2.0
const PORT_SCALE: float = 2.2
## Blocchi di alberi costruiti al massimo per fotogramma.
const BUILDS_PER_FRAME: int = 3
## Oltre questa distanza della telecamera villaggi minori e porti non si leggono più: nascosti.
const SMALL_PROPS_MAX_DISTANCE: float = 150.0

var details: CampaignDetails = null
var tree_fade_start: float = 18.0
var tree_fade_end: float = 30.0
var tree_fraction: float = 1.0
var hamlet_multimeshes: Dictionary[String, MultiMesh] = {}
var port_multimesh: MultiMesh = null

var _map: CampaignMapData = null
var _tree_mat: ShaderMaterial = null
var _tree_mesh: ArrayMesh = null
var _tree_nodes: Dictionary[int, MultiMeshInstance3D] = {}
var _check_timer: float = 0.0
var _camera: Camera3D = null


func setup(map: CampaignMapData, det: CampaignDetails, camera: Camera3D) -> void:
	_map = map
	details = det
	_camera = camera
	var veg: float = clampf(Settings.graphics.vegetation_density, 0.0, 1.0)
	tree_fraction = veg
	# Con meno vegetazione gli alberi spariscono anche prima.
	tree_fade_end = lerpf(20.0, 30.0, clampf((veg - 0.3) / 0.7, 0.0, 1.0))
	tree_fade_start = tree_fade_end * 0.6
	_tree_mat = ShaderMaterial.new()
	_tree_mat.shader = load(TREE_SHADER)
	_tree_mat.set_shader_parameter("fade_start", tree_fade_start)
	_tree_mat.set_shader_parameter("fade_end", tree_fade_end)
	_tree_mesh = CampaignModels.tree_mesh()
	var props := ShaderMaterial.new()
	props.shader = load(PROPS_SHADER)
	_build_hamlets(props)
	_build_ports(props)


## Da chiamare quando cambia lo zoom.
func update_zoom(camera_distance: float) -> void:
	var near_enough: bool = camera_distance < SMALL_PROPS_MAX_DISTANCE
	for c: Node in get_children():
		if c is MultiMeshInstance3D and not c.name.begins_with("Alberi"):
			(c as MultiMeshInstance3D).visible = near_enough


func set_winter(w: float) -> void:
	if _tree_mat != null:
		_tree_mat.set_shader_parameter("winter", w)


func tree_chunks_built() -> int:
	return _tree_nodes.size()


func _build_hamlets(mat: ShaderMaterial) -> void:
	var by_style: Dictionary[String, Array] = {}
	for pid: String in details.hamlets:
		var style: String = details.style_of(pid)
		if not by_style.has(style):
			by_style[style] = []
		for p: Vector2 in details.hamlets[pid]:
			by_style[style].append(p)
	for style: String in by_style:
		var pts: Array = by_style[style]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = CampaignModels.hamlet_mesh(style)
		mm.instance_count = pts.size()
		for i: int in pts.size():
			var p: Vector2 = pts[i]
			var yaw: float = fposmod(p.x * 1.7 + p.y * 2.3, TAU)
			var xb := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * HAMLET_SCALE)
			mm.set_instance_transform(i, Transform3D(xb, Vector3(p.x, _map.surface_at(p), p.y)))
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, Color(1, 1, 1, 0))
		var node := MultiMeshInstance3D.new()
		node.name = "Villaggi_%s" % style
		node.multimesh = mm
		node.material_override = mat
		add_child(node)
		hamlet_multimeshes[style] = mm


func _build_ports(mat: ShaderMaterial) -> void:
	var ids: Array[String] = []
	ids.assign(details.ports.keys())
	ids.sort()
	port_multimesh = MultiMesh.new()
	port_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	port_multimesh.use_colors = true
	port_multimesh.use_custom_data = true
	port_multimesh.mesh = CampaignModels.port_mesh()
	port_multimesh.instance_count = ids.size()
	for i: int in ids.size():
		var p: Vector3 = details.ports[ids[i]]
		# il molo (asse +X del modello) guarda verso il mare
		var xb := Basis(Vector3.UP, -p.z).scaled(Vector3.ONE * PORT_SCALE)
		port_multimesh.set_instance_transform(i, Transform3D(xb, Vector3(p.x, 0.0, p.y)))
		port_multimesh.set_instance_color(i, Color.WHITE)
		port_multimesh.set_instance_custom_data(i, Color(1, 1, 1, float(i % 7) / 7.0))
	var node := MultiMeshInstance3D.new()
	node.name = "Porti"
	node.multimesh = port_multimesh
	node.material_override = mat
	add_child(node)


func _process(delta: float) -> void:
	if details == null or _camera == null or tree_fraction <= 0.0:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.15
	update_trees(_camera.global_position)


## Costruisce i blocchi di alberi vicini alla telecamera (al massimo BUILDS_PER_FRAME alla volta).
## Restituisce quanti ne ha costruiti.
func update_trees(cam_pos: Vector3, max_builds: int = BUILDS_PER_FRAME) -> int:
	var reach: float = tree_fade_end + details.tree_chunk_size
	var built: int = 0
	var cam2 := Vector2(cam_pos.x, cam_pos.z)
	for i: int in details.tree_chunks.size():
		if _tree_nodes.has(i):
			continue
		var c: Dictionary = details.tree_chunks[i]
		var r: Rect2 = c["rect"]
		var center: Vector2 = r.get_center()
		var dy: float = maxf(cam_pos.y - float(c["y_max"]), 0.0)
		var dxz: float = maxf(cam2.distance_to(center) - r.size.x * 0.71, 0.0)
		if Vector2(dxz, dy).length() > reach:
			continue
		_build_chunk(i, c)
		built += 1
		if built >= max_builds:
			break
	return built


func _build_chunk(i: int, c: Dictionary) -> void:
	var buf: PackedFloat32Array = details.tree_chunk_buffer(c, tree_fraction)
	var node := MultiMeshInstance3D.new()
	node.name = "Alberi_%d" % i
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = tree_fade_end + details.tree_chunk_size
	node.material_override = _tree_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _tree_mesh
	@warning_ignore("integer_division")
	mm.instance_count = buf.size() / 20
	if mm.instance_count > 0:
		mm.buffer = buf
	var r: Rect2 = c["rect"]
	mm.custom_aabb = AABB(Vector3(r.position.x, -0.5, r.position.y), Vector3(r.size.x, float(c["y_max"]) + 1.0, r.size.y))
	node.multimesh = mm
	add_child(node)
	_tree_nodes[i] = node
