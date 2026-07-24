class_name DamageCounter
extends Label

# PBI 89 — a central readout of the CURRENT attack this turn: the damage the
# declared/pending attack will deal. It frames that number by whose turn it is —
# "Damage dealt" while the local player is attacking, "Incoming damage" while the
# opponent is (the attack is then aimed at us). match.gd owns the attack (it mutates
# _pending_attack / _outgoing_attack in place as Pounce/Prowl, Targeted and
# defensive prevention apply) and pushes the live total and the framing here, so
# this is a dumb display — it reads no game state. It shows 0 between turns and once
# an attack has resolved, so it never lingers as a stale number.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # a HUD readout, never eats board clicks
	show_damage(0, false)


## The current attack total; match.gd calls this at every point the attack's damage
## changes, and with 0 when there is none. `outgoing` is true on the local player's
## own turn (they are dealing the attack), false on the opponent's (it is incoming).
func show_damage(amount : int, outgoing : bool) -> void:
	var label := "Damage dealt" if outgoing else "Incoming damage"
	text = "%s: %d" % [label, amount]
