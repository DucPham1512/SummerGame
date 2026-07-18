class_name TryTryAgain
extends Card

# Common card — "Try, Try Again" (roll phase, any): re-roll up to two of your
# dice (the same die twice in a row is allowed).


func _init() -> void:
	card_id = "try_try_again"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	for i in 2:
		ctx.reroll_die(await ctx.choose_die(ctx.caster))
