extends Node

var login_session_time: int = 86400   # default/fallback

# Set by the login screen after a successful GD-Sync account login.
var active_username : String = ""

# Matchmaking: base elo seeded at registration, and the widest elo gap two
# players can be matched across.
const BASE_ELO : int = 1000
const ELO_THRESHOLD : int = 100

# Game rule – 1v1 mode (defaults mirror resources/game_rule.json)
var one_v_one_max_hp : int = 50
var one_v_one_starting_cp : int = 1
var one_v_one_max_cp : int = 15
var one_v_one_deck_size : int = 18
var one_v_one_starting_hand_size : int = 4
var one_v_one_hand_limit : int = 6   # Discard Phase: sell down to this many
var one_v_one_time_pool_seconds : int = 600
var max_dice_rolls : int = 3

func _ready() -> void:
	load_config()
	load_game_rule()
	GDSync.start_multiplayer()


## GD-Sync cloud/account calls fail while the plugin is not connected. It is
## started at boot (above), but the connection may still be mid-handshake — or
## have dropped back to disabled after a failure — when a screen needs it.
## Await this before any account/cloudstorage request. start_multiplayer() is
## safe to repeat: it no-ops unless the connection is fully disabled.
func ensure_gdsync_connected() -> void:
	if GDSync.is_active():
		return
	GDSync.start_multiplayer()
	await GDSync.connected
	
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

func load_game_rule() -> void:
	var file := FileAccess.open("res://resources/game_rule.json", FileAccess.READ)
	if file == null:
		push_error("Could not open game_rule.json")
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("game_rule.json is not a valid object")
		return

	max_dice_rolls = data.get("max_dice_rolls", max_dice_rolls)

	var modes: Dictionary = data.get("modes", {})
	var one_v_one: Dictionary = modes.get("one_v_one", {})
	one_v_one_max_hp = one_v_one.get("max_hp", one_v_one_max_hp)
	one_v_one_starting_cp = one_v_one.get("starting_cp", one_v_one_starting_cp)
	one_v_one_max_cp = one_v_one.get("max_cp", one_v_one_max_cp)
	one_v_one_deck_size = one_v_one.get("deck_size", one_v_one_deck_size)
	one_v_one_starting_hand_size = one_v_one.get("starting_hand_size", one_v_one_starting_hand_size)
	one_v_one_hand_limit = one_v_one.get("hand_limit", one_v_one_hand_limit)
	one_v_one_time_pool_seconds = one_v_one.get("time_pool_seconds", one_v_one_time_pool_seconds)
