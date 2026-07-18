extends AnimatedSprite2D

## Emitted when the roll animation finishes, carrying the rolled result (1-6).
signal roll_finished(result: int)

# Frame mapping (0-indexed): frames 0-3 = result 1, 4-7 = result 2, ... 20-23 = result 6.
# Frame 24 is the blank/idle die. If a face shows the wrong number, this is the
# knob to change — verify the art order matches and adjust accordingly.
const FRAMES_PER_RESULT := 4
const SIDES := 6
const IDLE_FRAME := SIDES * FRAMES_PER_RESULT   # 24, the blank die

@export var toss_height_min: float = 120.0
@export var toss_height_max: float = 240.0
## How far from its slot a die lands after the throw (± px, x and y). The
## gather phase then slides it back to the slot.
@export var toss_scatter: float = 70.0
@export var roll_time: float = 0.5
@export var spin_turns: float = 2.0
## How many random faces flash during the toss. Higher = faster flicker
## (more changes packed into the same roll_time).
@export var flicker_count: int = 12
## For the final N flickers the die holds one chosen result frame and only its
## rotation animates (via the spin), instead of swapping faces — so it locks onto
## a single image and rotates into place before settling.
@export var lock_in_flickers: int = 4

var _base_x: float
var _base_y: float
var _rolling: bool = false
var _last_flicker_step: int = -1
var _result: int = 1
var _final_frame: int = 0


func _ready() -> void:
	_base_y = position.y
	frame = IDLE_FRAME


## Rolls the die. Pass 1-6 to force a result (e.g. from networked game logic),
## or leave default for a local random roll. The result is authoritative; the
## animation is pure presentation and never changes it. `fast` snaps onto the
## chosen face almost instantly (a card forcing a value — bug 58), skipping the
## toss arc and spin.
func roll(result: int = -1, fast: bool = false) -> void:
	if _rolling:
		return
	_rolling = true
	if result < 1 or result > SIDES:
		result = randi_range(1, SIDES)
	_animate_roll(result, fast)


func _frame_for_result(result: int) -> int:
	var base := (result - 1) * FRAMES_PER_RESULT   # 0, 4, 8, ...
	return base + randi_range(0, FRAMES_PER_RESULT - 1)   # one of the 4 orientations


func _animate_roll(result: int, fast: bool = false) -> void:
	_result = result
	var final_frame := _frame_for_result(result)
	_final_frame = final_frame
	# Spin a whole number of turns so the die settles upright (no resting rotation).
	var final_angle := 0.0
	# A forced value snaps in place: no spin, no arc, near-zero duration — just a
	# brief face flicker before it locks onto the chosen frame.
	var spin := 0.0 if fast else TAU * spin_turns
	var dur := (0.08 if fast else roll_time) * randf_range(0.85, 1.15)
	var toss_height := 0.0 if fast else randf_range(toss_height_min, toss_height_max)

	rotation = 0.0
	_base_x = position.x   # toss arcs relative to wherever the die currently sits
	_base_y = position.y
	_last_flicker_step = -1

	# The throw lands at a random spot near the start; the gather slides it back.
	# A fast (forced) snap has no gather after it, so it must land where it sits.
	var scatter := 0.0 if fast else toss_scatter
	var landing_x := _base_x + randf_range(-scatter, scatter)
	var landing_y := _base_y + randf_range(-scatter, scatter)

	var tween := create_tween().set_parallel(true)
	# Toss up to the apex, then down to the landing spot (not back to the start).
	tween.tween_property(self, "position:y", _base_y - toss_height, dur * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", landing_y, dur * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(dur * 0.5)
	# Drift across to the landing spot's x over the whole arc.
	tween.tween_property(self, "position:x", landing_x, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Spin across the whole toss, decelerating onto the resting angle.
	tween.tween_property(self, "rotation", spin, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Flicker faces while airborne (purely cosmetic). Ease-out so the face swaps
	# start rapid and decelerate toward the settle — a slot-machine slowdown.
	tween.tween_method(_flicker, 0, flicker_count, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Settle on the chosen frame/angle once everything above finishes.
	tween.chain().tween_callback(_settle.bind(final_frame, final_angle, result))


func _flicker(step: int) -> void:
	# tween_method calls this every render frame; only swap the face when the
	# integer step advances, so flicker_count actually controls the number of changes.
	if step == _last_flicker_step:
		return
	_last_flicker_step = step
	if step >= flicker_count - lock_in_flickers:
		# Locked in: hold the single chosen frame; only its rotation animates now.
		frame = _final_frame
	else:
		frame = randi_range(0, SIDES * FRAMES_PER_RESULT - 1)   # any random face


func _settle(final_frame: int, final_angle: float, result: int) -> void:
	frame = final_frame
	rotation = final_angle
	_rolling = false
	roll_finished.emit(result)
