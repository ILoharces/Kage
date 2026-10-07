extends CanvasLayer
class_name TrapWheel

# Rueda de trampas y contramedidas: se abre al mantener next_trap, en el cursor.
# Anillo interior = trampas; anillo exterior = la contramedida de cada trampa, en el mismo ángulo.
# Clic (disparar) o soltar la tecla sobre un sector equipa esa herramienta.
# Con una herramienta en la mano, la X del centro la suelta. Fuera de la rueda, o en el centro vacío, se cierra sin cambiar nada.
# Con mando: inclinar el stick a medias elige trampa; a fondo, contramedida.

enum Ring { TRAP, COUNTER }

const _BASE_INNER_RADIUS: float = 30.0
const _BASE_SPLIT_RADIUS: float = 86.0
const _BASE_OUTER_RADIUS: float = 132.0
const _BASE_ICON_SIZE: float = 20.0
const _BASE_SCREEN_MARGIN: float = 36.0
const SLICE_GAP: float = 0.05
const STICK_SELECT_THRESHOLD: float = 0.42
const STICK_COUNTER_THRESHOLD: float = 0.9

const COLOR_SLICE: Color = Color(0.05, 0.05, 0.05, 0.94)
const COLOR_SLICE_COUNTER: Color = Color(0.07, 0.09, 0.12, 0.94)
const COLOR_SLICE_EMPTY: Color = Color(0.03, 0.03, 0.03, 0.7)
const COLOR_SLICE_HOVER: Color = Color(0.24, 0.18, 0.05, 0.98)
const COLOR_CENTER: Color = Color(0.0, 0.0, 0.0, 0.98)
const COLOR_CENTER_CLEAR: Color = Color(0.62, 0.08, 0.1, 0.98)

var is_open: bool = false

var _surface: Control = null
var _owner: Player = null
var _owner_index: int = 0
var _trap_ids: Array[int] = []
var _center: Vector2 = Vector2.ZERO
var _highlight: int = -1
var _highlight_ring: Ring = Ring.TRAP
var _pointer_offset: Vector2 = Vector2.ZERO
var _opened_frame: int = -1
var _latched: Array[bool] = [false, false]
var _blocked_player: Player = null
var _block_frame: int = -1


func _ready() -> void:
	layer = 22
	visible = false
	_trap_ids = ItemDB.get_all_traps()
	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.draw.connect(_on_surface_draw)
	add_child(_surface)
	if not get_viewport().size_changed.is_connected(_fit_surface):
		get_viewport().size_changed.connect(_fit_surface)
	_fit_surface()


func _on_surface_draw() -> void:
	if is_open and _surface != null:
		render(_surface)


func blocks_player(player: Player) -> bool:
	if player == null:
		return false
	if is_open and is_instance_valid(_owner) and _owner == player:
		return true
	if _blocked_player == null or not is_instance_valid(_blocked_player):
		_blocked_player = null
		return false
	if player != _blocked_player:
		return false
	if Engine.get_process_frames() <= _block_frame:
		return true
	_blocked_player = null
	return false


func close_cancel() -> void:
	if not is_open:
		return
	_finish(false, false)


func _process(_delta: float) -> void:
	_poll_latches()
	if not is_open:
		_try_open_any()
	if is_open:
		_update_open()
	if is_open:
		visible = true
		if _surface != null:
			_surface.queue_redraw()
	elif visible:
		visible = false


func _fit_surface() -> void:
	if _surface == null:
		return
	_surface.position = Vector2.ZERO
	_surface.size = get_viewport().get_visible_rect().size


# --- Apertura y cierre --------------------------------------------------------

func _poll_latches() -> void:
	for player: Player in _players():
		var index: int = _player_index(player)
		if _latched[index] and not Input.is_action_pressed(player.get_trap_wheel_action()):
			_latched[index] = false


func _try_open_any() -> void:
	for player: Player in _players():
		if is_open:
			return
		_try_open(player)


func _try_open(player: Player) -> void:
	var index: int = _player_index(player)
	if _latched[index] or not Input.is_action_just_pressed(player.get_trap_wheel_action()):
		return
	if not player.can_open_trap_wheel() or _trapulator_open() or _trap_ids.is_empty():
		return
	_fit_surface()
	_owner = player
	_owner_index = index
	_opened_frame = Engine.get_process_frames()
	_center = _clamp_center(_pointer_local(player))
	_update_highlight()
	is_open = true
	visible = true


func _update_open() -> void:
	if _owner == null or not is_instance_valid(_owner) or not _owner.can_open_trap_wheel() or _trapulator_open():
		_finish(false, false)
		return
	_update_highlight()
	var accept: bool = _highlight >= 0 or _is_clear_hovered()
	if Engine.get_process_frames() != _opened_frame and Input.is_action_just_pressed(_owner.get_fire_action_name()):
		_finish(accept, true)
		return
	if not Input.is_action_pressed(_owner.get_trap_wheel_action()):
		_finish(accept, false)


func _update_highlight() -> void:
	_pointer_offset = _selection_offset(_owner)
	_highlight_ring = _ring_at_offset(_pointer_offset)
	_highlight = _index_at_offset(_pointer_offset)


func _finish(accept: bool, from_fire: bool) -> void:
	var owner: Player = _owner if is_instance_valid(_owner) else null
	var clear_hands: bool = accept and _is_clear_hovered()
	var pick_index: int = _highlight if accept and not clear_hands else -1
	var pick_ring: Ring = _highlight_ring
	if owner != null and Input.is_action_pressed(owner.get_trap_wheel_action()):
		_latched[_owner_index] = true
	if from_fire and owner != null:
		_blocked_player = owner
		_block_frame = Engine.get_process_frames()
	is_open = false
	_owner = null
	_highlight = -1
	_pointer_offset = Vector2.ZERO
	visible = false
	if owner == null:
		return
	if clear_hands:
		owner.release_tool_selection()
	elif pick_index >= 0:
		_equip(owner, pick_ring, pick_index)


func _equip(owner: Player, ring: Ring, index: int) -> void:
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		owner.equip_counter(ItemDB.get_counter_for_trap(trap_id))
	else:
		owner.equip_trap(trap_id)


# --- Datos de cada sector -----------------------------------------------------

func _tool_count(ring: Ring, index: int) -> int:
	if _owner == null or index < 0 or index >= _trap_ids.size():
		return 0
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		return GameState.get_counter_count(_owner.spy_id, ItemDB.get_counter_for_trap(trap_id))
	return GameState.get_trap_count(_owner.spy_id, trap_id)


func _can_select(ring: Ring, index: int) -> bool:
	return _tool_count(ring, index) > 0


func _tool_name(ring: Ring, index: int) -> String:
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		return ItemDB.get_counter_name(ItemDB.get_counter_for_trap(trap_id))
	return ItemDB.get_trap_name(trap_id)


func _tool_color(ring: Ring, index: int) -> Color:
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		return ItemDB.get_counter_color(ItemDB.get_counter_for_trap(trap_id))
	return ItemDB.get_trap_color(trap_id)


func _tool_texture(ring: Ring, index: int) -> Texture2D:
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		return ArtLibrary.counter_texture(ItemDB.get_counter_for_trap(trap_id))
	return ArtLibrary.trap_texture(trap_id)


func _count_text(ring: Ring, index: int) -> String:
	var infinite: bool = (
		GameState.stock.counters_infinite() if ring == Ring.COUNTER else GameState.stock.traps_infinite()
	)
	if infinite:
		return ""
	return "x%d" % _tool_count(ring, index)


func _is_equipped(ring: Ring, index: int) -> bool:
	if _owner == null or _owner.held == null:
		return false
	var trap_id: int = _trap_ids[index]
	if ring == Ring.COUNTER:
		return _owner.held.get_counter_id() == ItemDB.get_counter_for_trap(trap_id)
	return _owner.held.get_trap_id() == trap_id


func _holding_tool() -> bool:
	return _owner != null and _owner.held != null and _owner.held.is_holding_tool()


func _is_clear_hovered() -> bool:
	return _holding_tool() and _pointer_offset.length() < _inner_radius()


# --- Dibujo -------------------------------------------------------------------

func render(canvas: CanvasItem) -> void:
	if _trap_ids.is_empty():
		return
	for ring: Ring in [Ring.TRAP, Ring.COUNTER]:
		var base: Color = COLOR_SLICE_COUNTER if ring == Ring.COUNTER else COLOR_SLICE
		for index: int in _trap_ids.size():
			var fill: Color = COLOR_SLICE_EMPTY
			if _can_select(ring, index):
				fill = COLOR_SLICE_HOVER if _is_highlighted(ring, index) else base
			canvas.draw_colored_polygon(_slice_points(ring, index), fill)
	canvas.draw_arc(_center, _outer_radius(), 0.0, TAU, 56, NesUiTheme.COLOR_BORDER, 2.0, true)
	canvas.draw_arc(_center, _split_radius(), 0.0, TAU, 48, NesUiTheme.COLOR_BORDER_DARK, 2.0, true)
	canvas.draw_arc(_center, _inner_radius(), 0.0, TAU, 32, NesUiTheme.COLOR_BORDER_DARK, 2.0, true)
	for ring: Ring in [Ring.TRAP, Ring.COUNTER]:
		for index: int in _trap_ids.size():
			if _is_equipped(ring, index):
				_draw_slice_rim(canvas, ring, index, _tool_color(ring, index), 3.0)
	if _highlight >= 0:
		_draw_slice_rim(canvas, _highlight_ring, _highlight, NesUiTheme.COLOR_TIMER_WARN, 3.0)
		var outline: PackedVector2Array = _slice_points(_highlight_ring, _highlight)
		if not outline.is_empty():
			outline.append(outline[0])
			canvas.draw_polyline(outline, NesUiTheme.COLOR_TIMER_WARN, 2.0, true)
	for ring: Ring in [Ring.TRAP, Ring.COUNTER]:
		for index: int in _trap_ids.size():
			_draw_slice_icon(canvas, ring, index)
	_draw_center(canvas)
	_draw_pointer(canvas)
	_draw_caption(canvas)


func _is_highlighted(ring: Ring, index: int) -> bool:
	return index == _highlight and ring == _highlight_ring


func _draw_center(canvas: CanvasItem) -> void:
	var holding: bool = _holding_tool()
	var hovered: bool = holding and _is_clear_hovered()
	var fill: Color = COLOR_CENTER_CLEAR if hovered else COLOR_CENTER
	canvas.draw_circle(_center, _inner_radius() - 2.0, fill)
	if not holding:
		return
	var arm: float = _inner_radius() * 0.46
	var x_color: Color = Color.WHITE if hovered else NesUiTheme.COLOR_BORDER
	for width: float in [5.0, 2.5]:
		var color: Color = Color.BLACK if width > 3.0 else x_color
		canvas.draw_line(_center + Vector2(-arm, -arm), _center + Vector2(arm, arm), color, width)
		canvas.draw_line(_center + Vector2(arm, -arm), _center + Vector2(-arm, arm), color, width)


func _draw_slice_rim(canvas: CanvasItem, ring: Ring, index: int, color: Color, width: float) -> void:
	var span: Vector2 = _slice_span(index)
	canvas.draw_arc(_center, _ring_outer(ring) - 2.0, span.x, span.y, 12, color, width, true)


func _draw_slice_icon(canvas: CanvasItem, ring: Ring, index: int) -> void:
	var mid: float = _slice_mid_angle(index)
	var icon_size: float = _icon_size()
	var icon_center: Vector2 = _center + Vector2.from_angle(mid) * _ring_mid(ring)
	var selectable: bool = _can_select(ring, index)
	var tint: Color = Color(1, 1, 1, 1) if selectable else Color(1, 1, 1, 0.35)
	var swatch: Color = _tool_color(ring, index)
	if not selectable:
		swatch.a = 0.35
	canvas.draw_circle(icon_center, icon_size * 0.62, swatch)
	var texture: Texture2D = _tool_texture(ring, index)
	if texture != null:
		var rect: Rect2 = Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		canvas.draw_texture_rect(texture, rect, false, tint)
	var count_label: String = _count_text(ring, index)
	if count_label.is_empty():
		return
	var count_pos: Vector2 = _center + Vector2.from_angle(mid) * (_ring_outer(ring) - 10.0 * _wheel_scale())
	var count_color: Color = NesUiTheme.COLOR_TEXT if selectable else NesUiTheme.COLOR_TEXT_DIM
	_draw_centered_text(canvas, count_label, count_pos, 11, count_color)


func _draw_pointer(canvas: CanvasItem) -> void:
	var pos: Vector2 = _center + _pointer_offset
	for width: float in [4.0, 2.0]:
		var color: Color = Color.BLACK if width > 3.0 else Color.WHITE
		canvas.draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), color, width)
		canvas.draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), color, width)


func _draw_caption(canvas: CanvasItem) -> void:
	if _highlight < 0:
		return
	var caption: String = _tool_name(_highlight_ring, _highlight)
	if _highlight_ring == Ring.COUNTER:
		caption = "%s  (contra %s)" % [caption, ItemDB.get_trap_name(_trap_ids[_highlight])]
	var count_label: String = _count_text(_highlight_ring, _highlight)
	if not count_label.is_empty():
		caption = "%s  %s" % [caption, count_label]
	var at: Vector2 = _center + Vector2(0, _outer_radius() + 18.0)
	_draw_centered_text(canvas, caption, at, NesUiTheme.FONT_LABEL, NesUiTheme.COLOR_TIMER_WARN, true)


func _draw_centered_text(
	canvas: CanvasItem,
	text: String,
	at: Vector2,
	font_size: int,
	color: Color,
	with_background: bool = false
) -> void:
	var font: Font = NesUiTheme.ui_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos: Vector2 = Vector2(at.x - text_size.x * 0.5, at.y + text_size.y * 0.35)
	if with_background:
		var pad: Vector2 = Vector2(8.0, 4.0)
		var bg: Rect2 = Rect2(
			pos.x - pad.x,
			pos.y - text_size.y - 1.0,
			text_size.x + pad.x * 2.0,
			text_size.y + pad.y * 2.0
		)
		canvas.draw_rect(bg, Color(0, 0, 0, 0.92))
		canvas.draw_rect(bg, NesUiTheme.COLOR_BORDER_DARK, false, 2.0)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Geometría ----------------------------------------------------------------

func _ring_at_offset(offset: Vector2) -> Ring:
	return Ring.COUNTER if offset.length() > _split_radius() else Ring.TRAP


func _index_at_offset(offset: Vector2) -> int:
	var count: int = _trap_ids.size()
	var distance: float = offset.length()
	if count == 0 or distance < _inner_radius() or distance > _outer_radius():
		return -1
	var from_top: float = wrapf(offset.angle() + PI * 0.5, 0.0, TAU)
	var index: int = clampi(int(from_top / (TAU / float(count))), 0, count - 1)
	if not _can_select(_ring_at_offset(offset), index):
		return -1
	return index


func _slice_mid_angle(index: int) -> float:
	var count: int = maxi(_trap_ids.size(), 1)
	return -PI * 0.5 + (TAU / float(count)) * (float(index) + 0.5)


func _slice_span(index: int) -> Vector2:
	var count: int = maxi(_trap_ids.size(), 1)
	var slice: float = TAU / float(count)
	var pad: float = 0.0 if count <= 1 else SLICE_GAP
	var start: float = -PI * 0.5 + slice * float(index) + pad
	var end: float = -PI * 0.5 + slice * float(index + 1) - pad
	if end <= start:
		end = start + 0.02
	return Vector2(start, end)


func _slice_points(ring: Ring, index: int) -> PackedVector2Array:
	var span: Vector2 = _slice_span(index)
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for step: int in steps + 1:
		var angle: float = lerpf(span.x, span.y, float(step) / float(steps))
		points.append(_center + Vector2.from_angle(angle) * _ring_outer(ring))
	for step: int in steps + 1:
		var angle: float = lerpf(span.y, span.x, float(step) / float(steps))
		points.append(_center + Vector2.from_angle(angle) * _ring_inner(ring))
	return points


func _ring_inner(ring: Ring) -> float:
	return _split_radius() if ring == Ring.COUNTER else _inner_radius()


func _ring_outer(ring: Ring) -> float:
	return _outer_radius() if ring == Ring.COUNTER else _split_radius()


func _ring_mid(ring: Ring) -> float:
	return (_ring_inner(ring) + _ring_outer(ring)) * 0.5


func _wheel_scale() -> float:
	return clampf(GameSettings.trap_wheel_scale, GameSettings.TRAP_WHEEL_SCALE_MIN, GameSettings.TRAP_WHEEL_SCALE_MAX)


func _inner_radius() -> float:
	return _BASE_INNER_RADIUS * _wheel_scale()


func _split_radius() -> float:
	return _BASE_SPLIT_RADIUS * _wheel_scale()


func _outer_radius() -> float:
	return _BASE_OUTER_RADIUS * _wheel_scale()


func _icon_size() -> float:
	return _BASE_ICON_SIZE * _wheel_scale()


func _screen_margin() -> float:
	return _BASE_SCREEN_MARGIN * _wheel_scale()


func _clamp_center(point: Vector2) -> Vector2:
	if _surface == null:
		return point
	var margin: float = _outer_radius() + _screen_margin()
	var bounds: Vector2 = _surface.size
	if bounds.x < margin * 2.0 or bounds.y < margin * 2.0:
		return point
	return Vector2(
		clampf(point.x, margin, bounds.x - margin),
		clampf(point.y, margin, bounds.y - margin)
	)


# --- Entrada y jugadores ------------------------------------------------------

func _players() -> Array[Player]:
	var players: Array[Player] = []
	var main_node: Main = _main()
	if main_node == null or main_node.mansion == null:
		return players
	if main_node.mansion.player != null:
		players.append(main_node.mansion.player)
	if main_node.mansion.player2 != null:
		players.append(main_node.mansion.player2)
	return players


func _main() -> Main:
	return get_tree().current_scene as Main


func _trapulator_open() -> bool:
	var main_node: Main = _main()
	return main_node != null and main_node.trapulator != null and main_node.trapulator.is_open


func _player_index(player: Player) -> int:
	return 1 if player.spy_id == ItemDB.SpyId.PLAYER2 else 0


func _player_uses_mouse(player: Player) -> bool:
	return InputBindings.get_control_mode(_player_index(player)) == InputBindings.PlayerControlMode.KEYBOARD_MOUSE


func _pointer_local(player: Player) -> Vector2:
	if _player_uses_mouse(player):
		return _viewport_to_local(get_viewport().get_mouse_position())
	return _viewport_to_local(_aim_screen_pos(player))


func _selection_offset(player: Player) -> Vector2:
	if player == null:
		return Vector2.ZERO
	if _player_uses_mouse(player):
		return _viewport_to_local(get_viewport().get_mouse_position()) - _center
	var aim: Vector2 = _aim_vector(player)
	var strength: float = aim.length()
	if strength < STICK_SELECT_THRESHOLD:
		return Vector2.ZERO
	var ring: Ring = Ring.COUNTER if strength >= STICK_COUNTER_THRESHOLD else Ring.TRAP
	return aim.normalized() * _ring_mid(ring)


func _aim_vector(player: Player) -> Vector2:
	if player.spy_id == ItemDB.SpyId.PLAYER2:
		return Input.get_vector("p2_aim_left", "p2_aim_right", "p2_aim_up", "p2_aim_down", 0.0)
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.0)


func _aim_screen_pos(player: Player) -> Vector2:
	var main_node: Main = _main()
	if main_node == null:
		return get_viewport().get_mouse_position()
	var controller: AimController = main_node.get_aim_controller(player.get_aim_controller_spy_id())
	if controller == null:
		return get_viewport().get_mouse_position()
	return controller.get_screen_pos()


func _viewport_to_local(point: Vector2) -> Vector2:
	if _surface == null:
		return point
	return _surface.get_global_transform_with_canvas().affine_inverse() * point
