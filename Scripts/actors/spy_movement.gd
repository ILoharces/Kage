class_name SpyMovement
extends RefCounted

# Movimiento, pasajes entre habitaciones y orden de dibujo.

const SPEED: float = 245.0
const ACCEL: float = 2100.0
const FRICTION: float = 2800.0
const WALK_PHASE_DECAY: float = 10.0
# Por encima de esto el espia esta en otra sala, no pegado a la pared.
const ROOM_CLAMP_MAX_PULL: float = 512.0

enum SpringPhase { NONE, FALL, TO_DOOR, INTO, LIE, RISE }

const SPRING_FALL_TIME: float = 0.34
const SPRING_LIE_TIME: float = 0.5
const SPRING_RISE_TIME: float = 0.28
const SPRING_SLIDE_SPEED: float = 420.0
const SPRING_ARRIVE_DIST: float = 22.0

var host: SpyBase = null
var _passage_entry_blocks: Dictionary = {}
var _spring_phase: SpringPhase = SpringPhase.NONE
var _spring_time: float = 0.0
var _spring_dest: Room = null
var _spring_entry: String = ""
var _spring_exit: String = ""
var _spring_goal: Vector2 = Vector2.ZERO


func _init(p_host: SpyBase) -> void:
	host = p_host


func physics_process(delta: float) -> void:
	if host.slow_timer > 0.0:
		host.slow_timer = maxf(0.0, host.slow_timer - delta)
	if _spring_phase != SpringPhase.NONE:
		_tick_spring(delta)
		return
	if not host.is_alive:
		host.velocity = Vector2.ZERO
		host.move_and_slide()
		host.queue_redraw()
		return
	if host.knockback_timer > 0.0:
		host.knockback_timer = maxf(0.0, host.knockback_timer - delta)
		host.velocity = host.knockback_velocity
		host.modulate = host.alive_modulate
		_update_draw_order()
		_update_walk_phase(delta)
		host.update_body_collider()
		host.move_and_slide()
		_constrain_to_current_room()
		host.queue_redraw()
		return
	if host.stun_timer > 0.0:
		host.stun_timer = maxf(0.0, host.stun_timer - delta)
		host.modulate = Color(host.alive_modulate.r, host.alive_modulate.g, host.alive_modulate.b, 0.45)
		host.velocity = Vector2.ZERO
		if host.stun_timer <= 0.0:
			host.stunned_changed.emit(false)
	elif host.is_searching() or host.orbital_targeting:
		host.modulate = Color(host.alive_modulate.r, host.alive_modulate.g, host.alive_modulate.b, 0.75)
		host.velocity = Vector2.ZERO
	else:
		host.modulate = host.alive_modulate
		var input_vector: Vector2 = host._compute_input_vector()
		var speed_scale: float = SpyBase.MOVE_SLOW_SCALE if host.slow_timer > 0.0 else 1.0
		var desired: Vector2 = input_vector * SPEED * speed_scale
		var rate: float = ACCEL if input_vector.length_squared() > 0.0004 else FRICTION
		host.velocity = host.velocity.move_toward(desired, rate * delta)
	_update_draw_order()
	_update_walk_phase(delta)
	host.update_body_collider()
	host.move_and_slide()
	_constrain_to_current_room()
	if host.current_room != null:
		host.current_room.poll_spy_passages(host)
	host.queue_redraw()


func is_springing() -> bool:
	return _spring_phase != SpringPhase.NONE


func begin_spring_launch() -> void:
	cancel_spring()
	_spring_phase = SpringPhase.FALL
	_spring_time = 0.0
	_spring_dest = null
	_spring_entry = ""
	_spring_exit = ""
	host.knockdown_pose = 0.0
	host.velocity = Vector2.ZERO
	var room: Room = host.current_room
	if room != null:
		var passage: Dictionary = room.find_spring_exit()
		_spring_dest = passage.get("room") as Room
		_spring_entry = String(passage.get("entry_dir", ""))
		_spring_exit = String(passage.get("exit_dir", ""))
	host.queue_redraw()


func cancel_spring() -> void:
	_spring_phase = SpringPhase.NONE
	_spring_time = 0.0
	_spring_dest = null
	_spring_entry = ""
	_spring_exit = ""
	if host != null:
		host.knockdown_pose = 0.0


func _tick_spring(delta: float) -> void:
	host.modulate = host.alive_modulate
	match _spring_phase:
		SpringPhase.FALL:
			_spring_time += delta
			var fall_t: float = clampf(_spring_time / SPRING_FALL_TIME, 0.0, 1.0)
			host.knockdown_pose = fall_t
			host.velocity = Vector2.ZERO
			if fall_t >= 1.0:
				_begin_spring_slide()
		SpringPhase.TO_DOOR, SpringPhase.INTO:
			if _spring_step_toward(delta):
				if _spring_phase == SpringPhase.TO_DOOR:
					_cross_spring_door()
				else:
					_spring_phase = SpringPhase.LIE
					_spring_time = 0.0
					host.velocity = Vector2.ZERO
		SpringPhase.LIE:
			host.knockdown_pose = 1.0
			host.velocity = Vector2.ZERO
			_spring_time += delta
			if _spring_time >= SPRING_LIE_TIME:
				_spring_phase = SpringPhase.RISE
				_spring_time = 0.0
		SpringPhase.RISE:
			_spring_time += delta
			host.knockdown_pose = 1.0 - clampf(_spring_time / SPRING_RISE_TIME, 0.0, 1.0)
			host.velocity = Vector2.ZERO
			if host.knockdown_pose <= 0.0:
				cancel_spring()
	host.move_and_slide()
	_update_draw_order()
	host.update_body_collider()
	host.queue_redraw()


func _begin_spring_slide() -> void:
	host.knockdown_pose = 1.0
	var room: Room = host.current_room
	if room == null or _spring_dest == null or _spring_entry.is_empty() or _spring_exit.is_empty():
		_spring_phase = SpringPhase.LIE
		_spring_time = 0.0
		return
	var door: Door = room.get_door_for_direction(_spring_exit)
	if door != null and door.is_closed():
		door.try_open_for_spy(host.spy_id, true)
	_spring_goal = room.get_door_world_pos(_spring_exit)
	_spring_phase = SpringPhase.TO_DOOR


func _cross_spring_door() -> void:
	var destination: Room = _spring_dest
	var entry_dir: String = _spring_entry
	var from_room: Room = host.current_room
	if destination == null or entry_dir.is_empty():
		_spring_phase = SpringPhase.LIE
		_spring_time = 0.0
		return
	teleport_to_room(destination, entry_dir, from_room)
	var entry_pos: Vector2 = host.global_position
	var center: Vector2 = destination.get_center_world_pos()
	var inward: Vector2 = center - entry_pos
	if inward.length_squared() < 4.0:
		inward = Vector2.DOWN
	_spring_goal = entry_pos + inward.normalized() * 90.0
	_spring_phase = SpringPhase.INTO
	host.knockdown_pose = 1.0


func _spring_step_toward(_delta: float) -> bool:
	var to_goal: Vector2 = _spring_goal - host.global_position
	if to_goal.length() <= SPRING_ARRIVE_DIST:
		host.global_position = _spring_goal
		host.velocity = Vector2.ZERO
		return true
	host.velocity = to_goal.normalized() * SPRING_SLIDE_SPEED
	return false


func arm_passage_entry_block(room: Room, entry_dir: String) -> void:
	_passage_entry_blocks[_passage_block_key(room, entry_dir)] = true


func clear_passage_entry_block(room: Room, exit_dir: String) -> void:
	_passage_entry_blocks.erase(_passage_block_key(room, exit_dir))


func is_passage_bounce_blocked(room: Room, exit_dir: String) -> bool:
	return _passage_entry_blocks.has(_passage_block_key(room, exit_dir))


func _passage_block_key(room: Room, dir_str: String) -> String:
	return "%d:%s" % [room.get_instance_id(), dir_str]


func _finalize_passage_entry_block(room: Room, entry_dir: String) -> void:
	if not is_instance_valid(room) or host.current_room != room:
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(room) or host.current_room != room:
		return
	var area: Area2D = room.get_node_or_null("Passage_%s" % entry_dir) as Area2D
	if area != null and area.overlaps_body(host):
		return
	clear_passage_entry_block(room, entry_dir)


func _update_walk_phase(delta: float) -> void:
	if host.velocity.length_squared() > 64.0:
		host.walk_phase += delta * SpyBase.WALK_WIGGLE_SPEED
	else:
		host.walk_phase = lerpf(host.walk_phase, 0.0, delta * WALK_PHASE_DECAY)


func _update_draw_order() -> void:
	if host.current_room == null:
		host.z_index = 0
		return
	var local_y: float = host.global_position.y - host.current_room.global_position.y
	host.z_index = clampi(int(local_y), -4096, 4096)


func set_current_room(room: Room) -> void:
	host.current_room = room


func _constrain_to_current_room() -> void:
	if host.current_room == null:
		return
	var local_pos: Vector2 = host.global_position - host.current_room.global_position
	var clamped: Vector2 = host.current_room.clamp_local_position(local_pos)
	if local_pos.distance_squared_to(clamped) > ROOM_CLAMP_MAX_PULL * ROOM_CLAMP_MAX_PULL:
		_recover_current_room_from_position()
		return
	host.global_position = host.current_room.global_position + clamped


func _recover_current_room_from_position() -> void:
	var mansion: Mansion = host.get_parent() as Mansion
	if mansion == null:
		return
	var found: Room = mansion.room_containing_point(host.global_position)
	if found == null or found == host.current_room:
		return
	host.set_current_room(found)


func teleport_to_room(room: Room, entry_dir: String, from_room: Room = null) -> void:
	if room == null:
		return
	if host.is_searching():
		host.interaction.cancel_search()
	host.interaction.close_open_furniture()
	var prev_room: Room = from_room if from_room != null else host.current_room
	var prev_local: Vector2 = Vector2.ZERO
	if prev_room != null:
		prev_local = host.global_position - prev_room.global_position
	if prev_room != null and prev_room.spies_inside.has(host):
		prev_room.spies_inside.erase(host)
		prev_room.spy_exited.emit(host)
	host.current_room = room
	if not room.spies_inside.has(host):
		room.spies_inside.append(host)
		room.spy_entered.emit(host)
	room.set_passage_cooldown(host, Room.PASSAGE_COOLDOWN_MS)
	arm_passage_entry_block(room, entry_dir)
	var local_spawn: Vector2 = room.get_door_spawn(entry_dir)
	if prev_room != null:
		local_spawn = RoomPerspective.adjust_passage_entry_position(
			prev_local,
			prev_room.get_room_w(),
			prev_room.get_room_h(),
			entry_dir,
			local_spawn,
			room.get_room_w(),
			room.get_room_h()
		)
	local_spawn += RoomPerspective.door_entry_inward_offset(
		entry_dir, room.get_room_w(), room.get_room_h()
	)
	local_spawn = RoomPerspective.ensure_spawn_clear_of_passage(
		local_spawn, entry_dir, room.get_room_w(), room.get_room_h()
	)
	local_spawn = room.clamp_local_position(local_spawn)
	host.global_position = room.global_position + local_spawn
	host.update_body_collider()
	var entry_door: Door = room.get_door_for_direction(entry_dir)
	if entry_door != null:
		entry_door.try_open_for_spy(host.spy_id, true)
	_finalize_passage_entry_block.call_deferred(room, entry_dir)
	var inward: Vector2 = RoomPerspective.door_entry_inward_offset(
		entry_dir, room.get_room_w(), room.get_room_h()
	)
	if inward.length_squared() > 0.001:
		if host.velocity.length_squared() < 1.0 or host.velocity.dot(inward) <= 0.0:
			host.velocity = inward.normalized() * SPEED
