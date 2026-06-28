extends Node

var login_session_time: int = 86400   # default/fallback


func _ready() -> void:
	load_config()
	GDSync.start_multiplayer()
	
func load_config() -> void:
	var file := FileAccess.open("res://config/game_config.json", FileAccess.READ)
	if file == null:
		push_error("Could not open game_config.json")
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("game_config.json is not a valid object")
		return
	login_session_time = data.get("login_session_time", login_session_time)
