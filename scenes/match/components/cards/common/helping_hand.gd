class_name HelpingHand
extends Card

# Common card — "Helping Hand" (roll phase, any): select one of the OPPONENT's
# dice and force them to re-roll it.


func _init() -> void:
	card_id = "helping_hand"


func resolve(ctx: BoardContext) -> void:
	ctx.reroll_die(await ctx.choose_die(ctx.opponent))
