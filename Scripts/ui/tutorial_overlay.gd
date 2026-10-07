extends MenuScreen
class_name TutorialOverlay

# "Cómo jugar": páginas con las teclas reales (teclado / mando) y las trampas de ItemDB.

signal finished

const KEY_COLOR: String = "#ffd54f"
const PANEL_SIZE: Vector2 = Vector2(760, 520)

var _pages: Array[Dictionary] = []
var _page_index: int = 0
var _title_label: Label = null
var _body: RichTextLabel = null
var _dots: Label = null
var _back_button: Button = null
var _skip_button: Button = null
var _next_button: Button = null


func _ready() -> void:
	layer = 35
	super._ready()


func _build() -> void:
	UiKit.dim_backdrop(root, 0.75)
	var content: VBoxContainer = UiKit.centered_panel(root, PANEL_SIZE, 14)
	_title_label = UiKit.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_title_label)
	content.add_child(HSeparator.new())
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(0, 340)
	_body.add_theme_constant_override("line_separation", 6)
	_body.add_theme_color_override("default_color", NesUiTheme.COLOR_TEXT)
	_body.add_theme_font_size_override("normal_font_size", UiThemeBuilder.FONT_SIZE)
	content.add_child(_body)
	_dots = UiKit.label("", &"SectionLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_dots)
	var actions: HBoxContainer = UiKit.hbox(12)
	content.add_child(actions)
	_skip_button = UiKit.button("Saltar", &"", 140.0)
	_skip_button.pressed.connect(_finish)
	actions.add_child(_skip_button)
	actions.add_child(UiKit.spacer(0.0, true))
	_back_button = UiKit.button("Atrás", &"", 140.0)
	_back_button.pressed.connect(func() -> void: _go_to(_page_index - 1))
	actions.add_child(_back_button)
	_next_button = UiKit.button("Siguiente", &"PrimaryButton", 180.0)
	_next_button.pressed.connect(_on_next_pressed)
	actions.add_child(_next_button)
	var chain: Array[Control] = [_skip_button, _back_button, _next_button]
	UiKit.chain_focus(chain, true, false)


func show_tutorial() -> void:
	_pages = _build_pages()
	_page_index = 0
	show_menu()
	_apply_page()


func is_showing() -> bool:
	return visible


func _initial_focus() -> Control:
	return _next_button


func _on_cancel() -> void:
	_finish()


func _on_next_pressed() -> void:
	if _page_index >= _pages.size() - 1:
		_finish()
	else:
		_go_to(_page_index + 1)


func _go_to(index: int) -> void:
	_page_index = clampi(index, 0, _pages.size() - 1)
	_apply_page()


func _apply_page() -> void:
	var page: Dictionary = _pages[_page_index]
	_title_label.text = String(page.get("title", ""))
	_body.text = String(page.get("body", ""))
	_body.scroll_to_line(0)
	var dots: PackedStringArray = PackedStringArray()
	for i: int in _pages.size():
		dots.append("●" if i == _page_index else "○")
	_dots.text = "  ".join(dots)
	var is_last: bool = _page_index >= _pages.size() - 1
	_next_button.text = "¡A jugar!" if is_last else "Siguiente"
	_back_button.disabled = _page_index == 0
	if _back_button.disabled and _back_button.has_focus():
		_next_button.grab_focus()


func _finish() -> void:
	GameSettings.mark_tutorial_completed()
	hide_menu()
	finished.emit()


# --- Contenido ----------------------------------------------------------------

func _key(action: String) -> String:
	var keyboard: String = InputBindings.get_slot_short_label(action, false)
	var gamepad: String = InputBindings.get_slot_short_label(action, true)
	return "[color=%s]%s[/color] / [color=%s]%s[/color]" % [KEY_COLOR, keyboard, KEY_COLOR, gamepad]


func _hl(text: String) -> String:
	return "[color=%s]%s[/color]" % [KEY_COLOR, text]


func _build_pages() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	pages.append({
		"title": "Bienvenido a Kage",
		"body": (
			"Dos espías, [b]Blanco[/b] y [b]Negro[/b], se cuelan en la misma mansión.\n\n"
			+ "Gana quien escape primero con todo el botín. Por el camino podéis llenar la casa "
			+ "de trampas y usar armas para frenar al otro.\n\n"
			+ "Las teclas aparecen así: %s (teclado / mando)." % _key("interact")
		),
	})
	pages.append({
		"title": "El objetivo",
		"body": (
			"Reúne [b]%s[/b].\n\n" % ", ".join(_item_names())
			+ "Sin maletín solo cabe un objeto en las manos; con él guardas todos.\n\n"
			+ "Sal por la puerta de salida (verde en el mapa) con el botín completo.\n\n"
			+ "Cada espía tiene su propio reloj: si se agota, pierde. Morir no acaba la partida, "
			+ "pero sueltas lo que llevabas, pierdes tiempo y reapareces en otra sala."
		),
	})
	pages.append({
		"title": "Moverse y registrar",
		"body": (
			"Mover: %s / %s\n\n" % [_hl("WASD"), _hl("Stick L")]
			+ "Interactuar: %s. Registra muebles, abre puertas y recoge lo que haya en el suelo. "
			% _key("interact")
			+ "En el panel de tu espía verás qué acción tienes disponible.\n\n"
			+ "Mapa de la mansión: %s\n\n" % _key("toggle_map")
			+ "Pausa: %s" % _key("pause_menu")
		),
	})
	pages.append({
		"title": "Trampas",
		"body": (
			"Mantén %s para abrir la rueda y suelta sobre una trampa para cogerla. "
			% _key("next_trap")
			+ "%s la coloca. %s abre el Trapulator, con el inventario completo.\n\n"
			% [_key("place_trap"), _key("trapulator")]
			+ _trap_table()
		),
	})
	pages.append({
		"title": "Contramedidas",
		"body": (
			"El anillo exterior de la rueda tiene una contramedida para cada trampa.\n\n"
			+ "Si registras un mueble o cruzas una puerta con la contramedida adecuada en la mano, "
			+ "desactivas la trampa sin sufrirla.\n\n"
			+ "El [b]%s[/b] anula la bomba de tiempo de la sala en la que estés." % ItemDB.get_counter_name(ItemDB.CounterId.DEFUSER)
		),
	})
	pages.append({
		"title": "Armas",
		"body": (
			"Las armas aparecen por la mansión: recógelas con %s.\n\n" % _key("interact")
			+ "Apunta con el %s o el %s y dispara con %s.\n\n" % [_hl("ratón"), _hl("stick R"), _key("fire_weapon")]
			+ "Cañón orbital: dispara para cargarlo, lleva la mirilla a la vista del rival "
			+ "y vuelve a disparar. Alcanza cualquier sala, pero tiene un solo disparo."
		),
	})
	return pages


func _item_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for item_id: int in ItemDB.get_all_items():
		names.append(ItemDB.get_item_name(item_id).to_lower())
	return names


func _trap_table() -> String:
	var site_names: Dictionary = {
		ItemDB.TrapSite.FURNITURE: "en un mueble",
		ItemDB.TrapSite.DOOR: "en una puerta",
		ItemDB.TrapSite.ROOM: "en la sala (explota a los %d s)" % int(ItemDB.TIMED_BOMB_FUSE),
	}
	var lines: PackedStringArray = PackedStringArray()
	for trap_id: int in ItemDB.get_all_traps():
		lines.append("• [b]%s[/b] %s" % [ItemDB.get_trap_name(trap_id), String(site_names.get(ItemDB.get_trap_site(trap_id), ""))])
	return "\n".join(lines)
