extends Control

@export var HomePage : PackedScene
@export var ProfilePage : PackedScene
@export var CharCodexPage : PackedScene
@export var CardCodex : PackedScene
@export var Lobby : PackedScene
@export var Setting : PackedScene

# The signed-in identity, shown in the navigation bar. The bar belongs to this
# shell rather than to any page, so it stays on screen across Home, the codexes
# and the lobby.
@onready var username_label : Label = $NavigationBar/UsernameLabel
@onready var user_id_label : Label = $NavigationBar/UserIdLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_refresh_identity()
	SceneManager.content_container = $ContentContainer
	if (!EventBus.new_match):
		SceneManager.load_scene(HomePage)
	else:
		EventBus.new_match = false
		SceneManager.load_scene(Lobby)


# Reaching this scene means a login succeeded, so the identity is already
# captured (login, session restore, or verification all set it). No connection
# hookup is needed: unlike the client id, the email does not change when the
# connection is re-established. Empty means we got here without one of those
# paths — say so rather than showing a blank strip.
func _refresh_identity() -> void:
	if Util.active_username.is_empty():
		username_label.text = "Not signed in"
	else:
		username_label.text = Util.active_username
	if Util.active_email.is_empty():
		user_id_label.text = "Mail: —"
	else:
		user_id_label.text = "Mail: %s" % Util.active_email


func _on_profile_button_button_down() -> void:
	SceneManager.load_scene(ProfilePage)
	
	
func _on_home_button_button_down() -> void:
	SceneManager.load_scene(HomePage)
	
	
func _on_char_codex_button_button_down() -> void:
	SceneManager.load_scene(CharCodexPage)


func _on_card_codex_button_button_down() -> void:
	SceneManager.load_scene(CardCodex)

func _on_new_match_signal() -> void:
	SceneManager.load_scene(Lobby)
	
func _on_setting_button_down() -> void:
	SceneManager.load_scene(Setting)
