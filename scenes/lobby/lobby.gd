extends Control

@export var CharSelection : PackedScene

## Seconds the confirmation dialog waits before an unattended player is
## treated as having declined.
@export var confirmation_timeout : float = 15.0

@onready var match_confirmation := $MatchConfirmation
@onready var search_time_label : Label = $SearchTimeLabel

var _confirm_timer : Timer
# Elapsed search clock: runs while actively finding (browsing, waiting as a
# hosted lobby), freezes while a confirmation is on screen, resumes when the
# search continues (a decline, a kick, a stale join), resets on Find Match.
var _search_time : float = 0.0
var _searching : bool = false
var _elo : int = 0
var _lobby_queue : Array = []      # fetched once per Find Match, walked in order
var _queue_index : int = 0
var _pending_lobby : String = ""   # the lobby offered in the dialog (guest role)
var _owns_lobby : bool = false
var _in_lobby : bool = false


func _ready() -> void:
	match_confirmation.hide()
	_confirm_timer = Timer.new()
	_confirm_timer.one_shot = true
	_confirm_timer.timeout.connect(_on_confirmation_timeout)
	add_child(_confirm_timer)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_lobby_join_failed)
	GDSync.lobby_tag_changed.connect(_on_lobby_tag_changed)
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)
	GDSync.kicked.connect(_on_kicked)


func _process(delta : float) -> void:
	if not _searching:
		return
	_search_time += delta
	var total := int(_search_time)
	@warning_ignore("integer_division")
	search_time_label.text = "Finding match... %d:%02d" % [total / 60, total % 60]


func _on_find_match_button_down() -> void:
	_search_time = 0.0
	_searching = true
	search_time_label.show()
	await Util.ensure_gdsync_connected()
	var response : Dictionary = await GDSync.leaderboard_get_score("elo", Util.active_username)
	# New accounts have no submission yet; the default result scores them 0.
	_elo = int(response.get("Result", {}).get("Score", Util.BASE_ELO))

	# Browsing is asynchronous: request the list, then wait for the server.
	GDSync.get_public_lobbies()
	_lobby_queue = await GDSync.lobbies_received
	_queue_index = 0
	_offer_next_lobby()


# Walks the cached list from wherever it left off: offers the next compatible
# waiting lobby, or hosts one once the list runs out. Every path that keeps
# the search going funnels through here, so the search clock resumes here
# (and re-freezes immediately if a candidate pops the confirmation).
func _offer_next_lobby() -> void:
	_searching = true
	while _queue_index < _lobby_queue.size():
		var lobby : Dictionary = _lobby_queue[_queue_index]
		_queue_index += 1
		var tags : Dictionary = lobby.get("Tags", {})
		if tags.get("state", "") == "waiting" \
				and absi(int(tags.get("elo", 0)) - _elo) <= Util.ELO_THRESHOLD:
			_pending_lobby = lobby["Name"]
			_show_confirmation()
			return
	_pending_lobby = ""
	_host_lobby()


func _host_lobby() -> void:
	GDSync.lobby_create(
		"match_%d_%s" % [Time.get_ticks_msec(), Util.active_username],
		"",     # no password
		true,   # public, so browsing clients can find it
		2,      # 1v1
		{"elo": _elo, "state": "waiting"},
	)


# --- the confirmation dialog (serves both roles) -------------------------------

# Every dialog appearance arms the AFK timer, and freezes the search clock;
# every button press disarms the AFK timer.
func _show_confirmation() -> void:
	_searching = false
	match_confirmation.show()
	_confirm_timer.start(confirmation_timeout)


# The search dead-ended (match started, we stopped hosting, creation failed):
# the clock stops and hides until the next Find Match press resets it.
func _stop_search() -> void:
	_searching = false
	search_time_label.hide()


# No response in time: treat it exactly as if that player pressed Decline —
# host drops the lobby, guest walks on to the next candidate. An unattended
# guest walks until the list runs out, hosts, and their host timeout then
# drops that lobby too, so the AFK flow always terminates.
func _on_confirmation_timeout() -> void:
	if not match_confirmation.visible:
		return
	_on_decline_button_down()


func _on_accept_button_down() -> void:
	_confirm_timer.stop()
	if _owns_lobby:
		# Guest gone between their arrival and our click: nothing to confirm.
		if GDSync.lobby_get_player_count() < 2:
			match_confirmation.hide()
			return
		# Host confirming: the tag flip IS the start signal — the guest reacts
		# to it; we go directly.
		GDSync.lobby_set_tag("state", "starting")
		_start_match()
		return
	if _in_lobby or _pending_lobby.is_empty():
		return   # already accepted; waiting on the host
	# Guest accepting: join, and keep the dialog up (Decline backs out) until
	# the host confirms via the state tag — or drops us via a kick.
	GDSync.lobby_join(_pending_lobby)


func _on_decline_button_down() -> void:
	_confirm_timer.stop()
	match_confirmation.hide()
	if _owns_lobby:
		_drop_owned_lobby()   # stop hosting; Find Match starts a fresh search
		_stop_search()
		return
	if _in_lobby:
		# Backed out while waiting on the host's confirmation.
		GDSync.lobby_leave()
		_in_lobby = false
	_offer_next_lobby()   # keep browsing from where the walk left off


# --- lobby lifecycle: host role -------------------------------------------------

func _on_lobby_created(lobby_name : String) -> void:
	_owns_lobby = true
	GDSync.lobby_join(lobby_name)   # creation does not put us inside


func _on_lobby_creation_failed(lobby_name : String, error : int) -> void:
	push_error("Lobby: failed to create '%s' (error %d)" % [lobby_name, error])
	_stop_search()


func _on_client_joined(client_id : int) -> void:
	if client_id == GDSync.get_client_id():
		return   # our own join echo (this signal includes yourself)
	if not _owns_lobby:
		return
	# A guest arrived: hide the lobby from other browsers, ask us to confirm.
	GDSync.lobby_set_tag("state", "confirming")
	_show_confirmation()


func _on_client_left(_client_id : int) -> void:
	if not _owns_lobby:
		return
	# The guest backed out before we confirmed: back on the market, so the
	# search clock resumes.
	GDSync.lobby_set_tag("state", "waiting")
	_confirm_timer.stop()
	match_confirmation.hide()
	_searching = true


func _drop_owned_lobby() -> void:
	for client_id in GDSync.lobby_get_all_clients():
		if client_id != GDSync.get_client_id():
			GDSync.lobby_kick_client(client_id)
	GDSync.lobby_leave()
	_owns_lobby = false
	_in_lobby = false


# --- lobby lifecycle: guest role -------------------------------------------------

func _on_lobby_joined(_lobby_name : String) -> void:
	# Deliberately NO scene change here: the host may still decline. Guests
	# start when the state tag flips; hosts start themselves in accept.
	_in_lobby = true


func _on_lobby_join_failed(lobby_name : String, error : int) -> void:
	# A stale queue entry (filled or closed since the fetch): walk on.
	push_warning("Lobby: failed to join '%s' (error %d)" % [lobby_name, error])
	_offer_next_lobby()


func _on_lobby_tag_changed(key : String, value) -> void:
	if _owns_lobby:
		return   # our own tag writes echoing back
	if key == "state" and value == "starting":
		_start_match()


func _on_kicked() -> void:
	# The host declined the match: keep browsing from where the walk left off.
	_in_lobby = false
	_confirm_timer.stop()
	match_confirmation.hide()
	_offer_next_lobby()


func _start_match() -> void:
	_stop_search()
	get_tree().change_scene_to_packed(CharSelection)
