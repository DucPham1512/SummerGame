class_name Skill
extends Control

# Shared ability database, keyed by skill id (populated by GameDataLoader).
var skill_repo := GameDataLoader.skill_repository

# Per-skill description scenes live here as "<skill_id>.tscn". Purely cosmetic:
# they present the skill's text/symbols and never affect logic.
const DESCRIPTION_DIR := "res://scenes/match/components/skills/descriptions/"

var skill_id : String
var char_id : String
var skill_name : String
var type : String
var dice_cost : Dictionary
var description : String

@onready var skill_name_label : Label = get_node_or_null("Panel/SkillName")
@onready var description_slot : TextureRect = get_node_or_null("Panel/SkillDescription")

var _description_instance : Node = null

signal effect(damage : int, status_effect : Dictionary, target : Player)

func _ready() -> void:
	# skill_id must be assigned before this node enters the tree, since _ready
	# loads the data. If it isn't set yet, stay quiet and let a later assignment
	# call load_data() explicitly.
	if skill_id.is_empty():
		return
	load_data()


## Populates every field from the repository entry for `skill_id`. Returns true
## on success, or false (and pushes an error) if no ability exists for that id.
func load_data() -> bool:
	var skill : Dictionary = skill_repo.get(skill_id, {})
	if skill.is_empty():
		push_error("Skill: no ability found for id '%s'" % skill_id)
		return false

	char_id = skill.get("character_id", "")
	skill_name = skill.get("name", "")
	type = skill.get("type", "")
	dice_cost = skill.get("dice_cost", {})
	description = skill.get("description", "")
	_refresh_view()
	return true


# Updates the cosmetic presentation from the loaded data. Safe to call before the
# node is in the tree — it no-ops until the child nodes exist (then _ready reruns
# load_data). Kept entirely separate from logic.
func _refresh_view() -> void:
	if not is_instance_valid(skill_name_label):
		return
	skill_name_label.text = skill_name
	_load_description_scene()


# Swaps in the description scene for the current skill_id, replacing any previous.
func _load_description_scene() -> void:
	if is_instance_valid(_description_instance):
		_description_instance.queue_free()
		_description_instance = null

	var path := DESCRIPTION_DIR + skill_id + ".tscn"
	if not ResourceLoader.exists(path):
		push_warning("Skill: no description scene for '%s' (expected %s)" % [skill_id, path])
		return

	var packed : PackedScene = load(path)
	_description_instance = packed.instantiate()
	description_slot.add_child(_description_instance)


## Override per skill to compute the resolved effect. The base returns an empty
## (no-op) effect. Resolution is via the return value — a combat resolver applies
## the SkillEffect to game state. (The `effect` signal, if used, is cosmetic only.)
func activate() -> SkillEffect:
	return SkillEffect.new()
