extends Node

# Each repository maps an entry's "id" -> the entry Dictionary, built from the
# matching JSON file's top-level array. The JSON files store arrays; we index
# them by id here so lookups are O(1) and the vars stay Dictionaries.
# Access e.g. GameDataLoader.skill_repository[some_id].
var skill_repository : Dictionary = {}
var card_repository : Dictionary = {}
var character_repository : Dictionary = {}
var dice_repository : Dictionary = {}
var status_effect_repository : Dictionary = {}
var companion_repository : Dictionary = {}

const DATA_DIR := "res://resources/game_data/"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_skills()
	load_cards()
	load_characters()
	load_dice()
	load_status_effects()
	load_companions()


# Reads and parses a JSON file, returning its parsed data (Variant), or null on
# a missing file / parse error.
func load_json(path : String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Game data file not found: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var status := json.parse(json_string)
	if status != OK:
		push_error("JSON parse error in %s (line %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null

	return json.data


# Loads `file`, reads its top-level array under `key`, and returns a Dictionary
# indexed by each entry's "id".
func _load_repository(file : String, key : String) -> Dictionary:
	var data = load_json(DATA_DIR + file)
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	var entries = data.get(key, [])
	var repo : Dictionary = {}
	for entry in entries:
		if entry is Dictionary and entry.has("id"):
			repo[entry["id"]] = entry
		else:
			push_warning("%s: skipping an entry without an 'id' under '%s'" % [file, key])
	return repo


func load_skills() -> void:
	skill_repository = _load_repository("skills.json", "abilities")

func load_cards() -> void:
	card_repository = _load_repository("cards.json", "cards")

func load_characters() -> void:
	character_repository = _load_repository("characters.json", "characters")

func load_dice() -> void:
	dice_repository = _load_repository("dice.json", "dice")

func load_status_effects() -> void:
	status_effect_repository = _load_repository("status_effects.json", "status_effects")

func load_companions() -> void:
	companion_repository = _load_repository("companions.json", "companions")
