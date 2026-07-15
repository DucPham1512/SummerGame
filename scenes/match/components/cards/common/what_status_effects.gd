class_name WhatStatusEffects
extends Card

# Common card — "What Status Effects?" (main phase): remove ALL status effect
# tokens from a chosen player.


func _init() -> void:
	card_id = "what_status_effects"


func resolve(ctx: BoardContext) -> void:
	ctx.clear_all_statuses(await ctx.choose_player())
