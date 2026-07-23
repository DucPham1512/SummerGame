class_name CardTacticianCountermeasuresII
extends Card

# Tactician — "Countermeasures II": upgrade slot 7 (Countermeasures, defensive)
# to tier II. Not playable once the slot has already reached II or III (bug 80:
# no re-buying an upgrade, and no playing II after III).

const SLOT_INDEX := 7    # Countermeasures
const TARGET_STAGE := 1  # II


func _init() -> void:
	card_id = "tactician_countermeasures_ii"


func layout_allows_play(skill_layout) -> bool:
	return _upgrade_available(skill_layout, SLOT_INDEX, TARGET_STAGE)


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
