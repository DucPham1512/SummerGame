class_name CardHuntressProwl
extends Card

# Huntress — "Prowl": roll 1 die: on Spear, add 1 damage; on Claw, add 2
# damage; on Soul, heal Nyra 1 HP; on Tooth, add 3 damage. Attack modifier —
# resolved as an immediate independent hit (see Pounce).


func _init() -> void:
	card_id = "huntress_prowl"


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	match Skill.symbol_for_value("huntress", value):
		"spear":
			ctx.deal_damage(1, ctx.opponent)
		"claw":
			ctx.deal_damage(2, ctx.opponent)
		"soul":
			ctx.heal_companion(1)
		"tooth":
			ctx.deal_damage(3, ctx.opponent)
