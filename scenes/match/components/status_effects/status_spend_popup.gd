class_name StatusSpendPopup
extends PanelContainer

# The spend menu for status tokens. open(token, ctx) builds the option list
# from the token's spend_options(ctx): every option is listed, but the ones
# the moment can't satisfy (not enough stacks, no incoming damage, Nyra down)
# are dimmed and disabled. "split"-kind options open a second stage — a
# slider distributing incoming damage between the owner and their companion.
# Passive tokens (no options) never open the popup.

signal closed   # after any outcome: spent, cancelled, or dismissed
## The huntress's defensive damage-allocation choice resolved (bug 60):
## how the incoming N splits between the player and the companion, and whether
## a Nyra's Bond was spent to do it.
signal transfer_decided(player_share : int, nyra_share : int, used_bond : bool)

const DISABLED_DIM := Color(0.5, 0.5, 0.5)
const MIN_WIDTH := 340.0


func _ready() -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, 0)
	hide()


## Opens the option list for a token. No-op for passive tokens.
func open(token : StatusEffect, ctx : BoardContext) -> void:
	var options := token.spend_options(ctx)
	if options.is_empty():
		return
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "%s  (x%d)" % [token.status_name, token.stacks]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	for option in options:
		var button := Button.new()
		button.text = option.get("label", "?")
		var enabled : bool = option.get("enabled", false)
		button.disabled = not enabled
		if not enabled:
			button.modulate = DISABLED_DIM
		button.pressed.connect(_on_option_pressed.bind(option))
		box.add_child(button)

	box.add_child(_make_cancel_button())
	show()


func _on_option_pressed(option : Dictionary) -> void:
	if option.get("kind", "") == "split":
		_open_split_stage(option)
		return
	var action : Callable = option.get("action", Callable())
	# Close BEFORE running it: an interactive spend (Tactical Advantage's die
	# re-roll and status transfer, bug 69) opens its own picker over the board,
	# and this panel would sit on top of it. The others are synchronous, so the
	# order makes no difference to them.
	close()
	if action.is_valid():
		action.call()


# Stage 2 for damage-split spends: one slider divides `damage` between the
# owner ("You") and the companion; confirming calls
# on_confirm(own_share, other_share).
func _open_split_stage(option : Dictionary) -> void:
	_clear()
	var damage : int = option.get("damage", 0)
	var other_name : String = option.get("split_with", "Nyra")
	var on_confirm : Callable = option.get("on_confirm", Callable())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Distribute %d incoming damage" % damage
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var readout := Label.new()
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(readout)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = damage
	slider.step = 1
	slider.value = damage / 2   # start at an even-ish split
	box.add_child(slider)

	var update_readout := func() -> void:
		var other_share := int(slider.value)
		readout.text = "You take %d   —   %s takes %d" % [damage - other_share, other_name, other_share]
	slider.value_changed.connect(func(_v : float) -> void: update_readout.call())
	update_readout.call()

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.pressed.connect(func() -> void:
		var other_share := int(slider.value)
		if on_confirm.is_valid():
			on_confirm.call(damage - other_share, other_share)
		close())
	box.add_child(confirm)

	box.add_child(_make_cancel_button())
	show()


# --- defensive damage transfer (bug 60) ------------------------------------------
# Kept companion-agnostic: the caller passes the raw numbers/name, not a
# CompanionNyra, so this stays a plain UI component.

## Asks who eats the N incoming damage. "<name> takes it" is offered only when
## the companion can survive the whole hit (N <= companion_hp); "Share (Bond)"
## appears only when a Nyra's Bond is held and opens the split slider (the
## companion's share capped at its HP). Resolves via transfer_decided. No
## cancel — the damage must land somewhere; "You take it" is the safe default.
func open_transfer(damage : int, companion_hp : int, companion_name : String, bond_held : bool) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Incoming %d damage — who takes it?" % damage
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var you := Button.new()
	you.text = "You take it (%d)" % damage
	you.pressed.connect(_decide_transfer.bind(damage, 0, false))
	box.add_child(you)

	var to_nyra := Button.new()
	to_nyra.text = "%s takes it (%d)" % [companion_name, damage]
	var nyra_can_eat := damage <= companion_hp
	to_nyra.disabled = not nyra_can_eat
	if not nyra_can_eat:
		to_nyra.modulate = DISABLED_DIM
	to_nyra.pressed.connect(_decide_transfer.bind(0, damage, false))
	box.add_child(to_nyra)

	if bond_held:
		var split := Button.new()
		split.text = "Share with %s (Bond)…" % companion_name
		split.pressed.connect(_open_transfer_split.bind(damage, companion_hp, companion_name))
		box.add_child(split)

	show()


func _open_transfer_split(damage : int, companion_hp : int, companion_name : String) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Distribute %d damage" % damage
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var readout := Label.new()
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(readout)

	var nyra_max := mini(damage, companion_hp)   # she can't take more than she has
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = nyra_max
	slider.step = 1
	slider.value = mini(damage / 2, nyra_max)
	box.add_child(slider)

	var update_readout := func() -> void:
		var nyra_share := int(slider.value)
		readout.text = "You take %d   —   %s takes %d" % [damage - nyra_share, companion_name, nyra_share]
	slider.value_changed.connect(func(_v : float) -> void: update_readout.call())
	update_readout.call()

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.pressed.connect(func() -> void:
		var nyra_share := int(slider.value)
		_decide_transfer(damage - nyra_share, nyra_share, true))
	box.add_child(confirm)

	# Back to the option list — not a dismiss, since the damage still has to land.
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(open_transfer.bind(damage, companion_hp, companion_name, true))
	box.add_child(back)
	show()


func _decide_transfer(player_share : int, nyra_share : int, used_bond : bool) -> void:
	hide()
	_clear()
	transfer_decided.emit(player_share, nyra_share, used_bond)


func close() -> void:
	hide()
	_clear()
	closed.emit()


func _make_cancel_button() -> Button:
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(close)
	return cancel


func _clear() -> void:
	for child in get_children():
		child.hide()          # gone this frame; freed at frame end
		child.queue_free()
