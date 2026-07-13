class_name TacticianCarpetBomb
extends Skill

# Tactician — "Carpet Bomb": gain Tactical Advantage, deal 2 undefendable
# collateral damage. The card text says "to 2 different chosen opponents" —
# in 1v1 exactly one valid target exists, so it lands on the opponent once
# (same single-target collapse as the huntress's Swipe).

var ta_gain : int = 1


func _init() -> void:
	skill_id = "tactician_carpet_bomb"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", ta_gain))
	e.damage = 2
	e.undefendable = true
	return e
