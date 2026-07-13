class_name HuntressSwipe
extends Skill

# Huntress — "Swipe" (Feral Instincts II's secondary): inflict Bleed on up to
# three chosen opponents. In 1v1 the only opponent is the target; the
# multi-target chooser matters in FFA (TODO with choose_player when it lands).


func _init() -> void:
	skill_id = "huntress_swipe"


func activate(_ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	e.inflict_on_opponent.append(StatusEffect.new("bleed"))
	return e
