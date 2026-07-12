class_name NotThisTime
extends Card

# Common card — "Not This Time" (roll phase, any): a chosen player prevents 6
# incoming damage.


func _init() -> void:
	card_id = "not_this_time"


func resolve(ctx: BoardContext) -> void:
	ctx.prevent_damage(6, await ctx.choose_player())
