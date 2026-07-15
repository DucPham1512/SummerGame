class_name CardTacticianCountermeasuresII
extends Card

# Tactician — "Countermeasures II": upgrade slot 7 (Countermeasures, the
# defensive ability) to its stage 1.

const SLOT_INDEX := 7   # Countermeasures


func _init() -> void:
	card_id = "tactician_countermeasures_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
