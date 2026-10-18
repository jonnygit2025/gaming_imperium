class_name ProvinceDef
extends RefCounted

var id: String = ""
var name: String = ""
var region: String = ""
var city: String = ""
var lat: float = 0.0
var lon: float = 0.0
var terrain: String = ""
var coastal: bool = false
var island: bool = false
var resources: PackedStringArray = []
## Popolazione iniziale in migliaia.
var population: int = 0
var fertility: int = 1
var wealth: int = 1
var neighbors: PackedStringArray = []


static func from_dict(d: Dictionary) -> ProvinceDef:
	var p := ProvinceDef.new()
	p.id = DataUtil.to_str(d, "id")
	p.name = DataUtil.to_str(d, "name")
	p.region = DataUtil.to_str(d, "region")
	p.city = DataUtil.to_str(d, "city")
	p.lat = DataUtil.to_float(d, "lat")
	p.lon = DataUtil.to_float(d, "lon")
	p.terrain = DataUtil.to_str(d, "terrain")
	p.coastal = DataUtil.to_bool(d, "coastal")
	p.island = DataUtil.to_bool(d, "island")
	p.resources = DataUtil.to_strings(d, "resources")
	p.population = DataUtil.to_int(d, "population")
	p.fertility = DataUtil.to_int(d, "fertility", 1)
	p.wealth = DataUtil.to_int(d, "wealth", 1)
	p.neighbors = DataUtil.to_strings(d, "neighbors")
	return p


func has_resource(res: String) -> bool:
	return res in resources
