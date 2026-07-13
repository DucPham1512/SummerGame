class_name CardTacticianBunkerUp
extends Card

# Tactician — "Bunker Up": a chosen player gains Protect.


func _init() -> void:
	card_id = "tactician_bunker_up"


func resolve(ctx : BoardContext) -> void:
	var target = await ctx.choose_player()
	ctx.apply_status("protect", 1, target)
