class_name CardHuntressResuscitateII
extends Card

# Huntress — "Resuscitate II": upgrade slot 2 (Resuscitate) to its stage 1.

const SLOT_INDEX := 2   # Resuscitate


func _init() -> void:
	card_id = "huntress_resuscitate_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
