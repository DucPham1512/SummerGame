extends ColorRect

@export var player : Player
var max_cp : int = Util.one_v_one_max_cp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	material.set_shader_parameter("count", max_cp)
	player.cp_changed.connect(update)

func update(player_cp : int) -> void:
	material.set_shader_parameter("value", clampf((float(player_cp) - 0.5) / max_cp, 0.0, 1.0))
