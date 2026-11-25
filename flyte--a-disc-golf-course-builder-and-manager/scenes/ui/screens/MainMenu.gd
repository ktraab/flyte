extends Control

var _update_btn: Button = null

func on_screen_entered(_params: Dictionary = {}) -> void:
	if _update_btn == null:
		_update_btn = Button.new()
		_update_btn.name = "UpdateBanner"
		_update_btn.custom_minimum_size = Vector2(0, 40)
		_update_btn.pressed.connect(func() -> void: UpdateChecker.open_download())
		var vbox := find_child("VBox", true, false)
		if vbox:
			vbox.add_child(_update_btn)
		UpdateChecker.status_changed.connect(func(_s: String) -> void: _sync_update_banner())
	_sync_update_banner()

## "Update available" button under Quit — only when a newer release exists.
func _sync_update_banner() -> void:
	if _update_btn == null:
		return
	_update_btn.visible = UpdateChecker.status == "available"
	_update_btn.text = "⬇ Update available: v%s" % UpdateChecker.latest_version

func on_screen_exited() -> void:
	pass

func _on_start_pressed() -> void:
	GameManager.change_state(GameManager.GameState.GAMEPLAY)

func _on_settings_pressed() -> void:
	EventBus.screen_push_requested.emit("Settings", {})

func _on_quit_pressed() -> void:
	EventBus.game_quit_requested.emit()
