class_name Samesies
extends Card

# Common card — "Samesies" (roll phase, any): change the value of one of your
# dice to match another of your dice from the same roll.


func _init() -> void:
	card_id = "samesies"


func resolve(ctx: BoardContext) -> void:
	var source : int = await ctx.choose_die(ctx.caster)
	var destination : int = await ctx.choose_die(ctx.caster)
	ctx.copy_die_value(source, destination)
