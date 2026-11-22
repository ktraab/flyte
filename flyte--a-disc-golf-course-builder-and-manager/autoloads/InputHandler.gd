## Input abstraction layer. Swap desktop ↔ touch by calling set_mode().
## Game code always talks to InputHandler, never directly to Input or touch events.
extends Node

# Preload required — class_name types are not yet registered when autoloads parse
const _DesktopScript = preload("res://input_handlers/DesktopInputHandler.gd")
const _TouchScript   = preload("res://input_handlers/TouchInputHandler.gd")

enum Mode { DESKTOP, TOUCH }

var mode: Mode
var _handler: Node  # BaseInputHandler

func _ready() -> void:
	mode = Mode.TOUCH if PlatformDetector.is_mobile else Mode.DESKTOP
	_activate(mode)

func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	_activate(mode)

func _activate(m: Mode) -> void:
	if _handler:
		_handler.queue_free()
	_handler = _TouchScript.new() if m == Mode.TOUCH else _DesktopScript.new()
	add_child(_handler)

# ── Unified API ──────────────────────────────────────────────────────────────

func get_pan_direction() -> Vector2:
	return _handler.get_pan_direction()

func get_zoom_delta() -> float:
	return _handler.get_zoom_delta()

func get_pointer_position() -> Vector2:
	return _handler.get_pointer_position()

func is_select_just_pressed() -> bool:
	return _handler.is_select_just_pressed()

func is_cancel_just_pressed() -> bool:
	return _handler.is_cancel_just_pressed()

func is_select_held() -> bool:
	return _handler.is_select_held()

func is_secondary_active() -> bool:
	return _handler.is_secondary_active()
