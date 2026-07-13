class_name CardHuntressPounce
extends Card

# Huntress — "Pounce": roll 5 dice: add 1 damage for every Spear; on Claw,
# inflict Bleed. Attack modifier — resolved as an immediate independent hit
# (no plumbing exists to stack a card onto a pending skill attack).


func _init() -> void:
	card_id = "huntress_pounce"


func resolve(ctx : BoardContext) -> void:
	var spear_count := 0
	var any_claw := false
	for i in 5:
		var value : int = await ctx.roll_die()
		match Skill.symbol_for_value("huntress", value):
			"spear":
				spear_count += 1
			"claw":
				any_claw = true
	ctx.deal_damage(spear_count, ctx.opponent)
	if any_claw:
		ctx.apply_status("bleed", 1, ctx.opponent)
