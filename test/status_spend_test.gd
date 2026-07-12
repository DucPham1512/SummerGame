extends Control

# Manual test harness for every status effect: one Apply button per catalogue
# entry, live token rows for both sides, a Nyra readout, and an adjustable
# "incoming damage" for exercising the defensive spends (protect halving,
# bond damage-split). Click an owner token to open its spend popup; passive
# tokens just log. Nothing here is game logic.

var owner_side : Combatant
var other_side : Combatant
var nyra : Companion

var hp_label : Label
var cp_label : Label
var nyra_label : Label
var other_label : Label
var damage_spin : SpinBox
var owner_tokens : HBoxContainer
var other_tokens : HBoxContainer

@onready var popup : StatusSpendPopup = $StatusSpendPopup


func _ready() -> void:
	owner_side = Combatant.new()
	owner_side.name = "OwnerSide"
	owner_side.health = owner_side.max_hp
	owner_side.cp = 5
	add_child(owner_side)

	other_side = Combatant.new()
	other_side.name = "OtherSide"
	other_side.health = other_side.max_hp
	add_child(other_side)

	nyra = Companion.create_for_character("huntress")
	if nyra != null:
		add_child(nyra)
		owner_side.companion = nyra
		nyra.health_changed.connect(func(_hp : int) -> void: _refresh_labels())
		nyra.state_changed.connect(func(_state : Companion.State) -> void: _refresh_labels())

	for side in [owner_side, other_side]:
		side.health_changed.connect(func(_v : int) -> void: _refresh_labels())
		side.cp_changed.connect(func(_v : int) -> void: _refresh_labels())
		side.status_applied.connect(func(_t : StatusEffect) -> void: _refresh_tokens())
		side.status_changed.connect(func(_t : StatusEffect) -> void: _refresh_tokens())
		side.status_removed.connect(func(_t : StatusEffect) -> void: _refresh_tokens())

	popup.closed.connect(_on_popup_closed)
	_build_ui()
	_refresh_labels()
	_refresh_tokens()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 48)
	add_child(root)
	move_child(root, 0)   # keep the popup drawn on top

	# --- left: the token owner -------------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	root.add_child(left)
	left.add_child(_header("Owner (holds & spends tokens)"))
	hp_label = _line(left)
	cp_label = _line(left)
	nyra_label = _line(left)

	var damage_row := HBoxContainer.new()
	left.add_child(damage_row)
	var damage_caption := Label.new()
	damage_caption.text = "Incoming damage: "
	damage_row.add_child(damage_caption)
	damage_spin = SpinBox.new()
	damage_spin.min_value = 0
	damage_spin.max_value = 20
	damage_spin.value = 6
	damage_row.add_child(damage_spin)

	left.add_child(_header("Tokens (click to spend)"))
	owner_tokens = HBoxContainer.new()
	left.add_child(owner_tokens)

	# --- middle: apply buttons ---------------------------------------------------
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 6)
	root.add_child(middle)
	middle.add_child(_header("Apply status (+1 stack)"))
	var ids : Array = GameDataLoader.status_effect_repository.keys()
	ids.sort()
	for id in ids:
		var button := Button.new()
		button.text = "Apply %s" % GameDataLoader.status_effect_repository[id].get("name", id)
		button.pressed.connect(_on_apply_pressed.bind(id))
		middle.add_child(button)
	var hurt_nyra := Button.new()
	hurt_nyra.text = "Damage Nyra (-2)"
	hurt_nyra.pressed.connect(func() -> void:
		if nyra != null:
			nyra.take_damage(2))
	middle.add_child(hurt_nyra)

	# --- right: the other side ----------------------------------------------------
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	root.add_child(right)
	right.add_child(_header("Opponent (receives inflictions)"))
	other_label = _line(right)
	other_tokens = HBoxContainer.new()
	right.add_child(other_tokens)


func _header(text : String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _line(parent : Control) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label


func _on_apply_pressed(status_id : String) -> void:
	owner_side.apply_status(status_id, 1)


func _on_token_clicked(token : StatusEffect) -> void:
	var ctx := _make_context()
	if token.spend_options(ctx).is_empty():
		print("[status-test] %s is passive — nothing to spend" % token.status_id)
		return
	popup.open(token, ctx)


func _make_context() -> BoardContext:
	var ctx := TestBoardContext.new()
	ctx.caster = owner_side
	ctx.opponent = other_side
	ctx.incoming_damage = int(damage_spin.value)
	return ctx


# Spends call token.remove_stacks directly (no combatant signal), so sweep
# depleted tokens and redraw once the popup closes, whatever happened in it.
func _on_popup_closed() -> void:
	for side in [owner_side, other_side]:
		for status_id in side.status_effects.keys():
			side.remove_status_stacks(status_id, 0)   # 0-removal just runs the purge
	_refresh_tokens()
	_refresh_labels()


func _refresh_labels() -> void:
	hp_label.text = "HP: %d / %d" % [owner_side.health, owner_side.max_hp]
	cp_label.text = "CP: %d / %d" % [owner_side.cp, owner_side.max_cp]
	if nyra != null:
		var state_text := "ACTIVE" if nyra.is_active() \
				else "DOWNED — heal to %d to revive" % nyra.activation_hp
		nyra_label.text = "%s: %d / %d HP (amp +%d) — %s" % [nyra.companion_name,
				nyra.hp, nyra.max_hp, nyra.damage_amp, state_text]
	else:
		nyra_label.text = "Companion: none"
	other_label.text = "HP: %d / %d" % [other_side.health, other_side.max_hp]


func _refresh_tokens() -> void:
	_rebuild_row(owner_tokens, owner_side, true)
	_rebuild_row(other_tokens, other_side, false)


func _rebuild_row(row : HBoxContainer, side : Combatant, clickable : bool) -> void:
	for child in row.get_children():
		child.queue_free()
	if side.status_effects.is_empty():
		var empty := Label.new()
		empty.text = "(no tokens)"
		row.add_child(empty)
		return
	for token in side.status_effects.values():
		var button := _token_button(token)
		if clickable:
			button.pressed.connect(_on_token_clicked.bind(token))
		else:
			button.disabled = true
		row.add_child(button)


# A token renders as its icon (assets/art/StatusEffect/<id>.png — loaded by
# StatusEffect.load_data; only bleed has art yet) with the stack count as the
# only text. Missing art gets an engine PlaceholderTexture2D block; the
# name/description live in the tooltip either way.
func _token_button(token : StatusEffect) -> Button:
	var button := Button.new()
	button.text = "x%d" % token.stacks
	var icon : Texture2D = token.picture_panel
	if icon == null:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(40, 40)
		icon = placeholder
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(76, 52)
	button.tooltip_text = "%s\n%s" % [token.status_name, token.description]
	return button


# Board verbs the spends need, wired to this harness's two combatants. The
# real match context supersedes this.
class TestBoardContext extends BoardContext:
	func gain_cp(amount : int) -> void:
		caster.cp = clampi(caster.cp + amount, 0, caster.max_cp)
		caster.cp_changed.emit(caster.cp)

	func draw_cards(amount : int) -> void:
		print("[status-test] draw %d card(s) — no deck in this harness" % amount)

	func apply_status(status_id : String, stacks : int = 1, target = null) -> void:
		var who : Combatant = target if target != null else caster
		who.apply_status(status_id, stacks)

	func halve_incoming_damage(target = null) -> void:
		print("[status-test] halve incoming damage on %s — the board applies this during real damage resolution" % [target])
