extends Node

const _WorldScene = preload("res://scenes/game_world/GameWorld3D.tscn")
const _HubScene   = preload("res://scenes/hub_world/HubWorld3D.tscn")

func _ready() -> void:
	var world := _WorldScene.instantiate()
	add_child(world)
	GameManager.world = world
	GameManager.restore_active_course()
	_aim_camera(world, Vector3(150.0, 0.0, 20.0))

	add_child(_HubScene.instantiate())

	EventBus.load_completed.connect(_on_load_completed, CONNECT_ONE_SHOT)
	EventBus.load_requested.emit()

func _on_load_completed(_success: bool) -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _aim_camera(world: Node, focus: Vector3) -> void:
	var cam: Camera3D = world.get_node_or_null("CourseCamera3D")
	if cam:
		var offset := Vector3(-55.0, 90.0, 55.0)
		cam.look_at_from_position(focus + offset, focus, Vector3.UP)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		EventBus.game_quit_requested.emit()
