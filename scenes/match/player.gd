class_name Player
extends Combatant

# The local, full side of the board. Resource signals/state live on Combatant,
# shared with the Opponent view, so the bar components serve both sides.

@onready var hp_label : Label = $PlayerResourceContainer/HpContainer/HealthLabel
@onready var cp_label : Label = $PlayerResourceContainer/CpContainer/CpLabel
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_player_health(max_hp)
	update_player_cp(Util.one_v_one_starting_cp)
	
func update_player_health(value : int):
	health = clampi(health + value, 0, max_hp)
	hp_label.text = "%d / %d" % [health, max_hp]
	health_changed.emit(health)
	
func update_player_cp(value : int):
	cp = clampi(cp + value, 0, max_cp)
	cp_label.text = "%d / %d" % [cp, max_cp]
	cp_changed.emit(cp)


func _on_decrease_hp_pressed() -> void:
	update_player_health(-1)


func _on_increase_hp_pressed() -> void:
	update_player_health(1)

func _on_increase_cp_pressed() -> void:
	update_player_cp(1)

func _on_decrease_cp_pressed() -> void:
	update_player_cp(-1)


	
