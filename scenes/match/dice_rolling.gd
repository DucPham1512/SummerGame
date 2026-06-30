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

# Selection semantics: a SET bit (1) in re_roll_mask means the die is SELECTED and
# WILL be rerolled; a CLEAR bit (0) means it is kept/locked and will NOT reroll.
enum Phase { IDLE, ANIMATING, SELECTING }

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

var dice_result: Array[int] = []   # last rolled value per die (logic record)
var re_roll_mask: int = 0          # which dice are selected for reroll (bit per index)
var phase: Phase = Phase.IDLE
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
	start_roll()   # auto-toss as soon as the scene loads


# Evenly spaced, horizontally centered row. Computed once; each die index maps
# to the same slot every time.
func _compute_slots() -> void:
	_slots.clear()
	var viewport := get_viewport_rect().size
	var total_width := GRID_SPACING * float(DICE_COUNT - 1)
	var start_x := viewport.x * 0.5 - total_width * 0.5
	var y := viewport.y * 0.5
	for i in DICE_COUNT:
		_slots.append(Vector2(start_x + GRID_SPACING * float(i), y))


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
# clicked die (no off-by-one).
func _on_die_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, index: int) -> void:
	if phase != Phase.SELECTING:
		return   # selection only allowed once dice have settled in the grid
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		flip_bit(index)
		update_die_visual(index)


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
	await _park_unselected_to_corner()
	await get_tree().create_timer(REROLL_PAUSE).timeout
	# Drop the selection tint so the rerolling dice animate normally.
	for index in dice:
		dice[index].modulate = Color.WHITE
	await toss_all(re_roll_mask)
	await gather_to_grid()
	# Fresh selection round: clear marks/visuals so the player can pick again.
	re_roll_mask = 0
	phase = Phase.SELECTING
	for index in dice:
		update_die_visual(index)


# --- Sequencing ------------------------------------------------------------

## First full roll: toss all five, then gather to the grid.
func start_roll() -> void:
	phase = Phase.ANIMATING
	# Fresh roll: nothing selected — the player explicitly picks what to reroll.
	re_roll_mask = 0
	for index in dice:
		update_die_visual(index)
	await toss_all(0b11111)
	await gather_to_grid()
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
