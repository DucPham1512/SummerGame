class_name MatchSync
extends Node

# The match's entire netcode layer. Everything rests on one structural fact:
# match.tscn is identical on both clients but MIRRORED in meaning — my
# Match/Opponent node is your view of me. GD-Sync's call_func resolves its
# target by matching absolute NodePath on the remote client, so calling a
# receiver on MY Opponent node executes on YOURS: exactly where my action
# should render. Public events only ever flow outward from the local Player
# (P2P trust model: each client is authoritative over its own side; hand
# contents and deck order never leave the owning client).
#
# Flow: both clients flag readiness via player data (safe even while the other
# client is still loading the scene) -> the host flips a coin for first turn
# and broadcasts it -> both start their mirrored turn loops and auto-draw the
# starting hand. From then on the local Player's public signals broadcast to
# the remote Opponent's receivers, and Next Phase transitions replicate via
# TurnManager.end_phase (match.gd broadcasts button presses only — automatic
# phase advances run deterministically on both clients).

const READY_KEY := "match_ready"

@onready var player : Player = $"../Player"
@onready var opponent : Opponent = $"../Opponent"
@onready var turn_manager : TurnManager = $"../TurnManager"
@onready var deck_and_hand : Control = $"../Player/DeckAndHand"

var _started : bool = false


func _ready() -> void:
	# Receiver whitelist: GD-Sync's protection mode blocks remote calls into
	# anything not exposed. Exposure is receiver-side — we expose what the
	# OTHER client is allowed to invoke here.
	GDSync.expose_func(opponent.on_opponent_drew)
	GDSync.expose_func(opponent.on_opponent_played)
	GDSync.expose_func(opponent.on_opponent_sold)
	GDSync.expose_func(opponent.on_opponent_health)
	GDSync.expose_func(opponent.on_opponent_cp)
	GDSync.expose_func(turn_manager.end_phase)
	GDSync.expose_func(_remote_match_start)

	# Outward wiring: the local Player's public events land on the remote
	# client's Opponent node (same path over there = their view of us).
	player.health_changed.connect(_broadcast_health)
	player.cp_changed.connect(_broadcast_cp)
	deck_and_hand.card_played.connect(_broadcast_card_played)
	deck_and_hand.card_sold.connect(_broadcast_card_sold)
	deck_and_hand.cards_drawn.connect(_broadcast_cards_drawn)

	deck_and_hand.turn_manager = turn_manager   # phase-gate card drops

	# No second client (scene run standalone / lobby lost): play locally, the
	# Next Phase button drives both sides like before.
	if GDSync.lobby_get_player_count() < 2:
		_start_match(true)
		return

	# Readiness handshake via player data rather than call_func: data survives
	# the other client still sitting in char selection, a call into a scene
	# that doesn't exist yet would not.
	GDSync.player_data_changed.connect(_on_player_data_changed)
	GDSync.player_set_data(READY_KEY, true)
	_check_all_ready()   # the other client may have been ready before us


# --- match start ----------------------------------------------------------------

func _on_player_data_changed(_client_id : int, key : String, _value) -> void:
	if key == READY_KEY:
		_check_all_ready()


func _check_all_ready() -> void:
	if _started:
		return
	var clients : Array = GDSync.lobby_get_all_clients()
	if clients.size() < 2:
		return
	for client_id in clients:
		if not GDSync.player_get_data(client_id, READY_KEY, false):
			return
	# Both clients are in the match scene. Only the host proceeds: it flips
	# the first-turn coin and tells the guest, so both start from one flip.
	if not GDSync.is_host():
		return
	var host_goes_first := randi() % 2 == 0
	GDSync.call_func(_remote_match_start, not host_goes_first)
	_start_match(host_goes_first)


## Remote receiver (guest side): the host's coin flip arrives here.
## `local_first` is already from the receiver's perspective.
func _remote_match_start(local_first : bool) -> void:
	_start_match(local_first)


func _start_match(local_first : bool) -> void:
	if _started:
		return
	_started = true
	# No ternary here: it would type the literal as a plain Array, which can't
	# assign to Array[Combatant] at runtime.
	var order : Array[Combatant]
	if local_first:
		order = [player, opponent]
	else:
		order = [opponent, player]
	turn_manager.start(order)
	# Opening hands: our draws broadcast, filling the remote fan; theirs fill ours.
	deck_and_hand.draw_cards(Util.one_v_one_starting_hand_size)


# --- outward broadcasts ----------------------------------------------------------

func _broadcast_health(health : int) -> void:
	GDSync.call_func(opponent.on_opponent_health, health)


func _broadcast_cp(cp : int) -> void:
	GDSync.call_func(opponent.on_opponent_cp, cp)


func _broadcast_card_played(slot : int, card_id : String) -> void:
	GDSync.call_func(opponent.on_opponent_played, slot, card_id)


func _broadcast_card_sold(slot : int, _card_id : String) -> void:
	# The sold card's identity stays private — only the slot leaving the fan
	# is public information.
	GDSync.call_func(opponent.on_opponent_sold, slot)


func _broadcast_cards_drawn(count : int) -> void:
	GDSync.call_func(opponent.on_opponent_drew, count)
