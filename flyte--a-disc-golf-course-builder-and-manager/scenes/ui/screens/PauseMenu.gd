extends Control

func on_screen_entered(_params: Dictionary = {}) -> void:
	pass

func on_screen_exited() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	# ESC again closes the menu (cached screens stay in the tree — only act while shown).
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	EventBus.game_resumed.emit()

func _on_save_pressed() -> void:
	EventBus.save_requested.emit()
	EventBus.notification_requested.emit("Game saved!", "info")

func _on_settings_pressed() -> void:
	EventBus.screen_push_requested.emit("Settings", {})

func _on_main_menu_pressed() -> void:
	EventBus.save_requested.emit()
	GameManager.change_state(GameManager.GameState.MAIN_MENU)

func _on_quit_pressed() -> void:
	EventBus.game_quit_requested.emit()
