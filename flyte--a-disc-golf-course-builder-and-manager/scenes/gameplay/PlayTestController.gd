## Overlay controller for player-driven course testing.
## Spawned as child of Gameplay when "Test Course" is pressed.
## Move mouse left/right to aim. Click to lock direction and open power bar. Click again to throw.
class_name PlayTestController
extends Control

enum Phase { AIMING, POWER, IN_FLIGHT, HOLE_COMPLETE, FINISHED }

const _Disc = preload("res://scenes/gameplay/DiscProjectile.gd")
const PREVIEW_DOTS := 28            # dotted flight-path preview while aiming
const MIN_THROW_DIST      := 0.5
const CLOSE_MISS_RADIUS   := 9.0   # show "so close!" feedback within this distance
const BASKET_AIM_SNAP_ANGLE := 0.82  # dot product threshold: ~35° — snap aim to basket when this close
const POWER_BAR_MIN_TIME    := 0.18  # seconds before power can be committed (prevents instant-click)

# Power bar zones (0-1 range)
const NICE_MIN := 0.38
const NICE_MAX := 0.68

var _charge_elapsed: float = 0.0   # seconds button has been held
const CHARGE_SPEED := 0.55         # 0→1 per second; nice zone hit at ~0.69–1.24s

# Disc type definitions.
# turn: right-curve in high-speed phase (world units at full throw distance)
# fade: left-curve in low-speed phase   (world units at full throw distance)
# deviation: random lateral noise (fraction of throw dist) at nice-zone power
# power_speed: how fast the power bar oscillates (0-1 range per second)
const DISC_TYPES := {
	"putter": {
		"label":       "Putter",
		"key":         "1",
		"max_dist":    44.0,
		"arc_mult":    0.07,
		"dur_mult":    0.08,
		"turn":         0.0,
		"fade":         1.2,
		"deviation":    0.0,
		"power_speed":  0.50,
		"color":       Color(1.00, 0.65, 0.20),
		"desc":        "Straight flight, gentle fade. Best for putting and short shots.",
	},
	"midrange": {
		"label":       "Mid-Range",
		"key":         "2",
		"max_dist":    76.0,
		"arc_mult":    0.10,
		"dur_mult":    0.065,
		"turn":         3.0,
		"fade":         3.5,
		"deviation":    0.03,
		"power_speed":  0.68,
		"color":       Color(0.35, 0.75, 1.00),
		"desc":        "Slight S-curve. Balanced distance and control.",
	},
	"fairway": {
		"label":       "Fairway Driver",
		"key":         "3",
		"max_dist":    110.0,
		"arc_mult":    0.08,
		"dur_mult":    0.055,
		"turn":         6.0,
		"fade":         6.0,
		"deviation":    0.07,
		"power_speed":  0.88,
		"color":       Color(0.45, 1.00, 0.40),
		"desc":        "Pronounced S-curve. Follow the dotted line, or aim at the basket and it compensates.",
	},
	"driver": {
		"label":       "Driver",
		"key":         "4",
		"max_dist":    145.0,
		"arc_mult":    0.07,
		"dur_mult":    0.046,
		"turn":        10.0,
		"fade":         9.0,
		"deviation":    0.12,
		"power_speed":  1.15,
		"color":       Color(1.00, 0.30, 0.30),
		"desc":        "Big S-curve: turns right, then fades hard left. The dotted line shows the flight.",
	},
}
const DISC_ORDER := ["putter", "midrange", "fairway", "driver"]

## Set before initialize() for an away round at a circuit course ("" = Test Course).
var away_course_name: String  = ""
var _holes:           Array   = []
var _hole_idx:        int     = 0
var _throws:          int     = 0
var _scores:          Array   = []
var _player_pos:      Vector3 = Vector3.ZERO
var _phase:           Phase   = Phase.AIMING
var _selected_disc:   String  = "midrange"

# Aim / power state
var _pending_target:  Vector3 = Vector3.INF   # throw target (set when charge begins)
var _power_t:         float   = 0.0           # 0–1 charge level (filled while button held)

var _active_disc:     Node3D   = null
var _aim_root:        Node3D   = null
var _path_root:       Node3D   = null    # flight-path preview dots (world space)
var _path_dots:       Array    = []
var _camera:          Camera3D = null   # active camera (3rd-person test cam while in test mode)
var _prev_camera:     Camera3D = null   # saved course camera — restored on exit
var _test_cam:        Camera3D = null
var _cam_pivot:       Node3D   = null
var _player_mesh:     Node3D   = null
var _aim_dir:         Vector3  = Vector3(0, 0, -1)   # current facing direction
var _aim_yaw:         float    = 0.0                  # horizontal rotation (radians)

const AIM_SENSITIVITY := 0.0015  # radians per pixel of mouse movement

# Player customization
var _player_shirt_color: Color = Color(0.25, 0.55, 0.9)
var _player_skin_color:  Color = Color(0.9, 0.75, 0.6)
var _player_body_mat:    StandardMaterial3D = null
var _player_head_mat:    StandardMaterial3D = null

# Camera occlusion — tree nodes hidden to keep player visible
var _occluded_props: Array = []   # tree cells hidden for camera occlusion

# UI refs
var _hud_panel:       PanelContainer
var _hud_label:       Label
var _hint_label:      Label
var _dist_label:      Label
var _fps_label:       Label
var _disc_buttons:    Dictionary = {}
var _forehand:        bool       = false   # false = backhand (RHBH), true = forehand (RHFH)
var _throw_btn:       Button     = null    # [F] toggle button
var _card_overlay:    PanelContainer
var _power_canvas:    CanvasLayer = null     # dedicated layer so power bar is always on top
var _power_panel:     PanelContainer
var _power_cursor:    ColorRect
var _power_rating:    Label      # "Low" / "Nice" / "High"
var _cust_overlay:    PanelContainer = null  # character customization overlay

# ── Public ────────────────────────────────────────────────────────────────────

func initialize(holes: Array) -> void:
	_holes = holes
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved: String = cfg.get_value("playtest", "disc", "midrange") as String
		if DISC_TYPES.has(saved):
			_selected_disc = saved
	_build_hud()
	_spawn_test_camera()
	_spawn_player_mesh()
	_start_hole(0)

func cleanup() -> void:
	_restore_occlusion()
	_destroy_aim_indicator()
	_destroy_power_bar()
	if _active_disc and is_instance_valid(_active_disc):
		_active_disc.call("pickup")
	_active_disc = null
	_restore_camera()
	if _player_mesh and is_instance_valid(_player_mesh):
		_player_mesh.queue_free()
	_player_mesh = null
	if _test_cam and is_instance_valid(_test_cam):
		_test_cam.current = false
		_test_cam.queue_free()
	_test_cam = null
	if _cam_pivot and is_instance_valid(_cam_pivot):
		_cam_pivot.queue_free()
	_cam_pivot = null
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.current = true
	_prev_camera = null

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Disc hotkeys — only in aiming phase
	if event is InputEventKey and (event as InputEventKey).pressed:
		var ke := event as InputEventKey
		match ke.keycode:
			KEY_1: _select_disc("putter");   get_viewport().set_input_as_handled(); return
			KEY_2: _select_disc("midrange"); get_viewport().set_input_as_handled(); return
			KEY_3: _select_disc("fairway");  get_viewport().set_input_as_handled(); return
			KEY_4: _select_disc("driver");   get_viewport().set_input_as_handled(); return
			KEY_F: _toggle_throw_type();     get_viewport().set_input_as_handled(); return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _phase == Phase.POWER:
			# Cancel power bar — return to aiming
			_destroy_power_bar()
			_pending_target = Vector3.INF
			_phase = Phase.AIMING
			_spawn_aim_indicator()
			_update_hud()
		else:
			_exit_test()
		return

	if event is InputEventMouseMotion and _phase == Phase.AIMING:
		var motion := event as InputEventMouseMotion
		_aim_yaw = wrapf(_aim_yaw - motion.relative.x * AIM_SENSITIVITY, -PI, PI)
		_aim_dir = Vector3(sin(_aim_yaw), 0, cos(_aim_yaw)).normalized()

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _phase == Phase.AIMING:
				get_viewport().set_input_as_handled()
				var max_dist: float = DISC_TYPES[_selected_disc]["max_dist"] as float
				_start_power_bar(_player_pos + _aim_dir * max_dist)
			elif not mb.pressed and _phase == Phase.POWER:
				get_viewport().set_input_as_handled()
				_commit_power()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _phase == Phase.AIMING:
			get_viewport().set_input_as_handled()
			var world_pos := _screen_to_world(mb.position)
			if world_pos != Vector3.INF:
				_teleport_player_to(world_pos)

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _fps_label and is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	match _phase:
		Phase.AIMING:
			_handle_player_movement(delta)
			_update_aim_indicator()
			_update_dist_label()
			_update_third_person_camera(_player_pos)
			_update_occlusion()
		Phase.POWER:
			_animate_power_bar(delta)
			_update_third_person_camera(_player_pos)
			_update_occlusion()
		Phase.IN_FLIGHT:
			if _active_disc and is_instance_valid(_active_disc):
				_follow_camera(_active_disc.global_position)
			_restore_occlusion()

# ── Power bar ─────────────────────────────────────────────────────────────────

func _start_power_bar(target: Vector3) -> void:
	_pending_target = target
	_phase          = Phase.POWER
	_charge_elapsed = 0.0
	_power_t        = 0.0
	_destroy_aim_indicator()
	_build_power_bar()
	_update_hud()

func _animate_power_bar(delta: float) -> void:
	_charge_elapsed += delta
	if not _power_panel or not is_instance_valid(_power_panel):
		_build_power_bar()
	_power_t = minf(_power_t + CHARGE_SPEED * delta, 1.0)
	_update_power_cursor()

func _commit_power() -> void:
	if _charge_elapsed < POWER_BAR_MIN_TIME:
		return
	var power := _power_t
	_destroy_power_bar()
	_throw_toward(_pending_target, power)
	_pending_target = Vector3.INF

func _build_power_bar() -> void:
	_destroy_power_bar()

	# Own CanvasLayer (layer 20) guarantees the bar renders above all game UI
	_power_canvas = CanvasLayer.new()
	_power_canvas.layer = 20
	add_child(_power_canvas)

	_power_panel = PanelContainer.new()
	_power_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_power_panel.offset_top    = -150.0
	_power_panel.offset_bottom = -55.0
	_power_panel.offset_left   = 120.0
	_power_panel.offset_right  = -120.0
	_power_panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	_power_canvas.add_child(_power_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_power_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Hold to charge — RELEASE mouse to throw!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	vbox.add_child(title)

	# Zone labels row
	var zone_labels := HBoxContainer.new()
	zone_labels.layout_mode = 2
	_make_zone_label(zone_labels, "Low", 0.25, Color(0.9, 0.4, 0.3))
	_make_zone_label(zone_labels, "OK",  0.13, Color(0.9, 0.75, 0.3))
	_make_zone_label(zone_labels, "NICE ★", 0.30, Color(0.3, 0.95, 0.4))
	_make_zone_label(zone_labels, "OK",  0.12, Color(0.9, 0.75, 0.3))
	_make_zone_label(zone_labels, "High", 0.20, Color(0.9, 0.4, 0.3))
	vbox.add_child(zone_labels)

	# Bar container (relative to this we overlay the cursor)
	var bar_wrap := Control.new()
	bar_wrap.layout_mode = 2
	bar_wrap.custom_minimum_size = Vector2(0, 32)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(bar_wrap)

	# Colored zone segments
	var bar_hbox := HBoxContainer.new()
	bar_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_hbox.add_theme_constant_override("separation", 0)
	bar_wrap.add_child(bar_hbox)
	_add_zone_rect(bar_hbox, 0.25, Color(0.55, 0.18, 0.12))
	_add_zone_rect(bar_hbox, 0.13, Color(0.55, 0.42, 0.10))
	_add_zone_rect(bar_hbox, 0.30, Color(0.12, 0.55, 0.18))
	_add_zone_rect(bar_hbox, 0.12, Color(0.55, 0.42, 0.10))
	_add_zone_rect(bar_hbox, 0.20, Color(0.55, 0.18, 0.12))

	# Fill rect — grows left→right as charge builds
	_power_cursor = ColorRect.new()
	_power_cursor.color = Color(0.25, 0.85, 0.35, 0.48)
	_power_cursor.anchor_left   = 0.0
	_power_cursor.anchor_right  = 0.0
	_power_cursor.anchor_top    = 0.0
	_power_cursor.anchor_bottom = 1.0
	_power_cursor.position = Vector2.ZERO
	_power_cursor.size     = Vector2.ZERO
	bar_wrap.add_child(_power_cursor)

	# Current rating label
	_power_rating = Label.new()
	_power_rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_rating.add_theme_font_size_override("font_size", 13)
	_power_rating.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_power_rating.text = "..."
	vbox.add_child(_power_rating)

func _make_zone_label(parent: HBoxContainer, text: String, frac: float, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = frac
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)

func _add_zone_rect(parent: HBoxContainer, frac: float, col: Color) -> void:
	var rect := ColorRect.new()
	rect.color = col
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_stretch_ratio = frac
	rect.custom_minimum_size = Vector2(0, 32)
	parent.add_child(rect)

func _update_power_cursor() -> void:
	if not _power_cursor or not is_instance_valid(_power_cursor):
		return
	var bar_wrap := _power_cursor.get_parent() as Control
	if not bar_wrap:
		return
	# Grow fill left→right based on charge level
	_power_cursor.size = Vector2(_power_t * bar_wrap.size.x, bar_wrap.size.y)
	if _power_t < NICE_MIN:
		_power_cursor.color = Color(0.85, 0.28, 0.18, 0.55)
	elif _power_t <= NICE_MAX:
		_power_cursor.color = Color(0.18, 0.85, 0.32, 0.52)
	else:
		_power_cursor.color = Color(0.90, 0.48, 0.12, 0.55)

	# Update rating label
	if _power_rating and is_instance_valid(_power_rating):
		if _power_t < 0.25:
			_power_rating.text = "Keep holding… (too short)"
			_power_rating.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		elif _power_t < NICE_MIN:
			_power_rating.text = "Almost… (release soon for short throw)"
			_power_rating.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		elif _power_t <= NICE_MAX:
			_power_rating.text = "RELEASE NOW  ★  Nice throw!"
			_power_rating.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
		elif _power_t < 0.88:
			_power_rating.text = "Overpowered — will hook"
			_power_rating.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		else:
			_power_rating.text = "MAX POWER — hard anhyzer!"
			_power_rating.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))

func _destroy_power_bar() -> void:
	if _power_canvas and is_instance_valid(_power_canvas):
		_power_canvas.queue_free()
	_power_canvas = null
	_power_panel = null
	_power_cursor = null
	_power_rating = null

# ── Hole management ───────────────────────────────────────────────────────────

func _start_hole(idx: int) -> void:
	_hole_idx   = idx
	_throws     = 0
	_player_pos = _holes[idx]["tee_pos"] as Vector3
	_phase      = Phase.AIMING
	# Aim toward basket at hole start
	var basket_pos: Vector3 = _holes[idx]["basket_pos"] as Vector3
	var to_basket := Vector3(basket_pos.x - _player_pos.x, 0.0, basket_pos.z - _player_pos.z)
	if to_basket.length_squared() > 0.01:
		_aim_yaw = atan2(to_basket.x, to_basket.z)
		_aim_dir = to_basket.normalized()
	_move_player_mesh(_player_pos)
	_update_hud()
	# Brief pan to basket so player sees the hole layout, then return to tee
	_pan_camera_to(basket_pos, 32.0)
	await get_tree().create_timer(1.2).timeout
	if _phase == Phase.AIMING:   # guard: player may have acted already
		_pan_camera_to(_player_pos, 40.0)
		_spawn_aim_indicator()

## Chance that a throw aimed straight at the basket (aim snapped) actually
## finds the chains, by distance. Putts used to be automatic.
const PUTT_CURVE := [[0.0, 0.99], [5.0, 0.95], [10.0, 0.70], [20.0, 0.35], [30.0, 0.10], [40.0, 0.03]]

static func putt_make_chance(dist: float) -> float:
	if dist <= 0.0:
		return PUTT_CURVE[0][1]
	for i in range(1, PUTT_CURVE.size()):
		var a: Array = PUTT_CURVE[i - 1]
		var b: Array = PUTT_CURVE[i]
		if dist <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (dist - float(a[0])) / (float(b[0]) - float(a[0])))
	return PUTT_CURVE[PUTT_CURVE.size() - 1][1]

## Where a snapped throw is aimed: the basket itself, or (a miss) 0.6–1.2 m to
## one side and a little long/short — close enough to glance the cage and leave
## a tap-in. `dir` = flat throw direction (normalised).
static func putt_target(basket: Vector3, dir: Vector3, dist: float, rng: RandomNumberGenerator) -> Vector3:
	if rng.randf() <= putt_make_chance(dist):
		return basket
	var side := Vector3(-dir.z, 0.0, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	return basket + side * rng.randf_range(0.6, 1.2) + dir * rng.randf_range(-0.4, 0.8)

## Everything about a throw before it leaves the hand. rng = null → no random
## deviation (used by the aim preview, which shows the intended flight).
func _plan_throw(world_pos: Vector3, power: float, rng: RandomNumberGenerator) -> Dictionary:
	var disc_info: Dictionary = DISC_TYPES[_selected_disc]
	var max_dist: float = disc_info["max_dist"] as float
	var snapped := false
	var basket_pos := Vector3.INF
	if _hole_idx < _holes.size():
		basket_pos = _holes[_hole_idx]["basket_pos"] as Vector3
		# Aim assist: aiming close to the basket and it's in range → throw at it
		var to_basket := Vector3(basket_pos.x - _player_pos.x, 0.0, basket_pos.z - _player_pos.z)
		var basket_dist := to_basket.length()
		if basket_dist < max_dist * 1.05 and basket_dist > 0.1 \
				and _aim_dir.dot(to_basket.normalized()) >= BASKET_AIM_SNAP_ANGLE:
			world_pos = basket_pos
			snapped = true

	var raw_dist: float = _player_pos.distance_to(world_pos)
	# Power: nice zone = full distance, no penalty; low = short + wobble; high = hook
	var dist_mult: float
	var extra_dev: float
	if power < NICE_MIN:
		dist_mult = lerpf(0.0, 1.0, power / NICE_MIN)
		extra_dev = (NICE_MIN - power) / NICE_MIN * 0.25
	elif power <= NICE_MAX:
		dist_mult = 1.0
		extra_dev = 0.0
	else:
		dist_mult = 1.0
		extra_dev = (power - NICE_MAX) / (1.0 - NICE_MAX) * 0.30

	var capped_dist := minf(raw_dist * dist_mult, max_dist)
	var frac := clampf(capped_dist / max_dist, 0.2, 1.0)
	var fh_sign := -1.0 if _forehand else 1.0
	var flat_target := Vector3(world_pos.x - _player_pos.x, 0.0, world_pos.z - _player_pos.z)
	var dir := flat_target.normalized() if flat_target.length_squared() > 0.0001 else _aim_dir

	var total_dev: float = (disc_info["deviation"] as float) + extra_dev
	if rng != null and total_dev > 0.0:
		var side_shift := rng.randf_range(-total_dev, total_dev)
		dir = (dir + Vector3(-dir.z, 0.0, dir.x) * side_shift).normalized()

	var ground_to := _player_pos + dir * capped_dist
	# Real throws at the basket can miss (the aim preview, rng == null, can't).
	if snapped and rng != null and dist_mult >= 1.0:
		ground_to = putt_target(basket_pos, dir, raw_dist, rng)
	var world := GameManager.world as GameWorld3D
	if world:
		ground_to.y = world.get_ground_y(ground_to)
	return {
		"from":    Vector3(_player_pos.x, _player_pos.y + 1.2, _player_pos.z),
		"to":      ground_to,
		"arc":     clampf(capped_dist * (disc_info["arc_mult"] as float), 1.0, 12.0),
		"dur":     clampf(capped_dist * (disc_info["dur_mult"] as float), 0.6, 3.2),
		"turn":    fh_sign * (disc_info["turn"] as float) * frac,
		"fade":    fh_sign * (disc_info["fade"] as float) * frac,
		"snapped": snapped,
		"basket":  basket_pos,
	}

func _throw_toward(world_pos: Vector3, power: float) -> void:
	_throws += 1
	_phase   = Phase.IN_FLIGHT
	_destroy_aim_indicator()
	_update_hud()

	var world_node := GameManager.world
	if not world_node:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var plan := _plan_throw(world_pos, power, rng)
	var disc: Node3D = _Disc.new()
	world_node.add_child(disc)
	disc.set("hole_num", _hole_idx)
	disc.set("disc_color", DISC_TYPES[_selected_disc]["color"] as Color)
	disc.set("_turn", plan["turn"])
	disc.set("_fade", plan["fade"])
	disc.set("basket_pos", plan["basket"])
	disc.set("aim_compensate", plan["snapped"])
	disc.call("launch", plan["from"], plan["to"], plan["arc"], plan["dur"])
	EventBus.disc_launched.emit()

	_active_disc = disc
	(disc as Object).connect("landed", _on_disc_landed)

func _on_disc_landed(land_pos: Vector3, penalty: int) -> void:
	_throws += penalty

	var basket_pos  := _holes[_hole_idx]["basket_pos"] as Vector3
	var dist_to_basket := Vector2(land_pos.x - basket_pos.x, land_pos.z - basket_pos.z).length()
	var holed := false

	if _active_disc and is_instance_valid(_active_disc):
		holed = bool(_active_disc.get("in_basket"))
		_active_disc.call("pickup")
	_active_disc = null
	EventBus.disc_landed.emit(penalty)

	if holed:
		land_pos = basket_pos
		_hole_complete(land_pos)
	else:
		_player_pos = Vector3(land_pos.x, land_pos.y, land_pos.z)
		_move_player_mesh(_player_pos)
		_phase = Phase.AIMING
		_pan_camera_to(_player_pos, 40.0)
		_spawn_aim_indicator()
		_update_hud()
		# Close miss feedback
		if dist_to_basket <= CLOSE_MISS_RADIUS:
			var world := GameManager.world as GameWorld3D
			if world:
				var msg := "%.1f m away!" % dist_to_basket
				world.spawn_score_popup(land_pos + Vector3(0, 0.5, 0), msg, Color(1.0, 0.75, 0.2))

func _hole_complete(pos: Vector3) -> void:
	_phase = Phase.HOLE_COMPLETE
	_scores.append(_throws)
	var par  := _holes[_hole_idx]["par"] as int
	var diff := _throws - par
	var world := GameManager.world as GameWorld3D
	if world:
		world.spawn_score_popup(pos + Vector3(0, 1, 0), _score_name(diff), _score_color(diff))

	if _hole_idx + 1 >= _holes.size():
		_phase = Phase.FINISHED
		await get_tree().create_timer(1.8).timeout
		_show_scorecard()
	else:
		await get_tree().create_timer(1.5).timeout
		_start_hole(_hole_idx + 1)

# ── Disc selection ─────────────────────────────────────────────────────────────

func _select_disc(key: String) -> void:
	if not DISC_TYPES.has(key):
		return
	_selected_disc = key
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("playtest", "disc", key)
	cfg.save("user://settings.cfg")
	_update_disc_buttons()
	if _phase == Phase.AIMING:
		_spawn_aim_indicator()
	_update_hud()

func _toggle_throw_type() -> void:
	_forehand = not _forehand
	_update_throw_button()
	_update_hud()

func _update_throw_button() -> void:
	if not _throw_btn or not is_instance_valid(_throw_btn):
		return
	if _forehand:
		_throw_btn.text = "[F] Forehand ↙"
		_throw_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	else:
		_throw_btn.text = "[F] Backhand ↗"
		_throw_btn.remove_theme_color_override("font_color")

func _update_disc_buttons() -> void:
	var disc_info: Dictionary = DISC_TYPES[_selected_disc]
	var active_color: Color = disc_info["color"] as Color
	for key in _disc_buttons:
		var btn := _disc_buttons[key] as Button
		if not btn or not is_instance_valid(btn):
			continue
		if key == _selected_disc:
			btn.add_theme_color_override("font_color", active_color)
			var sb := StyleBoxFlat.new()
			sb.bg_color = active_color * 0.25
			sb.border_color = active_color
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", sb)
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")

# ── Aim indicator ─────────────────────────────────────────────────────────────

func _spawn_aim_indicator() -> void:
	_destroy_aim_indicator()
	var world := GameManager.world
	if not world:
		return
	_aim_root = Node3D.new()
	_aim_root.position = Vector3(_player_pos.x, _player_pos.y + 0.08, _player_pos.z)
	world.add_child(_aim_root)

	var disc_info: Dictionary = DISC_TYPES[_selected_disc]
	var disc_color: Color = disc_info["color"] as Color

	var mat := StandardMaterial3D.new()
	mat.albedo_color     = disc_color
	mat.emission_enabled = true
	mat.emission         = disc_color * 0.55

	# Shaft
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.11, 0.05, 1.0)
	shaft_mesh.surface_set_material(0, mat)
	var shaft_mi := MeshInstance3D.new()
	shaft_mi.mesh        = shaft_mesh
	shaft_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft_mi.position    = Vector3(0, 0, -0.5)
	_aim_root.add_child(shaft_mi)

	# Arrowhead
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius    = 0.0
	head_mesh.bottom_radius = 0.20
	head_mesh.height        = 0.38
	head_mesh.surface_set_material(0, mat)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh        = head_mesh
	head_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_mi.rotation    = Vector3(0, 0, PI * 0.5)
	head_mi.position    = Vector3(0, 0, -1.10)
	_aim_root.add_child(head_mi)

	# Max-range circle
	_spawn_range_ring(disc_color, disc_info["max_dist"] as float)

func _spawn_range_ring(color: Color, radius: float) -> void:
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color     = Color(color.r, color.g, color.b, 0.30)
	ring_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission         = color * 0.20
	var segments := 48
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for i in segments:
		var a0 := float(i)     / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU
		st.add_vertex(Vector3(sin(a0) * radius, 0.05, cos(a0) * radius))
		st.add_vertex(Vector3(sin(a1) * radius, 0.05, cos(a1) * radius))
	var ring_mesh := st.commit()
	ring_mesh.surface_set_material(0, ring_mat)
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh        = ring_mesh
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_root.add_child(ring_mi)

func _update_aim_indicator() -> void:
	if not _aim_root or not is_instance_valid(_aim_root):
		return
	_move_player_mesh(_player_pos)
	_aim_root.position = Vector3(_player_pos.x, _player_pos.y + 0.08, _player_pos.z)
	_aim_root.look_at(_aim_root.position + _aim_dir, Vector3.UP)
	_update_flight_preview()
	var max_dist: float = DISC_TYPES[_selected_disc]["max_dist"] as float
	var scale_z := remap(max_dist * 0.45, 0.5, max_dist, 0.3, 2.5)
	if _aim_root.get_child_count() > 0:
		var shaft := _aim_root.get_child(0) as MeshInstance3D
		if shaft:
			shaft.scale.z = scale_z
			shaft.position.z = -0.5 * scale_z

func _destroy_aim_indicator() -> void:
	if _aim_root and is_instance_valid(_aim_root):
		_aim_root.queue_free()
	_aim_root = null
	if _path_root and is_instance_valid(_path_root):
		_path_root.queue_free()
	_path_root = null
	_path_dots.clear()

## Dotted line along the flight a nice-power throw would take right now
## (turn, fade, wind, aim assist), so players can see the curve and play it.
func _update_flight_preview() -> void:
	var world := GameManager.world as GameWorld3D
	if world == null:
		return
	if _path_root == null or not is_instance_valid(_path_root):
		_path_root = Node3D.new()
		world.add_child(_path_root)
		_path_dots.clear()
		var col: Color = DISC_TYPES[_selected_disc]["color"] as Color
		var m := SphereMesh.new()
		m.radius = 0.09; m.height = 0.18; m.radial_segments = 8; m.rings = 4
		for i in PREVIEW_DOTS:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(col.r, col.g, col.b, lerpf(0.95, 0.35, float(i) / PREVIEW_DOTS))
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_path_root.add_child(mi)
			_path_dots.append(mi)
	var max_dist: float = DISC_TYPES[_selected_disc]["max_dist"] as float
	var plan := _plan_throw(_player_pos + _aim_dir * max_dist, (NICE_MIN + NICE_MAX) * 0.5, null)
	var to: Vector3 = _Disc.aim_point(plan["to"], plan["basket"])
	var p := _Disc.flight_params(plan["from"], to, plan["arc"], plan["dur"],
		plan["turn"], plan["fade"], world.get_wind_vector(), plan["snapped"])
	for i in _path_dots.size():
		var t := float(i + 1) / float(_path_dots.size())
		(_path_dots[i] as Node3D).global_position = _Disc.flight_point(p, t)

# ── Camera ────────────────────────────────────────────────────────────────────

func _spawn_test_camera() -> void:
	_prev_camera = get_viewport().get_camera_3d()
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.current = false
	var world_node := GameManager.world
	if not world_node:
		return
	_cam_pivot = Node3D.new()
	world_node.add_child(_cam_pivot)
	_test_cam = Camera3D.new()
	_test_cam.fov  = 65.0
	_test_cam.near = 0.1
	_cam_pivot.add_child(_test_cam)
	_test_cam.current = true
	_camera = _test_cam

func _spawn_player_mesh() -> void:
	var world_node := GameManager.world
	if not world_node:
		return
	_player_mesh = Node3D.new()
	_player_mesh.scale = Vector3(1.6, 1.6, 1.6)   # match NPC scale
	world_node.add_child(_player_mesh)
	# Body
	_player_body_mat = StandardMaterial3D.new()
	_player_body_mat.albedo_color = _player_shirt_color
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.4
	body_mesh.surface_set_material(0, _player_body_mat)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body_mesh
	body_mi.position = Vector3(0, 0.7, 0)
	_player_mesh.add_child(body_mi)
	# Head
	_player_head_mat = StandardMaterial3D.new()
	_player_head_mat.albedo_color = _player_skin_color
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head_mesh.surface_set_material(0, _player_head_mat)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head_mesh
	head_mi.position = Vector3(0, 1.6, 0)
	_player_mesh.add_child(head_mi)
	_move_player_mesh(_player_pos)

func _move_player_mesh(pos: Vector3) -> void:
	if not _player_mesh or not is_instance_valid(_player_mesh):
		return
	_player_mesh.position = pos
	if _aim_dir.length_squared() > 0.001:
		_player_mesh.look_at(pos + _aim_dir, Vector3.UP)

func _update_third_person_camera(focus_pos: Vector3) -> void:
	if not _cam_pivot or not is_instance_valid(_cam_pivot):
		return
	if not _test_cam or not is_instance_valid(_test_cam):
		return
	# Smooth pivot toward player — reduces jitter on aim direction changes
	var delta := get_process_delta_time()
	var smooth := clampf(10.0 * delta, 0.0, 1.0)
	_cam_pivot.global_position = _cam_pivot.global_position.lerp(focus_pos, smooth)
	var back := -_aim_dir if _aim_dir.length_squared() > 0.001 else Vector3(0, 0, 1)
	var target_offset := back * 11.0 + Vector3(0, 6.0, 0)
	_test_cam.position = _test_cam.position.lerp(target_offset, smooth)
	# Look toward a point ahead of player so basket is visible in frame
	var look_fwd := _aim_dir * 22.0 if _aim_dir.length_squared() > 0.001 else Vector3.ZERO
	_test_cam.look_at(_cam_pivot.global_position + look_fwd + Vector3(0, 1.0, 0), Vector3.UP)

func _pan_camera_to(world_pos: Vector3, _zoom: float = 40.0) -> void:
	if _test_cam and is_instance_valid(_test_cam):
		if _cam_pivot and is_instance_valid(_cam_pivot):
			_cam_pivot.global_position = world_pos
		return
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if not _camera or not _camera.has_method("look_at_world_xz"):
		return
	_camera.call("look_at_world_xz", world_pos.x, world_pos.z)
	_camera.call("set_target_zoom", _zoom)

func _follow_camera(world_pos: Vector3) -> void:
	if _test_cam and is_instance_valid(_test_cam):
		if _cam_pivot and is_instance_valid(_cam_pivot):
			_cam_pivot.global_position = world_pos
			_test_cam.look_at(world_pos + Vector3(0, 0.5, 0), Vector3.UP)
		return
	if _camera and _camera.has_method("look_at_world_xz"):
		_camera.call("look_at_world_xz", world_pos.x, world_pos.z)
		_camera.call("set_target_zoom", 28.0)

func _restore_camera() -> void:
	if _test_cam and is_instance_valid(_test_cam):
		return  # cleanup() handles restoration
	if _camera and _camera.has_method("set_target_zoom"):
		_camera.call("set_target_zoom", 80.0)

# ── Raycast ───────────────────────────────────────────────────────────────────

func _screen_to_world(screen_pos: Vector2) -> Vector3:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if not _camera:
		return Vector3.INF
	var origin    := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return Vector3.INF
	var t := (_player_pos.y - origin.y) / direction.y
	if t < 0:
		return Vector3.INF
	return origin + direction * t

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hud_panel = PanelContainer.new()
	_hud_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_panel.offset_top    = 112.0
	_hud_panel.offset_bottom = 210.0
	_hud_panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_hud_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_hud_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "TEST MODE" if away_course_name == "" else "AWAY ROUND — %s" % away_course_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(title_lbl)

	_hud_label = Label.new()
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_hud_label)

	_dist_label = Label.new()
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dist_label.add_theme_font_size_override("font_size", 13)
	_dist_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(_dist_label)

	# Disc selector row
	var disc_row := HBoxContainer.new()
	disc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	disc_row.add_theme_constant_override("separation", 6)
	vbox.add_child(disc_row)

	for key in DISC_ORDER:
		var info: Dictionary = DISC_TYPES[key]
		var btn := Button.new()
		btn.text = "[%s] %s" % [info["key"] as String, info["label"] as String]
		btn.custom_minimum_size = Vector2(120, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = info["desc"] as String
		var k: String = key
		btn.pressed.connect(func() -> void: _select_disc(k))
		disc_row.add_child(btn)
		_disc_buttons[key] = btn

	# Throw type toggle
	_throw_btn = Button.new()
	_throw_btn.custom_minimum_size = Vector2(140, 30)
	_throw_btn.add_theme_font_size_override("font_size", 12)
	_throw_btn.tooltip_text = "Forehand: curve mirrors backhand — disc turns left, fades right."
	_throw_btn.pressed.connect(_toggle_throw_type)
	disc_row.add_child(_throw_btn)
	_update_throw_button()

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_hint_label)

	# FPS label (top-right corner, outside the HUD panel)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-88.0, 2.0)
	_fps_label.text = "FPS: —"
	add_child(_fps_label)

	# Customize button (top-right, below exit)
	var cust_btn := Button.new()
	cust_btn.text = "👕 Customize"
	cust_btn.custom_minimum_size = Vector2(140, 32)
	cust_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cust_btn.position = Vector2(-155, 154)
	cust_btn.pressed.connect(_toggle_customize)
	add_child(cust_btn)

	# Exit button (top-right)
	var exit_btn := Button.new()
	exit_btn.text = "Exit Test  [Esc]" if away_course_name == "" else "Head Home  [Esc]"
	exit_btn.custom_minimum_size = Vector2(140, 32)
	exit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	exit_btn.position = Vector2(-155, 118)
	exit_btn.pressed.connect(_exit_test)
	add_child(exit_btn)

	_update_disc_buttons()

func _toggle_customize() -> void:
	if _cust_overlay and is_instance_valid(_cust_overlay):
		_cust_overlay.queue_free()
		_cust_overlay = null
		return
	_build_customize_overlay()

func _build_customize_overlay() -> void:
	_cust_overlay = PanelContainer.new()
	_cust_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cust_overlay.offset_left   = -340.0
	_cust_overlay.offset_right  = -10.0
	_cust_overlay.offset_top    = 192.0
	_cust_overlay.offset_bottom = 370.0
	_cust_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_cust_overlay)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_cust_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.layout_mode = 2
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Character Customization"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.75))
	vbox.add_child(title_lbl)
	vbox.add_child(HSeparator.new())

	# Shirt color row
	var shirt_row := HBoxContainer.new()
	shirt_row.add_theme_constant_override("separation", 4)
	var shirt_lbl := Label.new()
	shirt_lbl.text = "Shirt:"
	shirt_lbl.add_theme_font_size_override("font_size", 11)
	shirt_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	shirt_lbl.custom_minimum_size = Vector2(38, 0)
	shirt_row.add_child(shirt_lbl)
	var shirt_colors: Array[Color] = [
		Color(0.25, 0.55, 0.9),  Color(0.9, 0.25, 0.25), Color(0.25, 0.75, 0.30),
		Color(0.9, 0.75, 0.1),   Color(0.7, 0.25, 0.9),  Color(0.9, 0.9, 0.9),
		Color(0.15, 0.15, 0.15), Color(0.85, 0.42, 0.12), Color(0.10, 0.50, 0.55),
	]
	for sc: Color in shirt_colors:
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(24, 24)
		var ss := StyleBoxFlat.new()
		ss.bg_color = sc; ss.set_corner_radius_all(3)
		sb.add_theme_stylebox_override("normal", ss)
		sb.add_theme_stylebox_override("hover", ss)
		sb.add_theme_stylebox_override("pressed", ss)
		var sc_copy := sc
		sb.pressed.connect(func() -> void:
			_player_shirt_color = sc_copy
			if _player_body_mat and is_instance_valid(_player_body_mat):
				_player_body_mat.albedo_color = sc_copy)
		shirt_row.add_child(sb)
	vbox.add_child(shirt_row)

	# Skin color row
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 4)
	var skin_lbl := Label.new()
	skin_lbl.text = "Skin:"
	skin_lbl.add_theme_font_size_override("font_size", 11)
	skin_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	skin_lbl.custom_minimum_size = Vector2(38, 0)
	skin_row.add_child(skin_lbl)
	var skin_colors: Array[Color] = [
		Color(0.9, 0.75, 0.6), Color(0.8, 0.60, 0.42),
		Color(0.55, 0.35, 0.18), Color(0.30, 0.18, 0.08),
	]
	for sk: Color in skin_colors:
		var skb := Button.new()
		skb.custom_minimum_size = Vector2(24, 24)
		var sks := StyleBoxFlat.new()
		sks.bg_color = sk; sks.set_corner_radius_all(3)
		skb.add_theme_stylebox_override("normal", sks)
		skb.add_theme_stylebox_override("hover", sks)
		skb.add_theme_stylebox_override("pressed", sks)
		var sk_copy := sk
		skb.pressed.connect(func() -> void:
			_player_skin_color = sk_copy
			if _player_head_mat and is_instance_valid(_player_head_mat):
				_player_head_mat.albedo_color = sk_copy)
		skin_row.add_child(skb)
	vbox.add_child(skin_row)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void:
		if _cust_overlay and is_instance_valid(_cust_overlay):
			_cust_overlay.queue_free()
			_cust_overlay = null)
	vbox.add_child(close_btn)

func _update_hud() -> void:
	if not _hud_label or _hole_idx >= _holes.size():
		return
	var par  := _holes[_hole_idx]["par"] as int
	var diff := _throws - par
	var diff_str := ""
	if _throws > 0:
		diff_str = "  E" if diff == 0 else ("  +%d" % diff if diff > 0 else "  %d" % diff)
	_hud_label.text = "Hole %d/%d  |  Par %d  |  Throws: %d%s" % [
		_hole_idx + 1, _holes.size(), par, _throws, diff_str]
	if _hint_label:
		var wind_str := ""
		var world := GameManager.world as GameWorld3D
		if world:
			var wv: Vector2 = world.get_wind_vector()
			var wspd := wv.length()
			if wspd < 0.3:
				wind_str = "  |  Wind: calm"
			else:
				var wdir := ""
				var wa := atan2(wv.x, wv.y)
				if wa < -2.356: wdir = "S"
				elif wa < -1.178: wdir = "SW"
				elif wa < 0.0: wdir = "W"
				elif wa < 1.178: wdir = "NW"
				elif wa < 2.356: wdir = "N"
				else: wdir = "NE"
				wind_str = "  |  Wind: %.1f %s" % [wspd, wdir]
		match _phase:
			Phase.AIMING:
				var info: Dictionary = DISC_TYPES[_selected_disc]
				var throw_str := "Forehand [F]" if _forehand else "Backhand [F]"
				_hint_label.text = "%s · %s — max %.0f m  |  WASD/Right-click to move · Mouse to aim · Click to throw%s" % [
					info["label"] as String, throw_str, info["max_dist"] as float, wind_str]
			Phase.POWER:
				_hint_label.text = "Release mouse to throw — [Esc] to cancel%s" % wind_str
			Phase.IN_FLIGHT:
				_hint_label.text = "Disc in flight…%s" % wind_str
			Phase.HOLE_COMPLETE:
				_hint_label.text = "Hole complete!"

func _update_dist_label() -> void:
	if not _dist_label or _hole_idx >= _holes.size():
		return
	if _phase != Phase.AIMING:
		_dist_label.text = ""
		return
	var basket_pos := _holes[_hole_idx]["basket_pos"] as Vector3
	var dist_to_basket := int(_player_pos.distance_to(basket_pos))
	var max_dist: int = int(DISC_TYPES[_selected_disc]["max_dist"] as float)
	var in_range := "✓" if dist_to_basket <= max_dist else "—"
	_dist_label.text = "To basket: %d m  |  Max range: %d m  %s" % [dist_to_basket, max_dist, in_range]

func _show_scorecard() -> void:
	_destroy_aim_indicator()
	if _card_overlay:
		_card_overlay.queue_free()

	_card_overlay = PanelContainer.new()
	_card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_overlay.offset_left   =  60.0
	_card_overlay.offset_right  = -60.0
	_card_overlay.offset_top    =  40.0
	_card_overlay.offset_bottom = -40.0
	_card_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_card_overlay)

	var outer := VBoxContainer.new()
	outer.layout_mode = 2
	outer.add_theme_constant_override("separation", 0)
	_card_overlay.add_child(outer)

	# ── Header ──
	var hdr_margin := MarginContainer.new()
	hdr_margin.add_theme_constant_override("margin_left", 20)
	hdr_margin.add_theme_constant_override("margin_right", 20)
	hdr_margin.add_theme_constant_override("margin_top", 14)
	hdr_margin.add_theme_constant_override("margin_bottom", 8)
	outer.add_child(hdr_margin)

	var title := Label.new()
	title.text = "ROUND SCORECARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.88, 0.95, 0.80))
	hdr_margin.add_child(title)
	outer.add_child(HSeparator.new())

	# ── Scrollable hole rows ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	outer.add_child(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(rows_vbox)

	var hdr_margin2 := MarginContainer.new()
	for s in ["left","right"]:
		hdr_margin2.add_theme_constant_override("margin_" + s, 12)
	rows_vbox.add_child(hdr_margin2)
	hdr_margin2.add_child(_card_row5("HOLE", "PAR", "SCORE", "+/-", "RATING", true))
	rows_vbox.add_child(HSeparator.new())

	var total_throws := 0
	var total_par    := 0
	var best_diff    := 999
	var best_hole    := -1
	var tally        := {"condor":0,"albatross":0,"eagle":0,"birdie":0,"par":0,"bogey":0,"double":0,"worse":0}

	for i in _scores.size():
		var par  := _holes[i]["par"] as int
		var sc   := _scores[i] as int
		var diff := sc - par
		total_throws += sc
		total_par    += par

		if diff < best_diff:
			best_diff = diff
			best_hole = i

		match diff:
			-4:  tally["condor"]    += 1
			-3:  tally["albatross"] += 1
			-2:  tally["eagle"]     += 1
			-1:  tally["birdie"]    += 1
			0:   tally["par"]       += 1
			1:   tally["bogey"]     += 1
			2:   tally["double"]    += 1
			_:   if diff > 2: tally["worse"] += 1

		var diff_str   := "E" if diff == 0 else ("+%d" % diff if diff > 0 else str(diff))
		var name_str   := _score_name(diff)
		var row_margin := MarginContainer.new()
		for s in ["left","right"]:
			row_margin.add_theme_constant_override("margin_" + s, 12)

		var row := _card_row5(
			"  %d" % (i + 1), "%d" % par, "%d" % sc, diff_str, name_str, false)
		# Color the entire row subtly
		var row_sb := StyleBoxFlat.new()
		var rc     := _score_color(diff)
		row_sb.bg_color = Color(rc.r, rc.g, rc.b, 0.12 if i == best_hole else 0.06)
		if i == best_hole:
			row_sb.border_width_left = 3
			row_sb.border_color = rc.lightened(0.2)
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", row_sb)
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_child(row_margin)
		row_margin.add_child(row)

		# Color diff and name labels
		(row.get_child(3) as Label).add_theme_color_override("font_color", rc)
		(row.get_child(4) as Label).add_theme_color_override("font_color", rc.lightened(0.15))
		rows_vbox.add_child(row_panel)

	# ── Totals ──
	outer.add_child(HSeparator.new())
	var totals_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		totals_margin.add_theme_constant_override("margin_" + s, 12)
	outer.add_child(totals_margin)
	var totals_vbox := VBoxContainer.new()
	totals_vbox.add_theme_constant_override("separation", 6)
	totals_margin.add_child(totals_vbox)

	var td    := total_throws - total_par
	var tdstr := "E" if td == 0 else ("+%d" % td if td > 0 else str(td))
	var total_row := _card_row5("TOTAL", "%d" % total_par, "%d" % total_throws, tdstr, "", true)
	var tdc := _score_color(td)
	(total_row.get_child(3) as Label).add_theme_color_override("font_color", tdc)
	totals_vbox.add_child(total_row)

	# Best hole callout
	if best_hole >= 0:
		var best_lbl := Label.new()
		var bd := _scores[best_hole] as int - (_holes[best_hole]["par"] as int)
		best_lbl.text = "Best hole: #%d — %s" % [best_hole + 1, _score_name(bd)]
		best_lbl.add_theme_font_size_override("font_size", 12)
		best_lbl.add_theme_color_override("font_color", _score_color(bd).lightened(0.2))
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		totals_vbox.add_child(best_lbl)

	# Score summary
	outer.add_child(HSeparator.new())
	var summary_margin := MarginContainer.new()
	for s in ["left","right"]:
		summary_margin.add_theme_constant_override("margin_" + s, 16)
	summary_margin.add_theme_constant_override("margin_top", 6)
	summary_margin.add_theme_constant_override("margin_bottom", 4)
	outer.add_child(summary_margin)
	var summary_hbox := HBoxContainer.new()
	summary_hbox.add_theme_constant_override("separation", 14)
	summary_margin.add_child(summary_hbox)

	var summary_entries := []
	if tally["condor"]    > 0: summary_entries.append(["Condor",    tally["condor"],    Color(1.0, 0.9, 0.0)])
	if tally["albatross"] > 0: summary_entries.append(["Albatross", tally["albatross"], Color(1.0, 0.85, 0.0)])
	if tally["eagle"]     > 0: summary_entries.append(["Eagle",     tally["eagle"],     Color(0.95, 0.78, 0.10)])
	if tally["birdie"]    > 0: summary_entries.append(["Birdie",    tally["birdie"],     Color(0.25, 0.90, 0.35)])
	if tally["par"]       > 0: summary_entries.append(["Par",       tally["par"],        Color(0.75, 0.75, 0.75)])
	if tally["bogey"]     > 0: summary_entries.append(["Bogey",     tally["bogey"],      Color(0.90, 0.45, 0.30)])
	if tally["double"]    > 0: summary_entries.append(["Dbl Bogey", tally["double"],     Color(0.85, 0.25, 0.20)])
	if tally["worse"]     > 0: summary_entries.append(["Worse",     tally["worse"],      Color(0.70, 0.15, 0.15)])

	for entry in summary_entries:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 1)
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count_lbl := Label.new()
		count_lbl.text = str(entry[1] as int)
		count_lbl.add_theme_font_size_override("font_size", 18)
		count_lbl.add_theme_color_override("font_color", entry[2] as Color)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(count_lbl)
		var name_lbl := Label.new()
		name_lbl.text = entry[0] as String
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.60, 0.65, 0.58))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sv.add_child(name_lbl)
		summary_hbox.add_child(sv)

	# ── Buttons ──
	outer.add_child(HSeparator.new())
	var btn_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		btn_margin.add_theme_constant_override("margin_" + s, 10)
	outer.add_child(btn_margin)
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_margin.add_child(btn_hbox)

	var play_again_btn := Button.new()
	play_again_btn.text = "▶  Play Again"
	play_again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_again_btn.custom_minimum_size = Vector2(0, 46)
	play_again_btn.pressed.connect(func() -> void:
		_card_overlay.queue_free()
		_card_overlay = null
		_scores.clear()
		_select_disc("midrange")
		_start_hole(0))
	btn_hbox.add_child(play_again_btn)

	var exit_btn := Button.new()
	exit_btn.text = "✕  Exit Test Mode" if away_course_name == "" else "🏠  Head Home"
	exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_btn.custom_minimum_size = Vector2(0, 46)
	exit_btn.pressed.connect(_exit_test)
	btn_hbox.add_child(exit_btn)

func _card_row5(h1: String, h2: String, h3: String, h4: String, h5: String, bold: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var widths := [0.5, 0.8, 0.8, 0.8, 2.0]
	var texts  := [h1, h2, h3, h4, h5]
	for i in texts.size():
		var lbl := Label.new()
		lbl.text = texts[i] as String
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_stretch_ratio = widths[i] as float
		lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14 if bold else 13)
		if bold:
			lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.72))
		row.add_child(lbl)
	return row

# ── Helpers ───────────────────────────────────────────────────────────────────

func _score_name(diff: int) -> String:
	match diff:
		-4: return "Condor!"
		-3: return "Albatross!"
		-2: return "Eagle!"
		-1: return "Birdie!"
		0:  return "Par"
		1:  return "Bogey"
		2:  return "Double Bogey"
		_:  return "+%d" % diff if diff > 2 else "%d" % diff

func _score_color(diff: int) -> Color:
	if   diff <= -2: return Color(1.0, 0.85, 0.0)
	elif diff == -1: return Color(0.2, 0.9, 0.3)
	elif diff == 0:  return Color(0.9, 0.9, 0.9)
	else:            return Color(0.95, 0.35, 0.25)

func _exit_test() -> void:
	cleanup()
	var parent := get_parent()
	if parent and parent.has_method("stop_play_test"):
		parent.call("stop_play_test")
	queue_free()

# ── Player movement (WASD + right-click reposition) ──────────────────────────

const WALK_SPEED := 5.0

func _handle_player_movement(delta: float) -> void:
	if not _camera or not is_instance_valid(_camera):
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): mv.y -= 1.0
	if Input.is_key_pressed(KEY_S): mv.y += 1.0
	if Input.is_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D): mv.x += 1.0
	if mv == Vector2.ZERO:
		return
	mv = mv.normalized()
	var right   := Vector3(_camera.transform.basis.x.x, 0, _camera.transform.basis.x.z).normalized()
	var forward := Vector3(-_camera.transform.basis.z.x, 0, -_camera.transform.basis.z.z).normalized()
	var world_dir := (right * mv.x + forward * (-mv.y)).normalized()
	var candidate := _player_pos + world_dir * WALK_SPEED * delta
	var max_x := float(GameWorld3D.GRID_COLS - 1) * GameWorld3D.CELL_SIZE
	var max_z := float(GameWorld3D.GRID_ROWS - 1) * GameWorld3D.CELL_SIZE
	candidate.x = clampf(candidate.x, 0.0, max_x)
	candidate.z = clampf(candidate.z, 0.0, max_z)
	if _is_blocked_at(candidate):
		return
	_player_pos = candidate
	if GameManager.world:
		_player_pos.y = (GameManager.world as GameWorld3D).get_ground_y(_player_pos)
	_aim_dir = world_dir
	_move_player_mesh(_player_pos)

func _teleport_player_to(pos: Vector3) -> void:
	var max_x := float(GameWorld3D.GRID_COLS - 1) * GameWorld3D.CELL_SIZE
	var max_z := float(GameWorld3D.GRID_ROWS - 1) * GameWorld3D.CELL_SIZE
	pos.x = clampf(pos.x, 0.0, max_x)
	pos.z = clampf(pos.z, 0.0, max_z)
	if _is_blocked_at(pos):
		return
	_player_pos = pos
	if GameManager.world:
		_player_pos.y = (GameManager.world as GameWorld3D).get_ground_y(_player_pos)
	_move_player_mesh(_player_pos)
	_update_third_person_camera(_player_pos)

func _is_blocked_at(pos: Vector3) -> bool:
	if not GameManager.world:
		return false
	var tile := (GameManager.world as GameWorld3D).get_tile_at(pos)
	return tile == GameWorld3D.TileType.TREE \
		or tile == GameWorld3D.TileType.WATER \
		or tile == GameWorld3D.TileType.BASKET

# ── Camera occlusion transparency ─────────────────────────────────────────────

func _update_occlusion() -> void:
	if not _camera or not is_instance_valid(_camera) or not GameManager.world:
		_restore_occlusion()
		return
	var world    := GameManager.world as GameWorld3D
	var cam_pos  := _camera.global_position
	var eye_pos  := _player_pos + Vector3(0.0, 1.4, 0.0)   # approx eye height

	# Restore previously hidden props first
	_restore_occlusion()

	# Segment direction and length
	var to_eye := eye_pos - cam_pos
	var seg_len := to_eye.length()
	if seg_len < 0.5:
		return
	var seg_dir := to_eye / seg_len

	# Only trees inside the sightline's bounding box (+ fade radius) are checked.
	const FADE_R := 2.2
	var lo := Vector2(minf(cam_pos.x, eye_pos.x), minf(cam_pos.z, eye_pos.z)) - Vector2.ONE * FADE_R
	var hi := Vector2(maxf(cam_pos.x, eye_pos.x), maxf(cam_pos.z, eye_pos.z)) + Vector2.ONE * FADE_R
	var trees := world.get_tree_positions_in(lo, hi)
	for cell in trees:
		var tree_pos: Vector3 = trees[cell]
		# Project tree onto camera→eye segment
		var t := (tree_pos - cam_pos).dot(seg_dir)
		if t < 0.5 or t > seg_len - 1.0:
			continue   # not between camera and player
		var closest := cam_pos + seg_dir * t
		if (tree_pos - closest).length() < FADE_R:   # within 2.2 m of sightline
			world.set_tree_hidden(cell, true)
			_occluded_props.append(cell)

func _restore_occlusion() -> void:
	var world: Variant = GameManager.world
	if world != null and is_instance_valid(world):
		for cell in _occluded_props:
			(world as GameWorld3D).set_tree_hidden(cell as Vector2i, false)
	_occluded_props.clear()
