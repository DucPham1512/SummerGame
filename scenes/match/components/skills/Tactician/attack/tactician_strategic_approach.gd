class_name TacticianStrategicApproach
extends Skill

# Tactician — "Strategic Approach": inflict Constrict, deal 7 damage.

var ta_gain : int = 0   # the II upgrade adds a TA gain


func _init() -> void:
	skill_id = "tactician_strategic_approach"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	if ta_gain > 0:
		e.grant_to_self.append(StatusEffect.new("tactical_advantage", ta_gain))
	e.inflict_on_opponent.append(StatusEffect.new("constrict"))
	e.damage = 7
	return e
