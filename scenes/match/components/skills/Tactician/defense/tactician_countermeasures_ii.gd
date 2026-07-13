class_name TacticianCountermeasuresII
extends TacticianCountermeasures

# Upgrade of Countermeasures: 5 dice (from the data's dice_count), and the
# per-pair saber counter damage is now undefendable.


func _init() -> void:
	skill_id = "tactician_countermeasures_ii"
	undefendable_counter = true
