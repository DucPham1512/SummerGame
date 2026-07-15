class_name CardHuntressMaternalBondIII
extends Card

# Huntress — "Maternal Bond III": upgrade slot 7 (Maternal Bond, defensive)
# to its stage 2. Requires Maternal Bond II to already be in play — the slot
# only advances one stage per upgrade, same as the skill layout does for
# every other upgrade chain.

const SLOT_INDEX := 7   # Maternal Bond


func _init() -> void:
	card_id = "huntress_maternal_bond_iii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
