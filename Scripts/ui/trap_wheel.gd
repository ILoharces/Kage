extends CanvasLayer
class_name TrapWheel

# Rueda de trampas: se abre al mantener next_trap, en el cursor.
# Clic (disparar) o soltar la tecla sobre un sector equipa esa trampa.
# Con una trampa en la mano, la X del centro la suelta. Fuera de la rueda, o en el centro vacío, se cierra sin cambiar nada.

const _BASE_OUTER_RADIUS: float = 86.0
const _BASE_INNER_RADIUS: float = 30.0
const _BASE_ICON_SIZE: float = 20.0
const _BASE_SCREEN_MARGIN: float = 36.0
const SLICE_GAP: float = 0.05
const STICK_SELECT_THRESHOLD: float = 0.42

const COLOR_SLICE: Color = Color(0.05, 0.05, 0.05, 0.94)
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
var _pointer_offset: Vector2 = Vector2.ZERO
var _opened_frame: int = -1
var _latched_p1: bool = false
var _latched_p2: bool = false
var _blocked_player: Player = null
var _block_frame: int = -1


func _ready() -> void:
	layer = 22
	visible = false
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


func render(canvas: CanvasItem) -> void:
	if _trap_ids.is_empty():
		return
	var equipped_id: int = _equipped_trap_id()
	for index: int in _trap_ids.size():
		var fill: Color = COLOR_SLICE_EMPTY
		if _can_select(index):
			fill = COLOR_SLICE_HOVER if index == _highlight else COLOR_SLICE
		canvas.draw_colored_polygon(_slice_points(index), fill)
	canvas.draw_arc(_center, _outer_radius(), 0.0, TAU, 48, NesUiTheme.COLOR_BORDER, 2.0, true)
	canvas.draw_arc(_center, _inner_radius(), 0.0, TAU, 32, NesUiTheme.COLOR_BORDER_DARK, 2.0, true)
	for index: int in _trap_ids.size():
		if _trap_ids[index] != equipped_id:
			continue
		var equipped_color: Color = ItemDB.TRAP_COLORS.get(_trap_ids[index], NesUiTheme.COLOR_TEXT)
		_draw_slice_rim(canvas, index, equipped_color, 3.0)
	if _highlight >= 0:
		_draw_slice_rim(canvas, _highlight, NesUiTheme.COLOR_TIMER_WARN, 3.0)
		var outline: PackedVector2Array = _slice_points(_highlight)
		if not outline.is_empty():
			outline.append(outline[0])
			canvas.draw_polyline(outline, NesUiTheme.COLOR_TIMER_WARN, 2.0, true)
	for index: int in _trap_ids.size():
		_draw_slice_icon(canvas, index)
	_draw_center(canvas)
	_draw_pointer(canvas)
	_draw_caption(canvas)


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
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_surface.position = Vector2.ZERO
	_surface.size = view_size


func _poll_latches() -> void:
	for player: Player in _players():
		var index: int = _player_index(player)
		if not _is_latched(index):
			continue
		if not Input.is_action_pressed(player.get_trap_wheel_action()):
			_set_latched(index, false)


func _try_open_any() -> void:
	for player: Player in _players():
		if is_open:
			return
		_try_open(player)


func _try_open(player: Player) -> void:
	var index: int = _player_index(player)
	if _is_latched(index):
		return
	if not Input.is_action_just_pressed(player.get_trap_wheel_action()):
		return
	if not player.can_open_trap_wheel():
		return
	if _trapulator_open():
		return
	var traps: Array[int] = ItemDB.get_all_traps()
	if traps.is_empty():
		return
	_fit_surface()
	_trap_ids = traps
	_owner = player
	_owner_index = index
	_opened_frame = Engine.get_process_frames()
	_center = _clamp_center(_pointer_local(player))
	_pointer_offset = _selection_offset(player)
	_highlight = _index_at_offset(_pointer_offset)
	is_open = true
	visible = true


func _update_open() -> void:
	if _owner == null or not is_instance_valid(_owner) or not _owner.can_open_trap_wheel() or _trapulator_open():
		_finish(false, false)
		return
	_pointer_offset = _selection_offset(_owner)
	_highlight = _index_at_offset(_pointer_offset)
	var fire_action: String = _owner.get_fire_action_name()
	var frame: int = Engine.get_process_frames()
	if frame != _opened_frame and Input.is_action_just_pressed(fire_action):
		_finish(_highlight >= 0 or _is_clear_hovered(), true)
		return
	if not Input.is_action_pressed(_owner.get_trap_wheel_action()):
		_finish(_highlight >= 0 or _is_clear_hovered(), false)


func _finish(accept: bool, from_fire: bool) -> void:
	var owner: Player = _owner if is_instance_valid(_owner) else null
	var player_index: int = _owner_index
	var clear_hands: bool = accept and _is_clear_hovered()
	var trap_id: int = -1
	if accept and not clear_hands and owner != null and _highlight >= 0 and _highlight < _trap_ids.size():
		trap_id = _trap_ids[_highlight]
		if GameState.get_trap_count(owner.spy_id, trap_id) <= 0:
			trap_id = -1
	if owner != null and Input.is_action_pressed(owner.get_trap_wheel_action()):
		_set_latched(player_index, true)
	if from_fire and owner != null:
		_blocked_player = owner
		_block_frame = Engine.get_process_frames()
	is_open = false
	_owner = null
	_highlight = -1
	_pointer_offset = Vector2.ZERO
	visible = false
	if clear_hands and owner != null:
		owner.release_trap_selection()
	elif trap_id >= 0 and owner != null:
		owner.equip_trap_from_trapulator(trap_id)


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
	if player.spy_id == ItemDB.SpyId.PLAYER2:
		return 1
	return 0


func _player_uses_mouse(player: Player) -> bool:
	var index: int = _player_index(player)
	return InputBindings.get_control_mode(index) == InputBindings.PlayerControlMode.KEYBOARD_MOUSE


func _pointer_local(player: Player) -> Vector2:
	if _player_uses_mouse(player):
		return _viewport_to_local(get_viewport().get_mouse_position())
	return _viewport_to_local(_aim_screen_pos(player))


func _selection_offset(player: Player) -> Vector2:
	if _player_uses_mouse(player):
		return _viewport_to_local(get_viewport().get_mouse_position()) - _center
	var aim: Vector2 = _aim_vector(player)
	if aim.length() < STICK_SELECT_THRESHOLD:
		return Vector2.ZERO
	var mid_radius: float = (_inner_radius() + _outer_radius()) * 0.5
	return aim.normalized() * mid_radius


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


func _index_at_offset(offset: Vector2) -> int:
	var count: int = _trap_ids.size()
	if count == 0:
		return -1
	var distance: float = offset.length()
	if distance < _inner_radius() or distance > _outer_radius():
		return -1
	var from_top: float = wrapf(offset.angle() + PI * 0.5, 0.0, TAU)
	var index: int = int(from_top / (TAU / float(count)))
	if index < 0:
		index = 0
	elif index >= count:
		index = count - 1
	if not _can_select(index):
		return -1
	return index


func _can_select(index: int) -> bool:
	if _owner == null or index < 0 or index >= _trap_ids.size():
		return false
	return GameState.get_trap_count(_owner.spy_id, _trap_ids[index]) > 0


func _equipped_trap_id() -> int:
	if _owner == null or _owner.held == null or not _owner.held.is_holding_trap():
		return -1
	return _owner.held.get_trap_id()


func _is_clear_hovered() -> bool:
	if _equipped_trap_id() < 0:
		return false
	return _pointer_offset.length() < _inner_radius()


func _draw_center(canvas: CanvasItem) -> void:
	var holding: bool = _equipped_trap_id() >= 0
	var hovered: bool = holding and _is_clear_hovered()
	var fill: Color = COLOR_CENTER_CLEAR if hovered else COLOR_CENTER
	canvas.draw_circle(_center, _inner_radius() - 2.0, fill)
	if not holding:
		return
	var arm: float = _inner_radius() * 0.46
	var x_color: Color = Color.WHITE if hovered else NesUiTheme.COLOR_BORDER
	canvas.draw_line(_center + Vector2(-arm, -arm), _center + Vector2(arm, arm), Color.BLACK, 5.0)
	canvas.draw_line(_center + Vector2(arm, -arm), _center + Vector2(-arm, arm), Color.BLACK, 5.0)
	canvas.draw_line(_center + Vector2(-arm, -arm), _center + Vector2(arm, arm), x_color, 2.5)
	canvas.draw_line(_center + Vector2(arm, -arm), _center + Vector2(-arm, arm), x_color, 2.5)


func _slice_span(index: int) -> Vector2:
	var count: int = maxi(_trap_ids.size(), 1)
	var slice: float = TAU / float(count)
	var pad: float = 0.0 if count <= 1 else SLICE_GAP
	var start: float = -PI * 0.5 + slice * float(index) + pad
	var end: float = -PI * 0.5 + slice * float(index + 1) - pad
	if end <= start:
		end = start + 0.02
	return Vector2(start, end)


func _slice_points(index: int) -> PackedVector2Array:
	var span: Vector2 = _slice_span(index)
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 10
	for step: int in steps + 1:
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(span.x, span.y, t)
		points.append(_center + Vector2.from_angle(angle) * _outer_radius())
	for step: int in steps + 1:
		var t: float = float(step) / float(steps)
		var angle: float = lerpf(span.y, span.x, t)
		points.append(_center + Vector2.from_angle(angle) * _inner_radius())
	return points


func _draw_slice_rim(canvas: CanvasItem, index: int, color: Color, width: float) -> void:
	var span: Vector2 = _slice_span(index)
	canvas.draw_arc(_center, _outer_radius() - 2.0, span.x, span.y, 12, color, width, true)


func _draw_slice_icon(canvas: CanvasItem, index: int) -> void:
	var count: int = maxi(_trap_ids.size(), 1)
	var mid: float = -PI * 0.5 + (TAU / float(count)) * (float(index) + 0.5)
	var icon_size: float = _icon_size()
	var icon_center: Vector2 = _center + Vector2.from_angle(mid) * ((_inner_radius() + _outer_radius()) * 0.5)
	var trap_id: int = _trap_ids[index]
	var selectable: bool = _can_select(index)
	var tint: Color = Color(1, 1, 1, 1) if selectable else Color(1, 1, 1, 0.35)
	var swatch: Color = ItemDB.TRAP_COLORS.get(trap_id, Color.WHITE)
	if not selectable:
		swatch.a = 0.35
	canvas.draw_circle(icon_center, icon_size * 0.62, swatch)
	var texture: Texture2D = ArtLibrary.trap_texture(trap_id)
	var rect: Rect2 = Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, tint)
	var count_label: String = _count_text(trap_id)
	if count_label.is_empty():
		return
	var count_pos: Vector2 = _center + Vector2.from_angle(mid) * (_outer_radius() - 12.0 * _wheel_scale())
	var count_color: Color = NesUiTheme.COLOR_TEXT if selectable else NesUiTheme.COLOR_TEXT_DIM
	_draw_centered_text(canvas, count_label, count_pos, 11, count_color)


func _draw_pointer(canvas: CanvasItem) -> void:
	var pos: Vector2 = _center + _pointer_offset
	canvas.draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), Color.BLACK, 4.0)
	canvas.draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), Color.BLACK, 4.0)
	canvas.draw_line(pos + Vector2(-7, 0), pos + Vector2(7, 0), Color.WHITE, 2.0)
	canvas.draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), Color.WHITE, 2.0)


func _draw_caption(canvas: CanvasItem) -> void:
	if _highlight < 0 or _highlight >= _trap_ids.size():
		return
	var trap_id: int = _trap_ids[_highlight]
	var caption: String = ItemDB.get_trap_hold_label(trap_id)
	var count_label: String = _count_text(trap_id)
	if not count_label.is_empty():
		caption = "%s  %s" % [caption, count_label]
	var at: Vector2 = _center + Vector2(0, _outer_radius() + 18.0)
	_draw_centered_text(canvas, caption, at, NesUiTheme.FONT_LABEL, NesUiTheme.COLOR_TIMER_WARN, true)


func _count_text(trap_id: int) -> String:
	if GameState.match_config.traps_infinite:
		return ""
	if _owner == null:
		return "x0"
	return "x%d" % GameState.get_trap_count(_owner.spy_id, trap_id)


func _wheel_scale() -> float:
	return clampf(GameSettings.trap_wheel_scale, GameSettings.TRAP_WHEEL_SCALE_MIN, GameSettings.TRAP_WHEEL_SCALE_MAX)


func _outer_radius() -> float:
	return _BASE_OUTER_RADIUS * _wheel_scale()


func _inner_radius() -> float:
	return _BASE_INNER_RADIUS * _wheel_scale()


func _icon_size() -> float:
	return _BASE_ICON_SIZE * _wheel_scale()


func _screen_margin() -> float:
	return _BASE_SCREEN_MARGIN * _wheel_scale()


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


func _is_latched(index: int) -> bool:
	return _latched_p1 if index == 0 else _latched_p2


func _set_latched(index: int, value: bool) -> void:
	if index == 0:
		_latched_p1 = value
	else:
		_latched_p2 = value
