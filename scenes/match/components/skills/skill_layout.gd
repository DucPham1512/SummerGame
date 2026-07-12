class_name SkillLayout
extends Control

# One side's ability board: nine base_skill.tscn slots (Ultimate + Skill1..8)
# arranged in the scene. On _ready each slot's editor placeholder is replaced
# with the real skill for this character's kit, built through the
# Skill.create(id) factory (node replacement, not set_script-in-place: the
# skill's @onready view refs would not survive a script swap on a live node).
#
# Per-character subclasses (e.g. TacticianSkillLayout) override _kit() with
# their id lists; the base's empty kit leaves the placeholders untouched, so
# the generic scene still opens standalone.

## The player picked an activatable skill during a selection window.
signal skill_chosen(skill : Skill)

## Selection-window tints — same placeholder treatment as the dice: swap for
## an outline shader / border panel later without touching the logic.
const AFFORDABLE_TINT := Color(1.0, 0.84, 0.0)
const UNAFFORDABLE_DIM := Color(0.55, 0.55, 0.55)

## The character whose kit this layout shows (char_id, e.g. "tactician").
## Subclasses set it in _init.
var character : String = ""

# Skill -> the bound gui_input Callable connected for this window (bound
# callables aren't reliably comparable, so keep them to disconnect cleanly).
var _click_handlers : Dictionary = {}

@onready var ultimate : Skill = $Ultimate
@onready var skills : Array[Skill] = [
	$Skill1, $Skill2, $Skill3, $Skill4,
	$Skill5, $Skill6, $Skill7, $Skill8,
]


func _ready() -> void:
	# Rotated placements (the opponent's board is turned 180° to face them)
	# must spin around the rect centre at every resolution — pivot_offset is
	# pixel-based, so it has to track the size instead of being scene-baked.
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	_populate()


## Override per character: the ids filling the board, as
## { "ultimate": String, "skills": Array[String] (8 ids, Skill1..Skill8 order) }.
## The base has no kit — the layout keeps its editor placeholders.
func _kit() -> Dictionary:
	return {}


func _populate() -> void:
	var kit := _kit()
	if kit.is_empty():
		return
	ultimate = _replace_slot(ultimate, kit.get("ultimate", ""))
	var ids : Array = kit.get("skills", [])
	for i in mini(ids.size(), skills.size()):
		skills[i] = _replace_slot(skills[i], ids[i])


## Swaps the currently slotted `current` skill for the upgraded one (its "_ii"
## data entry / behaviour). Returns the new node, or null (with a warning) if
## `current` isn't on this board. Shared by every character — upgrades are a
## kit-wide mechanic, not a tactician special.
func upgrade_skill(current : Skill, upgraded_id : String) -> Skill:
	if current == ultimate:
		ultimate = _replace_slot(ultimate, upgraded_id)
		return ultimate
	var index := skills.find(current)
	if index == -1:
		push_warning("SkillLayout: upgrade_skill target is not on this board (-> %s)" % upgraded_id)
		return null
	skills[index] = _replace_slot(skills[index], upgraded_id)
	return skills[index]


# --- roll-window selection ------------------------------------------------------

## Opens the pick window after a roll: every slot the roll can pay lights up
## and becomes clickable (-> skill_chosen); the rest dim. `symbol_counts` and
## `values` come from the dice result.
func enable_selection(symbol_counts : Dictionary, values : Array[int]) -> void:
	clear_selection()
	var affordable : Array[String] = []
	for slot in _all_slots():
		if slot.can_activate_with(symbol_counts, values):
			var handler := _on_slot_gui_input.bind(slot)
			slot.gui_input.connect(handler)
			_click_handlers[slot] = handler
			slot.modulate = AFFORDABLE_TINT
			affordable.append(slot.skill_id)
		else:
			slot.modulate = UNAFFORDABLE_DIM
	print("[skills] selection open — roll %s = %s | activatable: %s" % [
			values, symbol_counts, affordable if not affordable.is_empty() else "none"])


## Opens a pick window for exactly one slot (the defensive skill during the
## defensive roll phase): it alone lights up and is clickable; the rest dim.
func enable_only(chosen : Skill) -> void:
	clear_selection()
	for slot in _all_slots():
		if slot == chosen:
			var handler := _on_slot_gui_input.bind(slot)
			slot.gui_input.connect(handler)
			_click_handlers[slot] = handler
			slot.modulate = AFFORDABLE_TINT
		else:
			slot.modulate = UNAFFORDABLE_DIM
	print("[skills] defense window — only %s activatable" % chosen.skill_id)


## Closes the pick window: every slot back to normal look, clicks disconnected.
func clear_selection() -> void:
	for slot in _click_handlers:
		if is_instance_valid(slot):
			slot.gui_input.disconnect(_click_handlers[slot])
	_click_handlers.clear()
	for slot in _all_slots():
		slot.modulate = Color.WHITE


func _on_slot_gui_input(event : InputEvent, slot : Skill) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[skills] chosen: %s (%s)" % [slot.skill_id, slot.skill_name])
		# Deferred: the pick triggers a heavy cascade (activation, selection
		# teardown — which disconnects THIS emitting signal — phase advance,
		# possibly a new dice session). None of that belongs inside a
		# gui_input emission; run it once input handling is done.
		skill_chosen.emit.call_deferred(slot)


func _all_slots() -> Array[Skill]:
	var out : Array[Skill] = skills.duplicate()
	out.append(ultimate)
	return out


# Replaces a slot node with a freshly built skill, keeping the slot's place in
# the scene: same layout (anchors/offsets) and same tree position. Returns the
# replacement — or the old node untouched when the id is empty.
func _replace_slot(old : Skill, id : String) -> Skill:
	if id.is_empty():
		return old
	var fresh := Skill.create(id)
	# Hand the slot's name over: the old node keeps it until freed (end of
	# frame), which would auto-rename the newcomer on collision.
	var slot_name := old.name
	old.name = slot_name + "_replaced"
	fresh.name = slot_name
	add_child(fresh)
	move_child(fresh, old.get_index())
	# The slots are anchor-positioned by the scene; copy the whole layout.
	fresh.set_anchors_preset(Control.PRESET_TOP_LEFT)   # clear instance defaults first
	fresh.anchor_left = old.anchor_left
	fresh.anchor_top = old.anchor_top
	fresh.anchor_right = old.anchor_right
	fresh.anchor_bottom = old.anchor_bottom
	fresh.offset_left = old.offset_left
	fresh.offset_top = old.offset_top
	fresh.offset_right = old.offset_right
	fresh.offset_bottom = old.offset_bottom
	old.queue_free()
	return fresh
