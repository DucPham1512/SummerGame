class_name TacticianSkillLayout
extends SkillLayout

# The tactician's board. The base SkillLayout does all the work; this subclass
# names the kit stages. Upgrades that unlock a secondary put it second in the
# stage (smaller lower panel). Only the ultimate has a behaviour script so
# far — the other slots render their data and activate as no-ops until their
# scripts are written (same method as the huntress kit).
#
# CONVENTION: the last slot (8, bottom right) is the defensive ability — the
# defensive roll flow reads defensive_skill().


## The tactician opens every match already holding Tactical Advantage (bug 68) —
## his own kit rule, so it lives on his board rather than in match setup.
const STARTING_TACTICAL_ADVANTAGE := 2


func _init() -> void:
	character = "tactician"


func apply_starting_statuses(combatant : Combatant) -> void:
	combatant.apply_status("tactical_advantage", STARTING_TACTICAL_ADVANTAGE)


func _kit() -> Dictionary:
	return {
		"ultimate": "tactician_higher_ground",
		"slots": [
			{"stages": [
				["tactician_saber_strike"],
				["tactician_saber_strike_ii"],
			]},
			{"stages": [
				["tactician_carpet_bomb"],
				["tactician_carpet_bomb_ii", "tactician_strategize"],
			]},
			{"stages": [
				["tactician_profiteer"],
				["tactician_profiteer_ii"],
			]},
			{"stages": [
				["tactician_strategic_approach"],
				["tactician_strategic_approach_ii", "tactician_indirect_approach"],
			]},
			{"stages": [
				["tactician_flank"],
				["tactician_flank_ii"],
			]},
			{"stages": [
				["tactician_maneuver"],
				["tactician_maneuver_ii", "tactician_reconnaissance"],
			]},
			{"stages": [
				["tactician_exploit"],
				["tactician_exploit_ii", "tactician_interdiction"],
			]},
			{"stages": [
				["tactician_countermeasures"],
				["tactician_countermeasures_ii"],
				["tactician_countermeasures_iii"],
			]},
		],
	}
