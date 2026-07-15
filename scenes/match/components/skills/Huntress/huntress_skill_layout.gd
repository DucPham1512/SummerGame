class_name HuntressSkillLayout
extends SkillLayout

# The huntress's board. The base SkillLayout does all the work; this subclass
# names the kit stages. Upgrades that unlock a secondary put it second in the
# stage (smaller lower panel). Onslaught is a single container like
# Animalistic — its script scales the effect when a large straight is rolled.
#
# CONVENTION: the last slot (8, bottom right) is the defensive ability — the
# defensive roll flow reads defensive_skill().


func _init() -> void:
	character = "huntress"


func _kit() -> Dictionary:
	return {
		"ultimate": "huntress_jungle_fury",
		"slots": [
			{"stages": [
				["huntress_animalistic"],
				["huntress_animalistic_ii"],
			]},
			{"stages": [
				["huntress_savage"],
				["huntress_savage_ii", "huntress_hunt"],
			]},
			{"stages": [
				["huntress_resuscitate"],
				["huntress_resuscitate_ii"],
			]},
			{"stages": [
				["huntress_feral_instincts"],
				["huntress_feral_instincts_ii", "huntress_swipe"],
			]},
			{"stages": [
				["huntress_onslaught"],
				["huntress_onslaught_ii"],
			]},
			{"stages": [
				["huntress_feral"],
				["huntress_feral_ii", "huntress_ferocious"],
			]},
			{"stages": [
				["huntress_predatory_advance"],
				["huntress_predatory_advance_ii", "huntress_jugular"],
			]},
			{"stages": [
				["huntress_maternal_bond"],
				["huntress_maternal_bond_ii"],
				["huntress_maternal_bond_iii"],
			]},
		],
	}
