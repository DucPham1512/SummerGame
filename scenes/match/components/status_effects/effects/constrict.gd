class_name Constrict
extends StatusEffect

# Status effect — "Constrict" (negative, passive): during the holder's next
# Offensive Roll Phase, every roll attempt after the first costs 1 CP. The
# token leaves at the conclusion of that Roll Phase. The reroll surcharge is
# a rule the roll flow consults; the phase-end expiry is the hook below.

## Consulted by the offensive roll flow: CP owed per reroll while afflicted.
const EXTRA_ROLL_CP := 1


func is_positive() -> bool:
	return false


## Phase hook: the match calls this on the holder's tokens when their Roll
## Phase concludes (offensive through defensive).
func on_roll_phase_end(_ctx : BoardContext) -> void:
	remove_stacks(stacks)   # expires outright, whatever the stack count
