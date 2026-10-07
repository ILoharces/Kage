extends Area2D
class_name DroppedItem

# Objeto en el suelo. Se recoge con la accion interactuar (E), no al pasar encima.

var item_id: int = -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("dropped_item")
	add_to_group("ground_pickup")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = int(position.y)
	var col: CollisionShape2D = CollisionShape2D.new()
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = 14.0
	col.shape = sh
	add_child(col)
	_sync_pickup_shape()
	queue_redraw()


func _draw() -> void:
	if item_id < 0:
		return
	var size: Vector2 = PropMetrics.item_ground_size(item_id, PropMetrics.depth_of(self))
	var icon: Texture2D = ArtLibrary.item_texture(item_id)
	if icon != null:
		draw_texture_rect(icon, Rect2(-size * 0.5, size), false)
	var label: String = ItemDB.get_item_name(item_id)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(-text_w * 0.5, -size.y * 0.5 - 6.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ItemDB.COLOR_OUTLINE
	)


func _sync_pickup_shape() -> void:
	var col: CollisionShape2D = get_child(0) as CollisionShape2D
	if col == null or not (col.shape is CircleShape2D):
		return
	var size: Vector2 = Vector2(18, 14)
	if item_id >= 0:
		size = PropMetrics.item_ground_size(item_id, PropMetrics.depth_of(self))
	(col.shape as CircleShape2D).radius = PropMetrics.pickup_radius(size)


func get_pickup_label() -> String:
	return ItemDB.get_item_name(item_id)
