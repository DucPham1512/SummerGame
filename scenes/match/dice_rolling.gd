extends Control

const SIDES := 6
const DICE_COUNT := 5
const STAGGER := 0.1          # delay between each die's toss start
const GATHER_TIME := 0.4
const GRID_SPACING := 200.0   # horizontal gap between grid slots
const REROLL_PAUSE := 0.2      # beat between parking kept dice and rerolling
const CORNER_MARGIN := 130.0  # kept dice park this far from the bottom-left corner
const CORNER_SPACING := 110.0
const PARK_SCALE := 0.5        # kept dice shrink to this fraction while parked
## Selection tint — placeholder for a future gold-outline shader / border panel.
const SELECTED_TINT := Color(1.0, 0.84, 0.0)

# Result-strip face sprites — same asset convention as dice_cost_container.
const FACE_PATH := "res://assets/art/Dice/%s/face/Face%02d.png"
const RESULT_FACE_SIZE := Vector2(48, 48)

# Selection semantics: a SET bit (1) in re_roll_mask means the die is SELECTED and
# WILL be rerolled; a CLEAR bit (0) means it is kept/locked and will NOT reroll.
enum Phase { IDLE, ANIMATING, SELECTING, PICKING }

## A roll session ended — the roll budget ran out or Keep was pressed. Carries
## the recorded value of every die, by index.
signal rolling_finished(results : Array[int])

## A card verb changed the live roll (a die value forced, a die rerolled, an
## extra attempt taken). Carries every participating die's new value — the match
## re-tallies symbols and re-lights the skills off it (bug 58).
signal roll_modified(results : Array[int])
## helping_hand: the local player picked which of the OPPONENT's spectated dice
## to force a reroll on. The match turns this into a cross-client message.
signal opponent_reroll_requested(die_index : int)
# Internal resolves for the interactive card pickers (choose_die / value / option).
signal _die_picked(index : int)
signal _choice_made(index : int)

## Toss everything as soon as the scene loads (the standalone harness). The
## match embeds this scene hidden and drives sessions through run() instead.
@export var auto_roll : bool = true

## After gathering, straighten dice to upright (rotation 0) in the grid.
## False keeps each die's random resting angle from the toss.
@export var gather_upright: bool = true

@onready var dice: Dictionary = {
	0: $Dice1,
	1: $Dice2,
	2: $Dice3,
	3: $Dice4,
	4: $Dice5,
}

# Emitted internally once every die in a toss batch has settled.
signal _toss_all_done

@onready var roll_result : HBoxContainer = $RollResult
@onready var _click_catcher : Control = $ClickCatcher
@onready var _roll_button : Button = $Roll
@onready var _keep_button : Button = $Keep

var dice_result: Array[int] = []   # last rolled value per die (logic record)
var re_roll_mask: int = 0          # which dice are selected for reroll (bit per index)
var phase: Phase = Phase.IDLE
var rolls_used: int = 0            # rolls spent this session (first toss included)
var active_count: int = DICE_COUNT # dice taking part in the current session
var _session_max_rolls: int = 0    # 0 = uncapped (the standalone harness)
var _slots: Array[Vector2] = []    # fixed grid slot per die index
var _base_scale: Array[Vector2] = []   # each die's normal (grid) scale
var _corner_base: Vector2          # bottom-left park anchor
var _toss_pending: int = 0

# --- card interaction state (bug 58) ------------------------------------------
## Set by the match while a completed local roll is on display and still open to
## card modification (the post-session skill-pick window). Card plays that need a
## live roll consult has_live_roll() so they can't spend CP on nothing.
var _roll_live: bool = false
## The OPPONENT's roll as replicated to this client (helping_hand targets it).
## Empty when the opponent isn't showing a roll.
var _spectated_values: Array[int] = []

## Consulted right before a reroll actually happens (bug 71): returns whether it
## may proceed, charging any cost as a side effect. The match installs Constrict's
## CP surcharge here; unset (harness) means every reroll is free and allowed.
var reroll_gate: Callable = Callable()


func _ready() -> void:
	dice_result.resize(DICE_COUNT)
	_base_scale.resize(DICE_COUNT)
	for index in dice:
		dice[index].roll_finished.connect(_on_roll_finished.bind(index))
		_base_scale[index] = dice[index].scale   # remember the normal grid scale
		# Clicking a die toggles its selection (gated to the SELECTING phase).
		var area: Area2D = dice[index].get_node("ClickArea")
		area.input_event.connect(_on_die_clicked.bind(index))
	_compute_slots()
	var viewport := get_viewport_rect().size
	_corner_base = Vector2(CORNER_MARGIN, viewport.y - CORNER_MARGIN)
	for index in dice:
		dice[index].position = _slots[index]   # start resting in the grid
		update_die_visual(index)
	if auto_roll:
		start_roll()   # auto-toss as soon as the scene loads


# Evenly spaced, horizontally centered row for `count` participating dice.
# Every index still gets a slot (spares trail off to the right, hidden).
func _compute_slots(count: int = DICE_COUNT) -> void:
	_slots.clear()
	var viewport := get_viewport_rect().size
	var total_width := GRID_SPACING * float(count - 1)
	var start_x := viewport.x * 0.5 - total_width * 0.5
	var y := viewport.y * 0.5
	for i in DICE_COUNT:
		_slots.append(Vector2(start_x + GRID_SPACING * float(i), y))


## How many dice take part in rolls from here on — rendered, tossed, selectable
## and counted (e.g. defensive rolls throw 3-5 dice). The grid re-centres for
## the count; the spare dice hide.
func set_active_count(count: int) -> void:
	active_count = clampi(count, 1, DICE_COUNT)
	_compute_slots(active_count)
	for index in dice:
		dice[index].visible = index < active_count
		dice[index].position = _slots[index]


func _active_mask() -> int:
	return (1 << active_count) - 1


func _on_roll_finished(result: int, index: int) -> void:
	dice_result[index] = result


# --- Phase 1: toss ---------------------------------------------------------

## Toss every die whose bit is set in `mask`. The value is decided here (logic)
## via RNG, then handed to the die purely to display (view). Returns only once
## every tossed die has emitted roll_finished.
func toss_all(mask: int) -> void:
	_toss_pending = 0
	var indices := dice.keys()
	for i in indices.size():
		var index: int = indices[i]
		if mask & (1 << index) == 0:
			continue
		_toss_pending += 1
		var value := randi_range(1, SIDES)
		dice[index].roll_finished.connect(_on_toss_one_settled, CONNECT_ONE_SHOT)
		dice[index].roll(value)
		# Stagger the next die's start (no wait after the final iteration).
		if STAGGER > 0.0 and i < indices.size() - 1:
			await get_tree().create_timer(STAGGER).timeout

	# If any are still mid-toss, wait for the batch to finish. (Guarded so we
	# never await a signal that already fired during the stagger loop.)
	if _toss_pending > 0:
		await _toss_all_done


func _on_toss_one_settled(_result: int) -> void:
	_toss_pending -= 1
	if _toss_pending == 0:
		_toss_all_done.emit()


# --- Phase 2: gather -------------------------------------------------------

## Slide every die from where it currently is to its fixed grid slot. Returns
## once all the slide tweens finish.
func gather_to_grid() -> void:
	var tween := create_tween().set_parallel(true)
	for index in dice:
		var d: Node2D = dice[index]
		tween.tween_property(d, "position", _slots[index], GATHER_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(d, "scale", _base_scale[index], GATHER_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if gather_upright:
			tween.tween_property(d, "rotation", 0.0, GATHER_TIME)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


# --- Phase 3: selection ----------------------------------------------------

## Toggle a die's selected-for-reroll bit.
func flip_bit(index: int) -> void:
	re_roll_mask ^= (1 << index)


## Single source of truth for a die's selection appearance: reads the mask bit and
## tints accordingly, so visual and mask can never drift. Replace the body with an
## outline shader / border panel later — the selection logic stays unchanged.
func update_die_visual(index: int) -> void:
	var selected := (re_roll_mask & (1 << index)) != 0
	dice[index].modulate = SELECTED_TINT if selected else Color.WHITE


# Bound with the die's index via .bind(index), so `index` always matches the
# clicked die (no off-by-one). NOTE: this physics-picking path only fires when
# no Control consumed the click — the ClickCatcher below normally handles it;
# this stays as the fallback if the catcher is ever removed.
func _on_die_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, index: int) -> void:
	if phase != Phase.SELECTING or index >= active_count:
		return   # selection only for settled, participating dice
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		flip_bit(index)
		update_die_visual(index)


# The dice are Node2Ds: their Area2D picking loses to any overlapping Control
# (in the match, the skill boards cover the screen centre and eat the clicks).
# So a full-rect ClickCatcher Control — above the boards, below Roll/Keep —
# takes the click and hit-tests the dice itself, reusing the same ClickArea
# shapes via a physics point query. Also makes the roll session modal: while
# dice are out, clicks can't leak into the UI underneath.
func _on_catcher_gui_input(event: InputEvent) -> void:
	if phase != Phase.SELECTING and phase != Phase.PICKING:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var index := _die_at_point(get_global_mouse_position())
	if index < 0:
		return
	if phase == Phase.PICKING:
		# Single-pick for a card verb (choose_die): resolve and stop.
		_die_picked.emit(index)
		return
	flip_bit(index)
	update_die_visual(index)


# Which participating die (if any) sits under `global_pos`, via the same physics
# point query the reroll-selection uses. -1 when the click missed every die.
func _die_at_point(global_pos: Vector2) -> int:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_viewport().world_2d.direct_space_state.intersect_point(query):
		for index in dice:
			# Hidden spare dice keep live ClickAreas — only active ones count.
			if index < active_count and dice[index].get_node("ClickArea") == hit.collider:
				return index
	return -1


# --- Reroll ----------------------------------------------------------------

func _unselected_indices() -> Array:
	var out: Array = []
	for index in dice:
		if re_roll_mask & (1 << index) == 0:
			out.append(index)
	return out


func _corner_spot(k: int) -> Vector2:
	return _corner_base + Vector2(CORNER_SPACING * float(k), 0.0)


# Slide the kept (unselected) dice off to a corner so the selected dice have room
# to reroll. No-op if every die is selected.
func _park_unselected_to_corner() -> void:
	var kept := _unselected_indices()
	if kept.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for k in kept.size():
		var index: int = kept[k]
		tween.tween_property(dice[index], "position", _corner_spot(k), GATHER_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(dice[index], "scale", _base_scale[index] * PARK_SCALE, GATHER_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Reroll only the selected dice: park the kept ones, pause, toss the selected,
## then bring everything back to the grid.
func reroll_selected() -> void:
	if re_roll_mask == 0:
		return   # nothing selected, nothing to reroll
	# Bug 71: a reroll surcharge (Constrict) may refuse this attempt. Checked after
	# the empty-mask guard so a no-op press is never charged.
	if reroll_gate.is_valid() and not reroll_gate.call():
		return
	phase = Phase.ANIMATING
	rolls_used += 1
	await _park_unselected_to_corner()
	await get_tree().create_timer(REROLL_PAUSE).timeout
	# Drop the selection tint so the rerolling dice animate normally.
	for index in dice:
		dice[index].modulate = Color.WHITE
	await toss_all(re_roll_mask)
	await gather_to_grid()
	if _session_budget_spent():
		_finish_session()
		return
	# Fresh selection round: clear marks/visuals so the player can pick again.
	re_roll_mask = 0
	phase = Phase.SELECTING
	for index in dice:
		update_die_visual(index)


# --- Sequencing ------------------------------------------------------------

## First full roll: toss all five, then gather to the grid.
func start_roll() -> void:
	phase = Phase.ANIMATING
	rolls_used += 1
	# Fresh roll: nothing selected — the player explicitly picks what to reroll.
	re_roll_mask = 0
	for index in dice:
		update_die_visual(index)
	await toss_all(_active_mask())
	await gather_to_grid()
	if _session_budget_spent():
		_finish_session()
		return
	phase = Phase.SELECTING
	for index in dice:
		update_die_visual(index)


func _on_roll_pressed() -> void:
	match phase:
		Phase.IDLE:
			start_roll()           # first roll: throw everything
		Phase.SELECTING:
			reroll_selected()      # subsequent presses: reroll only the marked dice
		# Phase.ANIMATING: ignore — a toss/gather is already running.


## Keep the roll as it lies: ends the session early instead of spending the
## remaining rerolls.
func _on_keep_pressed() -> void:
	if phase == Phase.SELECTING:
		_finish_session()


# --- Roll sessions (the match's entry point) ---------------------------------

## Runs one capped roll session: the opening toss, then player-driven rerolls
## until the budget is spent or Keep is pressed. Returns the final values —
## one per participating die. `dice_count` trims the throw for rolls that use
## fewer than the full set (defensive rolls: 3-5 dice).
func run(max_rolls : int, dice_count : int = DICE_COUNT) -> Array[int]:
	show()
	# Starting our own roll supersedes anything we were spectating.
	_spectated_values = []
	_roll_live = false
	set_active_count(dice_count)
	_set_table_visible(true)
	_session_max_rolls = max_rolls
	rolls_used = 0
	start_roll()
	var results : Array[int] = await rolling_finished
	_session_max_rolls = 0
	return results


func _session_budget_spent() -> bool:
	return _session_max_rolls > 0 and rolls_used >= _session_max_rolls


func _finish_session() -> void:
	phase = Phase.IDLE
	re_roll_mask = 0
	for index in dice:
		update_die_visual(index)
	# Capped sessions put the interactive furniture away — the modal catcher
	# especially, so the board underneath becomes clickable again — but the
	# DICE STAY, showing what they landed on. A 1-roll session (the defensive
	# roll) has no SELECTING pause, so hiding them here blinked the result away
	# the instant it settled and the throw read as "no animation" (bug 65).
	# The whole roller is hidden by the match on the next non-roll phase.
	# The uncapped harness keeps its table.
	if _session_max_rolls > 0:
		_set_controls_visible(false)
	# Only the participating dice report a result. Built as a typed array —
	# slice() returns a plain Array, which can't cross a typed await boundary.
	var results : Array[int] = []
	for i in active_count:
		results.append(dice_result[i])
	rolling_finished.emit(results)


# The "table" = the interactive roll furniture PLUS the dice. Used to set the
# table for a session; teardown goes through _set_controls_visible so the dice
# can outlive it (see _finish_session).
func _set_table_visible(on : bool) -> void:
	_set_controls_visible(on)
	for index in dice:
		dice[index].visible = on and index < active_count


# Just the interactive furniture: the modal catcher (which blocks everything
# underneath while it's up) and the roll buttons. Hidden at session end so the
# scene can stay visible purely as a result display without blocking input.
func _set_controls_visible(on : bool) -> void:
	_click_catcher.visible = on
	_roll_button.visible = on
	_keep_button.visible = on


# --- roll result display -----------------------------------------------------

## Writes a roll into the result strip: one face sprite per die, from the
## character's face art (assets/art/Dice/<Character>/face). NEVER updated
## automatically — a finishing session doesn't touch it, so utility rolls
## (card/modifier effects) can run without overwriting the displayed phase
## roll. Callers decide what counts as THE result.
func display_result(values : Array[int], char_id : String) -> void:
	for child in roll_result.get_children():
		child.queue_free()
	var folder := char_id.substr(0, 1).to_upper() + char_id.substr(1)
	for value in values:
		var path := FACE_PATH % [folder, value]
		if not ResourceLoader.exists(path):
			push_warning("DiceRolling: missing face sprite %s" % path)
			continue
		var face := TextureRect.new()
		face.texture = load(path)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
		face.custom_minimum_size = RESULT_FACE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		roll_result.add_child(face)


## Empties and hides the result strip — a fresh roll window is starting and
## the previous phase's roll no longer applies.
func clear_result() -> void:
	for child in roll_result.get_children():
		child.queue_free()
	roll_result.hide()
	_roll_live = false


func set_result_visible(on : bool) -> void:
	roll_result.visible = on


func toggle_result() -> void:
	roll_result.visible = not roll_result.visible


# --- card interaction (bug 58) ------------------------------------------------
# Entry points for the dice-session board verbs. The match owns the "is a roll
# open to modification" flag (set after a roll settles, cleared when the skill is
# picked); a changed roll announces itself via roll_modified so the match can
# re-tally symbols and re-light the skills.

## The match's authority over whether the current roll may still be modified by a
## card (the post-roll, pre-skill-pick window). Play-gates read has_live_roll().
func set_roll_live(on : bool) -> void:
	_roll_live = on


func has_live_roll() -> bool:
	return _roll_live


## Every participating die's value as it stands right now — including any change a
## card made after the throw. The match reads this when it resolves a roll it let
## the player modify first (bug 56's upkeep).
func current_values() -> Array[int]:
	var results : Array[int] = []
	for i in active_count:
		results.append(dice_result[i])
	return results


# The payload the match refreshes off whenever a card rewrites the roll.
func _emit_modified() -> void:
	roll_modified.emit(current_values())


## Force die `index` to `value` (change_die_value / six_it). The value is logic
## (recorded at once); the die plays a quick "0-tween" snap to the chosen face.
func set_die(index : int, value : int) -> void:
	value = clampi(value, 1, SIDES)
	dice_result[index] = value
	dice[index].roll(value, true)   # fast path: snap onto the chosen face
	_emit_modified()


## Raise/lower a die by `delta`, clamped to a legal face (tip_it).
func bump_die(index : int, delta : int) -> void:
	set_die(index, clampi(dice_result[index] + delta, 1, SIDES))


## Copy one die's value onto another (samesies).
func copy_die(from_index : int, to_index : int) -> void:
	set_die(to_index, dice_result[from_index])


## Reroll a single die to a fresh random face with the full toss (try_try_again,
## and the owner side of helping_hand). Returns whether it happened — a refused
## reroll must not cost the caller whatever it was paying with (bug 69).
func reroll_die_at(index : int) -> bool:
	# Bug 71: taxed like any other reroll of your dice; refused if unaffordable.
	if reroll_gate.is_valid() and not reroll_gate.call():
		return false
	dice_result[index] = randi_range(1, SIDES)
	dice[index].roll(dice_result[index])
	_emit_modified()
	return true


## A card granted another roll attempt (one_more_time / better_d): decrease the
## roll counter by one and re-open the table on the dice as they lie for exactly
## one more reroll press, then announce the outcome.
func extra_roll_attempt() -> void:
	show()
	_set_table_visible(true)
	rolls_used = maxi(rolls_used - 1, 0)
	_session_max_rolls = rolls_used + 1   # headroom for exactly one more press
	re_roll_mask = 0
	phase = Phase.SELECTING
	for index in dice:
		update_die_visual(index)
	await rolling_finished
	_session_max_rolls = 0
	_emit_modified()


## A standalone roll of `count` dice for a card that rolls its own dice
## (vegas_baby, Pounce). There is only one set of dice in the scene, so this
## BORROWS them: the phase roll's values, count, phase and visibility are captured
## up front and restored afterwards, with each die snapped silently back to its
## recorded face. Without that, a card roll wiped the offensive roll's dice and
## left active_count wrong (bug 72). Never touches the live-roll flag.
func roll_fresh(count : int) -> Array[int]:
	var prev_result := dice_result.duplicate()
	var prev_count := active_count
	var prev_phase := phase
	var prev_visible := visible
	var prev_result_visible := roll_result.visible
	# The interactive furniture MUST be restored too. _set_table_visible(true)
	# below raises the full-rect modal ClickCatcher; leaving it up after the card's
	# roll swallows every click on this client while the opponent plays on — a
	# dead UI with no error to show for it (bug 72).
	var prev_catcher := _click_catcher.visible
	var prev_roll_btn := _roll_button.visible
	var prev_keep_btn := _keep_button.visible

	show()
	set_active_count(count)
	_set_table_visible(true)
	_roll_button.visible = false
	_keep_button.visible = false   # forced roll: watch only, no rerolls
	phase = Phase.ANIMATING
	re_roll_mask = 0
	for index in dice:
		update_die_visual(index)
	await toss_all(_active_mask())
	await gather_to_grid()
	var results : Array[int] = []
	for i in count:
		results.append(dice_result[i])

	# Hand the table back exactly as we found it.
	dice_result = prev_result
	set_active_count(prev_count)
	phase = prev_phase
	for i in prev_count:
		if dice_result[i] >= 1:
			# Fast path: snaps the face without emitting roll_modified, so the
			# match never mistakes a borrowed roll for a modified phase roll.
			dice[i].roll(dice_result[i], true)
	_click_catcher.visible = prev_catcher
	_roll_button.visible = prev_roll_btn
	_keep_button.visible = prev_keep_btn
	roll_result.visible = prev_result_visible
	visible = prev_visible
	return results


# --- interactive card pickers -------------------------------------------------

## choose_die: the player clicks one of their own dice on the table. Re-shows the
## modal catcher in single-pick mode and returns the chosen index.
func pick_own_die() -> int:
	var prev := phase
	_click_catcher.visible = true
	phase = Phase.PICKING
	var index : int = await _die_picked
	_click_catcher.visible = false
	phase = prev
	return index


## choose_die_value: pick a face 1-6 (so_wild, twice_as_wild).
func pick_value() -> int:
	return await _await_button_row("Set the die to…", [1, 2, 3, 4, 5, 6]) + 1


## choose_option: pick from a list of labels (tip_it: increase / decrease).
func pick_option(labels : Array) -> int:
	return await _await_button_row("Choose", labels)


# A transient modal button row (title + one button per label), centred over the
# dice. Returns the chosen index. Built in code — no scene dependency.
func _await_button_row(title_text : String, labels : Array) -> int:
	var overlay := Control.new()
	overlay.name = "ChoiceOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP   # modal: swallow board clicks
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in labels.size():
		var button := Button.new()
		button.text = str(labels[i])
		button.custom_minimum_size = Vector2(64, 44)
		button.pressed.connect(func() -> void: _choice_made.emit(i))
		row.add_child(button)

	show()
	var index : int = await _choice_made
	overlay.queue_free()
	return index


# --- spectating the opponent's roll (bug 58, helping_hand) ---------------------
# Only one side rolls per phase, so on the non-roller's client the roller is free
# to render the opponent's replicated roll (result strip only, non-modal so cards
# can still be played over it).

## Render the opponent's roll (its raw values, through their character's faces).
func show_spectated_roll(values : Array[int], char_id : String) -> void:
	_spectated_values = values.duplicate()
	show()
	_set_table_visible(false)   # their roll: strip only, our dice/controls stay away
	display_result(values, char_id)
	set_result_visible(true)


func clear_spectated_roll() -> void:
	_spectated_values = []
	clear_result()
	if phase == Phase.IDLE:
		hide()   # nothing of ours on the table either


func has_spectated_roll() -> bool:
	return not _spectated_values.is_empty()


## choose_opponent_die: pick which spectated die to force a reroll on. The big
## dice aren't ours to click here, so the faces are offered as a button row.
func pick_spectated_die() -> int:
	var labels : Array = []
	for i in _spectated_values.size():
		labels.append("Die %d  (%d)" % [i + 1, _spectated_values[i]])
	return await _await_button_row("Force opponent to reroll…", labels)


## force_opponent_reroll: announce the pick so the match relays it to the roll
## owner's client (which rerolls authoritatively).
func request_opponent_reroll(index : int) -> void:
	opponent_reroll_requested.emit(index)
