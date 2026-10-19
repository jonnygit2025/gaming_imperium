extends SceneTree
## Terreno semplificato per le viste lontane (assets/map/terrain_mesh_far.res), ottenuto dalla
## mesh completa con la semplificazione di Godot (meshoptimizer, che conserva i bordi).
## Da lontano 310.000 triangoli diventano di pochi pixel l'uno: con l'antialiasing la scheda
## video lavora molto per nulla. Uso: godot --headless -s tools/map/build_far_terrain.gd

const SRC: String = "res://assets/map/terrain_mesh.res"
const OUT: String = "res://assets/map/terrain_mesh_far.res"
## Frazione di triangoli desiderata.
const TARGET: float = 0.22


func _init() -> void:
	var src: ArrayMesh = load(SRC)
	if src == null:
		push_error("Manca %s" % SRC)
		quit(1)
		return
	var arrays: Array = src.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var best: PackedInt32Array = idx
	var want: int = int(idx.size() * TARGET)
	for i: int in im.get_surface_lod_count(0):
		var lod: PackedInt32Array = im.get_surface_lod_indices(0, i)
		print("livello %d: %.0f triangoli" % [i, lod.size() / 3.0])
		if absi(lod.size() - want) < absi(best.size() - want):
			best = lod
	# solo i vertici usati dai triangoli rimasti
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var new_of := PackedInt32Array()
	new_of.resize(src_v.size())
	new_of.fill(-1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(best.size())
	for i: int in best.size():
		var v: int = best[i]
		if new_of[v] < 0:
			new_of[v] = verts.size()
			verts.append(src_v[v])
			normals.append(src_n[v])
		new_idx[i] = new_of[v]
	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = verts
	out_arrays[Mesh.ARRAY_NORMAL] = normals
	out_arrays[Mesh.ARRAY_INDEX] = new_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	mesh.resource_name = "terreno_campagna_lontano"
	var err: Error = ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Impossibile salvare (%s)" % error_string(err))
		quit(1)
		return
	print("Terreno lontano: %.0f triangoli (completo %.0f)" % [best.size() / 3.0, idx.size() / 3.0])
	quit(0)
