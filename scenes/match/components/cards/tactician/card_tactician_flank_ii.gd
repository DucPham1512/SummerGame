class_name CardTacticianFlankII
extends Card

# Tactician — "Flank II": upgrade slot 4 (Flank) to its stage 1.

const SLOT_INDEX := 4   # Flank


func _init() -> void:
	card_id = "tactician_flank_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
