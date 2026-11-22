## Touch input for iOS / Android.
## Single finger: pan.  Two fingers: pinch-to-zoom.
## Tap (< TAP_MAX_TRAVEL px, < TAP_MAX_TIME s): select.
class_name TouchInputHandler
extends "res://input_handlers/BaseInputHandler.gd"

const PINCH_SENSITIVITY  := 0.005   # zoom units per pixel of pinch delta
const TAP_MAX_TRAVEL     := 12.0    # pixels — beyond this it's a drag, not a tap
const TAP_MAX_TIME       := 0.25    # seconds

var _touches: Dictionary = {}       # index → Vector2 position
var _touch_start: Dictionary = {}   # index → {pos, time}

var _pan_direction := Vector2.ZERO
var _zoom_delta    := 0.0
var _last_pinch_dist := 0.0

var _tap_fired     := false
var _select_held   := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_touch_start[event.index] = { "pos": event.position, "time": Time.get_ticks_msec() / 1000.0 }
		_select_held = true
		if _touches.size() == 2:
			_last_pinch_dist = _pinch_distance()
	else:
		# Check for tap on release
		if _touch_start.has(event.index):
			var start: Dictionary = _touch_start[event.index]
			var travel: float = event.position.distance_to(start["pos"])
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - start["time"]
			if travel < TAP_MAX_TRAVEL and elapsed < TAP_MAX_TIME and _touches.size() <= 1:
				_tap_fired = true
		_touches.erase(event.index)
		_touch_start.erase(event.index)
		if _touches.is_empty():
			_select_held = false
			_pan_direction = Vector2.ZERO
			_last_pinch_dist = 0.0

func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() == 2:
		# Two fingers — pinch zoom
		var dist := _pinch_distance()
		if _last_pinch_dist > 0.0:
			_zoom_delta += (dist - _last_pinch_dist) * PINCH_SENSITIVITY
		_last_pinch_dist = dist
		_pan_direction = Vector2.ZERO
	elif _touches.size() == 1:
		# Single finger — pan; preserve magnitude so slow drags pan slowly
		_pan_direction = event.relative

# ── API ───────────────────────────────────────────────────────────────────────

func get_pan_direction() -> Vector2:
	return _pan_direction

func get_zoom_delta() -> float:
	var d := _zoom_delta
	_zoom_delta = 0.0
	return d

func get_pointer_position() -> Vector2:
	if _touches.has(0):
		return _touches[0]
	return Vector2.ZERO

func is_select_just_pressed() -> bool:
	var fired := _tap_fired
	_tap_fired = false
	return fired

func is_cancel_just_pressed() -> bool:
	return Input.is_action_just_pressed("ui_cancel")

func is_select_held() -> bool:
	return _select_held

func is_secondary_active() -> bool:
	return _touches.size() >= 2

# ── Helpers ───────────────────────────────────────────────────────────────────

func _pinch_distance() -> float:
	var positions := _touches.values()
	if positions.size() < 2:
		return 0.0
	return positions[0].distance_to(positions[1])
