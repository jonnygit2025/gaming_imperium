class_name RegimentView
extends MultiMeshInstance3D
## Un reggimento = una MultiMesh. Muovere il reggimento costa una sola trasformazione;
## l'animazione dei singoli soldati è nello shader.

const SPACING_INFANTRY: float = 1.1
const SPACING_CAVALRY: float = 2.0

var soldier_count: int = 0
var marching: bool = false:
	set(value):
		if value != marching:
			marching = value
			_write_custom()

var _team_color: Color = Color.WHITE
var _phases := PackedFloat32Array()


func setup(mesh: Mesh, material: Material, count: int, ranks: int, team_color: Color, mounted: bool, rng: RandomNumberGenerator) -> void:
	soldier_count = count
	_team_color = team_color
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	var spacing: float = SPACING_CAVALRY if mounted else SPACING_INFANTRY
	var files: int = maxi(1, ceili(float(count) / ranks))
	var width: float = (files - 1) * spacing
	_phases.resize(count)
	for i: int in count:
		var file: int = i % files
		var rank: int = floori(float(i) / files)
		var pos := Vector3(file * spacing - width * 0.5, 0.0, rank * spacing * (1.6 if mounted else 1.0))
		pos.x += rng.randf_range(-0.15, 0.15)
		pos.z += rng.randf_range(-0.15, 0.15)
		var b := Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
		mm.set_instance_transform(i, Transform3D(b, pos))
		_phases[i] = rng.randf() * 0.49
	multimesh = mm
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_write_custom()


func _write_custom() -> void:
	if multimesh == null:
		return
	var offset: float = 0.5 if marching else 0.0
	for i: int in soldier_count:
		multimesh.set_instance_custom_data(i, Color(_team_color.r, _team_color.g, _team_color.b, _phases[i] + offset))
