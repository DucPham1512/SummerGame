class_name Card
extends Control

# Shared card database, keyed by card id (populated by GameDataLoader).
var card_repo := GameDataLoader.card_repository

# Per-card description scenes live here as "<card_id>.tscn". Purely cosmetic:
# they present the card's text and never affect logic.
const DESCRIPTION_DIR := "res://scenes/match/components/cards/descriptions/"

# Behaviour scripts per card id: instancing base_card.tscn alone yields this
# base (visual-only) Card, so the factory swaps in the subclass that owns
# resolve(). Ids without an entry stay base — they render, but do nothing when
# played. Paths are load()ed lazily to avoid preload cycles (scene <-> script).
const BASE_CARD_SCENE := "res://scenes/match/components/cards/base_card.tscn"
const CARD_SCRIPTS := {
	"getting_paid": "res://scenes/match/components/cards/common/getting_paid.gd",
	"double_up": "res://scenes/match/components/cards/common/double_up.gd",
	"triple_up": "res://scenes/match/components/cards/common/triple_up.gd",
	"vegas_baby": "res://scenes/match/components/cards/common/vegas_baby.gd",
	"buh_bye": "res://scenes/match/components/cards/common/buh_bye.gd",
	"get_that_outa_here": "res://scenes/match/components/cards/common/get_that_outa_here.gd",
	"what_status_effects": "res://scenes/match/components/cards/common/what_status_effects.gd",
	"transference": "res://scenes/match/components/cards/common/transference.gd",
	"not_this_time": "res://scenes/match/components/cards/common/not_this_time.gd",
	"helping_hand": "res://scenes/match/components/cards/common/helping_hand.gd",
	"samesies": "res://scenes/match/components/cards/common/samesies.gd",
	"so_wild": "res://scenes/match/components/cards/common/so_wild.gd",
	"twice_as_wild": "res://scenes/match/components/cards/common/twice_as_wild.gd",
	"six_it": "res://scenes/match/components/cards/common/six_it.gd",
	"tip_it": "res://scenes/match/components/cards/common/tip_it.gd",
	"try_try_again": "res://scenes/match/components/cards/common/try_try_again.gd",
	"one_more_time": "res://scenes/match/components/cards/common/one_more_time.gd",
	"better_d": "res://scenes/match/components/cards/common/better_d.gd",
	"huntress_animalistic_ii": "res://scenes/match/components/cards/huntress/card_huntress_animalistic_ii.gd",
	"huntress_savage_ii": "res://scenes/match/components/cards/huntress/card_huntress_savage_ii.gd",
	"huntress_resuscitate_ii": "res://scenes/match/components/cards/huntress/card_huntress_resuscitate_ii.gd",
	"huntress_feral_instincts_ii": "res://scenes/match/components/cards/huntress/card_huntress_feral_instincts_ii.gd",
	"huntress_onslaught_ii": "res://scenes/match/components/cards/huntress/card_huntress_onslaught_ii.gd",
	"huntress_feral_ii": "res://scenes/match/components/cards/huntress/card_huntress_feral_ii.gd",
	"huntress_predatory_advance_ii": "res://scenes/match/components/cards/huntress/card_huntress_predatory_advance_ii.gd",
	"huntress_maternal_bond_ii": "res://scenes/match/components/cards/huntress/card_huntress_maternal_bond_ii.gd",
	"huntress_maternal_bond_iii": "res://scenes/match/components/cards/huntress/card_huntress_maternal_bond_iii.gd",
	"huntress_blood_bond": "res://scenes/match/components/cards/huntress/card_huntress_blood_bond.gd",
	"huntress_primal_roar": "res://scenes/match/components/cards/huntress/card_huntress_primal_roar.gd",
	"huntress_savage_slash": "res://scenes/match/components/cards/huntress/card_huntress_savage_slash.gd",
	"huntress_pounce": "res://scenes/match/components/cards/huntress/card_huntress_pounce.gd",
	"huntress_prowl": "res://scenes/match/components/cards/huntress/card_huntress_prowl.gd",
	"huntress_resilient": "res://scenes/match/components/cards/huntress/card_huntress_resilient.gd",
	"tactician_saber_strike_ii": "res://scenes/match/components/cards/tactician/card_tactician_saber_strike_ii.gd",
	"tactician_carpet_bomb_ii": "res://scenes/match/components/cards/tactician/card_tactician_carpet_bomb_ii.gd",
	"tactician_profiteer_ii": "res://scenes/match/components/cards/tactician/card_tactician_profiteer_ii.gd",
	"tactician_strategic_approach_ii": "res://scenes/match/components/cards/tactician/card_tactician_strategic_approach_ii.gd",
	"tactician_flank_ii": "res://scenes/match/components/cards/tactician/card_tactician_flank_ii.gd",
	"tactician_maneuver_ii": "res://scenes/match/components/cards/tactician/card_tactician_maneuver_ii.gd",
	"tactician_exploit_ii": "res://scenes/match/components/cards/tactician/card_tactician_exploit_ii.gd",
	"tactician_countermeasures_ii": "res://scenes/match/components/cards/tactician/card_tactician_countermeasures_ii.gd",
	"tactician_countermeasures_iii": "res://scenes/match/components/cards/tactician/card_tactician_countermeasures_iii.gd",
	"tactician_upper_hand": "res://scenes/match/components/cards/tactician/card_tactician_upper_hand.gd",
	"tactician_war_room": "res://scenes/match/components/cards/tactician/card_tactician_war_room.gd",
	"tactician_bunker_up": "res://scenes/match/components/cards/tactician/card_tactician_bunker_up.gd",
	"tactician_disengage": "res://scenes/match/components/cards/tactician/card_tactician_disengage.gd",
	"tactician_feigned_retreat": "res://scenes/match/components/cards/tactician/card_tactician_feigned_retreat.gd",
	"tactician_ambush": "res://scenes/match/components/cards/tactician/card_tactician_ambush.gd",
}


## Factory: builds a fully-initialised card for an id — instances the base card
## scene, attaches the behaviour script registered for the id, and loads its
## data. Use this when creating cards from code (deck, deals, tests).
static func create(id : String) -> Card:
	var card : Card = (load(BASE_CARD_SCENE) as PackedScene).instantiate()
	if CARD_SCRIPTS.has(id):
		# Swap before assigning card_id: set_script resets script variables,
		# and it does not re-run _init, so the id must be set explicitly.
		card.set_script(load(CARD_SCRIPTS[id]))
	card.card_id = id
	card.load_data()   # data fields usable immediately; the view refreshes on _ready
	return card

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
var player_hand : PackedScene
@export var hover_lift : float = 20.0

## Emitted when the player picks the card up / lets it go. The hand/match will
## use drag_ended's drop position to decide play vs. return; until drop zones
## exist, the card just glides back to its rest position on release.
signal drag_started(card : Card)
signal drag_ended(card : Card, drop_position : Vector2)

var _rest_position : Vector2      # where the card sits in the hand
var _rest_rotation : float = 0.0  # the card's fan tilt at rest (degrees)
var _dragging : bool = false
var _drag_offset : Vector2 = Vector2.ZERO
var _hover_tween : Tween
var _consumed : bool = false      # set by consume(): the drop played the card

func _process(_delta : float) -> void:
	# Only runs mid-drag (set_process toggles with the drag state).
	global_position = get_global_mouse_position() - _drag_offset
	# End the drag on release even if the cursor is no longer over the card.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()


func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag()
		accept_event()


func _ready() -> void:
	# Structural wiring first — it must happen whether or not data is set yet.
	set_process(false)   # _process only runs while dragging
	_rest_position = position
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
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


func _on_hover() -> void:
	if _dragging:
		return
	# Full-state targets: every motion tween aims at an absolute position AND
	# rotation, so any tween interrupting another still converges somewhere
	# correct (never a half-finished x or tilt from a killed return glide).
	var tween := _new_motion_tween().set_parallel(true)
	tween.tween_property(self, "position", _rest_position + Vector2(0, -hover_lift), 0.1)
	tween.tween_property(self, "rotation_degrees", _rest_rotation, 0.1)


func _on_unhover() -> void:
	if _dragging:
		return
	var tween := _new_motion_tween().set_parallel(true)
	tween.tween_property(self, "position", _rest_position, 0.1)
	tween.tween_property(self, "rotation_degrees", _rest_rotation, 0.1)


func _start_drag() -> void:
	_dragging = true
	_consumed = false
	# Kills any lift tween, and straightens the card out of its fan tilt while
	# it is carried (position itself is driven per-frame by _process).
	_new_motion_tween().tween_property(self, "rotation_degrees", 0.0, 0.1)
	_drag_offset = get_global_mouse_position() - global_position
	move_to_front()           # draw above the other cards while held
	set_process(true)
	drag_started.emit(self)


func _end_drag() -> void:
	_dragging = false
	set_process(false)
	drag_ended.emit(self, get_global_mouse_position())
	# A drag_ended listener that played the card calls consume() during the
	# emit above — the card is leaving the hand, so skip the return glide.
	if _consumed:
		return
	# Not played: glide back to the rest spot in the hand, picking the fan
	# tilt back up on the way.
	var tween := _new_motion_tween().set_parallel(true)
	tween.tween_property(self, "position", _rest_position, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", _rest_rotation, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A drag_ended listener calls this — synchronously, during the emit — when the
## drop plays the card, so _end_drag skips the glide back into the hand.
func consume() -> void:
	_consumed = true


## The hand calls this after laying the card out, so hover lifts and drag
## returns aim at the card's real resting spot — including its fan tilt.
func set_rest_position(pos : Vector2, rot_degrees : float = 0.0) -> void:
	_rest_position = pos
	_rest_rotation = rot_degrees


# One tween at a time for card motion, so lift/return tweens never stack.
func _new_motion_tween() -> Tween:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	return _hover_tween

## Override per card to run its effect by composing the context's board verbs.
## The base is a no-op. This is the imperative counterpart to a skill's declarative
## SkillEffect: a card orchestrates verbs (which may await rolls/choices) rather
## than returning a fixed data struct, since card effects aren't standardizable.
func resolve(_ctx: BoardContext) -> void:
	pass


## What a card needs on the table to do anything (bug 58). The play flow refuses
## a card whose requirement isn't met — so it never spends CP on a no-op:
## OWN needs a live roll of ours to modify, OPPONENT a spectated opponent roll.
enum RollNeed { NONE, OWN, OPPONENT }

func roll_need() -> RollNeed:
	return RollNeed.NONE


## Whether this card improves an attack the player has ALREADY declared, rather
## than doing something on its own (Pounce, Prowl). Such a card is only legal once
## an attack ability has been chosen, and its effects ride that attack.
func is_attack_modifier() -> bool:
	return false


## The CP actually charged to play this card, given the caster's own skill layout.
## Flat for ordinary cards; a tier-III upgrade refunds its predecessor once that
## predecessor is in play (bug 80). A null layout (the harness) keeps the printed
## cost.
func effective_cp_cost(_skill_layout) -> int:
	return cp_cost


## Whether the caster's skill layout permits this card right now. Only upgrade
## cards ever say no — when their slot has already reached the tier they grant, so
## an upgrade can't be re-bought and II can't be played once III is in play
## (bug 80). Ordinary cards, and the null-layout harness, are always allowed.
func layout_allows_play(_skill_layout) -> bool:
	return true


# --- shared by the tiered-upgrade cards (bug 80) -----------------------------------

## Cost for a staged upgrade that refunds its predecessor once that predecessor is
## in play. The slot having advanced past its base stage IS "the previous tier has
## been played". The refund is the predecessor's own price, read from data rather
## than hardcoded; never below 0.
func _tiered_upgrade_cost(skill_layout, slot_index : int, prev_card_id : String) -> int:
	if skill_layout == null or skill_layout.stage_of(slot_index) < 1:
		return cp_cost
	var prev_cost : int = int(card_repo.get(prev_card_id, {}).get("cp_cost", 0))
	return maxi(cp_cost - prev_cost, 0)


## Whether an upgrade to `target_stage` would still advance slot `slot_index` —
## false once the slot has already reached (or passed) that tier.
func _upgrade_available(skill_layout, slot_index : int, target_stage : int) -> bool:
	return skill_layout == null or skill_layout.stage_of(slot_index) < target_stage
