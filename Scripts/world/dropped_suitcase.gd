extends Area2D
class_name DroppedSuitcase

# Maletin en el suelo con todo el botin dentro. Se recoge con interactuar (E).

var owner_spy_id: int = -1
var stored_items: Array[int] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("dropped_suitcase")
	add_to_group("ground_pickup")
	z_index = int(position.y)
	var col: CollisionShape2D = CollisionShape2D.new()
	var size: Vector2 = PropMetrics.item_ground_size(ItemDB.ItemId.SUITCASE, PropMetrics.depth_of(self))
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = PropMetrics.pickup_radius(size)
	col.shape = sh
	add_child(col)
	queue_redraw()


func setup(owner_id: int, items: Array[int]) -> void:
	owner_spy_id = owner_id
	stored_items = items.duplicate()
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = PropMetrics.item_ground_size(ItemDB.ItemId.SUITCASE, PropMetrics.depth_of(self))
	var icon: Texture2D = ArtLibrary.item_texture(ItemDB.ItemId.SUITCASE)
	if icon != null:
		draw_texture_rect(icon, Rect2(-size * 0.5, size), false)
	var label: String = "Maletin"
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(-text_w * 0.5, size.y * 0.5 + 12.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ItemDB.COLOR_OUTLINE
	)
	if stored_items.size() > 1:
		var loot_count: int = stored_items.size() - 1
		var count_text: String = "x%d" % loot_count
		var count_w: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font,
			Vector2(-count_w * 0.5, size.y * 0.5 + 24.0),
			count_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.95, 0.95, 0.95, 0.95)
		)


func get_pickup_label() -> String:
	return ItemDB.get_item_name(ItemDB.ItemId.SUITCASE)
