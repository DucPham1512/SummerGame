class_name CardTacticianManeuverII
extends Card

# Tactician — "Maneuver II": upgrade slot 5 (Maneuver) to its stage 1 (adds
# Reconnaissance as the slot's secondary).

const SLOT_INDEX := 5   # Maneuver


func _init() -> void:
	card_id = "tactician_maneuver_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
