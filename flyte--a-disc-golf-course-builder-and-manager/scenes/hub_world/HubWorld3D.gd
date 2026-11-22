## The Circuit Grounds — 3D walkable hub world connecting all disc golf destinations.
## Player walks around a festival park, approaches portals, presses E to travel.
extends Node3D

# ── Portal layout ─────────────────────────────────────────────────────────────
# Positions are XZ. Z+ = south (entrance). Z- = north (deep into grounds).

const PORTALS: Array = [
	{
		"id": "home", "name": "Your Course", "sub": "Home Base",
		"pos": Vector2(0, 52), "color": Color(0.18, 0.62, 0.22),
		"icon": "🏠", "unlock_key": "", "type": "course",
	},
	{
		"id": "disc_depot", "name": "Disc Depot", "sub": "Gear Shop",
		"pos": Vector2(-20, 36), "color": Color(0.42, 0.18, 0.72),
		"icon": "🥏", "unlock_key": "ten_players", "type": "shop",
	},
	{
		"id": "bag_shack", "name": "The Bag Shack", "sub": "Accessories",
		"pos": Vector2(20, 36), "color": Color(0.55, 0.25, 0.60),
		"icon": "🎒", "unlock_key": "first_staff", "type": "shop",
	},
	{
		"id": "hornets_hollow", "name": "Hornet's Hollow", "sub": "Charlotte, NC",
		"pos": Vector2(-34, 12), "color": Color(0.70, 0.52, 0.05),
		"icon": "🐝", "unlock_key": "five_star", "type": "course",
	},
	{
		"id": "idlebrook", "name": "Idlebrook", "sub": "Bluegrass Country, KY",
		"pos": Vector2(34, 12), "color": Color(0.28, 0.52, 0.20),
		"icon": "🌿", "unlock_key": "balance_50k", "type": "course",
	},
	{
		"id": "wdga_hq", "name": "WDGA Tour HQ", "sub": "Worldwide",
		"pos": Vector2(0, -5), "color": Color(0.72, 0.55, 0.10),
		"icon": "🏆", "unlock_key": "first_tourney", "type": "org",
	},
	{
		"id": "hawks_meadow", "name": "Hawk's Meadow", "sub": "Pacific NW, WA",
		"pos": Vector2(-46, -8), "color": Color(0.28, 0.48, 0.24),
		"icon": "🦅", "unlock_key": "fifty_players", "type": "course",
	},
	{
		"id": "maple_ridge", "name": "Maple Hill", "sub": "Leicester, MA",
		"pos": Vector2(46, -8), "color": Color(0.62, 0.20, 0.10),
		"icon": "🍁", "unlock_key": "three_star", "type": "course",
	},
	{
		"id": "smugglers_pass", "name": "Smuggler's Pass", "sub": "Green Mountains, VT",
		"pos": Vector2(-32, -34), "color": Color(0.18, 0.36, 0.16),
		"icon": "⛰️", "unlock_key": "first_tourney", "type": "course",
	},
	{
		"id": "la_veaga_bluffs", "name": "La Veaga Bluffs", "sub": "Santa Cruz, CA",
		"pos": Vector2(32, -34), "color": Color(0.14, 0.40, 0.72),
		"icon": "🌊", "unlock_key": "vip_visit", "type": "course",
	},
	{
		"id": "bromez", "name": "Bromez", "sub": "Disc Golf Media",
		"pos": Vector2(0, -56), "color": Color(0.85, 0.32, 0.05),
		"icon": "🎬", "unlock_key": "prestige_regional", "type": "media",
	},
]

# ── Constants ─────────────────────────────────────────────────────────────────

const WALK_SPEED      := 11.0
const CAM_OFFSET      := Vector3(-42, 68, 42)
const CAM_SMOOTH      := 9.0
const INTERACT_RADIUS := 6.5
const GROUND_SIZE     := 160.0
const START_POS       := Vector3(0.0, 0.0, 68.0)

const _CHAR_PATHS: Array = [
	"res://assets/models/Animated Men Pack/Male_Casual.fbx",
	"res://assets/models/Animated Men Pack/Male_Shirt.fbx",
]

# ── State ─────────────────────────────────────────────────────────────────────

var _player:        Node3D
var _player_body:   Node3D
var _player_anim:   AnimationPlayer
var _camera:        Camera3D
var _cam_pos:       Vector3
var _nearby_id:     String = ""
var _canvas:        CanvasLayer
var _prompt_panel:  PanelContainer
var _prompt_label:  Label
var _title_label:   Label
var _flash_rect:    ColorRect
var _is_active:     bool  = false
var _entering:      bool  = false
var _portal_discs:  Array = []   # unlocked portal disc MeshInstances to spin
var _hub_npcs:      Array = []   # wandering NPC Node3D refs

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	set_process(false)
	_build_world()
	EventBus.game_state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WORLD_MAP:
		_activate()
	elif _is_active:
		_deactivate()

func _activate() -> void:
	if _canvas:
		_canvas.visible = true
	if _flash_rect:
		_flash_rect.modulate.a = 0.0
	visible      = true
	_is_active   = true
	_entering    = false
	set_process(true)
	_player.global_position = START_POS
	_cam_pos = START_POS + CAM_OFFSET
	_camera.global_position = _cam_pos
	_camera.look_at(START_POS + Vector3(0, 1, 0), Vector3.UP)
	_camera.current = true
	_nearby_id = ""
	_set_prompt_visible(false)
	get_viewport().physics_object_picking = false

func _deactivate() -> void:
	if _flash_rect:
		_flash_rect.modulate.a = 0.0
	if _canvas:
		_canvas.visible = false
	visible    = false
	_is_active = false
	set_process(false)
	_camera.current = false
	_set_prompt_visible(false)
	# Re-enable game world camera
	if GameManager.world:
		var gc := (GameManager.world as Node3D).get_node_or_null("CourseCamera3D")
		if gc is Camera3D:
			(gc as Camera3D).current = true

func _process(delta: float) -> void:
	if _entering:
		return
	_move_player(delta)
	_update_camera(delta)
	_check_proximity()
	_spin_portal_discs(delta)
	if Input.is_action_just_pressed("ui_cancel"):
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
	if Input.is_key_pressed(KEY_E) and _nearby_id != "":
		_enter_portal(_nearby_id)

func _spin_portal_discs(delta: float) -> void:
	for disc in _portal_discs:
		if is_instance_valid(disc):
			(disc as Node3D).rotation.y += delta * 2.4

# ── Player movement ───────────────────────────────────────────────────────────

func _move_player(delta: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    mv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  mv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0

	if mv == Vector2.ZERO:
		_play_anim("Idle")
		return

	mv = mv.normalized()
	# Move relative to camera's horizontal basis (same as CourseCamera3D and PlayTestController)
	var right   := Vector3(_camera.transform.basis.x.x, 0, _camera.transform.basis.x.z).normalized()
	var forward := Vector3(-_camera.transform.basis.z.x, 0, -_camera.transform.basis.z.z).normalized()
	var world_dir := (right * mv.x + forward * (-mv.y)).normalized()

	var running  := Input.is_key_pressed(KEY_SHIFT)
	var speed    := WALK_SPEED * (1.85 if running else 1.0)
	var new_pos  := _player.global_position + world_dir * speed * delta
	new_pos.y    = 0.0
	# Circular clamp — keep player inside portal ring, away from perimeter trees (start at ~66m)
	var xz := Vector2(new_pos.x, new_pos.z)
	if xz.length() > 60.0:
		xz = xz.normalized() * 60.0
		new_pos.x = xz.x
		new_pos.z = xz.y
	_player.global_position = new_pos

	if _player_body:
		_player_body.rotation.y = atan2(world_dir.x, world_dir.z)
	_play_anim("Run" if running else "Walk")

func _update_camera(delta: float) -> void:
	var target := _player.global_position + CAM_OFFSET
	_cam_pos = _cam_pos.lerp(target, CAM_SMOOTH * delta)
	_camera.global_position = _cam_pos
	_camera.look_at(_player.global_position + Vector3(0, 1.2, 0), Vector3.UP)

# ── Proximity & interaction ───────────────────────────────────────────────────

func _check_proximity() -> void:
	var closest_id := ""
	var closest_dist := INTERACT_RADIUS

	for portal in PORTALS:
		var pd: Dictionary = portal as Dictionary
		var xz := pd["pos"] as Vector2
		var portal_pos := Vector3(xz.x, 0.0, xz.y)
		var d := _player.global_position.distance_to(portal_pos)
		if d < closest_dist:
			closest_dist = d
			closest_id   = pd["id"] as String

	if closest_id != _nearby_id:
		_nearby_id = closest_id
		if _nearby_id == "":
			_set_prompt_visible(false)
		else:
			var loc: Dictionary = _find_portal(_nearby_id)
			var unlocked := _is_unlocked(loc)
			if unlocked:
				_prompt_label.text = "[E]  Enter  %s" % (loc["name"] as String)
				_prompt_label.add_theme_color_override("font_color", Color(0.88, 0.96, 0.78))
			else:
				_prompt_label.text = "🔒  %s\n%s" % [loc["name"] as String, _unlock_desc(loc)]
				_prompt_label.add_theme_color_override("font_color", Color(0.75, 0.60, 0.28))
			_set_prompt_visible(true)

func _enter_portal(portal_id: String) -> void:
	if _entering:
		return
	var loc := _find_portal(portal_id)
	if not _is_unlocked(loc):
		return
	_entering = true
	_set_prompt_visible(false)
	# White flash then travel
	if _flash_rect:
		_flash_rect.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_flash_rect, "modulate:a", 1.0, 0.30)
		tw.tween_callback(func() -> void: _do_travel(portal_id))
	else:
		_do_travel(portal_id)

func _do_travel(portal_id: String) -> void:
	match portal_id:
		"home":
			GameManager.change_state(GameManager.GameState.GAMEPLAY)
		_:
			var loc := _find_portal(portal_id)
			_entering = false
			if _flash_rect:
				var tw := create_tween()
				tw.tween_property(_flash_rect, "modulate:a", 0.0, 0.25)
			EventBus.notification_requested.emit(
				"%s — coming in a future update!" % (loc["name"] as String), "info")

# ── Build world ───────────────────────────────────────────────────────────────

func _build_world() -> void:
	_build_environment()
	_build_ground()
	_build_paths()
	_build_center_monument()
	_build_portals()
	_build_perimeter_trees()
	_build_player()
	_build_camera()
	_build_hud()

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.18, 0.44, 0.85)
	sky_mat.sky_horizon_color    = Color(0.72, 0.78, 0.88)
	sky_mat.sky_curve            = 0.09
	sky_mat.ground_bottom_color  = Color(0.16, 0.24, 0.12)
	sky_mat.ground_horizon_color = Color(0.50, 0.54, 0.38)
	sky_mat.sun_angle_max        = 28.0
	sky_mat.sun_curve            = 0.08
	sky_mat.energy_multiplier    = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode      = Environment.BG_SKY
	env.sky                  = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(1.0, 0.93, 0.82)
	env.ambient_light_energy = 0.70
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.tonemap_white    = 1.0
	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast   = 1.02
	env.adjustment_saturation = 1.05
	env.fog_enabled        = true
	env.fog_light_color    = Color(0.88, 0.82, 0.72)
	env.fog_sun_scatter    = 0.30
	env.fog_density        = 0.0018
	env.fog_height         = -3.0
	env.fog_height_density = 0.06

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	sun.light_color      = Color(1.0, 0.96, 0.88)
	sun.light_energy     = 1.4
	sun.shadow_enabled   = true
	sun.directional_shadow_mode         = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias                     = 0.04
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, -150.0, 0.0)
	fill.light_color      = Color(0.78, 0.82, 0.90)
	fill.light_energy     = 0.22
	add_child(fill)

func _build_ground() -> void:
	# Main grass
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground_mesh.subdivide_width  = 0
	ground_mesh.subdivide_depth  = 0
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.22, 0.48, 0.16)
	ground_mesh.material = ground_mat
	var ground_mi := MeshInstance3D.new()
	ground_mi.mesh = ground_mesh
	ground_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_mi)

	# Rough border strip
	for side in [Vector3(0, 0, GROUND_SIZE * 0.5 - 2), Vector3(0, 0, -GROUND_SIZE * 0.5 + 2),
				 Vector3(GROUND_SIZE * 0.5 - 2, 0, 0), Vector3(-GROUND_SIZE * 0.5 + 2, 0, 0)]:
		pass  # keep clean for now

func _build_paths() -> void:
	# Central hub path (circle of dirt connecting portals)
	# Draw a dirt strip from entrance toward north (main avenue)
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.52, 0.40, 0.26)

	# Main north-south avenue
	_make_path_strip(Vector3(0, 0.01, 52), Vector3(0, 0.01, -56), 3.5, path_mat)

	# Cross paths to portals
	for portal in PORTALS:
		var pd: Dictionary = portal as Dictionary
		var xz := pd["pos"] as Vector2
		if absf(xz.x) > 2.0:  # skip center-column portals (already on main avenue)
			var portal_pos := Vector3(xz.x, 0.01, xz.y)
			var avenue_x0  := Vector3(0.0, 0.01, xz.y)
			_make_path_strip(avenue_x0, portal_pos, 2.5, path_mat)

func _make_path_strip(from: Vector3, to: Vector3, width: float, mat: StandardMaterial3D) -> void:
	var diff   := to - from
	var length := diff.length()
	if length < 0.1:
		return
	var mid    := (from + to) * 0.5
	var mesh   := BoxMesh.new()
	mesh.size  = Vector3(width, 0.02, length)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = mid
	mi.rotation.y = atan2(diff.x, diff.z)
	add_child(mi)

func _build_center_monument() -> void:
	# Central disc golf basket sculpture — the heart of The Circuit Grounds
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.35, 0.30, 0.22)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color  = Color(0.75, 0.72, 0.68)
	pole_mat.metallic      = 0.85
	pole_mat.roughness     = 0.25

	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.80, 0.75, 0.60)
	chain_mat.metallic     = 0.9
	chain_mat.roughness    = 0.2

	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color      = Color(0.95, 0.45, 0.10)
	disc_mat.emission_enabled  = true
	disc_mat.emission          = Color(1.0, 0.55, 0.10) * 1.5
	disc_mat.roughness         = 0.3

	var root := Node3D.new()
	root.position = Vector3(0, 0, -0.5)

	# Stone base
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius    = 1.0
	base_mesh.bottom_radius = 1.2
	base_mesh.height        = 0.35
	_mi(root, base_mesh, base_mat).position.y = 0.18

	# Pole
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = 3.0
	_mi(root, pole, pole_mat).position.y = 1.65

	# Basket ring
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.58
	_mi(root, ring, pole_mat).position.y = 2.60

	# Chain curtain (8 chains)
	for i in 8:
		var angle := (float(i) / 8.0) * TAU
		var cx := cos(angle) * 0.42
		var cz := sin(angle) * 0.42
		var chain := CylinderMesh.new()
		chain.top_radius = 0.025
		chain.bottom_radius = 0.025
		chain.height     = 0.62
		var cmi := _mi(root, chain, chain_mat)
		cmi.position = Vector3(cx, 2.28, cz)
		cmi.rotation.z = deg_to_rad(randf_range(-12, 12))

	# Top disc (glowing)
	var disc_mesh := SphereMesh.new()
	disc_mesh.radius = 0.30
	disc_mesh.height = 0.18
	_mi(root, disc_mesh, disc_mat).position.y = 3.20

	# "The Circuit Grounds" sign on a post
	var sign_label := Label3D.new()
	sign_label.text       = "THE CIRCUIT GROUNDS"
	sign_label.font_size  = 56
	sign_label.modulate   = Color(1.0, 0.95, 0.70)
	sign_label.position   = Vector3(0, 4.2, 0)
	sign_label.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.no_depth_test = true
	root.add_child(sign_label)

	var sub_label := Label3D.new()
	sub_label.text      = "World Disc Golf Tour"
	sub_label.font_size = 36
	sub_label.modulate  = Color(0.70, 0.90, 0.60)
	sub_label.position  = Vector3(0, 3.65, 0)
	sub_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sub_label.no_depth_test = true
	root.add_child(sub_label)

	add_child(root)

func _build_portals() -> void:
	for portal in PORTALS:
		var pd: Dictionary = portal as Dictionary
		_build_portal(pd)

func _build_portal(pd: Dictionary) -> void:
	var unlocked := _is_unlocked(pd)
	var xz       := pd["pos"] as Vector2
	var base_col := pd["color"] as Color

	var root := Node3D.new()
	root.position = Vector3(xz.x, 0.0, xz.y)

	# ── Tee pad base ──
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius    = 2.0
	pad_mesh.bottom_radius = 2.2
	pad_mesh.height        = 0.12
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = base_col.darkened(0.55) if not unlocked else base_col.darkened(0.25)
	_mi(root, pad_mesh, pad_mat).position.y = 0.06

	# ── Gateway arch ──
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.70, 0.68, 0.62) if unlocked else Color(0.28, 0.28, 0.30)
	arch_mat.metallic     = 0.6
	arch_mat.roughness    = 0.4

	# Left post
	var lp := CylinderMesh.new()
	lp.top_radius = 0.10
	lp.bottom_radius = 0.10
	lp.height = 4.0
	_mi(root, lp, arch_mat).position = Vector3(-1.5, 2.0, 0)

	# Right post
	var rp := CylinderMesh.new()
	rp.top_radius = 0.10
	rp.bottom_radius = 0.10
	rp.height = 4.0
	_mi(root, rp, arch_mat).position = Vector3(1.5, 2.0, 0)

	# Top crossbar
	var cb := CylinderMesh.new()
	cb.top_radius = 0.08
	cb.bottom_radius = 0.08
	cb.height = 3.20
	var cb_mi := _mi(root, cb, arch_mat)
	cb_mi.position = Vector3(0, 4.05, 0)
	cb_mi.rotation.z = PI / 2.0

	# ── Disc on top (emissive when unlocked, spins in _process) ──
	var disc_mesh := SphereMesh.new()
	disc_mesh.radius = 0.22
	disc_mesh.height = 0.13
	var disc_mat := StandardMaterial3D.new()
	if unlocked:
		disc_mat.albedo_color     = base_col.lightened(0.2)
		disc_mat.emission_enabled = true
		disc_mat.emission         = base_col.lightened(0.1) * 1.8
		disc_mat.roughness        = 0.2
	else:
		disc_mat.albedo_color = Color(0.22, 0.22, 0.24)
	var disc_mi := _mi(root, disc_mesh, disc_mat)
	disc_mi.position.y = 4.30
	if unlocked:
		_portal_discs.append(disc_mi)

	# ── Name label ──
	var name_label := Label3D.new()
	name_label.text      = (pd["icon"] as String) + "  " + (pd["name"] as String)
	name_label.font_size = 42
	name_label.modulate  = (
		Color(0.92, 0.96, 0.86) if unlocked else Color(0.35, 0.35, 0.38))
	name_label.position  = Vector3(0, 5.4, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	root.add_child(name_label)

	# Sub-label (region or locked text)
	var sub_label := Label3D.new()
	if unlocked:
		sub_label.text    = pd["sub"] as String
		sub_label.modulate = Color(0.60, 0.75, 0.55)
	else:
		sub_label.text    = "🔒  " + _unlock_desc(pd)
		sub_label.modulate = Color(0.60, 0.50, 0.22)
	sub_label.font_size = 28
	sub_label.position  = Vector3(0, 4.70, 0)
	sub_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sub_label.no_depth_test = true
	root.add_child(sub_label)

	add_child(root)

func _build_perimeter_trees() -> void:
	var tree_mat := StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.10, 0.28, 0.08)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.24, 0.12)

	var half := GROUND_SIZE * 0.5 - 5.0
	var positions: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in 40:
		var angle := (float(i) / 40.0) * TAU
		var r     := half * rng.randf_range(0.88, 1.0)
		positions.append(Vector3(cos(angle) * r, 0, sin(angle) * r))

	for pos in positions:
		var scale := rng.randf_range(0.8, 1.5)
		var tree_root := Node3D.new()
		tree_root.position = pos

		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.12 * scale; trunk.bottom_radius = 0.18 * scale
		trunk.height = 1.2 * scale
		_mi(tree_root, trunk, trunk_mat).position.y = 0.6 * scale

		var canopy := SphereMesh.new()
		canopy.radius = 1.1 * scale; canopy.height = 2.0 * scale
		_mi(tree_root, canopy, tree_mat).position.y = 2.2 * scale

		add_child(tree_root)

func _build_player() -> void:
	_player = Node3D.new()
	_player.position = START_POS
	add_child(_player)

	_player_body = Node3D.new()
	_player.add_child(_player_body)

	# Try FBX character
	var loaded := false
	for path in _CHAR_PATHS:
		if ResourceLoader.exists(path):
			var scene := load(path) as PackedScene
			if scene:
				var char_node := scene.instantiate()
				char_node.scale = Vector3.ONE * 0.55
				_player_body.add_child(char_node)
				_player_anim = char_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if not _player_anim:
					for child in char_node.get_children():
						if child is AnimationPlayer:
							_player_anim = child as AnimationPlayer
							break
				loaded = true
				break

	if not loaded:
		# Procedural capsule fallback
		var lm := CapsuleMesh.new(); lm.radius = 0.14; lm.height = 0.40
		_mi(_player_body, lm, _mat(Color(0.22, 0.35, 0.88))).position.y = 0.20
		var tm := CapsuleMesh.new(); tm.radius = 0.16; tm.height = 0.42
		_mi(_player_body, tm, _mat(Color(0.25, 0.62, 0.28))).position.y = 0.58
		var hm := SphereMesh.new(); hm.radius = 0.15; hm.height = 0.30
		_mi(_player_body, hm, _mat(Color(0.86, 0.68, 0.52))).position.y = 0.90

	# Player name tag
	var tag := Label3D.new()
	tag.text          = "YOU"
	tag.font_size     = 20
	tag.modulate      = Color(0.70, 0.90, 1.0, 0.90)
	tag.position.y    = 1.80
	tag.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	_player.add_child(tag)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size       = 55.0
	_camera.current    = false
	add_child(_camera)
	_camera.global_position = START_POS + CAM_OFFSET
	_camera.look_at(START_POS + Vector3(0, 1, 0), Vector3.UP)
	_cam_pos = _camera.global_position

func _build_hud() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)

	# Interaction prompt — bottom center
	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left   = 0.5
	_prompt_panel.anchor_right  = 0.5
	_prompt_panel.anchor_top    = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left   = -200.0
	_prompt_panel.offset_right  = 200.0
	_prompt_panel.offset_top    = -80.0
	_prompt_panel.offset_bottom = -18.0
	_prompt_panel.visible       = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.10, 0.06, 0.88)
	sb.corner_radius_top_left     = 8
	sb.corner_radius_top_right    = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left  = 8
	_prompt_panel.add_theme_stylebox_override("panel", sb)
	_canvas.add_child(_prompt_panel)

	var prompt_margin := MarginContainer.new()
	prompt_margin.add_theme_constant_override("margin_left",   18)
	prompt_margin.add_theme_constant_override("margin_right",  18)
	prompt_margin.add_theme_constant_override("margin_top",    10)
	prompt_margin.add_theme_constant_override("margin_bottom", 10)
	_prompt_panel.add_child(prompt_margin)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_margin.add_child(_prompt_label)

	# Top-left HUD: back button + location name
	var top_left := HBoxContainer.new()
	top_left.anchor_left   = 0.0
	top_left.anchor_right  = 0.0
	top_left.anchor_top    = 0.0
	top_left.anchor_bottom = 0.0
	top_left.offset_left   = 12.0
	top_left.offset_top    = 12.0
	top_left.offset_right  = 280.0
	top_left.offset_bottom = 60.0
	top_left.add_theme_constant_override("separation", 10)
	_canvas.add_child(top_left)

	var back_btn := Button.new()
	back_btn.text = "← Menu"
	back_btn.custom_minimum_size = Vector2(90, 40)
	back_btn.pressed.connect(func() -> void:
		GameManager.change_state(GameManager.GameState.MAIN_MENU))
	top_left.add_child(back_btn)

	var home_btn := Button.new()
	home_btn.text = "▶ My Course"
	home_btn.custom_minimum_size = Vector2(105, 40)
	home_btn.pressed.connect(func() -> void:
		GameManager.change_state(GameManager.GameState.GAMEPLAY))
	top_left.add_child(home_btn)

	# Controls hint — top right
	var hint := Label.new()
	hint.text = "WASD / Arrow keys to move  ·  E to enter  ·  Esc for menu"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.50, 0.85))
	hint.anchor_left   = 1.0; hint.anchor_right  = 1.0
	hint.anchor_top    = 0.0; hint.anchor_bottom = 0.0
	hint.offset_right  = -10.0; hint.offset_left  = -480.0
	hint.offset_top    = 14.0; hint.offset_bottom = 36.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_canvas.add_child(hint)

	# Full-screen flash rect — hidden until portal travel
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_flash_rect.modulate.a = 0.0
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_flash_rect)

func _set_prompt_visible(v: bool) -> void:
	if _prompt_panel:
		_prompt_panel.visible = v

# ── Hub NPCs ──────────────────────────────────────────────────────────────────

const _HUB_NPC_CHAR_PATHS: Array = [
	"res://assets/models/Animated Men Pack/Male_Casual.fbx",
	"res://assets/models/Animated Men Pack/Male_Shirt.fbx",
	"res://assets/models/Animated Female Pack/Female_Casual.fbx",
]
const _NPC_SHIRT_COLORS: Array = [
	Color(0.85, 0.22, 0.18), Color(0.22, 0.48, 0.85), Color(0.22, 0.72, 0.30),
	Color(0.85, 0.65, 0.10), Color(0.55, 0.20, 0.75), Color(0.85, 0.42, 0.10),
	Color(0.18, 0.62, 0.72), Color(0.72, 0.18, 0.55),
]
const _NPC_NAMES: Array = [
	"Jake", "Morgan", "Riley", "Sam", "Casey", "Taylor", "Jordan", "Alex",
	"Drew", "Skyler", "Quinn", "Parker",
]

func _build_hub_npcs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	for i in 10:
		var npc_root := Node3D.new()
		# Scatter within the hub grounds, avoiding center monument
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(10.0, 58.0)
		npc_root.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

		var body := Node3D.new()
		npc_root.add_child(body)

		# Try FBX, fallback to capsule
		var char_path: String = _HUB_NPC_CHAR_PATHS[i % _HUB_NPC_CHAR_PATHS.size()] as String
		var npc_anim: AnimationPlayer = null
		var loaded_char := false
		if ResourceLoader.exists(char_path):
			var scene := load(char_path) as PackedScene
			if scene:
				var cn := scene.instantiate()
				cn.scale = Vector3.ONE * 0.55
				body.add_child(cn)
				npc_anim = cn.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if not npc_anim:
					for child in cn.get_children():
						if child is AnimationPlayer:
							npc_anim = child as AnimationPlayer
							break
				loaded_char = true

		if not loaded_char:
			var shirt_col: Color = _NPC_SHIRT_COLORS[i % _NPC_SHIRT_COLORS.size()] as Color
			var lm := CapsuleMesh.new(); lm.radius = 0.13; lm.height = 0.38
			_mi(body, lm, _mat(Color(0.18, 0.22, 0.38))).position.y = 0.19
			var tm := CapsuleMesh.new(); tm.radius = 0.155; tm.height = 0.40
			_mi(body, tm, _mat(shirt_col)).position.y = 0.56
			var hm := SphereMesh.new(); hm.radius = 0.145; hm.height = 0.29
			_mi(body, hm, _mat(Color(0.86, 0.68, 0.52))).position.y = 0.88

		# Name label
		var nlbl := Label3D.new()
		nlbl.text          = _NPC_NAMES[i % _NPC_NAMES.size()] as String
		nlbl.font_size     = 16
		nlbl.modulate      = Color(0.85, 0.92, 0.78, 0.80)
		nlbl.position.y    = 1.65
		nlbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
		nlbl.no_depth_test = true
		npc_root.add_child(nlbl)

		add_child(npc_root)

		# State data attached to the node via metadata
		var target_angle := rng.randf() * TAU
		var target_radius := rng.randf_range(5.0, 55.0)
		npc_root.set_meta("target", Vector3(cos(target_angle) * target_radius, 0.0, sin(target_angle) * target_radius))
		npc_root.set_meta("wander_t", rng.randf_range(0.0, 6.0))
		npc_root.set_meta("wander_int", rng.randf_range(5.0, 12.0))
		npc_root.set_meta("body", body)
		npc_root.set_meta("anim", npc_anim)
		_hub_npcs.append(npc_root)

func _update_hub_npcs(delta: float) -> void:
	var rng := RandomNumberGenerator.new()
	for npc_node in _hub_npcs:
		if not is_instance_valid(npc_node):
			continue
		var npc := npc_node as Node3D
		var wander_t: float   = npc.get_meta("wander_t") as float
		var wander_int: float = npc.get_meta("wander_int") as float
		var target: Vector3   = npc.get_meta("target") as Vector3

		wander_t += delta
		npc.set_meta("wander_t", wander_t)

		var dist := npc.global_position.distance_to(target)
		if wander_t >= wander_int or dist < 0.8:
			# Pick new target
			rng.seed = int(npc.global_position.x * 100.0 + npc.global_position.z * 100.0 + wander_t * 10.0)
			var a := rng.randf() * TAU
			var r := rng.randf_range(5.0, 55.0)
			target = Vector3(cos(a) * r, 0.0, sin(a) * r)
			npc.set_meta("target", target)
			npc.set_meta("wander_t", 0.0)
			npc.set_meta("wander_int", rng.randf_range(5.0, 12.0))
			# Idle briefly
			var anim: AnimationPlayer = npc.get_meta("anim") as AnimationPlayer
			_play_anim_on(anim, "Idle")
			continue

		var dir := (target - npc.global_position)
		dir.y = 0.0
		if dir.length() > 0.3:
			var npc_speed := 3.5
			npc.global_position += dir.normalized() * npc_speed * delta
			npc.global_position.y = 0.0
			var body_node: Node3D = npc.get_meta("body") as Node3D
			if body_node:
				body_node.rotation.y = atan2(dir.x, dir.z)
			var anim: AnimationPlayer = npc.get_meta("anim") as AnimationPlayer
			_play_anim_on(anim, "Walk")

func _play_anim_on(anim: AnimationPlayer, want: String) -> void:
	if not anim:
		return
	var candidates: Array
	if want == "Walk":
		candidates = ["CharacterArmature|Walk", "HumanArmature|Man_Walk", "HumanArmature|Female_Walk",
					  "CharacterArmature|Run", "HumanArmature|Man_Run", "Walk", "Run"]
	else:
		candidates = ["CharacterArmature|Idle", "HumanArmature|Man_Idle", "HumanArmature|Female_Idle", "Idle"]
	for an in candidates:
		if anim.has_animation(an):
			if anim.current_animation != an:
				anim.play(an)
			return

# ── Animation ─────────────────────────────────────────────────────────────────

func _play_anim(want: String) -> void:
	if not _player_anim:
		return
	var candidates: Array
	match want:
		"Run":
			candidates = [
				"CharacterArmature|Run", "HumanArmature|Man_Run", "HumanArmature|Female_Run",
				"CharacterArmature|Walk", "HumanArmature|Man_Walk", "HumanArmature|Female_Walk",
				"Run", "Walk",
			]
		"Walk":
			candidates = [
				"CharacterArmature|Walk", "CharacterArmature|Run",
				"HumanArmature|Man_Walk",    "HumanArmature|Man_Run",
				"HumanArmature|Female_Walk", "HumanArmature|Female_Run",
				"Walk", "walk", "Run",
			]
		_:
			candidates = [
				"CharacterArmature|Idle",
				"HumanArmature|Man_Idle", "HumanArmature|Man_Standing",
				"HumanArmature|Female_Idle", "Idle", "idle", "Stand",
			]
	for anim in candidates:
		if _player_anim.has_animation(anim):
			if _player_anim.current_animation != anim:
				_player_anim.play(anim)
			return

# ── Unlock logic ──────────────────────────────────────────────────────────────

func _is_unlocked(pd: Dictionary) -> bool:
	var key: String = pd.get("unlock_key", "") as String
	if key == "":
		return true
	match key:
		"three_star":        return GoalsSystem.is_goal_complete("three_star")
		"five_star":         return GoalsSystem.is_goal_complete("five_star")
		"first_tourney":     return GoalsSystem.is_goal_complete("first_tourney")
		"vip_visit":         return GoalsSystem.is_goal_complete("vip_visit")
		"fifty_players":     return GoalsSystem.is_goal_complete("fifty_players")
		"ten_players":       return GoalsSystem.is_goal_complete("ten_players")
		"first_staff":       return GoalsSystem.is_goal_complete("first_staff")
		"balance_50k":       return EconomyManager.balance >= 50000.0
		"prestige_regional": return EconomyManager.get_prestige() >= 25.0
	return false

func _unlock_desc(pd: Dictionary) -> String:
	var key: String = pd.get("unlock_key", "") as String
	match key:
		"three_star":        return "Reach 3★ home course"
		"five_star":         return "Reach 5★ home course"
		"first_tourney":     return "Host a tournament"
		"vip_visit":         return "Host a VIP touring pro"
		"fifty_players":     return "Welcome 50 players"
		"ten_players":       return "Welcome 10 players"
		"first_staff":       return "Hire first staff member"
		"balance_50k":       return "Accumulate $50,000"
		"prestige_regional": return "Reach Regional prestige"
	return "Keep building"

# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_portal(id: String) -> Dictionary:
	for p in PORTALS:
		var pd: Dictionary = p as Dictionary
		if pd["id"] == id:
			return pd
	return {}

func _mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh              = mesh
	m.material_override = mat
	m.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
