class_name TacticianStrategize
extends Skill

# Tactician — "Strategize" (Carpet Bomb II's secondary): gain 3 Tactical
# Advantage, draw 3 cards.


func _init() -> void:
	skill_id = "tactician_strategize"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", 3))
	e.draw_cards = 3
	return e
