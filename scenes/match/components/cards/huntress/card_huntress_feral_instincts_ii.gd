class_name CardHuntressFeralInstinctsII
extends Card

# Huntress — "Feral Instincts II": upgrade slot 3 (Feral Instincts) to its
# stage 1 (adds Swipe as the slot's secondary).

const SLOT_INDEX := 3   # Feral Instincts


func _init() -> void:
	card_id = "huntress_feral_instincts_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
