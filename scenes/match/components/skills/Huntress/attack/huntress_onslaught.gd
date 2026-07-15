class_name HuntressOnslaught
extends Skill

# Huntress — "Onslaught": one ability in one container (like Animalistic).
# The cost gate is a small straight; if the roll actually holds a large
# straight the effect scales up: 1 Bleed + 4 damage -> 2 Bleed + 7 damage.

var small_damage : int = 4
var large_damage : int = 7
var small_bleed : int = 1
var large_bleed : int = 2


func _init() -> void:
	skill_id = "huntress_onslaught"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	var large := _has_straight(ctx.roll_values, 5)
	e.damage = large_damage if large else small_damage
	e.inflict_on_opponent.append(StatusEffect.new("bleed", large_bleed if large else small_bleed))
	return e
