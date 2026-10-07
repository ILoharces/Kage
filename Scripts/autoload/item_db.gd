extends Node

# Base de datos estática del juego: items, trampas, contramedidas y muebles.
# Se accede como singleton (autoload ItemDB).

enum ItemId { SUITCASE, KEY, MONEY, PASSPORT }
enum TrapId { BOMB, SPRING, BUCKET, GUN, TIMED }
enum CounterId { WIRE_CUTTERS, WRENCH, UMBRELLA, TONGS, DEFUSER }
enum FurnitureKind { PAINTING, BOOKSHELF, ARMCHAIR, DRAWERS, PLANT, LAMP, CLOCK, TABLE, WEAPON_BOX }
enum SpyId { PLAYER1, PLAYER2 }
## Dónde se coloca cada trampa.
enum TrapSite { FURNITURE, DOOR, ROOM }

# Cuanto dura la mecha de la temporizada despues de que un espia entre en la habitacion.
const TIMED_BOMB_FUSE: float = 5.0

const TRAP_SITES: Dictionary = {
	TrapId.BOMB: TrapSite.FURNITURE,
	TrapId.SPRING: TrapSite.FURNITURE,
	TrapId.BUCKET: TrapSite.DOOR,
	TrapId.GUN: TrapSite.FURNITURE,
	TrapId.TIMED: TrapSite.ROOM,
}

# Cada trampa se neutraliza con una contramedida concreta, que hay que llevar en la mano.
const TRAP_TO_COUNTER: Dictionary = {
	TrapId.BOMB: CounterId.WIRE_CUTTERS,
	TrapId.SPRING: CounterId.WRENCH,
	TrapId.BUCKET: CounterId.UMBRELLA,
	TrapId.GUN: CounterId.TONGS,
	TrapId.TIMED: CounterId.DEFUSER,
}

const ITEM_COLORS: Dictionary = {
	ItemId.SUITCASE: Color("#00bcd4"),
	ItemId.KEY: Color("#ffeb3b"),
	ItemId.MONEY: Color("#43a047"),
	ItemId.PASSPORT: Color("#1565c0"),
}

const ITEM_NAMES: Dictionary = {
	ItemId.SUITCASE: "Maletín",
	ItemId.KEY: "Llave",
	ItemId.MONEY: "Dinero",
	ItemId.PASSPORT: "Pasaporte",
}

const TRAP_COLORS: Dictionary = {
	TrapId.BOMB: Color("#ff1744"),
	TrapId.SPRING: Color("#ffeb3b"),
	TrapId.BUCKET: Color("#29b6f6"),
	TrapId.GUN: Color("#8d6e63"),
	TrapId.TIMED: Color("#ff6d00"),
}

const TRAP_NAMES: Dictionary = {
	TrapId.BOMB: "Bomba",
	TrapId.SPRING: "Muelle",
	TrapId.BUCKET: "Cubo",
	TrapId.GUN: "Cartucho",
	TrapId.TIMED: "Temporizada",
}

const TRAP_HIT_NOTICES: Dictionary = {
	TrapId.BOMB: "Explota la bomba",
	TrapId.SPRING: "Te tumba el muelle",
	TrapId.BUCKET: "Te cae el cubo",
	TrapId.GUN: "Te dispara el cartucho",
	TrapId.TIMED: "Te alcanza la temporizada",
}

const COUNTER_NAMES: Dictionary = {
	CounterId.WIRE_CUTTERS: "Cortacables",
	CounterId.WRENCH: "Llave inglesa",
	CounterId.UMBRELLA: "Paraguas",
	CounterId.TONGS: "Tenazas",
	CounterId.DEFUSER: "Desactivador",
}

const COUNTER_COLORS: Dictionary = {
	CounterId.WIRE_CUTTERS: Color("#ef9a9a"),
	CounterId.WRENCH: Color("#fff59d"),
	CounterId.UMBRELLA: Color("#81d4fa"),
	CounterId.TONGS: Color("#bcaaa4"),
	CounterId.DEFUSER: Color("#ffcc80"),
}

const FURNITURE_NAMES: Dictionary = {
	FurnitureKind.PAINTING: "Cuadro",
	FurnitureKind.BOOKSHELF: "Estanteria",
	FurnitureKind.ARMCHAIR: "Sillon",
	FurnitureKind.DRAWERS: "Cajonera",
	FurnitureKind.PLANT: "Planta",
	FurnitureKind.LAMP: "Lampara",
	FurnitureKind.CLOCK: "Reloj",
	FurnitureKind.TABLE: "Mesa",
	FurnitureKind.WEAPON_BOX: "Caja armas",
}

const FURNITURE_COLORS: Dictionary = {
	FurnitureKind.PAINTING: Color("#d4a017"),
	FurnitureKind.BOOKSHELF: Color("#5d4037"),
	FurnitureKind.ARMCHAIR: Color("#7b1f1f"),
	FurnitureKind.DRAWERS: Color("#a1887f"),
	FurnitureKind.PLANT: Color("#388e3c"),
	FurnitureKind.LAMP: Color("#fdd835"),
	FurnitureKind.CLOCK: Color("#fbc02d"),
	FurnitureKind.TABLE: Color("#8d6e63"),
	FurnitureKind.WEAPON_BOX: Color("#455a64"),
}

const SPY_COLORS: Dictionary = {
	SpyId.PLAYER1: Color("#f5f5f5"),
	SpyId.PLAYER2: Color("#1a1a1a"),
}

const COLOR_FLOOR: Color = Color("#9a92ae")
const COLOR_FLOOR_EXIT: Color = Color("#6a9a72")
const COLOR_WALL: Color = Color("#d4cce8")
const COLOR_DOOR: Color = Color("#c03030")
const COLOR_DOOR_EXIT: Color = Color("#2e8b4a")
const COLOR_DOOR_GAP: Color = Color("#0a0a0a")
const COLOR_OUTLINE: Color = Color("#1a1a1a")


func get_item_name(item_id: int) -> String:
	return String(ITEM_NAMES.get(item_id, "?"))


func get_trap_name(trap_id: int) -> String:
	return String(TRAP_NAMES.get(trap_id, "Trampa"))


func get_trap_color(trap_id: int) -> Color:
	return TRAP_COLORS.get(trap_id, Color.WHITE) as Color


func get_trap_hit_notice(trap_id: int) -> String:
	return String(TRAP_HIT_NOTICES.get(trap_id, "Te afecta: %s" % get_trap_name(trap_id)))


func get_counter_name(counter_id: int) -> String:
	return String(COUNTER_NAMES.get(counter_id, "Contramedida"))


func get_counter_color(counter_id: int) -> Color:
	return COUNTER_COLORS.get(counter_id, Color.WHITE) as Color


func get_furniture_name(kind: int) -> String:
	return String(FURNITURE_NAMES.get(kind, "Mueble"))


func get_all_items() -> Array[int]:
	return _enum_values(ItemId)


func get_all_traps() -> Array[int]:
	return _enum_values(TrapId)


func get_all_counters() -> Array[int]:
	return _enum_values(CounterId)


func get_trap_site(trap_id: int) -> int:
	return int(TRAP_SITES.get(trap_id, TrapSite.FURNITURE))


func is_furniture_trap(trap_id: int) -> bool:
	return TRAP_SITES.has(trap_id) and get_trap_site(trap_id) == TrapSite.FURNITURE


func is_door_trap(trap_id: int) -> bool:
	return get_trap_site(trap_id) == TrapSite.DOOR


func is_room_trap(trap_id: int) -> bool:
	return get_trap_site(trap_id) == TrapSite.ROOM


func get_counter_for_trap(trap_id: int) -> int:
	return int(TRAP_TO_COUNTER.get(trap_id, -1))


func get_trap_for_counter(counter_id: int) -> int:
	for trap_id: Variant in TRAP_TO_COUNTER.keys():
		if int(TRAP_TO_COUNTER[trap_id]) == counter_id:
			return int(trap_id)
	return -1


func get_all_furniture_kinds() -> Array[int]:
	var arr: Array[int] = get_decor_furniture_kinds()
	arr.append(FurnitureKind.WEAPON_BOX)
	return arr


func get_decor_furniture_kinds() -> Array[int]:
	var arr: Array[int] = _enum_values(FurnitureKind)
	arr.erase(FurnitureKind.WEAPON_BOX)
	return arr


func _enum_values(enum_dict: Dictionary) -> Array[int]:
	var arr: Array[int] = []
	for value: Variant in enum_dict.values():
		arr.append(int(value))
	return arr
