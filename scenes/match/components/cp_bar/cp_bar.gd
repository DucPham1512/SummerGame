extends ColorRect

# Either side of the match: the local Player or the Opponent view — both are
# Combatants and emit cp_changed.
@export var player : Combatant
var max_cp : int = Util.one_v_one_max_cp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	material.set_shader_parameter("count", max_cp)
	player.cp_changed.connect(update)
	update(max_cp)

func update(player_cp : int) -> void:
	material.set_shader_parameter("value", clampi(player_cp, 0, max_cp))
