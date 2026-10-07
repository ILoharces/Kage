class_name ArtLibrary
extends RefCounted

## Placeholders de color plano. Sustituye cada PNG por tu sprite, con el mismo nombre.

const TILE: float = 32.0
const FLOOR_EXIT_TINT := Color(0.72, 1.0, 0.78)

const FLOOR: Texture2D = preload("res://art/floor.png")
const WALL: Texture2D = preload("res://art/wall.png")
const WALL_SIDE: Texture2D = preload("res://art/wall_side.png")
const DOOR: Texture2D = preload("res://art/door.png")
const DOOR_EXIT: Texture2D = preload("res://art/door_exit.png")
const SPY_WHITE: Texture2D = preload("res://art/spy_white.png")
const SPY_BLACK: Texture2D = preload("res://art/spy_black.png")
const PISTOL: Texture2D = preload("res://art/pistol.png")
const LAPTOP: Texture2D = preload("res://art/laptop.png")

const FURNITURE: Array[Texture2D] = [
	preload("res://art/furniture/painting.png"),
	preload("res://art/furniture/bookshelf.png"),
	preload("res://art/furniture/armchair.png"),
	preload("res://art/furniture/drawers.png"),
	preload("res://art/furniture/plant.png"),
	preload("res://art/furniture/lamp.png"),
	preload("res://art/furniture/clock.png"),
	preload("res://art/furniture/table.png"),
	preload("res://art/furniture/weapon_box.png"),
]

const ITEMS: Array[Texture2D] = [
	preload("res://art/items/suitcase.png"),
	preload("res://art/items/key.png"),
	preload("res://art/items/money.png"),
	preload("res://art/items/passport.png"),
	preload("res://art/items/microfilm.png"),
]

const TRAPS: Array[Texture2D] = [
	preload("res://art/items/trap_bomb.png"),
	preload("res://art/items/trap_spring.png"),
	preload("res://art/items/trap_bucket.png"),
	preload("res://art/items/trap_gun.png"),
	preload("res://art/items/trap_timed.png"),
]

const COUNTERS: Array[Texture2D] = [
	preload("res://art/items/counter_cutters.png"),
	preload("res://art/items/counter_wrench.png"),
	preload("res://art/items/counter_umbrella.png"),
	preload("res://art/items/counter_tongs.png"),
	preload("res://art/items/counter_mask.png"),
]


static func spy_texture(spy_id: int) -> Texture2D:
	if spy_id == ItemDB.SpyId.PLAYER2:
		return SPY_BLACK
	return SPY_WHITE


static func furniture_texture(kind: int) -> Texture2D:
	return _at(FURNITURE, kind)


static func item_texture(item_id: int) -> Texture2D:
	return _at(ITEMS, item_id)


static func icon_for_held(held: HeldInventory) -> Texture2D:
	if held == null or not held.is_holding():
		return null
	if held.is_holding_suitcase():
		return item_texture(ItemDB.ItemId.SUITCASE)
	if held.kind == HeldInventory.Kind.ITEM:
		return item_texture(held.held_id)
	if held.kind == HeldInventory.Kind.TRAP:
		return _at(TRAPS, held.held_id)
	if held.kind == HeldInventory.Kind.COUNTER:
		return _at(COUNTERS, held.held_id)
	return null


static func _at(textures: Array[Texture2D], index: int) -> Texture2D:
	if index < 0 or index >= textures.size():
		return null
	return textures[index]
