## Persistence of meta state (settings.cfg) — runs in an isolated HOME.
extends "res://tests/TestCase.gd"

func test_story_persists_through_save_and_load() -> void:
	story().reset()
	story().deserialize({"chapter": 3, "beats": {"ch3_start": true}, "choices": {"ch3_start": "Let's do it."}})
	gm().call("_save_course_meta")
	story().reset()
	gm().call("_load_course_meta")
	check_eq(story().get_chapter(), 3, "chapter restored")
	check_eq(story().get_choice("ch3_start"), "Let's do it.", "choice restored")
	check(not story().get("_needs_migration"), "modern save is not treated as legacy")

func test_save_without_story_section_is_legacy() -> void:
	gm().call("_save_course_meta")
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.erase_section("story")
	cfg.save("user://settings.cfg")
	gm().call("_load_course_meta")
	check(story().get("_needs_migration"), "pre-story save flagged for migration")
	story().reset()

## Courses you buy keep what you build (they used to reset to the preset every visit),
## and one course's tiles never leak into another.
func test_owned_course_keeps_its_build() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var w: Node = gm().world
	var cell := Vector2i(40, 40)
	var home_tile: int = int(w.get("_tiles").get(cell, 0))
	if not gm().is_course_owned("maple_ridge"):
		gm().owned_courses.append("maple_ridge")
	gm().switch_to_course("maple_ridge")
	await frames(5)
	w.get("_tiles")[cell] = 12  # marker: PRO_SHOP id on an odd cell
	gm().switch_to_course("home")
	await frames(5)
	check_eq(int(w.get("_tiles").get(cell, 0)), home_tile, "home course untouched by Maple build")
	gm().switch_to_course("maple_ridge")
	await frames(5)
	check_eq(int(w.get("_tiles").get(cell, 0)), 12, "Maple Hill kept the player's tile")
	gm().switch_to_course("home")
	await frames(5)
	await quiet_story()

func test_untagged_snapshot_is_ignored() -> void:
	var snaps: Dictionary = gm().get("_course_snapshots")
	snaps["krokhol"] = {"tiles": {}}  # pre-tagging data (could be another course's tiles)
	check(not gm().call("_has_valid_snapshot", "krokhol"), "untagged non-home snapshot rejected")
	snaps["krokhol"] = {"tiles": {}, "course_id": "krokhol"}
	check(gm().call("_has_valid_snapshot", "krokhol"), "tagged snapshot accepted")
	snaps.erase("krokhol")
