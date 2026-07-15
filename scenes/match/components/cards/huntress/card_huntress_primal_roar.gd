class_name CardHuntressPrimalRoar
extends Card

# Huntress — "Primal Roar": roll 1 die: on Tooth, heal Nyra 4 HP; on any
# other outcome, draw 1 card.


func _init() -> void:
	card_id = "huntress_primal_roar"


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	if Skill.symbol_for_value("huntress", value) == "tooth":
		ctx.heal_companion(4)
	else:
		ctx.draw_cards(1)
