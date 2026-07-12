class_name Companion
extends Node

# A character's companion (companions.json) — deliberately tiny: health, plus
# a damage amplification the combat resolver consults when the owner attacks
# while the companion is active (TODO: resolver hookup).
#
# Two states: ACTIVE and DOWNED. She enters the match ACTIVE at start_hp.
# Depleting her HP downs her, and being downed is stickier than being hurt —
# she only returns to ACTIVE once healed back up to start_hp OR MORE (partial
# heals leave her downed). Bond-style tokens check is_active() for their
# spends.

enum State { ACTIVE, DOWNED }

signal health_changed(hp : int)
signal state_changed(state : State)

var companion_id : String
var companion_name : String
var max_hp : int = 1
var hp : int = 1
var recovery : int = 2       # bond heals restore this much
var damage_amp : int = 0     # the owner's attack bonus while active
var activation_hp : int = 5  # healed to this or more -> DOWNED ends (start_hp)
var state : State = State.ACTIVE


## Factory: the companion belonging to a character (e.g. "huntress" -> Nyra),
## fully initialised from the repository. Null when the character has none.
static func create_for_character(char_id : String) -> Companion:
	for entry in GameDataLoader.companion_repository.values():
		if entry.get("character_id", "") == char_id:
			return _from_entry(entry)
	return null


static func _from_entry(entry : Dictionary) -> Companion:
	var companion := Companion.new()
	companion.companion_id = entry.get("id", "")
	companion.companion_name = entry.get("name", "")
	companion.name = companion.companion_name
	var resources : Dictionary = entry.get("resources", {})
	companion.max_hp = int(resources.get("max_hp", 1))
	companion.hp = int(resources.get("start_hp", companion.max_hp))
	companion.recovery = int(resources.get("recovery", 2))
	companion.damage_amp = int(resources.get("damage_amp", 0))
	companion.activation_hp = int(resources.get("start_hp", companion.max_hp))
	return companion


func is_active() -> bool:
	return state == State.ACTIVE


func take_damage(amount : int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	health_changed.emit(hp)
	if hp == 0 and state == State.ACTIVE:
		state = State.DOWNED
		state_changed.emit(state)


func heal(amount : int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	health_changed.emit(hp)
	# Revival needs a full recovery: back to the activation threshold or more.
	if state == State.DOWNED and hp >= activation_hp:
		state = State.ACTIVE
		state_changed.emit(state)
