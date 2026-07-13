class_name HuntressFeralInstincts
extends Skill

# Huntress — "Feral Instincts": gain Nyra's Bond, deal undefendable damage.

var damage_amount : int = 2


func _init() -> void:
	skill_id = "huntress_feral_instincts"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("nyras_bond"))
	e.damage = damage_amount
	e.undefendable = true
	return e
