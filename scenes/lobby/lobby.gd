extends Control

@export var CharSelection : PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MatchConfirmation.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_find_match_button_down() -> void:
	$MatchConfirmation.show()

func _on_decline_button_down() -> void:
	$MatchConfirmation.hide()

func _on_accept_button_down() -> void:
	get_tree().change_scene_to_packed(CharSelection)
