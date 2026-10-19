extends Node
func _ready() -> void:
	Settings.graphics.apply_preset("alto")
	Settings.graphics.window_mode = "finestra"
	Settings.apply()
	Session.autosave_enabled = false
	Session.start_map_benchmark()
	get_tree().change_scene_to_file.call_deferred(Scenes.CAMPAIGN)
