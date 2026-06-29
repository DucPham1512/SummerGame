extends TextureProgressBar

@export var player : Player

var max_health : int = Util.one_v_one_max_hp
	
func _ready() -> void:
	player.health_changed.connect(update)

func update(player_health):
	value = player_health * 100 / max_health
