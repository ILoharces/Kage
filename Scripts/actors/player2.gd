extends Player
class_name Player2

# Jugador local 2 (espia negro): flechas + I/O/K/L.


func _ready() -> void:
	super._ready()
	add_to_group("player2")


func get_aim_controller_spy_id() -> int:
	return ItemDB.SpyId.PLAYER2


func _get_fire_action() -> String:
	return "p2_fire_weapon"


func _compute_input_vector() -> Vector2:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return Vector2.ZERO
	return Input.get_vector("p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down", 0.16)


func _get_interact_action() -> String:
	return "p2_interact"


func _get_place_trap_action() -> String:
	return "p2_place_trap"


func _get_next_trap_action() -> String:
	return "p2_next_trap"
