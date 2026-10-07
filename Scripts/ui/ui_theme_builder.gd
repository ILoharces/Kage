class_name UiThemeBuilder
extends RefCounted

# Genera el Theme global del proyecto (resources/ui/kage_theme.tres) a partir de la paleta NES.
# Regenerar tras cambiarlo: godot --headless --script res://tools/build_ui_theme.gd

const OUTPUT_PATH: String = "res://resources/ui/kage_theme.tres"

const FONT_SIZE: int = 18
const FONT_SIZE_SMALL: int = 15
const FONT_SIZE_HEADER: int = 22
const FONT_SIZE_TITLE: int = 44

const COLOR_SURFACE: Color = Color("#0a0a0a")
const COLOR_SURFACE_HOVER: Color = Color("#1e1e1e")
const COLOR_SURFACE_ACTIVE: Color = Color("#3c3c3c")
const COLOR_DISABLED: Color = Color("#3a3a3a")
const COLOR_TEXT_DISABLED: Color = Color("#5c5c5c")
const COLOR_FOCUS: Color = NesUiTheme.COLOR_TIMER_WARN
const COLOR_PRIMARY: Color = Color("#43a047")
const COLOR_PRIMARY_DARK: Color = Color("#10260f")
const COLOR_DANGER: Color = Color("#e53935")
const COLOR_DANGER_DARK: Color = Color("#2a0909")

const FOCUS_WIDTH: int = 3


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	_build_labels(theme)
	_build_buttons(theme)
	_build_check_buttons(theme)
	_build_option_button(theme)
	_build_popup_menu(theme)
	_build_panels(theme)
	_build_item_list(theme)
	_build_line_edit(theme)
	_build_slider(theme)
	_build_scrollbars(theme)
	_build_separators(theme)
	_build_progress_bar(theme)
	_build_windows(theme)
	_build_tooltip(theme)
	return theme


# --- Piezas -------------------------------------------------------------------

static func box(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	border_width: int = 0,
	margin_h: float = 0.0,
	margin_v: float = 0.0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


static func focus_ring() -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color.TRANSPARENT, COLOR_FOCUS, FOCUS_WIDTH)
	style.draw_center = false
	style.set_expand_margin_all(2.0)
	return style


static func _empty(margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxEmpty:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


static func _set_font_colors(theme: Theme, type_name: String, normal: Color, disabled: Color) -> void:
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(item, type_name, normal)
	theme.set_color("font_disabled_color", type_name, disabled)
	theme.set_color("font_outline_color", type_name, Color.BLACK)


# --- Tipos --------------------------------------------------------------------

static func _build_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font_size("font_size", "TitleLabel", FONT_SIZE_TITLE)
	theme.set_color("font_shadow_color", "TitleLabel", Color("#5a5a5a"))
	theme.set_constant("shadow_offset_x", "TitleLabel", 3)
	theme.set_constant("shadow_offset_y", "TitleLabel", 3)

	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font_size("font_size", "HeaderLabel", FONT_SIZE_HEADER)

	theme.set_type_variation("HintLabel", "Label")
	theme.set_font_size("font_size", "HintLabel", FONT_SIZE_SMALL)
	theme.set_color("font_color", "HintLabel", NesUiTheme.COLOR_TEXT_DIM)

	theme.set_type_variation("SectionLabel", "Label")
	theme.set_font_size("font_size", "SectionLabel", FONT_SIZE_SMALL)
	theme.set_color("font_color", "SectionLabel", NesUiTheme.COLOR_BORDER)

	theme.set_type_variation("WarningLabel", "Label")
	theme.set_font_size("font_size", "WarningLabel", FONT_SIZE_SMALL)
	theme.set_color("font_color", "WarningLabel", NesUiTheme.COLOR_TIMER_WARN)


static func _button_styles(theme: Theme, type_name: String, accent: Color, accent_bg: Color) -> void:
	theme.set_stylebox("normal", type_name, box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER_DARK, 2, 16.0, 8.0))
	theme.set_stylebox("hover", type_name, box(COLOR_SURFACE_HOVER, accent, 2, 16.0, 8.0))
	theme.set_stylebox("pressed", type_name, box(accent_bg, accent, 2, 16.0, 8.0))
	theme.set_stylebox("hover_pressed", type_name, box(accent_bg, NesUiTheme.COLOR_TEXT, 2, 16.0, 8.0))
	theme.set_stylebox("disabled", type_name, box(COLOR_SURFACE, COLOR_DISABLED, 2, 16.0, 8.0))
	theme.set_stylebox("focus", type_name, focus_ring())


static func _build_buttons(theme: Theme) -> void:
	_button_styles(theme, "Button", NesUiTheme.COLOR_BORDER, COLOR_SURFACE_ACTIVE)
	_set_font_colors(theme, "Button", NesUiTheme.COLOR_TEXT, COLOR_TEXT_DISABLED)
	theme.set_constant("h_separation", "Button", 8)

	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", COLOR_PRIMARY, COLOR_PRIMARY_DARK)
	theme.set_stylebox("normal", "PrimaryButton", box(COLOR_PRIMARY_DARK, COLOR_PRIMARY, 2, 16.0, 8.0))
	theme.set_color("font_color", "PrimaryButton", Color("#c8f5cb"))

	theme.set_type_variation("DangerButton", "Button")
	_button_styles(theme, "DangerButton", COLOR_DANGER, COLOR_DANGER_DARK)
	theme.set_color("font_hover_color", "DangerButton", Color("#ffb3b0"))

	theme.set_type_variation("BigButton", "Button")
	theme.set_font_size("font_size", "BigButton", FONT_SIZE_HEADER)
	theme.set_stylebox("normal", "BigButton", box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER_DARK, 2, 20.0, 10.0))
	theme.set_stylebox("hover", "BigButton", box(COLOR_SURFACE_HOVER, NesUiTheme.COLOR_BORDER, 2, 20.0, 10.0))
	theme.set_stylebox("pressed", "BigButton", box(COLOR_SURFACE_ACTIVE, NesUiTheme.COLOR_BORDER, 2, 20.0, 10.0))


static func _build_check_buttons(theme: Theme) -> void:
	for type_name: String in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type_name, _empty(8.0, 6.0))
		theme.set_stylebox("pressed", type_name, _empty(8.0, 6.0))
		theme.set_stylebox("hover", type_name, box(COLOR_SURFACE_HOVER, Color.TRANSPARENT, 0, 8.0, 6.0))
		theme.set_stylebox("hover_pressed", type_name, box(COLOR_SURFACE_HOVER, Color.TRANSPARENT, 0, 8.0, 6.0))
		theme.set_stylebox("disabled", type_name, _empty(8.0, 6.0))
		theme.set_stylebox("focus", type_name, focus_ring())
		_set_font_colors(theme, type_name, NesUiTheme.COLOR_TEXT, COLOR_TEXT_DISABLED)
		theme.set_constant("h_separation", type_name, 10)


static func _build_option_button(theme: Theme) -> void:
	_button_styles(theme, "OptionButton", NesUiTheme.COLOR_BORDER, COLOR_SURFACE_ACTIVE)
	_set_font_colors(theme, "OptionButton", NesUiTheme.COLOR_TEXT, COLOR_TEXT_DISABLED)
	theme.set_constant("arrow_margin", "OptionButton", 10)


static func _build_popup_menu(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER, 2, 6.0, 6.0))
	theme.set_stylebox("hover", "PopupMenu", box(COLOR_SURFACE_ACTIVE, COLOR_FOCUS, 1))
	theme.set_color("font_color", "PopupMenu", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", COLOR_TEXT_DISABLED)
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_constant("item_end_padding", "PopupMenu", 10)


static func _build_panels(theme: Theme) -> void:
	var panel: StyleBoxFlat = box(NesUiTheme.COLOR_BG, NesUiTheme.COLOR_BORDER, NesUiTheme.BORDER_WIDTH, 28.0, 24.0)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", box(NesUiTheme.COLOR_SLOT_EMPTY, NesUiTheme.COLOR_BORDER_DARK, 2, 14.0, 12.0))

	theme.set_type_variation("BarePanel", "PanelContainer")
	theme.set_stylebox("panel", "BarePanel", _empty())


static func _build_item_list(theme: Theme) -> void:
	theme.set_stylebox("panel", "ItemList", box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER_DARK, 2, 6.0, 6.0))
	theme.set_stylebox("focus", "ItemList", focus_ring())
	theme.set_stylebox("hovered", "ItemList", box(COLOR_SURFACE_HOVER))
	theme.set_stylebox("selected", "ItemList", box(COLOR_SURFACE_ACTIVE, NesUiTheme.COLOR_BORDER_DARK, 1))
	theme.set_stylebox("selected_focus", "ItemList", box(COLOR_SURFACE_ACTIVE, COLOR_FOCUS, 2))
	theme.set_stylebox("hovered_selected", "ItemList", box(COLOR_SURFACE_ACTIVE, NesUiTheme.COLOR_BORDER, 1))
	theme.set_stylebox("hovered_selected_focus", "ItemList", box(COLOR_SURFACE_ACTIVE, COLOR_FOCUS, 2))
	theme.set_stylebox("cursor", "ItemList", _empty())
	theme.set_stylebox("cursor_unfocused", "ItemList", _empty())
	theme.set_color("font_color", "ItemList", NesUiTheme.COLOR_TEXT_DIM)
	theme.set_color("font_hovered_color", "ItemList", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_selected_color", "ItemList", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_hovered_selected_color", "ItemList", NesUiTheme.COLOR_TEXT)
	theme.set_color("guide_color", "ItemList", Color(0, 0, 0, 0))
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_constant("h_separation", "ItemList", 10)
	theme.set_constant("line_separation", "ItemList", 4)


static func _build_line_edit(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER_DARK, 2, 10.0, 8.0))
	theme.set_stylebox("focus", "LineEdit", focus_ring())
	theme.set_stylebox("read_only", "LineEdit", box(COLOR_SURFACE, COLOR_DISABLED, 2, 10.0, 8.0))
	theme.set_color("font_color", "LineEdit", NesUiTheme.COLOR_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_DISABLED)
	theme.set_color("caret_color", "LineEdit", COLOR_FOCUS)
	theme.set_color("selection_color", "LineEdit", Color(1.0, 0.84, 0.31, 0.35))


static func _build_slider(theme: Theme) -> void:
	var track: StyleBoxFlat = box(Color("#262626"), NesUiTheme.COLOR_BORDER_DARK, 1)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	theme.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = box(NesUiTheme.COLOR_BORDER)
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hot: StyleBoxFlat = box(COLOR_FOCUS)
	fill_hot.content_margin_top = 4.0
	fill_hot.content_margin_bottom = 4.0
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hot)
	theme.set_stylebox("focus", "HSlider", focus_ring())


static func _build_scrollbars(theme: Theme) -> void:
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, box(COLOR_SURFACE, Color.TRANSPARENT, 0, 4.0, 4.0))
		theme.set_stylebox("scroll_focus", type_name, box(COLOR_SURFACE, Color.TRANSPARENT, 0, 4.0, 4.0))
		theme.set_stylebox("grabber", type_name, box(Color("#4a4a4a")))
		theme.set_stylebox("grabber_highlight", type_name, box(NesUiTheme.COLOR_TEXT_DIM))
		theme.set_stylebox("grabber_pressed", type_name, box(NesUiTheme.COLOR_BORDER))


static func _build_separators(theme: Theme) -> void:
	var h_line: StyleBoxLine = StyleBoxLine.new()
	h_line.color = NesUiTheme.COLOR_BORDER_DARK
	h_line.thickness = 2
	theme.set_stylebox("separator", "HSeparator", h_line)
	theme.set_constant("separation", "HSeparator", 12)
	var v_line: StyleBoxLine = StyleBoxLine.new()
	v_line.color = NesUiTheme.COLOR_BORDER_DARK
	v_line.thickness = 2
	v_line.vertical = true
	theme.set_stylebox("separator", "VSeparator", v_line)
	theme.set_constant("separation", "VSeparator", 12)


static func _build_progress_bar(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", box(Color("#1a1a1a"), NesUiTheme.COLOR_BORDER_DARK, 1))
	theme.set_stylebox("fill", "ProgressBar", box(COLOR_PRIMARY))
	theme.set_color("font_color", "ProgressBar", NesUiTheme.COLOR_TEXT)


static func _build_windows(theme: Theme) -> void:
	var border: StyleBoxFlat = box(NesUiTheme.COLOR_BG, NesUiTheme.COLOR_BORDER, NesUiTheme.BORDER_WIDTH)
	border.expand_margin_top = 40.0
	border.set_expand_margin(SIDE_LEFT, float(NesUiTheme.BORDER_WIDTH))
	border.set_expand_margin(SIDE_RIGHT, float(NesUiTheme.BORDER_WIDTH))
	border.set_expand_margin(SIDE_BOTTOM, float(NesUiTheme.BORDER_WIDTH))
	theme.set_stylebox("embedded_border", "Window", border)
	theme.set_stylebox("embedded_unfocused_border", "Window", border)
	theme.set_color("title_color", "Window", NesUiTheme.COLOR_TEXT)
	theme.set_font_size("title_font_size", "Window", FONT_SIZE)
	theme.set_constant("title_height", "Window", 36)
	theme.set_stylebox("panel", "AcceptDialog", box(NesUiTheme.COLOR_BG, Color.TRANSPARENT, 0, 20.0, 16.0))
	theme.set_constant("buttons_separation", "AcceptDialog", 16)
	theme.set_constant("buttons_min_width", "AcceptDialog", 140)
	theme.set_constant("buttons_min_height", "AcceptDialog", 40)


static func _build_tooltip(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(COLOR_SURFACE, NesUiTheme.COLOR_BORDER, 2, 10.0, 6.0))
	theme.set_color("font_color", "TooltipLabel", NesUiTheme.COLOR_TEXT)
	theme.set_font_size("font_size", "TooltipLabel", FONT_SIZE_SMALL)
