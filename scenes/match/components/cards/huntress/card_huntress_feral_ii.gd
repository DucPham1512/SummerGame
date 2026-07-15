class_name CardHuntressFeralII
extends Card

# Huntress — "Feral II": upgrade slot 5 (Feral) to its stage 1 (adds
# Ferocious as the slot's secondary).

const SLOT_INDEX := 5   # Feral


func _init() -> void:
	card_id = "huntress_feral_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
