class_name CardHuntressSavageSlash
extends Card

# Huntress — "Savage Slash": choose a player and roll 1 die: on Claw or
# Tooth, inflict 2 Bleed; otherwise inflict 1 Bleed.
#
# Inflicting Bleed makes this an attack, so the card resolves against the
# opponent without asking: in 1v1 there is no other sensible target. It must NOT
# go through ctx.choose_player(), which hands back the caster — that is what made
# this card bleed its own player (bug 75).


func _init() -> void:
	card_id = "huntress_savage_slash"


func resolve(ctx : BoardContext) -> void:
	# apply_status falls back to the caster when handed a null target, so a
	# missing opponent would quietly recreate exactly the bug this fixes.
	if ctx.opponent == null:
		push_warning("Savage Slash: no opponent on the board — nothing inflicted")
		return
	var value : int = await ctx.roll_die()
	var symbol := Skill.symbol_for_value("huntress", value)
	var stacks := 2 if (symbol == "claw" or symbol == "tooth") else 1
	ctx.apply_status("bleed", stacks, ctx.opponent)
