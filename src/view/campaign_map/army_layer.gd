class_name ArmyLayer
extends Node3D
## Eserciti sulla mappa: un solo MultiMesh (stendardo + tre soldati in miniatura) con il colore
## della fazione nei dati per istanza. Nella Fase 2 gli eserciti sono fermi accanto alla città.

var multimesh: MultiMesh = null
var positions: Dictionary[String, Vector3] = {}
var _ids: PackedStringArray = []


func setup(map: CampaignMapData, state: CampaignState) -> void:
	var by_province: Dictionary = {}
	for a: ArmyState in state.armies.values():
		if not by_province.has(a.province):
			by_province[a.province] = []
		(by_province[a.province] as Array).append(a)
	for pid: String in by_province:
		var list: Array = by_province[pid]
		list.sort_custom(func(x: ArmyState, y: ArmyState) -> bool: return x.id < y.id)
		for i: int in list.size():
			var a: ArmyState = list[i]
			positions[a.id] = slot_position(map, pid, i)
	_ids = PackedStringArray(positions.keys())
	_ids.sort()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true  # vedi SettlementLayer
	multimesh.mesh = CampaignModels.army_mesh()
	multimesh.instance_count = _ids.size()
	for i: int in _ids.size():
		var a: ArmyState = state.armies[_ids[i]]
		var c: Color = GameData.faction_color(a.faction)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, 0.4 * i).scaled(Vector3(2.2, 2.2, 2.2)), positions[a.id]))
		multimesh.set_instance_custom_data(i, Color(c.r, c.g, c.b, float(i % 7) / 7.0))
		multimesh.set_instance_color(i, Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/campaign_props.gdshader")
	node.material_override = mat
	node.name = "Eserciti"
	add_child(node)


## Posizione dell'i-esimo esercito in una provincia: vicino alla città, verso l'interno,
## sempre sulla terraferma.
static func slot_position(map: CampaignMapData, pid: String, i: int) -> Vector3:
	var city: Vector2 = map.city_pos.get(pid, Vector2.ZERO)
	var toward: Vector2 = map.label_pos.get(pid, city) - city
	var dir: Vector2 = toward.normalized() if toward.length() > 0.5 else Vector2(1, 0.4).normalized()
	var base_angle: float = dir.angle()
	for attempt: int in 12:
		var ang: float = base_angle + (i * 0.75) + attempt * (TAU / 12.0)
		var p: Vector2 = city + Vector2.from_angle(ang) * (2.6 + 0.8 * i)
		if map.is_land(p) and map.province_at(p) == pid:
			return Vector3(p.x, map.surface_at(p), p.y)
	var q: Vector2 = city + dir * 1.2
	return Vector3(q.x, map.surface_at(q), q.y)
