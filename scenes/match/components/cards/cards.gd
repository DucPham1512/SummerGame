class_name Card
extends Control

# Shared card database, keyed by card id (populated by GameDataLoader).
var card_repo := GameDataLoader.card_repository

# Per-card description scenes live here as "<card_id>.tscn". Purely cosmetic:
# they present the card's text and never affect logic.
const DESCRIPTION_DIR := "res://scenes/match/components/cards/descriptions/"

var card_id : String
var char_id : String         # "" for common cards
var card_name : String
var type : String            # "common" | "character"
var phase : String           # roll_phase | instant_action | main_phase
var phase_subtype : String   # offensive | defensive | any ("" unless roll_phase)
var cp_cost : int
var description : String

@onready var card_name_label : Label = get_node_or_null("Panel/CardName")
@onready var cp_cost_label : Label = get_node_or_null("Panel/CpCost")
@onready var description_slot : TextureRect = get_node_or_null("Panel/CardDescription")

var _description_instance : Node = null


func _ready() -> void:
	# card_id must be assigned before this node enters the tree, since _ready
	# loads the data. If it isn't set yet, stay quiet and let a later assignment
	# call load_data() explicitly.
	if card_id.is_empty():
		return
	load_data()


## Populates every field from the repository entry for `card_id`. Returns true on
## success, or false (and pushes an error) if no card exists for that id.
func load_data() -> bool:
	var card : Dictionary = card_repo.get(card_id, {})
	if card.is_empty():
		push_error("Card: no card found for id '%s'" % card_id)
		return false

	char_id = _str_or_empty(card.get("character_id"))   # null for common cards
	card_name = card.get("name", "")
	type = card.get("type", "")
	phase = card.get("phase", "")
	phase_subtype = _str_or_empty(card.get("phase_subtype"))   # null unless roll_phase
	cp_cost = int(card.get("cp_cost", 0))
	description = card.get("description", "")
	_refresh_view()
	return true


func _str_or_empty(value) -> String:
	return value if value != null else ""


# Updates the cosmetic presentation from the loaded data. Safe to call before the
# node is in the tree — it no-ops until the child nodes exist (then _ready reruns
# load_data). Kept entirely separate from logic.
func _refresh_view() -> void:
	if not is_instance_valid(card_name_label):
		return
	card_name_label.text = card_name
	if is_instance_valid(cp_cost_label):
		cp_cost_label.text = str(cp_cost)
	_load_description_scene()


# Swaps in the description scene for the current card_id, replacing any previous.
func _load_description_scene() -> void:
	if is_instance_valid(_description_instance):
		_description_instance.queue_free()
		_description_instance = null

	var path := DESCRIPTION_DIR + card_id + ".tscn"
	if not ResourceLoader.exists(path):
		push_warning("Card: no description scene for '%s' (expected %s)" % [card_id, path])
		return

	var packed : PackedScene = load(path)
	_description_instance = packed.instantiate()
	description_slot.add_child(_description_instance)


## Override per card to run its effect by composing the context's board verbs.
## The base is a no-op. This is the imperative counterpart to a skill's declarative
## SkillEffect: a card orchestrates verbs (which may await rolls/choices) rather
## than returning a fixed data struct, since card effects aren't standardizable.
func resolve(ctx: CardContext) -> void:
	pass
