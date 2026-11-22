extends Control

func on_screen_entered(_params: Dictionary = {}) -> void:
	pass

func on_screen_exited() -> void:
	pass

func _on_start_pressed() -> void:
	GameManager.change_state(GameManager.GameState.GAMEPLAY)

func _on_settings_pressed() -> void:
	EventBus.screen_push_requested.emit("Settings", {})

func _on_quit_pressed() -> void:
	EventBus.game_quit_requested.emit()
