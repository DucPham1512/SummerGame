class_name TacticianManeuver
extends Skill

# Tactician — "Maneuver": gain 5 Tactical Advantage, deal 5 undefendable
# damage.

var inflicts_constrict : bool = false   # the II upgrade adds Constrict


func _init() -> void:
	skill_id = "tactician_maneuver"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", 5))
	if inflicts_constrict:
		e.inflict_on_opponent.append(StatusEffect.new("constrict"))
	e.damage = 5
	e.undefendable = true
	return e
