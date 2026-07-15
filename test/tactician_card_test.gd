extends Control

# Manual harness for the 15 tactician cards, in the huntress_card_test format —
# a real TacticianSkillLayout on screen (so the 9 upgrade cards visibly
# advance real slot stages), no companion (the tactician has none), plus an
# Incoming-damage spinner backing prevent_damage (Disengage / Feigned
# Retreat). Every card pays its CP cost exactly like the match flow.

var owner_side : Combatant
var other_side : Combatant
var drawn_cards : int = 0   # draws land here; no real hand in this harness

var cp_spin : SpinBox
var incoming_spin : SpinBox
var target_select : OptionButton
var owner_label : Label
var hand_label : Label
var other_label : Label
var owner_tokens : HBoxContainer
var other_tokens : HBoxContainer
var slot_status : Label
var log_box : RichTextLabel

@onready var layout : SkillLayout = $TacticianSkillLayout


func _ready() -> void:
	owner_side = Combatant.new()
	owner_side.name = "Tactician"
	owner_side.health = owner_side.max_hp
	owner_side.cp = 5
	add_child(owner_side)

	other_side = Combatant.new()
	other_side.name = "Opponent"
	other_side.health = other_side.max_hp
	add_child(other_side)

	for side in [owner_side, other_side]:
		side.health_changed.connect(func(_v : int) -> void: _refresh_panels())
		side.cp_changed.connect(func(_v : int) -> void: _refresh_panels())
		side.status_applied.connect(func(_t : StatusEffect) -> void: _refresh_panels())
		side.status_changed.connect(func(_t : StatusEffect) -> void: _refresh_panels())
		side.status_removed.connect(func(_t : StatusEffect) -> void: _refresh_panels())

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

	panel.add_child(_header("Tactician"))
	owner_label = Label.new()
	panel.add_child(owner_label)
	hand_label = Label.new()
	panel.add_child(hand_label)
	var cp_row := HBoxContainer.new()
	panel.add_child(cp_row)
	var cp_caption := Label.new()
	cp_caption.text = "CP: "
	cp_row.add_child(cp_caption)
	cp_spin = SpinBox.new()
	cp_spin.min_value = 0
	cp_spin.max_value = owner_side.max_cp
	cp_spin.value = owner_side.cp
	cp_spin.value_changed.connect(func(value : float) -> void:
		owner_side.cp = int(value)
		_refresh_panels())
	cp_row.add_child(cp_spin)
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
	owner_tokens = HBoxContainer.new()
	panel.add_child(owner_tokens)

	panel.add_child(_header("Opponent"))
	other_label = Label.new()
	panel.add_child(other_label)
	var target_row := HBoxContainer.new()
	panel.add_child(target_row)
	var target_caption := Label.new()
	target_caption.text = "choose_player target: "
	target_row.add_child(target_caption)
	target_select = OptionButton.new()
	target_select.add_item("Owner")
	target_select.add_item("Opponent")
	target_select.select(0)
	target_row.add_child(target_select)
	other_tokens = HBoxContainer.new()
	panel.add_child(other_tokens)

	panel.add_child(_header("Skill slots"))
	slot_status = Label.new()
	slot_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(slot_status)

	panel.add_child(_header("Play a tactician card"))
	var card_grid := GridContainer.new()
	card_grid.columns = 2
	panel.add_child(card_grid)
	var ids : Array = []
	for id in GameDataLoader.card_repository:
		if GameDataLoader.card_repository[id].get("character_id", "") == "tactician":
			ids.append(id)
	ids.sort()
	for id in ids:
		var entry : Dictionary = GameDataLoader.card_repository[id]
		var play := Button.new()
		play.text = "%s (%d CP)" % [entry.get("name", id), int(entry.get("cp_cost", 0))]
		play.pressed.connect(_on_play_pressed.bind(id))
		card_grid.add_child(play)

	panel.add_child(_header("Log"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
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


# --- card play ---------------------------------------------------------------------

func _on_play_pressed(card_id : String) -> void:
	var entry : Dictionary = GameDataLoader.card_repository[card_id]
	var cost : int = int(entry.get("cp_cost", 0))
	if owner_side.cp < cost:
		_log("[color=orange]refused %s — costs %d CP, owner has %d[/color]"
				% [entry.get("name", card_id), cost, owner_side.cp])
		return
	if cost > 0:
		owner_side.cp -= cost
		owner_side.cp_changed.emit(owner_side.cp)
		_log("paid %d CP for [b]%s[/b] (cp now %d)" % [cost, entry.get("name", card_id), owner_side.cp])
	else:
		_log("played [b]%s[/b] (free)" % entry.get("name", card_id))

	var card := Card.create(card_id)
	var ctx := TacticianCardTestContext.new(self)
	ctx.caster = owner_side
	ctx.opponent = other_side
	ctx.incoming_damage = int(incoming_spin.value)
	@warning_ignore("redundant_await")
	await card.resolve(ctx)
	card.free()   # never entered the tree
	_refresh_panels()


func _selected_target() -> Combatant:
	return owner_side if target_select.selected == 0 else other_side


func reduce_incoming(amount : int) -> void:
	incoming_spin.value = maxi(int(incoming_spin.value) - amount, 0)


func _log(text : String) -> void:
	log_box.append_text(text + "\n")


# --- panels / tokens / slot readout --------------------------------------------------

func _refresh_panels() -> void:
	owner_label.text = "HP: %d / %d    CP: %d / %d" % [owner_side.health, owner_side.max_hp,
			owner_side.cp, owner_side.max_cp]
	hand_label.text = "Cards drawn (virtual hand): %d" % drawn_cards
	if cp_spin != null:
		cp_spin.set_value_no_signal(owner_side.cp)
	other_label.text = "HP: %d / %d" % [other_side.health, other_side.max_hp]
	_rebuild_row(owner_tokens, owner_side)
	_rebuild_row(other_tokens, other_side)
	_refresh_slot_status()


func _refresh_slot_status() -> void:
	var lines : Array[String] = []
	for i in layout.slot_skills.size():
		var group : Array = layout.slot_skills[i]
		if group.is_empty():
			continue
		lines.append("Slot %d: %s (stage %d)" % [i + 1, group[0].skill_name, layout.slot_stage[i]])
	slot_status.text = "\n".join(lines)


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


# Board verbs wired to the real combatants/layout on screen; dice rolls and
# player choices are logged stubs, same style as every other test context.
class TacticianCardTestContext extends BoardContext:
	var test

	func _init(p_test) -> void:
		test = p_test

	func gain_cp(amount : int) -> void:
		caster.cp = clampi(caster.cp + amount, 0, caster.max_cp)
		caster.cp_changed.emit(caster.cp)
		test._log("gain_cp(%d) -> caster at %d" % [amount, caster.cp])

	func draw_cards(amount : int) -> void:
		test.drawn_cards += amount
		test._log("draw_cards(%d) (virtual hand: %d)" % [amount, test.drawn_cards])

	func deal_damage(amount : int, target = null) -> void:
		var who : Combatant = target if target != null else caster
		who.change_health(-amount)
		test._log("deal_damage(%d) on %s -> hp %d" % [amount, who.name, who.health])

	func heal(amount : int, target = null) -> void:
		var who : Combatant = target if target != null else caster
		who.change_health(amount)
		test._log("heal(%d) on %s -> hp %d" % [amount, who.name, who.health])

	func apply_status(status_id : String, stacks : int = 1, target = null) -> void:
		var who : Combatant = target if target != null else caster
		who.apply_status(status_id, stacks)
		test._log("apply_status(%s x%d) on %s" % [status_id, stacks, who.name])

	func prevent_damage(amount : int, _target = null) -> void:
		test.reduce_incoming(amount)
		test._log("prevent_damage(%d) -> incoming now %d" % [amount, int(test.incoming_spin.value)])

	func upgrade_skill(slot_index : int) -> void:
		var upgraded : bool = test.layout.upgrade_slot(slot_index)
		test._log("upgrade_skill(slot %d) -> %s" % [slot_index + 1, "advanced" if upgraded else "already maxed"])

	func roll_die() -> int:
		var value := randi_range(1, 6)
		test._log("roll_die() -> %d (%s)" % [value, Skill.symbol_for_value("tactician", value)])
		return value

	func choose_player():
		var chosen : Combatant = test._selected_target()
		test._log("choose_player() -> %s (selector)" % chosen.name)
		return chosen
