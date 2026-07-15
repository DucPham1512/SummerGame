class_name CardTacticianAmbush
extends Card

# Tactician — "Ambush" (instant action): gain 2 Tactical Advantage.


func _init() -> void:
	card_id = "tactician_ambush"


func resolve(ctx : BoardContext) -> void:
	ctx.apply_status("tactical_advantage", 2)
