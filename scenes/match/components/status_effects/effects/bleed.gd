class_name Bleed
extends StatusEffect

# Status effect — "Bleed" (negative, trigger): during the owner's Upkeep Phase,
# roll 1 die. On 1-4 the owner takes 1 undefendable damage; on 5-6 remove this
# token. One roll per on_upkeep call — if the match rules one roll per token,
# it calls this once per stack.

func on_upkeep(ctx : BoardContext) -> void:
	var roll : int = await ctx.roll_die()
	if roll <= 4:
		ctx.deal_damage(1, ctx.caster)   # owner takes it; undefendable per data
	else:
		remove_stacks(1)
