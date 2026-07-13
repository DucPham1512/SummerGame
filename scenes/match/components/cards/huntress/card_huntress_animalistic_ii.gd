class_name CardHuntressAnimalisticII
extends Card

# Huntress — "Animalistic II": upgrade slot 0 (Animalistic) to its stage 1.

const SLOT_INDEX := 0   # Animalistic


func _init() -> void:
	card_id = "huntress_animalistic_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
