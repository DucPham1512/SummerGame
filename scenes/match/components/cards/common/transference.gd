class_name Transference
extends Card

# Common card — "Transference" (main phase): transfer 1 status effect token
# from a chosen player to another chosen player.


func _init() -> void:
	card_id = "transference"


func resolve(ctx: BoardContext) -> void:
	var from = await ctx.choose_player()
	var to = await ctx.choose_player()
	var status_id : String = await ctx.choose_status(from)
	ctx.transfer_status(status_id, from, to)
