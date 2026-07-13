class_name CardTacticianDisengage
extends Card

# Tactician — "Disengage" (defensive roll window, after being attacked):
# roll 1 die: on Saber, deal 2 damage to the attacker; on Flag, prevent 3
# damage; on Medal, gain Protect. The attacker is ctx.opponent — this card
# is only legal in the defender's window (phase gate in turn_manager).


func _init() -> void:
	card_id = "tactician_disengage"


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	match Skill.symbol_for_value("tactician", value):
		"saber":
			ctx.deal_damage(2, ctx.opponent)
		"flag":
			ctx.prevent_damage(3)
		"medal":
			ctx.apply_status("protect", 1)
