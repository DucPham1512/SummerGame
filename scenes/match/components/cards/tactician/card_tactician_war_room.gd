class_name CardTacticianWarRoom
extends Card

# Tactician — "War Room": roll 1 die, gain half the value as Tactical
# Advantage (rounded up).


func _init() -> void:
	card_id = "tactician_war_room"


func resolve(ctx : BoardContext) -> void:
	var value : int = await ctx.roll_die()
	ctx.apply_status("tactical_advantage", ceili(value / 2.0))
