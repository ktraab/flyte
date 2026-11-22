## Camera2D with pan (WASD / drag) and zoom (scroll / pinch).
class_name CourseCamera
extends Camera2D

const PAN_SPEED       := 500.0
const TOUCH_PAN_SCALE := 0.04   # raw pixel delta → normalized-equivalent (25px = full speed)
const ZOOM_SPEED := 0.12
const ZOOM_MIN   := Vector2(0.25, 0.25)
const ZOOM_MAX   := Vector2(2.5, 2.5)

func _ready() -> void:
	zoom = Vector2(0.65, 0.65)

func _process(delta: float) -> void:
	# Pan
	var dir := InputHandler.get_pan_direction()
	if InputHandler.mode == InputHandler.Mode.TOUCH:
		dir *= TOUCH_PAN_SCALE
	if dir != Vector2.ZERO:
		position += dir * PAN_SPEED * delta / zoom.x

	# Zoom (consume-on-read handled inside InputHandler)
	var dz := InputHandler.get_zoom_delta()
	if dz != 0.0:
		var new_z := clampf(zoom.x + dz * ZOOM_SPEED, ZOOM_MIN.x, ZOOM_MAX.x)
		zoom = Vector2(new_z, new_z)
