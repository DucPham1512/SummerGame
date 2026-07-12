class_name GetThatOutaHere
extends Card

# Common card — "Get That Outa Here" (main phase): remove a status effect
# token from a chosen player.


func _init() -> void:
	card_id = "get_that_outa_here"


func resolve(ctx: BoardContext) -> void:
	var target = await ctx.choose_player()
	var status_id : String = await ctx.choose_status(target)
	ctx.remove_status(status_id, target)
