class_name TurnManager
extends Node

# The match-global turn state machine: exactly one (active player, phase) pair
# exists per match. Combatants and components REACT to the signals below (tick
# statuses on Upkeep, grant CP on Income, gate card plays by phase) — they
# never drive transitions themselves. Automatic phases emit and advance in the
# same frame; interactive phases hold until end_phase() (the End Phase button
# now, replicated remote transitions later — with GDSync only the local
# player's turn is driven here, the opponent's is mirrored).

signal turn_started(active : Combatant)
signal turn_ended(active : Combatant)
signal phase_entered(active : Combatant, phase : Phase)

enum Phase { UPKEEP, INCOME, MAIN_ONE, OFFENSIVE, TARGETING, DEFENSIVE, MAIN_TWO, DISCARD }

const PHASE_ORDER : Array[Phase] = [
	Phase.UPKEEP, Phase.INCOME, Phase.MAIN_ONE, Phase.OFFENSIVE,
	Phase.TARGETING, Phase.DEFENSIVE, Phase.MAIN_TWO, Phase.DISCARD,
]

# The phases that wait for a decision; the rest resolve automatically.
const INTERACTIVE_PHASES : Array[Phase] = [
	Phase.MAIN_ONE, Phase.OFFENSIVE, Phase.TARGETING,
	Phase.DEFENSIVE, Phase.MAIN_TWO, Phase.DISCARD,
]

## TARGETING only exists in multiplayer matches; it is skipped otherwise.
@export var multiplayer_match : bool = false

var active : Combatant
var phase : Phase = Phase.UPKEEP

var _running : bool = false
var _phase_done : bool = false   # end_phase() called during the entered emit
signal _advance                  # internal gate releasing an interactive phase


## Runs the turn loop until stop(): each combatant in order takes a full
## phase cycle, forever. Fire-and-forget from the match's _ready.
func start(turn_order : Array[Combatant]) -> void:
	if _running:
		push_error("TurnManager: start() called while already running")
		return
	if turn_order.is_empty():
		push_error("TurnManager: start() needs at least one combatant")
		return
	_running = true
	var turn := 0
	while _running:
		active = turn_order[turn % turn_order.size()]
		await _run_turn(active)
		turn += 1


## Ends the match loop (also releases a phase currently waiting, so the loop
## can actually exit).
func stop() -> void:
	_running = false
	_advance.emit()


## Advances out of the current interactive phase. Called by the End Phase
## button / auto-passing UI now, by replicated remote transitions later.
## Safe to call synchronously from inside a phase_entered handler.
func end_phase() -> void:
	if not _running:
		return
	_phase_done = true
	_advance.emit()


func _run_turn(combatant : Combatant) -> void:
	turn_started.emit(combatant)
	for p in PHASE_ORDER:
		if not _running:
			return
		if p == Phase.TARGETING and not multiplayer_match:
			continue
		phase = p
		_phase_done = false
		phase_entered.emit(combatant, p)
		# A handler may have already ended the phase during the emit (e.g. an
		# auto-pass); only park on the gate if it hasn't.
		if p in INTERACTIVE_PHASES and not _phase_done:
			await _advance
	if _running:
		turn_ended.emit(combatant)


## Whether a card is playable right now, from its data fields: `card_phase` is
## "main_phase" | "instant_action" | "roll_phase", `card_subtype` the
## offensive/defensive/any qualifier roll_phase cards carry. Placeholder rules
## — tighten alongside the real battle system (e.g. who may act in OFFENSIVE
## vs DEFENSIVE, instant timing windows).
func can_play(who : Combatant, card_phase : String, card_subtype : String = "") -> bool:
	match card_phase:
		"instant_action":
			return true
		"main_phase":
			return who == active and (phase == Phase.MAIN_ONE or phase == Phase.MAIN_TWO)
		"roll_phase":
			match card_subtype:
				"offensive":
					return phase == Phase.OFFENSIVE
				"defensive":
					return phase == Phase.DEFENSIVE
				_:
					return phase == Phase.OFFENSIVE or phase == Phase.DEFENSIVE
	return false
