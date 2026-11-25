## Menus scroll (the wheel used to be swallowed while any overlay was open, so
## e.g. the Concessions Worker hire button was unreachable) + update checker.
extends "res://tests/TestCase.gd"

func _uc() -> Node:
	return tree.root.get_node("UpdateChecker")

func _wheel(at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	ev.position = at
	ev.global_position = at
	tree.root.push_input(ev, true)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	tree.root.push_input(up, true)
	await frames(3)

func test_staff_panel_scrolls_and_map_does_not_zoom() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var gp: Node = ui().get("_cache")["Gameplay"]
	gp.call("_on_staff_pressed")
	await frames(5)
	var scroll := gp.find_child("StaffScroll", true, false) as ScrollContainer
	check(scroll != null, "staff scroll exists")
	if scroll == null:
		return
	var cam: Node = gm().world.get_node("CourseCamera3D")
	var zoom_before: float = cam.get("_target_size")
	scroll.scroll_vertical = 0
	await _wheel(scroll.get_global_rect().get_center())
	check(scroll.scroll_vertical > 0, "mouse wheel scrolls the Staff panel")
	cam.call("_process", 0.016)
	check_eq(float(cam.get("_target_size")), zoom_before, "map doesn't zoom while scrolling a menu")
	gp.call("_on_staff_close_pressed")
	await frames(2)

func test_concessions_can_be_hired() -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	em.set("balance", maxf(float(em.get("balance")), 5000.0))
	var before: int = em.get_staff_count(2)
	if before >= int(em.STAFF_HIRE_LIMIT[2]):
		em.fire_staff(2)
		before -= 1
	check(em.hire_staff(2), "concessions worker hired")
	check_eq(em.get_staff_count(2), before + 1, "count went up")
	em.fire_staff(2)

func test_builder_bottom_bar_fits_on_screen() -> void:
	await goto_state(gm().GameState.COURSE_BUILDER)
	await frames(3)
	var bar := (ui().get("_cache")["CourseBuilder"] as Node).find_child("BottomBar", true, false) as Control
	check(bar != null, "bottom bar exists")
	if bar:
		check(bar.get_global_rect().end.y <= tree.root.get_visible_rect().end.y + 1.0, "bottom bar not clipped")
	await goto_state(gm().GameState.GAMEPLAY)

func test_version_compare() -> void:
	var U = _uc().get_script()
	check(U.is_newer("v1.1.0", "1.0.0"), "1.1.0 > 1.0.0")
	check(U.is_newer("1.0.1", "1.0"), "1.0.1 > 1.0")
	check(U.is_newer("2.0", "1.9.9"), "2.0 > 1.9.9")
	check(not U.is_newer("v1.0.0", "1.0.0"), "equal isn't newer")
	check(not U.is_newer("0.9.9", "1.0.0"), "older isn't newer")
	check(not U.is_newer("1.0.0-beta", "1.0.0"), "suffix ignored")
	check(U.current_version() != "0.0.0", "project has a version")

func test_update_status_from_release() -> void:
	var uc := _uc()
	check(uc.get("status") != "checking", "no automatic network check during tests")
	uc.call("apply_release", "v99.0.0", "https://evil.example/download")
	check_eq(uc.get("status"), "available", "newer release → available")
	check_eq(uc.get("latest_version"), "99.0.0", "version parsed")
	check_eq(uc.get("release_url"), uc.RELEASES_PAGE, "foreign URLs never opened")
	uc.call("apply_release", "v0.1.0", "https://github.com/ktraab/flyte/releases/tag/v0.1.0")
	check_eq(uc.get("status"), "up_to_date", "older release → up to date")
	check_eq(uc.get("release_url"), "https://github.com/ktraab/flyte/releases/tag/v0.1.0", "own release URL kept")
	uc.set("status", "idle")
