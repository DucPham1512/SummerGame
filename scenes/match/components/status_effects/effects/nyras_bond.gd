class_name NyrasBond
extends StatusEffect

# Status effect — "Nyra's Bond" (positive, spendable). Two spends:
#   * While Nyra is active and an attack's damage is incoming: freely
#     distribute that damage between the Huntress and Nyra (the popup's
#     split-slider stage).
#   * Any time: heal Nyra by her recovery (2 HP).


func is_positive() -> bool:
	return true


func can_spend() -> bool:
	return stacks > 0


func spend_options(ctx : BoardContext) -> Array[Dictionary]:
	var nyra : Companion = ctx.caster.companion if ctx.caster != null else null
	var nyra_active := nyra != null and nyra.is_active()
	return [
		{
			"label": "Share the incoming damage with Nyra",
			"enabled": stacks > 0 and nyra_active and ctx.incoming_damage > 0,
			"kind": "split",
			"damage": ctx.incoming_damage,
			"split_with": nyra.companion_name if nyra != null else "Nyra",
			"on_confirm": _spend_split.bind(ctx, nyra),
		},
		{
			"label": "Heal Nyra (+%d HP)" % (nyra.recovery if nyra != null else 2),
			"enabled": stacks > 0 and nyra != null and nyra.hp < nyra.max_hp,
			"action": _spend_heal.bind(nyra),
		},
	]


# on_confirm is called (own_share, other_share); ctx and nyra ride in as
# bound arguments after those.
func _spend_split(own_share : int, nyra_share : int, ctx : BoardContext, nyra : Companion) -> void:
	remove_stacks(1)
	ctx.caster.change_health(-own_share)
	nyra.take_damage(nyra_share)


func _spend_heal(nyra : Companion) -> void:
	remove_stacks(1)
	nyra.heal(nyra.recovery)
