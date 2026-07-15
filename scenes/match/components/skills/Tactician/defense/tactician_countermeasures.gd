class_name TacticianCountermeasures
extends Skill

# Tactician defense — "Countermeasures": tallies the defensive roll.
# Every 2 Sabers: counter damage to the attacker (1 per pair; the II/III
# upgrades make it undefendable and 2 per pair). Every Flag: prevent 1
# damage from the incoming attack. Every Medal: gain 1 Tactical Advantage.

var damage_per_pair : int = 1
var undefendable_counter : bool = false


func _init() -> void:
	skill_id = "tactician_countermeasures"


func activate(ctx : BoardContext) -> SkillEffect:
	var e := SkillEffect.new()
	var sabers : int = ctx.roll_symbols.get("saber", 0)
	var flags : int = ctx.roll_symbols.get("flag", 0)
	var medals : int = ctx.roll_symbols.get("medal", 0)
	@warning_ignore("integer_division")
	e.damage = (sabers / 2) * damage_per_pair
	e.undefendable = undefendable_counter
	e.prevent_damage = flags
	if medals > 0:
		e.grant_to_self.append(StatusEffect.new("tactical_advantage", medals))
	return e
