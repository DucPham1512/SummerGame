class_name HuntressResuscitateII
extends Skill

# Huntress — "Resuscitate II": gain Nyra's Bond, heal Nyra 2 HP for EVERY
# soul in the roll.


func _init() -> void:
	skill_id = "huntress_resuscitate_ii"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("nyras_bond"))
	e.heal_companion = 2 * int(ctx.roll_symbols.get("soul", 0))
	return e
