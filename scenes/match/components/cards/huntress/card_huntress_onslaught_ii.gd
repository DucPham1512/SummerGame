class_name CardHuntressOnslaughtII
extends Card

# Huntress — "Onslaught II": upgrade slot 4 (Onslaught) to its stage 1.

const SLOT_INDEX := 4   # Onslaught


func _init() -> void:
	card_id = "huntress_onslaught_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
