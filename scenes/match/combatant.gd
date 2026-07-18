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
func change_health(delta : int) -> void:
	health = clampi(health + delta, 0, max_hp)
	health_changed.emit(health)


# --- status effects -----------------------------------------------------------

## Inflicts `stack_count` stacks of a status on this combatant: merges into the
## existing token, or instantiates the behaviour subclass via the factory.
## Returns the token (stacks clamped to the data's stack_limit by the token).
func apply_status(status_id : String, stack_count : int = 1) -> StatusEffect:
	var token : StatusEffect = status_effects.get(status_id)
	if token != null:
		if token.add_stacks(stack_count) != 0:
			status_changed.emit(token)
		return token
	token = StatusEffect.create(status_id, stack_count)
	status_effects[status_id] = token
	status_applied.emit(token)
	return token


## Re-announces a token the caller mutated DIRECTLY — runtime stack-limit
## changes and max-outs (Higher Ground) go straight at the token and so bypass
## apply_status's signals. Callers doing that must announce it, or the UI and
## the netcode never hear about it.
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
	if token.remove_stacks(stack_count) != 0:
		status_changed.emit(token)
	_purge_depleted()


## Removes a status outright, whatever its stacks (clear effects).
func clear_status(status_id : String) -> void:
	var token : StatusEffect = status_effects.get(status_id)
	if token == null:
		return
	status_effects.erase(status_id)
	status_removed.emit(token)


## Upkeep tick: triggers every owned token's on_upkeep hook, once per stack
## (bleed rolls per stack), sequentially — hooks may await rolls. `ctx` is
## scoped with this combatant as caster. Depleted tokens leave afterwards.
func run_upkeep(ctx : BoardContext) -> void:
	for token in status_effects.values():
		for i in token.stacks:
			if token.is_depleted():
				break
			await token.on_upkeep(ctx)
	_purge_depleted()


# Tokens shed stacks themselves (bleed's 5-6, protect's spend), so depletion is
# swept here rather than trusted to every code path that touches stacks.
func _purge_depleted() -> void:
	for status_id in status_effects.keys():
		var token : StatusEffect = status_effects[status_id]
		if token.is_depleted():
			status_effects.erase(status_id)
			status_removed.emit(token)
