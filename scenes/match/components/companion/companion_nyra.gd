class_name CompanionNyra
extends Node

# Nyra — the huntress's companion (companions.json). Deliberately tiny: health,
# plus an offensive amplification she applies to her owner's outgoing skill
# effect while active (amplify_offense). Companions are concrete objects with
# no shared base class — that's why this is named for Nyra rather than a
# generic "Companion" — so each future companion is its own file/class; the
# match just hands each attack to whatever companion the side has.
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
static func create_for_character(char_id : String) -> CompanionNyra:
	for entry in GameDataLoader.companion_repository.values():
		if entry.get("character_id", "") == char_id:
			return _from_entry(entry)
	return null


static func _from_entry(entry : Dictionary) -> CompanionNyra:
	var companion := CompanionNyra.new()
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


## Applies this companion's offensive amplification to its owner's outgoing
## skill effect, returning the bonus added (0 when downed, or the skill deals
## no damage — the bonus rides existing damage "to deal damage to the other
## player", it doesn't turn a utility skill into an attack). The rule lives
## here because companions vary; the match just hands over the effect.
func amplify_offense(effect : SkillEffect) -> int:
	if not is_active() or damage_amp <= 0 or effect.damage <= 0:
		return 0
	effect.damage += damage_amp
	return damage_amp


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


## Netcode receiver path: absolute replicated values from the owning client.
## State comes along explicitly — hp alone can't distinguish a partial heal
## (still DOWNED) from never having been downed.
func sync_state(new_hp : int, new_state : State) -> void:
	hp = clampi(new_hp, 0, max_hp)
	health_changed.emit(hp)
	if state != new_state:
		state = new_state
		state_changed.emit(state)
