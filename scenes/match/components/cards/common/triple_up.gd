class_name TripleUp
extends Card

# Common card — "Triple Up" (instant action): draw 3 cards.


func _init() -> void:
	card_id = "triple_up"


func resolve(ctx: BoardContext) -> void:
	ctx.draw_cards(3)
