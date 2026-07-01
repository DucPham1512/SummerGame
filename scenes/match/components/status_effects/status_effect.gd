class_name StatusEffect
extends RefCounted

# PLACEHOLDER. A status-effect instance. The full version will pull its
# name / stack_limit / phase behavior from GameDataLoader.status_effect_repository
# and hook into the turn phases; for now it just carries an id + a stack count.

var id : String
var stacks : int


func _init(effect_id : String, stack_count : int = 1) -> void:
	id = effect_id
	stacks = stack_count


# Convenience: the underlying data row (name, stack_limit, description, ...).
func data() -> Dictionary:
	return GameDataLoader.status_effect_repository.get(id, {})
