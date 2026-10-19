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
## Blocchi di alberi messi in scena al massimo per fotogramma.
const BUILDS_PER_FRAME: int = 2
## Blocchi preparati in parallelo sugli altri core del processore.
const MAX_JOBS: int = 4


## Preparazione dei dati di un blocco di alberi, eseguita su un thread separato: il ciclo in
## GDScript costa qualche millisecondo per blocco e sul thread principale farebbe scattare la vista.
class TreeJob:
	extends RefCounted
	var index: int = 0
	var chunk: Dictionary = {}
	var fraction: float = 1.0
	var source: CampaignDetails = null
	var buf := PackedFloat32Array()

	func run() -> void:
		buf = source.tree_chunk_buffer(chunk, fraction)
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
## Blocchi in preparazione: indice -> [id del compito, TreeJob]
var _jobs: Dictionary[int, Array] = {}
## false = prepara i blocchi sul thread principale (test).
var threaded: bool = true


func setup(map: CampaignMapData, det: CampaignDetails, camera: Camera3D) -> void:
	_map = map
	details = det
	_camera = camera
	var veg: float = clampf(Settings.graphics.vegetation_density, 0.0, 1.0)
	tree_fraction = veg
	# Con meno vegetazione gli alberi spariscono anche prima.
	tree_fade_end = lerpf(19.0, 27.0, clampf((veg - 0.3) / 0.7, 0.0, 1.0))
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


func _exit_tree() -> void:
	for i: int in _jobs:
		WorkerThreadPool.wait_for_task_completion(int(_jobs[i][0]))
	_jobs.clear()


func _process(delta: float) -> void:
	if details == null or _camera == null or tree_fraction <= 0.0:
		return
	_check_timer -= delta
	if _check_timer > 0.0 and _jobs.is_empty():
		return
	_check_timer = 0.15
	update_trees(_camera.global_position)


## Prepara (su un altro thread) e mette in scena i blocchi di alberi vicini alla telecamera,
## i più vicini per primi. Restituisce quanti blocchi ha messo in scena in questa chiamata.
func update_trees(cam_pos: Vector3, max_builds: int = BUILDS_PER_FRAME) -> int:
	var built: int = 0
	# blocchi pronti
	for i: int in _jobs.keys():
		if built >= max_builds:
			break
		var task: int = int(_jobs[i][0])
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			var job: TreeJob = _jobs[i][1]
			_jobs.erase(i)
			_add_chunk(i, job.chunk, job.buf)
			built += 1
	# nuovi blocchi da preparare, dal più vicino
	var reach: float = tree_fade_end + details.tree_chunk_size
	var cam2 := Vector2(cam_pos.x, cam_pos.z)
	var wanted: Array = []
	for i: int in details.tree_chunks.size():
		if _tree_nodes.has(i) or _jobs.has(i):
			continue
		var c: Dictionary = details.tree_chunks[i]
		var r: Rect2 = c["rect"]
		var dy: float = maxf(cam_pos.y - float(c["y_max"]), 0.0)
		var dxz: float = maxf(cam2.distance_to(r.get_center()) - r.size.x * 0.71, 0.0)
		var d: float = Vector2(dxz, dy).length()
		if d <= reach:
			wanted.append([d, i])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for w: Array in wanted:
		var i: int = w[1]
		var c: Dictionary = details.tree_chunks[i]
		if not threaded:
			if built >= max_builds:
				break
			_add_chunk(i, c, details.tree_chunk_buffer(c, tree_fraction))
			built += 1
			continue
		if _jobs.size() >= MAX_JOBS:
			break
		var job := TreeJob.new()
		job.index = i
		job.chunk = c
		job.fraction = tree_fraction
		job.source = details
		_jobs[i] = [WorkerThreadPool.add_task(job.run, false, "Alberi"), job]
	return built


func _add_chunk(i: int, c: Dictionary, buf: PackedFloat32Array) -> void:
	var node := MultiMeshInstance3D.new()
	node.name = "Alberi_%d" % i
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# misurata dal centro del blocco: oltre fade_end + mezza diagonale gli alberi sono già spariti
	node.visibility_range_end = tree_fade_end + details.tree_chunk_size * 0.71
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
