class_name TacticianHigherGround
extends Skill

# Tactician ultimate — "Higher Ground!"
# Inflict Targeted and Constrict on the opponent, raise Tactical Advantage's
# stack limit by 1, gain max Tactical Advantage, then deal 12 undefendable damage.


func _init() -> void:
	skill_id = "tactician_higher_ground"


func activate() -> SkillEffect:
	var e := SkillEffect.new()
	e.inflict_on_opponent.append(StatusEffect.new("targeted"))
	e.inflict_on_opponent.append(StatusEffect.new("constrict"))
	e.stack_limit_delta = {"tactical_advantage": 1}
	e.max_out_self.append("tactical_advantage")   # gain max TA (after the +1 limit)
	e.damage = 12
	return e
