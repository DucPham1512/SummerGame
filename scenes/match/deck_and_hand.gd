extends Control

# Validates the deck -> hand deal flow: the deck scene sits as a pile on screen;
# each Draw pops the top card, turns it face-up on the pile (reveal), holds a
# beat so the player reads it, then flies it into its slot in the hand's fan.
# Manual-inspection harness; nothing here is game logic.

const DECK_CODE := "getting_paid,double_up,getting_paid,double_up,getting_paid,double_up"

# Deal animation timings.
const FLIP_TIME := 0.18
const REVEAL_HOLD := 0.4
const FLY_TIME := 0.35

@onready var deck : Deck = $Deck
@onready var deck_pile : Panel = $Deck/Panel
@onready var pile_count : Label = $Deck/Label
@onready var hand : Control = $Hand
@onready var draw_button : Button = $DrawButton


func _ready() -> void:
	if not deck.construct_from_hash(DECK_CODE):
		pile_count.text = "load failed"
		return
	deck.shuffle()
	_update_pile_count()


func _on_draw() -> void:
	var card : Card = deck.draw()
	if card == null:
		pile_count.text = "empty"
		return
	# One deal at a time: every joining card shifts the fan slots, so a second
	# in-flight card would aim at a stale slot.
	draw_button.disabled = true
	_update_pile_count()
	await _animate_draw(card)
	draw_button.disabled = false


# The deal: join the fan first (so the layout assigns the final slot), then
# visually restart from the pile edge-on, turn face-up, hold, and fly home.
func _animate_draw(card : Card) -> void:
	hand.add_card(card)                        # into the tree; fan slot assigned
	var slot_pos : Vector2 = card.position     # capture the slot the fan gave it
	var slot_rot : float = card.rotation_degrees

	card.mouse_filter = Control.MOUSE_FILTER_IGNORE   # no hover/drag mid-deal
	card.pivot_offset = card.size * 0.5               # turn around the centre
	card.rotation_degrees = 0.0
	card.scale = Vector2(0.0, 1.0)                    # edge-on: mid-turn
	# Centre the card on the pile (global coords; the card lives under Hand).
	card.global_position = deck_pile.global_position + deck_pile.size * 0.5 - card.size * 0.5

	var tween := create_tween()
	# The turn: edge-on -> face-up, with a little overshoot.
	tween.tween_property(card, "scale:x", 1.0, FLIP_TIME)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Let the player read what was drawn.
	tween.tween_interval(REVEAL_HOLD)
	# Fly into the fan slot, picking up the fan tilt on the way.
	tween.tween_property(card, "position", slot_pos, FLY_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(card, "rotation_degrees", slot_rot, FLY_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	# Hand the card back to normal hand behaviour (hover pivot, input).
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
	card.mouse_filter = Control.MOUSE_FILTER_STOP


func _update_pile_count() -> void:
	pile_count.text = str(deck.shuffled_deck.size())


func _on_remove() -> void:
	pass # Replace with function body.


func _on_card_remove() -> void:
	if hand.get_hand_size() <= 0:
		pass
	else:
		hand.remove_card(hand._cards[0])
