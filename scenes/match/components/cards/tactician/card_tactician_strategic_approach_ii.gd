class_name CardTacticianStrategicApproachII
extends Card

# Tactician — "Strategic Approach II": upgrade slot 3 (Strategic Approach)
# to its stage 1 (adds Indirect Approach as the slot's secondary).

const SLOT_INDEX := 3   # Strategic Approach


func _init() -> void:
	card_id = "tactician_strategic_approach_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
