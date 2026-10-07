extends MenuScreen
class_name SettingsMenu

# Ajustes: pestaña General (generada desde GameSettings) y Controles. Se guardan al cambiar.

enum Tab { GENERAL, CONTROLS }

const _CONTROLS_PANEL_SCENE: PackedScene = preload("res://Scenes/ui/controls_settings_panel.tscn")

var _tab_buttons: Array[Button] = []
var _general_page: ScrollContainer = null
var _options_vbox: VBoxContainer = null
var _controls_page: ControlsSettingsPanel = null
var _back_button: Button = null
var _hint_label: Label = null
var _widgets_by_id: Dictionary = {}
var _first_option: Control = null
var _current_tab: Tab = Tab.GENERAL
var _tab_group: ButtonGroup = null


func _ready() -> void:
	layer = 29
	super._ready()
	GameSettings.setting_changed.connect(_on_setting_changed)


func _build() -> void:
	UiKit.dim_backdrop(root, 0.6)
	var content: VBoxContainer = UiKit.centered_panel(root, Vector2(780, 0), 14)
	content.add_child(UiKit.label("Ajustes", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var tabs: HBoxContainer = UiKit.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	content.add_child(tabs)
	_tab_group = ButtonGroup.new()
	for tab_name: String in ["General", "Controles"]:
		var tab_button: Button = UiKit.toggle(tab_name, _tab_group, 180.0)
		tab_button.pressed.connect(_show_tab.bind(_tab_buttons.size()))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)
	var tab_chain: Array[Control] = []
	tab_chain.assign(_tab_buttons)
	UiKit.chain_focus(tab_chain, true, false)

	var pages: Control = Control.new()
	pages.custom_minimum_size = Vector2(0, 460)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(pages)
	_general_page = ScrollContainer.new()
	_general_page.follow_focus = true
	_general_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(UiKit.full_rect(_general_page))
	_options_vbox = UiKit.vbox(10)
	_options_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_general_page.add_child(_options_vbox)
	_controls_page = _CONTROLS_PANEL_SCENE.instantiate() as ControlsSettingsPanel
	_controls_page.visible = false
	pages.add_child(_controls_page)
	UiKit.full_rect(_controls_page)
	_build_options()

	_hint_label = UiKit.wrapped_label("", &"HintLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_hint_label)
	var actions: HBoxContainer = UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	content.add_child(actions)
	_back_button = UiKit.button("Volver", &"", 200.0)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(_back_button)


func _on_shown() -> void:
	_sync_widgets_from_settings()
	_controls_page.refresh()
	_show_tab(Tab.GENERAL)


func _on_hidden() -> void:
	get_viewport().gui_release_focus()


func _initial_focus() -> Control:
	return _first_option if _first_option != null else _back_button


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadButton and event.is_pressed():
		var button_index: JoyButton = (event as InputEventJoypadButton).button_index
		if button_index == JOY_BUTTON_LEFT_SHOULDER or button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_show_tab(posmod(int(_current_tab) + (1 if button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), 2))
			_grab_initial_focus_for_tab()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _show_tab(tab: int) -> void:
	_current_tab = tab as Tab
	_general_page.visible = _current_tab == Tab.GENERAL
	_controls_page.visible = _current_tab == Tab.CONTROLS
	_tab_buttons[tab].set_pressed_no_signal(true)
	for button: Button in _tab_buttons:
		button.focus_neighbor_bottom = button.get_path_to(_page_first_focus())
	if _current_tab == Tab.CONTROLS:
		_controls_page.refresh()
		_controls_page.wire_external_focus_down(_back_button)
	_hint_label.text = (
		"LB / RB: cambiar de pestaña   ·   Los cambios se guardan al momento"
		if _current_tab == Tab.GENERAL
		else "LB / RB: cambiar de pestaña   ·   Los controles son fijos; aquí eliges el dispositivo"
	)


func _page_first_focus() -> Control:
	if _current_tab == Tab.CONTROLS:
		var first: Control = _controls_page.get_first_focus_control()
		return first if first != null else _back_button
	return _first_option if _first_option != null else _back_button


func _grab_initial_focus_for_tab() -> void:
	var target: Control = _page_first_focus()
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


# --- Opciones generales -------------------------------------------------------

func _build_options() -> void:
	for section: Dictionary in GameSettings.get_sections():
		_options_vbox.add_child(UiKit.label(String(section.get("title", "")).to_upper(), &"SectionLabel"))
		for option: Variant in section.get("options", []) as Array:
			_add_option_row(option as Dictionary)
		_options_vbox.add_child(UiKit.spacer(8.0))


func _add_option_row(entry: Dictionary) -> void:
	var option_id: String = String(entry.get("id", ""))
	var row: VBoxContainer = UiKit.vbox(2)
	var widget: Control = null
	match String(entry.get("type", "")):
		"bool":
			var check: CheckButton = CheckButton.new()
			check.text = String(entry.get("label", option_id))
			check.toggled.connect(func(pressed: bool) -> void: GameSettings.set_option_value(option_id, pressed))
			widget = check
			row.add_child(check)
		"float":
			widget = _add_slider_row(row, entry, option_id)
		_:
			return
	widget.focus_mode = Control.FOCUS_ALL
	_widgets_by_id[option_id] = widget
	if _first_option == null:
		_first_option = widget
	var hint_text: String = String(entry.get("hint", ""))
	if not hint_text.is_empty():
		row.add_child(UiKit.wrapped_label(hint_text, &"HintLabel"))
	_options_vbox.add_child(row)


func _add_slider_row(row: VBoxContainer, entry: Dictionary, option_id: String) -> HSlider:
	var header: HBoxContainer = UiKit.hbox(12)
	var name_label: Label = UiKit.label(String(entry.get("label", option_id)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label: Label = UiKit.label("", &"SectionLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size.x = 64.0
	header.add_child(value_label)
	row.add_child(header)
	var slider: HSlider = HSlider.new()
	slider.min_value = float(entry.get("min", 0.0))
	slider.max_value = float(entry.get("max", 1.0))
	slider.step = float(entry.get("step", 0.05))
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.set_meta("value_label", value_label)
	slider.value_changed.connect(
		func(value: float) -> void:
			GameSettings.set_option_value(option_id, value)
			_refresh_slider_label(slider)
	)
	row.add_child(slider)
	return slider


func _refresh_slider_label(slider: HSlider) -> void:
	var value_label: Label = slider.get_meta("value_label") as Label
	value_label.text = "%d%%" % int(roundf(slider.value * 100.0))


func _sync_widget(option_id: String) -> void:
	var widget: Control = _widgets_by_id.get(option_id) as Control
	var value: Variant = GameSettings.get_option_value(option_id)
	if widget is CheckButton:
		(widget as CheckButton).set_pressed_no_signal(bool(value))
	elif widget is HSlider:
		var slider: HSlider = widget as HSlider
		slider.set_value_no_signal(float(value))
		_refresh_slider_label(slider)


func _sync_widgets_from_settings() -> void:
	for option_id: Variant in _widgets_by_id.keys():
		_sync_widget(String(option_id))


func _on_setting_changed(option_id: String, _value: Variant) -> void:
	if _widgets_by_id.has(option_id):
		_sync_widget(option_id)
