class_name SixIt
extends Card

# Common card — "Six-It" (roll phase, any): change one of YOUR dice to a 6.


func _init() -> void:
	card_id = "six_it"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	ctx.change_die_value(await ctx.choose_die(ctx.caster), 6)
