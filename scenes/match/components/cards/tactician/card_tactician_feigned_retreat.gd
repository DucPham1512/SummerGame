class_name CardTacticianFeignedRetreat
extends Card

# Tactician — "Feigned Retreat" (defensive roll window, after being
# attacked): inflict Constrict on the attacker and prevent 3 incoming damage.


func _init() -> void:
	card_id = "tactician_feigned_retreat"


func resolve(ctx : BoardContext) -> void:
	ctx.apply_status("constrict", 1, ctx.opponent)
	ctx.prevent_damage(3)
