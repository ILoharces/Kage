class_name HeldInventory
extends RefCounted

# Una sola cosa en las manos: objeto suelto, maletin (con todo el botin), trampa, contramedida o arma.
# Trampas y contramedidas son "herramientas": salen del stock y vuelven a él al soltarlas.

enum Kind { NONE, ITEM, SUITCASE, TRAP, COUNTER, WEAPON }

var kind: int = Kind.NONE
var held_id: int = -1
var held_weapon_id: StringName = &""
var held_weapon_ammo: int = 0


func is_holding() -> bool:
	return kind != Kind.NONE and (held_id >= 0 or not held_weapon_id.is_empty())


func is_holding_trap() -> bool:
	return kind == Kind.TRAP and held_id >= 0


func is_holding_counter() -> bool:
	return kind == Kind.COUNTER and held_id >= 0


func is_holding_tool() -> bool:
	return is_holding_trap() or is_holding_counter()


func is_holding_weapon() -> bool:
	return kind == Kind.WEAPON and not held_weapon_id.is_empty()


func is_holding_carried() -> bool:
	return kind == Kind.ITEM or kind == Kind.SUITCASE


func is_holding_suitcase() -> bool:
	return kind == Kind.SUITCASE


func get_trap_id() -> int:
	return held_id if is_holding_trap() else -1


func get_counter_id() -> int:
	return held_id if is_holding_counter() else -1


func get_weapon_id() -> StringName:
	return held_weapon_id if is_holding_weapon() else &""


func clear() -> void:
	kind = Kind.NONE
	held_id = -1
	held_weapon_id = &""
	held_weapon_ammo = 0


func set_item(item_id: int) -> void:
	clear()
	kind = Kind.ITEM
	held_id = item_id


func set_suitcase() -> void:
	clear()
	kind = Kind.SUITCASE
	held_id = ItemDB.ItemId.SUITCASE


func set_trap(trap_id: int) -> void:
	clear()
	kind = Kind.TRAP
	held_id = trap_id


func set_counter(counter_id: int) -> void:
	clear()
	kind = Kind.COUNTER
	held_id = counter_id


func set_weapon(weapon_id: StringName, ammo: int = -1) -> void:
	clear()
	kind = Kind.WEAPON
	held_weapon_id = weapon_id
	var weapon: WeaponData = WeaponDB.get_weapon(weapon_id)
	if weapon != null and not weapon.uses_ammo:
		held_weapon_ammo = 1
	elif ammo >= 0:
		held_weapon_ammo = ammo
	elif weapon != null:
		held_weapon_ammo = maxi(1, weapon.pickup_ammo)
	else:
		held_weapon_ammo = 1


func release_tool() -> void:
	if is_holding_tool():
		clear()


func get_weapon_ammo() -> int:
	if not is_holding_weapon():
		return 0
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon != null and not weapon.uses_ammo:
		return 1
	return held_weapon_ammo


func consume_weapon_ammo() -> bool:
	if not is_holding_weapon():
		return false
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon == null:
		return false
	if not weapon.uses_ammo:
		return true
	if held_weapon_ammo <= 0:
		return false
	held_weapon_ammo -= 1
	return true


func has_weapon_ammo() -> bool:
	if not is_holding_weapon():
		return false
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon == null:
		return false
	return not weapon.uses_ammo or held_weapon_ammo > 0


func sync_carried_from_inventory(spy_id: int) -> bool:
	if is_holding_weapon() or is_holding_tool():
		return false
	var before_kind: int = kind
	var before_id: int = held_id
	var inv: Array = GameState.get_items(spy_id)
	if inv.has(ItemDB.ItemId.SUITCASE):
		set_suitcase()
	elif inv.size() == 1:
		set_item(int(inv[0]))
	else:
		clear()
	return kind != before_kind or held_id != before_id


func get_display_color() -> Color:
	if not is_holding():
		return Color.TRANSPARENT
	match kind:
		Kind.WEAPON:
			var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
			return weapon.hold_color if weapon != null else Color.WHITE
		Kind.TRAP:
			return ItemDB.get_trap_color(held_id)
		Kind.COUNTER:
			return ItemDB.get_counter_color(held_id)
		Kind.SUITCASE, Kind.ITEM:
			return ItemDB.ITEM_COLORS.get(held_id, Color.WHITE) as Color
	return Color.WHITE


func get_display_name() -> String:
	if not is_holding():
		return ""
	match kind:
		Kind.WEAPON:
			return WeaponDB.get_weapon_name(held_weapon_id)
		Kind.TRAP:
			return ItemDB.get_trap_name(held_id)
		Kind.COUNTER:
			return ItemDB.get_counter_name(held_id)
		Kind.SUITCASE, Kind.ITEM:
			return ItemDB.get_item_name(held_id)
	return "?"
