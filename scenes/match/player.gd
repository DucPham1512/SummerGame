class_name Player
extends Combatant

# The local, full side of the board. Resource signals/state live on Combatant,
# shared with the Opponent view, so the bar components serve both sides.

@onready var hp_label : Label = $PlayerResourceContainer/HpContainer/HealthLabel
@onready var cp_label : Label = $PlayerResourceContainer/CpContainer/CpLabel
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_player_health(max_hp)
	update_player_cp(Util.one_v_one_starting_cp)
	
## Every HP change on this side funnels through Combatant's version — it owns the
## clamp, the damage mitigation an armed Protect provides (bug 79) and the
## signal — and this adds the numeric label the local board shows. Overriding
## here rather than only in update_player_health matters: cards and Nyra's Bond
## call change_health directly, and used to move the health bar (which listens to
## the signal) while leaving this label stale.
func change_health(delta : int) -> void:
	super.change_health(delta)
	hp_label.text = "%d / %d" % [health, max_hp]


func update_player_health(value : int):
	change_health(value)
	
func update_player_cp(value : int):
	cp = clampi(cp + value, 0, max_cp)
	cp_label.text = "%d / %d" % [cp, max_cp]
	cp_changed.emit(cp)


func _on_decrease_hp_pressed() -> void:
	update_player_health(-1)


func _on_increase_hp_pressed() -> void:
	update_player_health(1)

func _on_increase_cp_pressed() -> void:
	update_player_cp(1)

func _on_decrease_cp_pressed() -> void:
	update_player_cp(-1)


	
