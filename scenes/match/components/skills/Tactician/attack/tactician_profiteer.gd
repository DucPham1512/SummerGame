class_name TacticianProfiteer
extends Skill

# Tactician — "Profiteer": gain Tactical Advantage, then a one-die branch:
# saber -> deal damage, flag -> more TA, medal -> draw 1 card and begin an
# additional Offensive Roll Phase.

var base_ta : int = 1
var saber_damage : int = 5
var flag_ta : int = 4


func _init() -> void:
	skill_id = "tactician_profiteer"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.grant_to_self.append(StatusEffect.new("tactical_advantage", base_ta))
	var branch : int = await ctx.roll_die()
	match Skill.symbol_for_value("tactician", branch):
		"saber":
			e.damage = saber_damage
		"flag":
			e.grant_to_self.append(StatusEffect.new("tactical_advantage", flag_ta))
		"medal":
			e.draw_cards = 1
			e.extra_offensive_phase = true
	return e
