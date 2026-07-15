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
enum Phase { IDLE, ANIMATING, SELECTING }

## A roll session ended — the roll budget ran out or Keep was pressed. Carries
## the recorded value of every die, by index.
signal rolling_finished(results : Array[int])

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
	if phase != Phase.SELECTING:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_viewport().world_2d.direct_space_state.intersect_point(query):
		for index in dice:
			# Hidden spare dice keep live ClickAreas — only active ones count.
			if index < active_count and dice[index].get_node("ClickArea") == hit.collider:
				flip_bit(index)
				update_die_visual(index)
				return


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
	# Capped sessions clean their own table away (dice, buttons, the modal
	# catcher), leaving the root — and the result strip — showable on its own.
	# The uncapped harness keeps its table.
	if _session_max_rolls > 0:
		_set_table_visible(false)
	# Only the participating dice report a result. Built as a typed array —
	# slice() returns a plain Array, which can't cross a typed await boundary.
	var results : Array[int] = []
	for i in active_count:
		results.append(dice_result[i])
	rolling_finished.emit(results)


# The "table" = the interactive roll furniture. Hidden between sessions so the
# scene can stay visible purely as a result display without blocking input.
func _set_table_visible(on : bool) -> void:
	_click_catcher.visible = on
	_roll_button.visible = on
	_keep_button.visible = on
	for index in dice:
		dice[index].visible = on and index < active_count


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


func set_result_visible(on : bool) -> void:
	roll_result.visible = on


func toggle_result() -> void:
	roll_result.visible = not roll_result.visible
