class_name Deck
extends Node

# Deck building logic: open deck -> the saved deck code is parsed into
# deck_ids; modify deck = modify that array; save deck = reconstruct the code
# from it. shuffle() lays out the draw pile from the decklist, and draw() mints
# the card that comes off the top.
#
# The deck deals in card IDS, never in live Card nodes. It used to keep two
# arrays of the same instances (decklist + pile) and hand those instances out
# to the hand — but nothing ever removed a dealt card from the decklist, so the
# decklist held a reference to every card wherever it ended up. clear() then
# freed all of them: the ones already freed on play/sell (crashing on a
# previously freed instance) and the ones still sitting in the player's hand
# (destroying it). That detonated on the first reshuffle — exactly when the
# empty-deck rule was meant to save the match (bug 64). Ids can't alias
# anything, so nothing the deck deals can be freed behind its owner's back.

## The decklist: which cards this deck contains, as card ids.
var deck_ids : Array[String] = []
## The draw pile, as card ids. The LAST element is the top of the pile —
## higher index = drawn sooner.
var draw_pile : Array[String] = []


func add_card(card_id : String) -> void:
	deck_ids.append(card_id)


func remove_card(card_id : String) -> void:
	var index := deck_ids.find(card_id)
	if index == -1:
		return   # not in the deck; find() would return -1 and corrupt the array
	deck_ids.remove_at(index)


## Empties the deck and its pile. Frees nothing — the deck only ever held ids,
## and a card it dealt belongs to whoever it was dealt to.
func clear() -> void:
	deck_ids.clear()
	draw_pile.clear()


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
		deck_ids.append(id)
	return true


## Serialises the deck back to its code. Sorted, so the same multiset of cards
## always produces the same code regardless of current order.
func construct_hash() -> String:
	var ids := deck_ids.duplicate()
	ids.sort()
	return ",".join(ids)


## Builds the draw pile for a match: the full decklist in random order. The
## decklist itself is never reordered, so saving a deck mid-match stays stable.
func shuffle() -> void:
	draw_pile = deck_ids.duplicate()
	# NOTE: uses the global RNG. When netcode lands, shuffle with the synced
	# match RNG (or keep piles private and only replicate draw results).
	draw_pile.shuffle()


## Rules 1.2: a depleted deck continues from the shuffled discard pile. Only
## the PILE is rebuilt — deck_ids is the deck's identity and stays intact.
func refill_pile_from(ids : Array[String]) -> void:
	draw_pile = ids.duplicate()
	draw_pile.shuffle()


## Takes the top id off the pile (O(1) pop) and mints its card. Returns null
## when the pile is empty — the match decides what running out of cards means.
func draw() -> Card:
	if draw_pile.is_empty():
		return null
	return Card.create(draw_pile.pop_back())
