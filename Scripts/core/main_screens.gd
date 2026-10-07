class_name MainScreens
extends RefCounted

# Menús, flujo de partida, pausa y entrada global.

var main: Main = null
var _current_layout: LevelLayout = null
var _settings_from_pause: bool = false
var _editor_from_play: bool = false


func _init(p_main: Main) -> void:
	main = p_main


func connect_menus() -> void:
	main.main_menu.play_pressed.connect(func() -> void: _switch_menu(main.main_menu, main.play_menu))
	main.main_menu.create_map_pressed.connect(open_map_editor)
	main.main_menu.tutorial_pressed.connect(open_tutorial)
	main.main_menu.settings_pressed.connect(func() -> void: open_settings(false))
	main.main_menu.quit_pressed.connect(func() -> void: main.get_tree().quit())
	main.settings_menu.back_requested.connect(on_settings_back)
	main.play_menu.back_requested.connect(func() -> void: _switch_menu(main.play_menu, main.main_menu))
	main.play_menu.map_selected.connect(on_map_confirmed)
	main.play_menu.edit_requested.connect(open_map_editor)
	main.play_menu.create_map_requested.connect(func() -> void: open_map_editor())
	main.map_editor.map_confirmed.connect(on_map_confirmed)
	main.map_editor.editor_closed.connect(on_editor_closed)
	main.escape_menu.resume_pressed.connect(on_escape_resume)
	main.escape_menu.restart_pressed.connect(restart_match)
	main.escape_menu.settings_pressed.connect(func() -> void: open_settings(true))
	main.escape_menu.exit_pressed.connect(return_to_main_menu)
	main.game_over.rematch_pressed.connect(restart_match)
	main.game_over.choose_map_pressed.connect(func() -> void: return_to_main_menu(main.play_menu))
	main.game_over.menu_pressed.connect(return_to_main_menu)
	main.tutorial_overlay.finished.connect(_on_tutorial_finished)
	main.trapulator.toggled.connect(on_trapulator_toggled)
	main.mansion.player_room_changed.connect(main.hud.set_room_label)
	GameState.map_overlay_close_requested.connect(main.close_map_overlay)


func show_start_screen() -> void:
	if GameSettings.has_completed_tutorial():
		main.main_menu.show_menu()
	else:
		main.tutorial_overlay.show_tutorial()


func _switch_menu(from: MenuScreen, to: MenuScreen) -> void:
	from.hide_menu()
	to.show_menu()


# --- Menús --------------------------------------------------------------------

func open_map_editor(map_id: String = "") -> void:
	_editor_from_play = main.play_menu.visible or not map_id.is_empty()
	main.main_menu.hide_menu()
	main.play_menu.hide_menu()
	main.map_editor.show_editor(map_id)


func on_editor_closed() -> void:
	main.map_editor.hide_editor()
	if _editor_from_play:
		main.play_menu.show_menu()
	else:
		main.main_menu.show_menu()
	_editor_from_play = false


func open_tutorial() -> void:
	main.main_menu.hide_menu()
	main.tutorial_overlay.show_tutorial()


func _on_tutorial_finished() -> void:
	if not main._game_started:
		main.main_menu.show_menu()


func open_settings(from_pause: bool) -> void:
	_settings_from_pause = from_pause
	if from_pause:
		main.escape_menu.hide_menu()
	else:
		main.main_menu.hide_menu()
	main.settings_menu.show_menu()


func on_settings_back() -> void:
	main.settings_menu.hide_menu()
	if _settings_from_pause and main._game_started:
		main.escape_menu.show_menu()
	else:
		main.main_menu.show_menu()
	_settings_from_pause = false


# --- Partida ------------------------------------------------------------------

func set_game_ui_visible(visible_flag: bool) -> void:
	main.game_root.visible = visible_flag
	if main.hud != null:
		main.hud.visible = visible_flag
	if main.trapulator != null:
		if not visible_flag:
			main.trapulator.close()
		else:
			main.trapulator.visible = main.trapulator.is_open
	if main.trap_wheel != null and not visible_flag:
		main.trap_wheel.close_cancel()


func on_map_confirmed(layout: LevelLayout) -> void:
	_current_layout = layout
	main._game_started = true
	for screen: MenuScreen in [main.escape_menu, main.main_menu, main.settings_menu, main.play_menu, main.game_over]:
		screen.hide_menu()
	main.map_editor.hide_editor()
	main.escape_menu.set_map_name(layout.source_name)
	GameState.reset_match()
	InputBindings.set_ai_adaptive_controls(GameState.use_ai)
	InputBindings.apply_all()
	main.close_map_overlay()
	if main.trapulator.is_open:
		main.trapulator.close()
	set_game_ui_visible(true)
	main._layout_helper.apply_layout()
	main.mansion.begin_with_layout(layout)
	main.ai_viewport.world_2d = main.player_viewport.world_2d
	main._layout_helper.setup_cameras()
	bind_ui()
	main.setup_combat_aim()
	main._layout_helper.snap_cameras()
	main.call_deferred("_refresh_viewport_layout")


func restart_match() -> void:
	if _current_layout == null:
		return_to_main_menu()
		return
	var layout: LevelLayout = _current_layout
	_end_match()
	on_map_confirmed(layout)


func bind_ui() -> void:
	if main.mansion.player != null:
		main.hud.bind_player(main.mansion.player)
		main.trapulator.bind_player(main.mansion.player)
	if main.mansion.player2 != null:
		main.mansion.player2.reset_held_for_match()
		main.trapulator.bind_player2(main.mansion.player2)
	else:
		if main.mansion.ai_spy != null:
			main.mansion.ai_spy.reset_held_for_match()
		main.trapulator.bind_player2(null)
	main.hud.bind_world(main.mansion)
	if main._map_panel != null:
		main._map_panel.bind_mansion(main.mansion)
	if main.mansion.player != null and main.mansion.player.current_room != null:
		main.hud.set_room_label(main.mansion.player.current_room)


func on_trapulator_toggled(open: bool) -> void:
	if open and main._map_open:
		main.trapulator.close()
		return
	update_player_input_block()


func update_player_input_block() -> void:
	if main.mansion == null:
		return
	var blocked: bool = (
		main._map_open or main.trapulator.is_open or main.escape_menu.is_visible_menu()
	)
	if main.mansion.player != null:
		main.mansion.player.set_input_blocked(blocked)
	if main.mansion.player2 != null:
		main.mansion.player2.set_input_blocked(blocked)


func toggle_map_overlay() -> void:
	main._map_open = not main._map_open
	GameState.map_overlay_open = main._map_open
	if main._map_overlay != null:
		main._map_overlay.visible = main._map_open
	if main._map_open:
		if main.trapulator.is_open:
			main.trapulator.close()
		if main._map_panel != null:
			main._map_panel.bind_mansion(main.mansion)
	update_player_input_block()


func handle_unhandled_input(event: InputEvent) -> void:
	if not main._game_started or not GameState.running:
		return
	if main.game_over.visible:
		return
	if event.is_action_pressed("toggle_map") or event.is_action_pressed("p2_toggle_map"):
		toggle_map_overlay()
		main.get_viewport().set_input_as_handled()
		return
	if main._map_open:
		if event.is_action_pressed("ui_cancel"):
			toggle_map_overlay()
			main.get_viewport().set_input_as_handled()
		return
	if main.trapulator.is_open:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("p2_pause_menu"):
		open_escape_menu()
		main.get_viewport().set_input_as_handled()


# --- Pausa --------------------------------------------------------------------

func open_escape_menu() -> void:
	if main.escape_menu.is_visible_menu():
		return
	main._was_running_before_pause = GameState.running
	GameState.running = false
	if main.trapulator.is_open:
		main.trapulator.close()
	if main._map_open:
		toggle_map_overlay()
	if main.trap_wheel != null:
		main.trap_wheel.close_cancel()
	update_player_input_block()
	main.escape_menu.show_menu()


func on_escape_resume() -> void:
	main.escape_menu.hide_menu()
	if not main._game_started:
		return
	if main._was_running_before_pause:
		GameState.running = true
	update_player_input_block()


func return_to_main_menu(destination: MenuScreen = null) -> void:
	_end_match()
	_current_layout = null
	GameSettings.apply_to_match_defaults()
	if destination == null:
		destination = main.main_menu
	destination.show_menu()


func _end_match() -> void:
	main._game_started = false
	GameState.running = false
	main.escape_menu.hide_menu()
	main.game_over.hide_menu()
	InputBindings.set_ai_adaptive_controls(false)
	GameState.map_overlay_open = false
	main._map_open = false
	if main._map_overlay != null:
		main._map_overlay.visible = false
	if main.trapulator.is_open:
		main.trapulator.close()
	if main.hud != null:
		main.hud.unbind()
	if main.trapulator != null:
		main.trapulator.unbind()
	main.teardown_combat_aim()
	main.mansion.shutdown()
	set_game_ui_visible(false)
	update_player_input_block()
