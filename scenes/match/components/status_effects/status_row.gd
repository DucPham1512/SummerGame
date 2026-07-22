class_name StatusRow
extends HBoxContainer

# One side's status tokens, as a row of pills: icon + stack count, name and
# description on hover. Statuses are public info, so this serves either side —
# the local Player or the replicated Opponent view (both are Combatants
# carrying real tokens and emitting the same three signals).
#
# Display only: it never mutates a token, it just re-reads the combatant's
# status_effects whenever they change.

const PILL_SIZE := Vector2(64, 44)
const ICON_SIZE := Vector2(32, 32)

## The side whose tokens this row shows (set by player.tscn / opponent.tscn).
@export var combatant : Combatant
## When true the pills are live buttons that emit token_pressed on click — the
## local player spending their own tokens. The replicated opponent row leaves
## this false: their tokens are display-only.
@export var interactive : bool = false

## A live pill was clicked (interactive rows only).
signal token_pressed(token : StatusEffect)


func _ready() -> void:
	if combatant == null:
		return
	combatant.status_applied.connect(_on_status_signal)
	combatant.status_changed.connect(_on_status_signal)
	combatant.status_removed.connect(_on_status_signal)
	_rebuild()


func _on_status_signal(_token : StatusEffect) -> void:
	_rebuild()


func _rebuild() -> void:
	# remove_child before queue_free: freeing alone is deferred, so two
	# rebuilds in one frame would stack the old pills under the new ones.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for token in combatant.status_effects.values():
		add_child(_build_pill(token))


func _build_pill(token : StatusEffect) -> Button:
	var pill := Button.new()
	# The suffix carries state the stack count can't show — an armed Protect
	# would otherwise look exactly like an idle one.
	pill.text = "x%d%s" % [token.stacks, token.pill_suffix()]
	var icon : Texture2D = token.picture_panel
	if icon == null:
		# Art pending for most statuses — a placeholder still reads as a token.
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = ICON_SIZE
		icon = placeholder
	pill.icon = icon
	pill.expand_icon = true
	pill.disabled = not interactive   # display-only rows leave the pill inert
	if interactive:
		pill.pressed.connect(func() -> void: token_pressed.emit(token))
	pill.custom_minimum_size = PILL_SIZE
	pill.tooltip_text = "%s\n%s" % [token.status_name, token.description]
	return pill
