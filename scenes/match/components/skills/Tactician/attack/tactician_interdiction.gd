class_name TacticianInterdiction
extends Skill

# Tactician — "Interdiction" (Exploit II's secondary): draw 2 cards, inflict
# Constrict on a chosen opponent (the single opponent in 1v1).


func _init() -> void:
	skill_id = "tactician_interdiction"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.draw_cards = 2
	e.inflict_on_opponent.append(StatusEffect.new("constrict"))
	return e
