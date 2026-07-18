class_name HelpingHand
extends Card

# Common card — "Helping Hand" (roll phase, any): select one of the OPPONENT's
# dice and force them to re-roll it.


func _init() -> void:
	card_id = "helping_hand"


func roll_need() -> RollNeed:
	return RollNeed.OPPONENT


func resolve(ctx: BoardContext) -> void:
	ctx.force_opponent_reroll(await ctx.choose_opponent_die())
