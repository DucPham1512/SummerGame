class_name BuhBye
extends Card

# Common card — "Buh, Bye" (instant action): remove a status effect token from
# a chosen player.


func _init() -> void:
	card_id = "buh_bye"


func resolve(ctx: BoardContext) -> void:
	var target = await ctx.choose_player()
	var status_id : String = await ctx.choose_status(target)
	ctx.remove_status(status_id, target)
