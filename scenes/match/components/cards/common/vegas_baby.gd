class_name VegasBaby
extends Card

# Common card — "Vegas Baby" (main phase): roll 1 die, gain half the value as
# CP (rounded up).


func _init() -> void:
	card_id = "vegas_baby"


func resolve(ctx: BoardContext) -> void:
	var roll : int = await ctx.roll_die()
	ctx.gain_cp(ceili(roll / 2.0))
