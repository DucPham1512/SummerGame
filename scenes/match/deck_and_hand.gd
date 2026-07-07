extends Control

# Coordinates the deck -> hand -> play flow for one player's side: Draw deals
# the top card into the hand's fan (flip, reveal, fly); a card dragged out of
# the hand and released over the PlayArea is played — consumed out of the fan
# and its effect resolved against this player's board verbs.

const DECK_CODE := "getting_paid,double_up,getting_paid,double_up,getting_paid,double_up"

# Deal animation timings.
const FLIP_TIME := 0.18
const REVEAL_HOLD := 0.4
const FLY_TIME := 0.35

## The player whose resources this hand belongs to (set by player.tscn); left
## null in the standalone harness, where board verbs fall back to warnings.
@export var player : Player

@onready var deck : Deck = $Deck
@onready var deck_pile : Panel = $Deck/Panel
@onready var pile_count : Label = $Deck/Label
@onready var hand : Control = $Hand
@onready var draw_button : Button = $DrawButton
@onready var play_area : Control = $PlayArea


func _ready() -> void:
	hand.card_released.connect(_on_card_released)
	if not deck.construct_from_hash(DECK_CODE):
		pile_count.text = "load failed"
		return
	deck.shuffle()
	_update_pile_count()


func _on_draw() -> void:
	await draw_cards(1)


## Deals `amount` cards off the top of the pile into the hand, one at a time —
## every joining card shifts the fan slots, so a second in-flight card would
## aim at a stale slot. Doubles as the draw_cards board verb for card effects.
func draw_cards(amount : int) -> void:
	draw_button.disabled = true
	for i in amount:
		var card : Card = deck.draw()
		if card == null:
			pile_count.text = "empty"
			break
		_update_pile_count()
		await _animate_draw(card)
	draw_button.disabled = false


# Runs synchronously (up to the await) inside the card's drag_ended emit, so
# consume() reaches the card before it starts its glide-back tween.
func _on_card_released(card : Card, drop_global_position : Vector2) -> void:
	if not play_area.get_global_rect().has_point(drop_global_position):
		return   # not a play: the card glides back to the fan by itself
	card.consume()          # suppress the glide-back
	hand.play_card(card)    # out of the fan; this scene owns the node now
	card.hide()             # gone visually at once; freed after resolution
	# Static analysis sees the base (non-coroutine) resolve, but overrides may
	# await board verbs — the await keeps the card alive until they finish.
	@warning_ignore("redundant_await")
	await card.resolve(HandBoardContext.new(player, self))
	card.queue_free()


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


# Board verbs scoped to this side's player: just the subset the current cards
# need, wired to what exists today (player resources, this deck and hand).
# Anything else falls through to BoardContext's loud placeholder warnings.
# Superseded by the real Board context when the battle-phase system lands.
class HandBoardContext extends BoardContext:
	var _deck_and_hand

	func _init(p_caster, p_deck_and_hand) -> void:
		caster = p_caster
		_deck_and_hand = p_deck_and_hand

	func gain_cp(amount : int) -> void:
		if caster == null:
			super.gain_cp(amount)   # standalone harness: keep the warning
			return
		caster.update_player_cp(amount)

	func draw_cards(amount : int) -> void:
		await _deck_and_hand.draw_cards(amount)

	func apply_status(status_id : String, stacks : int = 1, target = null) -> void:
		# Verbs default to the caster unless a target is given (a Combatant —
		# either side carries real status tokens).
		var who = target if target != null else caster
		if who == null:
			super.apply_status(status_id, stacks, target)   # harness warning
			return
		who.apply_status(status_id, stacks)
