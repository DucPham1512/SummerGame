extends Control

# Fans the hand's cards along the bottom of the hand area: overlapping,
# tilted away from the centre, with the edge cards sinking slightly (arc).
# Purely presentational — play/drop logic comes later via the cards'
# drag_started / drag_ended signals.

## Placeholder deal until the deck exists: id per card child, in order.
@export var placeholder_ids : Array[String] = ["getting_paid", "double_up", "getting_paid", "double_up"]
@export var card_size := Vector2(180, 250)
## Centre-to-centre distance; smaller than card_size.x = overlap.
@export var card_spacing : float = 130.0
## Fan tilt added per card in hand: the outermost tilt is
## angle_per_card * (n-1) / 2, so small hands stay nearly straight.
@export var angle_per_card : float = 4.0
## Cap for the outermost card's tilt, in degrees, once the hand grows large.
@export var max_fan_angle : float = 12.0
## How far the edge cards sink below the centre card (parabolic arc) at full
## fan; scales down together with the tilt for small hands.
@export var arc_height : float = 25.0
@export var bottom_margin : float = 20.0

const BASE_CARD := preload("res://scenes/match/components/cards/base_card.tscn")

var _cards : Array[Card] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # hover/clicks belong to the cards
	for child in get_children():
		if child is Card:
			_cards.append(child)
	for i in _cards.size():
		if i < placeholder_ids.size():
			_cards[i].card_id = placeholder_ids[i]
			_cards[i].load_data()
	_layout()
	resized.connect(_layout)   # keep the fan centred when the window changes


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("Left click")
		else:
			print("Left click release")


func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	# Fan grows with hand size: outermost tilt in degrees, capped. The arc
	# droop scales by the same ratio so sparse hands sit flat, not saggy.
	var outer_angle := minf(angle_per_card * float(n - 1) * 0.5, max_fan_angle)
	var fan_scale := 0.0 if max_fan_angle <= 0.0 else outer_angle / max_fan_angle
	for i in n:
		var card := _cards[i]
		# -0.5 (leftmost) .. 0.5 (rightmost); the centre card is 0.
		var spread := 0.0 if n == 1 else (float(i) / float(n - 1)) - 0.5

		# The layout owns placement from here on: drop the editor anchors and
		# give every card the same explicit size.
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.size = card_size
		# Rotate around the bottom-centre so the fan splays like held cards.
		card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)

		var x := size.x * 0.5 + spread * card_spacing * float(n - 1) - card_size.x * 0.5
		var y := size.y - card_size.y - bottom_margin \
				+ arc_height * fan_scale * pow(spread * 2.0, 2.0)
		card.position = Vector2(x, y)
		card.rotation_degrees = spread * 2.0 * outer_angle
		# Anchor the card's hover-lift / drag-return to its spot in the fan,
		# including the tilt it should pick back up after a drag.
		card.set_rest_position(card.position, card.rotation_degrees)

## Takes ownership of a card node: into the tree, into the fan.
func add_card(card : Card) -> void:
	_cards.append(card)
	add_child(card)
	_layout()


## Removes a card from the hand, frees it, and re-fans the rest.
func remove_card(card : Card) -> void:
	if not _cards.has(card):
		return
	_cards.erase(card)
	card.queue_free()
	_layout()


func _on_add_card_pressed() -> void:
	var new_card : Card = BASE_CARD.instantiate()
	# Cycle the placeholder ids for variety; set before add_child so the
	# card's _ready loads its data.
	if not placeholder_ids.is_empty():
		new_card.card_id = placeholder_ids[_cards.size() % placeholder_ids.size()]
	add_card(new_card)


func _on_remove_card_pressed() -> void:
	if _cards.is_empty():
		return
	remove_card(_cards[0])
