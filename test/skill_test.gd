extends Control

# Validates the skill template proof end-to-end for the two implemented ultimates:
#   - data loads from GameDataLoader (name / char / type / cost / description)
#   - activate() returns the expected SkillEffect
#   - the dice-cost container renders the correct face sprites
#   - the per-skill description scene instantiates
# Purely a manual-inspection harness; nothing here is game logic.

const DICE_COST_CONTAINER := preload("res://scenes/match/components/skills/dice_cost_container.gd")
const DESCRIPTION_DIR := "res://scenes/match/components/skills/descriptions/"

@onready var content: VBoxContainer = $Scroll/Content


func _ready() -> void:
	_build_section(TacticianHigherGround.new())
	_build_section(HuntressJungleFury.new())


func _build_section(skill: Skill) -> void:
	add_child(skill)   # entering the tree triggers the base _ready() -> load_data()

	# 1) Data + activate() report.
	var report := RichTextLabel.new()
	report.bbcode_enabled = true
	report.fit_content = true
	report.custom_minimum_size = Vector2(640, 0)
	report.text = _describe(skill)
	content.add_child(report)

	# 2) Dice-cost faces built from the skill's cost data.
	var cost := HBoxContainer.new()
	cost.set_script(DICE_COST_CONTAINER)
	content.add_child(cost)
	cost.set_cost(skill.dice_cost, skill.char_id)

	# 3) The per-skill description scene (cosmetic).
	var desc_path := DESCRIPTION_DIR + skill.skill_id + ".tscn"
	if ResourceLoader.exists(desc_path):
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(640, 130)
		holder.add_child(load(desc_path).instantiate())
		content.add_child(holder)

	content.add_child(HSeparator.new())


func _describe(skill: Skill) -> String:
	var e := skill.activate()
	var t := ""
	t += "[b]%s[/b]   ( %s / %s )\n" % [skill.skill_name, skill.char_id, skill.type]
	t += "dice_cost: %s\n" % [skill.dice_cost]
	t += "description: %s\n" % skill.description
	t += "[b]activate() -> SkillEffect[/b]\n"
	t += "    damage: %d\n" % e.damage
	t += "    inflict_on_opponent: %s\n" % _statuses(e.inflict_on_opponent)
	t += "    grant_to_self: %s\n" % _statuses(e.grant_to_self)
	t += "    stack_limit_delta: %s\n" % [e.stack_limit_delta]
	t += "    max_out_self: %s\n" % [e.max_out_self]
	return t


func _statuses(arr: Array) -> String:
	if arr.is_empty():
		return "-"
	var parts: Array[String] = []
	for s in arr:
		parts.append("%s x%d" % [s.id, s.stacks])
	return ", ".join(parts)
