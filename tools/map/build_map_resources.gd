extends SceneTree
## Trasforma i file intermedi di tools/map/generate_map.py in risorse pronte per il gioco:
##   assets/map/terrain_mesh.res  mesh low-poly del terreno (ArrayMesh)
##   assets/map/heights.res       griglia di quote (Image RF) per telecamera, selezione e posizioni
##   assets/map/province_lookup.res  mappa degli id per la CPU (Image RG8: provincia, terra/acqua)
## Uso: godot --headless -s tools/map/build_map_resources.gd

const CACHE: String = "res://tools/map/_cache/"
const OUT: String = "res://assets/map/"


func _init() -> void:
	var ok: bool = _build_mesh() and _build_heights() and _build_lookup()
	quit(0 if ok else 1)


func _read_header(f: FileAccess, magic: String) -> Vector2i:
	var m: String = f.get_buffer(4).get_string_from_ascii()
	if m != magic:
		push_error("File non valido (atteso %s, trovato %s)" % [magic, m])
		return Vector2i(-1, -1)
	var a: int = f.get_32()
	var b: int = f.get_32()
	return Vector2i(a, b)


func _build_mesh() -> bool:
	var f := FileAccess.open(CACHE + "terrain_mesh.bin", FileAccess.READ)
	if f == null:
		push_error("Manca terrain_mesh.bin: esegui prima tools/map/generate_map.py")
		return false
	var counts: Vector2i = _read_header(f, "RGTM")
	if counts.x < 0:
		return false
	var nv: int = counts.x
	var nt: int = counts.y
	var pos_raw: PackedFloat32Array = f.get_buffer(nv * 12).to_float32_array()
	var nor_raw: PackedFloat32Array = f.get_buffer(nv * 12).to_float32_array()
	var idx: PackedInt32Array = f.get_buffer(nt * 12).to_int32_array()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(nv)
	normals.resize(nv)
	for i: int in nv:
		verts[i] = Vector3(pos_raw[i * 3], pos_raw[i * 3 + 1], pos_raw[i * 3 + 2])
		normals[i] = Vector3(nor_raw[i * 3], nor_raw[i * 3 + 1], nor_raw[i * 3 + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "terreno_campagna"
	var err: Error = ResourceSaver.save(mesh, OUT + "terrain_mesh.res", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Impossibile salvare la mesh (%s)" % error_string(err))
		return false
	print("Mesh del terreno: %d vertici, %d triangoli" % [nv, nt])
	return true


func _build_heights() -> bool:
	var f := FileAccess.open(CACHE + "heights.f32", FileAccess.READ)
	if f == null:
		push_error("Manca heights.f32")
		return false
	var size: Vector2i = _read_header(f, "RGTH")
	if size.x < 0:
		return false
	var data: PackedByteArray = f.get_buffer(size.x * size.y * 4)
	var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, data)
	var err: Error = ResourceSaver.save(img, OUT + "heights.res", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Impossibile salvare le quote (%s)" % error_string(err))
		return false
	print("Griglia delle quote: %d x %d" % [size.x, size.y])
	return true


func _build_lookup() -> bool:
	var src := Image.load_from_file(ProjectSettings.globalize_path(OUT + "province_ids.png"))
	if src == null or src.is_empty():
		push_error("Manca province_ids.png")
		return false
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var data: PackedByteArray = src.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 2)
	for i: int in w * h:
		out[i * 2] = data[i * 4]          # provincia (estesa di poco nel mare)
		out[i * 2 + 1] = data[i * 4 + 2]  # 255 = terra
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RG8, out)
	var err: Error = ResourceSaver.save(img, OUT + "province_lookup.res", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Impossibile salvare la mappa degli id (%s)" % error_string(err))
		return false
	print("Mappa degli id per la CPU: %d x %d" % [w, h])
	return true
