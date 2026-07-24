extends Control

@export var MatchResult : PackedScene

## Income Phase (rules 1.2): CP granted at the start of every turn but the
## match's very first.
const INCOME_CP := 1

## How long the match freezes between someone hitting 0 and the verdict. We
## apply our own damage synchronously but hear the opponent's HP over the
## network, so a double-KO (rules 1.6 resolves the attack and the counter
## together) lands as two separate zeroes in opposite orders on the two
## clients. Judging the first one would call it a Defeat on BOTH screens and
## never a Draw; this beat lets the other side's HP land so both clients read
## the same final pair and agree.
const RESULT_SETTLE := 0.3

@onready var player : Combatant = $Player
@onready var opponent : Combatant = $Opponent
@onready var turn_manager : TurnManager = $TurnManager
@onready var phase_label : Label = $PhaseLabel
@onready var next_phase_button : Button = $NextPhase
@onready var player_skill_layout : SkillLayout = $Player/SkillLayout
@onready var opponent_skill_layout : SkillLayout = $Opponent/SkillLayout
@onready var dice_roller : Control = $DiceRolling
@onready var deck_and_hand : Control = $Player/DeckAndHand
@onready var match_sync : MatchSync = $MatchSync
@onready var spend_popup : StatusSpendPopup = $StatusSpendPopup
@onready var player_status_row : StatusRow = $Player/PlayerResourceContainer/StatusRow
@onready var damage_counter : DamageCounter = $DamageCounter

## The recorded result of this turn's offensive roll (raw face values).
var offensive_roll : Array[int] = []
## The defender's single defensive roll this turn (raw face values).
var defensive_roll : Array[int] = []
## The announced Offensive Ability's target-requiring remainder (damage +
## inflictions), carried from the offensive roll into the defensive phase.
## On the DEFENDER's client this is the incoming attack (rebuilt from the
## attacker's announce); solo keeps it on the attacker's own client.
var _pending_attack : SkillEffect = null
## Attacker's client (multiplayer): an attack has been announced and we're
## waiting for the defender to resolve it — they own the DEFENSIVE window and
## drive it to MAIN_TWO. Solo never sets this (it uses _pending_attack).
var _awaiting_defense : bool = false
## The attack we have DECLARED this offensive phase but not yet sent: the chosen
## skill's target-facing remainder, still open to attack modifiers (Pounce /
## Prowl). Dispatched once, with its final numbers, when the phase ends — "all
## damage is calculated at the end of the phase". Null when no attack is on the
## table, which is also what gates the modifier cards.
var _outgoing_attack : SkillEffect = null
## Latched the moment the match is decided: stops the second combatant's zero
## (or a peer leaving on the way out) from re-deciding an outcome we already
## have, and freezes the phase flow while the verdict settles.
var _match_over : bool = false
## Bug 56 — the Upkeep's status dice are on the table and the player is free to
## alter them (tip_it) before anything resolves. Next Phase is their "done".
var _upkeep_awaiting_confirm : bool = false
## The upkeep dice are mid-throw: Next Phase must not end the phase before the
## roll they're meant to confirm even exists.
var _upkeep_rolling : bool = false
signal _upkeep_confirmed


func _ready() -> void:
	turn_manager.phase_entered.connect(_on_phase_entered)
	turn_manager.turn_started.connect(_on_turn_started)
	player_skill_layout.skill_chosen.connect(_on_skill_chosen)
	# Defense picks can come from either board: the defender's own board in
	# multiplayer, the mirror's board in the solo demo.
	opponent_skill_layout.skill_chosen.connect(_on_skill_chosen)
	deck_and_hand.card_sold.connect(_on_card_sold)
	# Death watch. Every way HP can reach 0 — Player.update_player_health,
	# Opponent.on_opponent_health, Combatant.change_health (cards, Nyra's Bond)
	# — ends in health_changed on one of these two, so this is a complete cut.
	# (Nyra is deliberately not watched: she isn't a Combatant, and 0 HP downs
	# her rather than losing the match.)
	player.health_changed.connect(_on_combatant_health_changed)
	opponent.health_changed.connect(_on_combatant_health_changed)
	# Spending our own tokens (bug 60: Nyra's Bond heal any time; also TA). The
	# opponent's mirror row stays display-only. Depleted tokens are swept when
	# the popup closes.
	player_status_row.token_pressed.connect(_on_own_token_pressed)
	spend_popup.closed.connect(_on_spend_popup_closed)
	# Dice cards (bug 58) reach the live roll through the roller: a card verb that
	# changes the roll re-lights the skills via roll_modified, and helping_hand's
	# pick becomes a cross-client forced reroll via opponent_reroll_requested.
	deck_and_hand.dice_roller = dice_roller
	# Cards aimed at the opponent (bug 72): the hand needs to know who that is, and
	# their effects are announced to the opponent's own client rather than written
	# to our mirror.
	deck_and_hand.opponent = opponent
	deck_and_hand.card_effect_on_opponent.connect(_on_card_effect_on_opponent)
	# Attack modifiers (Pounce / Prowl): legal only once an attack is declared, and
	# they fold into that attack rather than hitting on their own.
	deck_and_hand.attack_modifier_gate = _attack_modifier_playable
	deck_and_hand.attack_modifier_added.connect(_on_attack_modifier_added)
	dice_roller.roll_modified.connect(_on_roll_modified)
	dice_roller.opponent_reroll_requested.connect(_on_opponent_reroll_requested)
	# Constrict (bug 71): every reroll of our own offensive dice consults this,
	# paying 1 CP each while the token is held and refusing when we can't.
	dice_roller.reroll_gate = _constrict_reroll_gate
	# Neither board shows until the first turn declares whose it is.
	player_skill_layout.hide()
	opponent_skill_layout.hide()
	# MatchSync starts the turn loop: it waits for both clients, gets the
	# host's first-turn coin flip, and starts the mirrored orders (or starts
	# immediately, player first, when the scene runs without a lobby).


# --- playtest character assignment ------------------------------------------------
# No character-selection scene yet: MatchSync assigns the lobby host the
# tactician and the guest the huntress (host = tactician on both clients'
# mirrored views), calling in here once the tree is ready.

const LAYOUT_SCENES := {
	"tactician": "res://scenes/match/components/skills/Tactician/tactician_skill_layout.tscn",
	"huntress": "res://scenes/match/components/skills/Huntress/huntress_skill_layout.tscn",
}
const HEALTH_BAR_SCENE := "res://scenes/match/components/health_bar/health_bar.tscn"


## Gives each side its character: the right skill board (all slots at stage
## 0), each combatant's deck, and — for the huntress side — Nyra plus her HP
## bar (limit 7, same bar as the players').
##
## Decks initialize from a deck code/hash ("id,id,..."). The optional
## parameters are the placeholder for the future deck-building/selection
## feature: pass the players' saved codes there; empty falls back to the
## character's default playtest deck (all commons + the character's cards,
## one copy each).
func assign_characters(player_char : String, opponent_char : String,
		player_deck_code : String = "", opponent_deck_code : String = "") -> void:
	player_skill_layout = _swap_layout(player, player_skill_layout, player_char)
	opponent_skill_layout = _swap_layout(opponent, opponent_skill_layout, opponent_char)
	deck_and_hand.skill_layout = player_skill_layout
	_setup_companion(player, player_char)
	_setup_companion(opponent, opponent_char)
	# Opening kit tokens (bug 68: the tactician's 2 Tactical Advantage). Each board
	# declares its own, so this stays character-agnostic. Applied on both sides of
	# both clients — deterministic, and the status broadcast replaces absolutes
	# rather than adding, so the mirror lands on the same count.
	player_skill_layout.apply_starting_statuses(player)
	opponent_skill_layout.apply_starting_statuses(opponent)
	if player_deck_code.is_empty():
		player_deck_code = deck_and_hand.character_deck_code(player_char)
	if opponent_deck_code.is_empty():
		opponent_deck_code = deck_and_hand.character_deck_code(opponent_char)
	deck_and_hand.initialize_deck(player_deck_code)
	# The deck's composition is public knowledge (only its order is private),
	# so the mirror's pile counter starts at the opponent's real deck size.
	opponent.set_deck_count(opponent_deck_code.split(",").size())
	print("[match] characters assigned: player=%s opponent=%s" % [player_char, opponent_char])


# Replaces a side's skill board with `char_id`'s layout scene in the same box
# (anchors, offsets, rotation — the opponent's board is turned 180°). Keeps
# the node when the placeholder already is that character. The fresh board
# inherits the placeholder's name, visibility and the skill_chosen wiring.
func _swap_layout(side : Combatant, current : SkillLayout, char_id : String) -> SkillLayout:
	if current.character == char_id:
		return current
	var fresh : SkillLayout = (load(LAYOUT_SCENES[char_id]) as PackedScene).instantiate()
	var slot_name := current.name
	current.name = slot_name + "_replaced"
	fresh.name = slot_name
	side.add_child(fresh)
	side.move_child(fresh, current.get_index())
	fresh.set_anchors_preset(Control.PRESET_TOP_LEFT)   # clear instance defaults
	fresh.anchor_left = current.anchor_left
	fresh.anchor_top = current.anchor_top
	fresh.anchor_right = current.anchor_right
	fresh.anchor_bottom = current.anchor_bottom
	fresh.offset_left = current.offset_left
	fresh.offset_top = current.offset_top
	fresh.offset_right = current.offset_right
	fresh.offset_bottom = current.offset_bottom
	fresh.grow_horizontal = current.grow_horizontal
	fresh.grow_vertical = current.grow_vertical
	fresh.rotation = current.rotation
	fresh.visible = current.visible
	fresh.skill_chosen.connect(_on_skill_chosen)
	current.queue_free()
	return fresh


# The huntress side gets Nyra (ACTIVE at 5/7) and her HP bar; other
# characters have no companion and this is a no-op.
func _setup_companion(side : Combatant, char_id : String) -> void:
	var companion := CompanionNyra.create_for_character(char_id)
	if companion == null:
		return
	side.add_child(companion)
	side.companion = companion
	_add_companion_bar(side, companion)


# Nyra's HP bar: the players' health bar scene reused at companion scale,
# sitting to the right of the side's resource bars (Player = bottom band,
# Opponent = top band), with a name/HP/state label.
func _add_companion_bar(side : Combatant, companion : CompanionNyra) -> void:
	var wrapper := Control.new()
	wrapper.name = "CompanionBar"
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(wrapper)
	if side == player:
		wrapper.anchor_top = 0.994
		wrapper.anchor_bottom = 0.994
		wrapper.offset_top = -125.0
	else:
		wrapper.anchor_top = 0.006
		wrapper.anchor_bottom = 0.006
		wrapper.offset_top = 10.0
	wrapper.offset_left = 750.0
	wrapper.offset_right = 1150.0
	wrapper.offset_bottom = wrapper.offset_top + 50.0

	var bar : TextureProgressBar = (load(HEALTH_BAR_SCENE) as PackedScene).instantiate()
	bar.scale = Vector2(0.45, 0.45)
	wrapper.add_child(bar)
	bar.track_companion(companion)

	var label := Label.new()
	label.position = Vector2(310.0, 12.0)
	wrapper.add_child(label)
	var refresh := func(_arg = null) -> void:
		label.text = "%s  %d / %d%s" % [companion.companion_name, companion.hp,
				companion.max_hp, "" if companion.is_active() else "  (DOWNED)"]
	companion.health_changed.connect(refresh)
	companion.state_changed.connect(refresh)
	refresh.call()


# Exactly one skill board may ever be on screen: the two occupy the same
# centre-of-board space, and their roots are MOUSE_FILTER_STOP — so whichever
# is shown, the other MUST be hidden or it covers it and eats its clicks
# (bug 65: the attacker's board swallowed the defender's ability press).
func _show_only_board(board : SkillLayout) -> void:
	player_skill_layout.visible = board == player_skill_layout
	opponent_skill_layout.visible = board == opponent_skill_layout


# Only the active side's skill board is on screen: they occupy the same
# centre-of-board space, so they swap with the turn.
func _on_turn_started(active : Combatant) -> void:
	player_skill_layout.visible = active == player
	opponent_skill_layout.visible = active == opponent
	_pending_attack = null       # nothing announced yet this turn
	_awaiting_defense = false
	_outgoing_attack = null      # no attack declared and awaiting modifiers
	_upkeep_awaiting_confirm = false   # no upkeep of ours is mid-resolution
	_upkeep_rolling = false
	_refresh_incoming_damage()   # a fresh turn: the incoming-damage readout resets to 0


func _on_phase_entered(active : Combatant, phase : TurnManager.Phase) -> void:
	phase_label.text = "%s — %s" % [active.name, TurnManager.Phase.keys()[phase].capitalize()]
	# Visual cue: the button is live only in windows this side controls — and
	# not while the Discard Phase still owes cards (rules 1.8).
	next_phase_button.disabled = not _next_phase_available()
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
			# Interactive (bug 56). Start-of-turn status ticks: the tokens that
			# declare upkeep resolution throw their dice, which then sit on the
			# table for instant-action cards to alter before anything resolves —
			# the player presses Next Phase when done. ONLY for the local player:
			# the opponent's upkeep rolls on their client (their RNG) and its
			# results arrive as replicated absolutes; rolling their mirror here
			# would diverge.
			if active == player:
				_run_upkeep()
			elif _is_solo():
				_end_phase_networked()   # the mirror has no local upkeep to run
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
			# Interactive — the DEFENDER's window (1.6). The attacker announces
			# the attack (multiplayer) so it lands here on the defender's own
			# client, which resolves it against itself and drives the phase to
			# MAIN_TWO. The attacker just waits it out.
			if _is_solo():
				# Local demo: one client runs both sides off _pending_attack.
				if _pending_attack != null:
					_run_defensive_roll()
				else:
					_end_phase_networked()
			elif active == player:
				# Attacker's client: wait for the defender to resolve an
				# announced attack; with nothing out, there's no defense to
				# wait for, so pass the phase.
				if not _awaiting_defense:
					_end_phase_networked()
			elif _pending_attack != null:
				# Defender's client: an announced attack is incoming — roll to
				# defend. (No incoming attack: nothing to do; the attacker
				# passes the phase for both sides.)
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


# --- upkeep (bug 56) ------------------------------------------------------------

# The Upkeep flow: throw every die this side's upkeep-resolving tokens need, leave
# them on the table LIVE so instant-action cards (tip_it) can alter them, and only
# resolve the tokens — against the final values — once the player presses Next
# Phase. Resolving where the dice landed would make those cards pointless.
func _run_upkeep() -> void:
	var ctx := UpkeepContext.new(self)
	ctx.caster = player
	ctx.opponent = opponent
	# Clamped to the roller's five dice; Bleed's stack limit of 2 keeps it well under.
	var needed : int = mini(player.upkeep_dice_needed(), 5)
	if needed > 0:
		_upkeep_rolling = true
		next_phase_button.disabled = true   # nothing to confirm until it lands
		# Same shape as the defensive roll: one throw, no rerolls, dice stay out.
		var values : Array[int] = await dice_roller.run(1, needed)
		_upkeep_rolling = false
		if _match_over or turn_manager.phase != TurnManager.Phase.UPKEEP:
			return
		dice_roller.display_result(values, player_skill_layout.character)
		dice_roller.set_result_visible(true)
		dice_roller.set_roll_live(true)   # tip_it's OWN roll_need guard now passes
		_broadcast_spectate(values)
		print("[match] upkeep: threw %d die/dice %s" % [needed, values])
	# The player acts (instant cards); Next Phase is their confirmation.
	_upkeep_awaiting_confirm = true
	next_phase_button.disabled = not _next_phase_available()
	await _upkeep_confirmed
	if _match_over or turn_manager.phase != TurnManager.Phase.UPKEEP:
		return
	dice_roller.set_roll_live(false)   # the window is closed; these values are final
	if needed > 0:
		ctx.seed_rolls(dice_roller.current_values())
		_broadcast_spectate([])
	await player.run_upkeep(ctx)
	_end_phase_networked()


# Board verbs for the Upkeep Phase, replacing the placeholder context whose
# roll_die returned 0 and whose deal_damage did nothing — which is why Bleed never
# hurt anyone and (rolling a permanent "0") could never expire. The dice are thrown
# and possibly card-modified BEFORE any hook runs, so roll_die hands back those
# final values in order rather than rolling afresh; the status effects themselves
# stay unchanged and unaware.
class UpkeepContext extends BoardContext:
	var _match
	var _rolls : Array[int] = []
	var _next : int = 0

	func _init(m) -> void:
		_match = m

	## Hands the context the final dice, in throw order.
	func seed_rolls(values : Array[int]) -> void:
		_rolls = values.duplicate()
		_next = 0

	func roll_die() -> int:
		if _next < _rolls.size():
			var value : int = _rolls[_next]
			_next += 1
			return value
		# A status asked for more dice than its upkeep_dice_per_stack() declared.
		# Roll rather than hand back a silent 0 (the placeholder's exact bug), and
		# say so, since the declaration is what the match sized the throw from.
		push_warning("UpkeepContext: more roll_die() calls than dice thrown — rolling ad hoc")
		return randi_range(1, 6)

	func deal_damage(amount : int, target = null) -> void:
		var who = target if target != null else caster
		if who == _match.player:
			# Through Player so the HP label updates and the absolute broadcasts.
			(_match.player as Player).update_player_health(-amount)
		else:
			who.change_health(-amount)

	func heal(amount : int, target = null) -> void:
		var who = target if target != null else caster
		if who == _match.player:
			(_match.player as Player).update_player_health(amount)
		else:
			who.change_health(amount)

	func apply_status(status_id : String, stacks : int = 1, target = null) -> void:
		var who = target if target != null else caster
		who.apply_status(status_id, stacks)


# The offensive roll flow: dice UI up, one capped roll session (first toss +
# rerolls), record the result, then light up every skill the roll can pay on
# the player's board. Picking one fires _on_skill_chosen; the player may also
# just end the phase without activating anything.
func _run_offensive_roll() -> void:
	# run() shows the roller and packs the table away when the session ends;
	# the root stays visible carrying the result strip.
	offensive_roll = await dice_roller.run(Util.max_dice_rolls)
	# The phase may have been ended — or the match decided — while the dice
	# were still out. stop() doesn't cancel this coroutine, so check both.
	if _match_over or turn_manager.phase != TurnManager.Phase.OFFENSIVE:
		return
	# THE phase roll goes on display. Utility rolls (card/modifier effects)
	# just run() without calling display_result, so they never overwrite it.
	dice_roller.display_result(offensive_roll, player_skill_layout.character)
	dice_roller.set_result_visible(true)
	var symbols := _tally_symbols(offensive_roll, player_skill_layout.character)
	player_skill_layout.enable_selection(symbols, offensive_roll)
	# Bug 58: the roll is now open to card modification, and replicated so the
	# other player can watch it (and target it with helping_hand).
	dice_roller.set_roll_live(true)
	_broadcast_spectate(offensive_roll)


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
	# The defender's board must come up ALONE: the two boards share the centre
	# of the screen, so leaving the attacker's up would cover this one and
	# swallow the click that activates the ability (bug 65).
	_show_only_board(defender_board)
	var defensive_skill : Skill = defender_board.defensive_skill()
	if defensive_skill == null:
		return   # no defensive ability on this board (bare base layout)
	var dice_count := int(defensive_skill.dice_cost.get("dice_count", 1))
	print("[match] defensive roll: %s throws %d dice" % [defensive_skill.skill_id, dice_count])
	defensive_roll = await dice_roller.run(1, dice_count)   # single roll, no rerolls
	# Same as the offensive roll: the match may have been decided mid-throw.
	if _match_over or turn_manager.phase != TurnManager.Phase.DEFENSIVE:
		return
	dice_roller.display_result(defensive_roll, defender_board.character)
	dice_roller.set_result_visible(true)
	defender_board.enable_only(defensive_skill)
	# Bug 58: cards may still alter the defensive roll, and the attacker watches it.
	dice_roller.set_roll_live(true)
	_broadcast_spectate(defensive_roll)


# --- bug 58: a card changed the live roll --------------------------------------

# A card verb (change / reroll / extra attempt) rewrote the roll. Re-record it,
# re-display it, and re-light the skills the new roll can pay so the pick reflects
# reality. Only the side that OWNS the current roll acts; the change also
# re-broadcasts to the spectating opponent.
func _on_roll_modified(results : Array) -> void:
	if _match_over:
		return
	var values : Array[int] = []
	for v in results:
		values.append(int(v))
	match turn_manager.phase:
		TurnManager.Phase.UPKEEP:
			# Bug 56: an instant-action card altered a status die. Nothing to
			# re-light here — the new value is simply what the upkeep will resolve
			# against when the player confirms.
			if turn_manager.active != player:
				return
			dice_roller.display_result(values, player_skill_layout.character)
			dice_roller.set_result_visible(true)
			_broadcast_spectate(values)
		TurnManager.Phase.OFFENSIVE:
			if turn_manager.active != player:
				return   # not our roll
			offensive_roll = values
			dice_roller.display_result(values, player_skill_layout.character)
			dice_roller.set_result_visible(true)
			var symbols := _tally_symbols(values, player_skill_layout.character)
			player_skill_layout.enable_selection(symbols, values)
			_broadcast_spectate(values)
		TurnManager.Phase.DEFENSIVE:
			if turn_manager.active == player:
				return   # we're the attacker, not the one rolling
			defensive_roll = values
			dice_roller.display_result(values, player_skill_layout.character)
			dice_roller.set_result_visible(true)
			var defense := player_skill_layout.defensive_skill()
			if defense != null:
				player_skill_layout.enable_only(defense)
			_broadcast_spectate(values)


# Constrict (bug 71): while the local player holds it, each reroll of their own
# dice during their Offensive Roll Phase costs 1 CP; with none to pay, the reroll
# is refused. Consulted by the dice roller before any reroll proceeds; returns
# whether it may. Only our own offensive rerolls are taxed — defensive and upkeep
# throws are single-roll anyway, and the opponent's rerolls run on their client.
func _constrict_reroll_gate() -> bool:
	if turn_manager.phase != TurnManager.Phase.OFFENSIVE or turn_manager.active != player:
		return true
	if not player.has_status("constrict"):
		return true
	if player.cp < Constrict.EXTRA_ROLL_CP:
		return false
	(player as Player).update_player_cp(-Constrict.EXTRA_ROLL_CP)
	print("[match] Constrict: reroll cost %d CP (cp now %d)" % [Constrict.EXTRA_ROLL_CP, player.cp])
	return true


# Replicate our current roll to the other client so they can watch it (and target
# it with helping_hand); an empty list clears their view. Solo has no spectator.
func _broadcast_spectate(values : Array) -> void:
	if _is_solo():
		return
	match_sync.broadcast_spectate_roll(values, player_skill_layout.character)


# We played helping_hand: relay the forced reroll to the roll owner's client.
# Solo has no opponent client to drive, so this never fires there.
func _on_opponent_reroll_requested(die_index : int) -> void:
	if _is_solo():
		return
	match_sync.announce_force_reroll(die_index)


# The defender pressed their defensive skill: activate it with the defensive
# roll, apply its outcomes (counter damage on the attacker, companion heals
# and statuses on the defender), then the attack lands — attack and defense
# resolving together (1.6 — simultaneous at the phase's end).
func _on_defense_activated(skill : Skill) -> void:
	player_skill_layout.clear_selection()
	opponent_skill_layout.clear_selection()
	dice_roller.set_roll_live(false)   # committing to the defense closes card mods
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
	# Self-facing effects apply on this (the defender's) client directly.
	if defense.heal_companion > 0 and defender.companion != null:
		defender.companion.heal(defense.heal_companion)
	for status in defense.grant_to_self:
		defender.apply_status(status.status_id, status.stacks)
	# Attacker-facing effects (counter damage + inflictions): solo applies them
	# here; multiplayer announces them to the real attacker, who applies them on
	# their own client (and broadcasts the resulting HP back to our mirror).
	if _is_solo():
		if defense.damage > 0:
			if attacker == player:
				(player as Player).update_player_health(-defense.damage)
			else:
				(opponent as Opponent).on_opponent_health(opponent.health - defense.damage)
		for status in defense.inflict_on_opponent:
			attacker.apply_status(status.status_id, status.stacks)
	else:
		var counter_ids : Array = []
		var counter_stacks : Array = []
		for status in defense.inflict_on_opponent:
			counter_ids.append(status.status_id)
			counter_stacks.append(status.stacks)
		match_sync.announce_defense_result(defense.damage, defense.undefendable, counter_ids, counter_stacks)
	# Countermeasures-style prevention shaves the announced attack down
	# before it lands (attack and defense resolve together, 1.6).
	if _pending_attack != null and defense.prevent_damage > 0:
		var before : int = _pending_attack.damage
		_pending_attack.damage = maxi(before - defense.prevent_damage, 0)
		print("[skills] defense prevented %d damage (%d -> %d)" % [
				defense.prevent_damage, before, _pending_attack.damage])
		_refresh_incoming_damage()   # prevention shaved the incoming attack
	# Bug 60: the huntress may send the landing damage to Nyra (or split it).
	await _offer_damage_transfer(defender)
	_resolve_pending_attack()
	_broadcast_spectate([])   # our defensive roll is spent — clear the attacker's view
	_end_phase_networked()


# The huntress's defensive damage-transfer choice (bug 60), offered once the
# defence has resolved and the final incoming damage is known — after pressing
# the defensive skill, per the rules. Only when WE are the defender with an
# active companion, there's damage to take, and Nyra can either survive the
# whole hit or a Nyra's Bond allows a split. Applies the chosen shares and
# zeroes the pending damage so _resolve_pending_attack doesn't apply it again
# (it still applies the attack's inflicted statuses).
func _offer_damage_transfer(defender : Combatant) -> void:
	if _pending_attack == null or defender != player:
		return
	var n : int = _pending_attack.damage
	var nyra : CompanionNyra = player.companion
	if n <= 0 or nyra == null or not nyra.is_active():
		return
	var bond_held := player.has_status("nyras_bond")
	if n > nyra.hp and not bond_held:
		return   # she can't survive it and no Bond to split — the player just takes it
	spend_popup.open_transfer(n, nyra.hp, nyra.companion_name, bond_held)
	var shares : Array = await spend_popup.transfer_decided
	var player_share : int = shares[0]
	var nyra_share : int = shares[1]
	var used_bond : bool = shares[2]
	if player_share > 0:
		(player as Player).update_player_health(-player_share)
	if nyra_share > 0:
		nyra.take_damage(nyra_share)
	if used_bond:
		player.remove_status_stacks("nyras_bond", 1)
	_pending_attack.damage = 0
	_refresh_incoming_damage()   # damage routed to Nyra: none of it is incoming any more
	print("[match] damage transfer: you %d / %s %d%s" % [
			player_share, nyra.companion_name, nyra_share, " (Bond)" if used_bond else ""])


# --- spending our own tokens (bug 60: Nyra's Bond heal any time; also TA) --------

func _on_own_token_pressed(token : StatusEffect) -> void:
	# The same context an instant-action card resolves through (bug 69): a token
	# spendable "at any time" needs the dice session and the opponent-announce
	# path just as much as a card does.
	var ctx : BoardContext = deck_and_hand.make_board_context(player)
	ctx.incoming_damage = 0   # spending outside a defence: no damage to split
	spend_popup.open(token, ctx)


# Backstop. Spends announce their own stack changes now (bug 81), so the row and
# the netcode are already current by the time the popup closes; this just sweeps
# anything a spend left at 0 without going through the token.
func _on_spend_popup_closed() -> void:
	for status_id in player.status_effects.keys():
		player.remove_status_stacks(status_id, 0)   # 0-removal just runs the purge


# The announced attack's target-requiring effects land on the defender —
# damage and inflictions. Runs when the defense resolves, or undefended on
# the way into MAIN_TWO. No-op when nothing is pending.
func _resolve_pending_attack() -> void:
	if _pending_attack == null:
		return
	var defender : Combatant = _attack_defender()
	for status in _pending_attack.inflict_on_opponent:
		defender.apply_status(status.status_id, status.stacks)
	if _pending_attack.damage > 0:
		if defender == player:
			(player as Player).update_player_health(-_pending_attack.damage)
		else:
			(opponent as Opponent).on_opponent_health(opponent.health - _pending_attack.damage)
	_pending_attack = null
	_refresh_incoming_damage()   # the attack has landed: nothing incoming now


# Who a declared attack lands on: the side that is NOT taking the turn. Both the
# resolution above and the Targeted amplification below derive it the same way.
func _attack_defender() -> Combatant:
	return opponent if turn_manager.active == player else player


## Targeted (bug 70): a declared attack against a token holder lands harder.
## Applied as the attack hits the table — BEFORE the defensive phase — so the
## bonus is defendable, as the Tactician's description requires. The attack's OWN
## inflictions count, since an attack applies its statuses before its damage
## resolves (Higher Ground inflicts Targeted and boosts its own hit). Only
## declared attacks reach here: counter damage, card effects and Upkeep ticks are
## other paths and stay unboosted.
func _amplify_attack_for_defender(effect : SkillEffect, defender : Combatant) -> void:
	if effect == null or defender == null or effect.damage <= 0:
		return
	var bonus : int = defender.incoming_attack_bonus(effect.inflict_on_opponent)
	if bonus <= 0:
		return
	print("[match] Targeted: attack amplified %d -> %d" % [effect.damage, effect.damage + bonus])
	effect.damage += bonus


# --- incoming-damage readout (PBI 89) --------------------------------------------
# A central label showing the current declared attack's damage against whoever is
# defending this turn, so a player can read the threat as it is built and defended.

# The attack in flight against the defender: whichever of the declared
# (_outgoing_attack) or on-the-table (_pending_attack) attack exists. Pending wins —
# an attack only ever moves outgoing -> pending, never both at once. 0 when none.
func _current_incoming_attack() -> int:
	if _pending_attack != null:
		return _pending_attack.damage
	if _outgoing_attack != null:
		return _outgoing_attack.damage
	return 0


# Push the live total to the central readout. Called wherever the attack's damage is
# set, modified, cleared or resolved, so the number tracks the turn and resets to 0
# between turns. The label reads "Damage dealt" on our own turn and "Incoming damage"
# on the opponent's, keyed off who is active.
func _refresh_incoming_damage() -> void:
	damage_counter.show_damage(_current_incoming_attack(), turn_manager.active == player)


# --- networked combat resolution (multiplayer) ------------------------------------
# The attack is computed on the attacker's client but resolved on the
# DEFENDER's — each client stays authoritative over its own HP, and the
# resulting absolute values converge via the existing health broadcasts. Both
# receivers derive their side from the turn state (the caller is always the
# other combatant).

## Defender's client: the attacker announced their attack. Rebuild it as a
## pending attack so the normal DEFENSIVE flow resolves it against this side
## (defend to reduce/counter it, or eat it undefended into MAIN_TWO).
func receive_incoming_attack(damage : int, undefendable : bool, status_ids : Array, status_stacks : Array) -> void:
	var effect := SkillEffect.new()
	effect.damage = damage
	effect.undefendable = undefendable
	for i in status_ids.size():
		effect.inflict_on_opponent.append(StatusEffect.new(status_ids[i], int(status_stacks[i])))
	# We are the defender here and own our tokens authoritatively, so the Targeted
	# bonus is computed on this client — before the defensive phase, so it can be
	# defended against. The attacker announced its raw damage.
	_amplify_attack_for_defender(effect, _attack_defender())
	_pending_attack = effect
	_refresh_incoming_damage()   # an attack is on the table against us
	print("[match] incoming attack announced: %d damage, %d status(es)" % [damage, status_ids.size()])


## Attacker's client: the defender's defense resolved. Apply its
## attacker-facing results — counter damage and inflicted statuses — to our own
## (the attacker's) side; the HP change broadcasts back as an absolute.
func receive_defense_result(counter_damage : int, _undefendable : bool, status_ids : Array, status_stacks : Array) -> void:
	_awaiting_defense = false
	if counter_damage > 0:
		(player as Player).update_player_health(-counter_damage)
	for i in status_ids.size():
		player.apply_status(status_ids[i], int(status_stacks[i]))
	print("[match] defense result: %d counter damage taken, %d status(es)" % [counter_damage, status_ids.size()])


# A card we played lands damage/statuses on the OPPONENT (bug 72). Their side is
# authoritative on their own client, so announce it there; solo has no second
# client, so the mirror is applied directly.
func _on_card_effect_on_opponent(damage : int, status_ids : Array, status_stacks : Array) -> void:
	if _is_solo():
		if damage > 0:
			(opponent as Opponent).on_opponent_health(opponent.health - damage)
		for i in status_ids.size():
			opponent.apply_status(status_ids[i], int(status_stacks[i]))
		return
	match_sync.announce_card_effect(damage, status_ids, status_stacks)


## A card the opponent played lands on US. Applied to our own side authoritatively
## — the resulting HP/tokens broadcast back as absolutes like anything else.
func receive_card_effect(damage : int, status_ids : Array, status_stacks : Array) -> void:
	if _match_over:
		return
	if damage > 0:
		(player as Player).update_player_health(-damage)
	for i in status_ids.size():
		player.apply_status(status_ids[i], int(status_stacks[i]))
	print("[match] opponent's card hit us for %d, %d status(es)" % [damage, status_ids.size()])


## The other client showed us their live roll (or an empty list to clear it), so
## we can spectate it and target it with helping_hand (bug 58).
func on_spectate_roll(values : Array, char_id : String) -> void:
	if _match_over:
		return
	if values.is_empty():
		dice_roller.clear_spectated_roll()
		return
	var typed : Array[int] = []
	for v in values:
		typed.append(int(v))
	dice_roller.show_spectated_roll(typed, char_id)


## A helping_hand from the other client: reroll one of OUR dice — but only while
## our roll is still open (they may have played it just after we moved on). The
## reroll fires our own roll_modified, so our skills re-light and the new roll
## re-broadcasts to them.
func receive_force_reroll(die_index : int) -> void:
	if _match_over or not dice_roller.has_live_roll():
		return
	dice_roller.reroll_die_at(die_index)


func _on_skill_chosen(skill : Skill) -> void:
	# During the defensive window the pick IS the defense.
	if turn_manager.phase == TurnManager.Phase.DEFENSIVE:
		_on_defense_activated(skill)
		return
	player_skill_layout.clear_selection()
	dice_roller.set_roll_live(false)   # committing to a skill closes card mods
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
	# A stack_limit change goes straight at the token and is not a stack count,
	# so nothing announces it — this one has to say so itself.
	for status_id in skill_effect.stack_limit_delta:
		var token : StatusEffect = player.get_status(status_id)
		if token == null:
			token = player.apply_status(status_id, 0)
		token.stack_limit += int(skill_effect.stack_limit_delta[status_id])
		player.notify_status_changed(token)
	for status_id in skill_effect.max_out_self:
		var token : StatusEffect = player.get_status(status_id)
		if token == null:
			token = player.apply_status(status_id, 0)
		token.add_stacks(token.stack_limit)   # clamps to the (raised) limit, announces itself
	# Character-specific offensive modifiers (bug 61): the active player's board
	# transforms the outgoing skill effect (the huntress's Nyra adds +2 damage
	# while active; the tactician no-ops). Offense-only — this handler bails to
	# defense above. match.gd stays character-agnostic here.
	player_skill_layout.apply_offense_modifiers(skill_effect, player)
	# The target-requiring remainder is the Attack: it waits for the
	# defensive phase (1.6). Solo keeps it locally; multiplayer announces it
	# to the defender, who owns the DEFENSIVE window and resolves it against
	# their own (authoritative) side.
	# An attack (damage and/or an infliction on the opponent) is DECLARED, not sent:
	# it stays open to attack modifiers until the phase ends, then goes out once
	# with its final numbers. A non-attack ability leaves nothing to modify.
	var attack_out := skill_effect.damage > 0 or not skill_effect.inflict_on_opponent.is_empty()
	if attack_out:
		_outgoing_attack = skill_effect
		_refresh_incoming_damage()   # an attack is declared against the defender
	var self_ids : Array[String] = []
	for status in skill_effect.grant_to_self:
		self_ids.append("%s x%d" % [status.status_id, status.stacks])
	var inflict_ids : Array[String] = []
	for status in skill_effect.inflict_on_opponent:
		inflict_ids.append("%s x%d" % [status.status_id, status.stacks])
	print("[skills] activated: %s | damage %d | self %s | inflict %s | limit deltas %s | max out %s | attack out: %s" % [
			skill.skill_id, skill_effect.damage, self_ids, inflict_ids,
			skill_effect.stack_limit_delta, skill_effect.max_out_self,
			attack_out])
	# Choosing the ability no longer ends the phase: attack modifiers are played
	# AFTER the attack is declared, so the window has to stay open. The player
	# advances with Next Phase, which is what dispatches the finished attack.
	# Profiteer's medal branch still re-opens the roll in the same window.
	if turn_manager.phase == TurnManager.Phase.OFFENSIVE and skill_effect.extra_offensive_phase:
		print("[skills] extra offensive roll phase granted")
		dice_roller.clear_result()
		offensive_roll = []
		_run_offensive_roll()


# --- attack modifiers (Pounce / Prowl) -------------------------------------------
# A modifier improves the attack you have ALREADY declared this phase, so the
# attack is held from the moment the skill is chosen until the phase ends, and
# only then goes out — carrying the modified totals in one announce.

# The declared attack leaves the table. Solo resolves it locally; multiplayer
# announces the FINAL numbers to the defender, who owns the defensive window.
func _dispatch_outgoing_attack() -> void:
	if _outgoing_attack == null:
		return
	var effect := _outgoing_attack
	_outgoing_attack = null
	if _is_solo():
		# Solo runs both sides here, so the amplification happens on this path.
		# Multiplayer announces raw damage instead and the DEFENDER amplifies it
		# in receive_incoming_attack — so the bonus is only ever applied once.
		_amplify_attack_for_defender(effect, _attack_defender())
		_pending_attack = effect
	else:
		_awaiting_defense = true
		var ids : Array = []
		var stacks : Array = []
		for status in effect.inflict_on_opponent:
			ids.append(status.status_id)
			stacks.append(status.stacks)
		match_sync.announce_attack(effect.damage, effect.undefendable, ids, stacks)
	print("[skills] attack sent: %d damage%s, %d status(es)" % [
			effect.damage, " (undefendable)" if effect.undefendable else "",
			effect.inflict_on_opponent.size()])
	# Solo now holds the amplified pending attack; the MP attacker has handed it off
	# and holds nothing, so its readout drops to 0.
	_refresh_incoming_damage()


# A modifier card resolved: fold it into the declared attack. Only the numbers
# move — `undefendable` is never rewritten, so a modifier can't change the damage
# type (6 undefendable + 3 = 9 undefendable).
func _on_attack_modifier_added(damage : int, status_ids : Array, status_stacks : Array) -> void:
	if _outgoing_attack == null:
		push_warning("Match: attack modifier resolved with no declared attack — ignored")
		return
	_outgoing_attack.damage += damage
	for i in status_ids.size():
		_outgoing_attack.inflict_on_opponent.append(
				StatusEffect.new(status_ids[i], int(status_stacks[i])))
	print("[cards] attack modifier: +%d damage, %d status(es) -> attack now %d" % [
			damage, status_ids.size(), _outgoing_attack.damage])
	_refresh_incoming_damage()   # Pounce / Prowl grew the declared attack


# Whether an attack modifier may be played right now: our own declared attack is
# still on the table. Consulted by the hand before a modifier card is paid for.
func _attack_modifier_playable() -> bool:
	return _outgoing_attack != null and turn_manager.active == player


func _on_next_phase_pressed() -> void:
	if not _next_phase_available():
		return
	# Bug 56: during the Upkeep the press means "I'm done acting". The status
	# effects still have to resolve — against the dice as they NOW stand, after any
	# instant-action card — before the turn may advance, so hand back to
	# _run_upkeep rather than ending the phase here.
	if _upkeep_awaiting_confirm:
		_upkeep_awaiting_confirm = false
		_upkeep_confirmed.emit()
		return
	_end_phase_networked()


# Whether this side may advance the phase right now. Each side advances only
# the windows it controls (see _my_phase_window); the guard is skipped without
# a second client so the button can drive both sides in local testing.
#
# DISCARD is the one window the button may NOT skip: rules 1.8 says the active
# player sells down to the hand limit, and _try_finish_discard ends the phase
# for them the moment they comply. Skipping it let a player hoard their entire
# deck, so nothing ever reached the discard pile to reshuffle from (bug 64).
func _next_phase_available() -> bool:
	if not _my_phase_window() and not _is_solo():
		return false
	# Bug 56: the upkeep dice are still in the air — there is nothing to confirm
	# yet, and a press here would end the phase before the roll it exists for.
	if _upkeep_rolling:
		return false
	if turn_manager.phase == TurnManager.Phase.DISCARD and turn_manager.active == player:
		return deck_and_hand.hand.get_hand_size() <= Util.one_v_one_hand_limit
	return true


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
	# Bug 71: statuses that resolve at the Offensive Roll Phase's conclusion
	# (Constrict expires) tick here — on the active, authoritative side, once. Both
	# offensive endings (skill chosen / phase passed) route through here, while
	# Profiteer's extra offensive phase re-rolls WITHOUT ending the phase, so this
	# fires exactly at the true conclusion. The removal broadcasts like any status.
	if turn_manager.phase == TurnManager.Phase.OFFENSIVE:
		_dispatch_outgoing_attack()
		var ctx := BoardContext.new()
		ctx.caster = turn_manager.active
		ctx.opponent = opponent if turn_manager.active == player else player
		turn_manager.active.run_roll_phase_end(ctx)
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
	# Selling down to the limit is what re-opens the button (1.8).
	next_phase_button.disabled = not _next_phase_available()


# --- ending the match ------------------------------------------------------------

# A combatant's HP moved. The match is over the moment either side is down —
# whatever the phase (deliberately not Dice Throne's timing, but the rule we
# want here).
func _on_combatant_health_changed(_health : int) -> void:
	if _match_over or (player.health > 0 and opponent.health > 0):
		return
	_finish_match()


# Someone is down: freeze at once, then settle before judging (see
# RESULT_SETTLE — the double-KO's two zeroes don't arrive together).
func _finish_match() -> void:
	_match_over = true
	turn_manager.stop()
	await get_tree().create_timer(RESULT_SETTLE).timeout
	var outcome := _decide_outcome()
	print("[match] over — player %d hp, opponent %d hp -> %s" % [
			player.health, opponent.health, EventBus.Outcome.keys()[outcome]])
	_leave_to_result(outcome)


## The verdict from the final HP pair, local player's point of view. Kept pure
## so it can be checked without driving a whole match.
func _decide_outcome() -> EventBus.Outcome:
	if player.health <= 0 and opponent.health <= 0:
		return EventBus.Outcome.DRAW
	if player.health <= 0:
		return EventBus.Outcome.DEFEAT
	return EventBus.Outcome.VICTORY


## The other client vanished — conceded, crashed, or closed the game. Either
## way there's no match left, so we take the win. The _match_over latch keeps
## the normal end-of-match exodus (both sides leaving) from overwriting a
## verdict we already reached.
func opponent_forfeited() -> void:
	if _match_over:
		return
	_match_over = true
	turn_manager.stop()
	print("[match] opponent left the match — awarding the win")
	_leave_to_result(EventBus.Outcome.VICTORY)


# Hand the verdict to the result screen and get out. The screen reads
# match_outcome once and clears it.
func _leave_to_result(outcome : EventBus.Outcome) -> void:
	EventBus.match_outcome = outcome
	# Drop our readiness flag BEFORE leaving, so it can't carry into the next
	# match's start handshake and freeze the player who goes first (bug 67).
	match_sync.clear_ready_flag()
	GDSync.lobby_leave()
	get_tree().change_scene_to_packed(MatchResult)


# End Match is a concede: we take the loss, and simply leaving the lobby is
# what tells the other client they won (their client_left fires). No separate
# message to lose the race against lobby_leave().
func _on_end_match_button_down() -> void:
	if _match_over:
		return
	_match_over = true
	turn_manager.stop()
	print("[match] conceded")
	_leave_to_result(EventBus.Outcome.DEFEAT)
