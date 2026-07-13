class_name HuntressMaternalBond
extends Skill

# Huntress defense — "Maternal Bond": tallies the defensive roll.
#   * each Spear: deal 1 counter damage (III also counts Teeth)
#   * each Soul: heal Nyra 1 HP
#   * each Claw, while Nyra is ACTIVE: deal 2 counter damage
# The dice count (3 or 4) lives in the data's defensive_roll cost.

var tooth_counts_as_spear : bool = false


func _init() -> void:
	skill_id = "huntress_maternal_bond"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	var nyra_active : bool = ctx.caster != null and ctx.caster.companion != null \
			and ctx.caster.companion.is_active()
	for value in ctx.roll_values:
		match Skill.symbol_for_value("huntress", value):
			"spear":
				e.damage += 1
			"tooth":
				if tooth_counts_as_spear:
					e.damage += 1
			"soul":
				e.heal_companion += 1
			"claw":
				if nyra_active:
					e.damage += 2
	return e
