class_name TwiceAsWild
extends Card

# Common card — "Twice As Wild" (roll phase, any): change the value of any two
# dice.


func _init() -> void:
	card_id = "twice_as_wild"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	for i in 2:
		ctx.change_die_value(await ctx.choose_die(), await ctx.choose_die_value())
