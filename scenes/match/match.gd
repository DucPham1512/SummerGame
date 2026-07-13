extends Control

@export var MatchResult : PackedScene

## Income Phase (rules 1.2): CP granted at the start of every turn but the
## match's very first.
const INCOME_CP := 1

@onready var player : Combatant = $Player
@onready var opponent : Combatant = $Opponent
@onready var turn_manager : TurnManager = $TurnManager
@onready var phase_label : Label = $PhaseLabel
@onready var next_phase_button : Button = $NextPhase
@onready var player_skill_layout : SkillLayout = $Player/SkillLayout
@onready var opponent_skill_layout : SkillLayout = $Opponent/SkillLayout
@onready var dice_roller : Control = $DiceRolling
@onready var deck_and_hand : Control = $Player/DeckAndHand

## The recorded result of this turn's offensive roll (raw face values).
var offensive_roll : Array[int] = []
## The defender's single defensive roll this turn (raw face values).
var defensive_roll : Array[int] = []
## The announced Offensive Ability's target-requiring remainder (damage +
## inflictions), carried from the offensive roll into the defensive phase.
var _pending_attack : SkillEffect = null


func _ready() -> void:
	turn_manager.phase_entered.connect(_on_phase_entered)
	turn_manager.turn_started.connect(_on_turn_started)
	player_skill_layout.skill_chosen.connect(_on_skill_chosen)
	# Defense picks can come from either board: the defender's own board in
	# multiplayer, the mirror's board in the solo demo.
	opponent_skill_layout.skill_chosen.connect(_on_skill_chosen)
	deck_and_hand.card_sold.connect(_on_card_sold)
	# Neither board shows until the first turn declares whose it is.
	player_skill_layout.hide()
	opponent_skill_layout.hide()
	# MatchSync starts the turn loop: it waits for both clients, gets the
	# host's first-turn coin flip, and starts the mirrored orders (or starts
	# immediately, player first, when the scene runs without a lobby).


# Only the active side's skill board is on screen: they occupy the same
# centre-of-board space, so they swap with the turn.
func _on_turn_started(active : Combatant) -> void:
	player_skill_layout.visible = active == player
	opponent_skill_layout.visible = active == opponent
	_pending_attack = null   # nothing announced yet this turn


func _on_phase_entered(active : Combatant, phase : TurnManager.Phase) -> void:
	phase_label.text = "%s — %s" % [active.name, TurnManager.Phase.keys()[phase].capitalize()]
	# Visual cue: the button is live only in windows this side controls.
	next_phase_button.disabled = not _my_phase_window() and not _is_solo()
	# Roll-window furniture (dice, result strip, skill selections, the
	# defender board swap) belongs to the OFFENSIVE -> DEFENSIVE stretch;
	# any other phase clears it and restores the active side's board.
	if phase != TurnManager.Phase.OFFENSIVE and phase != TurnManager.Phase.DEFENSIVE:
		dice_roller.hide()
		player_skill_layout.clear_selection()
		opponent_skill_layout.clear_selection()
		player_skill_layout.visible = active == player
		opponent_skill_layout.visible = active == opponent
	match phase:
		TurnManager.Phase.UPKEEP:
			# Automatic. Start-of-turn ticks: status tokens trigger (bleed
			# rolls, etc.), but ONLY for the local player — the opponent's
			# upkeep runs on their client (their RNG) and its results arrive
			# as replicated absolutes; rolling their mirror here would
			# diverge. Placeholder context for now — verbs like roll_die /
			# deal_damage warn until the real Board lands. Note the loop
			# doesn't wait for this (fire-and-forget): async upkeeps need the
			# TurnManager hold mechanism when they matter.
			if active == player:
				var ctx := BoardContext.new()
				ctx.caster = player
				ctx.opponent = opponent
				player.run_upkeep(ctx)
		TurnManager.Phase.INCOME:
			# Automatic (1.2): +1 CP (clamped at max) and draw 1 — the draw
			# refills an empty deck from the discard pile first. The start
			# player skips income entirely on the match's very first turn.
			if turn_manager.turn_count <= 1:
				pass
			elif active == player:
				(player as Player).update_player_cp(INCOME_CP)
				deck_and_hand.draw_cards(1)
			elif _is_solo():
				# Local demo only. In multiplayer their client does this and
				# the results replicate — mirroring here would double-count
				# the (delta-based) drew event.
				(opponent as Opponent).on_opponent_cp(opponent.cp + INCOME_CP)
				(opponent as Opponent).on_opponent_drew(1)
		TurnManager.Phase.MAIN_ONE:
			# Interactive. Open the play window: main_phase cards become legal
			# (gate drops in deck_and_hand via turn_manager.can_play).
			pass
		TurnManager.Phase.OFFENSIVE:
			# Interactive. The attacker's roll window: throw the skill dice
			# (Util.max_dice_rolls budget), record the result, then open the
			# skill pick on the roller's board. Local side only — the
			# opponent's roll runs on their client. TODO(netcode): replicate
			# the roll/pick so the other side can watch it happen.
			# A fresh roll window: whatever roll was on display belongs to a
			# previous phase — empty the strip before anything new happens.
			dice_roller.clear_result()
			offensive_roll = []
			if active == player:
				_run_offensive_roll()
		TurnManager.Phase.TARGETING:
			# Interactive, multiplayer only (skipped otherwise): the active
			# player picks which opponent the attack lands on.
			pass
		TurnManager.Phase.DEFENSIVE:
			# Interactive — the DEFENDER's window (1.6). No announced attack:
			# the attacker skips the phase outright. With one, the defender's
			# side runs the defensive roll flow (the attacker's client just
			# waits). TODO(netcode): the attack announcement isn't replicated
			# yet, so in multiplayer the defender client can't know about it.
			if _pending_attack == null:
				if active == player or _is_solo():
					_end_phase_networked()
			elif active != player or _is_solo():
				_run_defensive_roll()
		TurnManager.Phase.MAIN_TWO:
			# Interactive. Second play window (1.7), same rules as MAIN_ONE.
			# An attack the defender left undefended resolves on the way in
			# (1.6: applied at the roll phase's conclusion).
			_resolve_pending_attack()
		TurnManager.Phase.DISCARD:
			# Interactive (1.8): the active player sells down to the hand
			# limit (+1 CP each, via the sell zone); the phase ends itself
			# once compliant — checked here and after every sale. Only the
			# active side ends its own discard; the remote hears the
			# replicated end_phase.
			_try_finish_discard()


# The offensive roll flow: dice UI up, one capped roll session (first toss +
# rerolls), record the result, then light up every skill the roll can pay on
# the player's board. Picking one fires _on_skill_chosen; the player may also
# just end the phase without activating anything.
func _run_offensive_roll() -> void:
	# run() shows the roller and packs the table away when the session ends;
	# the root stays visible carrying the result strip.
	offensive_roll = await dice_roller.run(Util.max_dice_rolls)
	# The phase may have been ended while the dice were still out.
	if turn_manager.phase != TurnManager.Phase.OFFENSIVE:
		return
	# THE phase roll goes on display. Utility rolls (card/modifier effects)
	# just run() without calling display_result, so they never overwrite it.
	dice_roller.display_result(offensive_roll, player_skill_layout.character)
	dice_roller.set_result_visible(true)
	var symbols := _tally_symbols(offensive_roll, player_skill_layout.character)
	player_skill_layout.enable_selection(symbols, offensive_roll)


# Face values -> {symbol: count} through the character's die (dice.json).
func _tally_symbols(values : Array[int], character : String) -> Dictionary:
	var faces : Dictionary = {}
	for die in GameDataLoader.dice_repository.values():
		if die.get("character_id", "") == character:
			faces = die.get("faces", {})
			break
	var counts : Dictionary = {}
	for value in values:
		var symbol : String = faces.get(str(value), "")
		if not symbol.is_empty():
			counts[symbol] = counts.get(symbol, 0) + 1
	return counts


# The defender's flow (1.6): their board comes up (the defensive skill lives
# in slot 8, bottom right, by kit convention), its dice_count dictates the
# throw, and the roll happens ONCE — no rerolls. The result stays on display
# WITHOUT resolving, so cards can still alter the dice; the (sole activatable)
# defensive skill resolves it when pressed.
func _run_defensive_roll() -> void:
	var defender_board : SkillLayout = opponent_skill_layout if turn_manager.active == player \
			else player_skill_layout
	defender_board.show()
	var defensive_skill : Skill = defender_board.defensive_skill()
	if defensive_skill == null:
		return   # no defensive ability on this board (bare base layout)
	var dice_count := int(defensive_skill.dice_cost.get("dice_count", 1))
	defensive_roll = await dice_roller.run(1, dice_count)   # single roll, no rerolls
	if turn_manager.phase != TurnManager.Phase.DEFENSIVE:
		return
	dice_roller.display_result(defensive_roll, defender_board.character)
	dice_roller.set_result_visible(true)
	defender_board.enable_only(defensive_skill)


# The defender pressed their defensive skill: activate it with the defensive
# roll, apply its outcomes (counter damage on the attacker, companion heals
# and statuses on the defender), then the attack lands — attack and defense
# resolving together (1.6 — simultaneous at the phase's end).
func _on_defense_activated(skill : Skill) -> void:
	player_skill_layout.clear_selection()
	opponent_skill_layout.clear_selection()
	var defender : Combatant = opponent if turn_manager.active == player else player
	var attacker : Combatant = turn_manager.active
	var board : SkillLayout = opponent_skill_layout if defender == opponent else player_skill_layout
	var ctx := BoardContext.new()
	ctx.caster = defender
	ctx.opponent = attacker
	ctx.roll_values = defensive_roll.duplicate()
	ctx.roll_symbols = _tally_symbols(defensive_roll, board.character)
	# Overrides may await mid-activation rolls; the base isn't a coroutine.
	@warning_ignore("redundant_await")
	var defense : SkillEffect = await skill.activate(ctx)
	print("[skills] defense activated: %s | roll %s | counter %d | companion heal %d" % [
			skill.skill_id, defensive_roll, defense.damage, defense.heal_companion])
	if defense.damage > 0:
		if attacker == player:
			(player as Player).update_player_health(-defense.damage)
		else:
			(opponent as Opponent).on_opponent_health(opponent.health - defense.damage)
	if defense.heal_companion > 0 and defender.companion != null:
		defender.companion.heal(defense.heal_companion)
	for status in defense.grant_to_self:
		defender.apply_status(status.status_id, status.stacks)
	for status in defense.inflict_on_opponent:
		attacker.apply_status(status.status_id, status.stacks)
	# Countermeasures-style prevention shaves the announced attack down
	# before it lands (attack and defense resolve together, 1.6).
	if _pending_attack != null and defense.prevent_damage > 0:
		var before : int = _pending_attack.damage
		_pending_attack.damage = maxi(before - defense.prevent_damage, 0)
		print("[skills] defense prevented %d damage (%d -> %d)" % [
				defense.prevent_damage, before, _pending_attack.damage])
	_resolve_pending_attack()
	_end_phase_networked()


# The announced attack's target-requiring effects land on the defender —
# damage and inflictions. Runs when the defense resolves, or undefended on
# the way into MAIN_TWO. No-op when nothing is pending.
func _resolve_pending_attack() -> void:
	if _pending_attack == null:
		return
	var defender : Combatant = opponent if turn_manager.active == player else player
	for status in _pending_attack.inflict_on_opponent:
		defender.apply_status(status.status_id, status.stacks)
	if _pending_attack.damage > 0:
		if defender == player:
			(player as Player).update_player_health(-_pending_attack.damage)
		else:
			(opponent as Opponent).on_opponent_health(opponent.health - _pending_attack.damage)
	_pending_attack = null


func _on_skill_chosen(skill : Skill) -> void:
	# During the defensive window the pick IS the defense.
	if turn_manager.phase == TurnManager.Phase.DEFENSIVE:
		_on_defense_activated(skill)
		return
	player_skill_layout.clear_selection()
	var ctx := BoardContext.new()
	ctx.caster = player
	ctx.opponent = opponent
	ctx.roll_values = offensive_roll.duplicate()
	ctx.roll_symbols = _tally_symbols(offensive_roll, player_skill_layout.character)
	# Overrides may await mid-activation rolls (Savage's branch die); the
	# base isn't a coroutine, hence the static-analysis ignore.
	@warning_ignore("redundant_await")
	var skill_effect : SkillEffect = await skill.activate(ctx)
	# Rules 1.4 step 3: effects that need no target resolve immediately.
	for status in skill_effect.grant_to_self:
		player.apply_status(status.status_id, status.stacks)
	if skill_effect.heal_companion > 0 and player.companion != null:
		player.companion.heal(skill_effect.heal_companion)
	if skill_effect.draw_cards > 0:
		await deck_and_hand.draw_cards(skill_effect.draw_cards)
	# Limit changes and max-outs must work from an empty board too (Higher
	# Ground grants max TA whether or not the player already holds any):
	# create the token at 0 stacks when it's missing.
	for status_id in skill_effect.stack_limit_delta:
		var token : StatusEffect = player.get_status(status_id)
		if token == null:
			token = player.apply_status(status_id, 0)
		token.stack_limit += int(skill_effect.stack_limit_delta[status_id])
	for status_id in skill_effect.max_out_self:
		var token : StatusEffect = player.get_status(status_id)
		if token == null:
			token = player.apply_status(status_id, 0)
		token.add_stacks(token.stack_limit)   # clamps to the (raised) limit
	# The target-requiring remainder is the Attack: it waits for the
	# defensive phase (1.6). TODO(netcode): announce the activation to the
	# defender's client.
	if skill_effect.damage > 0 or not skill_effect.inflict_on_opponent.is_empty():
		_pending_attack = skill_effect
	var self_ids : Array[String] = []
	for status in skill_effect.grant_to_self:
		self_ids.append("%s x%d" % [status.status_id, status.stacks])
	var inflict_ids : Array[String] = []
	for status in skill_effect.inflict_on_opponent:
		inflict_ids.append("%s x%d" % [status.status_id, status.stacks])
	print("[skills] activated: %s | damage %d | self %s | inflict %s | limit deltas %s | max out %s | attack pending: %s" % [
			skill.skill_id, skill_effect.damage, self_ids, inflict_ids,
			skill_effect.stack_limit_delta, skill_effect.max_out_self,
			_pending_attack != null])
	# Announcing the ability concludes the roll window: on to targeting /
	# defensive without needing a Next Phase press — unless the effect grants
	# an additional Offensive Roll Phase (Profiteer's medal branch): same
	# window, fresh roll session, new pick.
	if turn_manager.phase == TurnManager.Phase.OFFENSIVE:
		if skill_effect.extra_offensive_phase:
			print("[skills] extra offensive roll phase granted")
			dice_roller.clear_result()
			offensive_roll = []
			_run_offensive_roll()
		else:
			_end_phase_networked()


func _on_next_phase_pressed() -> void:
	# Each side advances only the windows it controls (see _my_phase_window);
	# the guard is skipped without a second client so the button can drive
	# both sides in local testing.
	if not _my_phase_window() and not _is_solo():
		return
	_end_phase_networked()


# The phase windows this client owns: the active player's own turn — except
# DEFENSIVE, which belongs to the DEFENDER (rules 1.6).
func _my_phase_window() -> bool:
	if turn_manager.phase == TurnManager.Phase.DEFENSIVE:
		return turn_manager.active != player
	return turn_manager.active == player


func _is_solo() -> bool:
	return GDSync.lobby_get_player_count() < 2


# Ends the current phase on both clients: locally at once, remotely via the
# replicated call (matching NodePaths land it on their mirrored TurnManager).
func _end_phase_networked() -> void:
	print("[match] ending phase: %s (%s active)" % [
			TurnManager.Phase.keys()[turn_manager.phase], turn_manager.active.name])
	turn_manager.end_phase()
	GDSync.call_func(turn_manager.end_phase)


# DISCARD (1.8) completes itself once the active side's hand is at the limit;
# checked on phase entry and again after every sale.
func _try_finish_discard() -> void:
	if turn_manager.phase != TurnManager.Phase.DISCARD:
		return
	if turn_manager.active == player:
		if deck_and_hand.hand.get_hand_size() <= Util.one_v_one_hand_limit:
			_end_phase_networked()
	elif _is_solo():
		_end_phase_networked()   # nobody drives the mirror's discard locally


func _on_card_sold(_slot : int, _card_id : String) -> void:
	_try_finish_discard()


func _on_end_match_button_down() -> void:
	turn_manager.stop()
	GDSync.lobby_leave()
	get_tree().change_scene_to_packed(MatchResult)
