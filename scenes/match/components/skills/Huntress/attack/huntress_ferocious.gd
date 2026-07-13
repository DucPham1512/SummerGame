class_name HuntressFerocious
extends Skill

# Huntress — "Ferocious" (Feral II's secondary): heal Nyra 1 HP, inflict
# 2 Bleed on a chosen opponent (the only opponent in 1v1).


func _init() -> void:
	skill_id = "huntress_ferocious"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.heal_companion = 1
	e.inflict_on_opponent.append(StatusEffect.new("bleed", 2))
	return e
