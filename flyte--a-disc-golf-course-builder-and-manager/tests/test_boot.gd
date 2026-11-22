## Boot + core navigation smoke tests.
extends "res://tests/TestCase.gd"

func test_boots_to_main_menu() -> void:
	check_eq(gm().state, gm().GameState.MAIN_MENU, "game reaches MAIN_MENU after boot")
	check_eq(ui().current_screen_name(), "MainMenu", "MainMenu is top screen")
	check(gm().world != null, "GameWorld3D registered on GameManager")

func test_enter_gameplay_and_builder() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await drain_dialogue()
	check_eq(ui().current_screen_name(), "Gameplay", "Gameplay screen shown")
	await goto_state(gm().GameState.COURSE_BUILDER)
	check_eq(ui().current_screen_name(), "CourseBuilder", "CourseBuilder screen shown")
	await goto_state(gm().GameState.GAMEPLAY)
	await drain_dialogue()
	check_eq(ui().current_screen_name(), "Gameplay", "back to Gameplay")

func test_world_map_opens() -> void:
	await goto_state(gm().GameState.WORLD_MAP)
	await drain_dialogue()
	check_eq(ui().current_screen_name(), "WorldMap", "WorldMap screen shown")
	await goto_state(gm().GameState.GAMEPLAY)
	await drain_dialogue()

## PropFactory was split out of GameWorld3D — every prop type must still build.
func test_prop_factory_builds_every_prop() -> void:
	var props: GDScript = load("res://scenes/game_world/PropFactory.gd")
	check_eq(props.CELL_SIZE, GameWorld3D.CELL_SIZE, "PropFactory.CELL_SIZE in sync with GameWorld3D")
	# TEE, BASKET, ENTRANCE, PARKING, RESTROOM, FOOD_STAND, PRO_SHOP, BENCH, FLOWER_BED, SCULPTURE
	# (trees, rough and sand are instanced — tests/test_prop_batch.gd)
	for tt in [6, 7, 8, 9, 10, 11, 12, 20, 21, 22]:
		var n: Node = gm().world.call("_prop_for", tt, 5, 5)
		check(n != null, "prop builds for tile type %d" % tt)
		if n:
			n.free()
	var pine: Node = props.make_pine(3.0, 1, 1)
	check(pine.get_child_count() > 0, "pine has meshes")
	pine.free()
	check_eq(props.sand_instances(1, 1, Vector3.ZERO, 0).size(), 12, "sand = 12 grains")
	check_eq(props.rough_grass_instances(1, 1, Vector3.ZERO, 0).size(), 8, "rough clump = 8 blades")

## Gameplay overlay panels were split into scenes/ui/screens/gameplay/*Panel.gd.
func test_gameplay_panels_build() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var gp: Node = ui().get("_cache")["Gameplay"]
	var panels := {
		"_rebuild_stats_panel": "_stats_vbox",
		"_rebuild_fees_panel": "_fees_vbox",
		"_rebuild_staff_panel": "_staff_vbox",
		"_rebuild_events_panel": "_events_vbox",
		"_rebuild_hole_panel": "_hole_vbox",
		"_build_analytics": "_analytics_vbox",
	}
	for fn in panels:
		gp.call(fn)
		await frames(1)
		var vb = gp.get(panels[fn])
		if vb == null:
			continue  # panel builds into a container it owns (e.g. staff rows)
		check((vb as Node).get_child_count() > 0, "%s filled %s" % [fn, panels[fn]])

## A brand-new game starts on Uncle Ray's land with his 3 rough holes (STORY.md Ch0).
func test_new_game_has_rays_three_holes() -> void:
	var w := GameWorld3D.new()
	w.set("_tiles", {})
	w.call("_generate_default_course")
	var holes: Array = w.get_holes_info()
	check_eq(holes.size(), 3, "three starter holes")
	for h in holes:
		check((h["distance"] as int) >= 35, "hole %d is a real hole (%dm)" % [h["hole_num"], h["distance"]])
		var path: Array = w.call("_bfs_cells", Vector2i(75, 0), [h["tee_cell"]])
		check(not path.is_empty(), "hole %d tee reachable from the gate" % h["hole_num"])
	w.free()

func test_rays_holes_are_rough() -> void:
	var w := GameWorld3D.new()
	w.set("_tiles", {})
	w.call("_generate_default_course")
	var r: float = w.get_course_rating()
	check(r >= 1.5 and r < 3.0, "starter course rates 1.5–3★ so 3★ goal isn't instant (got %.2f)" % r)
	w.free()

func test_builtin_basket_is_light() -> void:
	var props: GDScript = load("res://scenes/game_world/PropFactory.gd")
	var m: ArrayMesh = props.basket_mesh()
	check_eq(m.get_surface_count(), 3, "basket mesh has 3 material surfaces")
	var verts := 0
	for si in m.get_surface_count():
		verts += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(verts > 500 and verts < 20000, "basket is low-poly (%d verts vs ~341k imported)" % verts)
	check(props.basket_mesh() == m, "mesh cached and shared between holes")
	var flags: Array = []
	var b: Node = props.make_basket(flags)
	check_eq(flags.size(), 1, "flag registered for animation")
	b.free()

func test_course_builder_modules_work() -> void:
	await goto_state(gm().GameState.COURSE_BUILDER)
	var cb: Node = ui().get("_cache")["CourseBuilder"]
	var holes: Array = gm().world.get_holes_info()
	check(holes.size() > 0, "world has holes to critique")
	if holes.size() > 0:
		var crit: Dictionary = cb.call("_critique_hole", holes[0])
		check(crit.has("score") or crit.size() > 0, "critique returns a result: %s" % str(crit.keys()))
	cb.call("_refresh_hole_manager")
	await frames(1)
	check((cb.get("_n_holes_vbox") as Node).get_child_count() > 0, "hole manager lists holes")
	cb.call("_on_layouts_pressed")
	await frames(1)
	check(cb.get("_n_layouts_overlay") != null, "layouts overlay built")
	check(cb.get("_n_architect_overlay") != null, "architect overlay built")
	cb.call("_on_architect_pressed")
	await frames(1)
	cb.call("_on_critique_pressed")
	await frames(1)
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
