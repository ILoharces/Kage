class_name PropMetrics
extends RefCounted

# Tamaños en el frente de la habitación (profundidad 1).
# Ahí el espía mide unos 76 px de alto y 56 px de ancho.
# En el fondo (profundidad 0) todo se encoge al mismo ritmo que el espía.

const DEPTH_SCALE_BACK: float = 0.77
const PLACEMENT_GAP: float = 18.0

# Alto visual: estantería y reloj por encima del espía; sillón y mesa por debajo.
const FURNITURE_VISUAL: Dictionary = {
	ItemDB.FurnitureKind.PAINTING: Vector2(50, 36),
	ItemDB.FurnitureKind.BOOKSHELF: Vector2(58, 104),
	ItemDB.FurnitureKind.ARMCHAIR: Vector2(64, 48),
	ItemDB.FurnitureKind.DRAWERS: Vector2(52, 68),
	ItemDB.FurnitureKind.PLANT: Vector2(36, 62),
	ItemDB.FurnitureKind.LAMP: Vector2(26, 80),
	ItemDB.FurnitureKind.CLOCK: Vector2(30, 92),
	ItemDB.FurnitureKind.TABLE: Vector2(88, 34),
	ItemDB.FurnitureKind.WEAPON_BOX: Vector2(42, 32),
}

# Huella en el suelo (ancho, profundidad). No usa la altura del sprite.
const FURNITURE_FOOTPRINT: Dictionary = {
	ItemDB.FurnitureKind.PAINTING: Vector2(46, 12),
	ItemDB.FurnitureKind.BOOKSHELF: Vector2(54, 26),
	ItemDB.FurnitureKind.ARMCHAIR: Vector2(58, 30),
	ItemDB.FurnitureKind.DRAWERS: Vector2(48, 26),
	ItemDB.FurnitureKind.PLANT: Vector2(28, 22),
	ItemDB.FurnitureKind.LAMP: Vector2(20, 16),
	ItemDB.FurnitureKind.CLOCK: Vector2(24, 18),
	ItemDB.FurnitureKind.TABLE: Vector2(80, 32),
	ItemDB.FurnitureKind.WEAPON_BOX: Vector2(38, 26),
}

const ITEM_GROUND: Dictionary = {
	ItemDB.ItemId.SUITCASE: Vector2(36, 24),
	ItemDB.ItemId.KEY: Vector2(16, 12),
	ItemDB.ItemId.MONEY: Vector2(22, 14),
	ItemDB.ItemId.PASSPORT: Vector2(16, 22),
	ItemDB.ItemId.MICROFILM: Vector2(14, 14),
}

const WEAPON_GROUND: Vector2 = Vector2(30, 14)


static func depth_scale(depth: float) -> float:
	return lerpf(DEPTH_SCALE_BACK, 1.0, clampf(depth, 0.0, 1.0))


static func depth_of(node: Node2D) -> float:
	if node == null:
		return 0.65
	var room: Room = node.get_parent() as Room
	if room == null:
		return 0.65
	return room.get_depth_at_local(node.position)


static func furniture_visual(kind: int, depth: float) -> Vector2:
	return _vec(FURNITURE_VISUAL, kind, Vector2(48, 40)) * depth_scale(depth)


static func furniture_footprint(kind: int, depth: float) -> Vector2:
	return _vec(FURNITURE_FOOTPRINT, kind, Vector2(40, 24)) * depth_scale(depth)


static func plan_radius(kind: int) -> float:
	var visual: Vector2 = _vec(FURNITURE_VISUAL, kind, Vector2(48, 40))
	var foot: Vector2 = _vec(FURNITURE_FOOTPRINT, kind, Vector2(40, 24))
	return maxf(visual.x, foot.x) * 0.5


static func placement_gap(kind_a: int, kind_b: int) -> float:
	return plan_radius(kind_a) + plan_radius(kind_b) + PLACEMENT_GAP


static func item_ground_size(item_id: int, depth: float) -> Vector2:
	return _vec(ITEM_GROUND, item_id, Vector2(18, 14)) * depth_scale(depth)


static func weapon_ground_size(depth: float) -> Vector2:
	return WEAPON_GROUND * depth_scale(depth)


static func pickup_radius(size: Vector2) -> float:
	return maxf(14.0, maxf(size.x, size.y) * 0.65)


# Fracción del ancho del cuerpo (x) y del alto del torso (y) al llevarlo en la mano.
static func held_ratio(held: HeldInventory) -> Vector2:
	if held == null or not held.is_holding():
		return Vector2(0.4, 0.3)
	if held.is_holding_suitcase():
		return Vector2(0.78, 0.5)
	if held.kind == HeldInventory.Kind.ITEM:
		match held.held_id:
			ItemDB.ItemId.KEY:
				return Vector2(0.32, 0.22)
			ItemDB.ItemId.MONEY:
				return Vector2(0.42, 0.26)
			ItemDB.ItemId.PASSPORT:
				return Vector2(0.34, 0.4)
			ItemDB.ItemId.MICROFILM:
				return Vector2(0.26, 0.22)
			_:
				return Vector2(0.5, 0.36)
	if held.kind == HeldInventory.Kind.TRAP:
		if held.held_id == ItemDB.TrapId.WATER_BUCKET:
			return Vector2(0.46, 0.52)
		return Vector2(0.5, 0.4)
	if held.kind == HeldInventory.Kind.COUNTER:
		if held.held_id == ItemDB.CounterId.UMBRELLA:
			return Vector2(0.28, 0.62)
		return Vector2(0.4, 0.34)
	return Vector2(0.5, 0.36)


static func _vec(table: Dictionary, key: int, fallback: Vector2) -> Vector2:
	return table.get(key, fallback) as Vector2
