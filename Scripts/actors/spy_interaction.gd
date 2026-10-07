class_name SpyInteraction
extends RefCounted

# Muebles, pickups, maletín, colocación de trampas y uso de contramedidas.

var host: SpyBase = null


func _init(p_host: SpyBase) -> void:
	host = p_host


func can_interact() -> bool:
	return host.can_act() and not host.orbital_targeting


func nearby_prompt() -> String:
	var target: Node = _closest_interact_target()
	if target == null:
		return ""
	if target is Door:
		var door: Door = target as Door
		var noun: String = "salida" if door.is_exit_door else "puerta"
		return ("Cerrar %s" % noun) if door.is_open else ("Abrir %s" % noun)
	if target.has_method("get_pickup_label"):
		return "Recoger %s" % String(target.call("get_pickup_label"))
	if target is Furniture:
		var furn: Furniture = target as Furniture
		var name_text: String = ItemDB.get_furniture_name(furn.kind).to_lower()
		return "Cerrar" if furn.is_raised_open() else "Registrar %s" % name_text
	return "Interactuar"


func interact_with_nearby() -> bool:
	if not can_interact():
		return false
	var target: Node = _closest_interact_target()
	if target == null:
		return false
	if target is Door:
		(target as Door).try_toggle_for_spy(host)
		return true
	if target.is_in_group("ground_pickup"):
		host.nearby_pickup = target
		return _try_pickup_nearby_ground()
	return use_furniture(target as Furniture)


func use_furniture(furn: Furniture) -> bool:
	if not can_interact() or furn == null or not is_instance_valid(furn):
		return false
	if furn.is_raised_open():
		close_furniture(furn)
		return true
	close_open_furniture()
	furn.raise_open(host)
	host.open_furniture = furn
	host.nearby_furniture = furn
	_resolve_search(furn, furn.interact(host))
	host.search_finished.emit(furn)
	return true


# --- Herramientas (trampas y contramedidas) -----------------------------------

## Pone en la mano una trampa o contramedida del stock. Suelta lo que llevara antes.
func equip_tool(kind: int, tool_id: int) -> bool:
	if host.held == null or tool_id < 0:
		return false
	if not _has_tool_stock(kind, tool_id):
		return false
	if host.held.kind == kind and host.held.held_id == tool_id:
		return true
	if not host.held.is_holding_tool() and not GameState.empty_hands(host):
		return false
	if kind == HeldInventory.Kind.COUNTER:
		host.held.set_counter(tool_id)
	else:
		host.held.set_trap(tool_id)
	host.emit_held_changed()
	return true


func _has_tool_stock(kind: int, tool_id: int) -> bool:
	if kind == HeldInventory.Kind.COUNTER:
		return GameState.get_counter_count(host.spy_id, tool_id) > 0
	if kind == HeldInventory.Kind.TRAP:
		return GameState.get_trap_count(host.spy_id, tool_id) > 0
	return false


func try_place_trap(trap_id: int) -> bool:
	if not host.can_act() or trap_id < 0:
		return false
	if not equip_tool(HeldInventory.Kind.TRAP, trap_id):
		return false
	var placed: bool = false
	match ItemDB.get_trap_site(trap_id):
		ItemDB.TrapSite.ROOM:
			placed = host.current_room != null and host.current_room.arm_timed_trap(host.spy_id)
		ItemDB.TrapSite.DOOR:
			var door: Door = host.nearby_door
			placed = door != null and is_instance_valid(door) and door.arm_bucket(host.spy_id)
		ItemDB.TrapSite.FURNITURE:
			var furn: Furniture = host.nearby_furniture
			placed = furn != null and is_instance_valid(furn) and furn.set_trap(trap_id, host.spy_id)
			if placed:
				host.open_furniture = null
	if placed:
		_commit_placed_trap(trap_id)
	return placed


func _commit_placed_trap(trap_id: int) -> void:
	GameState.consume_trap(host.spy_id, trap_id)
	host.release_tool_selection()
	GameState.notify_human(host.spy_id, "%s colocado" % ItemDB.get_trap_name(trap_id))
	Sfx.play_trap_placed()


# --- Muebles ------------------------------------------------------------------

func close_furniture(furn: Furniture) -> void:
	if furn == null or not is_instance_valid(furn):
		return
	furn.lower_close()
	if host.open_furniture == furn:
		host.open_furniture = null


func close_open_furniture() -> void:
	if host.open_furniture != null:
		close_furniture(host.open_furniture)


func _resolve_search(furn: Furniture, result: Furniture.SearchResult) -> void:
	if result.item_id >= 0 and not GameState.owns_item(host.spy_id, result.item_id):
		var collected: bool = GameState.make_room_for_loot(host) and GameState.collect_item(host, result.item_id)
		if collected:
			_refresh_hands_from_inventory()
		elif result.item_id != ItemDB.ItemId.SUITCASE and host.current_room != null:
			GameState.spawn_dropped_item(host.current_room, host.global_position, result.item_id)
	if not result.weapon_id.is_empty():
		GameState.try_pickup_weapon_in_hands(host, result.weapon_id)
	if result.trap_id >= 0:
		TrapRules.trigger(host, result.trap_id, furn.global_position)
		close_furniture(furn)


# --- Manos y suelo ------------------------------------------------------------

func refresh_hands_from_inventory() -> void:
	_refresh_hands_from_inventory()


func _refresh_hands_from_inventory() -> void:
	if host.held == null:
		return
	if host.held.sync_carried_from_inventory(host.spy_id):
		host.emit_held_changed()
	else:
		host.queue_redraw()


func _try_pickup_nearby_ground() -> bool:
	if host.nearby_pickup == null or not is_instance_valid(host.nearby_pickup):
		return false
	if not GameState.try_pickup_ground(host, host.nearby_pickup):
		return false
	_refresh_hands_from_inventory()
	return true


func _closest_interact_target() -> Node:
	var best: Node = null
	var best_dist: float = INF
	var candidates: Array[Node] = [_find_ground_pickup_target()]
	if host.nearby_door != null and is_instance_valid(host.nearby_door):
		candidates.append(host.nearby_door)
	if host.nearby_furniture != null and is_instance_valid(host.nearby_furniture):
		candidates.append(host.nearby_furniture)
	for candidate: Node in candidates:
		if candidate == null:
			continue
		var dist: float = _distance_to(candidate)
		if dist < best_dist:
			best = candidate
			best_dist = dist
	return best


func _distance_to(node: Node) -> float:
	var body: Node2D = node as Node2D
	if body == null:
		return INF
	return host.global_position.distance_to(body.global_position)


func _find_ground_pickup_target() -> Node:
	var best: Node = null
	var best_dist: float = SpyBase.PROBE_RADIUS
	if host.nearby_pickup != null and is_instance_valid(host.nearby_pickup):
		var cached_dist: float = _distance_to(host.nearby_pickup)
		if cached_dist <= SpyBase.PROBE_RADIUS:
			best = host.nearby_pickup
			best_dist = cached_dist
	if host.current_room == null:
		return best
	for child: Node in host.current_room.get_children():
		if not child.is_in_group("ground_pickup"):
			continue
		var dist: float = _distance_to(child)
		if dist <= best_dist:
			best = child
			best_dist = dist
	return best
