extends Control

@export var HomePage : PackedScene
@export var ProfilePage : PackedScene
@export var CharCodexPage : PackedScene
@export var CardCodex : PackedScene
@export var Lobby : PackedScene
@export var Setting : PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneManager.content_container = $ContentContainer
	if (!EventBus.new_match):
		SceneManager.load_scene(HomePage)
	else:
		EventBus.new_match = false
		SceneManager.load_scene(Lobby)


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
