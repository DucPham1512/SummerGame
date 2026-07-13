class_name HuntressResuscitate
extends Skill

# Huntress — "Resuscitate": gain Nyra's Bond, heal Nyra 3 HP.


func _init() -> void:
	skill_id = "huntress_resuscitate"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("nyras_bond"))
	e.heal_companion = 3
	return e
