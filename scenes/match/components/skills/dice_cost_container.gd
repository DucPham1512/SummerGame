extends HBoxContainer

# Dice-face sprites: res://assets/art/Dice/<Character>/face/Face0N.png (+ FaceBlank).
# A symbol is shown using a die face that displays it, looked up from the dice
# data (GameDataLoader) so there's no hardcoded symbol->face table to drift.
const FACE_PATH := "res://assets/art/Dice/%s/face/Face%02d.png"
const BLANK_PATH := "res://assets/art/Dice/%s/face/FaceBlank.png"
const FACE_SIZE := Vector2(48, 48)


## Rebuilds the cost row from a skill's `dice_cost` (belonging to `char_id`),
## clearing any existing faces first. Purely cosmetic.
func set_cost(dice_cost: Dictionary, char_id: String) -> void:
	clear_faces()
	match dice_cost.get("type", ""):
		"symbols", "symbols_min":
			# symbols_min shows its minimum count; the max-scaling is code-side only.
			var symbols: Dictionary = dice_cost.get("symbols", {})
			for symbol in symbols:
				add_symbol(symbol, int(symbols[symbol]), char_id)
		"defensive_roll":
			var n := int(dice_cost.get("dice_count", 0))
			var blank := _load_texture(BLANK_PATH % _folder(char_id))
			for i in n:
				_add_face(blank)
		"pattern":
			# Named pattern (small/large straight) — not a symbol cost. Nothing to
			# add here; show a pattern label/icon elsewhere if desired.
			pass


## Appends `count` copies of a symbol's die-face sprite.
func add_symbol(symbol: String, count: int, char_id: String) -> void:
	var tex := _symbol_texture(symbol, char_id)
	for i in count:
		_add_face(tex)


func clear_faces() -> void:
	for child in get_children():
		child.queue_free()


func _add_face(tex: Texture2D) -> void:
	if tex == null:
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	rect.custom_minimum_size = FACE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(rect)


func _symbol_texture(symbol: String, char_id: String) -> Texture2D:
	var face_num := _face_for_symbol(symbol, char_id)
	if face_num == 0:
		push_warning("dice_cost: no face shows symbol '%s' for '%s'" % [symbol, char_id])
		return null
	return _load_texture(FACE_PATH % [_folder(char_id), face_num])


# A representative face number (1-6) that shows `symbol` on char_id's die, or 0
# if none — derived from the dice data so it stays in sync with dice.json.
func _face_for_symbol(symbol: String, char_id: String) -> int:
	for die_id in GameDataLoader.dice_repository:
		var die: Dictionary = GameDataLoader.dice_repository[die_id]
		if die.get("character_id", "") != char_id:
			continue
		var faces: Dictionary = die.get("faces", {})
		for face_key in faces:
			if faces[face_key] == symbol:
				return int(face_key)
	return 0


func _folder(char_id: String) -> String:
	# Face folders are the capitalized character id (Tactician, Huntress).
	if char_id.is_empty():
		return char_id
	return char_id.substr(0, 1).to_upper() + char_id.substr(1)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("dice_cost: missing face sprite %s" % path)
		return null
	return load(path)
