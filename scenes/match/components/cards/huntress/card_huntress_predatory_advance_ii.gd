class_name CardHuntressPredatoryAdvanceII
extends Card

# Huntress — "Predatory Advance II": upgrade slot 6 (Predatory Advance) to
# its stage 1 (adds Jugular as the slot's secondary).

const SLOT_INDEX := 6   # Predatory Advance


func _init() -> void:
	card_id = "huntress_predatory_advance_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
