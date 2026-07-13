class_name CardHuntressBloodBond
extends Card

# Huntress — "Blood Bond": roll 3 dice, heal Nyra 1 HP, +1 for every Soul,
# +2 for every Tooth.


func _init() -> void:
	card_id = "huntress_blood_bond"


func resolve(ctx : BoardContext) -> void:
	var heal := 1
	for i in 3:
		var value : int = await ctx.roll_die()
		match Skill.symbol_for_value("huntress", value):
			"soul":
				heal += 1
			"tooth":
				heal += 2
	ctx.heal_companion(heal)
