class_name RoomGeometry
extends RefCounted

# Colisiones y geometría de paredes de una habitación.


static func build_wall_collision(room: Room) -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	room.add_child(walls)
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var floor_pts: PackedVector2Array = RoomPerspective.floor_polygon(rw, rh)
	var centroid: Vector2 = RoomPerspective.floor_centroid(rw, rh)
	for edge_idx: int in floor_pts.size():
		if edge_idx == RoomPerspective.EDGE_S:
			continue
		# El borde N del suelo queda dentro de la zona jugable; colisionarlo bloquea
		# la hitbox del espía antes de llegar a muebles en la pared norte (cuadros).
		if edge_idx == RoomPerspective.EDGE_N:
			continue
		var seg_a: Vector2 = floor_pts[edge_idx]
		var seg_b: Vector2 = floor_pts[(edge_idx + 1) % floor_pts.size()]
		var dir_str: String = RoomPerspective.direction_for_edge_index(edge_idx)
		var gaps: Array = _gaps_along_edge(room, dir_str, seg_a, seg_b, rw, rh)
		_add_edge_with_gaps(walls, seg_a, seg_b, gaps, centroid, true)
	_add_south_bar_collision(room, walls, rw, rh)


static func _gaps_along_edge(
	room: Room,
	dir_str: String,
	seg_a: Vector2,
	seg_b: Vector2,
	rw: float,
	rh: float
) -> Array:
	var gaps: Array = []
	var edge: Vector2 = seg_b - seg_a
	var length: float = edge.length()
	if length < 1.0:
		return gaps
	var along: Vector2 = edge / length
	var door_half: float = RoomPerspective.get_door_gap_half_tight(dir_str, rw, rh)
	var breach_half: float = RoomPerspective.opening_half_along_edge(dir_str, rw, rh)
	if _room_has_door(room, dir_str):
		var door_center: Vector2 = RoomPerspective.get_door_visual_center(dir_str, rw, rh)
		var door_on: Vector2 = RoomPerspective.project_point_on_segment(door_center, seg_a, seg_b)
		gaps.append({"along": (door_on - seg_a).dot(along), "half": door_half})
	for breach: Dictionary in room.breaches:
		if String(breach.get("dir", "")) != dir_str:
			continue
		gaps.append({"along": float(breach.get("t", 0.5)) * length, "half": breach_half})
	return gaps


static func _room_has_door(room: Room, dir_str: String) -> bool:
	match dir_str:
		"N":
			return room.has_door_n
		"E":
			return room.has_door_e
		"S":
			return room.has_door_s
		"W":
			return room.has_door_w
	return false


static func _add_edge_with_gaps(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	gaps: Array,
	centroid: Vector2,
	use_capsule: bool
) -> void:
	var edge: Vector2 = seg_b - seg_a
	var length: float = edge.length()
	if length < 1.0:
		return
	var dir: Vector2 = edge / length
	var cuts: Array[Vector2] = []
	for gap: Variant in gaps:
		var data: Dictionary = gap as Dictionary
		var center: float = float(data.get("along", 0.0))
		var half: float = float(data.get("half", 0.0))
		cuts.append(Vector2(center - half, center + half))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for cut: Vector2 in cuts:
		if merged.is_empty() or cut.x > merged[merged.size() - 1].y:
			merged.append(cut)
			continue
		var last: Vector2 = merged[merged.size() - 1]
		last.y = maxf(last.y, cut.y)
		merged[merged.size() - 1] = last
	var solids: Array[Vector2] = []
	var cursor: float = 0.0
	for span: Vector2 in merged:
		if span.x > cursor + 1.0:
			solids.append(Vector2(cursor, span.x))
		cursor = maxf(cursor, span.y)
	if cursor < length - 1.0:
		solids.append(Vector2(cursor, length))
	var cap_radius: float = Room.WALL_THICKNESS * 0.5 if use_capsule else 0.0
	for solid: Vector2 in solids:
		var x0: float = solid.x
		var x1: float = solid.y
		if x0 > 0.5:
			x0 += cap_radius
		if x1 < length - 0.5:
			x1 -= cap_radius
		if x1 - x0 < 4.0:
			continue
		var piece_a: Vector2 = seg_a + dir * x0
		var piece_b: Vector2 = seg_a + dir * x1
		if use_capsule:
			var extend_a: float = Room.WALL_CAPSULE_OVERLAP if solid.x <= 0.5 else 0.0
			var extend_b: float = Room.WALL_CAPSULE_OVERLAP if solid.y >= length - 0.5 else 0.0
			_add_capsule_wall_on_edge(
				parent, piece_a, piece_b, centroid, Room.WALL_THICKNESS, extend_a, extend_b
			)
		else:
			_add_wall_strip_on_edge(parent, piece_a, piece_b, centroid, Room.WALL_THICKNESS, 0.0)


static func _add_south_bar_collision(room: Room, parent: StaticBody2D, rw: float, rh: float) -> void:
	var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
	var ranges: Array[Vector2] = _south_gap_ranges(room, rw, rh)
	if ranges.is_empty():
		_add_collision_polygon(parent, bar)
		return
	var top_l: Vector2 = bar[0]
	var top_r: Vector2 = bar[1]
	var front_r: Vector2 = bar[2]
	var front_l: Vector2 = bar[3]
	var cursor: float = top_l.x
	for span: Vector2 in ranges:
		if span.x > cursor + 4.0:
			_add_south_bar_piece(parent, cursor, span.x, top_l, top_r, front_l, front_r)
		cursor = maxf(cursor, span.y)
	if cursor < top_r.x - 4.0:
		_add_south_bar_piece(parent, cursor, top_r.x, top_l, top_r, front_l, front_r)


static func _south_gap_ranges(room: Room, rw: float, rh: float) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	if room.has_door_s:
		_append_poly_x_range(ranges, RoomPerspective.get_door_polygon("S", rw, rh))
	for breach: Dictionary in room.breaches:
		if String(breach.get("dir", "")) != "S":
			continue
		_append_poly_x_range(
			ranges,
			RoomPerspective.breach_polygon("S", float(breach.get("t", 0.5)), rw, rh)
		)
	ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for span: Vector2 in ranges:
		if merged.is_empty() or span.x > merged[merged.size() - 1].y:
			merged.append(span)
			continue
		var last: Vector2 = merged[merged.size() - 1]
		last.y = maxf(last.y, span.y)
		merged[merged.size() - 1] = last
	return merged


static func _append_poly_x_range(ranges: Array[Vector2], poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var min_x: float = poly[0].x
	var max_x: float = poly[0].x
	for point: Vector2 in poly:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	ranges.append(Vector2(min_x, max_x))


static func _add_south_bar_piece(
	parent: StaticBody2D,
	x0: float,
	x1: float,
	top_l: Vector2,
	top_r: Vector2,
	front_l: Vector2,
	front_r: Vector2
) -> void:
	var left_top: Vector2 = top_l if absf(x0 - top_l.x) < 1.0 else Vector2(x0, top_l.y)
	var right_top: Vector2 = top_r if absf(x1 - top_r.x) < 1.0 else Vector2(x1, top_r.y)
	var left_bot: Vector2 = front_l if absf(x0 - top_l.x) < 1.0 else Vector2(x0, front_l.y)
	var right_bot: Vector2 = front_r if absf(x1 - top_r.x) < 1.0 else Vector2(x1, front_r.y)
	_add_collision_polygon(parent, PackedVector2Array([left_top, right_top, right_bot, left_bot]))


static func _add_collision_polygon(parent: StaticBody2D, poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = poly
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	parent.add_child(col)


static func _add_wall_strip_on_edge(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	centroid: Vector2,
	thickness_outward: float,
	thickness_inward: float
) -> void:
	var normal_out: Vector2 = RoomPerspective.outward_normal_for_edge(seg_a, seg_b, centroid)
	var poly: PackedVector2Array = PackedVector2Array([
		seg_a - normal_out * thickness_inward,
		seg_b - normal_out * thickness_inward,
		seg_b + normal_out * thickness_outward,
		seg_a + normal_out * thickness_outward,
	])
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = poly
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	parent.add_child(col)


static func _add_capsule_wall_on_edge(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	centroid: Vector2,
	thickness: float,
	extend_a: float = Room.WALL_CAPSULE_OVERLAP,
	extend_b: float = Room.WALL_CAPSULE_OVERLAP
) -> void:
	var edge: Vector2 = seg_b - seg_a
	var length: float = edge.length()
	if length < 1.0:
		return
	var dir: Vector2 = edge / length
	var start: Vector2 = seg_a - dir * extend_a
	var end: Vector2 = seg_b + dir * extend_b
	var span: Vector2 = end - start
	var span_len: float = span.length()
	if span_len < 1.0:
		return
	var radius: float = thickness * 0.5
	var normal_out: Vector2 = RoomPerspective.outward_normal_for_edge(seg_a, seg_b, centroid)
	var mid: Vector2 = (start + end) * 0.5 + normal_out * radius
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = maxf(span_len - thickness, 0.01)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = capsule
	col.position = mid
	col.rotation = span.angle() + PI * 0.5
	parent.add_child(col)
