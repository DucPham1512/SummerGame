class_name StatusSpendPopup
extends PanelContainer

# The spend menu for status tokens. open(token, ctx) builds the option list
# from the token's spend_options(ctx): every option is listed, but the ones
# the moment can't satisfy (not enough stacks, no incoming damage, Nyra down)
# are dimmed and disabled. "split"-kind options open a second stage — a
# slider distributing incoming damage between the owner and their companion.
# Passive tokens (no options) never open the popup.

signal closed   # after any outcome: spent, cancelled, or dismissed

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
	if action.is_valid():
		action.call()
	close()


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
