class_name SettlementLayer
extends Node3D
## Città capoluogo: un MultiMesh per tipo (villaggio, cittadina, città, capitale), quindi 4
## chiamate di disegno per 47 città. Il colore della fazione è nei dati per istanza.
## Il nome sta sopra ogni città (Label3D a dimensione fissa sullo schermo).

const SCALE: Dictionary = {
	CampaignModels.Settlement.VILLAGE: 2.0,
	CampaignModels.Settlement.TOWN: 2.1,
	CampaignModels.Settlement.CITY: 2.2,
	CampaignModels.Settlement.CAPITAL: 2.4,
}

var _map: CampaignMapData = null
var _state: CampaignState = null
var _mm: Dictionary = {}                 # tier -> MultiMesh
var _slot: Dictionary[String, Vector2i] = {}   # pid -> (tier, indice istanza)
var _labels: Dictionary[String, Label3D] = {}
var _tier_of: Dictionary[String, int] = {}
var positions: Dictionary[String, Vector3] = {}


func setup(map: CampaignMapData, state: CampaignState, db: GameDatabase) -> void:
	_map = map
	_state = state
	var capitals: Dictionary = {}
	for fs: FactionState in state.factions.values():
		capitals[fs.capital] = true
	var by_tier: Dictionary = {}
	for pid: String in map.province_order:
		var p: ProvinceDef = db.provinces.get(pid)
		if p == null:
			continue
		var tier: int = CampaignModels.settlement_tier(p.population, capitals.has(pid))
		_tier_of[pid] = tier
		if not by_tier.has(tier):
			by_tier[tier] = []
		(by_tier[tier] as Array).append(pid)
		var c: Vector2 = map.city_pos[pid]
		positions[pid] = Vector3(c.x, map.surface_at(c), c.y)
	var shader: Shader = load("res://assets/shaders/campaign_props.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for tier: int in by_tier:
		var list: Array = by_tier[tier]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		# Colori per istanza bianchi: con il renderer Compatibilità il colore dei vertici viene
		# moltiplicato per quello dell'istanza, che senza questa opzione vale zero.
		mm.use_colors = true
		mm.mesh = CampaignModels.settlement_mesh(tier)
		mm.instance_count = list.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + tier
		for i: int in list.size():
			var pid: String = list[i]
			var s: float = SCALE[tier]
			var rot := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(rot, positions[pid]))
			mm.set_instance_color(i, Color.WHITE)
			_slot[pid] = Vector2i(tier, i)
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = mat
		node.name = "Citta_%d" % tier
		add_child(node)
		_mm[tier] = mm
	for pid: String in map.province_order:
		var p: ProvinceDef = db.provinces.get(pid)
		if p != null:
			_add_label(pid, p.city)
	refresh_all()


func _add_label(pid: String, city: String) -> void:
	var l := Label3D.new()
	var tier: int = _tier_of[pid]
	l.text = city
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font = UiTheme.title_font()
	l.font_size = 30 if tier >= CampaignModels.Settlement.CITY else 26
	l.outline_size = 9
	l.outline_modulate = Color(0.06, 0.05, 0.04, 0.9)
	l.modulate = Color("f3e6c4") if tier != CampaignModels.Settlement.CAPITAL else Color("ffd877")
	l.no_depth_test = true
	l.render_priority = 2
	l.position = positions[pid] + Vector3(0, 1.5 if tier >= CampaignModels.Settlement.CITY else 1.1, 0)
	l.name = "Nome_%s" % pid
	add_child(l)
	_labels[pid] = l


## Riscrive i colori di tutte le città (padroni cambiati).
func refresh_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for pid: String in _slot:
		_write_color(pid, rng.randf())


func refresh_province(pid: String) -> void:
	_write_color(pid, randf())


func _write_color(pid: String, phase: float) -> void:
	var s: Vector2i = _slot[pid]
	var c: Color = GameData.faction_color(_state.province_owner.get(pid, ""))
	(_mm[s.x] as MultiMesh).set_instance_custom_data(s.y, Color(c.r, c.g, c.b, phase))


## Nomi visibili secondo lo zoom: da lontano solo capitali e città grandi, e più piccoli.
## La dimensione cambia con la scala del nodo: cambiare pixel_size ricostruirebbe il testo di
## tutte le etichette a ogni fotogramma di zoom (lavoro inutile per il processore).
func update_labels(zoom: float) -> void:
	var s: float = lerpf(1.0, 0.69, smoothstep(0.2, 0.9, zoom))
	var scale_v := Vector3(s, s, s)
	for pid: String in _labels:
		var tier: int = _tier_of[pid]
		var visible_now: bool = zoom < 0.32 or tier == CampaignModels.Settlement.CAPITAL \
				or (zoom < 0.62 and tier >= CampaignModels.Settlement.CITY)
		var l: Label3D = _labels[pid]
		if l.visible != visible_now:
			l.visible = visible_now
		if visible_now:
			l.scale = scale_v


func label_of(pid: String) -> Label3D:
	return _labels.get(pid)


func tier_of(pid: String) -> int:
	return _tier_of.get(pid, 0)
