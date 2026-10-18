class_name Scenes
extends RefCounted
## Percorsi delle schermate e cambio di scena.

const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const NEW_GAME: String = "res://scenes/menu/new_game_menu.tscn"
const LOAD_GAME: String = "res://scenes/menu/load_menu.tscn"
const OPTIONS: String = "res://scenes/menu/options_menu.tscn"
const CAMPAIGN: String = "res://scenes/campaign/campaign_map.tscn"
const BENCHMARK: String = "res://scenes/benchmark/benchmark.tscn"


static func goto(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file.call_deferred(path)
