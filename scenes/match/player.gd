class_name Player
extends Control

signal health_changed(health : int)
signal cp_changed(cp: int)

var health : int
var cp: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health = Util.one_v_one_max_hp
	health_changed.emit(health)
	cp = Util.one_v_one_starting_cp
	cp_changed.emit(cp)
	
func update_player_health(value : int):
	health += value
	health_changed.emit(health)

func update_player_cp(value : int):
	cp += value
	cp_changed.emit(cp)


func _on_decrease_hp_pressed() -> void:
	update_player_health(-1)


func _on_increase_hp_pressed() -> void:
	update_player_health(1)

func _on_increase_cp_pressed() -> void:
	update_player_cp(1)

func _on_decrease_cp_pressed() -> void:
	update_player_cp(-1)
