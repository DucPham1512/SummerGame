class_name CardHuntressSavageSlash
extends Card

# Huntress — "Savage Slash": choose a player and roll 1 die: on Claw or
# Tooth, inflict 2 Bleed; otherwise inflict 1 Bleed.


func _init() -> void:
	card_id = "huntress_savage_slash"


func resolve(ctx : BoardContext) -> void:
	var target = await ctx.choose_player()
	var value : int = await ctx.roll_die()
	var symbol := Skill.symbol_for_value("huntress", value)
	var stacks := 2 if (symbol == "claw" or symbol == "tooth") else 1
	ctx.apply_status("bleed", stacks, target)
