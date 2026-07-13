class_name HuntressJugular
extends Skill

# Huntress — "Jugular" (Predatory Advance II's secondary): inflict 2 Bleed.


func _init() -> void:
	skill_id = "huntress_jugular"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.inflict_on_opponent.append(StatusEffect.new("bleed", 2))
	return e
