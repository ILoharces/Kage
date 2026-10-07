extends Node

# Ajustes persistentes del juego. Anade nuevas opciones en _DEFINITIONS y propiedades
# tipadas debajo; el menu de ajustes se genera automaticamente a partir de ellas.

signal setting_changed(option_id: String, value: Variant)
signal control_modes_changed

const SETTINGS_PATH: String = "user://game_settings.cfg"
const TRAP_WHEEL_SCALE_MIN: float = 0.6
const TRAP_WHEEL_SCALE_MAX: float = 1.8
const TRAP_WHEEL_SCALE_DEFAULT: float = 1.0
const MASTER_VOLUME_DEFAULT: float = 0.8

const _DEFINITIONS: Array[Dictionary] = [
	{
		"section_id": "gameplay",
		"title": "Partida",
		"options": [
			{
				"id": "use_ai_default",
				"label": "Jugar contra la IA por defecto",
				"type": "bool",
				"default": true,
				"hint": "Se recuerda la última elección al elegir mapa.",
			},
		],
	},
	{
		"section_id": "audio",
		"title": "Sonido",
		"options": [
			{
				"id": "master_volume",
				"label": "Volumen general",
				"type": "float",
				"min": 0.0,
				"max": 1.0,
				"step": 0.05,
				"default": MASTER_VOLUME_DEFAULT,
			},
		],
	},
	{
		"section_id": "interface",
		"title": "Pantalla e interfaz",
		"options": [
			{
				"id": "fullscreen",
				"label": "Pantalla completa",
				"type": "bool",
				"default": true,
			},
			{
				"id": "show_controls_guide",
				"label": "Mostrar la guía de controles en partida",
				"type": "bool",
				"default": true,
				"hint": "Columna central con los botones de cada jugador.",
			},
			{
				"id": "trap_wheel_scale",
				"label": "Tamaño de la rueda de trampas",
				"type": "float",
				"min": TRAP_WHEEL_SCALE_MIN,
				"max": TRAP_WHEEL_SCALE_MAX,
				"step": 0.05,
				"default": TRAP_WHEEL_SCALE_DEFAULT,
			},
		],
	},
]

var use_ai_default: bool = true
var master_volume: float = MASTER_VOLUME_DEFAULT
var fullscreen: bool = true
var show_controls_guide: bool = true
var trap_wheel_scale: float = TRAP_WHEEL_SCALE_DEFAULT
var p1_control_mode: int = 0
var p2_control_mode: int = 2
var p1_gamepad_aim_mode: int = 0
var p2_gamepad_aim_mode: int = 0
var tutorial_completed: bool = false

var _values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_properties_to_values()
	load_settings()
	apply_to_match_defaults()


func get_sections() -> Array[Dictionary]:
	return _DEFINITIONS.duplicate(true)


func get_option_value(option_id: String) -> Variant:
	return _values.get(option_id)


func set_option_value(option_id: String, value: Variant) -> void:
	if not _values.has(option_id):
		push_warning("[GameSettings] Opcion desconocida: %s" % option_id)
		return
	if _values[option_id] == value:
		return
	_values[option_id] = value
	_apply_value_to_property(option_id, value)
	save_settings()
	setting_changed.emit(option_id, value)


func set_p1_control_mode(mode: int) -> void:
	if p1_control_mode == mode:
		return
	p1_control_mode = mode
	save_settings()
	control_modes_changed.emit()


func set_p2_control_mode(mode: int) -> void:
	if p2_control_mode == mode:
		return
	p2_control_mode = mode
	save_settings()
	control_modes_changed.emit()


func get_gamepad_aim_mode(player_index: int) -> int:
	if player_index <= 0:
		return clampi(p1_gamepad_aim_mode, 0, 1)
	return clampi(p2_gamepad_aim_mode, 0, 1)


func has_completed_tutorial() -> bool:
	return tutorial_completed


func mark_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	save_settings()


func set_gamepad_aim_mode(player_index: int, mode: int) -> void:
	var clamped: int = clampi(mode, 0, 1)
	if player_index <= 0:
		if p1_gamepad_aim_mode == clamped:
			return
		p1_gamepad_aim_mode = clamped
	else:
		if p2_gamepad_aim_mode == clamped:
			return
		p2_gamepad_aim_mode = clamped
	save_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[GameSettings] No se pudo cargar ajustes: %s" % error_string(err))
	for section: Dictionary in _DEFINITIONS:
		var section_id: String = String(section.get("section_id", ""))
		var options: Array = section.get("options", []) as Array
		for option: Variant in options:
			var entry: Dictionary = option as Dictionary
			var option_id: String = String(entry.get("id", ""))
			if option_id.is_empty():
				continue
			var default_value: Variant = _default_for_option(entry)
			var stored: Variant = default_value
			if err == OK:
				stored = config.get_value(section_id, option_id, default_value)
			_values[option_id] = stored
	if err == OK:
		p1_control_mode = int(config.get_value("controls", "p1_control_mode", 0))
		p2_control_mode = int(config.get_value("controls", "p2_control_mode", 2))
		p1_gamepad_aim_mode = int(config.get_value("controls", "p1_gamepad_aim_mode", 0))
		p2_gamepad_aim_mode = int(config.get_value("controls", "p2_gamepad_aim_mode", 0))
		tutorial_completed = bool(config.get_value("meta", "tutorial_completed", false))
	_sync_values_to_properties()


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for section: Dictionary in _DEFINITIONS:
		var section_id: String = String(section.get("section_id", ""))
		var options: Array = section.get("options", []) as Array
		for option: Variant in options:
			var entry: Dictionary = option as Dictionary
			var option_id: String = String(entry.get("id", ""))
			if option_id.is_empty() or not _values.has(option_id):
				continue
			config.set_value(section_id, option_id, _values[option_id])
	config.set_value("controls", "p1_control_mode", p1_control_mode)
	config.set_value("controls", "p2_control_mode", p2_control_mode)
	config.set_value("controls", "p1_gamepad_aim_mode", p1_gamepad_aim_mode)
	config.set_value("controls", "p2_gamepad_aim_mode", p2_gamepad_aim_mode)
	config.set_value("meta", "tutorial_completed", tutorial_completed)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[GameSettings] No se pudo guardar ajustes: %s" % error_string(err))


func apply_to_match_defaults() -> void:
	GameState.use_ai = use_ai_default


## Cada opción de _DEFINITIONS tiene una propiedad homónima en este autoload.
func _sync_properties_to_values() -> void:
	for entry: Dictionary in _all_options():
		var option_id: String = String(entry.get("id", ""))
		_values[option_id] = get(option_id)


func _sync_values_to_properties() -> void:
	for entry: Dictionary in _all_options():
		var option_id: String = String(entry.get("id", ""))
		_apply_value_to_property(option_id, _values.get(option_id, _default_for_option(entry)))


func _apply_value_to_property(option_id: String, value: Variant) -> void:
	var entry: Dictionary = _find_option(option_id)
	match String(entry.get("type", "")):
		"bool":
			set(option_id, bool(value))
		"float":
			set(option_id, clampf(float(value), float(entry.get("min", 0.0)), float(entry.get("max", 1.0))))
	match option_id:
		"master_volume":
			_apply_audio()
		"fullscreen":
			_apply_window_mode()


func _all_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section: Dictionary in _DEFINITIONS:
		for option: Variant in section.get("options", []) as Array:
			out.append(option as Dictionary)
	return out


func _find_option(option_id: String) -> Dictionary:
	for entry: Dictionary in _all_options():
		if String(entry.get("id", "")) == option_id:
			return entry
	return {}


func _apply_audio() -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fullscreen: bool = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if fullscreen and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif not fullscreen and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _default_for_option(entry: Dictionary) -> Variant:
	match String(entry.get("type", "")):
		"bool":
			return bool(entry.get("default", false))
		"float":
			return float(entry.get("default", 0.0))
		_:
			return entry.get("default", null)
