extends MenuScreen
class_name EscapeMenu

# Pausa: reanudar, reiniciar el mapa, ajustes o volver al menú principal.

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal exit_pressed

const BUTTON_WIDTH: float = 300.0

var _subtitle: Label = null
var _resume_button: Button = null
var _buttons: Array[Control] = []


func _ready() -> void:
	layer = 28
	super._ready()


func _build() -> void:
	UiKit.dim_backdrop(root, 0.6)
	var content: VBoxContainer = UiKit.centered_panel(root, Vector2(380, 0), 12)
	content.add_child(UiKit.label("PAUSA", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_subtitle = UiKit.wrapped_label("", &"HintLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_subtitle)
	content.add_child(UiKit.spacer(6.0))
	_resume_button = _add_button(content, "Reanudar", &"PrimaryButton", func() -> void: resume_pressed.emit())
	_add_button(content, "Reiniciar partida", &"", _confirm_restart)
	_add_button(content, "Ajustes", &"", func() -> void: settings_pressed.emit())
	_add_button(content, "Salir al menú", &"DangerButton", _confirm_exit)
	UiKit.chain_focus(_buttons)


func _add_button(parent: Container, text: String, variation: StringName, callback: Callable) -> Button:
	var btn: Button = UiKit.button(text, variation, BUTTON_WIDTH)
	btn.custom_minimum_size.y = 48.0
	btn.pressed.connect(callback)
	parent.add_child(btn)
	_buttons.append(btn)
	return btn


func set_map_name(map_name: String) -> void:
	var where: String = "Mapa: %s   ·   " % map_name if not map_name.is_empty() else ""
	_subtitle.text = "%sEl reloj está detenido" % where


func is_visible_menu() -> bool:
	return visible


func _initial_focus() -> Control:
	return _resume_button


func _on_cancel() -> void:
	resume_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause_menu") or event.is_action_pressed("p2_pause_menu")):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _confirm_restart() -> void:
	UiKit.confirm(root, "Reiniciar partida", "Se pierde el progreso de esta partida.", "Reiniciar",
		func() -> void: restart_pressed.emit())


func _confirm_exit() -> void:
	UiKit.confirm(root, "Salir al menú", "La partida en curso se abandona.", "Salir",
		func() -> void: exit_pressed.emit())
