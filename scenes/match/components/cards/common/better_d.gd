class_name BetterD
extends Card

# Common card — "Better D" (roll phase, any): a chosen player gets an
# additional Roll Attempt of up to five dice in their Defensive Roll Phase.


func _init() -> void:
	card_id = "better_d"


func resolve(ctx: BoardContext) -> void:
	ctx.grant_extra_roll(await ctx.choose_player())
