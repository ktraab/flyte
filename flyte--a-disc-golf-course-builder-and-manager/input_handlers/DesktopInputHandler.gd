## Mouse + keyboard input for desktop / Steam builds.
## Assumes InputMap actions: move_left, move_right, move_up, move_down
## (add via Project → Project Settings → Input Map if missing).
class_name DesktopInputHandler
extends "res://input_handlers/BaseInputHandler.gd"

var _zoom_delta := 0.0
var _left_click_just := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:        _left_click_just = true
			MOUSE_BUTTON_WHEEL_UP:    _zoom_delta += 1.0
			MOUSE_BUTTON_WHEEL_DOWN:  _zoom_delta -= 1.0

# ── API ───────────────────────────────────────────────────────────────────────

func get_pan_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func get_zoom_delta() -> float:
	var d := _zoom_delta
	_zoom_delta = 0.0
	return d

func get_pointer_position() -> Vector2:
	return get_viewport().get_mouse_position()

func is_select_just_pressed() -> bool:
	var fired := _left_click_just or Input.is_action_just_pressed("ui_accept")
	_left_click_just = false
	return fired

func is_cancel_just_pressed() -> bool:
	return Input.is_action_just_pressed("ui_cancel")

func is_select_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func is_secondary_active() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
