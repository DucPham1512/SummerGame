class_name TacticianReconnaissance
extends Skill

# Tactician — "Reconnaissance" (Maneuver II's secondary): gain 5 Tactical
# Advantage.


func _init() -> void:
	skill_id = "tactician_reconnaissance"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", 5))
	return e
