class_name HuntressHunt
extends Skill

# Huntress — "Hunt" (Savage II's secondary): inflict 1 Bleed, deal 3 damage.


func _init() -> void:
	skill_id = "huntress_hunt"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.damage = 3
	e.inflict_on_opponent.append(StatusEffect.new("bleed"))
	return e
