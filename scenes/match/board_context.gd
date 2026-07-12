class_name BoardContext
extends RefCounted

# Placeholder for the game's "rules API": the authoritative board verbs that
# cards' resolve(), status effects' spend()/phase hooks, and the SkillEffect
# resolver all compose. The real implementation lands with the Board /
# battle-phase system; the test scenes use mocks that override these to log
# calls.
#
# Scoped to a single resolution — it knows the caster (the player whose card /
# skill / status is resolving). Verbs default to the caster unless a target is
# given. All mutation, RNG (roll_die) and networked choices (choose_*) funnel
# through here so resolution stays authoritative and deterministic. Each verb
# warns until the real Board implements it, so an unimplemented verb is loud
# rather than silent.

var caster       # the player whose card / skill / status is resolving
var opponent     # convenience reference

## Damage currently being resolved against `caster`, when this context is
## scoped to a defensive window (protect / bond spends read it). 0 otherwise.
var incoming_damage : int = 0


func gain_cp(amount: int) -> void:
	_todo("gain_cp(%d)" % amount)

func draw_cards(amount: int) -> void:
	_todo("draw_cards(%d)" % amount)

func deal_damage(amount: int, target = null) -> void:
	_todo("deal_damage(%d, %s)" % [amount, target])

func heal(amount: int, target = null) -> void:
	_todo("heal(%d, %s)" % [amount, target])

func apply_status(status_id: String, stacks: int = 1, target = null) -> void:
	_todo("apply_status(%s x%d, %s)" % [status_id, stacks, target])

func transfer_status(status_id: String, from_player, to_player) -> void:
	_todo("transfer_status(%s, %s -> %s)" % [status_id, from_player, to_player])

func halve_incoming_damage(target = null) -> void:
	_todo("halve_incoming_damage(%s)" % target)

func reroll_die(die) -> void:
	_todo("reroll_die(%s)" % die)

# Value-returning / interactive verbs. In the real context these are coroutines
# (await a synced RNG roll or a networked choice); the placeholders return
# defaults so they can be called without a Board.
func roll_die() -> int:
	_todo("roll_die()")
	return 0

func choose_player():
	_todo("choose_player()")
	return null


func _todo(call_desc: String) -> void:
	push_warning("BoardContext.%s not implemented (placeholder)" % call_desc)
