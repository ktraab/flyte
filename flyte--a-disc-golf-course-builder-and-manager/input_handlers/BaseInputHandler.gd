## Abstract interface. InputHandler autoload wraps one concrete subclass at a time.
class_name BaseInputHandler
extends Node

func get_pan_direction() -> Vector2:
	return Vector2.ZERO

func get_zoom_delta() -> float:
	return 0.0

func get_pointer_position() -> Vector2:
	return Vector2.ZERO

func is_select_just_pressed() -> bool:
	return false

func is_cancel_just_pressed() -> bool:
	return false

func is_select_held() -> bool:
	return false

func is_secondary_active() -> bool:
	return false
