class_name ArtDraw
extends RefCounted

## Dibuja texturas sobre los polígonos de la habitación sin cambiar la colisión.


static func tiled(
	canvas: CanvasItem,
	points: PackedVector2Array,
	texture: Texture2D,
	tile: float,
	tint: Color = Color.WHITE,
	uv_origin: Vector2 = Vector2.ZERO
) -> void:
	if points.size() < 3 or texture == null or tile <= 0.0:
		return
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	for i: int in points.size():
		var p: Vector2 = points[i] + uv_origin
		uvs[i] = Vector2(p.x / tile, p.y / tile)
	canvas.draw_polygon(points, _colors(points.size(), tint), uvs, texture)


static func stretch(
	canvas: CanvasItem,
	points: PackedVector2Array,
	texture: Texture2D,
	tint: Color = Color.WHITE
) -> void:
	if points.size() < 3 or texture == null:
		return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	var size: Vector2 = bounds.size
	if size.x < 0.001:
		size.x = 1.0
	if size.y < 0.001:
		size.y = 1.0
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	for i: int in points.size():
		var local: Vector2 = points[i] - bounds.position
		uvs[i] = Vector2(local.x / size.x, local.y / size.y)
	canvas.draw_polygon(points, _colors(points.size(), tint), uvs, texture)


static func _colors(count: int, tint: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(count)
	for i: int in count:
		colors[i] = tint
	return colors
