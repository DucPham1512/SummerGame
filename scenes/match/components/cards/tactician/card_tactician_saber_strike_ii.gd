class_name CardTacticianSaberStrikeII
extends Card

# Tactician — "Saber Strike II": upgrade slot 0 (Saber Strike) to its stage 1.

const SLOT_INDEX := 0   # Saber Strike


func _init() -> void:
	card_id = "tactician_saber_strike_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
