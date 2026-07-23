class_name CardTacticianCountermeasuresIII
extends Card

# Tactician — "Countermeasures III": upgrade slot 7 (Countermeasures, defensive)
# to tier III. Lands on III whether or not Countermeasures II was played first; if
# II WAS played its cost is refunded (bug 80), and once III is in play neither
# tier card can be dropped again.

const SLOT_INDEX := 7                                # Countermeasures
const TARGET_STAGE := 2                              # III
const PREV_CARD_ID := "tactician_countermeasures_ii" # refunded once it's in play


func _init() -> void:
	card_id = "tactician_countermeasures_iii"


func effective_cp_cost(skill_layout) -> int:
	return _tiered_upgrade_cost(skill_layout, SLOT_INDEX, PREV_CARD_ID)


func layout_allows_play(skill_layout) -> bool:
	return _upgrade_available(skill_layout, SLOT_INDEX, TARGET_STAGE)


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill_to(SLOT_INDEX, TARGET_STAGE)
