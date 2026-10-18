class_name LowPolyBuilder
extends RefCounted
## Unisce forme semplici (cilindri, sfere, cubi) in un'unica mesh low-poly con colori per vertice.
## UV.x = 1 indica le parti da tingere col colore della fazione (tunica, scudo).

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func add(mesh: PrimitiveMesh, xform: Transform3D, color: Color, team_tint: bool = false) -> LowPolyBuilder:
	var arrays: Array = mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: int = _verts.size()
	var nb: Basis = xform.basis.inverse().transposed()
	var tint := Vector2(1.0 if team_tint else 0.0, 0.0)
	for i: int in v.size():
		_verts.append(xform * v[i])
		_normals.append((nb * n[i]).normalized())
		_colors.append(color)
		_uvs.append(tint)
	for i: int in idx:
		_indices.append(base + i)
	return self


func triangle_count() -> int:
	return floori(_indices.size() / 3.0)


func build() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ------------------------------------------------------------------ forme base

static func cylinder(top: float, bottom: float, height: float, sides: int = 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 0
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(radius: float, sides: int = 6, rings: int = 3) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = sides
	s.rings = rings
	return s


static func at(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	return Transform3D(b, pos)


# ------------------------------------------------------------------ modelli provvisori

const SKIN: Color = Color("c89a74")
const CLOTH_DARK: Color = Color("4a3a2a")
const METAL: Color = Color("8d8f93")
const WOOD: Color = Color("6b4a2b")
const HORSE: Color = Color("5a3d28")


## Fante (origine ai piedi, guarda verso -Z, alto circa 1,8 m). ~150 triangoli.
static func soldier_mesh() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.add(box(Vector3(0.13, 0.8, 0.15)), at(Vector3(-0.09, 0.4, 0)), CLOTH_DARK)
	b.add(box(Vector3(0.13, 0.8, 0.15)), at(Vector3(0.09, 0.4, 0)), CLOTH_DARK)
	b.add(cylinder(0.2, 0.17, 0.66), at(Vector3(0, 1.12, 0)), Color(1, 1, 1), true)
	b.add(sphere(0.11), at(Vector3(0, 1.58, 0)), SKIN)
	b.add(cylinder(0.02, 0.125, 0.15), at(Vector3(0, 1.7, 0)), METAL)
	b.add(cylinder(0.32, 0.32, 0.05, 8), at(Vector3(-0.27, 1.1, -0.14), Vector3(90, 0, 0)), Color(0.75, 0.75, 0.75), true)
	b.add(cylinder(0.018, 0.018, 2.4, 4), at(Vector3(0.23, 1.25, -0.05)), WOOD)
	b.add(cylinder(0.0, 0.04, 0.16, 4), at(Vector3(0.23, 2.5, -0.05)), METAL)
	return b.build()


## Cavaliere a cavallo (origine a terra, guarda verso -Z). ~300 triangoli.
static func cavalry_mesh() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	for x: float in [-0.17, 0.17]:
		for z: float in [-0.58, 0.58]:
			b.add(box(Vector3(0.12, 0.95, 0.14)), at(Vector3(x, 0.47, z)), HORSE)
	b.add(box(Vector3(0.5, 0.55, 1.55)), at(Vector3(0, 1.2, 0)), HORSE)
	b.add(box(Vector3(0.3, 0.75, 0.32)), at(Vector3(0, 1.6, -0.82), Vector3(-30, 0, 0)), HORSE)
	b.add(box(Vector3(0.24, 0.26, 0.55)), at(Vector3(0, 1.92, -1.1), Vector3(15, 0, 0)), HORSE)
	b.add(box(Vector3(0.56, 0.06, 0.7)), at(Vector3(0, 1.5, 0.05)), Color(1, 1, 1), true)
	b.add(cylinder(0.19, 0.16, 0.62), at(Vector3(0, 1.85, 0.05)), Color(1, 1, 1), true)
	b.add(sphere(0.11), at(Vector3(0, 2.3, 0.05)), SKIN)
	b.add(cylinder(0.02, 0.125, 0.15), at(Vector3(0, 2.42, 0.05)), METAL)
	b.add(cylinder(0.28, 0.28, 0.05, 8), at(Vector3(-0.3, 1.85, 0.0), Vector3(0, 0, 90)), Color(0.75, 0.75, 0.75), true)
	b.add(cylinder(0.018, 0.018, 3.0, 4), at(Vector3(0.28, 2.0, -0.4), Vector3(-70, 0, 0)), WOOD)
	return b.build()


## Albero low-poly (tronco e due coni).
static func tree_mesh() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.add(cylinder(0.12, 0.18, 1.6, 5), at(Vector3(0, 0.8, 0)), WOOD)
	b.add(cylinder(0.0, 1.5, 2.6, 7), at(Vector3(0, 2.6, 0)), Color("2f4a26"))
	b.add(cylinder(0.0, 1.1, 2.0, 7), at(Vector3(0, 3.8, 0)), Color("3b5a2e"))
	return b.build()
