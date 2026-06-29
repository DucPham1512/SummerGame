class_name Player
extends Control

signal health_changed(health : int)

var health : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health = Util.one_v_one_starting_hp
	health_changed.emit(health)
	
func test():
	health -= 10
	health_changed.emit(health)

func _on_test_hp_pressed() -> void:
	test()
