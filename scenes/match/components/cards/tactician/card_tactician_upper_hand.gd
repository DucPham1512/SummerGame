class_name CardTacticianUpperHand
extends Card

# Tactician — "Upper Hand": roll 1 die: on Medal, gain 4 Tactical Advantage;
# on any other outcome, draw 1 card.


func _init() -> void:
	card_id = "tactician_upper_hand"


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	if Skill.symbol_for_value("tactician", value) == "medal":
		ctx.apply_status("tactical_advantage", 4)
	else:
		ctx.draw_cards(1)
