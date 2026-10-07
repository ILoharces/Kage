class_name MapPreview
extends Control

# Miniatura de un LevelLayout: habitaciones, puertas, salida y spawns de cada espía.

const PAD: float = 14.0
const GAP: float = 3.0
const ROOM_COLOR: Color = Color("#8f8f8f")
const DOOR_COLOR: Color = Color("#c62828")
const EXIT_COLOR: Color = Color("#4caf50")
const EMPTY_TEXT_COLOR: Color = Color("#8a8a8a")

var _layout: LevelLayout = null
var _empty_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_layout(layout: LevelLayout) -> void:
	_layout = layout
	_empty_text = ""
	queue_redraw()


func show_message(text: String) -> void:
	_layout = null
	_empty_text = text
	queue_redraw()


func _draw() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, NesUiTheme.COLOR_BG, true)
	draw_rect(frame, NesUiTheme.COLOR_BORDER_DARK, false, 2.0)
	if _layout == null or _layout.room_cells.is_empty():
		_draw_centered_text(_empty_text)
		return
	var cols: int = maxi(_layout.grid_width, 1)
	var rows: int = maxi(_layout.grid_height, 1)
	var inner: Vector2 = size - Vector2(PAD, PAD) * 2.0
	var cell: float = minf(inner.x / float(cols), inner.y / float(rows))
	var origin: Vector2 = Vector2(PAD, PAD) + (inner - Vector2(cols, rows) * cell) * 0.5
	for key: Variant in _layout.room_cells.keys():
		draw_rect(_cell_rect(origin, cell, key as Vector2i), ROOM_COLOR, true)
	for spec: Dictionary in _layout.get_door_specs():
		_draw_door(origin, cell, spec["cell"] as Vector2i, String(spec["dir"]), DOOR_COLOR)
	var exit_spec: Dictionary = _layout.get_exit_door_spec()
	if not exit_spec.is_empty():
		_draw_door(origin, cell, exit_spec["cell"] as Vector2i, String(exit_spec["dir"]), EXIT_COLOR, 2.0)
	_draw_spawn(origin, cell, _layout.player_spawn_cell, ItemDB.SpyId.PLAYER1, -0.18)
	_draw_spawn(origin, cell, _layout.ai_spawn_cell, ItemDB.SpyId.PLAYER2, 0.18)


func _cell_rect(origin: Vector2, cell: float, gp: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(gp) * cell + Vector2(GAP, GAP) * 0.5, Vector2(cell - GAP, cell - GAP))


func _draw_door(origin: Vector2, cell: float, gp: Vector2i, dir_str: String, color: Color, thickness_scale: float = 1.0) -> void:
	var rect: Rect2 = _cell_rect(origin, cell, gp)
	var thick: float = maxf(cell * 0.09, 2.0) * thickness_scale
	var span: float = rect.size.x * 0.34
	var center: Vector2 = rect.get_center()
	var half: Vector2 = rect.size * 0.5
	var door_rect: Rect2
	match dir_str:
		"N":
			door_rect = Rect2(Vector2(center.x - span * 0.5, rect.position.y - thick * 0.5), Vector2(span, thick))
		"S":
			door_rect = Rect2(Vector2(center.x - span * 0.5, center.y + half.y - thick * 0.5), Vector2(span, thick))
		"W":
			door_rect = Rect2(Vector2(rect.position.x - thick * 0.5, center.y - span * 0.5), Vector2(thick, span))
		_:
			door_rect = Rect2(Vector2(center.x + half.x - thick * 0.5, center.y - span * 0.5), Vector2(thick, span))
	draw_rect(door_rect, color, true)


func _draw_spawn(origin: Vector2, cell: float, gp: Vector2i, spy_id: int, x_offset: float) -> void:
	if gp.x < 0:
		return
	var rect: Rect2 = _cell_rect(origin, cell, gp)
	var radius: float = maxf(cell * 0.14, 4.0)
	var pos: Vector2 = rect.get_center() + Vector2(rect.size.x * x_offset, 0.0)
	var fill: Color = ItemDB.SPY_COLORS.get(spy_id, Color.WHITE) as Color
	draw_circle(pos, radius + 2.0, NesUiTheme.COLOR_BORDER if fill.get_luminance() < 0.3 else Color.BLACK)
	draw_circle(pos, radius, fill)


func _draw_centered_text(text: String) -> void:
	if text.is_empty():
		return
	var font: Font = get_theme_default_font()
	var font_size: int = UiThemeBuilder.FONT_SIZE_SMALL
	var width: float = size.x - PAD * 2.0
	var text_size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	var pos: Vector2 = Vector2(PAD, (size.y - text_size.y) * 0.5 + font.get_ascent(font_size))
	draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, -1, EMPTY_TEXT_COLOR)
