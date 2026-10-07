class_name SpyHudPanel
extends PanelContainer

# Panel de un espía durante la partida: tiempo, vida, manos y botín.

const HEALTH_BAR_HEIGHT: float = 16.0
const TICK_COLOR: Color = Color("#3ddc6a")

var spy_id: int = 0
var show_room_label: bool = false
var time_label: Label = null
var health_bar: ProgressBar = null
var health_value: Label = null
var hands_mark: ColorRect = null
var hands_label: Label = null
var room_label: Label = null
var loot_label: Label = null
var prompt_label: Label = null
var name_label: Label = null
var role_label: Label = null
var pip: ColorRect = null
var slot_ids: Array[int] = []
var slot_rows: Array[Control] = []
var slot_marks: Array[ColorRect] = []
var slot_names: Array[Label] = []
var slot_checks: Array[Label] = []


func setup(p_spy_id: int, p_show_room_label: bool) -> void:
	spy_id = p_spy_id
	show_room_label = p_show_room_label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	add_theme_stylebox_override("panel", NesUiTheme.panel_style())
	_build_content()
	refresh_identity()


func _build_content() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	col.add_child(_make_header())
	col.add_child(_make_time_row())
	col.add_child(_make_health_row())
	col.add_child(_make_hands_row())
	col.add_child(_make_prompt_row())

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	col.add_child(_make_inventory_box())


func _make_header() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pip = ColorRect.new()
	pip.custom_minimum_size = Vector2(14, 14)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pip)
	name_label = Label.new()
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_spy_label(name_label)
	row.add_child(name_label)
	role_label = Label.new()
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(role_label)
	role_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(role_label)
	if show_room_label:
		room_label = Label.new()
		room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		NesUiTheme.style_caption(room_label)
		room_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
		row.add_child(room_label)
	return row


func _make_time_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.text = "TIEMPO"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(title)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(title)
	time_label = Label.new()
	time_label.text = "05:00"
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_timer(time_label)
	row.add_child(time_label)
	return row


func _make_health_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title: Label = Label.new()
	title.text = "VIDA"
	title.custom_minimum_size = Vector2(52, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(title)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(80, HEALTH_BAR_HEIGHT)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	health_bar.max_value = SpyBase.MAX_HEALTH
	health_bar.value = SpyBase.MAX_HEALTH
	health_bar.show_percentage = false
	var bar_styles: Dictionary = NesUiTheme.health_bar_styles()
	health_bar.add_theme_stylebox_override("background", bar_styles["bg"] as StyleBoxFlat)
	health_bar.add_theme_stylebox_override("fill", bar_styles["fill"] as StyleBoxFlat)
	row.add_child(health_bar)
	health_value = Label.new()
	health_value.text = "%d" % int(SpyBase.MAX_HEALTH)
	health_value.custom_minimum_size = Vector2(36, 0)
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(health_value)
	row.add_child(health_value)
	return row


func _make_hands_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title: Label = Label.new()
	title.text = "MANOS"
	title.custom_minimum_size = Vector2(52, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(title)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(title)
	hands_mark = ColorRect.new()
	hands_mark.custom_minimum_size = Vector2(12, 12)
	hands_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hands_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hands_mark.visible = false
	row.add_child(hands_mark)
	hands_label = Label.new()
	hands_label.text = "Vacío"
	hands_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hands_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hands_label.clip_text = true
	NesUiTheme.style_caption(hands_label)
	hands_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(hands_label)
	return row


func _make_prompt_row() -> Label:
	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.clip_text = true
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	NesUiTheme.style_caption(prompt_label)
	prompt_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TIMER_WARN)
	prompt_label.visible = false
	return prompt_label


func set_prompt(text: String) -> void:
	if prompt_label == null:
		return
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()


func _make_inventory_box() -> PanelContainer:
	var outer: PanelContainer = PanelContainer.new()
	outer.add_theme_stylebox_override("panel", NesUiTheme.inset_panel_style())
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	outer.add_child(margin)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	margin.add_child(list)
	loot_label = Label.new()
	loot_label.text = "BOTÍN"
	NesUiTheme.style_caption(loot_label)
	loot_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	list.add_child(loot_label)
	for item_id: int in ItemDB.get_all_items():
		list.add_child(_make_item_row(item_id))
	return outer


func _make_item_row(item_id: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark: ColorRect = ColorRect.new()
	mark.custom_minimum_size = Vector2(14, 14)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.color = NesUiTheme.COLOR_SLOT_EMPTY
	row.add_child(mark)
	var item_name: Label = Label.new()
	item_name.text = ItemDB.get_item_name(item_id)
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(item_name)
	item_name.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
	row.add_child(item_name)
	var check: Label = Label.new()
	check.text = ""
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	NesUiTheme.style_caption(check)
	row.add_child(check)
	slot_ids.append(item_id)
	slot_rows.append(row)
	slot_marks.append(mark)
	slot_names.append(item_name)
	slot_checks.append(check)
	return row


func refresh_identity() -> void:
	if name_label == null:
		return
	if spy_id == ItemDB.SpyId.PLAYER1:
		name_label.text = "BLANCO"
	else:
		name_label.text = "NEGRO"
	var role: String = ""
	if GameState.use_ai:
		role = "Tú" if spy_id == ItemDB.SpyId.PLAYER1 else "Rival"
	if role_label != null:
		role_label.text = role
		role_label.visible = not role.is_empty()
	if pip != null:
		pip.color = _pip_color()


func _pip_color() -> Color:
	var color: Color = ItemDB.SPY_COLORS.get(spy_id, Color.WHITE) as Color
	if color.get_luminance() < 0.25:
		return NesUiTheme.COLOR_BORDER
	return color


func set_time_text(text: String, timer_color: Color) -> void:
	if time_label == null:
		return
	time_label.text = text
	time_label.add_theme_color_override("font_color", timer_color)


func update_health(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum
	health_bar.value = current
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	var styles: Dictionary = NesUiTheme.health_bar_styles()
	var fill: StyleBoxFlat = (styles["fill"] as StyleBoxFlat).duplicate() as StyleBoxFlat
	var fill_color: Color = NesUiTheme.health_fill_color(ratio)
	fill.bg_color = fill_color
	health_bar.add_theme_stylebox_override("fill", fill)
	if health_value != null:
		health_value.text = "%d" % int(round(current))
		health_value.add_theme_color_override("font_color", fill_color)


func update_ammo(spy: SpyBase, _weapon_id: StringName) -> void:
	update_hands(spy)


func update_hands(spy: SpyBase) -> void:
	if hands_label == null:
		return
	if spy == null or spy.held == null or not spy.held.is_holding():
		hands_label.text = "Vacío"
		hands_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
		if hands_mark != null:
			hands_mark.visible = false
		return
	var held_name: String = spy.held.get_display_name()
	if spy.held.is_holding_weapon():
		var ammo: String = GameState.get_equipped_ammo_label(spy, spy.held.get_weapon_id())
		if ammo.begins_with("BAL: "):
			ammo = ammo.substr(5)
		if not ammo.is_empty():
			held_name = "%s  ·  %s" % [held_name, ammo]
	hands_label.text = held_name
	hands_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	if hands_mark != null:
		hands_mark.visible = true
		hands_mark.color = spy.held.get_display_color()


func update_inventory(carrier: SpyBase = null) -> void:
	var carried: Array[int] = _ids_in_hand(carrier)
	for i: int in slot_ids.size():
		var in_hand: bool = carried.has(slot_ids[i])
		var mark: ColorRect = slot_marks[i]
		var item_name: Label = slot_names[i]
		var check: Label = slot_checks[i]
		if mark != null:
			if in_hand:
				mark.color = ItemDB.ITEM_COLORS.get(slot_ids[i], Color.WHITE) as Color
			else:
				mark.color = NesUiTheme.COLOR_BG
		if item_name != null:
			item_name.add_theme_color_override(
				"font_color",
				NesUiTheme.COLOR_TEXT if in_hand else NesUiTheme.COLOR_TEXT_DIM
			)
		if check != null:
			check.text = "✓" if in_hand else ""
			check.add_theme_color_override("font_color", TICK_COLOR)
		var row: Control = slot_rows[i]
		if row != null:
			row.modulate = Color.WHITE
	if loot_label != null:
		loot_label.text = "BOTÍN  %d/%d" % [carried.size(), slot_ids.size()]


func _ids_in_hand(carrier: SpyBase) -> Array[int]:
	var carried: Array[int] = []
	if carrier == null or carrier.held == null or not carrier.held.is_holding_carried():
		return carried
	if carrier.held.is_holding_suitcase():
		var stored: Array = GameState.get_items(spy_id)
		for raw_id: Variant in stored:
			carried.append(int(raw_id))
		return carried
	if carrier.held.kind == HeldInventory.Kind.ITEM and carrier.held.held_id >= 0:
		carried.append(carrier.held.held_id)
	return carried


func set_room_text(text: String) -> void:
	if room_label != null:
		room_label.text = text


func blink_inventory() -> void:
	for i: int in slot_ids.size():
		var check: Label = slot_checks[i]
		if check == null or check.text.is_empty():
			continue
		var row: Control = slot_rows[i]
		if row == null:
			continue
		row.modulate = Color.WHITE
		var tween: Tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(row, "modulate", Color(1.0, 1.0, 0.45), 0.12)
		tween.tween_property(row, "modulate", Color.WHITE, 0.12)
