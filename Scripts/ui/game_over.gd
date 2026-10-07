extends MenuScreen
class_name GameOverPanel

# Fin de partida: resultado, resumen de cada espía y revancha / otro mapa / menú.

signal rematch_pressed
signal choose_map_pressed
signal menu_pressed

const INPUT_LOCK_TIME: float = 0.8

var _title: Label = null
var _subtitle: Label = null
var _summary: Label = null
var _rematch_button: Button = null
var _menu_button: Button = null
var _buttons: Array[Control] = []
var _lock_left: float = 0.0


func _ready() -> void:
	layer = 31
	super._ready()
	GameState.game_over.connect(_on_game_over)


func _build() -> void:
	UiKit.dim_backdrop(root, 0.55)
	var content: VBoxContainer = UiKit.centered_panel(root, Vector2(560, 0), 14)
	_title = UiKit.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_title)
	_subtitle = UiKit.wrapped_label("", &"", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_subtitle)
	content.add_child(HSeparator.new())
	_summary = UiKit.wrapped_label("", &"HintLabel", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_summary)
	content.add_child(UiKit.spacer(8.0))
	var actions: HBoxContainer = UiKit.hbox(12, BoxContainer.ALIGNMENT_CENTER)
	content.add_child(actions)
	_rematch_button = _add_button(actions, "Revancha", &"PrimaryButton", rematch_pressed)
	_add_button(actions, "Otro mapa", &"", choose_map_pressed)
	_menu_button = _add_button(actions, "Menú principal", &"", menu_pressed)
	UiKit.chain_focus(_buttons, true)


func _add_button(parent: Container, text: String, variation: StringName, pressed_signal: Signal) -> Button:
	var btn: Button = UiKit.button(text, variation, 160.0)
	btn.pressed.connect(
		func() -> void:
			hide_menu()
			pressed_signal.emit()
	)
	parent.add_child(btn)
	_buttons.append(btn)
	return btn


func _process(delta: float) -> void:
	if _lock_left <= 0.0:
		return
	_lock_left -= delta
	if _lock_left <= 0.0:
		_set_buttons_enabled(true)
		_rematch_button.grab_focus()


func _set_buttons_enabled(enabled: bool) -> void:
	for control: Control in _buttons:
		(control as Button).disabled = not enabled


func _initial_focus() -> Control:
	return null


func _on_cancel() -> void:
	if _lock_left <= 0.0:
		_menu_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _lock_left <= 0.0 and event.is_action_pressed("restart"):
		hide_menu()
		rematch_pressed.emit()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


# --- Contenido ----------------------------------------------------------------

func _on_game_over(winner_id: int) -> void:
	var copy: Dictionary = _build_end_copy(winner_id)
	_title.text = String(copy.get("title", "FIN"))
	_title.add_theme_color_override("font_color", copy.get("color", NesUiTheme.COLOR_TEXT) as Color)
	_subtitle.text = String(copy.get("subtitle", ""))
	_summary.text = "%s\n%s" % [_spy_summary(ItemDB.SpyId.PLAYER1), _spy_summary(ItemDB.SpyId.PLAYER2)]
	_set_buttons_enabled(false)
	_lock_left = INPUT_LOCK_TIME
	show_menu()


func _spy_summary(spy_id: int) -> String:
	var time_left: float = maxf(GameState.get_time_left(spy_id), 0.0)
	var loot: int = GameState.get_items(spy_id).size()
	return "%s  ·  botín %d/%d  ·  reloj %02d:%02d" % [
		_spy_label(spy_id), loot, ItemDB.get_all_items().size(), int(time_left) / 60, int(time_left) % 60,
	]


func _build_end_copy(winner_id: int) -> Dictionary:
	if winner_id == GameState.WINNER_TIMEOUT:
		return {"title": "TIEMPO AGOTADO", "subtitle": "Nadie escapó a tiempo."}
	var winner_name: String = _spy_label(winner_id)
	var loser_name: String = _spy_label(_loser_id(winner_id))
	var title: String = "%s GANA" % winner_name.to_upper()
	var color: Color = NesUiTheme.COLOR_TEXT
	if GameState.use_ai:
		var won: bool = winner_id == ItemDB.SpyId.PLAYER1
		title = "VICTORIA" if won else "DERROTA"
		color = NesUiTheme.COLOR_TIMER_WARN if won else NesUiTheme.COLOR_TIMER_DANGER
	var subtitle: String = ""
	match GameState.match_end_reason:
		GameState.MatchEndReason.ESCAPE:
			subtitle = "%s escapó con todo el botín." % winner_name
		GameState.MatchEndReason.TRAP:
			subtitle = "%s cayó en una trampa." % loser_name
		GameState.MatchEndReason.WEAPON:
			var weapon_name: String = WeaponDB.get_weapon_name(GameState.elimination_weapon_id)
			subtitle = "%s fue eliminado con %s." % [loser_name, weapon_name if not weapon_name.is_empty() else "un arma"]
		GameState.MatchEndReason.TIMEOUT:
			subtitle = "%s se quedó sin tiempo." % loser_name
	return {"title": title, "subtitle": subtitle, "color": color}


func _spy_label(spy_id: int) -> String:
	if spy_id == ItemDB.SpyId.PLAYER1:
		return "Blanco (tú)" if GameState.use_ai else "Blanco"
	if spy_id == ItemDB.SpyId.PLAYER2:
		return "Negro (IA)" if GameState.use_ai else "Negro"
	return "?"


func _loser_id(winner_id: int) -> int:
	return ItemDB.SpyId.PLAYER2 if winner_id == ItemDB.SpyId.PLAYER1 else ItemDB.SpyId.PLAYER1
