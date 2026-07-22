class_name Protect
extends StatusEffect

# Status effect — "Protect" (positive, spendable): spend at any time to prevent
# 1/2 of incoming damage (rounded up).
#
# "At any time" means there is no defensive window handing this token a damage
# number to act on, so it works as an ARMED FLAG (bug 79): the player arms it
# whenever they like, and the next damage that lands on them is halved. The
# stack is paid at that moment, not when armed — arming with nothing incoming
# must never waste the token.


## Set by the spend option; consumed by the next damage this token's owner takes.
var armed : bool = false


func is_positive() -> bool:
	return true


func can_spend() -> bool:
	return stacks > 0


## Arms the token. (Was: prevent damage through a board verb that no context
## ever implemented — the second half of bug 79.)
func spend(_ctx : BoardContext) -> bool:
	if not can_spend() or armed:
		return false
	_arm()
	return true


func spend_options(_ctx : BoardContext) -> Array[Dictionary]:
	if armed:
		return [
			{
				"label": "Armed — cancel",
				"enabled": true,
				"action": _disarm,
			},
		]
	return [
		{
			# Gated on holding a stack and nothing else. Requiring incoming
			# damage here was what made this permanently unselectable: the only
			# caller opens the popup with incoming_damage hard-set to 0.
			"label": "Prevent half of the next incoming damage (rounded up)",
			"enabled": can_spend(),
			"action": _arm,
		},
	]


## Halves the hit and pays for itself. Damage taken is `amount - ceil(amount/2)`,
## so half is prevented rounding UP: 6 -> 3 taken, 5 -> 2, 1 -> 0.
func mitigate_damage(amount : int) -> int:
	if not armed or amount <= 0 or not can_spend():
		return amount
	armed = false
	remove_stacks(1)   # announces itself, and retires the token (bug 81)
	return amount - ceili(amount / 2.0)


func pill_suffix() -> String:
	return " ●" if armed else ""


func _arm() -> void:
	armed = true
	_announce_armed()


func _disarm() -> void:
	armed = false
	_announce_armed()


# Arming moves no stacks, so nothing else would tell the token row to redraw and
# the armed marker would not appear until some unrelated status event happened
# (bug 81's lesson, in the one shape that fix does not cover).
func _announce_armed() -> void:
	if is_instance_valid(owner_combatant):
		owner_combatant.notify_status_changed(self)
