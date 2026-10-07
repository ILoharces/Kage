extends MenuScreen
class_name MainMenu

signal play_pressed
signal create_map_pressed
signal tutorial_pressed
signal settings_pressed
signal quit_pressed

const BUTTON_WIDTH: float = 380.0

var _buttons: Array[Button] = []
var _quit_button: Button = null
var _last_focused: Button = null


func _ready() -> void:
	layer = 30
	super._ready()


func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(UiKit.full_rect(center))
	var column: VBoxContainer = UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title: Label = UiKit.label("KAGE", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 96)
	column.add_child(title)
	column.add_child(UiKit.label("Espías en la mansión", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UiKit.spacer(28.0))

	_add_button(column, "Jugar", play_pressed, &"PrimaryButton")
	_add_button(column, "Crear mapa", create_map_pressed)
	_add_button(column, "Cómo jugar", tutorial_pressed)
	_add_button(column, "Ajustes", settings_pressed)
	_quit_button = _add_button(column, "Salir", quit_pressed)
	var focus_chain: Array[Control] = []
	focus_chain.assign(_buttons)
	UiKit.chain_focus(focus_chain)

	var footer: Label = UiKit.label(
		"Flechas / stick: elegir   ·   Enter / A: aceptar   ·   Esc / B: volver",
		&"HintLabel",
		HORIZONTAL_ALIGNMENT_CENTER
	)
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -72.0
	footer.offset_bottom = -36.0


func _add_button(parent: Container, text: String, pressed_signal: Signal, variation: StringName = &"BigButton") -> Button:
	var btn: Button = UiKit.button(text, variation, BUTTON_WIDTH)
	if variation != &"BigButton":
		btn.add_theme_font_size_override("font_size", UiThemeBuilder.FONT_SIZE_HEADER)
		btn.custom_minimum_size.y = 52.0
	btn.pressed.connect(
		func() -> void:
			_last_focused = btn
			pressed_signal.emit()
	)
	parent.add_child(btn)
	_buttons.append(btn)
	return btn


func _initial_focus() -> Control:
	if _last_focused != null:
		return _last_focused
	return _buttons[0]


func _on_cancel() -> void:
	_quit_button.grab_focus()
