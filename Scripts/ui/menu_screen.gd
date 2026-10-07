class_name MenuScreen
extends CanvasLayer

# Base de las pantallas de menú: construcción por código, fundido al mostrarse,
# foco inicial (mando/teclado) y Esc / B para volver.

signal back_requested

const FADE_TIME: float = 0.14

## Raíz de la pantalla; las subclases cuelgan aquí su contenido en `_build()`.
var root: Control = null
var _fade_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(root))
	_build()


func show_menu() -> void:
	visible = true
	_on_shown()
	_fade_in()
	_grab_initial_focus.call_deferred()


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	_on_hidden()


func is_open() -> bool:
	return visible


# --- Para sobrescribir --------------------------------------------------------

func _build() -> void:
	pass


func _on_shown() -> void:
	pass


func _on_hidden() -> void:
	pass


func _initial_focus() -> Control:
	return null


func _on_cancel() -> void:
	back_requested.emit()


# --- Internos -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


func _grab_initial_focus() -> void:
	if not visible:
		return
	var target: Control = _initial_focus()
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()


func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_fade_tween = root.create_tween()
	_fade_tween.tween_property(root, "modulate:a", 1.0, FADE_TIME)
