extends Control

# Validates the status-effect framework for the two implemented behaviours:
#   - data loads from GameDataLoader (name / stack_limit / transferable / description)
#   - stacks are tracked by the entity itself and clamp to stack_limit
#   - Bleed's on_upkeep trigger calls the expected board verbs (forced rolls)
#   - Protect's spend() consumes a stack and calls its verb; refuses when empty
#   - the factory returns a base data-only instance for unregistered ids
# Purely a manual-inspection harness; nothing here is game logic.

@onready var content: VBoxContainer = $Scroll/Content


# Mock context that records the verbs a status calls; roll_die() pops forced
# values so the Bleed branches can be exercised deterministically.
class LoggingContext extends BoardContext:
	var log: Array[String] = []
	var forced_rolls: Array[int] = []

	func roll_die() -> int:
		var v: int = 1
		if not forced_rolls.is_empty():
			v = forced_rolls.pop_front()
		log.append("roll_die() -> %d" % v)
		return v

	func deal_damage(amount: int, target = null) -> void:
		log.append("deal_damage(%d)" % amount)

	func halve_incoming_damage(target = null) -> void:
		log.append("halve_incoming_damage()")


func _ready() -> void:
	await _bleed_section()
	_protect_section()
	_factory_section()


func _bleed_section() -> void:
	var bleed := StatusEffect.create("bleed", 5)   # over the limit on purpose
	var ctx := LoggingContext.new()
	ctx.forced_rolls.assign([2, 6])

	var t := _describe(bleed)
	t += "created with 5 stacks -> clamped to %d (limit %d)\n" % [bleed.stacks, bleed.stack_limit]
	await bleed.on_upkeep(ctx)
	t += "upkeep #1 (forced roll 2): expect deal_damage(1); stacks: %d\n" % bleed.stacks
	await bleed.on_upkeep(ctx)
	t += "upkeep #2 (forced roll 6): expect token removed; stacks: %d\n" % bleed.stacks
	t += "[b]verbs:[/b] %s" % ", ".join(ctx.log)
	_add_report(t)


func _protect_section() -> void:
	var protect := StatusEffect.create("protect")
	var ctx := LoggingContext.new()

	var t := _describe(protect)
	t += "spend #1 -> %s (stacks: %d)\n" % [protect.spend(ctx), protect.stacks]
	t += "spend #2 -> %s (empty, must refuse)\n" % protect.spend(ctx)
	t += "[b]verbs:[/b] %s" % ", ".join(ctx.log)
	_add_report(t)


func _factory_section() -> void:
	# No behaviour script registered for "targeted": the factory must fall back
	# to a base, data-only instance (its +2 rule is consulted by the board).
	var targeted := StatusEffect.create("targeted")
	var t := _describe(targeted)
	t += "base instance (data-only): %s, can_spend: %s" % [
			targeted.get_script() == StatusEffect, targeted.can_spend()]
	_add_report(t)


func _describe(s: StatusEffect) -> String:
	return "[b]%s[/b] (%s)   stacks: %d/%d   transferable: %s   positive: %s\n%s\n" % [
			s.status_name, s.status_id, s.stacks, s.stack_limit,
			s.transferable, s.is_positive(), s.description]


func _add_report(text: String) -> void:
	var report := RichTextLabel.new()
	report.bbcode_enabled = true
	report.fit_content = true
	report.custom_minimum_size = Vector2(700, 0)
	report.text = text
	content.add_child(report)
	content.add_child(HSeparator.new())
