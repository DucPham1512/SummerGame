class_name Opponent
extends Combatant

# The replicated, PUBLIC-INFO-ONLY view of the other player: a mirrored fan of
# face-down placeholder cards (count only — never real hand contents), deck
# count, HP and CP. The on_opponent_* receivers below are this scene's entire
# input surface; the netcode layer (GDSync call_func) will invoke them later.
# Until then the debug Sim buttons drive them for manual testing.

# Reveal animation timings (mirrors the deal animation in deck_and_hand.gd).
const FLIP_TIME := 0.18
const FLY_TIME := 0.35
const REVEAL_HOLD := 0.8
const FADE_TIME := 0.25

const BASE_CARD := preload("res://scenes/match/components/cards/base_card.tscn")

## Placeholders until the match-start handshake replicates the real numbers.
@export var starting_deck_count : int = 6
@export var starting_hand_count : int = 3

var _deck_count : int

@onready var opp_hand : Control = $OpponentHand
@onready var pile_count : Label = $Deck/Label
@onready var hp_label : Label = $OpponentResourceContainer/HpContainer/HealthLabel
@onready var cp_label : Label = $OpponentResourceContainer/CpContainer/CpLabel
@onready var played_card_spot : Control = $PlayedCardSpot


func _ready() -> void:
	_deck_count = starting_deck_count
	pile_count.text = str(_deck_count)
	on_opponent_health(max_hp)
	on_opponent_cp(Util.one_v_one_starting_cp)
	for i in starting_hand_count:
		_add_hidden_card()


# --- receivers: the public sync surface (netcode calls these later) ---

## The opponent drew `count` cards: that many more face-down placeholders in
## the fan, that many fewer in the pile. Which cards stays unknown by design.
func on_opponent_drew(count : int = 1) -> void:
	for i in count:
		_deck_count = maxi(_deck_count - 1, 0)
		_add_hidden_card()
	pile_count.text = str(_deck_count)


## The opponent played the card at `slot` (index in their fan, 0 = leftmost),
## revealed as `card_id`: the placeholder swaps for the real card, which flips
## face-up out of its fan tilt, flies to the reveal spot, holds so the player
## reads it, then fades out.
func on_opponent_played(slot : int, card_id : String) -> void:
	var placeholder : Card = opp_hand.get_card_at(slot)
	if placeholder == null:
		push_warning("Opponent: play received for empty hand slot %d" % slot)
		return
	# Capture where the fan held it, then let the fan close the gap.
	var start_position := placeholder.global_position
	var start_rotation := placeholder.rotation_degrees
	opp_hand.remove_card(placeholder)

	var card := Card.create(card_id)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)   # parented here, not the hand: it's leaving the fan
	card.size = opp_hand.card_size
	card.pivot_offset = card.size * 0.5
	card.global_position = start_position
	card.rotation_degrees = start_rotation
	card.scale = Vector2(0.0, 1.0)   # edge-on: mid-turn from face-down

	var tween := create_tween()
	# The reveal: turn face-up with a little overshoot, shedding the fan tilt.
	tween.tween_property(card, "scale:x", 1.0, FLIP_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "rotation_degrees", 0.0, FLIP_TIME)
	# Fly to the reveal spot (the marker is the card's centre point).
	tween.tween_property(card, "global_position",
			played_card_spot.global_position - card.size * 0.5, FLY_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(REVEAL_HOLD)
	tween.tween_property(card, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	card.queue_free()
	# TODO(netcode/board): resolve the card's effect against the local mirror
	# of the match state once the real Board context exists.


## The opponent sold/discarded the card at `slot`: one placeholder leaves the
## fan unrevealed — which card it was stays private; only the count is public.
func on_opponent_sold(slot : int) -> void:
	var placeholder : Card = opp_hand.get_card_at(slot)
	if placeholder == null:
		# Out-of-range slot (shouldn't happen): trim the last card so at least
		# the public count stays right.
		placeholder = opp_hand.get_card_at(opp_hand.get_hand_size() - 1)
		if placeholder == null:
			return
	opp_hand.remove_card(placeholder)


## Absolute values, not deltas: replicated state should converge even if an
## event is missed.
func on_opponent_health(new_health : int) -> void:
	health = clampi(new_health, 0, max_hp)
	hp_label.text = "%d / %d" % [health, max_hp]
	health_changed.emit(health)


func on_opponent_cp(new_cp : int) -> void:
	cp = clampi(new_cp, 0, max_cp)
	cp_label.text = "%d / %d" % [cp, max_cp]
	cp_changed.emit(cp)


## The opponent's status tokens, as absolute replicated state: the complete
## set, not a delta. These are display-only over here (the owning client runs
## the real behaviour), so the set is rebuilt wholesale rather than merged —
## and the stack LIMITS travel too, since abilities raise them at runtime
## (Higher Ground's +1 TA limit) and apply_status would otherwise clamp a
## 6-stack Tactical Advantage back down to the data's base 5.
func on_opponent_statuses(ids : Array, stacks : Array, limits : Array) -> void:
	for status_id in status_effects.keys():
		var stale : StatusEffect = status_effects[status_id]
		status_effects.erase(status_id)
		status_removed.emit(stale)
	for i in ids.size():
		var token := StatusEffect.create(ids[i], 0)
		token.stack_limit = int(limits[i])
		token.add_stacks(int(stacks[i]))
		status_effects[ids[i]] = token
		status_applied.emit(token)


## The opponent's companion (Nyra) changed: absolute replicated hp + state.
## No-op when this opponent's character has no companion — the receiver must
## exist on both clients for the mirrored-path call to resolve.
func on_opponent_companion(hp : int, state : int) -> void:
	if companion == null:
		return
	companion.sync_state(hp, state as CompanionNyra.State)


## Match setup: the real size of the opponent's deck (its composition is
## public — every common card plus their character's cards — only the order
## is private).
func set_deck_count(count : int) -> void:
	_deck_count = count
	pile_count.text = str(_deck_count)


# A face-down stand-in: a bare base card with no id — it renders the template
# and, in this non-interactive hand, ignores the mouse entirely.
func _add_hidden_card() -> void:
	var card : Card = BASE_CARD.instantiate()
	opp_hand.add_card(card)


# --- debug simulation (until GDSync wires the receivers) ---

var _sim_ids : Array[String] = ["getting_paid", "double_up"]
var _sim_next : int = 0


func _on_sim_draw_pressed() -> void:
	on_opponent_drew()


func _on_sim_play_pressed() -> void:
	var hand_size : int = opp_hand.get_hand_size()
	if hand_size == 0:
		return
	on_opponent_played(randi() % hand_size, _sim_ids[_sim_next])
	_sim_next = (_sim_next + 1) % _sim_ids.size()


func _on_decrease_hp_pressed() -> void:
	on_opponent_health(health - 1)


func _on_increase_cp_pressed() -> void:
	on_opponent_cp(cp + 1)
