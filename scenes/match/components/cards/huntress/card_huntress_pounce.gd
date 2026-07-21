class_name CardHuntressPounce
extends Card

# Huntress — "Pounce": roll 5 dice: add 1 damage for every Spear; on Claw,
# inflict Bleed. ATTACK MODIFIER: it improves the attack already declared this
# phase, so its damage and Bleed ride that attack and land when it resolves —
# it is never a hit of its own.


func _init() -> void:
	card_id = "huntress_pounce"


func is_attack_modifier() -> bool:
	return true


func resolve(ctx : BoardContext) -> void:
	# One throw of five dice, as the card reads — not five separate single rolls.
	var values : Array = await ctx.roll_dice(5)
	var spear_count := 0
	var any_claw := false
	for value in values:
		match Skill.symbol_for_value("huntress", int(value)):
			"spear":
				spear_count += 1
			"claw":
				any_claw = true
	if spear_count > 0:
		ctx.add_attack_damage(spear_count)
	if any_claw:
		ctx.add_attack_status("bleed", 1)
