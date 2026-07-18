class_name OneMoreTime
extends Card

# Common card — "One More Time" (roll phase, offensive): a chosen player gets
# an additional Roll Attempt of up to five dice in their Offensive Roll Phase.


func _init() -> void:
	card_id = "one_more_time"


func roll_need() -> RollNeed:
	return RollNeed.OWN


func resolve(ctx: BoardContext) -> void:
	ctx.grant_extra_roll(await ctx.choose_player())
