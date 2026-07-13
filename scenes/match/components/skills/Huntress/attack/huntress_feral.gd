class_name HuntressFeral
extends Skill

# Huntress — "Feral": heal Nyra 1 HP, deal undefendable damage.

var damage_amount : int = 5


func _init() -> void:
	skill_id = "huntress_feral"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.heal_companion = 1
	e.damage = damage_amount
	e.undefendable = true
	return e
