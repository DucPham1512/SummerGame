class_name TacticianManeuverII
extends TacticianManeuver

# Upgrade of Maneuver: additionally inflicts Constrict.


func _init() -> void:
	skill_id = "tactician_maneuver_ii"
	inflicts_constrict = true
