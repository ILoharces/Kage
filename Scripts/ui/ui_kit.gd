class_name UiKit
extends RefCounted

# Constructores de controles con las variantes del tema global (resources/ui/kage_theme.tres).


static func label(text: String, variation: StringName = &"", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var out: Label = Label.new()
	out.text = text
	out.theme_type_variation = variation
	out.horizontal_alignment = align
	return out


static func wrapped_label(text: String, variation: StringName = &"", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var out: Label = label(text, variation, align)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return out


static func button(text: String, variation: StringName = &"", min_width: float = 0.0) -> Button:
	var out: Button = Button.new()
	out.text = text
	out.theme_type_variation = variation
	out.custom_minimum_size = Vector2(min_width, 0.0)
	out.focus_mode = Control.FOCUS_ALL
	return out


static func toggle(text: String, group: ButtonGroup, min_width: float = 0.0) -> Button:
	var out: Button = button(text, &"", min_width)
	out.toggle_mode = true
	out.button_group = group
	return out


static func vbox(separation: int = 12) -> VBoxContainer:
	var out: VBoxContainer = VBoxContainer.new()
	out.add_theme_constant_override("separation", separation)
	return out


static func hbox(separation: int = 12, alignment: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var out: HBoxContainer = HBoxContainer.new()
	out.add_theme_constant_override("separation", separation)
	out.alignment = alignment
	return out


static func spacer(height: float = 0.0, expand: bool = false) -> Control:
	var out: Control = Control.new()
	out.custom_minimum_size = Vector2(0.0, height)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		out.size_flags_vertical = Control.SIZE_EXPAND_FILL
		out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return out


static func full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


## Panel centrado en pantalla; devuelve el contenedor vertical donde añadir el contenido.
static func centered_panel(parent: Node, min_size: Vector2, separation: int = 14) -> VBoxContainer:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(full_rect(center))
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var content: VBoxContainer = vbox(separation)
	panel.add_child(content)
	return content


static func dim_backdrop(parent: Node, alpha: float = 0.7) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(full_rect(rect))
	return rect


## Enlaza el foco en cadena (arriba/abajo o izquierda/derecha), opcionalmente en bucle.
static func chain_focus(controls: Array[Control], horizontal: bool = false, wrap: bool = true) -> void:
	var count: int = controls.size()
	for i: int in count:
		var current: Control = controls[i]
		var prev_index: int = i - 1
		var next_index: int = i + 1
		if wrap:
			prev_index = posmod(prev_index, count)
			next_index = posmod(next_index, count)
		if prev_index >= 0:
			var prev_path: NodePath = current.get_path_to(controls[prev_index])
			if horizontal:
				current.focus_neighbor_left = prev_path
			else:
				current.focus_neighbor_top = prev_path
		if next_index < count:
			var next_path: NodePath = current.get_path_to(controls[next_index])
			if horizontal:
				current.focus_neighbor_right = next_path
			else:
				current.focus_neighbor_bottom = next_path


## Diálogo de confirmación con el estilo del juego. `on_confirm` se llama al aceptar.
static func confirm(parent: Node, title: String, text: String, ok_text: String, on_confirm: Callable) -> ConfirmationDialog:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "Cancelar"
	dialog.min_size = Vector2i(440, 0)
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.confirmed.connect(on_confirm)
	dialog.visibility_changed.connect(
		func() -> void:
			if not dialog.visible:
				dialog.queue_free()
	)
	parent.add_child(dialog)
	dialog.get_ok_button().theme_type_variation = &"DangerButton"
	dialog.popup_centered()
	dialog.get_cancel_button().grab_focus.call_deferred()
	return dialog
