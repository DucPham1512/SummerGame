class_name TacticalAdvantage
extends StatusEffect

# Status effect — "Tactical Advantage" (positive, spendable): a token pool the
# tactician spends in tiers. 1: gain 1 CP, or re-roll one die. 3: draw 1 card,
# or inflict Targeted on the opponent. 4: gain Protect, or transfer a status
# (Main Phase only). All spends go through the spend popup, which lists every
# option and dims the ones the current stack count can't pay.


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
			# TODO: needs the dice session hookup (pick a die, reroll it).
			"label": "1 — Re-roll one of your dice (not implemented)",
			"enabled": false,
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
			# TODO: needs a status/player picker + Main Phase gating.
			"label": "4 — Transfer a status effect (not implemented)",
			"enabled": false,
		},
	]


func _spend_gain_cp(ctx : BoardContext) -> void:
	remove_stacks(1)
	ctx.gain_cp(1)


func _spend_draw(ctx : BoardContext) -> void:
	remove_stacks(3)
	ctx.draw_cards(1)


func _spend_inflict_targeted(ctx : BoardContext) -> void:
	remove_stacks(3)
	ctx.apply_status("targeted", 1, ctx.opponent)


func _spend_gain_protect(ctx : BoardContext) -> void:
	remove_stacks(4)
	ctx.apply_status("protect", 1, ctx.caster)
