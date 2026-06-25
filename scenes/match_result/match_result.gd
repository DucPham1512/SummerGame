extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_again_button_button_down() -> void:
	EventBus.new_match = true
	get_tree().change_scene_to_file("res://scenes/common/main_client.tscn")


func _on_home_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/common/main_client.tscn")
