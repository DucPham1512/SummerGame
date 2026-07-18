class_name SkillLayout
extends Control

# One side's ability board. The scene provides nine anchored positions
# (Ultimate + Skill1..8); on _ready each of the eight skill positions becomes
# a slot GROUP host filled from the character kit's current stage. A group
# holds one or two skills — primary on top, secondary below in a smaller
# panel, matching the physical cards — each with its own cost and its own
# press target: the slot is effectively "usable" whenever ANY of its skills
# can pay the roll, and which one fires is decided by where the player
# presses. Upgrading a slot advances it to the kit's next stage, replacing
# the whole group (upgrades may introduce the secondary, e.g. Savage ->
# Savage II + Hunt).
#
# Skills are built through Skill.create(id) — node replacement, never
# set_script on a live node (the skill's @onready view refs would not
# survive). Per-character subclasses override _kit(); the base's empty kit
# leaves the editor placeholders untouched so the generic scene still opens.

## The player picked an activatable skill during a selection window.
signal skill_chosen(skill : Skill)

## Selection-window tints — same placeholder treatment as the dice: swap for
## an outline shader / border panel later without touching the logic.
const AFFORDABLE_TINT := Color(1.0, 0.84, 0.0)
const UNAFFORDABLE_DIM := Color(0.55, 0.55, 0.55)

## Vertical share of a slot: the primary skill gets twice the secondary.
const PRIMARY_STRETCH := 2.0
const SECONDARY_STRETCH := 1.0

const SLOT_COUNT := 8

## The character whose kit this layout shows (char_id, e.g. "tactician").
## Subclasses set it in _init.
var character : String = ""

var ultimate : Skill = null
var slot_hosts : Array[VBoxContainer] = []   # container occupying each slot rect
var slot_skills : Array = []                 # per slot: Array of Skill nodes
var slot_stage : Array[int] = []             # per slot: current kit stage

# Skill -> the bound gui_input Callable connected for this window (bound
# callables aren't reliably comparable, so keep them to disconnect cleanly).
var _click_handlers : Dictionary = {}


func _ready() -> void:
	# Rotated placements (the opponent's board is turned 180° to face them)
	# must spin around the rect centre at every resolution — pivot_offset is
	# pixel-based, so it has to track the size instead of being scene-baked.
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_populate()


## Override per character. Format:
## { "ultimate": String,
##   "slots": [ {"stages": [[ids...], [ids...], ...]} x8 ] } — stage 0 is the
## base loadout; each further stage is what upgrade_slot() swaps in.
## The base has no kit — the layout keeps its editor placeholders.
func _kit() -> Dictionary:
	return {}


## Hook: the active player's board transforms the outgoing offensive
## SkillEffect in place, before it becomes the announced attack (1.4).
## Per-character subclasses override to add their bespoke offensive rules (the
## huntress's companion damage bonus, etc.); the base no-ops, so match
## resolution stays character-agnostic and characters without such a rule need
## no override.
func apply_offense_modifiers(_effect : SkillEffect, _caster : Combatant) -> void:
	pass


func _populate() -> void:
	var kit := _kit()
	if kit.is_empty():
		return
	ultimate = _replace_with_skill($Ultimate, kit.get("ultimate", ""))
	var slots : Array = kit.get("slots", [])
	for i in SLOT_COUNT:
		var placeholder : Control = get_node("Skill%d" % (i + 1))
		var host := VBoxContainer.new()
		host.name = "Slot%d" % (i + 1)
		host.add_theme_constant_override("separation", 4)
		add_child(host)
		move_child(host, placeholder.get_index())
		_copy_layout(host, placeholder)
		placeholder.queue_free()
		slot_hosts.append(host)
		slot_skills.append([])
		slot_stage.append(0)
		if i < slots.size():
			_fill_slot(i, slots[i].get("stages", [[]])[0])


# Replaces slot `index`'s group with freshly built skills for `ids`
# (first id = primary, optional second = secondary).
func _fill_slot(index : int, ids : Array) -> void:
	for old in slot_skills[index]:
		if is_instance_valid(old):
			old.queue_free()
	var group : Array = []
	for j in ids.size():
		var skill := Skill.create(ids[j])
		skill.set_anchors_preset(Control.PRESET_TOP_LEFT)   # container drives layout
		skill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skill.size_flags_stretch_ratio = PRIMARY_STRETCH if j == 0 else SECONDARY_STRETCH
		slot_hosts[index].add_child(skill)
		group.append(skill)
	slot_skills[index] = group


## Advances slot `index` (0-based) to its next kit stage, replacing the whole
## group. Returns false when the slot is already at its final stage.
func upgrade_slot(index : int) -> bool:
	var slots : Array = _kit().get("slots", [])
	if index < 0 or index >= mini(slots.size(), slot_stage.size()):
		return false
	var stages : Array = slots[index].get("stages", [])
	var next := slot_stage[index] + 1
	if next >= stages.size():
		return false
	slot_stage[index] = next
	_fill_slot(index, stages[next])
	print("[skills] slot %d upgraded to stage %d: %s" % [index + 1, next, stages[next]])
	return true


## Whether slot `index` still has an upgrade stage left.
func has_upgrade(index : int) -> bool:
	var slots : Array = _kit().get("slots", [])
	if index < 0 or index >= mini(slots.size(), slot_stage.size()):
		return false
	return slot_stage[index] + 1 < slots[index].get("stages", []).size()


## The current defensive ability — slot 8's primary, by kit convention.
func defensive_skill() -> Skill:
	if slot_skills.size() < SLOT_COUNT or (slot_skills[SLOT_COUNT - 1] as Array).is_empty():
		return null
	return slot_skills[SLOT_COUNT - 1][0]


# --- roll-window selection ------------------------------------------------------

## Opens the pick window after a roll: every skill the roll can pay lights up
## and becomes clickable (-> skill_chosen); the rest dim. Grouped slots light
## per skill, so a slot with only its secondary payable offers exactly that.
func enable_selection(symbol_counts : Dictionary, values : Array[int]) -> void:
	clear_selection()
	var affordable : Array[String] = []
	for slot in _all_slots():
		if slot.can_activate_with(symbol_counts, values):
			_make_clickable(slot)
			affordable.append(slot.skill_id)
		else:
			slot.modulate = UNAFFORDABLE_DIM
	print("[skills] selection open — roll %s = %s | activatable: %s" % [
			values, symbol_counts, str(affordable) if not affordable.is_empty() else "none"])


## Opens a pick window for exactly one skill (the defensive ability during
## the defensive roll phase): it alone lights up; the rest dim.
func enable_only(chosen : Skill) -> void:
	clear_selection()
	for slot in _all_slots():
		if slot == chosen:
			_make_clickable(slot)
		else:
			slot.modulate = UNAFFORDABLE_DIM
	print("[skills] defense window — only %s activatable" % chosen.skill_id)


## Closes the pick window: every skill back to normal look, clicks disconnected.
func clear_selection() -> void:
	for slot in _click_handlers:
		if is_instance_valid(slot):
			slot.gui_input.disconnect(_click_handlers[slot])
	_click_handlers.clear()
	for slot in _all_slots():
		slot.modulate = Color.WHITE


func _make_clickable(slot : Skill) -> void:
	var handler := _on_slot_gui_input.bind(slot)
	slot.gui_input.connect(handler)
	_click_handlers[slot] = handler
	slot.modulate = AFFORDABLE_TINT


func _on_slot_gui_input(event : InputEvent, slot : Skill) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[skills] chosen: %s (%s)" % [slot.skill_id, slot.skill_name])
		# Deferred: the pick triggers a heavy cascade (activation, selection
		# teardown — which disconnects THIS emitting signal — phase advance,
		# possibly a new dice session). None of that belongs inside a
		# gui_input emission; run it once input handling is done.
		skill_chosen.emit.call_deferred(slot)


## Every live skill on the board, groups flattened, ultimate included.
func _all_slots() -> Array[Skill]:
	var out : Array[Skill] = []
	for group in slot_skills:
		for skill in group:
			if is_instance_valid(skill):
				out.append(skill)
	if is_instance_valid(ultimate):
		out.append(ultimate)
	return out


# --- node plumbing ----------------------------------------------------------------

# Builds the skill for `id` in the placeholder's place (used for the single
# ultimate slot). Returns the replacement, or the placeholder when id is "".
func _replace_with_skill(old : Skill, id : String) -> Skill:
	if id.is_empty():
		return old
	var fresh := Skill.create(id)
	var slot_name := old.name
	old.name = slot_name + "_replaced"
	fresh.name = slot_name
	add_child(fresh)
	move_child(fresh, old.get_index())
	_copy_layout(fresh, old)
	old.queue_free()
	return fresh


# Gives `node` the placeholder's exact rect: same anchors, same offsets.
func _copy_layout(node : Control, from : Control) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)   # clear instance defaults first
	node.anchor_left = from.anchor_left
	node.anchor_top = from.anchor_top
	node.anchor_right = from.anchor_right
	node.anchor_bottom = from.anchor_bottom
	node.offset_left = from.offset_left
	node.offset_top = from.offset_top
	node.offset_right = from.offset_right
	node.offset_bottom = from.offset_bottom
