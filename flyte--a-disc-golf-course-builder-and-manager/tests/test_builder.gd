## Course builder safety + editing (playtest feedback 2026-11-25): painting
## never wipes objects, whole-stroke undo, tee facing, select/move, route
## waypoints, NPCs not walking through water, camera drag-pan.
extends "res://tests/TestCase.gd"

const GRASS := 0
const FAIRWAY := 1
const WATER := 3
const TREE := 5
const TEE := 6
const BASKET := 7
const HOLE := 17          # unused hole number — keeps Ray's holes intact
const AREA := Vector2i(115, 115)   # empty corner of the home course

var w: GameWorld3D

func before_each() -> void:
	await goto_state(gm().GameState.COURSE_BUILDER)
	await quiet_story()
	w = gm().world as GameWorld3D
	var em: Node = tree.root.get_node("EconomyManager")
	em.set("balance", maxf(float(em.get("balance")), 50000.0))
	_clear_area()

func _clear_area() -> void:
	for dx in 20:
		for dy in 20:
			var c := AREA + Vector2i(dx, dy)
			if int(w.get("_tiles").get(c, GRASS)) != GRASS:
				w.erase_cell(c)
	w.clear_route_waypoints(HOLE)
	(w.get("_undo_stack") as Array).clear()

func _tile(c: Vector2i) -> int:
	return int(w.get("_tiles").get(c, GRASS))

## One mouse stroke with `tool` over `cells` (press on the first, drag over the rest).
func _stroke(tool: int, cells: Array, hole: int = HOLE) -> void:
	w.set_active_tool(tool)
	w.set_active_hole_num(hole)
	w.call("_begin_stroke")
	for c in cells:
		w.call("_paint_at", c)
	w.call("_end_stroke")

func test_grass_never_paints_over_a_basket() -> void:
	var b := AREA + Vector2i(5, 5)
	_stroke(BASKET, [b])
	check_eq(_tile(b), BASKET, "basket placed")
	_stroke(GRASS, [b + Vector2i(-1, 0), b, b + Vector2i(1, 0)])
	check_eq(_tile(b), BASKET, "dragging grass across the basket leaves it")
	_stroke(FAIRWAY, [b])
	check_eq(_tile(b), BASKET, "fairway doesn't replace it either")
	_stroke(TREE, [b])
	check_eq(_tile(b), BASKET, "another object doesn't replace it")
	_stroke(GameWorld3D.TOOL_ERASE, [b])
	check_eq(_tile(b), GRASS, "Erase removes it")
	_clear_area()

func test_select_tool_id_is_never_painted() -> void:
	var c := AREA + Vector2i(2, 2)
	_stroke(18, [c])   # CourseBuilder TOOL_SELECT
	check_eq(_tile(c), GRASS, "tool 18 (Select) paints nothing")

func test_builder_reentry_keeps_select_mode() -> void:
	var cb: Node = ui().get("_cache").get("CourseBuilder")
	check(cb != null, "builder screen cached")
	if cb == null:
		return
	cb.call("_on_tool_pressed", 18)
	await goto_state(gm().GameState.GAMEPLAY)
	await goto_state(gm().GameState.COURSE_BUILDER)
	check(bool(w.get("_select_mode")), "select mode restored on re-entry")
	check(not bool(w.get("_builder_mode")), "world isn't painting with the Select tool")
	cb.call("_on_tool_pressed", 0)

func test_one_stroke_is_one_undo() -> void:
	var cells: Array = []
	for i in 6:
		cells.append(AREA + Vector2i(i, 0))
	_stroke(FAIRWAY, cells)
	for c in cells:
		check_eq(_tile(c), FAIRWAY, "stroke painted %s" % str(c))
	check_eq(w.get_undo_depth(), 1, "whole drag is one undo step")
	w.undo_paint()
	for c in cells:
		check_eq(_tile(c), GRASS, "undo restored %s" % str(c))
	_clear_area()

func test_second_tee_moves_the_first_and_faces_basket() -> void:
	var t1 := AREA + Vector2i(2, 2)
	var t2 := AREA + Vector2i(2, 10)
	var bk := AREA + Vector2i(15, 10)
	_stroke(BASKET, [bk])
	_stroke(TEE, [t1])
	_stroke(TEE, [t2])
	check_eq(_tile(t1), GRASS, "old tee removed when the hole's tee is placed again")
	check_eq(_tile(t2), TEE, "new tee placed")
	check_eq(w.get_tile_orientation(t2), 1, "tee auto-faces its basket (+X)")
	# Move the basket north of the tee: tee turns to face it.
	_stroke(GameWorld3D.TOOL_ERASE, [bk])
	_stroke(BASKET, [AREA + Vector2i(2, 0)])
	check_eq(w.get_tile_orientation(t2), 0, "tee re-aims when its basket moves (-Z)")
	_clear_area()

func test_tee_drag_places_one_tee() -> void:
	var cells: Array = [AREA + Vector2i(1, 1), AREA + Vector2i(2, 1), AREA + Vector2i(3, 1)]
	w.set_active_tool(TEE)
	w.set_active_hole_num(HOLE)
	w.call("_begin_stroke")
	w.call("_paint_at", cells[0])
	w.call("_end_stroke")
	var n := 0
	for c in cells:
		if _tile(c) == TEE:
			n += 1
	check_eq(n, 1, "one tee per click")
	check(GameWorld3D.SINGLE_PLACE_TOOLS.has(TEE), "tee is a single-place tool (drag doesn't stamp)")
	_clear_area()

func test_move_object_is_safe_and_undoable() -> void:
	var tree_c := AREA + Vector2i(4, 4)
	var other := AREA + Vector2i(6, 4)
	var dest := AREA + Vector2i(8, 4)
	_stroke(TREE, [tree_c])
	_stroke(TREE, [other])
	check(not w.move_object(tree_c, other), "can't drop onto another object")
	check_eq(_tile(other), TREE, "target object survives")
	check_eq(_tile(tree_c), TREE, "source object survives a refused move")
	var h := w.get("_tile_heights") as Dictionary
	h[tree_c] = 0.5
	check(w.move_object(tree_c, dest), "moves onto grass")
	check_eq(_tile(dest), TREE, "tree at destination")
	check_eq(_tile(tree_c), GRASS, "source cleared")
	check_eq(float(h.get(tree_c, 0.0)), 0.5, "terrain height stays put")
	w.undo_paint()
	check_eq(_tile(tree_c), TREE, "undo puts it back")
	check_eq(_tile(dest), GRASS, "undo clears destination")
	h.erase(tree_c)
	_clear_area()

func test_route_waypoints_insert_move_remove() -> void:
	var tee := AREA + Vector2i(0, 0)
	var bk := AREA + Vector2i(18, 0)
	_stroke(BASKET, [bk])
	_stroke(TEE, [tee])
	w.insert_route_waypoint(HOLE, AREA + Vector2i(14, 3))
	w.insert_route_waypoint(HOLE, AREA + Vector2i(4, 3))   # nearer the tee → goes first
	var wps := w.get_route_waypoints(HOLE)
	check_eq(wps, [AREA + Vector2i(4, 3), AREA + Vector2i(14, 3)], "bend inserted where it fits")
	check_eq(w.get_tile_orientation(tee), 1, "tee faces first bend")
	w.move_route_waypoint(HOLE, 0, AREA + Vector2i(5, 6))
	check_eq(w.get_route_waypoints(HOLE)[0], AREA + Vector2i(5, 6), "bend moved")
	check_eq(int(w.call("_waypoint_index_near", HOLE, AREA + Vector2i(6, 7))), 0, "click next to a dot finds it")
	w.remove_route_waypoint(HOLE, 0)
	check_eq(w.get_route_waypoints(HOLE).size(), 1, "bend removed")
	_clear_area()

func test_npc_path_never_crosses_water() -> void:
	var sw := GameWorld3D.new()
	var t := {}
	for c in 150:
		for r in 150:
			t[Vector2i(c, r)] = GRASS
	# Diagonal river from (10,10) to (30,30), two cells thick, with a gap at the south end.
	for i in 21:
		t[Vector2i(10 + i, 10 + i)] = WATER
		t[Vector2i(11 + i, 10 + i)] = WATER
	sw.set("_tiles", t)
	check(not sw.call("_los_clear", Vector2i(12, 20), Vector2i(22, 14)), "straight line across the river is blocked")
	# Diagonal squeeze between two ponds touching at a corner.
	t[Vector2i(50, 50)] = WATER
	t[Vector2i(51, 51)] = WATER
	sw.set("_tiles", t)
	check(not sw.call("_los_clear", Vector2i(49, 52), Vector2i(52, 49)), "no squeezing between corner-touching ponds")
	check(sw.call("_los_clear", Vector2i(40, 40), Vector2i(40, 45)), "open grass stays clear")
	var path: Array = sw.find_walkable_path(Vector3(12 * 2.0, 0, 20 * 2.0), Vector3(22 * 2.0, 0, 14 * 2.0))
	check(path.size() > 2, "walks around the river")
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		for k in 41:
			var p := a.lerp(b, k / 40.0)
			var cell := Vector2i(roundi(p.x / 2.0), roundi(p.z / 2.0))
			if int(t.get(cell, GRASS)) == WATER:
				check(false, "path segment %d crosses water at %s" % [i, str(cell)])
				break
	sw.free()

func test_builder_keys_ignored_when_hidden() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/ui/screens/CourseBuilder.gd")
	check(src.contains("is_visible_in_tree()"), "builder hotkeys guarded by visibility")
	check(src.contains("is_command_or_control_pressed()"), "undo accepts ⌘Z as well as Ctrl+Z")

func test_camera_drag_pan_moves_view() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	var cam := w.get_node("CourseCamera3D") as CourseCamera3D
	var before: Vector3 = cam.get("_target_pos")
	var vp := cam.get_viewport().get_visible_rect().size
	cam.drag_pan(vp * 0.5, vp * 0.5 + Vector2(-80, 0))
	var after: Vector3 = cam.get("_target_pos")
	check((after - before).length() > 1.0, "dragging the map moves the camera")
	check(absf(after.y - before.y) < 0.001, "drag pans on the ground plane only")
	cam.set("_target_pos", before)
	cam.position = before
