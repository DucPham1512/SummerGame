class_name TacticalAdvantage
extends StatusEffect

# Status effect — "Tactical Advantage" (positive, spendable): a token pool the
# tactician spends in tiers. 1: gain 1 CP, or re-roll one die. 3: draw 1 card,
# or inflict Targeted on the opponent. 4: gain Protect, or transfer a status
# (Main Phase only). All spends go through the spend popup, which lists every
# option and dims the ones the current stack count can't pay.


## What the status transfer costs, in stacks of this very token — which is why
## the transfer has to check whether paying would leave any of it to move.
const TRANSFER_COST := 4


func is_positive() -> bool:
	return true


func can_spend() -> bool:
	return stacks > 0


func spend_options(ctx : BoardContext) -> Array[Dictionary]:
	return [
		{
			"label": "1 — Gain 1 CP",
			"enabled": stacks >= 1,
			"action": _spend_gain_cp.bind(ctx),
		},
		{
			"label": "1 — Re-roll one of your dice",
			"enabled": stacks >= 1 and ctx.has_live_roll(),
			"action": _spend_reroll_die.bind(ctx),
		},
		{
			"label": "3 — Draw 1 card",
			"enabled": stacks >= 3,
			"action": _spend_draw.bind(ctx),
		},
		{
			"label": "3 — Inflict Targeted on the opponent",
			"enabled": stacks >= 3 and ctx.opponent != null,
			"action": _spend_inflict_targeted.bind(ctx),
		},
		{
			# "A chosen player gains Protect" — self for now; the chooser UI
			# arrives with the targeting flow.
			"label": "4 — Gain Protect",
			"enabled": stacks >= 4,
			"action": _spend_gain_protect.bind(ctx),
		},
		{
			# "From any player to any player"; in 1v1 what we can act on is our
			# own board, so this gives one of ours away (bug 69 decision).
			# NO phase gate: these tokens are spent "at any time", which makes this
			# an instant action — legal on the opponent's turn as much as our own.
			# (Gating it on the caster's own Main Phase was the main-phase CARD
			# rule, which is not what a spend-any-time token obeys.)
			"label": "4 — Give one of your status effects to the opponent",
			"enabled": stacks >= 4 and ctx.opponent != null
					and _holds_transferable(ctx.caster),
			"action": _spend_transfer_status.bind(ctx),
		},
	]


# Whether `who` carries anything the transfer could actually move. These very
# tokens pay for the spend, so they only count when paying would leave some
# behind — otherwise the option would charge 4 stacks and move nothing.
func _holds_transferable(who) -> bool:
	if who == null:
		return false
	for token in who.status_effects.values():
		if not token.transferable:
			continue
		if token == self and stacks - TRANSFER_COST <= 0:
			continue
		return true
	return false


func _spend_gain_cp(ctx : BoardContext) -> void:
	remove_stacks(1)
	ctx.gain_cp(1)


# The two interactive spends pay their tokens LAST, once the interaction has
# actually committed: backing out of the picker, or a reroll the Constrict
# surcharge refuses (bug 71), must not cost the player a stack for nothing.

func _spend_reroll_die(ctx : BoardContext) -> void:
	var index : int = await ctx.choose_die(ctx.caster)
	if index < 0:
		return                       # no die picked
	if not ctx.reroll_die(index):
		return                       # refused — the surcharge was unaffordable
	remove_stacks(1)


func _spend_transfer_status(ctx : BoardContext) -> void:
	var status_id : String = await ctx.choose_status(ctx.caster)
	if status_id.is_empty():
		return                       # nothing picked, or nothing transferable held
	# Picking these tokens is only legal if paying with them leaves any to move.
	if status_id == self.status_id and stacks - TRANSFER_COST <= 0:
		return
	remove_stacks(TRANSFER_COST)
	ctx.transfer_status(status_id, ctx.caster, ctx.opponent)


func _spend_draw(ctx : BoardContext) -> void:
	remove_stacks(3)
	ctx.draw_cards(1)


func _spend_inflict_targeted(ctx : BoardContext) -> void:
	remove_stacks(3)
	ctx.apply_status("targeted", 1, ctx.opponent)


func _spend_gain_protect(ctx : BoardContext) -> void:
	remove_stacks(4)
	ctx.apply_status("protect", 1, ctx.caster)
