extends Node2D
class_name Room

# Habitacion en proyeccion oblicua. Solo es visible desde la camara del espia
# que esta dentro (la mansion separa habitaciones en el mundo).

signal spy_entered(spy: Node)
signal spy_exited(spy: Node)

const OUTLINE_W: float = 2.5
const WALL_THICKNESS: float = 16.0
const WALL_CAPSULE_OVERLAP: float = 8.0
const PASSAGE_COOLDOWN_MS: int = 220

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var has_door_n: bool = false
@export var has_door_e: bool = false
@export var has_door_s: bool = false
@export var has_door_w: bool = false

var spies_inside: Array[Node] = []
var furniture_list: Array[Node] = []
var door_list: Array[Door] = []
var furniture_container: Node2D
var doors_container: Node2D
var south_wall_bar: SouthWallBar = null
var _passage_cooldowns: Dictionary = {}  # spy_id -> expire_time_ms
var _passage_links: Dictionary = {}
var breaches: Array[Dictionary] = []
var _breach_serial: int = 0

enum TimedTrapState { NONE, ARMED, COUNTING }

const TICK_GAP: float = 0.42

static var _shared_tick: AudioStreamWAV = null

var _timed_state: TimedTrapState = TimedTrapState.NONE
var _timed_trapper_id: int = -1
var _timed_fuse_left: float = 0.0
var _tick_player: AudioStreamPlayer = null
var _tick_wait: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("room")
	furniture_container = Node2D.new()
	furniture_container.name = "Furniture"
	furniture_container.y_sort_enabled = true
	add_child(furniture_container)
	doors_container = Node2D.new()
	doors_container.name = "Doors"
	doors_container.y_sort_enabled = true
	add_child(doors_container)
	south_wall_bar = SouthWallBar.new()
	south_wall_bar.name = "SouthWallBar"
	doors_container.add_child(south_wall_bar)
	south_wall_bar.setup(self)
	_build_wall_collision()
	_build_trigger()
	spy_entered.connect(_on_timed_spy_entered)
	queue_redraw()


func get_room_w() -> float:
	return float(DisplayConfig.room_width)


func get_room_h() -> float:
	return float(DisplayConfig.room_height)


func rebuild_geometry() -> void:
	var rw: float = get_room_w()
	var rh: float = get_room_h()
	var walls: StaticBody2D = get_node_or_null("Walls") as StaticBody2D
	if walls != null:
		walls.collision_layer = 0
		walls.name = "WallsOld"
		walls.queue_free()
	_build_wall_collision()
	for child: Node in get_children():
		if not child is Area2D:
			continue
		if not String(child.name).begins_with("Passage_"):
			continue
		var dir_str: String = String(child.name).trim_prefix("Passage_")
		var passage_poly: PackedVector2Array = RoomPerspective.get_door_polygon(dir_str, rw, rh)
		for shape_node: Node in child.get_children():
			var col: CollisionShape2D = shape_node as CollisionShape2D
			if col == null or not col.shape is ConvexPolygonShape2D:
				continue
			(col.shape as ConvexPolygonShape2D).points = passage_poly
	for door: Door in door_list:
		door.refresh_from_room()
	if south_wall_bar != null:
		south_wall_bar.setup(self)
	_refresh_breach_shapes()
	queue_redraw()


func _process(delta: float) -> void:
	if _timed_state != TimedTrapState.COUNTING:
		return
	if _try_defuse_by_anyone_inside():
		return
	_timed_fuse_left -= delta
	_play_tick_if_due(delta)
	queue_redraw()
	if _timed_fuse_left > 0.0:
		return
	_explode_timed_trap()


func _draw() -> void:
	var rw: float = get_room_w()
	var rh: float = get_room_h()
	var outline: Color = ItemDB.COLOR_OUTLINE
	var alarm: Color = _fuse_tint()
	var room_quad: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2(rw, 0.0),
		Vector2(rw, rh),
		Vector2(0.0, rh),
	])
	ArtDraw.tiled(self, room_quad, ArtLibrary.WALL, ArtLibrary.TILE, alarm)

	var back: PackedVector2Array = RoomPerspective.back_wall_polygon(rw, rh)
	ArtDraw.tiled(self, back, ArtLibrary.WALL, ArtLibrary.TILE, alarm)
	draw_polyline(back + PackedVector2Array([back[0]]), outline, OUTLINE_W, true)

	var left_w: PackedVector2Array = RoomPerspective.left_wall_polygon(rw, rh)
	ArtDraw.tiled(self, left_w, ArtLibrary.WALL_SIDE, ArtLibrary.TILE, alarm)
	draw_polyline(left_w + PackedVector2Array([left_w[0]]), outline, OUTLINE_W, true)

	var right_w: PackedVector2Array = RoomPerspective.right_wall_polygon(rw, rh)
	ArtDraw.tiled(self, right_w, ArtLibrary.WALL_SIDE, ArtLibrary.TILE, alarm)
	draw_polyline(right_w + PackedVector2Array([right_w[0]]), outline, OUTLINE_W, true)

	var floor_poly: PackedVector2Array = RoomPerspective.floor_polygon(rw, rh)
	var floor_tint: Color = ArtLibrary.FLOOR_EXIT_TINT if _has_exit_door() else Color.WHITE
	floor_tint *= alarm
	ArtDraw.tiled(self, floor_poly, ArtLibrary.FLOOR, ArtLibrary.TILE, floor_tint)
	draw_polyline(floor_poly + PackedVector2Array([floor_poly[0]]), outline, OUTLINE_W, true)

	_draw_doors_on_walls(rw, rh, outline)
	_draw_breaches(rw, rh, outline)


func _has_exit_door() -> bool:
	for door: Door in door_list:
		if door.is_exit_door:
			return true
	return false


func _draw_doors_on_walls(room_w: float, room_h: float, outline: Color) -> void:
	var gap_col: Color = ItemDB.COLOR_DOOR_GAP
	if has_door_n:
		_draw_door_gap_polygon("N", room_w, room_h, gap_col, outline)
	if has_door_w:
		_draw_door_gap_polygon("W", room_w, room_h, gap_col, outline)
	if has_door_e:
		_draw_door_gap_polygon("E", room_w, room_h, gap_col, outline)


func _draw_breaches(room_w: float, room_h: float, outline: Color) -> void:
	for breach: Dictionary in breaches:
		var dir_str: String = String(breach.get("dir", ""))
		if dir_str == "S":
			continue
		var pts: PackedVector2Array = RoomPerspective.breach_polygon(
			dir_str, float(breach.get("t", 0.5)), room_w, room_h
		)
		if pts.size() < 3:
			continue
		draw_colored_polygon(pts, ItemDB.COLOR_DOOR_GAP)
		draw_polyline(pts + PackedVector2Array([pts[0]]), outline, OUTLINE_W, true)


func _draw_door_gap_polygon(direction: String, room_w: float, room_h: float, gap_col: Color, outline: Color) -> void:
	_draw_door_polygon(direction, room_w, room_h, gap_col, outline)


func _draw_door_polygon(direction: String, room_w: float, room_h: float, door_col: Color, outline: Color) -> void:
	var pts: PackedVector2Array = RoomPerspective.get_door_polygon(direction, room_w, room_h)
	draw_colored_polygon(pts, door_col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, OUTLINE_W, true)


func register_passage(exit_dir: String, target_room: Room, entry_dir: String) -> void:
	if target_room == null:
		return
	var area: Area2D = _create_passage_area(exit_dir)
	area.body_entered.connect(_on_passage_entered.bind(target_room, exit_dir, entry_dir))
	_passage_links[exit_dir] = {"target": target_room, "entry": entry_dir, "is_exit": false}
	_register_room_door(exit_dir, area)


func register_exit_passage(exit_dir: String) -> void:
	if get_door_for_direction(exit_dir) != null:
		return
	var area: Area2D = _create_passage_area(exit_dir)
	area.body_entered.connect(_on_exit_passage_entered.bind(exit_dir))
	_passage_links[exit_dir] = {"target": null, "entry": "", "is_exit": true}
	_register_room_door(exit_dir, area)


func _create_passage_area(exit_dir: String) -> Area2D:
	var rw: float = get_room_w()
	var rh: float = get_room_h()
	var area: Area2D = Area2D.new()
	area.name = "Passage_%s" % exit_dir
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = false
	area.monitorable = false
	var door_poly: PackedVector2Array = RoomPerspective.get_door_polygon(exit_dir, rw, rh)
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = door_poly
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_exited.connect(_on_passage_body_exited.bind(exit_dir))
	return area


func _on_passage_body_exited(body: Node, exit_dir: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	spy.clear_passage_entry_block(self, exit_dir)


func _register_room_door(dir_str: String, passage: Area2D) -> void:
	var door: Door = Door.new()
	doors_container.add_child(door)
	door.setup(self, dir_str, passage)
	door_list.append(door)
	if dir_str == "S" and south_wall_bar != null:
		south_wall_bar.setup(self)


func clear_passage_cooldown(spy: Node) -> void:
	_passage_cooldowns.erase(spy.get_instance_id())


func set_passage_cooldown(spy: Node, duration_ms: int) -> void:
	if spy == null:
		return
	_passage_cooldowns[spy.get_instance_id()] = Time.get_ticks_msec() + duration_ms


func poll_spy_passages(spy: SpyBase) -> void:
	if spy == null or not spies_inside.has(spy):
		return
	var now_ms: int = Time.get_ticks_msec()
	var key: int = spy.get_instance_id()
	if int(_passage_cooldowns.get(key, 0)) > now_ms:
		return
	for exit_dir: String in _passage_links.keys():
		var area: Area2D = get_node_or_null("Passage_%s" % exit_dir) as Area2D
		if area == null:
			continue
		var passage_door: Door = get_door_for_direction(exit_dir)
		if passage_door != null and passage_door.is_closed() and area.overlaps_body(spy):
			passage_door.try_open_for_spy(spy)
		if spy.is_passage_bounce_blocked(self, exit_dir):
			continue
		if not area.monitoring or not area.overlaps_body(spy):
			continue
		var link: Dictionary = _passage_links[exit_dir] as Dictionary
		if bool(link.get("is_exit", false)):
			_try_exit_passage_for_spy(spy, exit_dir)
		else:
			_try_passage_for_spy(
				spy, link["target"] as Room, exit_dir, String(link["entry"])
			)
		return
	for breach: Dictionary in breaches:
		var area_name: String = String(breach.get("name", ""))
		var area: Area2D = get_node_or_null(area_name) as Area2D
		if area == null or not area.monitoring or not area.overlaps_body(spy):
			continue
		_try_breach_for_spy(spy, breach)
		return


func open_rocket_breach(direction: String, floor_t: float) -> bool:
	var mansion: Mansion = get_parent() as Mansion
	if mansion == null or direction.is_empty():
		return false
	var neighbor: Room = mansion.get_room_at(grid_pos + GridDirection.delta(direction))
	if neighbor == null:
		return false
	var clamped: float = _clamp_breach_t(direction, floor_t)
	var entry_dir: String = GridDirection.opposite(direction)
	var entry_t: float = 1.0 - clamped
	if _breach_blocked(direction, clamped) or neighbor._breach_blocked(entry_dir, entry_t):
		return false
	_add_breach(direction, clamped, neighbor, entry_dir, entry_t)
	neighbor._add_breach(entry_dir, entry_t, self, direction, clamped)
	return true


func breach_entry_local(direction: String, floor_t: float) -> Vector2:
	var rw: float = get_room_w()
	var rh: float = get_room_h()
	var edge: PackedVector2Array = _floor_edge(direction)
	var center: Vector2 = edge[0].lerp(edge[1], clampf(floor_t, 0.0, 1.0))
	var inward: Vector2 = RoomPerspective.floor_centroid(rw, rh) - center
	if inward.length_squared() < 1.0:
		inward = Vector2.DOWN
	inward = inward.normalized()
	var hole: PackedVector2Array = RoomPerspective.breach_trigger_polygon(direction, floor_t, rw, rh)
	var dist: float = RoomPerspective.breach_trigger_depth(rh) + rh * 0.07
	var pos: Vector2 = RoomPerspective.clamp_to_floor(center + inward * dist, rw, rh)
	var guard: int = 0
	while hole.size() >= 3 and Geometry2D.is_point_in_polygon(pos, hole) and guard < 6:
		dist += rh * 0.04
		pos = RoomPerspective.clamp_to_floor(center + inward * dist, rw, rh)
		guard += 1
	return pos


func spy_overlaps_exit(spy: SpyBase, direction: String) -> bool:
	var passage: Area2D = get_node_or_null("Passage_%s" % direction) as Area2D
	if passage != null and passage.monitoring and passage.overlaps_body(spy):
		return true
	for breach: Dictionary in breaches:
		if String(breach.get("dir", "")) != direction:
			continue
		var area: Area2D = get_node_or_null(String(breach.get("name", ""))) as Area2D
		if area != null and area.monitoring and area.overlaps_body(spy):
			return true
	return false


func _add_breach(
	direction: String,
	floor_t: float,
	target: Room,
	entry_dir: String,
	entry_t: float
) -> void:
	_breach_serial += 1
	var area_name: String = "Breach_%d" % _breach_serial
	breaches.append({
		"dir": direction,
		"t": floor_t,
		"name": area_name,
		"target": target,
		"entry": entry_dir,
		"entry_t": entry_t,
	})
	var area: Area2D = Area2D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = RoomPerspective.breach_trigger_polygon(direction, floor_t, get_room_w(), get_room_h())
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_breach_entered.bind(area_name))
	area.body_exited.connect(_on_passage_body_exited.bind(direction))
	rebuild_geometry()


func _on_breach_entered(body: Node, area_name: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	var breach: Dictionary = _breach_by_name(area_name)
	if breach.is_empty():
		return
	_try_breach_for_spy(spy, breach)


func _try_breach_for_spy(spy: SpyBase, breach: Dictionary) -> void:
	if spy.current_room != self:
		return
	var exit_dir: String = String(breach.get("dir", ""))
	var now_ms: int = Time.get_ticks_msec()
	var key: int = spy.get_instance_id()
	if int(_passage_cooldowns.get(key, 0)) > now_ms or spy.is_passage_bounce_blocked(self, exit_dir):
		return
	var target: Room = breach.get("target") as Room
	if target == null:
		return
	_passage_cooldowns[key] = now_ms + PASSAGE_COOLDOWN_MS
	var entry_dir: String = String(breach.get("entry", ""))
	var spawn: Vector2 = target.breach_entry_local(entry_dir, float(breach.get("entry_t", 0.5)))
	spy.teleport_to_room(target, entry_dir, self, spawn)


func _breach_by_name(area_name: String) -> Dictionary:
	for breach: Dictionary in breaches:
		if String(breach.get("name", "")) == area_name:
			return breach
	return {}


func _clamp_breach_t(direction: String, floor_t: float) -> float:
	var length: float = _floor_edge_length(direction)
	var half: float = RoomPerspective.opening_half_along_edge(direction, get_room_w(), get_room_h())
	if length < 1.0:
		return 0.5
	var margin: float = clampf((half + 4.0) / length, 0.0, 0.45)
	return clampf(floor_t, margin, 1.0 - margin)


func _breach_blocked(direction: String, floor_t: float) -> bool:
	var length: float = _floor_edge_length(direction)
	var half: float = RoomPerspective.opening_half_along_edge(direction, get_room_w(), get_room_h())
	if _has_door_direction(direction):
		var door_t: float = _door_edge_t(direction)
		if absf(floor_t - door_t) * length < half * 2.0:
			return true
	for breach: Dictionary in breaches:
		if String(breach.get("dir", "")) != direction:
			continue
		if absf(float(breach.get("t", 0.5)) - floor_t) * length < half * 2.0:
			return true
	return false


func _has_door_direction(direction: String) -> bool:
	match direction:
		"N":
			return has_door_n
		"E":
			return has_door_e
		"S":
			return has_door_s
		"W":
			return has_door_w
	return false


func _door_edge_t(direction: String) -> float:
	var edge: PackedVector2Array = _floor_edge(direction)
	var center: Vector2 = RoomPerspective.get_door_visual_center(direction, get_room_w(), get_room_h())
	var projected: Vector2 = RoomPerspective.project_point_on_segment(center, edge[0], edge[1])
	var span: Vector2 = edge[1] - edge[0]
	var len_sq: float = span.length_squared()
	if len_sq < 0.001:
		return 0.5
	return clampf((projected - edge[0]).dot(span) / len_sq, 0.0, 1.0)


func _floor_edge(direction: String) -> PackedVector2Array:
	var poly: PackedVector2Array = RoomPerspective.floor_polygon(get_room_w(), get_room_h())
	var idx: int = RoomPerspective.edge_index_for_direction(direction)
	return PackedVector2Array([poly[idx], poly[(idx + 1) % poly.size()]])


func _floor_edge_length(direction: String) -> float:
	var edge: PackedVector2Array = _floor_edge(direction)
	return edge[0].distance_to(edge[1])


func _refresh_breach_shapes() -> void:
	var rw: float = get_room_w()
	var rh: float = get_room_h()
	for breach: Dictionary in breaches:
		var area: Area2D = get_node_or_null(String(breach.get("name", ""))) as Area2D
		if area == null:
			continue
		var poly: PackedVector2Array = RoomPerspective.breach_trigger_polygon(
			String(breach.get("dir", "")), float(breach.get("t", 0.5)), rw, rh
		)
		for shape_node: Node in area.get_children():
			var col: CollisionShape2D = shape_node as CollisionShape2D
			if col == null or not col.shape is ConvexPolygonShape2D:
				continue
			(col.shape as ConvexPolygonShape2D).points = poly


func _on_passage_entered(body: Node, target_room: Room, exit_dir: String, entry_dir: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	_try_passage_for_spy(spy, target_room, exit_dir, entry_dir)


func _try_passage_for_spy(
	spy: SpyBase, target_room: Room, exit_dir: String, entry_dir: String
) -> void:
	if _cross_passage_door(spy, exit_dir):
		spy.teleport_to_room(target_room, entry_dir, self)


func _on_exit_passage_entered(body: Node, exit_dir: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	_try_exit_passage_for_spy(spy, exit_dir)


func _try_exit_passage_for_spy(spy: SpyBase, exit_dir: String) -> void:
	_cross_passage_door(spy, exit_dir)


## Gestiona cooldown, puerta de salida y apertura. Devuelve true si el espía puede seguir.
func _cross_passage_door(spy: SpyBase, exit_dir: String) -> bool:
	# Solo si el espia sale desde ESTA habitacion (no al reaparecer en la de destino).
	if spy.current_room != self:
		return false
	var now_ms: int = Time.get_ticks_msec()
	var key: int = spy.get_instance_id()
	if int(_passage_cooldowns.get(key, 0)) > now_ms or spy.is_passage_bounce_blocked(self, exit_dir):
		return false
	_passage_cooldowns[key] = now_ms + PASSAGE_COOLDOWN_MS
	var passage_door: Door = get_door_for_direction(exit_dir)
	if passage_door == null:
		return true
	if passage_door.is_exit_door:
		GameState.notify_exit_reached(spy.spy_id)
		if not GameState.running:
			return false
		if not GameState.has_all_items(spy.spy_id):
			return false
	passage_door.try_open_for_spy(spy)
	return true


func _build_wall_collision() -> void:
	RoomGeometry.build_wall_collision(self)


func _build_trigger() -> void:
	var area: Area2D = Area2D.new()
	area.name = "RoomTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	var shape: CollisionPolygon2D = CollisionPolygon2D.new()
	shape.polygon = RoomPerspective.floor_polygon(get_room_w(), get_room_h())
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("spy"):
		return
	if not spies_inside.has(body):
		spies_inside.append(body)
	spy_entered.emit(body)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("spy"):
		return
	spies_inside.erase(body)
	spy_exited.emit(body)


func register_furniture(node: Node) -> void:
	furniture_list.append(node)
	if node is Furniture:
		(node as Furniture).owning_room = self
	furniture_container.add_child(node)


func clamp_local_position(local_pos: Vector2) -> Vector2:
	return RoomPerspective.clamp_to_floor(local_pos, get_room_w(), get_room_h())


# El origen del espía cuenta como dentro si cae en el suelo o a pocos pixeles del borde.
func contains_world_point(world_pos: Vector2, margin: float = 64.0) -> bool:
	var local_pos: Vector2 = world_pos - global_position
	var clamped: Vector2 = clamp_local_position(local_pos)
	return local_pos.distance_squared_to(clamped) <= margin * margin


func get_depth_at_local(local_pos: Vector2) -> float:
	return RoomPerspective.depth_from_y(local_pos.y, get_room_h())


func get_door_spawn(direction: String) -> Vector2:
	return RoomPerspective.get_door_entry_position(direction, get_room_w(), get_room_h())


func get_door_world_pos(direction: String) -> Vector2:
	return global_position + RoomPerspective.get_door_nav_position(direction, get_room_w(), get_room_h())


func get_door_for_direction(direction: String) -> Door:
	for door: Door in door_list:
		if door.direction == direction:
			return door
	return null


func get_center_world_pos() -> Vector2:
	return global_position + RoomPerspective.visible_content_center(get_room_w(), get_room_h())


func has_timed_trap() -> bool:
	return _timed_state != TimedTrapState.NONE


func is_timed_trap_counting() -> bool:
	return _timed_state == TimedTrapState.COUNTING


func arm_timed_trap(owner_spy_id: int) -> bool:
	if has_timed_trap():
		return false
	_timed_state = TimedTrapState.ARMED
	_timed_trapper_id = owner_spy_id
	_timed_fuse_left = 0.0
	return true


## Con el desactivador en la mano se corta la mecha (armada o ya en cuenta atrás).
func try_defuse_timed_trap(spy: SpyBase) -> bool:
	if not has_timed_trap() or not TrapRules.try_disarm(spy, ItemDB.TrapId.TIMED):
		return false
	_clear_timed_trap()
	return true


func _try_defuse_by_anyone_inside() -> bool:
	for body: Node in spies_inside:
		var spy: SpyBase = body as SpyBase
		if TrapRules.holds_counter_for(spy, ItemDB.TrapId.TIMED):
			return try_defuse_timed_trap(spy)
	return false


func _clear_timed_trap() -> void:
	_timed_state = TimedTrapState.NONE
	_timed_trapper_id = -1
	_timed_fuse_left = 0.0
	_stop_fuse_audio()
	queue_redraw()


func find_spring_exit() -> Dictionary:
	var mansion: Mansion = _find_mansion()
	if mansion == null:
		return {}
	var options: Array[Dictionary] = []
	for dir_str: String in ["N", "S", "E", "W"]:
		if not _has_passage(dir_str):
			continue
		var neighbor: Room = mansion.room_grid.get(grid_pos + GridDirection.delta(dir_str)) as Room
		if neighbor == null:
			continue
		var entry_dir: String = GridDirection.opposite(dir_str)
		if not neighbor._has_passage(entry_dir):
			continue
		options.append({
			"room": neighbor,
			"entry_dir": entry_dir,
			"exit_dir": dir_str,
		})
	if options.is_empty():
		return {}
	return options[randi() % options.size()]


func _on_timed_spy_entered(spy: Node) -> void:
	if _timed_state != TimedTrapState.ARMED:
		return
	var body: SpyBase = spy as SpyBase
	if body == null or not body.is_alive:
		return
	if try_defuse_timed_trap(body):
		return
	_timed_state = TimedTrapState.COUNTING
	_timed_fuse_left = ItemDB.TIMED_BOMB_FUSE
	_tick_wait = 0.0
	_start_fuse_audio()
	queue_redraw()


func _explode_timed_trap() -> void:
	_clear_timed_trap()
	Sfx.play_bomb_exploded()
	var victims: Array[SpyBase] = []
	for body: Node in spies_inside:
		var spy: SpyBase = body as SpyBase
		if spy != null and spy.is_alive:
			victims.append(spy)
	for spy: SpyBase in victims:
		spy.apply_trap_effect(ItemDB.TrapId.TIMED)


func _fuse_tint() -> Color:
	if _timed_state != TimedTrapState.COUNTING:
		return Color.WHITE
	var wave: float = sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5
	return Color(1.0, lerpf(0.32, 0.55, wave), lerpf(0.28, 0.45, wave))


func _has_passage(dir_str: String) -> bool:
	match dir_str:
		"N":
			return has_door_n
		"S":
			return has_door_s
		"W":
			return has_door_w
		"E":
			return has_door_e
	return false


func _find_mansion() -> Mansion:
	var node: Node = self
	while node != null:
		if node is Mansion:
			return node as Mansion
		node = node.get_parent()
	return null


func _start_fuse_audio() -> void:
	_stop_fuse_audio()
	_tick_player = AudioStreamPlayer.new()
	_tick_player.stream = _shared_tick_stream()
	_tick_player.volume_db = -6.0
	add_child(_tick_player)


func _stop_fuse_audio() -> void:
	if _tick_player == null:
		return
	_tick_player.stop()
	_tick_player.queue_free()
	_tick_player = null


func _play_tick_if_due(delta: float) -> void:
	if _tick_player == null:
		return
	_tick_wait -= delta
	if _tick_wait > 0.0:
		return
	_tick_wait = TICK_GAP
	_tick_player.play()


static func _shared_tick_stream() -> AudioStreamWAV:
	if _shared_tick != null:
		return _shared_tick
	var rate: int = 22050
	var count: int = int(float(rate) * 0.06)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / float(rate)
		var env: float = 1.0 - (float(i) / float(count))
		var sample: float = sin(t * TAU * 740.0) * env * 0.45
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_shared_tick = wav
	return wav
