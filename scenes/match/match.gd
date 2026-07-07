extends Control

@export var MatchResult : PackedScene

## Placeholder income rule: CP granted at the start of every turn.
const INCOME_CP := 2

@onready var player : Combatant = $Player
@onready var opponent : Combatant = $Opponent
@onready var turn_manager : TurnManager = $TurnManager
@onready var phase_label : Label = $PhaseLabel


func _ready() -> void:
	turn_manager.phase_entered.connect(_on_phase_entered)
	# Local loop for now: both sides' turns run on this instance. With GDSync,
	# only the local player's turn is driven here — the opponent's transitions
	# arrive as replicated end_phase()/turn events instead.
	var turn_order : Array[Combatant] = [player, opponent]
	turn_manager.start(turn_order)


func _on_phase_entered(active : Combatant, phase : TurnManager.Phase) -> void:
	phase_label.text = "%s — %s" % [active.name, TurnManager.Phase.keys()[phase].capitalize()]
	match phase:
		TurnManager.Phase.UPKEEP:
			# Automatic. Start-of-turn ticks: the active side's status tokens
			# trigger (bleed rolls, etc.). Placeholder context for now — verbs
			# like roll_die/deal_damage warn until the real Board lands. Note
			# the loop doesn't wait for this (fire-and-forget): async upkeeps
			# need the TurnManager hold mechanism when they matter.
			var ctx := BoardContext.new()
			ctx.caster = active
			ctx.opponent = opponent if active == player else player
			active.run_upkeep(ctx)
		TurnManager.Phase.INCOME:
			# Automatic. The active side gains its turn CP. The opponent branch
			# is local-demo only: once GDSync lands, their income happens on
			# their client and arrives as a replicated cp update instead.
			if active == player:
				(player as Player).update_player_cp(INCOME_CP)
			elif active == opponent:
				(opponent as Opponent).on_opponent_cp(opponent.cp + INCOME_CP)
		TurnManager.Phase.MAIN_ONE:
			# Interactive. Open the play window: main_phase cards become legal
			# (gate drops in deck_and_hand via turn_manager.can_play).
			pass
		TurnManager.Phase.OFFENSIVE:
			# Interactive. The attacker's roll window: skill dice + offensive
			# roll_phase cards.
			pass
		TurnManager.Phase.TARGETING:
			# Interactive, multiplayer only (skipped otherwise): the active
			# player picks which opponent the attack lands on.
			pass
		TurnManager.Phase.DEFENSIVE:
			# Interactive. The defender's response window: defensive
			# roll_phase cards, then damage resolves.
			pass
		TurnManager.Phase.MAIN_TWO:
			# Interactive. Second play window, same rules as MAIN_ONE.
			pass
		TurnManager.Phase.DISCARD:
			# Interactive once a hand limit exists: prompt the active player
			# down to the limit. TODO: replace the auto-pass with that check
			# (end_phase() only when hand size <= limit).
			turn_manager.end_phase()


func _on_next_phase_pressed() -> void:
	turn_manager.end_phase()


func _on_end_match_button_down() -> void:
	turn_manager.stop()
	get_tree().change_scene_to_packed(MatchResult)
