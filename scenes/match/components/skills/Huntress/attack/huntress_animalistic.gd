class_name HuntressAnimalistic
extends Skill

# Huntress — "Animalistic": damage scales with the spears rolled
# (3 -> 3 dmg, 4 -> 4, 5 -> 5).

## Added on top of the spear count (0 at base; II raises it).
var damage_bonus : int = 0


func _init() -> void:
	skill_id = "huntress_animalistic"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	var spears : int = clampi(ctx.roll_symbols.get("spear", 0), 3, 5)
	e.damage = spears + damage_bonus
	return e
