extends Node2D
class_name Furniture

# Mueble: vacio / con item / con arma / con trampa (oculta). Abierto = desplazado para inspeccionar o poner trampa.

signal item_taken(item_id: int, spy: SpyBase)
signal trap_triggered(trap_id: int, spy: SpyBase)
signal opened_changed(is_open: bool)


## Lo que encuentra un espía al registrar el mueble. La trampa la resuelve TrapRules.
class SearchResult:
	extends RefCounted
	var item_id: int = -1
	var weapon_id: StringName = &""
	var trap_id: int = -1
	var trapper_id: int = -1

const INTERACT_PADDING: float = 20.0
const INSPECT_LIFT_PX: float = 20.0
const INSPECT_SLIDE_PX: float = 28.0

enum State { EMPTY, HAS_ITEM, HAS_WEAPON, HAS_TRAP }

@export var kind: int = ItemDB.FurnitureKind.DRAWERS

var state: int = State.EMPTY
var hidden_item: int = -1
var hidden_weapon_id: StringName = &""
var trap_id: int = -1
var trapper_id: int = -1
var owning_room: Room = null
var is_open: bool = false
var _inspect_visual_offset: Vector2 = Vector2.ZERO
var _body_shape: RectangleShape2D = null
var _interact_shape: RectangleShape2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("furniture")
	_build_collider()
	_build_interact_zone()
	_sync_collision_to_metrics()
	queue_redraw()


func _process(_delta: float) -> void:
	z_index = int(position.y)


func is_raised_open() -> bool:
	return is_open


func raise_open(opener: Node2D = null) -> void:
	if is_open:
		return
	is_open = true
	if kind == ItemDB.FurnitureKind.PAINTING:
		_inspect_visual_offset = _painting_slide_offset(opener)
	else:
		_inspect_visual_offset = Vector2(0.0, -INSPECT_LIFT_PX)
	opened_changed.emit(true)
	queue_redraw()


func lower_close() -> void:
	if not is_open:
		return
	is_open = false
	_inspect_visual_offset = Vector2.ZERO
	opened_changed.emit(false)
	queue_redraw()


func _painting_slide_offset(opener: Node2D) -> Vector2:
	var dir: float = 1.0
	if opener != null and opener.global_position.x >= global_position.x:
		dir = -1.0
	return Vector2(INSPECT_SLIDE_PX * dir, 0.0)


func _depth() -> float:
	if owning_room == null:
		return 0.65
	return owning_room.get_depth_at_local(position)


func _draw() -> void:
	var vis: Vector2 = PropMetrics.furniture_visual(kind, _depth())
	var foot: Vector2 = PropMetrics.furniture_footprint(kind, _depth())
	var offset: Vector2 = _inspect_visual_offset
	var bottom: float = foot.y * 0.5
	var rect := Rect2(Vector2(-vis.x * 0.5, bottom - vis.y) + offset, vis)
	var tex: Texture2D = ArtLibrary.furniture_texture(kind)
	if tex != null:
		draw_texture_rect(tex, rect, false)
	_draw_kind_label(rect)
	if is_open and state == State.HAS_WEAPON and not hidden_weapon_id.is_empty():
		_draw_hidden_weapon(rect)


func _draw_hidden_weapon(rect: Rect2) -> void:
	var weapon: WeaponData = WeaponDB.get_weapon(hidden_weapon_id)
	var col: Color = weapon.hold_color if weapon != null else Color("#9e9e9e")
	var center: Vector2 = rect.get_center()
	draw_circle(center, 7.0, col)
	draw_arc(center, 7.0, 0.0, TAU, 12, ItemDB.COLOR_OUTLINE, 1.5, false)


func _draw_kind_label(rect: Rect2) -> void:
	var label: String = ItemDB.get_furniture_name(kind)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base: Vector2 = Vector2(rect.get_center().x - text_size.x * 0.5, rect.end.y + 12.0)
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.85)
	var text_col: Color = Color(0.98, 0.98, 0.98, 0.95)
	draw_string(font, base + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


func _build_collider() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_body_shape = RectangleShape2D.new()
	_body_shape.size = Vector2(32, 20)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _body_shape
	body.add_child(col)
	add_child(body)


func _build_interact_zone() -> void:
	var area: Area2D = Area2D.new()
	area.name = "InteractZone"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	_interact_shape = RectangleShape2D.new()
	_interact_shape.size = Vector2(48, 36)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _interact_shape
	area.add_child(col)
	add_child(area)


func _sync_collision_to_metrics() -> void:
	var foot: Vector2 = PropMetrics.furniture_footprint(kind, _depth())
	if _body_shape != null:
		_body_shape.size = foot
	if _interact_shape != null:
		_interact_shape.size = foot + Vector2.ONE * INTERACT_PADDING * 2.0


func hide_item(item_id: int) -> void:
	hidden_item = item_id
	state = State.HAS_ITEM


func hide_weapon(weapon_id: StringName) -> void:
	if weapon_id.is_empty():
		return
	hidden_weapon_id = weapon_id
	state = State.HAS_WEAPON


func set_trap(new_trap_id: int, owner_spy_id: int) -> bool:
	if not ItemDB.is_furniture_trap(new_trap_id):
		return false
	if not is_open or state != State.EMPTY:
		return false
	trap_id = new_trap_id
	trapper_id = owner_spy_id
	state = State.HAS_TRAP
	lower_close()
	flash_placed()
	return true


func flash_placed() -> void:
	modulate = Color(1.55, 1.35, 0.55)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.45)


## Vacía el mueble y devuelve lo que había dentro.
func interact(spy: SpyBase) -> SearchResult:
	var result: SearchResult = SearchResult.new()
	match state:
		State.HAS_ITEM:
			result.item_id = hidden_item
			item_taken.emit(hidden_item, spy)
		State.HAS_WEAPON:
			result.weapon_id = hidden_weapon_id
		State.HAS_TRAP:
			result.trap_id = trap_id
			result.trapper_id = trapper_id
			trap_triggered.emit(trap_id, spy)
	_clear_contents()
	return result


func _clear_contents() -> void:
	state = State.EMPTY
	hidden_item = -1
	hidden_weapon_id = &""
	trap_id = -1
	trapper_id = -1


func has_trap() -> bool:
	return state == State.HAS_TRAP


func has_item() -> bool:
	return state == State.HAS_ITEM


func has_weapon() -> bool:
	return state == State.HAS_WEAPON


func is_empty() -> bool:
	return state == State.EMPTY


func world_hit_rect() -> Rect2:
	var size: Vector2 = _body_shape.size if _body_shape != null else Vector2(40.0, 24.0)
	return Rect2(global_position - size * 0.5, size)


func destroy_from_rocket() -> void:
	_drop_rocket_contents()
	_release_inspecting_spies()
	if owning_room != null:
		owning_room.furniture_list.erase(self)
		var mansion: Mansion = owning_room.get_parent() as Mansion
		if mansion != null:
			mansion.all_furniture.erase(self)
	queue_free()


func _drop_rocket_contents() -> void:
	if owning_room == null:
		return
	match state:
		State.HAS_ITEM:
			if hidden_item >= 0:
				GameState.spawn_dropped_item(owning_room, global_position, hidden_item)
		State.HAS_WEAPON:
			if hidden_weapon_id.is_empty():
				return
			var ammo: int = -1
			var weapon: WeaponData = WeaponDB.get_weapon(hidden_weapon_id)
			if weapon != null:
				ammo = weapon.pickup_ammo
			GameState.spawn_dropped_weapon(owning_room, global_position, hidden_weapon_id, ammo)
		State.HAS_TRAP:
			pass


func _release_inspecting_spies() -> void:
	if owning_room == null:
		return
	for node: Node in owning_room.spies_inside:
		var spy: SpyBase = node as SpyBase
		if spy == null:
			continue
		if spy.open_furniture == self:
			spy.open_furniture = null
		if spy.nearby_furniture == self:
			spy.nearby_furniture = null
