class_name HuntressPredatoryAdvance
extends Skill

# Huntress — "Predatory Advance": heal Nyra 1 HP, deal damage.

var damage_amount : int = 5


func _init() -> void:
	skill_id = "huntress_predatory_advance"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.heal_companion = 1
	e.damage = damage_amount
	return e
