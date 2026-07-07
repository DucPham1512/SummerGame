class_name Combatant
extends Control

# The shared PUBLIC surface of one side of the board: the resource state and
# signals that components like the HP/CP bars consume. Player (the local, full
# side) and Opponent (the replicated, public-info-only view) both extend this,
# so a component exporting a Combatant works on either side of the match.

signal health_changed(health : int)
signal cp_changed(cp : int)

var health : int
var cp : int

var max_hp : int = Util.one_v_one_max_hp
var max_cp : int = Util.one_v_one_max_cp
