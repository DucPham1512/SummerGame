class_name CardHuntressSavageII
extends Card

# Huntress — "Savage II": upgrade slot 1 (Savage) to its stage 1 (adds Hunt
# as the slot's secondary).

const SLOT_INDEX := 1   # Savage


func _init() -> void:
	card_id = "huntress_savage_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
