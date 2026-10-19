class_name CampaignModels
extends RefCounted
## Modelli low-poly della mappa di campagna, costruiti da forme semplici (nessun file esterno).
## Unità: 1 = 10 km. Città ed eserciti sono "fuori scala" come nelle mappe strategiche.

enum Settlement { VILLAGE, TOWN, CITY, CAPITAL }

const WALL: Color = Color("d8ccb0")
const WALL_DARK: Color = Color("a89a7c")
const ROOF: Color = Color("a6533a")
const ROOF_DARK: Color = Color("7d3f2e")
const STONE: Color = Color("bdb5a4")
const DOME: Color = Color("c9a45c")
const POLE: Color = Color("4a3a2a")
const GROUND: Color = Color("6e6248")
const TEAM: Color = Color(1, 1, 1)

static var _cache: Dictionary = {}


static func settlement_tier(population: int, is_capital: bool) -> Settlement:
	if is_capital:
		return Settlement.CAPITAL
	if population >= 300:
		return Settlement.CITY
	if population >= 200:
		return Settlement.TOWN
	return Settlement.VILLAGE


static func settlement_mesh(tier: int) -> ArrayMesh:
	var key: String = "s%d" % tier
	if not _cache.has(key):
		_cache[key] = _build_settlement(tier)
	return _cache[key]


static func army_mesh() -> ArrayMesh:
	if not _cache.has("army"):
		_cache["army"] = _build_army()
	return _cache["army"]


static func _house(b: LowPolyBuilder, pos: Vector3, size: Vector3, rot: float, roof: Color) -> void:
	b.add(LowPolyBuilder.box(size), LowPolyBuilder.at(pos + Vector3(0, size.y * 0.5, 0), Vector3(0, rot, 0)), WALL)
	var r: float = maxf(size.x, size.z) * 0.72
	b.add(LowPolyBuilder.cylinder(0.0, r, size.y * 0.7, 4), LowPolyBuilder.at(pos + Vector3(0, size.y + size.y * 0.35, 0), Vector3(0, rot + 45.0, 0)), roof)


static func _flag(b: LowPolyBuilder, pos: Vector3, height: float, w: float) -> void:
	b.add(LowPolyBuilder.cylinder(0.012, 0.016, height, 4), LowPolyBuilder.at(pos + Vector3(0, height * 0.5, 0)), POLE)
	b.add(LowPolyBuilder.box(Vector3(w, w * 0.62, 0.012)), LowPolyBuilder.at(pos + Vector3(w * 0.5 + 0.01, height - w * 0.33, 0)), TEAM, true, true)


static func _ring_houses(b: LowPolyBuilder, count: int, radius: float, size: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in count:
		var a: float = TAU * i / count + rng.randf_range(-0.2, 0.2)
		var r: float = radius * rng.randf_range(0.55, 1.0)
		var s: float = size * rng.randf_range(0.8, 1.25)
		var roof: Color = ROOF if rng.randf() < 0.7 else ROOF_DARK
		_house(b, Vector3(cos(a) * r, 0, sin(a) * r), Vector3(s, s * 0.8, s * rng.randf_range(0.9, 1.4)), rng.randf_range(0, 90), roof)


static func _walls(b: LowPolyBuilder, radius: float, height: float, towers: int) -> void:
	var segs: int = towers * 2
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var mid: Vector3 = (p0 + p1) * 0.5
		var length: float = p0.distance_to(p1)
		var ang: float = rad_to_deg(atan2(p1.x - p0.x, p1.z - p0.z))
		b.add(LowPolyBuilder.box(Vector3(0.03, height, length)), LowPolyBuilder.at(mid + Vector3(0, height * 0.5, 0), Vector3(0, ang, 0)), STONE)
	for i: int in towers:
		var a: float = TAU * i / towers
		var p := Vector3(cos(a), 0, sin(a)) * radius
		b.add(LowPolyBuilder.cylinder(0.045, 0.05, height * 1.5, 6), LowPolyBuilder.at(p + Vector3(0, height * 0.75, 0)), WALL_DARK)
		b.add(LowPolyBuilder.cylinder(0.0, 0.06, 0.06, 6), LowPolyBuilder.at(p + Vector3(0, height * 1.5 + 0.03, 0)), ROOF_DARK)


static func _build_settlement(tier: int) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	match tier:
		Settlement.VILLAGE:
			b.add(LowPolyBuilder.cylinder(0.24, 0.27, 0.02, 8), LowPolyBuilder.at(Vector3(0, 0.01, 0)), GROUND)
			_ring_houses(b, 5, 0.17, 0.075, 11)
			_flag(b, Vector3(0, 0, 0), 0.32, 0.12)
		Settlement.TOWN:
			b.add(LowPolyBuilder.cylinder(0.34, 0.38, 0.02, 10), LowPolyBuilder.at(Vector3(0, 0.01, 0)), GROUND)
			_ring_houses(b, 9, 0.27, 0.085, 23)
			_house(b, Vector3(0.0, 0, -0.02), Vector3(0.16, 0.11, 0.1), 0.0, ROOF_DARK)
			b.add(LowPolyBuilder.cylinder(0.035, 0.04, 0.26, 6), LowPolyBuilder.at(Vector3(0.12, 0.13, 0.1)), WALL_DARK)
			_flag(b, Vector3(0.12, 0.26, 0.1), 0.2, 0.13)
		Settlement.CITY, Settlement.CAPITAL:
			var cap: bool = tier == Settlement.CAPITAL
			var r: float = 0.5 if cap else 0.42
			b.add(LowPolyBuilder.cylinder(r + 0.06, r + 0.1, 0.02, 12), LowPolyBuilder.at(Vector3(0, 0.01, 0)), GROUND)
			_ring_houses(b, 16 if cap else 13, r * 0.85, 0.085, 37 if cap else 41)
			_walls(b, r, 0.07 if cap else 0.06, 8 if cap else 6)
			# basilica
			b.add(LowPolyBuilder.box(Vector3(0.24, 0.12, 0.12)), LowPolyBuilder.at(Vector3(-0.05, 0.06, 0.06)), WALL)
			b.add(LowPolyBuilder.cylinder(0.0, 0.11, 0.07, 3), LowPolyBuilder.at(Vector3(-0.05, 0.155, 0.06), Vector3(90, 0, 90)).scaled_local(Vector3(1, 2.2, 1)), ROOF)
			if cap:
				# palazzo con cupola dorata e due stendardi
				b.add(LowPolyBuilder.box(Vector3(0.22, 0.16, 0.22)), LowPolyBuilder.at(Vector3(0.08, 0.08, -0.12)), WALL)
				b.add(LowPolyBuilder.cylinder(0.09, 0.1, 0.06, 8), LowPolyBuilder.at(Vector3(0.08, 0.19, -0.12)), WALL_DARK)
				b.add(LowPolyBuilder.sphere(0.1, 8, 4), LowPolyBuilder.at(Vector3(0.08, 0.23, -0.12)), DOME)
				_flag(b, Vector3(-0.22, 0, -0.18), 0.55, 0.2)
				_flag(b, Vector3(0.3, 0, 0.12), 0.45, 0.16)
			else:
				_flag(b, Vector3(0.06, 0, -0.1), 0.45, 0.17)
	return b.build()


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
	b.add(LowPolyBuilder.cylinder(0.0, 0.035, 0.07, 4), LowPolyBuilder.at(Vector3(0.0, 0.96, 0.0)), DOME)
	return b.build()
