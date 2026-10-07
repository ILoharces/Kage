extends CanvasLayer
class_name Trapulator

# Trapulator: elegir trampa o contramedida (suelta lo que lleves en la mano) y consultar el stock.
# Columna izquierda = trampas; derecha = contramedidas. Arriba/abajo elige fila, izquierda/derecha cambia de columna.

const ROW_HEIGHT: float = 40.0
const COLUMN_TRAPS: int = 0
const COLUMN_COUNTERS: int = 1

signal toggled(open: bool)

var player: Player = null
var player2: Player = null
var _active_player: Player = null
var is_open: bool = false

var panel: PanelContainer
var hint_label: Label = null
## Por columna: ids, filas y etiquetas de cantidad.
var _ids: Array[Array] = [[], []]
var _rows: Array[Array] = [[], []]
var _count_labels: Array[Array] = [[], []]
var _selected_column: int = COLUMN_TRAPS
var _selected_row: int = 0


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ids[COLUMN_TRAPS] = ItemDB.get_all_traps()
	_ids[COLUMN_COUNTERS] = ItemDB.get_all_counters()
	_build_ui()
	GameState.traps_changed.connect(_on_traps_changed)
	GameState.game_over.connect(_on_game_over)


func bind_player(p: Player) -> void:
	player = p
	_connect_held(player)


func bind_player2(p: Player) -> void:
	player2 = p
	_connect_held(p)


func unbind() -> void:
	player = null
	player2 = null
	_active_player = null
	if is_open:
		close(false)


func _connect_held(p: Player) -> void:
	if p == null:
		return
	if p.held_changed.is_connected(_on_held_external_change):
		p.held_changed.disconnect(_on_held_external_change)
	p.held_changed.connect(_on_held_external_change)
	_refresh_highlight()


func _owner_player() -> Player:
	if _active_player != null:
		return _active_player
	return player


# --- Construcción -------------------------------------------------------------

func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title: Label = UiKit.label("TRAPULATOR", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(title)
	root.add_child(UiKit.label("El reloj sigue corriendo", &"WarningLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	columns.add_child(_build_column(COLUMN_TRAPS, "Trampas"))
	columns.add_child(VSeparator.new())
	columns.add_child(_build_column(COLUMN_COUNTERS, "Contramedidas"))

	hint_label = UiKit.wrapped_label("", &"HintLabel", HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(hint_label)
	_refresh_highlight()


func _build_column(column: int, title_text: String) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiKit.label(title_text.to_upper(), &"SectionLabel"))
	var ids: Array = _ids[column]
	for row_index: int in ids.size():
		col.add_child(_build_row(column, row_index, int(ids[row_index])))
	return col


func _build_row(column: int, row_index: int, tool_id: int) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_gui_input.bind(column, row_index))
	var row_margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		row_margin.add_theme_constant_override(side, 4)
	for side: String in ["margin_top", "margin_bottom"]:
		row_margin.add_theme_constant_override(side, 2)
	row.add_child(row_margin)
	var inner: HBoxContainer = HBoxContainer.new()
	row_margin.add_child(inner)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(swatch)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	NesUiTheme.style_caption(name_label)
	inner.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.text = "x0"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	NesUiTheme.style_caption(count_label)
	inner.add_child(count_label)
	if column == COLUMN_COUNTERS:
		swatch.color = ItemDB.get_counter_color(tool_id)
		var trap_id: int = ItemDB.get_trap_for_counter(tool_id)
		name_label.text = "%s  · %s" % [ItemDB.get_counter_name(tool_id), ItemDB.get_trap_name(trap_id)]
	else:
		swatch.color = ItemDB.get_trap_color(tool_id)
		name_label.text = ItemDB.get_trap_name(tool_id)
	_rows[column].append(row)
	_count_labels[column].append(count_label)
	return row


# --- Apertura -----------------------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	visible = true
	_sync_selection_to_held()
	_refresh_counts()
	_refresh_highlight()
	toggled.emit(true)


func close(release_tool: bool = true) -> void:
	var owner: Player = _owner_player()
	if release_tool and is_open and owner != null:
		owner.release_tool_selection()
	is_open = false
	visible = false
	_active_player = null
	toggled.emit(false)


func _toggle_for(p: Player) -> void:
	if is_open and _active_player != p:
		close()
	_active_player = p
	toggle()


# --- Entrada ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if GameState.map_overlay_open:
		return
	if event.is_action_pressed("trapulator") and player != null:
		_toggle_for(player)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("p2_trapulator") and player2 != null:
		_toggle_for(player2)
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	var handled: bool = true
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
	elif event.is_action_pressed("ui_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move_selection(1, 0)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_row_gui_input(event: InputEvent, column: int, row_index: int) -> void:
	if not is_open or not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_selected_column = column
		_selected_row = row_index
		_refresh_highlight()
		_confirm_selection()
		get_viewport().set_input_as_handled()


func _move_selection(column_delta: int, row_delta: int) -> void:
	_selected_column = clampi(_selected_column + column_delta, COLUMN_TRAPS, COLUMN_COUNTERS)
	var count: int = _ids[_selected_column].size()
	if count == 0:
		return
	_selected_row = posmod(clampi(_selected_row, 0, count - 1) + row_delta, count)
	_refresh_highlight()


func _confirm_selection() -> void:
	var owner: Player = _owner_player()
	var ids: Array = _ids[_selected_column]
	if owner == null or _selected_row < 0 or _selected_row >= ids.size():
		return
	var tool_id: int = int(ids[_selected_row])
	var equipped: bool = (
		owner.equip_counter(tool_id) if _selected_column == COLUMN_COUNTERS else owner.equip_trap(tool_id)
	)
	if equipped:
		close(false)


# --- Refresco -----------------------------------------------------------------

func _sync_selection_to_held() -> void:
	_selected_column = COLUMN_TRAPS
	_selected_row = 0
	var owner: Player = _owner_player()
	if owner == null or owner.held == null:
		return
	if owner.held.is_holding_counter():
		_selected_column = COLUMN_COUNTERS
		_selected_row = maxi(_ids[COLUMN_COUNTERS].find(owner.held.get_counter_id()), 0)
	elif owner.held.is_holding_trap():
		_selected_row = maxi(_ids[COLUMN_TRAPS].find(owner.held.get_trap_id()), 0)


func _active_player_index() -> int:
	if _active_player != null and player2 != null and _active_player == player2:
		return 1
	return 0


func _row_style(equipped: bool, selected: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	if equipped:
		box.bg_color = Color("#3a3010")
		box.border_color = NesUiTheme.COLOR_TIMER_WARN
	elif selected:
		box.bg_color = Color("#142414")
		box.border_color = Color("#43a047")
	else:
		box.bg_color = NesUiTheme.COLOR_TOGGLE_UNSELECTED
		box.border_color = NesUiTheme.COLOR_BORDER_DARK
	return box


func _equipped_id(column: int) -> int:
	var owner: Player = _owner_player()
	if owner == null or owner.held == null:
		return -1
	return owner.held.get_counter_id() if column == COLUMN_COUNTERS else owner.held.get_trap_id()


func _refresh_highlight() -> void:
	for column: int in [COLUMN_TRAPS, COLUMN_COUNTERS]:
		var equipped_id: int = _equipped_id(column)
		var rows: Array = _rows[column]
		for i: int in rows.size():
			var row: PanelContainer = rows[i] as PanelContainer
			var equipped: bool = int(_ids[column][i]) == equipped_id
			var selected: bool = column == _selected_column and i == _selected_row
			row.add_theme_stylebox_override("panel", _row_style(equipped, selected))
	_refresh_hint()


func _refresh_hint() -> void:
	var owner: Player = _owner_player()
	if hint_label == null or owner == null:
		return
	var player_index: int = _active_player_index()
	var close_key: String = InputBindings.get_binding_short_label(player_index, "trapulator")
	var place_key: String = InputBindings.get_binding_short_label(player_index, "place_trap")
	var interact_key: String = InputBindings.get_binding_short_label(player_index, "interact")
	if owner.held != null and owner.held.is_holding_carried():
		hint_label.text = (
			"Equipar una herramienta suelta lo que llevas. Recógelo con %s. Cerrar: %s · Equipar: Enter"
			% [interact_key, close_key]
		)
	else:
		hint_label.text = (
			"Cerrar: %s · Elegir: flechas · Equipar: Enter · Colocar trampa: %s\n"
			% [close_key, place_key]
			+ "Lleva la contramedida en la mano al registrar un mueble o cruzar una puerta para desactivar su trampa."
		)


func _refresh_counts() -> void:
	var owner: Player = _owner_player()
	if owner == null:
		return
	var infinite: Array[bool] = [GameState.stock.traps_infinite(), GameState.stock.counters_infinite()]
	for column: int in [COLUMN_TRAPS, COLUMN_COUNTERS]:
		var labels: Array = _count_labels[column]
		for i: int in labels.size():
			var label: Label = labels[i] as Label
			if infinite[column]:
				label.text = "inf"
				continue
			var tool_id: int = int(_ids[column][i])
			var count: int = (
				GameState.get_counter_count(owner.spy_id, tool_id)
				if column == COLUMN_COUNTERS
				else GameState.get_trap_count(owner.spy_id, tool_id)
			)
			label.text = "x%d" % count


func _on_traps_changed(_spy_id: int) -> void:
	if is_open:
		_refresh_counts()


func _on_held_external_change(_kind: int, _held_id: int) -> void:
	if is_open:
		_refresh_highlight()


func _on_game_over(_winner_id: int) -> void:
	if is_open:
		close()
	GameState.map_overlay_close_requested.emit()
