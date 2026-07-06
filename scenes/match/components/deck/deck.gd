class_name Deck
extends Node

# Deck building logic: open deck -> the saved deck code is parsed into
# deck_cards as real, forward-loaded Card instances (ready to deal); modify
# deck = modify the array; save deck = reconstruct the code from the array.
#
# The card instances live OUTSIDE the scene tree until dealt (e.g. into the
# hand) — they are not children of this node, so clear() must free them.

var deck_cards : Array[Card] = []
var shuffled_deck : Array[Card] = []


func add_card(card : Card) -> void:
	deck_cards.append(card)


func remove_card(card : Card) -> void:
	var index := deck_cards.find(card)
	if index == -1:
		return   # not in the deck; find() would return -1 and corrupt the array
	deck_cards.remove_at(index)


## Frees every card instance and empties the deck (draw pile included — it
## holds the same instances, which were just freed).
func clear() -> void:
	for card in deck_cards:
		card.queue_free()
	deck_cards.clear()
	shuffled_deck.clear()


## Rebuilds the deck from a deck code ("id,id,..."), replacing the current
## contents. Returns false (and leaves the deck empty) on an unknown card id.
func construct_from_hash(code : String) -> bool:
	clear()
	if code.is_empty():
		return true
	var ids := code.split(",")
	# Validate the whole code before building anything.
	for id in ids:
		if not GameDataLoader.card_repository.has(id):
			push_error("Deck: unknown card id '%s' in deck code" % id)
			return false
	for id in ids:
		deck_cards.append(Card.create(id))
	return true


## Serialises the deck back to its code. Sorted, so the same multiset of cards
## always produces the same code regardless of current order.
func construct_hash() -> String:
	var ids : Array[String] = []
	for card in deck_cards:
		ids.append(card.card_id)
	ids.sort()
	return ",".join(ids)

## Builds the draw pile for a match: the full decklist in random order. The
## LAST element is the top of the pile — higher index = drawn sooner.
## (Shares the same Card instances as deck_cards; the decklist itself is
## never reordered, so saving a deck mid-match stays stable.)
func shuffle() -> void:
	shuffled_deck = deck_cards.duplicate()
	# NOTE: uses the global RNG. When netcode lands, shuffle with the synced
	# match RNG (or keep piles private and only replicate draw results).
	shuffled_deck.shuffle()


## Draws the top card of the pile (highest index, O(1) pop). Returns null when
## the pile is empty — the match decides what running out of cards means.
func draw() -> Card:
	if shuffled_deck.is_empty():
		return null
	return shuffled_deck.pop_back()
