class_name CardTacticianCarpetBombII
extends Card

# Tactician — "Carpet Bomb II": upgrade slot 1 (Carpet Bomb) to its stage 1
# (adds Strategize as the slot's secondary).

const SLOT_INDEX := 1   # Carpet Bomb


func _init() -> void:
	card_id = "tactician_carpet_bomb_ii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
