class_name TrapRules
extends RefCounted

# Punto único donde se resuelve una trampa al saltar.
# Si la víctima lleva en la mano la contramedida correcta, la desactiva; si no, sufre el efecto.


## Salta la trampa sobre el espía. Devuelve true si le afecta, false si la desactiva.
static func trigger(spy: SpyBase, trap_id: int, effect_origin: Vector2 = Vector2.ZERO) -> bool:
	if spy == null or not spy.is_alive:
		return false
	if try_disarm(spy, trap_id):
		return false
	spy.apply_trap_effect(trap_id, effect_origin)
	return true


## Desactiva la trampa si el espía lleva su contramedida. Gasta una del stock.
static func try_disarm(spy: SpyBase, trap_id: int) -> bool:
	if not holds_counter_for(spy, trap_id):
		return false
	var counter_id: int = ItemDB.get_counter_for_trap(trap_id)
	GameState.consume_counter(spy.spy_id, counter_id)
	if GameState.get_counter_count(spy.spy_id, counter_id) <= 0:
		spy.release_tool_selection()
	GameState.notify_human(
		spy.spy_id,
		"%s desactivada con %s" % [ItemDB.get_trap_name(trap_id), ItemDB.get_counter_name(counter_id)]
	)
	Sfx.play_trap_disarmed()
	return true


static func holds_counter_for(spy: SpyBase, trap_id: int) -> bool:
	if spy == null or spy.held == null or not spy.is_alive:
		return false
	var counter_id: int = ItemDB.get_counter_for_trap(trap_id)
	return counter_id >= 0 and spy.held.get_counter_id() == counter_id
