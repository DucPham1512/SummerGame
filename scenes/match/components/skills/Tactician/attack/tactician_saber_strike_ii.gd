class_name TacticianSaberStrikeII
extends TacticianSaberStrike

# Upgrade of Saber Strike: damage 5/6/7, and a 3-of-a-kind (any 3 dice
# showing the same value) additionally inflicts Constrict.


func _init() -> void:
	skill_id = "tactician_saber_strike_ii"
	damage_bonus = 2


func activate(ctx : BoardContext) -> SkillEffect:
	var e : SkillEffect = super.activate(ctx)
	if _has_n_of_a_kind(ctx.roll_values, 3):
		e.inflict_on_opponent.append(StatusEffect.new("constrict"))
	return e


static func _has_n_of_a_kind(values : Array[int], n : int) -> bool:
	var counts := {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
		if counts[v] >= n:
			return true
	return false
