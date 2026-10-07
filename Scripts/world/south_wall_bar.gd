extends Node2D
class_name SouthWallBar

# Barra de pared sur; mismo z_index que la puerta sur para ordenarse con el jugador.

const OUTLINE_W: float = 2.5

var owning_room: Room = null
var _local_bar: PackedVector2Array = PackedVector2Array()
var _local_gaps: Array[PackedVector2Array] = []


func setup(room: Room) -> void:
	owning_room = room
	_rebuild_polygons()
	queue_redraw()


func _process(_delta: float) -> void:
	if owning_room == null:
		return
	var south_door: Door = owning_room.get_door_for_direction("S")
	if south_door != null and is_instance_valid(south_door):
		z_index = south_door.z_index
	else:
		var rw: float = owning_room.get_room_w()
		var rh: float = owning_room.get_room_h()
		var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
		var center: Vector2 = _polygon_centroid(bar)
		z_index = int(center.y) + 2


func _rebuild_polygons() -> void:
	if owning_room == null:
		return
	var rw: float = owning_room.get_room_w()
	var rh: float = owning_room.get_room_h()
	var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
	var center: Vector2 = _polygon_centroid(bar)
	position = center
	_local_bar.clear()
	for p: Vector2 in bar:
		_local_bar.append(p - center)
	_local_gaps.clear()
	if owning_room.has_door_s:
		_local_gaps.append(_to_local(RoomPerspective.get_door_polygon("S", rw, rh), center))
	for breach: Dictionary in owning_room.breaches:
		if String(breach.get("dir", "")) != "S":
			continue
		_local_gaps.append(_to_local(
			RoomPerspective.breach_polygon("S", float(breach.get("t", 0.5)), rw, rh),
			center
		))


func _draw() -> void:
	if _local_bar.size() < 3:
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var outline: Color = ItemDB.COLOR_OUTLINE
	ArtDraw.tiled(self, _local_bar, ArtLibrary.WALL, ArtLibrary.TILE, Color.WHITE, position)
	draw_polyline(_local_bar + PackedVector2Array([_local_bar[0]]), outline, OUTLINE_W, true)
	for gap: PackedVector2Array in _local_gaps:
		if gap.size() < 3:
			continue
		draw_colored_polygon(gap, ItemDB.COLOR_DOOR_GAP)
		draw_polyline(gap + PackedVector2Array([gap[0]]), outline, OUTLINE_W, true)


static func _to_local(poly: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var local: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in poly:
		local.append(point - center)
	return local


static func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / float(poly.size())
