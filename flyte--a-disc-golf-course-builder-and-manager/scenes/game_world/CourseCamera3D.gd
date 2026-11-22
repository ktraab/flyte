## Orthographic isometric camera. Pan with WASD / arrow keys; zoom with scroll / pinch.
## Q / E to orbit (yaw) around the look-at centre.
class_name CourseCamera3D
extends Camera3D

const PAN_SPEED         := 58.0
const TOUCH_PAN_SCALE   := 0.04   # raw pixel delta → normalized-equivalent (25px = full speed)
const ZOOM_SPEED   := 3.5
const ZOOM_MIN     := 8.0
const ZOOM_MAX     := 200.0
const PAN_SMOOTH   := 10.0
const ZOOM_SMOOTH  := 8.0
const TILT_SPEED   := 1.2
const TILT_MIN     := -1.20
const TILT_MAX     := -0.30
const ORBIT_SPEED  := 1.4   # radians / second for Q/E yaw

# Camera is offset (+55, -90, -55) from its look-at point (set in Main.gd).
# lookat.x = cam.x + 55,  lookat.z = cam.z - 55.
# Clamp camera so the look-at stays within the 300×300 world (150×150 grid @ 2.0) + margin.
const CAM_X_MIN := -65.0    # lookat.x = -10
const CAM_X_MAX :=  255.0   # lookat.x = 310
const CAM_Z_MIN :=  45.0    # lookat.z = -10
const CAM_Z_MAX :=  365.0   # lookat.z = 310

var _target_pos:   Vector3
var _target_size:  float = 80.0
var _tilt_angle:   float = -1.05
var _yaw_angle:    float = 0.0   # synced from scene setup in _sync_target_pos

func _ready() -> void:
	projection   = Camera3D.PROJECTION_ORTHOGONAL
	size         = 80.0
	_target_size = size
	# Defer so Main.gd's look_at_from_position() runs first, then we lock
	# _target_pos to that position instead of the tscn default (0,0,0).
	call_deferred("_sync_target_pos")

func _sync_target_pos() -> void:
	_target_pos = global_position
	_yaw_angle  = rotation.y   # capture initial yaw from Main.gd look_at setup

func _process(delta: float) -> void:
	# Don't consume input while inactive (e.g. during play-test mode).
	if not current:
		return

	var dir := InputHandler.get_pan_direction()
	if InputHandler.mode == InputHandler.Mode.TOUCH:
		dir *= TOUCH_PAN_SCALE
	if dir != Vector2.ZERO:
		var right_flat   := Vector3(transform.basis.x.x, 0.0, transform.basis.x.z).normalized()
		var forward_flat := Vector3(-transform.basis.z.x, 0.0, -transform.basis.z.z).normalized()
		_target_pos += (right_flat * dir.x - forward_flat * dir.y) * PAN_SPEED * delta

	_target_pos.x = clampf(_target_pos.x, CAM_X_MIN, CAM_X_MAX)
	_target_pos.z = clampf(_target_pos.z, CAM_Z_MIN, CAM_Z_MAX)

	var dz := InputHandler.get_zoom_delta()
	if dz != 0.0:
		_target_size = clampf(_target_size - dz * ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)

	if Input.is_action_pressed("ui_page_up"):
		_tilt_angle = clampf(_tilt_angle + TILT_SPEED * delta, TILT_MIN, TILT_MAX)
	if Input.is_action_pressed("ui_page_down"):
		_tilt_angle = clampf(_tilt_angle - TILT_SPEED * delta, TILT_MIN, TILT_MAX)

	# Q / E: orbit (yaw) around look-at centre
	if Input.is_key_pressed(KEY_Q):
		_yaw_angle -= ORBIT_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		_yaw_angle += ORBIT_SPEED * delta

	position   = position.lerp(_target_pos, PAN_SMOOTH * delta)
	size       = lerpf(size, _target_size, ZOOM_SMOOTH * delta)
	rotation.x = lerpf(rotation.x, _tilt_angle, 6.0 * delta)
	rotation.y = lerpf(rotation.y, _yaw_angle, 6.0 * delta)

## Scripted fly-over (story intro pan). Runs while the tree is paused — the
## camera's own _process is paused then, so the tween has sole control.
## points: world positions to look at, in order. Returns the Tween.
const TOUR_ZOOM := 55.0

func play_tour(points: Array, travel: float = 1.8, hold: float = 0.6) -> Tween:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var first := true
	for p in points:
		var v: Vector3 = p as Vector3
		var to := Vector3(clampf(v.x - 55.0, CAM_X_MIN, CAM_X_MAX), position.y,
			clampf(v.z + 55.0, CAM_Z_MIN, CAM_Z_MAX))
		tw.tween_property(self, "position", to, travel)
		if first:
			tw.parallel().tween_property(self, "size", TOUR_ZOOM, travel)
			first = false
		tw.tween_interval(hold)
	tw.finished.connect(end_tour)
	return tw

## Keep the camera where the tour left it (no lerp back to the old target).
func end_tour() -> void:
	_target_pos  = position
	_target_size = size

func tilt_by(delta_rad: float) -> void:
	_tilt_angle = clampf(_tilt_angle + delta_rad, TILT_MIN, TILT_MAX)

func look_at_world_xz(world_x: float, world_z: float) -> void:
	_target_pos.x = clampf(world_x - 55.0, CAM_X_MIN, CAM_X_MAX)
	_target_pos.z = clampf(world_z + 55.0, CAM_Z_MIN, CAM_Z_MAX)

func set_target_zoom(zoom_size: float) -> void:
	_target_size = clampf(zoom_size, ZOOM_MIN, ZOOM_MAX)

## Returns the approximate world XZ ground point the camera is centred on.
func get_ground_center() -> Vector2:
	# cam offset from look-at: (-55, +90, +55) at yaw=0 (see Main.gd)
	var fwd := Vector3(-transform.basis.z.x, 0.0, -transform.basis.z.z).normalized()
	var side := Vector3(transform.basis.x.x, 0.0, transform.basis.x.z).normalized()
	# project camera ground position: camera is ~127 units above look-at horizontally
	var ground_x := global_position.x + fwd.x * 55.0 - side.x * 0.0
	var ground_z := global_position.z + fwd.z * 55.0 - side.z * 0.0
	return Vector2(ground_x, ground_z)
