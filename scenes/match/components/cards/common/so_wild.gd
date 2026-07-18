class_name SoWild
extends Card

# Common card — "So Wild" (roll phase, any): change the value of any one die.


func _init() -> void:
	card_id = "so_wild"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	ctx.change_die_value(await ctx.choose_die(), await ctx.choose_die_value())
