class_name TacticianProfiteerII
extends TacticianProfiteer

# Upgrade of Profiteer: gains 2 base TA; saber branch deals 6; flag branch
# grants 3 TA.


func _init() -> void:
	skill_id = "tactician_profiteer_ii"
	base_ta = 2
	saber_damage = 6
	flag_ta = 3
