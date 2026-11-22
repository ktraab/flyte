## Base class for smoke-test suites. Provides assertions + frame helpers.
## Assertions record failures instead of aborting, so one test reports every problem.
extends RefCounted

var tree: SceneTree
var _errors: Array = []

# ── Assertions ────────────────────────────────────────────────────────────────

func check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)

func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_errors.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

# ── Frame helpers ─────────────────────────────────────────────────────────────

func frames(n: int = 1) -> void:
	for i in n:
		await tree.process_frame

## Step the simulation forward by `seconds` of game time, in fixed 1/60 chunks.
## Calls _process directly on the economy so day/income logic runs fast in tests.
func advance_economy(seconds: float) -> void:
	var em: Node = tree.root.get_node("EconomyManager")
	var steps: int = int(seconds * 10.0)
	for i in steps:
		em._process(0.1)
		if i % 50 == 0:
			await tree.process_frame

# ── Game helpers ──────────────────────────────────────────────────────────────

func gm() -> Node:
	return tree.root.get_node("GameManager")

func ui() -> Node:
	return tree.root.get_node("UIManager")

func story() -> Node:
	return tree.root.get_node("StoryManager")

func bus() -> Node:
	return tree.root.get_node("EventBus")

func goto_state(s: int) -> void:
	gm().change_state(s)
	await frames(3)

## Completes every queued story beat so tests start from a clean screen stack.
func drain_dialogue() -> void:
	for i in 40:
		await frames(1)
		if story().call("is_panning"):
			story().call("finish_pan")
			continue
		if ui().current_screen_name() != "DialogueOverlay":
			if (story().get("_queue") as Array).is_empty():
				return
			continue
		ui().get("_cache")["DialogueOverlay"].call("_complete")

## Put the story in a finished state so beats never pop up mid-test.
func quiet_story() -> void:
	var all: Dictionary = {}
	for b in story().BEATS:
		all[b] = true
	story().deserialize({"chapter": 6, "beats": all})
	await drain_dialogue()

func press_key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)
