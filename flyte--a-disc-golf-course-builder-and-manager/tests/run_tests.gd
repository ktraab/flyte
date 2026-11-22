## Headless smoke-test runner.
##
## Run via tools/run_tests.sh (NOT directly) — the wrapper points HOME at a
## throwaway folder so user:// saves never touch your real game data.
##
## Each test is a method named test_* in one of the suites listed in SUITES.
## Suites extend tests/TestCase.gd and get the helpers defined there.
extends SceneTree

const SUITES: Array[String] = [
	"res://tests/test_boot.gd",
	"res://tests/test_pause.gd",
	"res://tests/test_story.gd",
	"res://tests/test_save.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_away.gd",
	"res://tests/test_disc.gd",
	"res://tests/test_prop_batch.gd",
	"res://tests/test_perf.gd",
	"res://tests/test_hole_score.gd",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Refuse to run against a real user data dir — protects the player's save.
	if not OS.get_user_data_dir().contains("flyte_test_home"):
		printerr("ABORT: user data dir is not isolated (%s). Use tools/run_tests.sh." % OS.get_user_data_dir())
		quit(2)
		return

	change_scene_to_file("res://scenes/main/Main.tscn")
	# Let Main._ready → load_requested → MAIN_MENU settle.
	for i in 10:
		await process_frame

	var only: String = OS.get_environment("FLYTE_TEST_FILTER")
	for path in SUITES:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			_record(false, path.get_file(), "suite failed to load (parse error?)")
			continue
		var suite: Object = script.new()
		suite.set("tree", self)
		for m in script.get_script_method_list():
			var mname: String = m["name"] as String
			if not mname.begins_with("test_"):
				continue
			var label := "%s::%s" % [path.get_file().get_basename(), mname]
			if only != "" and not label.contains(only):
				continue
			if suite.has_method("before_each"):
				await suite.call("before_each")
			suite.set("_errors", [])
			await suite.call(mname)
			var errs: Array = suite.get("_errors") as Array
			_record(errs.is_empty(), label, "; ".join(PackedStringArray(errs)))
		if suite is Node:
			(suite as Node).free()

	print("")
	print("==== %d passed, %d failed ====" % [_passed, _failed])
	for f in _failures:
		print("  FAIL ", f)
	quit(1 if _failed > 0 else 0)

func _record(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  ok   ", label)
	else:
		_failed += 1
		_failures.append("%s — %s" % [label, detail])
		print("  FAIL ", label, " — ", detail)
