extends SceneTree

# Regenera resources/ui/kage_theme.tres desde UiThemeBuilder.
# Uso: godot --headless --path . --script res://tools/build_ui_theme.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(UiThemeBuilder.OUTPUT_PATH.get_base_dir())
	var err: Error = ResourceSaver.save(UiThemeBuilder.build(), UiThemeBuilder.OUTPUT_PATH)
	if err != OK:
		push_error("No se pudo guardar el tema: %s" % error_string(err))
	else:
		print("Tema guardado en %s" % UiThemeBuilder.OUTPUT_PATH)
	quit(0 if err == OK else 1)
