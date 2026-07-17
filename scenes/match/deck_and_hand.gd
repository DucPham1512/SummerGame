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

## Public match events for the sync layer (MatchSync broadcasts these to the
## other client) and the match's phase logic. Slot is the fan index at the
## moment the card left the hand.
signal card_played(slot : int, card_id : String)
signal card_sold(slot : int, card_id : String)
signal cards_drawn(count : int)
## The deck ran dry and refilled from the discard pile (rules 1.2). Deck size
## is public info, so the mirror's counter — which only ever counts draws down —
## needs the new absolute pile size.
signal pile_refilled(pile_size : int)

## The player whose resources this hand belongs to (set by player.tscn); left
## null in the standalone harness, where board verbs fall back to warnings.
@export var player : Player

## The sibling skill board (set by player.tscn), so character cards can
## upgrade a kit slot; left null in the standalone harness / on the opponent
## side (which has no DeckAndHand at all — opponent cards resolve on that
## client's own instance).
@export var skill_layout : SkillLayout

## Injected by the match (MatchSync) to gate plays by turn phase; null in the
## standalone harness = every drop is legal.
var turn_manager : TurnManager

## The public discard pile, top of pile = last element. Ids only — the card
## nodes are freed; an empty deck rebuilds itself from these (shuffled).
var discard_pile : Array[String] = []

@onready var deck : Deck = $Deck
@onready var deck_pile : Panel = $Deck/Panel
@onready var pile_count : Label = $Deck/Label
@onready var hand : Control = $Hand
@onready var draw_button : Button = $DrawButton
@onready var play_area : Control = $PlayArea
@onready var sell_area : Control = $SellArea


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
			# Rules 1.2: an empty deck refills from the shuffled discard pile.
			if discard_pile.is_empty():
				# Nothing anywhere left to draw: skip the draw and play on. The
				# Discard Phase's hand limit keeps the whole deck from sitting
				# in one hand, so this should stay unreachable — say so rather
				# than failing silently if it ever isn't.
				push_warning("DeckAndHand: deck AND discard empty — draw skipped")
				pile_count.text = "empty"
				break
			_reshuffle_discard_into_deck()
			card = deck.draw()
			if card == null:
				break
		_update_pile_count()
		cards_drawn.emit(1)
		await _animate_draw(card)
	draw_button.disabled = false


## A character's default deck as a deck CODE (the "id,id,..." hash format
## Deck saves and loads): every common card plus the character's own cards,
## one copy each. This is the stand-in deck source until the deck-building /
## deck-selection feature exists — that feature will hand the match the
## player's saved code instead, and nothing downstream changes.
static func character_deck_code(char_id : String) -> String:
	var ids : Array[String] = []
	for id in GameDataLoader.card_repository:
		var entry : Dictionary = GameDataLoader.card_repository[id]
		if entry.get("type", "") == "common" or entry.get("character_id") == char_id:
			ids.append(id)
	ids.sort()
	return ",".join(ids)


## Match setup: replaces the debug deck built in _ready with the deck the
## combatant brings to this match, given as its deck code/hash. Clears any
## leftover discard state and shuffles the fresh pile.
func initialize_deck(deck_code : String) -> void:
	discard_pile.clear()
	deck.construct_from_hash(deck_code)
	deck.shuffle()
	_update_pile_count()


# Rules 1.2: a depleted deck continues from the shuffled discard pile. Only the
# PILE is refilled — rebuilding the deck from the discard code (as this used to)
# would replace the decklist itself with whatever happened to be discarded, on
# top of freeing the cards still in the player's hand (bug 64).
func _reshuffle_discard_into_deck() -> void:
	deck.refill_pile_from(discard_pile)
	print("[cards] deck depleted — reshuffled %d discarded card(s) into the pile"
			% discard_pile.size())
	discard_pile.clear()
	_update_pile_count()
	pile_refilled.emit(deck.draw_pile.size())


# Runs synchronously (up to the await) inside the card's drag_ended emit, so
# consume() reaches the card before it starts its glide-back tween.
func _on_card_released(card : Card, drop_global_position : Vector2) -> void:
	# Selling wins over playing when the zones overlap: check it first.
	if sell_area.get_global_rect().has_point(drop_global_position):
		_sell_card(card)
		return
	if not play_area.get_global_rect().has_point(drop_global_position):
		return   # not a play: the card glides back to the fan by itself
	# Phase gate: outside a legal window the card just glides back.
	if turn_manager != null and not turn_manager.can_play(player, card.phase, card.phase_subtype):
		return
	# Rules 1.3: playing an action card pays its CP cost; unaffordable cards
	# glide back.
	if player != null and player.cp < card.cp_cost:
		return
	var slot : int = hand.get_card_index(card)   # before the fan closes the gap
	card.consume()          # suppress the glide-back
	hand.play_card(card)    # out of the fan; this scene owns the node now
	card.hide()             # gone visually at once; freed after resolution
	if player != null and card.cp_cost > 0:
		player.update_player_cp(-card.cp_cost)
		print("[cards] paid %d CP for %s (cp now %d)" % [card.cp_cost, card.card_id, player.cp])
	card_played.emit(slot, card.card_id)
	# Static analysis sees the base (non-coroutine) resolve, but overrides may
	# await board verbs — the await keeps the card alive until they finish.
	@warning_ignore("redundant_await")
	await card.resolve(HandBoardContext.new(player, self))
	discard_pile.append(card.card_id)   # resolved actions land on the pile
	card.queue_free()


# Rules 1.3 / 1.8 — Sell a card: discard it from the hand, gain +1 CP.
func _sell_card(card : Card) -> void:
	if turn_manager != null and not turn_manager.can_sell(player):
		return   # outside a selling window: glide back
	var slot : int = hand.get_card_index(card)
	card.consume()
	hand.play_card(card)
	card.hide()
	discard_pile.append(card.card_id)
	if player != null:
		player.update_player_cp(1)
	card_sold.emit(slot, card.card_id)
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
	pile_count.text = str(deck.draw_pile.size())


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

	func deal_damage(amount : int, target = null) -> void:
		var who = target if target != null else caster
		if who == null:
			super.deal_damage(amount, target)   # harness warning
			return
		who.change_health(-amount)

	func heal(amount : int, target = null) -> void:
		var who = target if target != null else caster
		if who == null:
			super.heal(amount, target)   # harness warning
			return
		who.change_health(amount)

	func heal_companion(amount : int, target = null) -> void:
		var who = target if target != null else caster
		if who == null or who.companion == null:
			super.heal_companion(amount, target)   # harness warning
			return
		who.companion.heal(amount)

	func upgrade_skill(slot_index : int) -> void:
		if _deck_and_hand.skill_layout == null:
			super.upgrade_skill(slot_index)   # harness warning
			return
		_deck_and_hand.skill_layout.upgrade_slot(slot_index)
