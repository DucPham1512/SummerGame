class_name HuntressJungleFury
extends Skill

# Huntress ultimate — "Jungle Fury"
# Gain Nyra's Bond, inflict 2 Bleed on the opponent, then deal 12 undefendable damage.


func _init() -> void:
	skill_id = "huntress_jungle_fury"


func activate() -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("nyras_bond"))
	e.inflict_on_opponent.append(StatusEffect.new("bleed", 2))
	e.damage = 12
	return e
