extends Control

# The post-match screen. The match hands the verdict over on EventBus right
# before it swaps here (change_scene_to_* can't carry arguments), the same way
# Play Again hands new_match to the client shell.

## Placeholder presentation — a single word until the real win/defeat screen
## art exists.
const OUTCOME_TEXT := {
	EventBus.Outcome.VICTORY: "Victory",
	EventBus.Outcome.DEFEAT: "Defeat",
	EventBus.Outcome.DRAW: "Draw",
}

@onready var result_label : Label = $ResultLabel


func _ready() -> void:
	result_label.text = OUTCOME_TEXT.get(EventBus.match_outcome, "")
	# Consume-then-reset, like EventBus.new_match: the verdict belongs to the
	# match that just ended, so it must not survive into the next one.
	EventBus.match_outcome = EventBus.Outcome.NONE


func _on_play_again_button_button_down() -> void:
	EventBus.new_match = true
	get_tree().change_scene_to_file("res://scenes/common/main_client.tscn")


func _on_home_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/common/main_client.tscn")
