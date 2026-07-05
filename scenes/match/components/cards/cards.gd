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
	# No drop zones yet: glide back to the rest spot in the hand, picking the
	# fan tilt back up on the way. The match will later listen to drag_ended
	# and play/consume the card instead.
	var tween := _new_motion_tween().set_parallel(true)
	tween.tween_property(self, "position", _rest_position, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", _rest_rotation, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
