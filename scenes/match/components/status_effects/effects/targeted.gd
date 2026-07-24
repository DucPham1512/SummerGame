class_name Targeted
extends StatusEffect

# Status effect — "Targeted" (negative, passive): attackers deal +2 attack
# damage to the holder. Purely a rule the damage resolution consults — the
# token itself does nothing actively.
#
# Fires only for a declared attack in an opponent's Offensive Roll Phase, never
# for counter damage, card effects or Upkeep ticks. It is not spent by
# triggering and never expires: only a removal/transfer card takes it off.

## Consulted by the combat resolver when the holder is attacked.
const ATTACKER_BONUS := 2


func is_positive() -> bool:
	return false


## The +2 the attacker gains. Flat rather than per-stack: the description reads
## "+2 attack damage" and the token's stack limit is 1.
func attack_damage_bonus() -> int:
	return ATTACKER_BONUS
