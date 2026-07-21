class_name CardHuntressProwl
extends Card

# Huntress — "Prowl": roll 1 die: on Spear, add 1 damage; on Claw, add 2
# damage; on Soul, heal Nyra 1 HP; on Tooth, add 3 damage. ATTACK MODIFIER: the
# damage rides the attack already declared this phase (see Pounce). The Soul
# branch is a self effect and still resolves immediately.


func _init() -> void:
	card_id = "huntress_prowl"


func is_attack_modifier() -> bool:
	return true


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	match Skill.symbol_for_value("huntress", value):
		"spear":
			ctx.add_attack_damage(1)
		"claw":
			ctx.add_attack_damage(2)
		"soul":
			ctx.heal_companion(1)
		"tooth":
			ctx.add_attack_damage(3)
