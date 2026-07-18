class_name TipIt
extends Card

# Common card — "Tip It!" (instant action): raise or lower any die by 1
# (a 1 can't go lower, a 6 can't go higher — the die UI enforces the bounds).


func _init() -> void:
	card_id = "tip_it"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	var die : int = await ctx.choose_die()
	var increase : bool = await ctx.choose_option(["Increase by 1", "Decrease by 1"]) == 0
	ctx.adjust_die_value(die, 1 if increase else -1)
