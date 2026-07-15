class_name DoubleUp
extends Card

# Common card — "Double Up" (instant action): draw 2 cards.


func _init() -> void:
	card_id = "double_up"


func resolve(ctx: BoardContext) -> void:
	ctx.draw_cards(2)
