class_name Skill
extends Control

# Shared ability database, keyed by skill id (populated by GameDataLoader).
var skill_repo := GameDataLoader.skill_repository

# Per-skill description scenes live here as "<skill_id>.tscn". Purely cosmetic:
# they present the skill's text/symbols and never affect logic. Skills with a
# behaviour script may instead keep the scene next to that script (see
# _load_description_scene's fallback).
const DESCRIPTION_DIR := "res://scenes/match/components/skills/descriptions/"

# Behaviour scripts per skill id, mirroring Card.CARD_SCRIPTS: instancing
# base_skill.tscn alone yields this base (visual-only) Skill, so the factory
# swaps in the subclass that owns activate(). Ids without an entry stay base —
# they render their data but resolve to a no-op effect. Paths are load()ed
# lazily to avoid preload cycles (scene <-> script).
const BASE_SKILL_SCENE := "res://scenes/match/components/skills/base_skill.tscn"
const SKILL_SCRIPTS := {
	"huntress_jungle_fury": "res://scenes/match/components/skills/Huntress/ultimate/huntress_jungle_fury.gd",
	"tactician_higher_ground": "res://scenes/match/components/skills/Tactician/ultimate/tactician_higher_ground.gd",
}


## Factory: builds a fully-initialised skill node for an id — instances the
## base skill scene, attaches the behaviour script registered for the id, and
## loads its data. Use this when creating skills from code (the layouts).
static func create(id : String) -> Skill:
	var skill : Skill = (load(BASE_SKILL_SCENE) as PackedScene).instantiate()
	if SKILL_SCRIPTS.has(id):
		# Swap before assigning skill_id: set_script resets script variables,
		# and it does not re-run _init, so the id must be set explicitly.
		skill.set_script(load(SKILL_SCRIPTS[id]))
	skill.skill_id = id
	skill.load_data()   # data fields usable immediately; the view refreshes on _ready
	return skill

var skill_id : String
var char_id : String
var skill_name : String
var type : String
var dice_cost : Dictionary
var description : String

@onready var skill_name_label : Label = get_node_or_null("Panel/SkillName")
@onready var description_slot : TextureRect = get_node_or_null("Panel/SkillDescription")

var _description_instance : Node = null

# Cosmetic-only by design (see activate below); nothing emits it yet.
@warning_ignore("unused_signal")
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

	# Two homes for description scenes: the shared descriptions/ folder, or —
	# for skills with a behaviour script — right next to that script (e.g.
	# Tactician/ultimate/tactician_higher_ground.tscn).
	var path := DESCRIPTION_DIR + skill_id + ".tscn"
	if not ResourceLoader.exists(path) and SKILL_SCRIPTS.has(skill_id):
		path = SKILL_SCRIPTS[skill_id].get_base_dir() + "/" + skill_id + ".tscn"
	if not ResourceLoader.exists(path):
		push_warning("Skill: no description scene for '%s' (expected %s)" % [skill_id, path])
		return

	var packed : PackedScene = load(path)
	_description_instance = packed.instantiate()
	description_slot.add_child(_description_instance)


## Whether an offensive roll can pay this ability's dice cost. `symbol_counts`
## is {symbol: count} tallied from the roll through the character's die faces;
## `values` are the raw face values (1-6) — pattern costs are value-based.
## Defensive-roll abilities never activate from an offensive roll: they run
## their own roll when defending.
func can_activate_with(symbol_counts : Dictionary, values : Array[int]) -> bool:
	match dice_cost.get("type", ""):
		"symbols", "symbols_min":
			# symbols = exact-count costs, symbols_min = scaling minimums;
			# both are payable once every required symbol reaches its count.
			var required : Dictionary = dice_cost.get("symbols", {})
			for symbol in required:
				if symbol_counts.get(symbol, 0) < int(required[symbol]):
					return false
			return true
		"pattern":
			var length := 4 if dice_cost.get("pattern", "") == "small_straight" else 5
			return _has_straight(values, length)
		"defensive_roll":
			return false
	return false


# A run of `length` consecutive face values anywhere in the roll.
static func _has_straight(values : Array[int], length : int) -> bool:
	var seen := {}
	for v in values:
		seen[v] = true
	var run := 0
	for v in range(1, 7):
		run = run + 1 if seen.has(v) else 0
		if run >= length:
			return true
	return false


## Override per skill to compute the resolved effect. The base returns an empty
## (no-op) effect. Resolution is via the return value — a combat resolver applies
## the SkillEffect to game state. (The `effect` signal, if used, is cosmetic only.)
func activate() -> SkillEffect:
	return SkillEffect.new()
