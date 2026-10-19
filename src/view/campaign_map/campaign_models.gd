class_name CampaignModels
extends RefCounted
## Modelli low-poly della mappa di campagna, costruiti da forme semplici (nessun file esterno).
## Unità: 1 = 10 km. Città ed eserciti sono "fuori scala" come nelle mappe strategiche.
##
## Le città hanno quattro stili architettonici (vedi CampaignDetails.STYLES):
##   mediterraneo   tetti in coppi, intonaco chiaro, foro e tempio con colonne, anfiteatro
##   orientale      pietra chiara, cupole, chiese a pianta centrale, mura teodosiane
##   settentrionale case in legno con tetti di paglia, palizzate, chiesa in pietra
##   desertico      mattoni crudi, tetti piatti, palme, palazzo a gradoni
## e quattro taglie (villaggio, cittadina, città, capitale). Le parti con UV.x = 1 prendono il
## colore della fazione, quelle con UV.y = 1 sventolano (vedi campaign_props.gdshader).

enum Settlement { VILLAGE, TOWN, CITY, CAPITAL }

const POLE: Color = Color("4a3a2a")
const GOLD: Color = Color("c9a45c")
const TEAM: Color = Color(1, 1, 1)
const PALM: Color = Color("4d6b2e")
const WOOD: Color = Color("6b4a2b")
const SAIL: Color = Color("e6dcc6")
const FIELD: Color = Color("a89a58")

## Colori per stile: muri, muri scuri, tetti, tetti scuri, pietra, terreno, accento.
const PALETTE: Dictionary = {
	"mediterraneo": {"wall": Color("e0d4b8"), "wall2": Color("c9b48e"), "roof": Color("a6533a"),
		"roof2": Color("8a4330"), "stone": Color("c2b9a6"), "ground": Color("8f7f5c"), "accent": Color("efe9dc")},
	"orientale": {"wall": Color("ebe2cc"), "wall2": Color("d2c19c"), "roof": Color("b8704c"),
		"roof2": Color("93573c"), "stone": Color("d4cab2"), "ground": Color("958463"), "accent": Color("8d99a0")},
	"settentrionale": {"wall": Color("8b6b49"), "wall2": Color("6e5236"), "roof": Color("8e7646"),
		"roof2": Color("74603a"), "stone": Color("9c958a"), "ground": Color("6c5d42"), "accent": Color("5c4630")},
	"desertico": {"wall": Color("cfae7e"), "wall2": Color("b8935f"), "roof": Color("dcc196"),
		"roof2": Color("a98353"), "stone": Color("dcc8a0"), "ground": Color("b39b70"), "accent": Color("3d7a8a")},
}

static var _cache: Dictionary = {}


static func settlement_tier(population: int, is_capital: bool) -> Settlement:
	if is_capital:
		return Settlement.CAPITAL
	if population >= 300:
		return Settlement.CITY
	if population >= 200:
		return Settlement.TOWN
	return Settlement.VILLAGE


static func settlement_mesh(tier: int, style: String = "mediterraneo") -> ArrayMesh:
	var key: String = "s%d_%s" % [tier, style]
	if not _cache.has(key):
		_cache[key] = _build_settlement(tier, _style(style))
	return _cache[key]


## Versione semplice (~150 triangoli) per le viste lontane: da lontano i dettagli sono più
## piccoli di un pixel e farebbero solo lavorare la scheda video.
static func settlement_lod_mesh(tier: int, style: String = "mediterraneo") -> ArrayMesh:
	var key: String = "l%d_%s" % [tier, style]
	if not _cache.has(key):
		_cache[key] = _build_settlement_lod(tier, _style(style))
	return _cache[key]


static func hamlet_mesh(style: String) -> ArrayMesh:
	var key: String = "h_%s" % style
	if not _cache.has(key):
		_cache[key] = _build_hamlet(_style(style))
	return _cache[key]


static func port_mesh() -> ArrayMesh:
	if not _cache.has("port"):
		_cache["port"] = _build_port()
	return _cache["port"]


static func army_mesh() -> ArrayMesh:
	if not _cache.has("army"):
		_cache["army"] = _build_army()
	return _cache["army"]


static func _style(style: String) -> String:
	return style if PALETTE.has(style) else "mediterraneo"


# ------------------------------------------------------------------ forme

## Tetto a due spioventi: prisma triangolare con il colmo lungo Z. `pos` = centro della base.
static func _gable(b: LowPolyBuilder, pos: Vector3, size: Vector3, rot: float, color: Color) -> void:
	var pr := PrismMesh.new()
	pr.size = size
	b.add(pr, LowPolyBuilder.at(pos + Vector3(0, size.y * 0.5, 0), Vector3(0, rot, 0)), color)


static func _cyl(top: float, bottom: float, height: float, sides: int, cap_bottom: bool = false) -> CylinderMesh:
	var c := LowPolyBuilder.cylinder(top, bottom, height, sides)
	c.cap_bottom = cap_bottom
	c.cap_top = top > 0.0
	return c


## Casa con tetto adatto allo stile. `pos` = centro della base.
static func _house(b: LowPolyBuilder, style: String, pos: Vector3, size: Vector3, rot: float, dark: bool) -> void:
	var p: Dictionary = PALETTE[style]
	var wall: Color = p["wall2"] if dark else p["wall"]
	var roof: Color = p["roof2"] if dark else p["roof"]
	b.add(LowPolyBuilder.box(size), LowPolyBuilder.at(pos + Vector3(0, size.y * 0.5, 0), Vector3(0, rot, 0)), wall)
	match style:
		"settentrionale":
			# tetto di paglia a due spioventi, ripido e sporgente
			_gable(b, pos + Vector3(0, size.y - 0.002, 0), Vector3(size.x * 1.25, size.y * 0.95, size.z * 1.1), rot, roof)
		"desertico":
			# tetto piatto con parapetto
			b.add(LowPolyBuilder.box(Vector3(size.x * 1.04, size.y * 0.12, size.z * 1.04)),
					LowPolyBuilder.at(pos + Vector3(0, size.y + size.y * 0.06, 0), Vector3(0, rot, 0)), roof)
		_:
			# tetto a padiglione in coppi
			var r: float = maxf(size.x, size.z) * 0.74
			b.add(_cyl(0.0, r, size.y * 0.42, 4), LowPolyBuilder.at(pos + Vector3(0, size.y + size.y * 0.21, 0), Vector3(0, rot + 45.0, 0))
					.scaled_local(Vector3(size.x / maxf(size.x, size.z), 1.0, size.z / maxf(size.x, size.z))), roof)


static func _flag(b: LowPolyBuilder, pos: Vector3, height: float, w: float) -> void:
	b.add(_cyl(0.011, 0.015, height, 4), LowPolyBuilder.at(pos + Vector3(0, height * 0.5, 0)), POLE)
	b.add(LowPolyBuilder.box(Vector3(w, w * 0.62, 0.012)), LowPolyBuilder.at(pos + Vector3(w * 0.5 + 0.01, height - w * 0.33, 0)), TEAM, true, true)


static func _palm(b: LowPolyBuilder, pos: Vector3, h: float) -> void:
	b.add(_cyl(0.008, 0.013, h, 4), LowPolyBuilder.at(pos + Vector3(0, h * 0.5, 0), Vector3(0, 0, 6)), WOOD)
	for i: int in 5:
		var a: float = 72.0 * i
		b.add(LowPolyBuilder.box(Vector3(h * 0.55, 0.006, 0.03)),
				LowPolyBuilder.at(pos + Vector3(0, h, 0), Vector3(0, a, -22)).translated_local(Vector3(h * 0.22, 0, 0)), PALM)


static func _tree(b: LowPolyBuilder, pos: Vector3, h: float, color: Color) -> void:
	b.add(_cyl(0.006, 0.009, h * 0.4, 3), LowPolyBuilder.at(pos + Vector3(0, h * 0.2, 0)), WOOD)
	b.add(LowPolyBuilder.sphere(h * 0.32, 5, 2), LowPolyBuilder.at(pos + Vector3(0, h * 0.62, 0)), color)


## Case su una griglia di isolati (cardo e decumano liberi) oppure sparse (stile del nord).
static func _houses(b: LowPolyBuilder, style: String, radius: float, step: float, size: float, seed_value: int, keep_out: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if style == "settentrionale":
		# anelli di case lunghe con il colmo rivolto verso il centro, come attorno a una piazza
		var ring_r: float = radius * 0.42
		while ring_r <= radius * 0.98:
			var n: int = maxi(5, int(TAU * ring_r / (size * 1.25)))
			var a0: float = rng.randf() * TAU
			for i: int in n:
				var a: float = a0 + TAU * i / n
				var p := Vector3(cos(a) * ring_r, 0, sin(a) * ring_r)
				if _blocked(p, keep_out) or rng.randf() < 0.15:
					continue
				var s: float = size * rng.randf_range(0.9, 1.15)
				_house(b, style, p, Vector3(s * 0.75, s * 0.5, s * rng.randf_range(1.3, 1.6)), -rad_to_deg(a) + 90.0 + rng.randf_range(-8, 8), rng.randf() < 0.35)
			ring_r += size * 1.7
		return
	var cells: int = int(radius / step)
	for gx: int in range(-cells, cells + 1):
		for gz: int in range(-cells, cells + 1):
			if gx == 0 or gz == 0:
				continue  # vie principali
			var p := Vector3(gx * step, 0, gz * step) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)) * step
			if p.length() > radius or _blocked(p, keep_out) or rng.randf() < 0.12:
				continue
			var s: float = size * rng.randf_range(0.8, 1.15)
			var h: float = s * rng.randf_range(0.55, 0.9)
			if style == "desertico":
				h *= 0.85
			_house(b, style, p, Vector3(s, h, s * rng.randf_range(0.8, 1.3)), rng.randf_range(-6, 6), rng.randf() < 0.3)


static func _blocked(p: Vector3, keep_out: Array) -> bool:
	for k: Variant in keep_out:
		var c: Vector3 = k
		if Vector2(p.x - c.x, p.z - c.z).length() < c.y:
			return true
	return false


## Mura ad anello con torri e una porta verso +Z. Stile del nord: palizzata di legno.
static func _walls(b: LowPolyBuilder, style: String, radius: float, height: float, towers: int) -> void:
	var p: Dictionary = PALETTE[style]
	var north: bool = style == "settentrionale"
	var wall_c: Color = p["wall2"] if north else p["stone"]
	var tower_c: Color = p["wall2"] if north else p["wall2"].lerp(p["stone"], 0.4)
	var segs: int = towers * 2
	for i: int in segs:
		var a0: float = TAU * i / segs + PI * 0.5 + PI / segs
		var a1: float = TAU * (i + 1) / segs + PI * 0.5 + PI / segs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		if i == segs - 1:
			# porta: il tratto che guarda verso +Z resta aperto
			var mid0: Vector3 = (p0 + p1) * 0.5
			p1 = p0.lerp(mid0, 0.62)
		var mid: Vector3 = (p0 + p1) * 0.5
		var ang: float = rad_to_deg(atan2(p1.x - p0.x, p1.z - p0.z))
		b.add(LowPolyBuilder.box(Vector3(0.028, height, p0.distance_to(p1) + 0.02)), LowPolyBuilder.at(mid + Vector3(0, height * 0.5, 0), Vector3(0, ang, 0)), wall_c)
		if not north:
			# camminamento merlato (una fascia più chiara)
			b.add(LowPolyBuilder.box(Vector3(0.036, 0.012, p0.distance_to(p1) + 0.02)), LowPolyBuilder.at(mid + Vector3(0, height + 0.004, 0), Vector3(0, ang, 0)), p["stone"].lightened(0.15))
	for i: int in towers:
		var a: float = TAU * i / towers + PI * 0.5 + PI / segs * 2.0
		var tp := Vector3(cos(a), 0, sin(a)) * radius
		if north:
			b.add(LowPolyBuilder.box(Vector3(0.06, height * 1.7, 0.06)), LowPolyBuilder.at(tp + Vector3(0, height * 0.85, 0)), tower_c)
			b.add(_cyl(0.0, 0.055, 0.05, 4), LowPolyBuilder.at(tp + Vector3(0, height * 1.7 + 0.025, 0), Vector3(0, 45, 0)), p["roof2"])
		else:
			b.add(LowPolyBuilder.box(Vector3(0.065, height * 1.55, 0.065)), LowPolyBuilder.at(tp + Vector3(0, height * 0.775, 0), Vector3(0, -rad_to_deg(a), 0)), tower_c)
			b.add(LowPolyBuilder.box(Vector3(0.075, 0.014, 0.075)), LowPolyBuilder.at(tp + Vector3(0, height * 1.55 + 0.007, 0), Vector3(0, -rad_to_deg(a), 0)), p["stone"].lightened(0.1))
	# torri della porta
	var gate_a: float = PI * 0.5
	for side: float in [-1.0, 1.0]:
		var gp := Vector3(cos(gate_a + side * 0.17), 0, sin(gate_a + side * 0.17)) * radius
		b.add(LowPolyBuilder.box(Vector3(0.075, height * 1.9, 0.075)), LowPolyBuilder.at(gp + Vector3(0, height * 0.95, 0)), tower_c)
		if north:
			b.add(_cyl(0.0, 0.06, 0.06, 4), LowPolyBuilder.at(gp + Vector3(0, height * 1.9 + 0.03, 0), Vector3(0, 45, 0)), p["roof2"])


# ------------------------------------------------------------------ monumenti

## Tempio con podio, colonne e frontone (mediterraneo).
static func _temple(b: LowPolyBuilder, p: Dictionary, pos: Vector3, s: float, rot: float) -> void:
	var t := LowPolyBuilder.at(pos, Vector3(0, rot, 0))
	b.add(LowPolyBuilder.box(Vector3(0.16, 0.025, 0.24) * s), t.translated_local(Vector3(0, 0.0125 * s, 0)), p["stone"])
	b.add(LowPolyBuilder.box(Vector3(0.1, 0.07, 0.15) * s), t.translated_local(Vector3(0, 0.06 * s, -0.02 * s)), p["accent"])
	for x: float in [-0.065, -0.022, 0.022, 0.065]:
		for z: float in [0.1, 0.06]:
			b.add(_cyl(0.008 * s, 0.008 * s, 0.075 * s, 4), t.translated_local(Vector3(x * s, 0.0625 * s, z * s)), p["accent"])
	_gable(b, pos + Vector3(0, 0.1 * s, 0), Vector3(0.13, 0.045, 0.25) * s, rot, p["roof"])


## Anfiteatro ellittico (mediterraneo, capitale).
static func _amphitheatre(b: LowPolyBuilder, p: Dictionary, pos: Vector3) -> void:
	var n: int = 14
	for i: int in n:
		var a0: float = TAU * i / n
		var a1: float = TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 0.12, 0, sin(a0) * 0.09)
		var p1 := Vector3(cos(a1) * 0.12, 0, sin(a1) * 0.09)
		var ang: float = rad_to_deg(atan2(p1.x - p0.x, p1.z - p0.z))
		b.add(LowPolyBuilder.box(Vector3(0.03, 0.07, p0.distance_to(p1) + 0.012)), LowPolyBuilder.at(pos + (p0 + p1) * 0.5 + Vector3(0, 0.035, 0), Vector3(0, ang, 0)), p["accent"])
	b.add(_cyl(0.075, 0.075, 0.01, 10), LowPolyBuilder.at(pos + Vector3(0, 0.005, 0)).scaled_local(Vector3(1.0, 1.0, 0.72)), Color("c7b48a"))


## Chiesa a cupola (orientale): corpo, tamburo e cupola.
static func _domed_church(b: LowPolyBuilder, p: Dictionary, pos: Vector3, s: float, gold: bool) -> void:
	b.add(LowPolyBuilder.box(Vector3(0.2, 0.1, 0.2) * s), LowPolyBuilder.at(pos + Vector3(0, 0.05 * s, 0)), p["wall"])
	for d: Vector3 in [Vector3(0.13, 0, 0), Vector3(-0.13, 0, 0), Vector3(0, 0, 0.13), Vector3(0, 0, -0.13)]:
		b.add(LowPolyBuilder.box(Vector3(0.08, 0.075, 0.08) * s), LowPolyBuilder.at(pos + d * s + Vector3(0, 0.0375 * s, 0)), p["wall2"])
		b.add(LowPolyBuilder.sphere(0.04 * s, 6, 3), LowPolyBuilder.at(pos + d * s + Vector3(0, 0.075 * s, 0)), p["accent"])
	b.add(_cyl(0.075 * s, 0.08 * s, 0.05 * s, 8), LowPolyBuilder.at(pos + Vector3(0, 0.125 * s, 0)), p["wall2"])
	b.add(LowPolyBuilder.sphere(0.08 * s, 8, 4), LowPolyBuilder.at(pos + Vector3(0, 0.15 * s, 0)), GOLD if gold else p["accent"])


## Chiesa in pietra con campanile (nord).
static func _stone_church(b: LowPolyBuilder, p: Dictionary, pos: Vector3, s: float) -> void:
	b.add(LowPolyBuilder.box(Vector3(0.09, 0.08, 0.2) * s), LowPolyBuilder.at(pos + Vector3(0, 0.04 * s, 0)), p["stone"])
	_gable(b, pos + Vector3(0, 0.08 * s, 0), Vector3(0.105, 0.06, 0.215) * s, 0.0, Color("5d5a55"))
	b.add(LowPolyBuilder.box(Vector3(0.05, 0.17, 0.05) * s), LowPolyBuilder.at(pos + Vector3(0, 0.085 * s, 0.11 * s)), p["stone"])
	b.add(_cyl(0.0, 0.042 * s, 0.07 * s, 4), LowPolyBuilder.at(pos + Vector3(0, 0.205 * s, 0.11 * s), Vector3(0, 45, 0)), Color("5d5a55"))


## Sala lunga in legno (nord).
static func _long_hall(b: LowPolyBuilder, p: Dictionary, pos: Vector3, s: float, rot: float) -> void:
	_house(b, "settentrionale", pos, Vector3(0.08, 0.05, 0.22) * s, rot, true)
	b.add(LowPolyBuilder.box(Vector3(0.02, 0.02, 0.02) * s), LowPolyBuilder.at(pos + Vector3(0, 0.11 * s, 0)), p["accent"])


## Palazzo a gradoni (deserto).
static func _stepped_palace(b: LowPolyBuilder, p: Dictionary, pos: Vector3, s: float) -> void:
	var y: float = 0.0
	var w: float = 0.24
	for i: int in 3:
		var h: float = 0.05
		b.add(LowPolyBuilder.box(Vector3(w, h, w * 0.8) * s), LowPolyBuilder.at(pos + Vector3(0, (y + h * 0.5) * s, 0)), p["wall"] if i % 2 == 0 else p["wall2"])
		y += h
		w *= 0.7
	# iwan: grande arco sulla facciata
	b.add(LowPolyBuilder.box(Vector3(0.06, 0.07, 0.01) * s), LowPolyBuilder.at(pos + Vector3(0, 0.035 * s, 0.097 * s)), Color("4a3b2a"))
	b.add(LowPolyBuilder.box(Vector3(0.05, 0.02, 0.05) * s), LowPolyBuilder.at(pos + Vector3(0, (y + 0.01) * s, 0)), p["accent"])


# ------------------------------------------------------------------ insediamenti

static func _build_settlement(tier: int, style: String) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var p: Dictionary = PALETTE[style]
	var cap: bool = tier == Settlement.CAPITAL
	var r: float
	match tier:
		Settlement.VILLAGE: r = 0.24
		Settlement.TOWN: r = 0.33
		Settlement.CITY: r = 0.43
		_: r = 0.52
	var walled: bool = tier >= Settlement.CITY or (tier == Settlement.TOWN and style == "settentrionale")
	# terreno battuto e lastricato
	b.add(_cyl(r + 0.05, r + 0.09, 0.02, 14, false), LowPolyBuilder.at(Vector3(0, 0.01, 0)), p["ground"])
	if style != "settentrionale" and tier >= Settlement.TOWN:
		# vie principali lastricate
		b.add(LowPolyBuilder.box(Vector3(0.035, 0.004, r * 2.0)), LowPolyBuilder.at(Vector3(0, 0.021, 0)), p["stone"])
		b.add(LowPolyBuilder.box(Vector3(r * 2.0, 0.004, 0.035)), LowPolyBuilder.at(Vector3(0, 0.021, 0)), p["stone"])
	var keep: Array = []
	var seed_value: int = 100 + tier * 13 + STYLE_SEEDS.get(style, 0)
	match style:
		"mediterraneo":
			if tier >= Settlement.TOWN:
				# foro lastricato con il tempio
				b.add(LowPolyBuilder.box(Vector3(0.16, 0.006, 0.12)), LowPolyBuilder.at(Vector3(-0.1, 0.022, -0.09)), p["accent"])
				_temple(b, p, Vector3(-0.1, 0.02, -0.11), 1.0 if tier < Settlement.CITY else 1.25, 0.0)
				keep.append(Vector3(-0.1, 0.13, -0.1))
			if tier >= Settlement.CITY:
				# basilica
				b.add(LowPolyBuilder.box(Vector3(0.2, 0.08, 0.09)), LowPolyBuilder.at(Vector3(0.12, 0.06, -0.1)), p["wall"])
				_gable(b, Vector3(0.12, 0.1, -0.1), Vector3(0.105, 0.04, 0.215), 90.0, p["roof"])
				keep.append(Vector3(0.12, 0.13, -0.1))
			if cap:
				_amphitheatre(b, p, Vector3(0.2, 0.02, 0.2))
				keep.append(Vector3(0.2, 0.15, 0.2))
		"orientale":
			if tier >= Settlement.TOWN:
				_domed_church(b, p, Vector3(-0.08, 0.02, -0.1), 0.8 if tier < Settlement.CITY else 1.0, false)
				keep.append(Vector3(-0.08, 0.14, -0.1))
			if cap:
				_domed_church(b, p, Vector3(0.14, 0.02, -0.06), 1.45, true)
				keep.append(Vector3(0.14, 0.2, -0.06))
				# ippodromo
				b.add(LowPolyBuilder.box(Vector3(0.09, 0.02, 0.3)), LowPolyBuilder.at(Vector3(0.24, 0.03, 0.16), Vector3(0, 20, 0)), p["wall2"])
				b.add(LowPolyBuilder.box(Vector3(0.05, 0.022, 0.24)), LowPolyBuilder.at(Vector3(0.24, 0.032, 0.16), Vector3(0, 20, 0)), Color("c7b48a"))
				keep.append(Vector3(0.24, 0.18, 0.16))
		"settentrionale":
			_long_hall(b, p, Vector3(0.0, 0.02, -0.02), 1.0 if tier < Settlement.CITY else 1.3, 15.0)
			keep.append(Vector3(0.0, 0.12, -0.02))
			if tier >= Settlement.CITY:
				_stone_church(b, p, Vector3(-0.17, 0.02, 0.08), 1.0 if not cap else 1.3)
				keep.append(Vector3(-0.17, 0.12, 0.1))
			if cap:
				# torrione in pietra
				b.add(LowPolyBuilder.box(Vector3(0.11, 0.2, 0.11)), LowPolyBuilder.at(Vector3(0.18, 0.12, -0.15)), p["stone"])
				b.add(LowPolyBuilder.box(Vector3(0.125, 0.02, 0.125)), LowPolyBuilder.at(Vector3(0.18, 0.23, -0.15)), p["stone"].lightened(0.1))
				keep.append(Vector3(0.18, 0.11, -0.15))
		"desertico":
			if tier >= Settlement.TOWN:
				_stepped_palace(b, p, Vector3(0.0, 0.02, -0.08), 0.8 if tier < Settlement.CITY else (1.0 if not cap else 1.35))
				keep.append(Vector3(0.0, 0.17 if cap else 0.13, -0.08))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5 + tier
			for i: int in 3 + tier * 2:
				var a: float = rng.randf() * TAU
				_palm(b, Vector3(cos(a), 0, sin(a)) * (r + 0.02 + rng.randf() * 0.05) + Vector3(0, 0.02, 0), rng.randf_range(0.08, 0.12))
	var house: float = 0.068 if style != "desertico" else 0.064
	_houses(b, style, r * (0.88 if walled else 0.95), 0.085 if style != "settentrionale" else 0.0, house, seed_value, keep)
	if walled:
		_walls(b, style, r + 0.02, 0.055 if not cap else 0.07, 6 if tier == Settlement.TOWN else (7 if tier == Settlement.CITY else 9))
	elif style == "settentrionale":
		pass
	# stendardi
	if cap:
		_flag(b, Vector3(-0.24, 0.02, -0.22), 0.56, 0.2)
		_flag(b, Vector3(0.3, 0.02, 0.0), 0.46, 0.16)
	elif tier >= Settlement.TOWN:
		_flag(b, Vector3(0.05, 0.02, 0.05), 0.42, 0.16)
	else:
		_flag(b, Vector3(0.0, 0.02, 0.0), 0.32, 0.12)
	return b.build()


static func _build_settlement_lod(tier: int, style: String) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var p: Dictionary = PALETTE[style]
	var r: float = [0.24, 0.33, 0.43, 0.52][clampi(tier, 0, 3)]
	b.add(_cyl(r + 0.05, r + 0.09, 0.02, 8, false), LowPolyBuilder.at(Vector3(0, 0.01, 0)), p["ground"])
	# isolati: blocchi bassi con il colore dei tetti
	var blocks: int = 4 + tier * 2
	for i: int in blocks:
		var a: float = TAU * i / blocks + 0.3
		var rr: float = r * (0.35 if i % 2 == 0 else 0.62)
		var sz: float = r * 0.42
		b.add(LowPolyBuilder.box(Vector3(sz, 0.06, sz * 0.8)), LowPolyBuilder.at(Vector3(cos(a) * rr, 0.05, sin(a) * rr), Vector3(0, rad_to_deg(a), 0)),
				p["roof"] if i % 3 != 0 else p["wall"])
	# edificio principale
	match style:
		"orientale":
			b.add(LowPolyBuilder.sphere(0.08 + tier * 0.02, 6, 3), LowPolyBuilder.at(Vector3(0, 0.08, 0)), GOLD if tier == Settlement.CAPITAL else p["accent"])
		"desertico":
			b.add(LowPolyBuilder.box(Vector3(0.16, 0.1 + tier * 0.02, 0.13)), LowPolyBuilder.at(Vector3(0, 0.07, 0)), p["wall"])
		_:
			b.add(LowPolyBuilder.box(Vector3(0.1, 0.09, 0.16)), LowPolyBuilder.at(Vector3(0, 0.065, 0)), p["accent"] if style == "mediterraneo" else p["stone"])
	if tier >= Settlement.CITY or (tier == Settlement.TOWN and style == "settentrionale"):
		# mura: un anello aperto (tubo senza basi)
		var ring := _cyl(r + 0.02, r + 0.02, 0.06, 10, false)
		ring.cap_top = false
		b.add(ring, LowPolyBuilder.at(Vector3(0, 0.05, 0)), p["wall2"] if style == "settentrionale" else p["stone"])
	if tier == Settlement.CAPITAL:
		_flag(b, Vector3(-0.24, 0.02, -0.22), 0.56, 0.2)
		_flag(b, Vector3(0.3, 0.02, 0.0), 0.46, 0.16)
	elif tier >= Settlement.TOWN:
		_flag(b, Vector3(0.05, 0.02, 0.05), 0.42, 0.16)
	else:
		_flag(b, Vector3(0.0, 0.02, 0.0), 0.32, 0.12)
	return b.build()


const STYLE_SEEDS: Dictionary = {"mediterraneo": 0, "orientale": 7, "settentrionale": 19, "desertico": 31}


## Villaggio minore: poche case, un orto recintato o qualche palma. Niente stendardo:
## il padrone si legge dal colore della provincia.
static func _build_hamlet(style: String) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	var p: Dictionary = PALETTE[style]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + STYLE_SEEDS.get(style, 0)
	b.add(_cyl(0.13, 0.16, 0.012, 8, false), LowPolyBuilder.at(Vector3(0, 0.006, 0)), p["ground"])
	for i: int in 5:
		var a: float = TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		var rr: float = rng.randf_range(0.04, 0.11)
		var s: float = rng.randf_range(0.05, 0.065)
		var size := Vector3(s, s * 0.7, s * 1.3) if style == "settentrionale" else Vector3(s, s * 0.75, s * 1.1)
		_house(b, style, Vector3(cos(a) * rr, 0.01, sin(a) * rr), size, rad_to_deg(a), rng.randf() < 0.4)
	if style == "desertico":
		_palm(b, Vector3(0.13, 0.0, 0.05), 0.1)
		_palm(b, Vector3(-0.1, 0.0, -0.11), 0.09)
	else:
		# orto e recinto
		b.add(LowPolyBuilder.box(Vector3(0.12, 0.006, 0.09)), LowPolyBuilder.at(Vector3(0.15, 0.004, 0.08), Vector3(0, 15, 0)), FIELD)
		_tree(b, Vector3(-0.14, 0.0, 0.04), 0.13, Color("3f5f2f") if style != "orientale" else Color("56663a"))
	return b.build()


## Porto: molo in legno verso +X (il mare) con una nave ormeggiata.
static func _build_port() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.add(LowPolyBuilder.box(Vector3(0.36, 0.02, 0.05)), LowPolyBuilder.at(Vector3(0.16, 0.012, 0)), WOOD)
	b.add(LowPolyBuilder.box(Vector3(0.05, 0.02, 0.2)), LowPolyBuilder.at(Vector3(0.32, 0.012, 0)), WOOD)
	for x: float in [0.04, 0.14, 0.24]:
		b.add(_cyl(0.008, 0.008, 0.05, 4), LowPolyBuilder.at(Vector3(x, -0.01, 0.03)), WOOD.darkened(0.3))
	# nave: scafo, ponte, albero e vela
	var ship := Vector3(0.28, 0.0, 0.16)
	var hull := PrismMesh.new()
	hull.size = Vector3(0.09, 0.05, 0.32)
	b.add(hull, LowPolyBuilder.at(ship + Vector3(0, 0.012, 0), Vector3(180, 90, 0)), Color("5a3f28"))
	b.add(LowPolyBuilder.box(Vector3(0.26, 0.008, 0.06)), LowPolyBuilder.at(ship + Vector3(0, 0.038, 0)), Color("8a6a46"))
	b.add(_cyl(0.006, 0.008, 0.26, 4), LowPolyBuilder.at(ship + Vector3(0.0, 0.17, 0)), POLE)
	b.add(LowPolyBuilder.box(Vector3(0.008, 0.13, 0.17)), LowPolyBuilder.at(ship + Vector3(0.008, 0.19, 0)), SAIL, false, true)
	return b.build()


## Albero della mappa (alto 1, base all'origine): tronco e chioma a doppio cono, con i vertici
## condivisi (14 in tutto: in un bosco fitto conta il lavoro per vertice della scheda video).
## campaign_trees.gdshader lo trasforma in latifoglia, conifera o pino domestico.
## UV.y = 1 sulla chioma, UV.x = altezza relativa nella chioma (0 in basso, 1 in alto).
static func tree_mesh() -> ArrayMesh:
	if _cache.has("tree"):
		return _cache["tree"]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var trunk := Color("5b4330")
	var crown := Color("4a6a34")
	# tronco: prisma a 3 lati senza basi (vertici 0-2 in basso, 3-5 in alto)
	for y: float in [0.0, 0.4]:
		for i: int in 3:
			var a: float = TAU * i / 3.0
			verts.append(Vector3(cos(a) * 0.05, y, sin(a) * 0.05))
			normals.append(Vector3(cos(a), 0, sin(a)))
			colors.append(trunk)
			uvs.append(Vector2(0, 0))
	for i: int in 3:
		var j: int = (i + 1) % 3
		idx.append_array([i, 3 + j, j, i, 3 + i, 3 + j])
	# chioma: anello di 6 vertici, punta in alto e in basso
	var sides: int = 6
	var y_low: float = 0.28
	var y_mid: float = 0.55
	var y_top: float = 1.0
	var ring0: int = verts.size()
	for i: int in sides:
		var a: float = TAU * i / sides
		verts.append(Vector3(cos(a) * 0.3, y_mid, sin(a) * 0.3))
		normals.append(Vector3(cos(a), 0.15, sin(a)).normalized())
		colors.append(crown)
		uvs.append(Vector2((y_mid - y_low) / (y_top - y_low), 1.0))
	var top: int = verts.size()
	verts.append(Vector3(0, y_top, 0))
	normals.append(Vector3.UP)
	colors.append(crown.lightened(0.15))
	uvs.append(Vector2(1.0, 1.0))
	var bottom: int = verts.size()
	verts.append(Vector3(0, y_low, 0))
	normals.append(Vector3.DOWN)
	colors.append(crown.darkened(0.2))
	uvs.append(Vector2(0.0, 1.0))
	for i: int in sides:
		var a0: int = ring0 + i
		var a1: int = ring0 + (i + 1) % sides
		idx.append_array([a0, top, a1, a0, a1, bottom])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["tree"] = mesh
	return mesh


static func _build_army() -> ArrayMesh:
	var b := LowPolyBuilder.new()
	# base, tre soldati in miniatura, stendardo alto con il colore della fazione
	b.add(LowPolyBuilder.cylinder(0.2, 0.22, 0.03, 8), LowPolyBuilder.at(Vector3(0, 0.015, 0)), Color("3b3127"))
	var soldier: ArrayMesh = LowPolyBuilder.soldier_mesh()
	var s: float = 0.12
	for p: Vector3 in [Vector3(-0.1, 0.03, 0.05), Vector3(0.1, 0.03, 0.06), Vector3(0.0, 0.03, -0.08)]:
		b.add_built(soldier, Transform3D(Basis.from_scale(Vector3(s, s, s)).rotated(Vector3.UP, PI), p))
	b.add(LowPolyBuilder.cylinder(0.014, 0.018, 0.9, 4), LowPolyBuilder.at(Vector3(0.0, 0.48, 0.0)), POLE)
	b.add(LowPolyBuilder.box(Vector3(0.05, 0.02, 0.36)), LowPolyBuilder.at(Vector3(0.0, 0.9, 0.0), Vector3(0, 90, 0)), POLE)
	b.add(LowPolyBuilder.box(Vector3(0.34, 0.42, 0.014)), LowPolyBuilder.at(Vector3(0.0, 0.68, 0.0)), TEAM, true, true)
	b.add(LowPolyBuilder.cylinder(0.0, 0.035, 0.07, 4), LowPolyBuilder.at(Vector3(0.0, 0.96, 0.0)), GOLD)
	return b.build()
