extends Control

# Manual test harness for every COMMON card effect, in the status_spend_test
# format: two code-built combatants, one Play button per common card (cost in
# the label), and test parameters — owner CP (spinner), incoming damage (for
# prevention cards), a target selector driving choose_player, and Apply-status
# buttons so the removal/transfer cards have material to work on. Every card
# pays its CP cost exactly like the match flow (refused when unaffordable).
# Verbs the dice session will implement later just log their intent.

var owner_side : Combatant
var other_side : Combatant
var hand_size : int = 0   # draws land here; no real hand in this harness

var cp_spin : SpinBox
var damage_spin : SpinBox
var target_select : OptionButton
var hp_label : Label
var hand_label : Label
var other_label : Label
var owner_tokens : HBoxContainer
var other_tokens : HBoxContainer
var log_text : RichTextLabel


func _ready() -> void:
	owner_side = Combatant.new()
	owner_side.name = "Owner"
	owner_side.health = owner_side.max_hp
	owner_side.cp = 5
	add_child(owner_side)

	other_side = Combatant.new()
	other_side.name = "Opponent"
	other_side.health = other_side.max_hp
	add_child(other_side)

	for side in [owner_side, other_side]:
		side.status_applied.connect(func(_t : StatusEffect) -> void: _refresh_tokens())
		side.status_changed.connect(func(_t : StatusEffect) -> void: _refresh_tokens())
		side.status_removed.connect(func(_t : StatusEffect) -> void: _refresh_tokens())
		side.cp_changed.connect(func(_v : int) -> void: _refresh_labels())
		side.health_changed.connect(func(_v : int) -> void: _refresh_labels())

	_build_ui()
	_refresh_labels()
	_refresh_tokens()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 40)
	add_child(root)

	# --- left: the card player + test parameters -------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	root.add_child(left)
	left.add_child(_header("Owner (plays the cards)"))
	hp_label = _line(left)
	hand_label = _line(left)
	cp_spin = _param_spin(left, "CP:", 0, owner_side.max_cp, owner_side.cp)
	cp_spin.value_changed.connect(func(value : float) -> void:
		owner_side.cp = int(value)
		_refresh_labels())
	damage_spin = _param_spin(left, "Incoming damage:", 0, 30, 8)

	var target_row := HBoxContainer.new()
	left.add_child(target_row)
	var target_caption := Label.new()
	target_caption.text = "choose_player target: "
	target_row.add_child(target_caption)
	target_select = OptionButton.new()
	target_select.add_item("Owner")
	target_select.add_item("Opponent")
	target_select.select(1)
	target_row.add_child(target_select)

	var apply_row := HBoxContainer.new()
	left.add_child(apply_row)
	for status_id in ["bleed", "protect"]:
		var apply := Button.new()
		apply.text = "Apply %s to target" % status_id
		apply.pressed.connect(func() -> void:
			_selected_target().apply_status(status_id, 1))
		apply_row.add_child(apply)

	left.add_child(_header("Owner tokens"))
	owner_tokens = HBoxContainer.new()
	left.add_child(owner_tokens)
	left.add_child(_header("Opponent"))
	other_label = _line(left)
	other_tokens = HBoxContainer.new()
	left.add_child(other_tokens)

	# --- middle: one Play button per common card ---------------------------------
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	root.add_child(middle)
	middle.add_child(_header("Play a common card"))
	var ids : Array = []
	for id in GameDataLoader.card_repository:
		if GameDataLoader.card_repository[id].get("type", "") == "common":
			ids.append(id)
	ids.sort()
	for id in ids:
		var entry : Dictionary = GameDataLoader.card_repository[id]
		var play := Button.new()
		play.text = "%s  (%d CP)" % [entry.get("name", id), int(entry.get("cp_cost", 0))]
		play.pressed.connect(_on_play_pressed.bind(id))
		middle.add_child(play)

	# --- right: verb log -----------------------------------------------------------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	right.add_child(_header("Resolution log"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	log_text = RichTextLabel.new()
	log_text.fit_content = true
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_text)


func _header(text : String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _line(parent : Control) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label


func _param_spin(parent : Control, caption : String, minimum : int, maximum : int, value : int) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption + " "
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	row.add_child(spin)
	return spin


func _selected_target() -> Combatant:
	return owner_side if target_select.selected == 0 else other_side


# The play flow mirrors the match's deck_and_hand: refuse when unaffordable,
# pay the cost, then resolve against the context.
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
	var ctx := CardTestContext.new(self)
	ctx.caster = owner_side
	ctx.opponent = other_side
	ctx.incoming_damage = int(damage_spin.value)
	await card.resolve(ctx)
	card.free()   # never entered the tree
	_refresh_labels()
	_refresh_tokens()


func reduce_incoming(amount : int) -> void:
	damage_spin.value = maxi(int(damage_spin.value) - amount, 0)


func _log(text : String) -> void:
	log_text.append_text(text + "\n")


func _refresh_labels() -> void:
	hp_label.text = "HP: %d / %d    CP: %d / %d" % [owner_side.health, owner_side.max_hp,
			owner_side.cp, owner_side.max_cp]
	hand_label.text = "Cards drawn (virtual hand): %d" % hand_size
	other_label.text = "HP: %d / %d" % [other_side.health, other_side.max_hp]
	if cp_spin != null:
		cp_spin.set_value_no_signal(owner_side.cp)


func _refresh_tokens() -> void:
	_rebuild_row(owner_tokens, owner_side)
	_rebuild_row(other_tokens, other_side)


func _rebuild_row(row : HBoxContainer, side : Combatant) -> void:
	for child in row.get_children():
		child.queue_free()
	if side.status_effects.is_empty():
		var empty := Label.new()
		empty.text = "(no tokens)"
		row.add_child(empty)
		return
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
		button.custom_minimum_size = Vector2(64, 44)
		button.disabled = true
		button.tooltip_text = token.status_name
		row.add_child(button)


# Board verbs wired to this harness: state-touching verbs act on the two
# combatants; dice-session verbs log their intent (the roll UI implements
# them later). The real Board context supersedes this.
class CardTestContext extends BoardContext:
	var test

	func _init(p_test) -> void:
		test = p_test

	func gain_cp(amount : int) -> void:
		caster.cp = clampi(caster.cp + amount, 0, caster.max_cp)
		caster.cp_changed.emit(caster.cp)
		test._log("gain_cp(%d) -> caster at %d" % [amount, caster.cp])

	func draw_cards(amount : int) -> void:
		test.hand_size += amount
		test._log("draw_cards(%d)" % amount)

	func apply_status(status_id : String, stacks : int = 1, target = null) -> void:
		var who : Combatant = target if target != null else caster
		who.apply_status(status_id, stacks)
		test._log("apply_status(%s x%d) on %s" % [status_id, stacks, who.name])

	func remove_status(status_id : String, target = null) -> void:
		var who : Combatant = target if target != null else caster
		if status_id.is_empty() or not who.has_status(status_id):
			test._log("remove_status: %s has no token to remove" % who.name)
			return
		who.remove_status_stacks(status_id, 1)
		test._log("remove_status(%s) on %s" % [status_id, who.name])

	func clear_all_statuses(target = null) -> void:
		var who : Combatant = target if target != null else caster
		for status_id in who.status_effects.keys():
			who.clear_status(status_id)
		test._log("clear_all_statuses on %s" % who.name)

	func transfer_status(status_id : String, from_player, to_player) -> void:
		if status_id.is_empty() or not from_player.has_status(status_id):
			test._log("transfer_status: %s has nothing to transfer" % from_player.name)
			return
		var stacks : int = from_player.get_status(status_id).stacks
		from_player.clear_status(status_id)
		to_player.apply_status(status_id, stacks)
		test._log("transfer_status(%s x%d) %s -> %s" % [status_id, stacks, from_player.name, to_player.name])

	func prevent_damage(amount : int, target = null) -> void:
		test.reduce_incoming(amount)
		test._log("prevent_damage(%d) on %s -> incoming now %d"
				% [amount, target.name if target != null else "caster", int(test.damage_spin.value)])

	func roll_die() -> int:
		var value := randi_range(1, 6)
		test._log("roll_die() -> %d" % value)
		return value

	func choose_player():
		var chosen : Combatant = test._selected_target()
		test._log("choose_player() -> %s (selector)" % chosen.name)
		return chosen

	func choose_status(target = null) -> String:
		var who : Combatant = target if target != null else caster
		if who.status_effects.is_empty():
			test._log("choose_status(%s) -> none available" % who.name)
			return ""
		var status_id : String = who.status_effects.keys()[0]
		test._log("choose_status(%s) -> %s (first token; picker pending)" % [who.name, status_id])
		return status_id

	func choose_die(target = null) -> int:
		test._log("choose_die(%s) -> #0 (die picker pending)" % (target.name if target != null else "any"))
		return 0

	func choose_die_value() -> int:
		test._log("choose_die_value() -> 6 (value picker pending)")
		return 6

	func choose_option(options : Array) -> int:
		test._log("choose_option(%s) -> 0 (option picker pending)" % [options])
		return 0

	func reroll_die(die) -> bool:
		test._log("reroll_die(#%s) — dice session hookup pending" % die)
		return true

	func change_die_value(die_index : int, value : int, _target = null) -> void:
		test._log("change_die_value(#%d -> %d) — dice session hookup pending" % [die_index, value])

	func adjust_die_value(die_index : int, delta : int, _target = null) -> void:
		test._log("adjust_die_value(#%d %+d) — dice session hookup pending" % [die_index, delta])

	func copy_die_value(from_index : int, to_index : int, _target = null) -> void:
		test._log("copy_die_value(#%d -> #%d) — dice session hookup pending" % [from_index, to_index])

	func grant_extra_roll(target = null) -> void:
		test._log("grant_extra_roll(%s) — dice session hookup pending"
				% (target.name if target != null else "caster"))
