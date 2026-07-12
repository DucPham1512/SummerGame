class_name Targeted
extends StatusEffect

# Status effect — "Targeted" (negative, passive): attackers deal +2 attack
# damage to the holder. Purely a rule the damage resolution consults — the
# token itself does nothing actively.

## Consulted by the combat resolver when the holder is attacked.
const ATTACKER_BONUS := 2


func is_positive() -> bool:
	return false
