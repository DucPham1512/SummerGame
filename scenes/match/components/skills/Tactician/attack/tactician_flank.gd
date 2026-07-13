class_name TacticianFlank
extends Skill

# Tactician — "Flank" (small straight): gain Tactical Advantage, deal 6 damage.

var ta_gain : int = 1


func _init() -> void:
	skill_id = "tactician_flank"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", ta_gain))
	e.damage = 6
	return e
