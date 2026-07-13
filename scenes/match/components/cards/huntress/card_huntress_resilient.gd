class_name CardHuntressResilient
extends Card

# Huntress — "Resilient": gain Nyra's Bond.


func _init() -> void:
	card_id = "huntress_resilient"


func resolve(ctx : BoardContext) -> void:
	ctx.apply_status("nyras_bond")
