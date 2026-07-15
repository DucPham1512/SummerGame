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

## The roll this resolution is scoped to (skill activations scale off it):
## the raw die values and their symbol tally through the caster's die faces.
var roll_values : Array[int] = []
var roll_symbols : Dictionary = {}


func gain_cp(amount: int) -> void:
	_todo("gain_cp(%d)" % amount)

func draw_cards(amount: int) -> void:
	_todo("draw_cards(%d)" % amount)

func deal_damage(amount: int, target = null) -> void:
	_todo("deal_damage(%d, %s)" % [amount, target])

func heal(amount: int, target = null) -> void:
	_todo("heal(%d, %s)" % [amount, target])

func heal_companion(amount: int, target = null) -> void:
	_todo("heal_companion(%d, %s)" % [amount, target])

func apply_status(status_id: String, stacks: int = 1, target = null) -> void:
	_todo("apply_status(%s x%d, %s)" % [status_id, stacks, target])

func remove_status(status_id: String, target = null) -> void:
	_todo("remove_status(%s, %s)" % [status_id, target])

func clear_all_statuses(target = null) -> void:
	_todo("clear_all_statuses(%s)" % target)

func transfer_status(status_id: String, from_player, to_player) -> void:
	_todo("transfer_status(%s, %s -> %s)" % [status_id, from_player, to_player])

func halve_incoming_damage(target = null) -> void:
	_todo("halve_incoming_damage(%s)" % target)

func prevent_damage(amount: int, target = null) -> void:
	_todo("prevent_damage(%d, %s)" % [amount, target])

# --- dice-session verbs (the roll UI hookup implements these) -----------------

func reroll_die(die) -> void:
	_todo("reroll_die(%s)" % die)

func change_die_value(die_index: int, value: int, target = null) -> void:
	_todo("change_die_value(#%d -> %d, %s)" % [die_index, value, target])

func adjust_die_value(die_index: int, delta: int, target = null) -> void:
	_todo("adjust_die_value(#%d %+d, %s)" % [die_index, delta, target])

func copy_die_value(from_index: int, to_index: int, target = null) -> void:
	_todo("copy_die_value(#%d -> #%d, %s)" % [from_index, to_index, target])

func grant_extra_roll(target = null) -> void:
	_todo("grant_extra_roll(%s)" % target)

# --- character-kit verbs --------------------------------------------------------

## Advances the caster's own skill layout slot `slot_index` to its next kit
## stage (the card counterpart of SkillLayout.upgrade_slot). Always self —
## there is no "upgrade the opponent's kit" card.
func upgrade_skill(slot_index: int) -> void:
	_todo("upgrade_skill(slot %d)" % slot_index)

# Value-returning / interactive verbs. In the real context these are coroutines
# (await a synced RNG roll or a networked choice); the placeholders return
# defaults so they can be called without a Board.
func roll_die() -> int:
	_todo("roll_die()")
	return 0

func choose_player():
	_todo("choose_player()")
	return null

func choose_status(target = null) -> String:
	_todo("choose_status(%s)" % target)
	return ""

func choose_die(target = null) -> int:
	_todo("choose_die(%s)" % target)
	return -1

func choose_die_value() -> int:
	_todo("choose_die_value()")
	return 6

func choose_option(options: Array) -> int:
	_todo("choose_option(%s)" % [options])
	return 0


func _todo(call_desc: String) -> void:
	push_warning("BoardContext.%s not implemented (placeholder)" % call_desc)
