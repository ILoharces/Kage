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

enum TimedTrapState { NONE, ARMED, COUNTING }

const TICK_GAP: float = 0.42

static var _shared_tick: AudioStreamWAV = null

var _timed_state: TimedTrapState = TimedTrapState.NONE
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
	queue_redraw()


func _process(delta: float) -> void:
	if _timed_state != TimedTrapState.COUNTING:
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
			passage_door.try_open_for_spy(spy.spy_id, true)
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


func _on_passage_entered(body: Node, target_room: Room, exit_dir: String, entry_dir: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	_try_passage_for_spy(spy, target_room, exit_dir, entry_dir)


func _try_passage_for_spy(
	spy: SpyBase, target_room: Room, exit_dir: String, entry_dir: String
) -> void:
	# Solo si el espia sale desde ESTA habitacion (no al reaparecer en la de destino).
	if spy.current_room != self:
		return
	var now_ms: int = Time.get_ticks_msec()
	var key: int = spy.get_instance_id()
	if int(_passage_cooldowns.get(key, 0)) > now_ms or spy.is_passage_bounce_blocked(self, exit_dir):
		return
	_passage_cooldowns[key] = now_ms + PASSAGE_COOLDOWN_MS
	var passage_door: Door = get_door_for_direction(exit_dir)
	if passage_door != null:
		if passage_door.is_exit_door:
			if not GameState.has_all_items(spy.spy_id):
				GameState.exit_reached.emit(spy.spy_id)
				return
			GameState.notify_exit_reached(spy.spy_id)
			if not GameState.running:
				return
		passage_door.try_open_for_spy(spy.spy_id, true)
	spy.teleport_to_room(target_room, entry_dir, self)


func _on_exit_passage_entered(body: Node, exit_dir: String) -> void:
	var spy: SpyBase = body as SpyBase
	if spy == null:
		return
	_try_exit_passage_for_spy(spy, exit_dir)


func _try_exit_passage_for_spy(spy: SpyBase, exit_dir: String) -> void:
	if spy.current_room != self:
		return
	var now_ms: int = Time.get_ticks_msec()
	var key: int = spy.get_instance_id()
	if int(_passage_cooldowns.get(key, 0)) > now_ms or spy.is_passage_bounce_blocked(self, exit_dir):
		return
	_passage_cooldowns[key] = now_ms + PASSAGE_COOLDOWN_MS
	var passage_door: Door = get_door_for_direction(exit_dir)
	if passage_door != null:
		if passage_door.is_exit_door:
			if not GameState.has_all_items(spy.spy_id):
				GameState.exit_reached.emit(spy.spy_id)
				return
			GameState.notify_exit_reached(spy.spy_id)
			if not GameState.running:
				return
		passage_door.try_open_for_spy(spy.spy_id, true)


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


func arm_timed_trap() -> bool:
	if has_timed_trap():
		return false
	_timed_state = TimedTrapState.ARMED
	_timed_fuse_left = 0.0
	return true


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
	_timed_state = TimedTrapState.COUNTING
	_timed_fuse_left = ItemDB.TIMED_BOMB_FUSE
	_tick_wait = 0.0
	_start_fuse_audio()
	queue_redraw()


func _explode_timed_trap() -> void:
	_timed_state = TimedTrapState.NONE
	_timed_fuse_left = 0.0
	_stop_fuse_audio()
	Sfx.play_bomb_exploded()
	var victims: Array[SpyBase] = []
	for body: Node in spies_inside:
		var spy: SpyBase = body as SpyBase
		if spy != null and spy.is_alive and spy.combat != null:
			victims.append(spy)
	for spy: SpyBase in victims:
		if spy.is_alive:
			spy.combat.kill_from_trap(ItemDB.TrapId.TIMED)
	queue_redraw()


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
