class_name TacticianIndirectApproach
extends Skill

# Tactician — "Indirect Approach" (Strategic Approach II's secondary):
# gain 2 Tactical Advantage, deal 2 undefendable damage.


func _init() -> void:
	skill_id = "tactician_indirect_approach"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", 2))
	e.damage = 2
	e.undefendable = true
	return e
