## StoryManager: sequential chapters, one-at-a-time queue, legacy migration, choices.
extends "res://tests/TestCase.gd"

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await drain_dialogue()
	story().reset()
	_goals().deserialize({})
	_econ().set("_prestige", 0.0)
	gm().owned_courses.assign(["home"])
	await frames(2)
	await drain_dialogue()
	check(not gm().is_paused_for("dialogue"), "setup: no dialogue pause left over")

func _goals() -> Node: return tree.root.get_node("GoalsSystem")
func _econ() -> Node: return tree.root.get_node("EconomyManager")
func _overlay() -> Node: return ui().get("_cache").get("DialogueOverlay")

func _set_prestige(v: float) -> void:
	_econ().set("_prestige", v)
	bus().prestige_changed.emit(v)

## Click through the current overlay; picks the first choice if one is offered.
func _finish_current_beat() -> void:
	var ov := _overlay()
	var id := _showing()
	for i in 20:
		if _showing() != id or id == "":
			return
		var choice_row: HBoxContainer = ov.get("_choice_row")
		if (ov.get("_name_row") as Control).visible:
			ov.call("_confirm_name")
		elif choice_row.visible and choice_row.get_child_count() > 0:
			(choice_row.get_child(0) as Button).pressed.emit()
		else:
			ov.call("_on_next")
		await frames(1)

func _showing() -> String:
	return story().get("_showing") as String

func test_new_game_shows_intro_and_pauses() -> void:
	await goto_state(gm().GameState.MAIN_MENU)
	check_eq(_showing(), "", "nothing shown over main menu")
	await goto_state(gm().GameState.GAMEPLAY)
	await frames(2)
	check_eq(_showing(), "ch0_start", "Ray's letter shows on entering gameplay")
	check(tree.paused, "world paused during dialogue")
	await _finish_current_beat()
	await frames(2)
	check_eq(_showing(), "ch0_name", "name prompt follows the letter")
	await _finish_current_beat()
	await frames(2)
	check_eq(_showing(), "ch0_pan", "camera pans over Ray's holes after the name prompt")
	check(tree.paused, "world stays paused during the pan")
	var cam: Camera3D = gm().world.get_node("CourseCamera3D")
	var tw: Tween = story().get("_pan_tween")
	check(tw != null and tw.is_valid(), "pan tween running")
	story().finish_pan()   # same path as Esc / click
	await frames(2)
	check_eq(cam.get("_target_pos"), cam.position, "camera stays where the pan left it")
	check_eq(_showing(), "ch0_arrival", "arrival beat follows the pan")
	await _finish_current_beat()
	await frames(2)
	check_eq(_showing(), "", "queue empty")
	check(not tree.paused, "unpaused after last beat")
	check_eq(ui().current_screen_name(), "Gameplay", "back on Gameplay")

func test_chapters_never_skip() -> void:
	_set_prestige(60.0)  # already past Regional AND National
	await frames(2)
	check_eq(story().get_chapter(), 0, "prestige alone can't skip Ch1")
	_goals().notify_hole_count(6)
	await frames(2)
	check_eq(story().get_chapter(), 1, "six holes → Ch1; Ch2 waits a day even though Regional is met")
	check(story().is_beat_fired("ch1_start") and not story().is_beat_fired("ch2_start"), "Ch1 beats only")
	bus().day_changed.emit(2, "Spring")
	await frames(2)
	check_eq(story().get_chapter(), 2, "next day → Ch2")
	bus().tournament_completed.emit(100.0)
	await frames(2)
	check_eq(story().get_chapter(), 3, "first tournament → Ch3; Ch4 waits a day")
	bus().day_changed.emit(3, "Spring")
	await frames(2)
	check_eq(story().get_chapter(), 5, "next day → Ch4 (course unlocked) then Ch5 (National met)")
	for b in ["ch3_start", "ch3_newspaper", "ch4_start", "ch5_start"]:
		check(story().is_beat_fired(b), "beat %s not skipped" % b)
	check_eq(story().get_chapter() < 6, true, "Ch6 needs World Class + 5 courses")

func test_world_class_needs_five_courses() -> void:
	story().deserialize({"chapter": 5, "beats": {}})
	_set_prestige(80.0)
	await frames(2)
	check_eq(story().get_chapter(), 5, "World Class prestige alone is not enough")
	var five := ["maple_ridge", "winthrop_gold", "idlewild", "krokhol", "ale_white"]
	gm().owned_courses.assign(["home"] + five)
	bus().day_changed.emit(3, "Spring")
	await frames(2)
	check_eq(story().get_chapter(), 5, "owning 5 courses isn't enough — they must be certified")
	var saved_stats: Dictionary = gm().get("_course_stats").duplicate(true)
	for c in five:
		gm().get("_course_stats")[c] = {"holes": 9, "rating": 3.6, "restrooms": 1}
	bus().day_changed.emit(4, "Spring")
	await frames(2)
	check_eq(story().get_chapter(), 6, "5 certified circuit courses + World Class → Ch6")
	gm().set("_course_stats", saved_stats)

func test_beats_show_one_at_a_time() -> void:
	story().deserialize({"chapter": 1, "beats": {}})
	story().fire_beat("ch2_start")
	story().fire_beat("ch3_start")
	await frames(3)
	var stack: Array = ui().get("_stack")
	var overlays := stack.filter(func(s: Node) -> bool: return s.name == "DialogueOverlay").size()
	check_eq(overlays, 1, "only one overlay on the stack")
	check_eq(_showing(), "ch2_start", "first queued beat shows first")
	await _finish_current_beat()
	await frames(2)
	check_eq(_showing(), "ch3_start", "second beat shows after first closes")
	await _finish_current_beat()

func test_choice_is_recorded() -> void:
	story().deserialize({"chapter": 1, "beats": {}})
	story().fire_beat("ch2_start")
	await frames(3)
	await _finish_current_beat()
	check_eq(story().get_choice("ch2_start"), "Decline", "first choice recorded")

func test_legacy_save_migrates_without_dialogue_flood() -> void:
	_goals().deserialize({"completed": {"six_holes": true, "first_tourney": true}})
	_econ().set("_prestige", 30.0)
	story().mark_legacy_save()
	story().call("_evaluate")
	await frames(3)
	check_eq(story().get_chapter(), 4, "legacy player lands in Ch4")
	check(story().is_circuit_unlocked(), "Circuit unlocked for migrated player")
	check_eq(_showing(), "ch4_start", "only the current chapter's opener is shown")
	check_eq((story().get("_queue") as Array).size(), 0, "no backlog of old beats")
	await _finish_current_beat()

func test_circuit_unlocked_if_player_owns_courses() -> void:
	gm().owned_courses.assign(["home", "maple_ridge"])
	check(story().is_circuit_unlocked(), "owning a 2nd course always shows Circuit")

func test_story_state_round_trips() -> void:
	story().deserialize({"chapter": 2, "beats": {"ch2_start": true}, "choices": {"ch2_start": "Consider It"}, "queue": ["ch2_close"], "days": 3})
	var data: Dictionary = story().serialize()
	story().reset()
	story().deserialize(data)
	check_eq(story().get_chapter(), 2, "chapter")
	check_eq(story().get_choice("ch2_start"), "Consider It", "choice")
	check_eq(story().get("_days_in_chapter"), 3, "days in chapter")
	check(story().is_beat_fired("ch2_start"), "fired beats")
	await frames(3)
	check_eq(_showing(), "ch2_close", "pending queue resumes after load")
	await _finish_current_beat()

func test_escape_still_pauses_after_dialogue() -> void:
	story().deserialize({"chapter": 1, "beats": {}})
	story().fire_beat("ch1_reflection")
	await frames(3)
	await _finish_current_beat()
	await frames(2)
	await press_key("ui_cancel")
	check_eq(ui().current_screen_name(), "PauseMenu", "hidden overlay no longer eats ESC")
	bus().game_resumed.emit()
	await frames(3)

func test_hud_stays_visible_under_dialogue() -> void:
	story().deserialize({"chapter": 1, "beats": {}})
	story().fire_beat("ch1_reflection")
	await frames(3)
	var gp: Control = ui().get("_cache")["Gameplay"]
	check(gp.visible, "Gameplay HUD still visible under the dialogue")
	await press_key("ui_cancel")
	check_eq(_showing(), "", "ESC skipped the dialogue")
	check_eq(gm().state, gm().GameState.GAMEPLAY, "ESC on dialogue did not open pause")

func test_name_prompt_sets_player_name() -> void:
	story().deserialize({"chapter": 0, "beats": {"ch0_start": true, "ch0_arrival": true}})
	await goto_state(gm().GameState.MAIN_MENU)
	await goto_state(gm().GameState.GAMEPLAY)
	await frames(3)
	check_eq(_showing(), "ch0_name", "name prompt follows the letter")
	var ov := _overlay()
	(ov.get("_name_edit") as LineEdit).text = "  Sam [b]K[/b]  "
	ov.call("_confirm_name")
	await frames(2)
	check_eq(story().player_name, "Sam bK/b", "name trimmed and BBCode brackets stripped")
	check_eq(story().format_text("Dear {name},"), "Dear Sam bK/b,", "{name} placeholder filled")
	var data: Dictionary = story().serialize()
	story().reset()
	check_eq(story().player_name, "Coach", "reset → default name")
	story().deserialize(data)
	check_eq(story().player_name, "Sam bK/b", "name persists")
	await drain_dialogue()

func test_name_prompt_offers_male_and_female_look() -> void:
	story().deserialize({"chapter": 0, "beats": {"ch0_start": true, "ch0_arrival": true}})
	await goto_state(gm().GameState.MAIN_MENU)
	await goto_state(gm().GameState.GAMEPLAY)
	await frames(3)
	check_eq(_showing(), "ch0_name", "name prompt up")
	var ov := _overlay()
	check((ov.get("_look_row") as Control).visible, "look picker shown with the name field")
	var btns: Dictionary = ov.get("_look_btns")
	check(btns.has("male") and btns.has("female"), "male and female looks offered")
	check((btns["male"] as Button).button_pressed, "default look pre-selected")
	(btns["female"] as Button).emit_signal("pressed")
	await frames(1)
	check_eq(story().player_look, "female", "picking a look stores it")
	var tex := (ov.get("_portrait_tex") as TextureRect).texture
	check(tex != null and tex.resource_path.ends_with("player_female.svg"), "prompt portrait swaps to the picked look")
	ov.call("_confirm_name")
	await frames(2)
	check(not (ov.get("_look_row") as Control).visible, "picker hidden after confirming")
	check(story().get_portrait("player").ends_with("player_female.svg"), "player portrait follows the look")
	check(story().get_portrait("jess_nakamura").ends_with("jess_nakamura.svg"), "other portraits unchanged")
	var data: Dictionary = story().serialize()
	story().reset()
	check_eq(story().player_look, "male", "reset → default look")
	story().deserialize(data)
	check_eq(story().player_look, "female", "look persists in the save")
	story().set_player_look("robot")
	check_eq(story().player_look, "male", "unknown look falls back to default")
	await drain_dialogue()

func test_empty_name_defaults_to_coach() -> void:
	story().set_player_name("   ")
	check_eq(story().player_name, "Coach", "blank name → Coach")

func test_every_portrait_loads() -> void:
	for cid in story().CHARACTERS:
		var path: String = story().CHARACTERS[cid]["portrait"]
		if path == "":
			continue
		check(ResourceLoader.exists(path), "%s portrait exists" % cid)
		check(load(path) is Texture2D, "%s portrait is a texture" % cid)
	for look in story().PLAYER_LOOKS:
		check(load(story().PLAYER_LOOKS[look]) is Texture2D, "player %s portrait loads" % look)

func test_bench_near_hole_one_after_ch5() -> void:
	var w: Node = gm().world
	var holes: Array = w.get_holes_info()
	if holes.is_empty():
		check(false, "need holes")
		return
	var tee: Vector2i = holes[0]["tee_cell"]
	var cell := tee + Vector2i(2, 0)
	var old: int = int(w.get("_tiles").get(cell, 0))
	w.get("_tiles")[cell] = 20  # BENCH
	story().deserialize({"chapter": 4, "beats": {}})
	bus().tile_placed.emit(20)
	check(not story().is_beat_fired("ch5_bench"), "no bench moment before Ch5")
	story().deserialize({"chapter": 5, "beats": {}})
	bus().tile_placed.emit(20)
	check(story().is_beat_fired("ch5_bench"), "bench near Hole 1 after Ch5 → Diana toast")
	w.get("_tiles")[cell] = old
	await drain_dialogue()

func test_final_card_plays_ambient_only() -> void:
	story().deserialize({"chapter": 6, "beats": {}})
	story().fire_beat("ch6_card")
	await frames(3)
	var ga: Node = tree.root.get_node("GameAudio")
	check(ga.get("_duck_tween") != null, "music fade started under memorial card")
	check(ga.call("is_ambient_only"), "ambient bed on under memorial card")
	var amb: AudioStreamPlayer = ga.get("_ambient_player")
	check(amb != null and amb.stream != null, "wind/nature loop loaded")
	if amb and amb.stream is AudioStreamWAV:
		check_eq((amb.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "ambient loop imported as looping")
	await _finish_current_beat()
	await frames(2)
	check(not ga.call("is_ambient_only"), "ambient off and music back after the card")

func test_first_tournament_toast_series() -> void:
	story().deserialize({"chapter": 3, "beats": {}})
	bus().tournament_started.emit()
	check(story().is_beat_fired("ch3_tourney_day"), "sign-up toast on first tournament")
	bus().round_completed.emit("npc_1", false, 10.0, 6)
	check(story().is_beat_fired("ch3_tourney_busy"), "Hole 6 backing up toast mid-tournament")
	bus().tournament_completed.emit(1000.0)
	check(story().is_beat_fired("ch3_tourney_done"), "closing toast when it ends")
	await drain_dialogue()

func test_diana_sponsors_one_tournament_after_ch5() -> void:
	story().deserialize({"chapter": 4, "beats": {}})
	var before: float = _econ().get("balance")
	bus().tournament_completed.emit(2000.0)
	check(not story().is_beat_fired("ch5_sponsor"), "no sponsor before Diana's visit")
	story().deserialize({"chapter": 5, "beats": {"ch5_diana": true}})
	before = _econ().get("balance")
	bus().tournament_completed.emit(2000.0)
	check(story().is_beat_fired("ch5_sponsor"), "Cross Pines sponsorship toast")
	check(float(_econ().get("balance")) - before >= story().SPONSOR_MIN - 0.01, "sponsor money paid")
	var after: float = _econ().get("balance")
	bus().tournament_completed.emit(2000.0)
	check_eq(float(_econ().get("balance")), after, "sponsor only once")
	await drain_dialogue()

func test_regular_asks_about_rays_bag() -> void:
	var w: Node = gm().world
	var has_gate: bool = not (w.get_tiles_of_type(8) as Array).is_empty()
	story().deserialize({"chapter": 1, "beats": {}})
	bus().round_completed.emit("npc_1", false, 10.0, 3)
	check(not story().is_beat_fired("side_disc_bag"), "not in Ch1")
	story().deserialize({"chapter": 2, "beats": {}})
	bus().round_completed.emit("npc_2", true, 10.0, 3)
	check(not story().is_beat_fired("side_disc_bag"), "VIPs don't ask")
	bus().round_completed.emit("npc_3", false, 10.0, 3)
	check_eq(story().is_beat_fired("side_disc_bag"), has_gate, "a regular asks about the bag (gate present: %s)" % has_gate)
	if has_gate:
		await frames(2)
		check_eq(_showing(), "side_disc_bag", "bag dialogue shows")
		await _finish_current_beat()
		check_eq(story().get_choice("side_disc_bag"), "It belongs there.", "player answers")
	await drain_dialogue()

func test_home_gate_carries_rays_bag() -> void:
	var props: GDScript = load("res://scenes/game_world/PropFactory.gd")
	var g: Node = props.make_gate(true)
	check(g.find_child("RayDiscBag", false, false) != null, "home gate has Ray's bag")
	g.free()
	var g2: Node = props.make_gate()
	check(g2.find_child("RayDiscBag", false, false) == null, "other gates don't")
	g2.free()

func test_pro_shop_upgrade_mentions_rays_shed() -> void:
	story().deserialize({"chapter": 2, "beats": {}})
	bus().facility_upgraded.emit("restroom", 2)
	check(not story().is_beat_fired("side_shed"), "only the pro shop")
	bus().facility_upgraded.emit("pro_shop", 2)
	check(story().is_beat_fired("side_shed"), "shed flavor toast on pro shop upgrade")
	await drain_dialogue()

func test_dani_epilogue_after_final_card() -> void:
	story().deserialize({"chapter": 6, "beats": {"ch6_ranking": true, "ch6_start": true}})
	bus().day_changed.emit(100, "Summer")
	check(not story().is_beat_fired("ch6_dani"), "not before the final card")
	story().deserialize({"chapter": 6, "beats": {"ch6_ranking": true, "ch6_start": true, "ch6_card": true}})
	bus().day_changed.emit(101, "Summer")
	check(story().is_beat_fired("ch6_dani"), "Dani's world-rankings piece the next day")
	await drain_dialogue()

func test_first_away_beat_needs_an_away_round() -> void:
	story().deserialize({"chapter": 4, "beats": {}})
	bus().course_purchased.emit("maple_ridge")
	check(not story().is_beat_fired("ch4_first_away"), "buying a course isn't an away round")
	bus().away_round_completed.emit("maple_ridge", 30, 27)
	check(story().is_beat_fired("ch4_first_away"), "reflection after the first away round")
	await drain_dialogue()

## Loading story state while a beat is on screen must release the dialogue
## pause (it used to stay on with nothing showing: frozen world).
func test_loading_story_mid_dialogue_unfreezes() -> void:
	story().call("reset")
	story().fire_beat("ch1_start")
	await frames(3)
	check(gm().is_paused_for("dialogue"), "a beat is showing and pauses the world")
	story().deserialize({"chapter": 6, "beats": {}})
	await frames(3)
	check(not gm().is_paused_for("dialogue"), "loading story state releases the dialogue pause")
	check(ui().current_screen_name() != "DialogueOverlay", "and closes the stale overlay")
	await quiet_story()
