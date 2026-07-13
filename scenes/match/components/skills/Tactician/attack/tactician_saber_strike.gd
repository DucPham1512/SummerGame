class_name TacticianSaberStrike
extends Skill

# Tactician — "Saber Strike": damage scales with the roll's saber count
# (3 sabers -> 4, 4 -> 5, 5 -> 6).

var damage_bonus : int = 1


func _init() -> void:
	skill_id = "tactician_saber_strike"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.damage = damage_bonus + clampi(ctx.roll_symbols.get("saber", 0), 3, 5)
	return e
