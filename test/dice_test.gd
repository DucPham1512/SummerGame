extends Control

@onready var dice: AnimatedSprite2D = $Dice
@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	dice.roll_finished.connect(_on_roll_finished)


func _on_roll_button_pressed() -> void:
	result_label.text = "Rolling..."
	dice.roll()


func _on_roll_finished(result: int) -> void:
	result_label.text = "Result: %d" % result
