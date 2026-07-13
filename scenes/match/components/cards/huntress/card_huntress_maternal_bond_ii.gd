class_name CardHuntressMaternalBondII
extends Card

# Huntress — "Maternal Bond II": upgrade slot 7 (Maternal Bond, defensive)
# to its stage 1.

const SLOT_INDEX := 7   # Maternal Bond


func _init() -> void:
	card_id = "huntress_maternal_bond_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
