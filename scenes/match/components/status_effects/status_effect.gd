class_name StatusEffect
extends RefCounted

# Base status-effect entity, mirroring the skill/card pattern: data loads from
# GameDataLoader by id, behaviour lives in per-effect subclasses under effects/,
# and everything a status *does* runs through the shared board-verb context
# (BoardContext), so resolution stays authoritative and deterministic.
#
# Each instance is one player's token stack: it tracks its own stack count,
# clamped to the data's stack_limit. Transfer/steal/clear bookkeeping and the
# "spend at any time" resolving UI live match-side — the match calls into
# can_spend()/spend() (including the window right before a transfer/steal/clear)
# and the phase hooks (on_upkeep) here.

# Registered behaviour scripts: status_id -> script path. Ids not listed produce
# a base, data-only instance — fine for purely passive tokens whose rule the
# board consults during resolution (e.g. targeted's +2, constrict's roll cost).
# Paths are load()ed lazily to avoid preload cycles with the subclasses.
const EFFECT_SCRIPTS := {
	"bleed": "res://scenes/match/components/status_effects/effects/bleed.gd",
	"protect": "res://scenes/match/components/status_effects/effects/protect.gd",
	"targeted": "res://scenes/match/components/status_effects/effects/targeted.gd",
	"constrict": "res://scenes/match/components/status_effects/effects/constrict.gd",
	"tactical_advantage": "res://scenes/match/components/status_effects/effects/tactical_advantage.gd",
	"nyras_bond": "res://scenes/match/components/status_effects/effects/nyras_bond.gd",
}

var status_id : String
var status_name : String
var description : String
var stack_limit : int = 1
var transferable : bool = true

var stacks : int = 0
var picture_panel : Texture2D
## The board this token sits on, set by the Combatant when the token joins its
## status_effects (and cleared when it leaves). Null while unowned — intent
## payloads (SkillEffect) and tests hold tokens no board has adopted.
var owner_combatant : Combatant = null
## Factory: builds the behaviour subclass registered for the id, or a base
## data-only instance when there is none. Prefer this over new() for tokens a
## player actually owns; plain new() is fine for intent payloads (SkillEffect).
static func create(effect_id : String, stack_count : int = 1) -> StatusEffect:
	if EFFECT_SCRIPTS.has(effect_id):
		var script : GDScript = load(EFFECT_SCRIPTS[effect_id])
		return script.new(effect_id, stack_count)
	return StatusEffect.new(effect_id, stack_count)


func _init(effect_id : String = "", stack_count : int = 1) -> void:
	if effect_id.is_empty():
		return
	status_id = effect_id
	load_data()
	stacks = clampi(stack_count, 0, stack_limit)


## Populates the data fields from the repository entry for `status_id`. Returns
## true on success, or false (and pushes an error) if no such status exists.
func load_data() -> bool:
	var entry : Dictionary = GameDataLoader.status_effect_repository.get(status_id, {})
	if entry.is_empty():
		push_error("StatusEffect: no status effect found for id '%s'" % status_id)
		return false

	status_name = entry.get("name", "")
	description = entry.get("description", "")
	stack_limit = int(entry.get("stack_limit", 1))
	transferable = bool(entry.get("transferable", true))
	# Icon per status id. load(), not preload: preload only takes constant
	# paths. Missing art stays a warning, not an error — the token still works.
	var icon_path := "res://assets/art/StatusEffect/%s.png" % status_id
	if ResourceLoader.exists(icon_path):
		picture_panel = load(icon_path)
	else:
		push_warning("StatusEffect: no icon for '%s' (expected %s)" % [status_id, icon_path])
	return true


# --- stacks (owned by this entity, clamped to the data's limit) --------------

## Adds stacks, clamped to stack_limit. Returns how many were actually added.
func add_stacks(amount : int) -> int:
	var before := stacks
	stacks = clampi(stacks + amount, 0, stack_limit)
	if stacks != before:
		_announce()
	return stacks - before


## Removes stacks (never below 0). Returns how many were actually removed.
func remove_stacks(amount : int) -> int:
	var before := stacks
	stacks = clampi(stacks - amount, 0, stack_limit)
	if stacks != before:
		_announce()
	return before - stacks


# Tells the board the count moved. Effects shed their own stacks (bleed's 5-6, a
# Protect/TA/Bond spend, constrict expiring) without going through the
# combatant, so announcing HERE is what keeps the token row and the netcode in
# step — neither polls, both listen for Combatant's status signals (bug 81).
# Silent when unowned, so tokens off the board still work headless.
func _announce() -> void:
	if is_instance_valid(owner_combatant):
		owner_combatant.on_token_stacks_changed(self)


func is_depleted() -> bool:
	return stacks <= 0


# --- behaviour hooks (override per effect) -----------------------------------

## Buff/debuff classification. Not part of the JSON data, so subclasses declare
## it (cosmetic — drives token presentation, never rules).
func is_positive() -> bool:
	return false


## Whether this token can currently be spent. The match's resolving scene calls
## this to offer the spend window, which can open at any time — including right
## before the token would be transferred, stolen or cleared.
func can_spend() -> bool:
	return false


## Damage mitigation: the owner runs every incoming hit past each token it holds,
## and each returns what survives (bug 79 — an armed Protect halves it). Tokens
## that mitigate pay their own cost here, since only they know whether they fired.
## The base is transparent, so a token that does not mitigate needs no wiring.
func mitigate_damage(amount : int) -> int:
	return amount


## A short marker appended to the token's pill, for state the stack count can't
## show — an armed Protect looks identical to an idle one otherwise. "" for the
## tokens that carry no such state.
func pill_suffix() -> String:
	return ""


## Spend the token by composing board verbs. Returns true if it was spent.
## When the match resolves a status, ctx.caster is the token's owner.
func spend(_ctx : BoardContext) -> bool:
	return false


## The token's spend MENU, driving the spend popup. Each option is
## { "label": String, "enabled": bool, "action": Callable } — disabled options
## still list (dimmed) so the player sees what the token could do. Special
## kinds replace "action": {"kind": "split", "damage": int,
## "on_confirm": Callable(own_share, other_share)} opens the popup's
## damage-split stage. Base/passive tokens have no menu.
func spend_options(_ctx : BoardContext) -> Array[Dictionary]:
	return []


## Whether this token resolves during the owner's Upkeep Phase. NOT every status
## does — Constrict resolves in the Offensive Roll Phase, Protect is spend-anytime
## with no expiry, Targeted is a passive damage rule — so the upkeep ticks only
## the tokens that declare themselves here (bug 56). Bleed is the only one today.
func resolves_on_upkeep() -> bool:
	return false


## How many dice this token's upkeep needs PER STACK, so the match can throw them
## all in one roll before any hook runs. 0 = resolves without dice. Only consulted
## when resolves_on_upkeep() is true.
func upkeep_dice_per_stack() -> int:
	return 0


## Phase trigger: the match calls this during the owner's Upkeep Phase, once per
## stack, and only when resolves_on_upkeep() is true. The dice are already thrown
## by then (and may have been altered by an instant-action card), so ctx.roll_die()
## hands back the FINAL value rather than rolling afresh.
func on_upkeep(_ctx : BoardContext) -> void:
	pass


## Phase trigger: the match calls this when the owner's Roll Phase concludes
## (constrict expires here).
func on_roll_phase_end(_ctx : BoardContext) -> void:
	pass
