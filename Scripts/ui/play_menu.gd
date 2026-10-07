extends MenuScreen
class_name PlayMenu

# Elegir mapa guardado, ver su miniatura y elegir rival (IA o segundo jugador).

signal map_selected(layout: LevelLayout)
signal edit_requested(map_id: String)
signal create_map_requested

var _entries: Array[Dictionary] = []
var _last_map_id: String = ""

var _list: ItemList = null
var _preview: MapPreview = null
var _info_label: Label = null
var _warning_label: Label = null
var _status_label: Label = null
var _ai_toggle: Button = null
var _local_toggle: Button = null
var _back_button: Button = null
var _delete_button: Button = null
var _edit_button: Button = null
var _play_button: Button = null
var _create_button: Button = null
var _rival_group: ButtonGroup = null


func _ready() -> void:
	layer = 25
	super._ready()


func _build() -> void:
	var content: VBoxContainer = UiKit.centered_panel(root, Vector2(1000, 0), 16)
	content.add_child(UiKit.label("Elegir mapa", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var body: HBoxContainer = UiKit.hbox(24)
	content.add_child(body)
	var left: VBoxContainer = UiKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(UiKit.label("MAPAS GUARDADOS", &"SectionLabel"))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(400, 400)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.allow_reselect = true
	_list.item_selected.connect(_on_item_selected)
	_list.item_activated.connect(func(_index: int) -> void: _on_play_pressed())
	left.add_child(_list)
	_create_button = UiKit.button("Crear un mapa nuevo")
	_create_button.pressed.connect(func() -> void: create_map_requested.emit())
	left.add_child(_create_button)

	var right: VBoxContainer = UiKit.vbox(8)
	body.add_child(right)
	right.add_child(UiKit.label("VISTA PREVIA", &"SectionLabel"))
	_preview = MapPreview.new()
	_preview.custom_minimum_size = Vector2(440, 340)
	right.add_child(_preview)
	_info_label = UiKit.wrapped_label("", &"HintLabel")
	_info_label.custom_minimum_size.x = 440.0
	right.add_child(_info_label)
	_warning_label = UiKit.wrapped_label("", &"WarningLabel")
	_warning_label.custom_minimum_size.x = 440.0
	right.add_child(_warning_label)

	content.add_child(HSeparator.new())
	var rival_row: HBoxContainer = UiKit.hbox(12)
	content.add_child(rival_row)
	var rival_title: Label = UiKit.label("RIVAL", &"SectionLabel")
	rival_title.custom_minimum_size.x = 80.0
	rival_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rival_row.add_child(rival_title)
	_rival_group = ButtonGroup.new()
	_ai_toggle = UiKit.toggle("Contra la IA", _rival_group, 220.0)
	_local_toggle = UiKit.toggle("2 jugadores (local)", _rival_group, 220.0)
	_ai_toggle.toggled.connect(_on_rival_toggled)
	rival_row.add_child(_ai_toggle)
	rival_row.add_child(_local_toggle)
	_status_label = UiKit.wrapped_label("", &"HintLabel")
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rival_row.add_child(_status_label)

	var actions: HBoxContainer = UiKit.hbox(12)
	content.add_child(actions)
	_back_button = UiKit.button("Volver", &"", 140.0)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(_back_button)
	actions.add_child(UiKit.spacer(0.0, true))
	_delete_button = UiKit.button("Borrar", &"DangerButton", 120.0)
	_delete_button.pressed.connect(_on_delete_pressed)
	actions.add_child(_delete_button)
	_edit_button = UiKit.button("Editar", &"", 120.0)
	_edit_button.pressed.connect(_on_edit_pressed)
	actions.add_child(_edit_button)
	_play_button = UiKit.button("Jugar", &"PrimaryButton", 180.0)
	_play_button.pressed.connect(_on_play_pressed)
	actions.add_child(_play_button)
	_wire_focus()


func _wire_focus() -> void:
	var action_chain: Array[Control] = [_back_button, _delete_button, _edit_button, _play_button]
	UiKit.chain_focus(action_chain, true, false)
	var rival_chain: Array[Control] = [_ai_toggle, _local_toggle]
	UiKit.chain_focus(rival_chain, true, false)
	_list.focus_neighbor_bottom = _list.get_path_to(_create_button)
	_create_button.focus_neighbor_top = _create_button.get_path_to(_list)
	_create_button.focus_neighbor_bottom = _create_button.get_path_to(_ai_toggle)
	for toggle: Button in [_ai_toggle, _local_toggle]:
		toggle.focus_neighbor_top = toggle.get_path_to(_create_button)
		toggle.focus_neighbor_bottom = toggle.get_path_to(_play_button)
	for action: Control in action_chain:
		action.focus_neighbor_top = action.get_path_to(_ai_toggle)


# --- Ciclo de vida ------------------------------------------------------------

func _on_shown() -> void:
	var use_ai: bool = GameSettings.use_ai_default
	_ai_toggle.set_pressed_no_signal(use_ai)
	_local_toggle.set_pressed_no_signal(not use_ai)
	GameState.use_ai = use_ai
	_refresh_list()
	_update_status()


func _initial_focus() -> Control:
	if _entries.is_empty():
		return _create_button
	return _play_button if not _play_button.disabled else _list


func _refresh_list() -> void:
	_list.clear()
	_entries = MapStorage.list_map_entries()
	for entry: Dictionary in _entries:
		_list.add_item(String(entry.get("label", entry.get("id", "Mapa"))))
	if _entries.is_empty():
		_preview.show_message("Todavía no hay mapas guardados.\nCrea uno en el editor.")
		_info_label.text = ""
		_warning_label.text = ""
		_set_map_actions_enabled(false)
		return
	var index: int = 0
	for i: int in _entries.size():
		if String(_entries[i].get("id", "")) == _last_map_id:
			index = i
			break
	_list.select(index)
	_list.ensure_current_is_visible()
	_on_item_selected(index)


func _set_map_actions_enabled(enabled: bool) -> void:
	_delete_button.disabled = not enabled
	_edit_button.disabled = not enabled
	_play_button.disabled = not enabled


func _selected_index() -> int:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		return -1
	return int(selected[0])


func _selected_id() -> String:
	var index: int = _selected_index()
	if index < 0 or index >= _entries.size():
		return ""
	return String(_entries[index].get("id", ""))


func _layout_for(index: int) -> LevelLayout:
	if index < 0 or index >= _entries.size():
		return null
	var entry: Dictionary = _entries[index]
	var data: Dictionary = entry.get("data", {}) as Dictionary
	if data.is_empty():
		return null
	return MapStorage.data_to_layout(data, String(entry.get("label", "mapa")))


# --- Selección ----------------------------------------------------------------

func _on_item_selected(index: int) -> void:
	_last_map_id = _selected_id()
	var layout: LevelLayout = _layout_for(index)
	if layout == null or layout.room_cells.is_empty():
		_preview.show_message("Mapa vacío o dañado.")
		_info_label.text = ""
		_warning_label.text = "No se puede jugar este mapa."
		_set_map_actions_enabled(true)
		_play_button.disabled = true
		return
	_preview.show_layout(layout)
	_info_label.text = "%d habitaciones  ·  %d puertas" % [layout.room_cells.size(), layout.get_door_specs().size()]
	var warnings: PackedStringArray = PackedStringArray()
	var playable: bool = true
	if layout.get_exit_door_spec().is_empty():
		warnings.append("Sin puerta de salida: ábrelo en el editor y coloca una.")
		playable = false
	var unreachable: Array[Vector2i] = layout.find_unreachable_room_cells()
	if not unreachable.is_empty():
		warnings.append("%d habitación(es) inaccesibles." % unreachable.size())
	_warning_label.text = "\n".join(warnings)
	_set_map_actions_enabled(true)
	_play_button.disabled = not playable


func _on_rival_toggled(_pressed: bool) -> void:
	var use_ai: bool = _ai_toggle.button_pressed
	GameState.use_ai = use_ai
	GameSettings.set_option_value("use_ai_default", use_ai)
	_update_status()


func _update_status() -> void:
	if _ai_toggle.button_pressed:
		_status_label.text = "Juegas con teclado y ratón o con mando; se adapta solo."
		return
	if InputBindings.needs_two_gamepads_for_local_play() and not InputBindings.has_enough_gamepads_for_local_play():
		_status_label.text = "Faltan mandos: hay %d conectado(s) y se necesitan 2 (Ajustes > Controles)." % InputBindings.get_connected_gamepad_count()
		return
	_status_label.text = "Blanco: %s  ·  Negro: %s" % [
		InputBindings.get_control_mode_label(InputBindings.get_control_mode(0), 0),
		InputBindings.get_control_mode_label(InputBindings.get_control_mode(1), 1),
	]


# --- Acciones -----------------------------------------------------------------

func _on_play_pressed() -> void:
	if _play_button.disabled:
		return
	var layout: LevelLayout = _layout_for(_selected_index())
	if layout == null:
		return
	GameState.use_ai = _ai_toggle.button_pressed
	if not GameState.use_ai and not InputBindings.has_enough_gamepads_for_local_play():
		_update_status()
		_local_toggle.grab_focus()
		return
	hide_menu()
	map_selected.emit(layout)


func _on_edit_pressed() -> void:
	var map_id: String = _selected_id()
	if map_id.is_empty():
		return
	hide_menu()
	edit_requested.emit(map_id)


func _on_delete_pressed() -> void:
	var index: int = _selected_index()
	if index < 0 or index >= _entries.size():
		return
	var map_id: String = _selected_id()
	var label: String = String(_entries[index].get("label", map_id))
	UiKit.confirm(
		root,
		"Borrar mapa",
		"¿Borrar «%s»? No se puede deshacer." % label,
		"Borrar",
		func() -> void:
			MapStorage.delete_map(map_id)
			_last_map_id = ""
			_refresh_list()
			_list.grab_focus()
	)
