extends SpyBase
class_name AiSpy

# Spy controlado por una IA simple basada en estados. Pide rutas al Mansion
# para decidir hacia que puerta caminar y registra muebles ya revisados.

enum State { SEARCH, RETURN, PLACE_TRAP }

const FURNITURE_REACH: float = 72.0
const DOOR_REACH: float = 48.0
const TRAP_PLACE_CHANCE: float = 0.35
const TRAP_PLACE_COOLDOWN: float = 5.0
## Probabilidad de equipar una contramedida al azar antes de registrar un mueble con las manos libres.
const COUNTER_GUESS_CHANCE: float = 0.3

var mansion: Mansion = null
var ai_state: int = State.SEARCH
var target_room: Room = null
var target_furniture: Furniture = null
var visited_furniture: Dictionary = {}
var rooms_visited: Dictionary = {}
var decision_timer: float = 0.0
var input_vector: Vector2 = Vector2.ZERO
var place_trap_cooldown: float = 0.0


func _ready() -> void:
	spy_id = ItemDB.SpyId.PLAYER2
	super._ready()
	add_to_group("ai_spy")
	search_finished.connect(_on_search_finished)


func _on_search_finished(furniture: Furniture) -> void:
	if furniture != null and is_instance_valid(furniture):
		visited_furniture[furniture.get_instance_id()] = true
	target_furniture = null


func set_mansion(m: Mansion) -> void:
	mansion = m


func _compute_input_vector() -> Vector2:
	return input_vector


func _physics_process(delta: float) -> void:
	if is_alive and GameState.running:
		_ai_tick(delta)
	else:
		input_vector = Vector2.ZERO
	super._physics_process(delta)


func _ai_tick(delta: float) -> void:
	decision_timer = maxf(0.0, decision_timer - delta)
	place_trap_cooldown = maxf(0.0, place_trap_cooldown - delta)
	if current_room == null or mansion == null or not can_act():
		input_vector = Vector2.ZERO
		return
	_react_to_timed_trap()
	if decision_timer <= 0.0:
		_choose_state()
		decision_timer = randf_range(0.5, 1.2)
	input_vector = _execute_state()


func _choose_state() -> void:
	if GameState.has_all_items(spy_id):
		ai_state = State.RETURN
		target_room = mansion.get_exit_room()
		return
	if place_trap_cooldown <= 0.0 and _pick_trap_to_place() != -1 and randf() < TRAP_PLACE_CHANCE:
		ai_state = State.PLACE_TRAP
		return
	ai_state = State.SEARCH


func _execute_state() -> Vector2:
	match ai_state:
		State.RETURN:
			return _navigate_step()
		State.PLACE_TRAP:
			return _place_trap_step()
		_:
			return _search_step()


# --- Búsqueda -----------------------------------------------------------------

func _search_step() -> Vector2:
	if target_room == null:
		target_room = mansion.pick_next_search_room(self)
	if current_room != target_room:
		return _navigate_step()
	if not _is_valid_search_target(target_furniture):
		target_furniture = _pick_unvisited_furniture()
	if target_furniture == null:
		rooms_visited[current_room.get_instance_id()] = true
		target_room = mansion.pick_next_search_room(self)
		return Vector2.ZERO
	var to_furn: Vector2 = target_furniture.global_position - global_position
	if to_furn.length() > FURNITURE_REACH:
		return to_furn.normalized()
	_maybe_guess_counter()
	interaction.use_furniture(target_furniture)
	return Vector2.ZERO


func _is_valid_search_target(furn: Furniture) -> bool:
	return (
		furn != null
		and is_instance_valid(furn)
		and furn.owning_room == current_room
		and not visited_furniture.has(furn.get_instance_id())
	)


func _pick_unvisited_furniture() -> Furniture:
	var candidates: Array[Furniture] = []
	for furn_node: Node in current_room.furniture_list:
		var furn: Furniture = furn_node as Furniture
		if _is_valid_search_target(furn):
			candidates.append(furn)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


# --- Contramedidas ------------------------------------------------------------

## La IA no sabe qué mueble está trampeado: a veces se arriesga a adivinar.
func _maybe_guess_counter() -> void:
	if held == null or held.is_holding_carried() or held.is_holding_weapon():
		return
	if randf() >= COUNTER_GUESS_CHANCE:
		return
	var options: Array[int] = []
	for trap_id: int in ItemDB.get_all_traps():
		if ItemDB.is_furniture_trap(trap_id):
			options.append(ItemDB.get_counter_for_trap(trap_id))
	if not options.is_empty():
		equip_counter(options[randi() % options.size()])


func _react_to_timed_trap() -> void:
	if not current_room.is_timed_trap_counting() or held == null:
		return
	if held.is_holding_carried() or held.is_holding_weapon():
		return
	equip_counter(ItemDB.get_counter_for_trap(ItemDB.TrapId.TIMED))


# --- Navegación ---------------------------------------------------------------

func _navigate_step() -> Vector2:
	if target_room == null:
		return Vector2.ZERO
	if current_room == target_room:
		if current_room != mansion.get_exit_room():
			return Vector2.ZERO
		var exit_dir: String = mansion.get_exit_door_direction()
		if exit_dir.is_empty():
			return Vector2.ZERO
		return _walk_to_door(exit_dir)
	var dir: String = mansion.next_direction(current_room, target_room)
	if dir.is_empty():
		return Vector2.ZERO
	return _walk_to_door(dir)


func _walk_to_door(dir: String) -> Vector2:
	var to_door: Vector2 = current_room.get_door_world_pos(dir) - global_position
	if to_door.length() > DOOR_REACH:
		return to_door.normalized()
	var door: Door = current_room.get_door_for_direction(dir)
	if door != null and door.is_closed():
		door.try_open_for_spy(self)
		return Vector2.ZERO
	return to_door.normalized() * 0.6


# --- Colocar trampas ----------------------------------------------------------

func _place_trap_step() -> Vector2:
	var trap_id: int = _pick_trap_to_place()
	var target_node: Node2D = _pick_trap_target_for(trap_id) if trap_id >= 0 else null
	if target_node == null:
		ai_state = State.SEARCH
		return Vector2.ZERO
	var to_target: Vector2 = target_node.global_position - global_position
	if to_target.length() > FURNITURE_REACH:
		return to_target.normalized()
	if ItemDB.is_door_trap(trap_id):
		nearby_door = target_node as Door
	else:
		var furn: Furniture = target_node as Furniture
		if not furn.is_raised_open():
			interaction.use_furniture(furn)
		nearby_furniture = furn
	if try_place_trap(trap_id):
		place_trap_cooldown = TRAP_PLACE_COOLDOWN
	ai_state = State.SEARCH
	return Vector2.ZERO


func _pick_trap_to_place() -> int:
	var available: Array[int] = []
	for trap_id: int in ItemDB.get_all_traps():
		if GameState.get_trap_count(spy_id, trap_id) <= 0:
			continue
		if _pick_trap_target_for(trap_id) != null:
			available.append(trap_id)
	if available.is_empty():
		return -1
	return available[randi() % available.size()]


func _pick_trap_target_for(trap_id: int) -> Node2D:
	match ItemDB.get_trap_site(trap_id):
		ItemDB.TrapSite.DOOR:
			return _pick_bucket_door()
		ItemDB.TrapSite.FURNITURE:
			return _pick_furniture_for_trap()
	return null


func _pick_furniture_for_trap() -> Furniture:
	for furn_node: Node in current_room.furniture_list:
		var furn: Furniture = furn_node as Furniture
		if furn != null and furn.is_empty() and visited_furniture.has(furn.get_instance_id()):
			return furn
	return null


func _pick_bucket_door() -> Door:
	for door: Door in current_room.door_list:
		if door.is_closed() and not door.has_bucket() and not door.is_exit_door:
			return door
	return null
