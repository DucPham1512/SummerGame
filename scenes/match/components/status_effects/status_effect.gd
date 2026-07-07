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
}

var status_id : String
var status_name : String
var description : String
var stack_limit : int = 1
var transferable : bool = true

var stacks : int = 0
var stack_label : Label
var picture_panel : Texture2D
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
	_refresh_label()
	return stacks - before


## Removes stacks (never below 0). Returns how many were actually removed.
func remove_stacks(amount : int) -> int:
	var before := stacks
	stacks = clampi(stacks - amount, 0, stack_limit)
	_refresh_label()
	return before - stacks


# The label is optional: it's assigned by the token's UI when one exists, and
# stack changes must also work headless (tests, effects resolving off-screen).
func _refresh_label() -> void:
	if is_instance_valid(stack_label):
		stack_label.text = "x%d" % stacks


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


## Spend the token by composing board verbs. Returns true if it was spent.
## When the match resolves a status, ctx.caster is the token's owner.
func spend(_ctx : BoardContext) -> bool:
	return false


## Phase trigger: the match calls this during the owner's Upkeep Phase.
func on_upkeep(_ctx : BoardContext) -> void:
	pass
