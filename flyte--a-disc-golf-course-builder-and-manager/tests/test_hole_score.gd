## HoleScore: one design-for-par scorer (spec 2026-11-21-hole-scoring-design).
extends "res://tests/TestCase.gd"

const HoleScore = preload("res://core/simulation/HoleScore.gd")

func test_par_for_length_thresholds() -> void:
	check_eq(HoleScore.par_for_length(60.0), 3, "60 m → par 3")
	check_eq(HoleScore.par_for_length(100.0), 3, "100 m → par 3")
	check_eq(HoleScore.par_for_length(101.0), 4, "101 m → par 4")
	check_eq(HoleScore.par_for_length(170.0), 4, "170 m → par 4")
	check_eq(HoleScore.par_for_length(200.0), 5, "200 m → par 5")

func test_length_score_bands() -> void:
	check(is_equal_approx(HoleScore.length_score(70.0, 3), 1.0), "70 m par 3 is ideal")
	check(is_equal_approx(HoleScore.length_score(200.0, 5), 1.0), "200 m par 5 is ideal")
	check(HoleScore.length_score(150.0, 3) < 0.6, "150 m is too long for par 3 (%.2f)" % HoleScore.length_score(150.0, 3))
	check(HoleScore.length_score(30.0, 3) <= 0.4, "under 35 m caps at 0.4")
	check(HoleScore.length_score(400.0, 3) >= 0.2, "never below 0.2")

# ── Synthetic worlds ──────────────────────────────────────────────────────────

func _world() -> GameWorld3D:
	var w := GameWorld3D.new()
	var t := {}
	for c in 150:
		for r in 150:
			t[Vector2i(c, r)] = 0
	w.set("_tiles", t)
	return w

func _put(w: GameWorld3D, cell: Vector2i, tt: int) -> void:
	(w.get("_tiles") as Dictionary)[cell] = tt

func _hole(w: GameWorld3D, num: int) -> Dictionary:
	for h in w.get_holes_info():
		if int(h["hole_num"]) == num:
			return h
	return {}

## Straight 35-cell (70 m) par 3 along +x at row 50, with full fairway, 2 hazard
## types, framing trees + rough. shape decides straight vs dogleg.
func _built_par3(w: GameWorld3D, dogleg: bool) -> Dictionary:
	var tee := Vector2i(20, 50)
	var bk := Vector2i(55, 50) if not dogleg else Vector2i(45, 65)
	w.call("_place_hole", 1, tee, 1, bk)
	if dogleg:
		(w.get("_hole_waypoints") as Dictionary)[1] = [Vector2i(45, 50)]
	var line: Array = HoleScore.hole_line(_hole(w, 1), w)
	var on_line: Array = []
	for i in line.size() - 1:
		var a: Vector2i = line[i]
		var b: Vector2i = line[i + 1]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for k in range(0, steps + 1):
			on_line.append(Vector2i(roundi(lerpf(a.x, b.x, float(k) / steps)), roundi(lerpf(a.y, b.y, float(k) / steps))))
	for c in on_line:                                          # fairway on the line first…
		if int((w.get("_tiles") as Dictionary)[c]) == 0:
			_put(w, c, 1)
	for c in on_line:                                          # …then rough edge + framing trees
		for side in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]:
			if int((w.get("_tiles") as Dictionary).get(c + side, -1)) == 0:
				_put(w, c + side, 4)
		for side in [Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 0), Vector2i(-4, 0)]:
			if int((w.get("_tiles") as Dictionary).get(c + side, -1)) == 0:
				_put(w, c + side, 5)
	for i in 6:
		_put(w, Vector2i(30 + i, 53), 3)                       # water
	for i in 4:
		_put(w, Vector2i(38 + i, 47), 13)                      # sand
	return _hole(w, 1)

func test_built_par3_with_dogleg_scores_near_five() -> void:
	var w := _world()
	var r: Dictionary = HoleScore.score(_built_par3(w, true), w)
	check(float(r["stars"]) >= 4.9, "fully built dogleg par 3 ≥ 4.9★ (got %.2f, parts %s)" % [r["stars"], r["parts"]])
	w.free()

func test_straight_hole_caps_at_four_and_a_half() -> void:
	var w := _world()
	var r: Dictionary = HoleScore.score(_built_par3(w, false), w)
	check(absf(float((r["parts"] as Dictionary)["shape"]) - 0.5) < 0.001, "straight hole shape = 0.5")
	check(float(r["stars"]) <= 4.5 + 0.001, "straight hole never above 4.5★ (got %.2f)" % r["stars"])
	check(float(r["stars"]) >= 4.3, "but a well-built straight hole is close to it (got %.2f)" % r["stars"])
	w.free()

func test_one_hazard_type_caps_challenge() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(55, 50))
	for i in 30:
		_put(w, Vector2i(22 + i, 52), 3)                       # lots of water, nothing else
	var r: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float((r["parts"] as Dictionary)["challenge"]) - 0.6) < 0.001, "one hazard type maxes at 0.6")
	w.free()

func test_bare_hole_scores_low_with_tips() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(48, 50))
	var r: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(float(r["stars"]) < 2.0, "bare straight 56 m hole is weak (got %.2f)" % r["stars"])
	check((r["tips"] as Array).size() >= 3, "tips explain what's missing: %s" % str(r["tips"]))
	w.free()

func test_fairness_penalties() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(55, 50))
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_put(w, Vector2i(55, 50) + d, 5)                       # basket boxed on 3 sides
	var boxed: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float(boxed["penalty"]) - 0.5) < 0.001, "boxed-in basket penalised 0.5")
	_put(w, Vector2i(54, 50), 5)                               # now fully walled off
	var walled: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float(walled["penalty"]) - 1.0) < 0.001, "unreachable basket penalised 1.0 (cap)")
	w.free()

func _fake_holes(pars: Array, dists: Array) -> Array:
	var out: Array = []
	for i in pars.size():
		out.append({"hole_num": i + 1, "par": pars[i], "distance": dists[i]})
	return out

func test_course_bonus_variety_and_amenities() -> void:
	var nine_same := _fake_holes([3, 3, 3, 3, 3, 3, 3, 3, 3], [60, 60, 60, 60, 60, 60, 60, 60, 60])
	var none: Dictionary = HoleScore.course_bonus(nine_same, {"restroom": 0, "food_stand": 0}, 0)
	check(is_equal_approx(float(none["total"]), 0.0), "identical holes, no amenities → no bonus")
	var mixed := _fake_holes([3, 4, 5, 3, 4, 3, 3, 4, 5], [60, 130, 200, 70, 140, 80, 55, 150, 210])
	var full: Dictionary = HoleScore.course_bonus(mixed, {"restroom": 3, "food_stand": 1}, 5)
	check(is_equal_approx(float(full["variety"]), 0.15), "3 pars + 40 m spread → +0.15 variety")
	check(is_equal_approx(float(full["amenities"]), 0.15), "restrooms + food + decor → +0.15")
	check(is_equal_approx(float(full["total"]), 0.30), "max bonus 0.30")
	var small := _fake_holes([3, 4, 5], [60, 130, 200])
	check(is_equal_approx(float(HoleScore.course_bonus(small, {"restroom": 1, "food_stand": 1}, 9)["total"]), 0.0), "under 6 holes → no bonus")
	# 4.6★ holes + full bonus reach the 4.8 goal
	check(4.6 + float(full["total"]) >= 4.8, "great course with bonuses reaches the 5★ goal")

func test_world_uses_hole_score_and_course_bonus() -> void:
	var w := _world()
	var h := _built_par3(w, true)
	check(is_equal_approx(w.get_hole_rating(h), float(HoleScore.score(h, w)["stars"])), "world rating = HoleScore stars")
	var per: Array = w.get_per_hole_breakdown()
	check(per.size() == 1 and (per[0] as Dictionary).has("parts") and (per[0] as Dictionary).has("tips"), "breakdown carries parts + tips")
	var rb: Dictionary = w.get_rating_breakdown()
	check(rb.has("bonus") and rb.has("variety") and rb.has("amenities"), "rating breakdown reports the course bonus")
	# Editing route waypoints must invalidate the cached rating (layout key).
	var before := w.get_course_rating()
	(w.get("_hole_waypoints") as Dictionary).erase(1)
	check(w.get_course_rating() != before, "waypoint change re-scores (%.2f → %.2f)" % [before, w.get_course_rating()])
	w.free()

func test_par_auto_suggested_from_length() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(90, 50))   # 140 m
	w.call("_auto_par", 1)
	check_eq(int(_hole(w, 1)["par"]), 4, "140 m hole gets par 4")
	w.call("set_hole_par", Vector2i(20, 50), 3)
	check_eq(int(_hole(w, 1)["par"]), 3, "player override sticks")
	_put(w, Vector2i(90, 50), 0)                                      # basket moved further: 180 m
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(110, 50))
	w.call("_auto_par", 1)
	check_eq(int(_hole(w, 1)["par"]), 5, "moving the basket re-suggests par")
	w.free()

func test_paint_at_calls_auto_par() -> void:
	var src := (load("res://scenes/game_world/GameWorld3D.gd") as GDScript).source_code
	check(src.contains("_auto_par(_active_hole_num)"), "_paint_at re-suggests par when a tee/basket is placed")

func test_architect_critique_matches_stars() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var holes: Array = gm().world.get_holes_info()
	check(holes.size() > 0, "home course has holes")
	var h: Dictionary = holes[0]
	var crit: Dictionary = preload("res://core/simulation/HoleCritique.gd").critique(h)
	var stars: float = gm().world.get_hole_rating(h)
	check_eq(int(crit["score"]), roundi(stars * 20.0), "Architect score = stars × 20")
	check((crit["critiques"] as Array).size() >= 5, "one line per part")

func test_five_star_goal_at_four_point_eight() -> void:
	var goals: Node = tree.root.get_node("GoalsSystem")
	for g in goals.call("get_all_goals"):
		if g["id"] == "five_star":
			check(is_equal_approx(float(g["target"]), 4.8), "5★ goal triggers at 4.8")

func test_certification_is_permanent() -> void:
	var stats: Dictionary = gm().get("_course_stats")
	var owned: Array = gm().get("owned_courses")
	owned.append("cert_test")
	stats["cert_test"] = {"holes": 9, "rating": 4.0, "restrooms": 1}
	gm().call("_record_course_stats", "cert_test")
	check(gm().call("is_course_certified", "cert_test"), "meets the bar → certified")
	stats["cert_test"] = {"holes": 9, "rating": 2.0, "restrooms": 1}
	check(gm().call("is_course_certified", "cert_test"), "rating drop doesn't revoke it")
	owned.erase("cert_test")
	stats.erase("cert_test")
	(gm().get("_certified") as Dictionary).erase("cert_test")

## Trees in or next to the line are disc golf's main hazard ("woods"); trees
## further out frame the hole. Woods + one more type = full challenge.
func test_trees_in_play_count_as_woods_hazard() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(55, 50))
	for c in range(24, 52, 4):
		_put(w, Vector2i(c, 51), 5)                            # trees 1 cell off the line
	var woods_only: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float((woods_only["parts"] as Dictionary)["challenge"]) - 0.6) < 0.001,
		"woods alone = one hazard type (0.6), got %.2f" % float((woods_only["parts"] as Dictionary)["challenge"]))
	check(float((woods_only["parts"] as Dictionary)["framing"]) < 0.01, "in-play trees don't also count as framing")
	for i in 4:
		_put(w, Vector2i(38 + i, 47), 13)                      # plus a sand trap
	var woods_sand: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float((woods_sand["parts"] as Dictionary)["challenge"]) - 1.0) < 0.001, "woods + sand = full challenge")
	w.free()
