class_name Combatant
extends Control

# The shared PUBLIC surface of one side of the board: the resource state and
# signals that components like the HP/CP bars consume. Player (the local, full
# side) and Opponent (the replicated, public-info-only view) both extend this,
# so a component exporting a Combatant works on either side of the match.

# Emitted by the subclasses (Player's update_* / Opponent's on_opponent_*),
# hence the unused-signal ignores here in the base.
@warning_ignore("unused_signal")
signal health_changed(health : int)
@warning_ignore("unused_signal")
signal cp_changed(cp : int)

## Status-token bookkeeping, for whichever UI renders the tokens: a new token
## joined the row / an existing one changed stacks / a token left (depleted or
## cleared). Statuses are public info, so both sides carry real tokens.
signal status_applied(status : StatusEffect)
signal status_changed(status : StatusEffect)
signal status_removed(status : StatusEffect)

var health : int
var cp : int

var max_hp : int = Util.one_v_one_max_hp
var max_cp : int = Util.one_v_one_max_cp

## The character's companion (Nyra for the huntress); null when none. Assigned
## by whatever builds the side (char selection later; tests directly).
var companion : CompanionNyra = null

# One token (stack pile) per status id — stacking merges, per StatusEffect's
# "each instance is one player's token stack".
var status_effects : Dictionary = {}


## Direct health delta for resolution code and tests. Player/Opponent layer
## their label updates on top through their own wrapper methods.
##
## Every hit this side takes passes through here, so mitigation belongs here
## rather than at the half-dozen call sites that deal damage (bug 79). Healing
## is left alone — only a negative delta is "incoming damage".
func change_health(delta : int) -> void:
	if delta < 0:
		delta = -absorb_incoming_damage(-delta)
	health = clampi(health + delta, 0, max_hp)
	health_changed.emit(health)


## Runs `amount` past every token this side holds and returns what actually
## lands. Tokens that mitigate (an armed Protect) pay their own cost inside
## mitigate_damage, since only they know whether they fired. Iterating values()
## copies, so a token retiring itself mid-walk is safe.
func absorb_incoming_damage(amount : int) -> int:
	for token in status_effects.values():
		if amount <= 0:
			break
		amount = token.mitigate_damage(amount)
	return maxi(amount, 0)


# --- status effects -----------------------------------------------------------

## Inflicts `stack_count` stacks of a status on this combatant: merges into the
## existing token, or instantiates the behaviour subclass via the factory.
## Returns the token (stacks clamped to the data's stack_limit by the token).
func apply_status(status_id : String, stack_count : int = 1) -> StatusEffect:
	var token : StatusEffect = status_effects.get(status_id)
	if token != null:
		token.add_stacks(stack_count)   # the token announces the move itself
		return token
	token = StatusEffect.create(status_id, stack_count)
	status_effects[status_id] = token
	# Adopt only once it's on the board, and before announcing it: the token's
	# starting stacks were set in its constructor and must not read as a change.
	token.owner_combatant = self
	status_applied.emit(token)
	return token


## A token told us its stack count moved (StatusEffect._announce). A count that
## hit 0 retires the token then and there, so has_status() never reports a spent
## one — the end-of-tick _purge_depleted sweeps are now just a backstop. Erasing
## before emitting matters: listeners (match_sync's broadcast) re-read
## status_effects and must see the post-removal truth.
func on_token_stacks_changed(token : StatusEffect) -> void:
	if not token.is_depleted():
		status_changed.emit(token)
		return
	if status_effects.get(token.status_id) == token:
		status_effects.erase(token.status_id)
	status_removed.emit(token)
	token.owner_combatant = null


## Re-announces a token the caller mutated DIRECTLY. Stack COUNTS announce
## themselves; this is for the rest — runtime stack_limit changes (Higher
## Ground) go straight at the token and nothing else would hear about them.
func notify_status_changed(token : StatusEffect) -> void:
	status_changed.emit(token)


func has_status(status_id : String) -> bool:
	return status_effects.has(status_id)


func get_status(status_id : String) -> StatusEffect:
	return status_effects.get(status_id)


## Removes stacks from a status; the token leaves the board when it hits 0.
func remove_status_stacks(status_id : String, stack_count : int = 1) -> void:
	var token : StatusEffect = status_effects.get(status_id)
	if token == null:
		return
	token.remove_stacks(stack_count)   # the token announces the move (and its own retirement)
	_purge_depleted()


## Removes a status outright, whatever its stacks (clear effects).
func clear_status(status_id : String) -> void:
	var token : StatusEffect = status_effects.get(status_id)
	if token == null:
		return
	status_effects.erase(status_id)
	status_removed.emit(token)
	token.owner_combatant = null   # off the board: it can't announce onto us any more


## Upkeep tick: triggers the on_upkeep hook of every token that DECLARES upkeep
## resolution (bug 56 — most statuses resolve elsewhere or not at all), once per
## stack, sequentially since hooks may await. `ctx` is scoped with this combatant
## as caster. Depleted tokens leave afterwards.
func run_upkeep(ctx : BoardContext) -> void:
	for token in status_effects.values():
		if not token.resolves_on_upkeep():
			continue
		for i in token.stacks:
			if token.is_depleted():
				break
			await token.on_upkeep(ctx)
	_purge_depleted()


## How many dice this side's upkeep needs in total, so the match can throw them
## all in one roll before any hook resolves (letting instant-action cards modify
## them first). Sums each upkeep-resolving token's per-stack need.
func upkeep_dice_needed() -> int:
	var total := 0
	for token in status_effects.values():
		if token.resolves_on_upkeep():
			total += token.stacks * token.upkeep_dice_per_stack()
	return total


## Roll-phase-end tick (bug 71): fires every token's on_roll_phase_end hook — the
## base is a no-op, Constrict removes its stacks here — then sweeps any that
## depleted, so the emptied token leaves and its status_removed replicates. The
## match calls this on the active side as the Offensive Roll Phase concludes.
func run_roll_phase_end(ctx : BoardContext) -> void:
	for token in status_effects.values():
		token.on_roll_phase_end(ctx)
	_purge_depleted()


# Backstop. A token that empties itself now retires on the spot (see
# on_token_stacks_changed), so this normally finds nothing — it still catches
# tokens created empty and never touched since.
func _purge_depleted() -> void:
	for status_id in status_effects.keys():
		var token : StatusEffect = status_effects[status_id]
		if token.is_depleted():
			status_effects.erase(status_id)
			status_removed.emit(token)
			token.owner_combatant = null
