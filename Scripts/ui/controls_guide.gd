class_name ControlsGuide
extends PanelContainer

# Columna central de la partida: botón y acción según el modo de cada jugador.

const ROW_FONT: int = 13
const CHIP_MIN_WIDTH: float = 72.0

var _scroll: ScrollContainer = null
var _list: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", NesUiTheme.panel_style())
	_build()
	if not InputBindings.control_modes_changed.is_connected(refresh):
		InputBindings.control_modes_changed.connect(refresh)
	refresh()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)


func refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.queue_free()
	var title: Label = _make_label("CONTROLES", NesUiTheme.FONT_SPY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(title)
	var players: Array[int] = [0]
	if not GameState.use_ai:
		players.append(1)
	for player_index: int in players:
		if player_index > 0:
			_list.add_child(_make_separator())
		if players.size() > 1:
			var who: String = "BLANCO" if player_index <= 0 else "NEGRO"
			var who_label: Label = _make_label(who, NesUiTheme.FONT_LABEL)
			who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_list.add_child(who_label)
		var mode: Label = _make_label(_mode_title(player_index), NesUiTheme.FONT_LABEL)
		mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mode.add_theme_color_override("font_color", NesUiTheme.COLOR_BORDER)
		_list.add_child(mode)
		var section: String = ""
		for row: Dictionary in InputBindings.get_controls_guide(player_index):
			var action_text: String = String(row.get("action", ""))
			var next_section: String = _section_for(action_text)
			if next_section != section:
				section = next_section
				var section_label: Label = _make_label(section, NesUiTheme.FONT_LABEL)
				section_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT_DIM)
				_list.add_child(section_label)
			_list.add_child(_make_row(String(row.get("button", "")), action_text))


func _section_for(action_text: String) -> String:
	match action_text:
		"Mover", "Apuntar":
			return "Movimiento"
		"Disparar", "Modo mirilla":
			return "Combate"
		_:
			return "Partida"


func _make_separator() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = NesUiTheme.COLOR_BORDER_DARK
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _mode_title(player_index: int) -> String:
	match InputBindings.get_control_mode(player_index):
		InputBindings.PlayerControlMode.KEYBOARD_MOUSE:
			return "Teclado y ratón"
		InputBindings.PlayerControlMode.KEYBOARD:
			return "Teclado"
		InputBindings.PlayerControlMode.GAMEPAD:
			return "Mando"
		_:
			return ""


func _make_row(button_text: String, action_text: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip: PanelContainer = PanelContainer.new()
	chip.custom_minimum_size = Vector2(CHIP_MIN_WIDTH, 0.0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _chip_style())
	var key: Label = _make_label(button_text, ROW_FONT)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(key)
	row.add_child(chip)
	var action: Label = _make_label(action_text, ROW_FONT)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(action)
	return row


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	NesUiTheme.style_caption(label)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _chip_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = NesUiTheme.COLOR_SLOT_EMPTY
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = NesUiTheme.COLOR_BORDER
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	return box
