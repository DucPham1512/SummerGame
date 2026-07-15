extends Control

# Manual harness for the tactician kit on the slot-group layout, cloned from
# the huntress harness. Left: the real TacticianSkillLayout. Right: five
# dice-value spinners standing in for the offensive roll (values, not symbol
# counts — straights and 3-of-a-kind need them), Evaluate/Defensive-roll
# buttons, an Incoming-damage spinner (Countermeasures' per-Flag prevention
# subtracts from it), an Upgrade button per base slot, both sides' panels and
# a log. No companion — the tactician has none. Nothing here is game logic.

var owner_side : Combatant
var other_side : Combatant
var drawn_cards : int = 0   # draw_cards effects land here; no real hand

var value_spins : Array[SpinBox] = []
var upgrade_buttons : Array[Button] = []
var incoming_spin : SpinBox
var owner_label : Label
var hand_label : Label
var other_label : Label
var owner_tokens : HBoxContainer
var other_tokens : HBoxContainer
var log_box : RichTextLabel

@onready var layout : SkillLayout = $TacticianSkillLayout


func _ready() -> void:
	owner_side = Combatant.new()
	owner_side.name = "Tactician"
	owner_side.health = owner_side.max_hp
	add_child(owner_side)

	other_side = Combatant.new()
	other_side.name = "TargetDummy"
	other_side.health = other_side.max_hp
	add_child(other_side)

	for side in [owner_side, other_side]:
		side.health_changed.connect(func(_v : int) -> void: _refresh_panels())
		side.status_applied.connect(func(_t : StatusEffect) -> void: _refresh_panels())
		side.status_changed.connect(func(_t : StatusEffect) -> void: _refresh_panels())
		side.status_removed.connect(func(_t : StatusEffect) -> void: _refresh_panels())

	layout.skill_chosen.connect(_on_skill_chosen)
	_build_ui()
	_refresh_panels()


func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.66
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)

	panel.add_child(_header("Roll (die values 1-6)"))
	var dice_row := HBoxContainer.new()
	panel.add_child(dice_row)
	# 3 sabers + 2 flags AND both straights: lights Saber Strike, Flank and
	# Exploit at once — a good first demo.
	var defaults := [1, 2, 3, 4, 5]
	for i in 5:
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 6
		spin.value = defaults[i]
		dice_row.add_child(spin)
		value_spins.append(spin)

	var evaluate := Button.new()
	evaluate.text = "Evaluate roll"
	evaluate.pressed.connect(_on_evaluate_pressed)
	panel.add_child(evaluate)

	var defensive := Button.new()
	defensive.text = "Defensive roll (random dice)"
	defensive.pressed.connect(_on_defensive_roll_pressed)
	panel.add_child(defensive)

	var incoming_row := HBoxContainer.new()
	panel.add_child(incoming_row)
	var incoming_caption := Label.new()
	incoming_caption.text = "Incoming damage: "
	incoming_row.add_child(incoming_caption)
	incoming_spin = SpinBox.new()
	incoming_spin.min_value = 0
	incoming_spin.max_value = 30
	incoming_spin.value = 8
	incoming_row.add_child(incoming_spin)

	panel.add_child(_header("Upgrades"))
	var upgrade_grid := GridContainer.new()
	upgrade_grid.columns = 2
	panel.add_child(upgrade_grid)
	for i in SkillLayout.SLOT_COUNT:
		var button := Button.new()
		button.text = "Upgrade slot %d" % (i + 1)
		button.pressed.connect(_on_upgrade_pressed.bind(i))
		upgrade_grid.add_child(button)
		upgrade_buttons.append(button)

	panel.add_child(_header("Tactician"))
	owner_label = Label.new()
	panel.add_child(owner_label)
	hand_label = Label.new()
	panel.add_child(hand_label)
	owner_tokens = HBoxContainer.new()
	panel.add_child(owner_tokens)

	panel.add_child(_header("Opponent"))
	other_label = Label.new()
	panel.add_child(other_label)
	other_tokens = HBoxContainer.new()
	panel.add_child(other_tokens)

	panel.add_child(_header("Log"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 140)
	panel.add_child(scroll)
	log_box = RichTextLabel.new()
	log_box.fit_content = true
	log_box.scroll_following = true
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_box)


func _header(text : String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


# --- roll evaluation / activation ------------------------------------------------

func _roll_values() -> Array[int]:
	var values : Array[int] = []
	for spin in value_spins:
		values.append(int(spin.value))
	return values


func _tally(values : Array[int]) -> Dictionary:
	var counts : Dictionary = {}
	for value in values:
		var symbol := Skill.symbol_for_value("tactician", value)
		if not symbol.is_empty():
			counts[symbol] = counts.get(symbol, 0) + 1
	return counts


func _on_evaluate_pressed() -> void:
	var values := _roll_values()
	layout.enable_selection(_tally(values), values)


func _on_skill_chosen(skill : Skill) -> void:
	layout.clear_selection()
	var values := _roll_values()
	await _activate_and_apply(skill, values)


# The defensive skill runs its own roll: the current countermeasures tier's
# dice count, rolled randomly here (the match uses the dice UI for this).
func _on_defensive_roll_pressed() -> void:
	var skill := layout.defensive_skill()
	if skill == null:
		_log("no defensive skill on the board")
		return
	var dice_count := int(skill.dice_cost.get("dice_count", 4))
	var values : Array[int] = []
	for i in dice_count:
		values.append(randi_range(1, 6))
	_log("[b]defensive roll[/b] (%d dice): %s" % [dice_count, values])
	await _activate_and_apply(skill, values)


func _activate_and_apply(skill : Skill, values : Array[int]) -> void:
	var ctx := TestContext.new(self)
	ctx.caster = owner_side
	ctx.opponent = other_side
	ctx.roll_values = values
	ctx.roll_symbols = _tally(values)
	@warning_ignore("redundant_await")
	var effect : SkillEffect = await skill.activate(ctx)

	_log("[b]%s[/b] -> damage %d%s | prevent %d | draw %d | self %s | inflict %s" % [
			skill.skill_id, effect.damage,
			" (undefendable)" if effect.undefendable else "",
			effect.prevent_damage, effect.draw_cards,
			_status_list(effect.grant_to_self), _status_list(effect.inflict_on_opponent)])

	if effect.damage > 0:
		other_side.change_health(-effect.damage)
	if effect.prevent_damage > 0:
		var before := int(incoming_spin.value)
		incoming_spin.value = maxi(before - effect.prevent_damage, 0)
		_log("prevented %d incoming damage (%d -> %d)" % [
				effect.prevent_damage, before, int(incoming_spin.value)])
	if effect.draw_cards > 0:
		drawn_cards += effect.draw_cards
		_log("drew %d card(s) (virtual hand: %d)" % [effect.draw_cards, drawn_cards])
	if effect.extra_offensive_phase:
		_log("[color=yellow]additional offensive roll phase granted — evaluate again[/color]")
	for status in effect.grant_to_self:
		owner_side.apply_status(status.status_id, status.stacks)
	for status in effect.inflict_on_opponent:
		other_side.apply_status(status.status_id, status.stacks)
	# Limit changes / max-outs work from an empty board (match.gd does the
	# same): a missing token is created at 0 stacks first.
	for status_id in effect.stack_limit_delta:
		var token : StatusEffect = owner_side.get_status(status_id)
		if token == null:
			token = owner_side.apply_status(status_id, 0)
		token.stack_limit += int(effect.stack_limit_delta[status_id])
	for status_id in effect.max_out_self:
		var token : StatusEffect = owner_side.get_status(status_id)
		if token == null:
			token = owner_side.apply_status(status_id, 0)
		token.add_stacks(token.stack_limit)
	_refresh_panels()


func _on_upgrade_pressed(index : int) -> void:
	if layout.upgrade_slot(index):
		_log("slot %d upgraded" % (index + 1))
	upgrade_buttons[index].disabled = not layout.has_upgrade(index)


# --- panels / log ------------------------------------------------------------------

func _refresh_panels() -> void:
	owner_label.text = "HP: %d / %d" % [owner_side.health, owner_side.max_hp]
	hand_label.text = "Cards drawn (virtual hand): %d" % drawn_cards
	other_label.text = "HP: %d / %d" % [other_side.health, other_side.max_hp]
	_rebuild_row(owner_tokens, owner_side)
	_rebuild_row(other_tokens, other_side)


func _rebuild_row(row : HBoxContainer, side : Combatant) -> void:
	for child in row.get_children():
		child.queue_free()
	for token in side.status_effects.values():
		var button := Button.new()
		button.text = "x%d" % token.stacks
		var icon : Texture2D = token.picture_panel
		if icon == null:
			var placeholder := PlaceholderTexture2D.new()
			placeholder.size = Vector2(32, 32)
			icon = placeholder
		button.icon = icon
		button.expand_icon = true
		button.disabled = true
		button.custom_minimum_size = Vector2(64, 44)
		button.tooltip_text = "%s\n%s" % [token.status_name, token.description]
		row.add_child(button)


func _status_list(statuses : Array[StatusEffect]) -> String:
	if statuses.is_empty():
		return "-"
	var parts : Array[String] = []
	for status in statuses:
		parts.append("%s x%d" % [status.status_id, status.stacks])
	return ", ".join(parts)


func _log(text : String) -> void:
	log_box.append_text(text + "\n")


# Board verbs the harness backs: only the branch die roll needs a real value.
class TestContext extends BoardContext:
	var test

	func _init(p_test) -> void:
		test = p_test

	func roll_die() -> int:
		var value := randi_range(1, 6)
		test._log("branch roll -> %d (%s)" % [value, Skill.symbol_for_value("tactician", value)])
		return value
