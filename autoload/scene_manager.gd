extends Node

var content_container : Node

func load_scene(scene: PackedScene) -> void:
	if(content_container == null):
		push_error("ContentContainer not set!")
		return
	for child in content_container.get_children():
		child.queue_free()
	content_container.add_child(scene.instantiate())
