extends CanvasLayer
class_name Hud

# HUD estilo Spy vs Spy (NES): panel derecho con TIME, vida e inventario; centro reservado.

const STATS_PAD: float = 8.0

var player_panel: SpyHudPanel
var ai_panel: SpyHudPanel
var controls_guide: ControlsGuide
var message_panel: PanelContainer
var message_label: Label
var bound_player: Player = null
var bound_opponent: SpyBase = null
var _message_tween: Tween = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud_root")
	_build_ui()
	GameState.time_changed.connect(_on_time_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.weapons_changed.connect(_on_weapons_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.exit_reached.connect(_on_exit_reached)
	GameState.item_blocked_no_suitcase.connect(_on_item_blocked)
	GameState.suitcase_dropped.connect(_on_suitcase_state_changed)
	GameState.suitcase_recovered.connect(_on_suitcase_recovered)
	GameState.suitcase_stolen.connect(_on_suitcase_stolen)
	_on_time_changed(ItemDB.SpyId.PLAYER1, GameState.get_time_left(ItemDB.SpyId.PLAYER1))
	_on_time_changed(ItemDB.SpyId.PLAYER2, GameState.get_time_left(ItemDB.SpyId.PLAYER2))
	player_panel.update_inventory(null)
	ai_panel.update_inventory(null)
	relayout_for_display()


func relayout_for_display() -> void:
	var metrics: LayoutMetrics = DisplayConfig.get_metrics() as LayoutMetrics
	var stats_rect: Rect2 = metrics.stats_panel_rect()
	var stats_left: float = stats_rect.position.x + STATS_PAD
	var stats_w: float = stats_rect.size.x - STATS_PAD * 2.0
	var mid_y: float = metrics.mid_y
	var central: Rect2 = metrics.central_panel_rect()
	var guide_pad: float = STATS_PAD
	controls_guide.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controls_guide.position = central.position + Vector2(guide_pad, guide_pad)
	controls_guide.size = central.size - Vector2(guide_pad * 2.0, guide_pad * 2.0)
	controls_guide.refresh()
	player_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_panel.position = Vector2(stats_left, 0.0)
	player_panel.size = Vector2(stats_w, mid_y)
	ai_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ai_panel.position = Vector2(stats_left, mid_y)
	ai_panel.size = Vector2(stats_w, metrics.screen_size.y - mid_y)
	if message_panel != null:
		var game: Rect2 = metrics.game_column_rect()
		var toast_w: float = minf(game.size.x - 48.0, 520.0)
		var toast_h: float = 58.0
		message_panel.position = Vector2(
			game.position.x + (game.size.x - toast_w) * 0.5,
			mid_y - toast_h - 18.0
		)
		message_panel.size = Vector2(toast_w, toast_h)


func bind_player(player: Player) -> void:
	_disconnect_spy_ui(bound_player, _on_player_weapon_changed, _on_player_held_changed)
	bound_player = player
	_connect_health_bar(player, _on_player_health_changed)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.held_changed.connect(_on_player_held_changed)
	player.reset_held_for_match()
	player_panel.refresh_identity()
	player_panel.update_inventory(player)
	player_panel.update_ammo(null, &"")
	_refresh_ammo_displays()
	controls_guide.refresh()


func bind_world(mansion: Mansion) -> void:
	if mansion == null:
		return
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy == null:
		return
	_disconnect_spy_ui(bound_opponent, _on_opponent_weapon_changed, _on_opponent_held_changed)
	bound_opponent = bottom_spy
	_connect_health_bar(bottom_spy, _on_ai_health_changed)
	bottom_spy.weapon_changed.connect(_on_opponent_weapon_changed)
	bottom_spy.held_changed.connect(_on_opponent_held_changed)
	ai_panel.refresh_identity()
	ai_panel.update_health(bottom_spy.health, SpyBase.MAX_HEALTH)
	ai_panel.update_inventory(bottom_spy)
	ai_panel.update_ammo(null, &"")
	_refresh_ammo_displays()
	controls_guide.refresh()


func _build_ui() -> void:
	player_panel = SpyHudPanel.new()
	player_panel.name = "PlayerStats"
	player_panel.setup(ItemDB.SpyId.PLAYER1, true)
	player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_panel)
	ai_panel = SpyHudPanel.new()
	ai_panel.name = "AiStats"
	ai_panel.setup(ItemDB.SpyId.PLAYER2, false)
	ai_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ai_panel)
	controls_guide = ControlsGuide.new()
	controls_guide.name = "ControlsGuide"
	add_child(controls_guide)
	message_panel = PanelContainer.new()
	message_panel.name = "FlashMessage"
	message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_panel.modulate = Color(1, 1, 1, 0)
	var toast_style: StyleBoxFlat = NesUiTheme.panel_style()
	toast_style.content_margin_left = 16.0
	toast_style.content_margin_right = 16.0
	toast_style.content_margin_top = 8.0
	toast_style.content_margin_bottom = 8.0
	message_panel.add_theme_stylebox_override("panel", toast_style)
	add_child(message_panel)
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_font_override("font", NesUiTheme.ui_font())
	message_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.text = ""
	message_panel.add_child(message_label)


func _disconnect_spy_ui(spy: SpyBase, weapon_callback: Callable, held_callback: Callable) -> void:
	if spy == null or not is_instance_valid(spy):
		return
	if spy.weapon_changed.is_connected(weapon_callback):
		spy.weapon_changed.disconnect(weapon_callback)
	if spy.held_changed.is_connected(held_callback):
		spy.held_changed.disconnect(held_callback)


func _connect_health_bar(spy: SpyBase, callback: Callable) -> void:
	if spy.health_changed.is_connected(callback):
		spy.health_changed.disconnect(callback)
	spy.health_changed.connect(callback)
	callback.call(spy.health, SpyBase.MAX_HEALTH)


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_panel.update_health(current, maximum)


func _on_ai_health_changed(current: float, maximum: float) -> void:
	ai_panel.update_health(current, maximum)


func _on_time_changed(spy_id: int, value: float) -> void:
	var clamped: float = maxf(0.0, value)
	var minutes: int = int(clamped) / 60
	var seconds: int = int(clamped) % 60
	var text: String = "%02d:%02d" % [minutes, seconds]
	if spy_id == ItemDB.SpyId.PLAYER1:
		player_panel.set_time_text(text, NesUiTheme.timer_color(clamped))
	elif spy_id == ItemDB.SpyId.PLAYER2:
		ai_panel.set_time_text(text, NesUiTheme.timer_color(clamped))


func _on_inventory_changed(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER1:
		player_panel.update_inventory(bound_player)
	else:
		ai_panel.update_inventory(bound_opponent)


func _on_weapons_changed(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER1:
		player_panel.update_ammo(bound_player, _get_equipped_weapon_id(bound_player))
	else:
		ai_panel.update_ammo(bound_opponent, _get_equipped_weapon_id(bound_opponent))


func _on_player_weapon_changed(weapon_id: StringName) -> void:
	player_panel.update_ammo(bound_player, weapon_id)


func _on_opponent_weapon_changed(weapon_id: StringName) -> void:
	ai_panel.update_ammo(bound_opponent, weapon_id)


func _on_player_held_changed(_kind: int, _held_id: int) -> void:
	player_panel.update_hands(bound_player)
	player_panel.update_inventory(bound_player)


func _on_opponent_held_changed(_kind: int, _held_id: int) -> void:
	ai_panel.update_hands(bound_opponent)
	ai_panel.update_inventory(bound_opponent)


func _refresh_ammo_displays() -> void:
	player_panel.update_ammo(bound_player, _get_equipped_weapon_id(bound_player))
	ai_panel.update_ammo(bound_opponent, _get_equipped_weapon_id(bound_opponent))


func _get_equipped_weapon_id(spy: SpyBase) -> StringName:
	if spy == null or spy.held == null or not spy.held.is_holding_weapon():
		return &""
	return spy.held.get_weapon_id()


func _on_game_over(_winner_id: int) -> void:
	var copy: Dictionary = _build_flash_copy(_winner_id)
	flash_message(copy.get("message", "GAME OVER") as String)


func _build_flash_copy(winner_id: int) -> Dictionary:
	if winner_id == GameState.WINNER_TIMEOUT:
		return {"message": "TIEMPO"}
	match GameState.match_end_reason:
		GameState.MatchEndReason.ESCAPE:
			return {"message": _escape_flash(winner_id)}
		GameState.MatchEndReason.TRAP:
			return {"message": "TRAMPA"}
		GameState.MatchEndReason.WEAPON:
			return {"message": "ELIMINADO"}
		GameState.MatchEndReason.TIMEOUT:
			return {"message": "TIEMPO"}
	if winner_id == ItemDB.SpyId.PLAYER1:
		return {"message": "VICTORIA" if GameState.use_ai else "BLANCO GANA"}
	if winner_id == ItemDB.SpyId.PLAYER2:
		return {"message": "DERROTA" if GameState.use_ai else "NEGRO GANA"}
	return {"message": "FIN"}


func _escape_flash(winner_id: int) -> String:
	if GameState.use_ai and winner_id == ItemDB.SpyId.PLAYER1:
		return "HAS ESCAPADO"
	if GameState.use_ai and winner_id == ItemDB.SpyId.PLAYER2:
		return "EL RIVAL ESCAPA"
	if winner_id == ItemDB.SpyId.PLAYER1:
		return "BLANCO ESCAPA"
	if winner_id == ItemDB.SpyId.PLAYER2:
		return "NEGRO ESCAPA"
	return "ESCAPA"


func _on_exit_reached(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER1:
		flash_message("Te faltan objetos para escapar")


func _on_item_blocked(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER1:
		flash_message("Primero necesitas el maletín")


func _on_suitcase_state_changed(spy_id: int) -> void:
	_on_inventory_changed(spy_id)
	if spy_id == ItemDB.SpyId.PLAYER1:
		flash_message("Has soltado lo que llevabas")


func _on_suitcase_recovered(spy_id: int) -> void:
	_on_inventory_changed(spy_id)
	if spy_id == ItemDB.SpyId.PLAYER1:
		player_panel.blink_inventory()
		flash_message("Maletín recuperado")


func _on_suitcase_stolen(thief_id: int, victim_id: int) -> void:
	_on_inventory_changed(thief_id)
	_on_inventory_changed(victim_id)
	if thief_id == ItemDB.SpyId.PLAYER1:
		flash_message("Has robado el maletín")
	elif victim_id == ItemDB.SpyId.PLAYER1:
		flash_message("Te han robado el maletín")


func flash_message(text: String) -> void:
	if message_panel == null or message_label == null:
		return
	message_label.text = text
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message_panel.modulate = Color.WHITE
	_message_tween = create_tween()
	_message_tween.tween_interval(1.15)
	_message_tween.tween_property(message_panel, "modulate:a", 0.0, 0.7)


func set_room_label(room: Room) -> void:
	if room == null:
		player_panel.set_room_text("")
		return
	var gp: Vector2i = room.grid_pos
	player_panel.set_room_text("Sala %d · %d" % [gp.x, gp.y])
