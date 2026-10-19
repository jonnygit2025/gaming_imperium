class_name CampaignControls
extends RefCounted
## Tasti della mappa di campagna. Le azioni sono create in codice (se mancano), così restano
## tutte in un solo posto e il file del progetto non si riempie di eventi.

const BINDINGS: Dictionary = {
	"cam_forward": [KEY_W, KEY_UP],
	"cam_back": [KEY_S, KEY_DOWN],
	"cam_left": [KEY_A, KEY_LEFT],
	"cam_right": [KEY_D, KEY_RIGHT],
	"cam_rotate_left": [KEY_Q],
	"cam_rotate_right": [KEY_E],
	"end_turn": [KEY_ENTER, KEY_KP_ENTER],
}


static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
