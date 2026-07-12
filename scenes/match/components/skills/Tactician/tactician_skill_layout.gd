class_name TacticianSkillLayout
extends SkillLayout

# The tactician's board. The base SkillLayout does all the work (populate,
# upgrade_skill); this subclass only names the kit. tactician_skill_layout.tscn
# is currently hardcoded into player.tscn / opponent.tscn — TODO: character
# selection assigns the right layout per side once it exists.
#
# Kit = the 8 base abilities + ultimate from skills.json. The "_ii" upgrades
# swap in via upgrade_skill(current, "<id>_ii"); secondary abilities
# (strategize, indirect_approach, reconnaissance, interdiction) are unlocked
# by their _ii owners and live outside these nine slots.


func _init() -> void:
	character = "tactician"


func _kit() -> Dictionary:
	# CONVENTION: the last entry (slot 8, bottom right) must be the defensive
	# ability — the defensive roll flow reads skills[7].
	return {
		"ultimate": "tactician_higher_ground",
		"skills": [
			"tactician_saber_strike",
			"tactician_carpet_bomb",
			"tactician_profiteer",
			"tactician_strategic_approach",
			"tactician_flank",
			"tactician_maneuver",
			"tactician_exploit",
			"tactician_countermeasures",
		],
	}
