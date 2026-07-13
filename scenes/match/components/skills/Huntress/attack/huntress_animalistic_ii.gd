class_name HuntressAnimalisticII
extends HuntressAnimalistic

# "Animalistic II": one damage tier up (3 spears -> 4 dmg ... 5 -> 6), and a
# 4-of-a-kind (four identical face VALUES) also inflicts Bleed.


func _init() -> void:
	skill_id = "huntress_animalistic_ii"
	damage_bonus = 1


func activate(ctx : BoardContext) -> SkillEffect:
	var e := super.activate(ctx)
	if _has_four_of_a_kind(ctx.roll_values):
		e.inflict_on_opponent.append(StatusEffect.new("bleed"))
	return e


static func _has_four_of_a_kind(values : Array[int]) -> bool:
	var counts := {}
	for value in values:
		counts[value] = counts.get(value, 0) + 1
		if counts[value] >= 4:
			return true
	return false
