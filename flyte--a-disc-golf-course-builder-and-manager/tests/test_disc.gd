## Disc flight + ground physics (scenes/gameplay/DiscProjectile.gd): flight shape,
## wind, chains, rim, trees, water, OB-at-rest, rough stroke, slopes, hills, skips.
## Flights run on an empty strip of the home map (rows 100–130), stepped by hand.
extends "res://tests/TestCase.gd"

const Disc = preload("res://scenes/gameplay/DiscProjectile.gd")
const ROW := 115                 # throws travel along this row, west → east
const X0 := 20                   # tee cell column

var _saved_tiles := {}
var _saved_heights := {}
var _saved_ob := {}
var _saved_wind := 0.0

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	_saved_wind = float(_w().get("_wind_speed"))
	_w().set("_wind_speed", 0.0)

func _w() -> Node:
	return gm().world

func _cell_pos(c: int, r: int = ROW) -> Vector3:
	var p: Vector3 = _w().call("get_cell_world_pos", Vector2i(c, r))
	p.y = _w().call("get_ground_y", p)
	return p

func _paint(cells: Array, tt: int) -> void:
	var tiles: Dictionary = _w().get("_tiles")
	for c in cells:
		if not _saved_tiles.has(c):
			_saved_tiles[c] = tiles.get(c, null)
		tiles[c] = tt

func _raise(cells: Array, h: float) -> void:
	var hs: Dictionary = _w().get("_tile_heights")
	for c in cells:
		if not _saved_heights.has(c):
			_saved_heights[c] = hs.get(c, null)
		hs[c] = h

func _ob(cells: Array) -> void:
	var ob: Dictionary = _w().get("_ob_zones")
	for c in cells:
		if not _saved_ob.has(c):
			_saved_ob[c] = ob.get(c, null)
		ob[c] = 0

func _restore() -> void:
	var tiles: Dictionary = _w().get("_tiles")
	for c in _saved_tiles:
		if _saved_tiles[c] == null: tiles.erase(c)
		else: tiles[c] = _saved_tiles[c]
	var hs: Dictionary = _w().get("_tile_heights")
	for c in _saved_heights:
		if _saved_heights[c] == null: hs.erase(c)
		else: hs[c] = _saved_heights[c]
	var ob: Dictionary = _w().get("_ob_zones")
	for c in _saved_ob:
		if _saved_ob[c] == null: ob.erase(c)
		else: ob[c] = _saved_ob[c]
	_saved_tiles.clear(); _saved_heights.clear(); _saved_ob.clear()
	_w().set("_wind_speed", _saved_wind)

func _rect(c0: int, c1: int, r0: int, r1: int) -> Array:
	var out := []
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			out.append(Vector2i(c, r))
	return out

## Fly a disc to rest; returns {pos, pen, in_basket}.
func _fly(to: Vector3, arc: float = 3.0, dur: float = 1.6, turn := 0.0, fade := 0.0,
		basket := Vector3.INF, comp := false) -> Dictionary:
	var d: Node3D = Disc.new()
	_w().add_child(d)
	d.set("_turn", turn); d.set("_fade", fade)
	d.set("basket_pos", basket); d.set("aim_compensate", comp)
	var res := {}
	d.landed.connect(func(p: Vector3, pen: int) -> void: res["pos"] = p; res["pen"] = pen)
	d.call("launch", _cell_pos(X0) + Vector3(0, 1.2, 0), to, arc, dur)
	for i in 600:
		if not res.is_empty():
			break
		d.call("_process", 1.0 / 60.0)
	res["in_basket"] = bool(d.get("in_basket"))
	d.queue_free()
	check(res.has("pos"), "disc came to rest")
	return res

func _tile_at(p: Vector3) -> int:
	return int(_w().call("get_tile_at", p))

# ── Flight shape ─────────────────────────────────────────────────────────────

func test_flight_shape_like_a_disc() -> void:
	var from := Vector3(0, 1.2, 0)
	var to := Vector3(0, 0, -100)          # straight north
	var p := Disc.flight_params(from, to, 10.0, 3.0, 8.0, 6.0, Vector2.ZERO, false)
	var peak_t := 0.0; var peak_h := -INF
	for i in 101:
		var t := i / 100.0
		var h: float = Disc.flight_point(p, t).y
		if h > peak_h: peak_h = h; peak_t = t
	check(peak_t > 0.33 and peak_t < 0.5, "peaks before halfway (t=%.2f)" % peak_t)
	check(Disc.progress(0.5) > 0.6, "fast off the hand, slower late")
	check(Disc.flight_point(p, 0.25).x > 2.0, "RHBH turn goes right early")
	check(absf(Disc.flight_point(p, 1.0).x + 6.0) < 0.01, "ends one fade-length left")
	var pc := Disc.flight_params(from, to, 10.0, 3.0, 8.0, 6.0, Vector2.ZERO, true)
	check(Disc.flight_point(pc, 1.0).distance_to(to) < 0.01, "aim compensation finishes on target")
	check(Disc.flight_point(pc, 0.6).x > 1.0, "compensated flight still shows the curve")
	_restore()

func test_headwind_turns_tailwind_fades() -> void:
	var from := Vector3(0, 1.2, 0); var to := Vector3(0, 0, -100)
	var calm := Disc.flight_params(from, to, 8.0, 2.5, 8.0, 6.0, Vector2.ZERO, false)
	var head := Disc.flight_params(from, to, 8.0, 2.5, 8.0, 6.0, Vector2(0, 3.0), false)   # blowing south, into the throw
	var tail := Disc.flight_params(from, to, 8.0, 2.5, 8.0, 6.0, Vector2(0, -3.0), false)
	check(float(head["turn"]) > float(calm["turn"]), "headwind adds turn")
	check(float(head["arc"]) > float(calm["arc"]), "headwind lifts")
	check(float(tail["fade"]) > float(calm["fade"]), "tailwind adds fade")
	var putt := Disc.flight_params(from, Vector3(0, 0, -8), 0.8, 0.6, 0, 0, Vector2(3, 0), false)
	var drive := Disc.flight_params(from, to, 10.0, 0.6, 0, 0, Vector2(3, 0), false)
	check((putt["drift"] as Vector3).length() < (drive["drift"] as Vector3).length() * 0.3, "low putts barely drift")
	_restore()

# ── Basket ───────────────────────────────────────────────────────────────────

func test_chains_catch_a_throw_at_the_basket() -> void:
	var basket := _cell_pos(X0 + 6)
	var r := _fly(basket, 0.8, 0.8, 0.0, 0.0, basket)
	check(r["in_basket"], "disc caught by the chains")
	check(Vector2((r["pos"] as Vector3).x - basket.x, (r["pos"] as Vector3).z - basket.z).length() < 0.05, "rests in the tray")
	check((r["pos"] as Vector3).y > basket.y + 0.5, "sits up in the tray, not on the grass")
	_restore()

func test_long_drive_through_the_chains_is_an_ace() -> void:
	var basket := _cell_pos(X0 + 25)
	var r := _fly(basket, 6.0, 2.2, 6.0, 5.0, basket, true)
	check(r["in_basket"], "compensated drive at the basket finds the chains")
	_restore()

func test_near_miss_is_not_holed() -> void:
	var basket := _cell_pos(X0 + 6)
	var r := _fly(basket + Vector3(0, 0, 1.6), 0.8, 0.8, 0.0, 0.0, basket)
	check(not r["in_basket"], "1.6 m wide is a miss (no more 2 m auto-catch)")
	var g := _fly(basket + Vector3(0, 0, 0.6), 0.8, 0.8, 0.0, 0.0, basket)
	check(not g["in_basket"], "rim glance is a miss")
	var gp: Vector3 = g["pos"]
	check(Vector2(gp.x - basket.x, gp.z - basket.z).length() < 2.5, "glance drops near the basket")
	_restore()

func test_disc_flies_over_basket_when_high() -> void:
	var basket := _cell_pos(X0 + 8)
	var r := _fly(_cell_pos(X0 + 16), 6.0, 1.4, 0.0, 0.0, basket)
	check(not r["in_basket"], "high flight passes over the basket")
	check((r["pos"] as Vector3).x > basket.x + 4.0, "and keeps going")
	_restore()

# ── Obstacles ────────────────────────────────────────────────────────────────

func test_tree_knocks_the_disc_down() -> void:
	_paint(_rect(X0 + 8, X0 + 9, ROW - 1, ROW + 1), 5)   # tall trees (default size 2)
	var r := _fly(_cell_pos(X0 + 20), 1.5, 1.2)
	var p: Vector3 = r["pos"]
	check(_tile_at(p) != 5, "never comes to rest inside a tree")
	check(p.x < _cell_pos(X0 + 10).x, "stopped at the trees, not past them")
	check(r["pen"] == 0, "no penalty for a tree hit")
	_restore()

func test_high_throw_clears_small_trees() -> void:
	var cells := _rect(X0 + 8, X0 + 9, ROW - 1, ROW + 1)
	_paint(cells, 5)
	var sizes: Dictionary = _w().get("_tile_tree_size")
	var saved := {}
	for c in cells:
		saved[c] = sizes.get(c, null); sizes[c] = 0
	var r := _fly(_cell_pos(X0 + 20), 6.0, 1.4)
	check((r["pos"] as Vector3).x > _cell_pos(X0 + 15).x, "high flight goes over small trees")
	for c in cells:
		if saved[c] == null: sizes.erase(c)
		else: sizes[c] = saved[c]
	_restore()

func test_water_splash_costs_a_stroke_and_replays_from_dry_ground() -> void:
	_paint(_rect(X0 + 12, X0 + 18, ROW - 3, ROW + 3), 3)
	var r := _fly(_cell_pos(X0 + 15), 2.0, 1.2)
	check(r["pen"] == 1, "splash = +1")
	check(_tile_at(r["pos"]) != 3, "lie is back on dry ground")
	check((r["pos"] as Vector3).x < _cell_pos(X0 + 13).x, "lie is where it was last over land")
	_restore()

func test_ob_judged_at_rest_not_in_the_air() -> void:
	_ob(_rect(X0 + 8, X0 + 12, ROW - 2, ROW + 2))
	var over := _fly(_cell_pos(X0 + 20), 5.0, 1.4)
	check(over["pen"] == 0, "flying over OB and landing in bounds is fine")
	var into := _fly(_cell_pos(X0 + 10), 2.0, 1.0)
	check(into["pen"] == 1, "coming to rest OB = +1")
	check(not bool(_w().call("is_ob_at", into["pos"], 0)), "lie moves back in bounds")
	_restore()

func test_rough_and_sand_still_cost_a_stroke() -> void:
	_paint(_rect(X0 + 9, X0 + 12, ROW - 2, ROW + 2), 4)
	var r := _fly(_cell_pos(X0 + 10), 2.0, 1.0)
	check(r["pen"] == 1, "rest in rough = +1")
	_paint(_rect(X0 + 9, X0 + 12, ROW - 2, ROW + 2), 13)
	var s := _fly(_cell_pos(X0 + 10), 2.0, 1.0)
	check(s["pen"] == 1, "rest in sand = +1")
	check(_tile_at(s["pos"]) == 13, "sand stops the disc dead")
	_restore()

# ── Ground ───────────────────────────────────────────────────────────────────

func test_fairway_skip_carries_the_disc_forward() -> void:
	_paint(_rect(X0 + 1, X0 + 30, ROW - 2, ROW + 2), 1)
	var to := _cell_pos(X0 + 20)
	var r := _fly(to, 3.0, 1.4)
	check((r["pos"] as Vector3).x > to.x + 1.0, "skips forward on fairway")
	check(r["pen"] == 0, "no penalty on fairway")
	_restore()

func test_disc_rolls_down_a_slope() -> void:
	# Ground falls away to the south across the landing area.
	for c in range(X0 + 8, X0 + 13):
		for r in range(ROW - 3, ROW + 6):
			_raise([Vector2i(c, r)], 1.2 - (r - (ROW - 3)) * 0.35)
	var to := _cell_pos(X0 + 10)
	_paint(_rect(X0 + 8, X0 + 12, ROW - 3, ROW + 5), 0)   # plain grass (skip short)
	var r := _fly(to, 2.0, 1.0)
	check((r["pos"] as Vector3).z > to.z + 0.5, "rolls downhill after landing")
	_restore()

func test_hill_stops_a_low_throw() -> void:
	_raise(_rect(X0 + 9, X0 + 11, ROW - 3, ROW + 3), 3.0)
	var r := _fly(_cell_pos(X0 + 20), 1.2, 1.2)
	check((r["pos"] as Vector3).x < _cell_pos(X0 + 13).x, "low throw doesn't pass through the hill")
	_restore()

# ── Player aim ───────────────────────────────────────────────────────────────

func test_player_aim_assist_compensates_the_curve() -> void:
	var pt: Node = load("res://scenes/gameplay/PlayTestController.gd").new()
	var basket := _cell_pos(X0 + 30)
	pt.set("_holes", [{"basket_pos": basket, "par": 3}])
	pt.set("_hole_idx", 0)
	pt.set("_player_pos", _cell_pos(X0))
	pt.set("_aim_dir", Vector3(1, 0, 0))
	pt.set("_selected_disc", "fairway")
	var plan: Dictionary = pt.call("_plan_throw", _cell_pos(X0) + Vector3(110, 0, 0), 0.5, null)
	check(plan["snapped"], "aiming at the basket snaps to it")
	var to: Vector3 = Disc.aim_point(plan["to"], plan["basket"])
	var p := Disc.flight_params(plan["from"], to, plan["arc"], plan["dur"], plan["turn"], plan["fade"], Vector2.ZERO, true)
	var end := Disc.flight_point(p, 1.0)
	check(Vector2(end.x - basket.x, end.z - basket.z).length() < 0.05, "assisted flight ends at the chains")
	check(float(plan["turn"]) > 3.0, "fairway driver has a real S-curve now")
	pt.free()
	_restore()

# ── Graphics helpers ─────────────────────────────────────────────────────────

func test_diagonal_fairway_edges_are_smoothed() -> void:
	var cells := []
	for i in 8:
		cells.append(Vector2i(X0 + i, ROW - 10 + i))
	_paint(cells, 1)
	_w().call("_build_edge_fill")
	var m: Mesh = _w().call("get_edge_fill_mesh")
	check(m != null and m.get_surface_count() > 0, "edge fill mesh built for a diagonal fairway")
	_restore()
	_w().call("_build_edge_fill")

func test_every_tree_has_a_contact_shadow() -> void:
	_w().call("_build_contact_shadows")
	var trees: int = (_w().call("get_tiles_of_type", 5) as Array).size()
	check_eq(_w().call("get_contact_shadow_count"), trees, "one soft shadow per tree")
	_restore()

## Putts used to be automatic (putter deviation 0 + aim snap). Now the make
## chance falls with distance; a miss lands close to the basket.
func test_putt_make_chance_falls_with_distance() -> void:
	var PT: GDScript = load("res://scenes/gameplay/PlayTestController.gd")
	check(PT.putt_make_chance(3.0) >= 0.95, "tap-ins almost always go in")
	check(absf(PT.putt_make_chance(10.0) - 0.70) < 0.01, "~70% from 10 m")
	check(absf(PT.putt_make_chance(20.0) - 0.35) < 0.01, "~35% from 20 m")
	check(PT.putt_make_chance(45.0) <= 0.05, "long bombs rarely drop")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var basket := Vector3(50, 0, 50)
	var made := 0
	var worst := 0.0
	for i in 400:
		var t: Vector3 = PT.putt_target(basket, Vector3(1, 0, 0), 20.0, rng)
		var off := Vector2(t.x - basket.x, t.z - basket.z).length()
		if off < 0.01:
			made += 1
		worst = maxf(worst, off)
	check(made > 400 * 0.25 and made < 400 * 0.45, "about 35%% of 20 m putts aim true (%d/400)" % made)
	check(worst <= 1.6, "misses stay close to the basket (max %.2f m)" % worst)
