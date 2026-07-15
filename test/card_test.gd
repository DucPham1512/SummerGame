extends Control

# Validates the card template proof end-to-end for the two implemented commons:
#   - data loads from GameDataLoader (name / type / phase / cp_cost / description)
#   - resolve(ctx) calls the expected board verbs (captured by a mock context)
#   - the per-card description scene instantiates
# Purely a manual-inspection harness; nothing here is game logic.

const DESCRIPTION_DIR := "res://scenes/match/components/cards/descriptions/"

@onready var content: VBoxContainer = $Scroll/Content


# Mock BoardContext that records the verbs a card calls, so we can validate
# resolution without the real Board. Override more verbs as cards use them.
class LoggingContext extends BoardContext:
	var log: Array[String] = []

	func gain_cp(amount: int) -> void:
		log.append("gain_cp(%d)" % amount)

	func draw_cards(amount: int) -> void:
		log.append("draw_cards(%d)" % amount)

	func deal_damage(amount: int, target = null) -> void:
		log.append("deal_damage(%d)" % amount)

	func apply_status(status_id: String, stacks: int = 1, target = null) -> void:
		log.append("apply_status(%s x%d)" % [status_id, stacks])


func _ready() -> void:
	_build_section(GettingPaid.new())
	_build_section(DoubleUp.new())


func _build_section(card: Card) -> void:
	add_child(card)   # entering the tree triggers the base _ready() -> load_data()

	var ctx := LoggingContext.new()
	card.resolve(ctx)

	# 1) Data + resolve() verb log.
	var report := RichTextLabel.new()
	report.bbcode_enabled = true
	report.fit_content = true
	report.custom_minimum_size = Vector2(640, 0)
	report.text = _describe(card, ctx)
	content.add_child(report)

	# 2) The per-card description scene (cosmetic).
	var desc_path := DESCRIPTION_DIR + card.card_id + ".tscn"
	if ResourceLoader.exists(desc_path):
		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(640, 90)
		holder.add_child(load(desc_path).instantiate())
		content.add_child(holder)

	content.add_child(HSeparator.new())


func _describe(card: Card, ctx: LoggingContext) -> String:
	var subtype := card.phase_subtype if card.phase_subtype else "-"
	var t := ""
	t += "[b]%s[/b]   ( %s / %s )\n" % [card.card_name, card.type, card.phase]
	t += "phase_subtype: %s    cp_cost: %d\n" % [subtype, card.cp_cost]
	t += "description: %s\n" % card.description
	t += "[b]resolve(ctx) called:[/b]\n"
	if ctx.log.is_empty():
		t += "    (no verbs)\n"
	else:
		for entry in ctx.log:
			t += "    %s\n" % entry
	return t
