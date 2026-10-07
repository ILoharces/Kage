class_name TrapStock
extends RefCounted

# Trampas y contramedidas que le quedan a cada espía.
# Con traps_infinite / counters_infinite en MatchConfig nunca se agotan.

const INFINITE_COUNT: int = 99

var _config: MatchConfig = null
var _traps: Dictionary = {}
var _counters: Dictionary = {}


func reset(config: MatchConfig, spy_ids: Array[int]) -> void:
	_config = config
	_traps.clear()
	_counters.clear()
	for spy_id: int in spy_ids:
		_traps[spy_id] = _filled(ItemDB.get_all_traps(), config.starting_traps_per_kind)
		_counters[spy_id] = _filled(ItemDB.get_all_counters(), config.starting_counters_per_kind)


func clear_spy(spy_id: int) -> void:
	_traps[spy_id] = _filled(ItemDB.get_all_traps(), 0)
	_counters[spy_id] = _filled(ItemDB.get_all_counters(), 0)


func traps_infinite() -> bool:
	return _config != null and _config.traps_infinite


func counters_infinite() -> bool:
	return _config != null and _config.counters_infinite


func get_trap_count(spy_id: int, trap_id: int) -> int:
	if traps_infinite():
		return INFINITE_COUNT
	return _count(_traps, spy_id, trap_id)


func consume_trap(spy_id: int, trap_id: int) -> bool:
	if traps_infinite():
		return true
	return _take(_traps, spy_id, trap_id)


func add_trap(spy_id: int, trap_id: int, amount: int = 1) -> void:
	_add(_traps, spy_id, trap_id, amount)


func get_counter_count(spy_id: int, counter_id: int) -> int:
	if counters_infinite():
		return INFINITE_COUNT
	return _count(_counters, spy_id, counter_id)


func consume_counter(spy_id: int, counter_id: int) -> bool:
	if counters_infinite():
		return true
	return _take(_counters, spy_id, counter_id)


func add_counter(spy_id: int, counter_id: int, amount: int = 1) -> void:
	_add(_counters, spy_id, counter_id, amount)


func _filled(ids: Array[int], amount: int) -> Dictionary:
	var out: Dictionary = {}
	for id: int in ids:
		out[id] = maxi(amount, 0)
	return out


func _count(table: Dictionary, spy_id: int, key: int) -> int:
	var per_spy: Dictionary = table.get(spy_id, {}) as Dictionary
	return int(per_spy.get(key, 0))


func _take(table: Dictionary, spy_id: int, key: int) -> bool:
	var per_spy: Dictionary = table.get(spy_id, {}) as Dictionary
	var current: int = int(per_spy.get(key, 0))
	if current <= 0:
		return false
	per_spy[key] = current - 1
	table[spy_id] = per_spy
	return true


func _add(table: Dictionary, spy_id: int, key: int, amount: int) -> void:
	var per_spy: Dictionary = table.get(spy_id, {}) as Dictionary
	per_spy[key] = maxi(int(per_spy.get(key, 0)) + amount, 0)
	table[spy_id] = per_spy
