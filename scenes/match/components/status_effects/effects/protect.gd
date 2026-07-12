class_name Protect
extends StatusEffect

# Status effect — "Protect" (positive, spendable): spend at any time to prevent
# 1/2 of incoming damage (rounded up). The halving is a board verb because only
# the board knows the incoming amount during damage resolution; this token just
# pays the cost and declares the intent.


func is_positive() -> bool:
	return true


func can_spend() -> bool:
	return stacks > 0


func spend(ctx : BoardContext) -> bool:
	if not can_spend():
		return false
	remove_stacks(1)
	ctx.halve_incoming_damage(ctx.caster)
	return true


func spend_options(ctx : BoardContext) -> Array[Dictionary]:
	return [
		{
			"label": "Prevent half of the incoming damage (rounded up)",
			"enabled": can_spend() and ctx.incoming_damage > 0,
			"action": spend.bind(ctx),
		},
	]
