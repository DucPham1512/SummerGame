class_name CardTacticianCountermeasuresIII
extends Card

# Tactician — "Countermeasures III": upgrade slot 7 (Countermeasures, the
# defensive ability) to its stage 2. Requires Countermeasures II to already
# be in play — the slot only advances one stage per upgrade, same as every
# other upgrade chain.

const SLOT_INDEX := 7   # Countermeasures


func _init() -> void:
	card_id = "tactician_countermeasures_iii"


func resolve(ctx : BoardContext) -> void:
	ctx.upgrade_skill(SLOT_INDEX)
