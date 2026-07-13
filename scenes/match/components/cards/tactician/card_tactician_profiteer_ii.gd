class_name CardTacticianProfiteerII
extends Card

# Tactician — "Profiteer II": upgrade slot 2 (Profiteer) to its stage 1.

const SLOT_INDEX := 2   # Profiteer


func _init() -> void:
	card_id = "tactician_profiteer_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
