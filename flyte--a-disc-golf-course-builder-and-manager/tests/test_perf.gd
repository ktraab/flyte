## Performance features: layout cache (course stats computed once per layout),
## minimap terrain cache, graphics presets (render scale, grass tufts, auto pick).
extends "res://tests/TestCase.gd"

const GRASS := 0
const FAIRWAY := 1
const TEE := 6
const BASKET := 7
const BENCH := 20

var _saved := {}

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()

func _w() -> Node:
	return gm().world

func _put(cell: Vector2i, tt: int, hole := -1) -> void:
	var tiles: Dictionary = _w().get("_tiles")
	var hn: Dictionary = _w().get("_tile_hole_num")
	if not _saved.has(cell):
		_saved[cell] = [tiles.get(cell, null), hn.get(cell, null)]
	tiles[cell] = tt
	if hole >= 0:
		hn[cell] = hole

func _restore() -> void:
	var tiles: Dictionary = _w().get("_tiles")
	var hn: Dictionary = _w().get("_tile_hole_num")
	for c in _saved:
		var v: Array = _saved[c]
		if v[0] == null: tiles.erase(c)
		else: tiles[c] = v[0]
		if v[1] == null: hn.erase(c)
		else: hn[c] = v[1]
	_saved.clear()

func test_layout_cache_never_returns_stale_holes() -> void:
	var before: int = (_w().call("get_holes_info") as Array).size()
	_put(Vector2i(20, 140), TEE, 77)
	_put(Vector2i(40, 140), BASKET, 77)
	var after: Array = _w().call("get_holes_info")
	check_eq(after.size(), before + 1, "new hole shows up immediately")
	var rating_a: float = _w().call("get_course_rating")
	for c in range(21, 40):
		_put(Vector2i(c, 140), FAIRWAY)
	var rating_b: float = _w().call("get_course_rating")
	check(rating_b != rating_a, "painting a fairway changes the cached rating (%.3f → %.3f)" % [rating_a, rating_b])
	_restore()
	check_eq((_w().call("get_holes_info") as Array).size(), before, "removing it updates again")

func test_layout_cache_returns_copies() -> void:
	var a: Array = _w().call("get_holes_info")
	check(a.size() > 0, "home course has holes")
	(a[0] as Dictionary)["par"] = 99
	a.clear()
	var b: Array = _w().call("get_holes_info")
	check(b.size() > 0 and int((b[0] as Dictionary)["par"]) != 99, "caller edits don't leak into the cache")
	var t: Array = _w().call("get_tiles_of_type", 5)
	var n := t.size()
	t.clear()
	check_eq((_w().call("get_tiles_of_type", 5) as Array).size(), n, "tiles_of_type returns a copy")

func test_cached_counts_match_a_full_scan() -> void:
	_put(Vector2i(10, 145), BENCH)
	var tiles: Dictionary = _w().get("_tiles")
	var trees := 0; var decor := 0; var restrooms := 0
	for c in tiles:
		match int(tiles[c]):
			5: trees += 1
			20, 21, 22: decor += 1
			10: restrooms += 1
	check_eq((_w().call("get_tiles_of_type", 5) as Array).size(), trees, "tree count")
	check_eq(_w().call("_count_decor_tiles"), decor, "decor count (incl. new bench)")
	check_eq(int((_w().call("get_facility_counts") as Dictionary)["restroom"]), restrooms, "restroom count")
	_restore()

func test_minimap_terrain_redrawn_only_on_change() -> void:
	var gp: Node = ui().get("_cache")["Gameplay"]
	gp.call("_rebuild_minimap")
	var base1: Image = gp.get("_minimap_base")
	gp.call("_rebuild_minimap")
	check(gp.get("_minimap_base") == base1, "unchanged course reuses the terrain layer")
	_put(Vector2i(12, 146), FAIRWAY)
	gp.call("_rebuild_minimap")
	var base2: Image = gp.get("_minimap_base")
	check(base2 != base1, "painting redraws the terrain layer")
	_restore()

func test_graphics_presets_apply_render_scale_and_tufts() -> void:
	var root: Viewport = tree.root
	var tufts: Node3D = _w().get("_grass_tuft_mmi")
	gm().call("apply_graphics_preset", 0)
	check(is_equal_approx(root.scaling_3d_scale, 0.75), "Low renders 3D at 75%")
	check(tufts == null or not tufts.visible, "Low hides grass tufts")
	gm().call("apply_custom_graphics", {"scale": 0.6})
	check(is_equal_approx(root.scaling_3d_scale, 0.6), "custom render scale applies")
	check_eq(gm().get("graphics_preset"), 3, "custom change → Custom preset")
	gm().call("apply_graphics_preset", 1)
	check(is_equal_approx(root.scaling_3d_scale, 1.0), "Medium renders at full resolution")
	check(tufts == null or tufts.visible, "Medium shows grass tufts")
	var rec: int = gm().call("recommended_graphics_preset")
	check(rec == 0 or rec == 1, "auto preset is Low or Medium")

func test_settings_preset_pick_is_not_flipped_to_custom() -> void:
	ui().call("push_screen", "Settings")
	await frames(3)
	var st: Node = ui().get("_cache")["Settings"]
	st.call("_sync_graphics_ui")
	st.call("_on_preset_selected", 0)
	check_eq(gm().get("graphics_preset"), 0, "picking Low stays Low")
	st.call("_on_preset_selected", 1)
	check_eq(gm().get("graphics_preset"), 1, "picking Medium stays Medium")
	press_key("ui_cancel")
	await frames(3)
	if ui().call("current_screen_name") == "Settings":
		EventBus_pop()
		await frames(2)

func EventBus_pop() -> void:
	bus().emit_signal("screen_pop_requested")

## Painting water used to build (and GPU-compile) a new shader every time.
func test_water_rebuild_reuses_shader() -> void:
	var w := _w()
	w.call("_rebuild_water_layer")
	var sh1: Variant = w.get("_water_shader")
	w.call("_rebuild_water_layer")
	check(sh1 != null and w.get("_water_shader") == sh1, "water shader material is reused")

## The old hidden full-grid ArrayMesh (never drawn) is gone; rebuild only does
## edge fill + contact shadows.
func test_terrain_rebuild_builds_only_visible_overlays() -> void:
	var w := _w()
	var before := w.get_child_count()
	w.call("_rebuild_smooth_surface")
	await frames(2)
	check_eq(w.get_child_count(), before, "rebuild doesn't add nodes")
	check(not ("_smooth_surface_msi" in w), "hidden terrain mesh removed")

## Auto guard: a slow stretch lowers settings one notch at a time, never raises,
## ignores single spikes, and stops at the floor (50 % render scale).
func _feed(fps: float, n: int) -> int:
	var lowered := 0
	for i in n:
		if gm().call("perf_guard_sample", fps):
			lowered += 1
	return lowered

func test_perf_guard_steps_down_when_slow() -> void:
	gm().call("apply_graphics_preset", 1)
	check_eq(_feed(60.0, 20), 0, "smooth frames change nothing")
	check_eq(gm().get("graphics_preset"), 1, "still Medium")
	gm().call("_perf_reset")
	var spikes := 0
	for i in 20:
		spikes += 1 if gm().call("perf_guard_sample", 5.0 if i % 4 == 0 else 60.0) else 0
	check_eq(spikes, 0, "occasional hitches (median filter) change nothing")
	gm().call("_perf_reset")
	check_eq(_feed(10.0, 11), 1, "8 slow seconds (after 3 settle samples) → one step")
	check_eq(gm().get("graphics_preset"), 0, "Medium → Low")
	var steps := _feed(5.0, 11 * 6)
	check_eq(steps, 2, "Low then steps render scale 75 → 60 → 50 % and stops")
	check(is_equal_approx(float(gm().get("gfx_render_scale")), 0.5), "floor is 50 %% (got %s)" % gm().get("gfx_render_scale"))
	check_eq(gm().call("lower_graphics_one_step"), "", "nothing left to lower")
	gm().call("apply_graphics_preset", 1)

func test_perf_guard_respects_off_switch_and_settings_row() -> void:
	ui().call("push_screen", "Settings")
	await frames(3)
	var st: Node = ui().get("_cache")["Settings"]
	st.call("_sync_graphics_ui")
	var cb: CheckButton = st.get("_auto_check")
	check(cb != null and cb.button_pressed == bool(gm().get("gfx_auto")), "Settings shows the Auto Adjust switch")
	if cb:
		cb.button_pressed = false
		check_eq(gm().get("gfx_auto"), false, "switch turns the guard off")
		cb.button_pressed = true
		check_eq(gm().get("gfx_auto"), true, "and back on")
	EventBus_pop()
	await frames(2)

## Low preset draws simplified tree meshes; Medium/High draw the full models.
func _tree_tris(batch: Node) -> int:
	var src: Dictionary = _w().get("_tree_detail_src")
	var n := 0
	for pid in src:
		var m: Mesh = batch.call("part_mesh", pid)
		n += m.get_faces().size() / 3
	return n

func test_low_preset_simplifies_trees_only() -> void:
	var batch: Node = _w().call("get_prop_batch")
	gm().call("apply_graphics_preset", 1)
	var full := _tree_tris(batch)
	var inst: int = batch.call("instance_count")
	check(full > 0, "tree parts registered")
	gm().call("apply_graphics_preset", 0)
	var low := _tree_tris(batch)
	check(low < full * 0.7, "Low: tree meshes simplified (%d → %d tris)" % [full, low])
	check_eq(batch.call("instance_count"), inst, "same trees, same places")
	check(batch.call("slots_consistent"), "batch slots intact")
	gm().call("apply_graphics_preset", 2)
	check_eq(_tree_tris(batch), full, "High: full-detail trees")
	gm().call("apply_custom_graphics", {"trees": 0})
	check_eq(_tree_tris(batch), low, "Custom → Simplified reuses the cached meshes")
	gm().call("apply_graphics_preset", 1)
	check_eq(_tree_tris(batch), full, "Medium: full-detail trees")

## The Compatibility-renderer lighting correction must never touch Forward+.
func test_compat_light_fix_only_on_compat_with_shadows() -> void:
	var w := _w()
	var sun: DirectionalLight3D = w.get("_sun")
	var env: Environment = (w.get("_world_env_node") as WorldEnvironment).environment
	w.call("_apply_compat_light_fix", true)
	if GameWorld3D.is_compat_renderer():
		check(is_equal_approx(sun.light_energy, GameWorld3D.COMPAT_SHADOW_LIGHT["sun"]), "compat + shadows → corrected sun")
	else:
		check(is_equal_approx(sun.light_energy, GameWorld3D.SUN_ENERGY), "other renderers keep the tuned sun")
		check(is_equal_approx(env.ambient_light_energy, GameWorld3D.AMBIENT_ENERGY), "and ambient")
	w.call("_apply_compat_light_fix", false)
	check(is_equal_approx(sun.light_energy, GameWorld3D.SUN_ENERGY), "no shadows → normal values everywhere")
	check(is_equal_approx(env.adjustment_saturation, GameWorld3D.SATURATION), "saturation restored")
	gm().call("apply_graphics_preset", 1)

## NPC pathfinding: packed-array BFS must give the same paths as the original
## Dictionary BFS, reach goals that sit on sand, and be fast on a full map.
func _old_bfs(tiles: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var walkable := {0: true, 1: true, 2: true, 4: true, 6: true, 7: true, 8: true}
	var visited := {start: true}
	var came := {start: null}
	var queue: Array = [start]
	var found = null
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = cur; break
		for nb in [Vector2i(cur.x + 1, cur.y), Vector2i(cur.x - 1, cur.y), Vector2i(cur.x, cur.y + 1), Vector2i(cur.x, cur.y - 1)]:
			if not visited.has(nb) and walkable.has(tiles.get(nb, 3)):
				visited[nb] = true; came[nb] = cur; queue.append(nb)
	if found == null:
		return []
	var path: Array = []
	var c = found
	while c != null:
		path.push_front(c); c = came.get(c, null)
	return path

func test_npc_pathfinding_same_paths_and_fast() -> void:
	var w := GameWorld3D.new()
	w.set("_tiles", {})
	w.call("_generate_default_course")
	var tiles: Dictionary = w.get("_tiles")
	for c in 150:
		for r in 150:
			if not tiles.has(Vector2i(c, r)):
				tiles[Vector2i(c, r)] = 0
	for c in range(30, 120):
		tiles[Vector2i(c, 60)] = 5            # a long tree line to route around
	tiles[Vector2i(60, 61)] = 3               # and some water
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var same := 0
	for i in 40:
		var a := Vector2i(rng.randi_range(0, 149), rng.randi_range(0, 149))
		var b := Vector2i(rng.randi_range(0, 149), rng.randi_range(0, 149))
		if int(tiles[a]) == 5 or int(tiles[b]) == 5 or int(tiles[a]) == 3 or int(tiles[b]) == 3:
			continue
		if w.call("_bfs_cells", a, [b]) == _old_bfs(tiles, a, b):
			same += 1
		else:
			check(false, "path %s → %s differs from the original BFS" % [a, b])
	check(same > 25, "%d random routes identical to the original BFS" % same)
	tiles[Vector2i(100, 100)] = 13             # sand: not walkable, but a disc can rest there
	var p: Array = w.call("_bfs_cells", Vector2i(75, 1), [Vector2i(100, 100)])
	check(not p.is_empty() and p.back() == Vector2i(100, 100), "path reaches a disc resting in sand")
	var t0 := Time.get_ticks_usec()
	for i in 10:
		w.call("_bfs_cells", Vector2i(75, 1), [Vector2i(140, 140)])
	var ms := (Time.get_ticks_usec() - t0) / 10000.0
	check(ms < 8.0, "full-map path in %.1f ms (was ~20 ms)" % ms)
	w.free()
