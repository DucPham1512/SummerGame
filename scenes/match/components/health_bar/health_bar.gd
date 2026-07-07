extends TextureProgressBar

# Either side of the match: the local Player or the Opponent view — both are
# Combatants and emit health_changed.
@export var player : Combatant

var max_health : int = Util.one_v_one_max_hp

func _ready() -> void:
	player.health_changed.connect(update)

func update(player_health):
	value = player_health * 100 / max_health
