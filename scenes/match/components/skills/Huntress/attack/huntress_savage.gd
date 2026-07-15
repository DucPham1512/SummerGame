class_name HuntressSavage
extends Skill

# Huntress — "Savage": fixed damage plus a one-die branch roll:
# spear -> +1 dmg, claw -> +2 dmg, soul -> gain Nyra's Bond,
# tooth -> inflict 1 Bleed.

var base_damage : int = 4


func _init() -> void:
	skill_id = "huntress_savage"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.damage = base_damage
	var branch : int = await ctx.roll_die()
	match Skill.symbol_for_value("huntress", branch):
		"spear":
			e.damage += 1
		"claw":
			e.damage += 2
		"soul":
			e.grant_to_self.append(StatusEffect.new("nyras_bond"))
		"tooth":
			e.inflict_on_opponent.append(StatusEffect.new("bleed"))
	return e
