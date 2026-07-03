class_name GettingPaid
extends Card

# Common card — "Getting Paid" (instant action): gain 2 combat points.


func _init() -> void:
	card_id = "getting_paid"


func resolve(ctx: BoardContext) -> void:
	ctx.gain_cp(2)
