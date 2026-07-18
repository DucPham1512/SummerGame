extends TextureProgressBar

# Either side of the match: the local Player or the Opponent view — both are
# Combatants and emit health_changed. Left null when the bar is repurposed in
# code (Nyra's companion bar): call track_companion instead.
@export var player : Combatant

var max_health : int = Util.one_v_one_max_hp

func _ready() -> void:
	if player != null:
		player.health_changed.connect(update)

func update(player_health):
	value = player_health * 100 / max_health


## Points the bar at a companion instead of a combatant (Nyra's HP bar): same
## visuals, the companion's max HP (7) as the scale.
func track_companion(companion : CompanionNyra) -> void:
	max_health = companion.max_hp
	companion.health_changed.connect(update)
	update(companion.hp)
