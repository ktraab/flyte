## Pause menu: opening, actually freezing the sim, and resuming cleanly.
extends "res://tests/TestCase.gd"

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()

func test_escape_opens_pause_menu() -> void:
	await press_key("ui_cancel")
	check_eq(gm().state, gm().GameState.PAUSED, "ESC enters PAUSED")
	check_eq(ui().current_screen_name(), "PauseMenu", "PauseMenu on top")
	bus().game_resumed.emit()
	await frames(3)

func test_pause_freezes_simulation() -> void:
	await press_key("ui_cancel")
	check(tree.paused, "scene tree paused while PauseMenu open")
	bus().game_resumed.emit()
	await frames(3)
	check(not tree.paused, "scene tree unpaused after resume")

func test_resume_closes_pause_menu() -> void:
	await press_key("ui_cancel")
	bus().game_resumed.emit()
	await frames(3)
	check_eq(gm().state, gm().GameState.GAMEPLAY, "state back to GAMEPLAY")
	check_eq(ui().current_screen_name(), "Gameplay", "PauseMenu popped after Resume")

func test_pause_twice_does_not_stack_menus() -> void:
	await press_key("ui_cancel")
	bus().game_resumed.emit()
	await frames(3)
	await press_key("ui_cancel")
	check_eq(ui().get("_stack").size(), 2, "stack is [Gameplay, PauseMenu]")
	bus().game_resumed.emit()
	await frames(3)

func test_pause_to_main_menu_unpauses() -> void:
	await press_key("ui_cancel")
	await goto_state(gm().GameState.MAIN_MENU)
	check(not tree.paused, "tree not left paused on main menu")
	check_eq(ui().current_screen_name(), "MainMenu", "MainMenu shown")
