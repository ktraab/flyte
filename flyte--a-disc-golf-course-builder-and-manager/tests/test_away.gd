## Away rounds (STORY.md Ch4): play a circuit course's front nine, then go home
## with your own course, economy and save untouched.
extends "res://tests/TestCase.gd"

const AwayLayouts = preload("res://core/data/AwayLayouts.gd")

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	if gm().is_away_round():
		gm().end_away_round([], [])
	await frames(1)

func test_every_circuit_course_has_a_valid_front_nine() -> void:
	for cid in ["maple_ridge", "winthrop_gold", "idlewild", "disc_side_of_heaven", "krokhol", "ale_white"]:
		var tiles: Dictionary = gm().call("_preset_tiles", cid)
		check(not tiles.is_empty(), "%s preset builds" % cid)
		var holes: Array = AwayLayouts.resolve(cid, tiles)
		check_eq(holes.size(), AwayLayouts.HOLES_PER_ROUND, "%s has a front nine" % cid)
		var seen := {}
		for i in holes.size():
			for cell in holes[i]:
				var c: Vector2i = cell
				check(c.x >= 0 and c.x < 150 and c.y >= 0 and c.y < 150, "%s H%d cell %s on the map" % [cid, i + 1, c])
				check(not seen.has(c), "%s H%d cell %s not shared with another hole" % [cid, i + 1, c])
				seen[c] = true
				var tt: int = int(tiles.get(c, 0))
				check(tt != 3 and tt != 5, "%s H%d %s sits on playable ground (tile %d)" % [cid, i + 1, c, tt])
			var tee: Vector2i = holes[i][0]
			var bk: Vector2i = holes[i][1]
			check(Vector2(tee).distance_to(Vector2(bk)) * 2.0 >= 15.0, "%s H%d is a real hole" % [cid, i + 1])

func test_away_round_restores_home_and_freezes_economy() -> void:
	var w: Node = gm().world
	var home_holes: int = (w.get_holes_info() as Array).size()
	var home_tiles: int = (w.get("_tiles") as Dictionary).size()
	var bal: float = tree.root.get_node("EconomyManager").get("balance")
	var day: int = tree.root.get_node("EconomyManager").get("current_day")

	check(gm().start_away_round("maple_ridge"), "away round starts")
	await frames(3)
	check(gm().is_away_round(), "away flag set")
	check_eq((w.get_holes_info() as Array).size(), 9, "visited course has 9 holes")
	check(not bool(w.get("_gameplay_mode")), "no NPC traffic on the visited course")

	# Economy frozen while away
	await advance_economy(70.0)
	check_eq(tree.root.get_node("EconomyManager").get("current_day"), day, "no days pass while away")
	check_eq(float(tree.root.get_node("EconomyManager").get("balance")), bal, "balance frozen while away")

	# A save mid-round must store the real home course, not the visited one
	gm().call("_save_active_course")
	var snap: Dictionary = (gm().get("_course_snapshots") as Dictionary)["home"]
	check_eq((snap["tiles"] as Dictionary).size(), home_tiles, "save during away round keeps home tiles")

	# Gameplay drops straight into the round with the away title
	var gp: Node = ui().get("_cache")["Gameplay"]
	var pt: Node = gp.get("_play_test")
	check(pt != null and is_instance_valid(pt), "play controls opened for the away round")
	if pt:
		check_eq(pt.get("away_course_name"), "Maple Hill", "away title names the course")

	var got := []
	var cb := func(cid: String, strokes: int, par: int) -> void: got.append([cid, strokes, par])
	bus().away_round_completed.connect(cb)
	var pars: Array = []
	for h in w.get_holes_info():
		pars.append(h["par"])
	var scores: Array = pars.duplicate()
	scores[0] = int(scores[0]) + 1
	if pt:
		pt.set("_scores", scores)
		pt.call("_exit_test")      # "Head Home"
	else:
		gm().end_away_round(scores, pars)
	await frames(3)
	bus().away_round_completed.disconnect(cb)

	check(not gm().is_away_round(), "home again")
	check_eq((w.get_holes_info() as Array).size(), home_holes, "home holes restored")
	check_eq((w.get("_tiles") as Dictionary).size(), home_tiles, "home tiles restored")
	check(bool(w.get("_gameplay_mode")), "home NPC traffic back on")
	check_eq(got.size(), 1, "away_round_completed emitted once")
	check_eq(gm().get_away_best("maple_ridge"), 1, "best score recorded (+1)")

func test_abandoned_away_round_goes_home_without_credit() -> void:
	var w: Node = gm().world
	var home_holes: int = (w.get_holes_info() as Array).size()
	story().deserialize({"chapter": 4, "beats": {}})
	gm().start_away_round("krokhol")
	await frames(2)
	await goto_state(gm().GameState.COURSE_BUILDER)   # leave mid-round
	check(not gm().is_away_round(), "leaving play ends the away round")
	check_eq((w.get_holes_info() as Array).size(), home_holes, "home holes restored")
	check(not story().is_beat_fired("ch4_first_away"), "no story credit for an unfinished round")
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var gp: Node = ui().get("_cache")["Gameplay"]
	var pt: Node = gp.get("_play_test")
	if pt and is_instance_valid(pt):
		pt.call("_exit_test")
		await frames(2)

func test_away_best_persists() -> void:
	(gm().get("_away_best") as Dictionary)["idlewild"] = -2
	gm().call("_save_course_meta")
	(gm().get("_away_best") as Dictionary).clear()
	gm().call("_load_course_meta")
	check_eq(gm().get_away_best("idlewild"), -2, "best away score survives save/load")
	await quiet_story()

## Circuit presets have no gate; without one no holes are built and no players
## ever arrive (playthrough bot: Maple Hill stuck at 0 players for 50 days).
func test_every_circuit_preset_gets_a_reachable_entrance() -> void:
	for cid in ["maple_ridge", "winthrop_gold", "idlewild", "disc_side_of_heaven", "krokhol", "ale_white"]:
		var w := GameWorld3D.new()
		w.set("_tiles", {})
		var tiles: Dictionary = gm().call("_preset_tiles", cid)
		for c in tiles:
			if int(tiles[c]) not in [6, 7, 8, 12]:
				(w.get("_tiles") as Dictionary)[c] = tiles[c]
		var sizes: PackedInt32Array = (w.call("_walk_components") as Array)[1]
		var largest := 0
		for sz in sizes:
			largest = maxi(largest, sz)
		var need := mini(3000, largest)
		var e: Vector2i = w.call("ensure_entrance")
		check(e.x >= 0, "%s gets an entrance (%s)" % [cid, e])
		if e.x >= 0:
			var reach := 0
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				reach = maxi(reach, int(w.call("_reach_count", e + d, need)))
			check(reach >= need, "%s entrance opens onto the biggest open area (%d of %d cells)" % [cid, reach, need])
			check_eq(w.call("ensure_entrance"), e, "%s: second call keeps the same gate" % cid)
		w.free()

func test_bought_course_gets_players_and_fresh_upkeep() -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	gm().set("_empire_balance", 100000.0)
	if not gm().call("is_course_owned", "winthrop_gold"):
		check(gm().call("buy_course", "winthrop_gold"), "bought Winthrop Gold")
	else:
		gm().call("switch_to_course", "winthrop_gold")
	await frames(3)
	var w: Node = gm().world
	check(not (w.call("get_tiles_of_type", 8) as Array).is_empty(), "bought course has an entrance")
	check_eq(int(em.get("_hole_count")), (w.call("get_holes_info") as Array).size(), "upkeep counts this course's holes, not home's")
	gm().call("switch_to_course", "home")
	await frames(3)
	await quiet_story()
