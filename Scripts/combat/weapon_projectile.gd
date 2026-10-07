extends CharacterBody2D
class_name WeaponProjectile

const DEFAULT_MAX_TRAVEL: float = 1200.0
const SPAWN_OFFSET: float = 14.0
const BULLET_RADIUS: float = 4.0

var owner_spy_id: int = -1
var weapon_id: StringName = &""
var damage: float = 0.0
var knockback_force: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var max_travel: float = DEFAULT_MAX_TRAVEL
var room: Room = null

var _traveled: float = 0.0
var _hit: bool = false


static func spawn(
	p_room: Room,
	p_owner_spy_id: int,
	p_weapon_id: StringName,
	p_damage: float,
	p_knockback_force: float,
	p_direction: Vector2,
	p_speed: float,
	p_max_travel: float,
	p_muzzle_world_pos: Vector2
) -> WeaponProjectile:
	var projectile: WeaponProjectile = WeaponProjectile.new()
	projectile.owner_spy_id = p_owner_spy_id
	projectile.weapon_id = p_weapon_id
	projectile.damage = p_damage
	projectile.knockback_force = p_knockback_force
	projectile.direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	projectile.speed = p_speed
	projectile.max_travel = p_max_travel if p_max_travel > 0.0 else DEFAULT_MAX_TRAVEL
	projectile.room = p_room
	p_room.add_child(projectile)
	projectile.global_position = p_muzzle_world_pos + projectile.direction * SPAWN_OFFSET
	return projectile


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 7.0 if _is_rocket() else BULLET_RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	z_index = 512
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _hit:
		return
	var step: float = speed * delta
	var motion: Vector2 = direction * step
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + motion
	var hit_spy: SpyBase = _find_spy_hit_on_segment(start_pos, end_pos)
	if hit_spy != null:
		if _is_rocket():
			Sfx.play_bazooka_impact()
		_apply_spy_hit(hit_spy)
		return
	if _is_rocket():
		var furniture_hit: Dictionary = _furniture_on_segment(start_pos, end_pos)
		var wall_hit: Dictionary = _floor_edge_cross(start_pos, end_pos)
		var furniture_t: float = float(furniture_hit.get("t", -1.0))
		var wall_t: float = float(wall_hit.get("t", -1.0))
		if furniture_t >= 0.0 and (wall_t < 0.0 or furniture_t <= wall_t):
			_consume_rocket()
			var furn: Furniture = furniture_hit.get("furniture") as Furniture
			if furn != null:
				furn.destroy_from_rocket()
			return
		if wall_t >= 0.0:
			_consume_rocket()
			_open_breach(String(wall_hit.get("dir", "")), float(wall_hit.get("edge_t", 0.5)))
			return
		global_position = end_pos
		_traveled += step
		if _traveled >= max_travel:
			queue_free()
		return
	var collision: KinematicCollision2D = move_and_collide(motion)
	_traveled += step
	if collision != null:
		_handle_collision(collision.get_collider())
		return
	if _traveled >= max_travel:
		queue_free()
		return
	if room == null or not _is_inside_room():
		queue_free()


func _draw() -> void:
	if _is_rocket():
		var side: Vector2 = direction.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([
			direction * 14.0,
			-direction * 8.0 + side,
			-direction * 5.0,
			-direction * 8.0 - side,
		]), Color(0.78, 0.32, 0.12, 1.0))
		draw_circle(-direction * 9.0, 3.2, Color(1.0, 0.7, 0.18, 0.95))
		return
	draw_circle(Vector2.ZERO, BULLET_RADIUS, Color(1.0, 0.88, 0.2, 0.95))
	draw_circle(Vector2.ZERO, BULLET_RADIUS * 0.55, Color(1.0, 0.98, 0.75, 1.0))


func _handle_collision(collider: Object) -> void:
	if _hit:
		return
	if collider is StaticBody2D:
		_hit = true
		queue_free()


func _find_spy_hit_on_segment(from_pos: Vector2, to_pos: Vector2) -> SpyBase:
	if room == null:
		return null
	for node: Node in room.spies_inside:
		var spy: SpyBase = node as SpyBase
		if spy == null or spy.spy_id == owner_spy_id or not spy.is_alive:
			continue
		if spy.intersects_damage_segment(from_pos, to_pos):
			return spy
	return null


func _apply_spy_hit(spy: SpyBase) -> void:
	if _hit or spy == null:
		return
	_hit = true
	if damage > 0.0:
		spy.combat.apply_damage(damage, owner_spy_id, weapon_id)
	if knockback_force > 0.0:
		spy.combat.apply_weapon_knockback(direction, knockback_force)
	queue_free()


func _is_rocket() -> bool:
	return weapon_id == GameState.BAZOOKA_ID


func _consume_rocket() -> void:
	if _hit:
		return
	_hit = true
	Sfx.play_bazooka_impact()
	queue_free()


func _open_breach(direction: String, edge_t: float) -> void:
	if room == null or direction.is_empty():
		return
	room.open_rocket_breach.call_deferred(direction, edge_t)


func _furniture_on_segment(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	if room == null:
		return {}
	var best_t: float = -1.0
	var best: Furniture = null
	for node: Node in room.furniture_list:
		var furn: Furniture = node as Furniture
		if furn == null or not is_instance_valid(furn):
			continue
		var hit_t: float = _segment_rect_t(from_pos, to_pos, furn.world_hit_rect())
		if hit_t < 0.0:
			continue
		if best_t < 0.0 or hit_t < best_t:
			best_t = hit_t
			best = furn
	if best == null:
		return {}
	return {"t": best_t, "furniture": best}


func _floor_edge_cross(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	if room == null:
		return {}
	var start: Vector2 = from_pos - room.global_position
	var finish: Vector2 = to_pos - room.global_position
	var poly: PackedVector2Array = RoomPerspective.floor_polygon(room.get_room_w(), room.get_room_h())
	var best_t: float = -1.0
	var best: Dictionary = {}
	for edge_idx: int in poly.size():
		var seg_a: Vector2 = poly[edge_idx]
		var seg_b: Vector2 = poly[(edge_idx + 1) % poly.size()]
		var hit: Vector2 = _segment_hit(start, finish, seg_a, seg_b)
		if hit.x < 0.0:
			continue
		if best_t >= 0.0 and hit.x >= best_t:
			continue
		best_t = hit.x
		best = {
			"t": hit.x,
			"edge_t": hit.y,
			"dir": RoomPerspective.direction_for_edge_index(edge_idx),
		}
	return best


func _segment_rect_t(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> float:
	if rect.has_point(from_pos):
		return 0.0
	var corners: PackedVector2Array = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	])
	var best: float = -1.0
	for i: int in corners.size():
		var hit: Vector2 = _segment_hit(from_pos, to_pos, corners[i], corners[(i + 1) % corners.size()])
		if hit.x < 0.0:
			continue
		if best < 0.0 or hit.x < best:
			best = hit.x
	return best


func _segment_hit(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Vector2:
	var ray: Vector2 = b - a
	var edge: Vector2 = d - c
	var denom: float = ray.cross(edge)
	if absf(denom) < 0.00001:
		return Vector2(-1.0, -1.0)
	var offset: Vector2 = c - a
	var t: float = offset.cross(edge) / denom
	var u: float = offset.cross(ray) / denom
	if t < 0.0 or t > 1.0 or u < -0.001 or u > 1.001:
		return Vector2(-1.0, -1.0)
	return Vector2(t, clampf(u, 0.0, 1.0))


func _is_inside_room() -> bool:
	if room == null:
		return false
	var local_pos: Vector2 = global_position - room.global_position
	var clamped: Vector2 = room.clamp_local_position(local_pos)
	return local_pos.distance_to(clamped) < 2.0
