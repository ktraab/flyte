## Disc golf NPC: walks entry path → plays each hole (throw+walk loop) → exits.
## Receives pre-built hole data from GameWorld3D. Uses BFS paths for all walking.
extends Node3D

enum Phase { WALKING, PAUSING, WAITING_DISC, DONE }
enum Skill { BEGINNER, AMATEUR, PRO }

const WALK_SPEED        := 7.2
const ARRIVE_DIST       := 0.30
const EARN_PER_ROUND    := 15.0
const THROW_PAUSE       := 0.7
const CELEBRATE_DUR     := 1.4
const NPC_CHAR_SCALE    := 0.55
const NPC_CHAR_FACING   := 0.0
const NPC_CHAR_Y_OFFSET := 0.0   # tune down (e.g. -0.10) if FBX characters hover

# Per-skill tuning: [putt_range, max_throws, deviate_range]
const SKILL_PUTT_RANGE:  Array = [6.0,  10.0, 15.0]
const SKILL_MAX_THROWS:  Array = [5,    4,    3   ]
const SKILL_DEVIATE:     Array = [0.45, 0.28, 0.15]

const SHIRT_COLORS: Array = [
	Color(0.85, 0.18, 0.18),
	Color(0.18, 0.35, 0.88),
	Color(0.15, 0.70, 0.28),
	Color(0.90, 0.65, 0.08),
	Color(0.72, 0.18, 0.82),
	Color(0.90, 0.42, 0.10),
	Color(0.88, 0.88, 0.88),
	Color(0.12, 0.58, 0.72),
]

const _MALE_PATHS: Array = [
	"res://assets/models/Animated Men Pack/Male_Casual.fbx",
	"res://assets/models/Animated Men Pack/Male_Shirt.fbx",
	"res://assets/models/Animated Men Pack/Male_LongSleeve.fbx",
	"res://assets/models/Animated Men Pack/Male_Suit.fbx",
	"res://assets/models/FBX animated character pack/Casual_Male.fbx",
	"res://assets/models/FBX animated character pack/Casual2_Male.fbx",
	"res://assets/models/FBX animated character pack/Casual3_Male.fbx",
]
const _FEMALE_PATHS: Array = [
	"res://assets/models/Animated Female Pack/Female_Casual.fbx",
	"res://assets/models/Animated Female Pack/Female_TankTop.fbx",
	"res://assets/models/Animated Female Pack/Female_Dress.fbx",
	"res://assets/models/Animated Female Pack/Female_Alternative.fbx",
	"res://assets/models/FBX animated character pack/Casual_Female.fbx",
	"res://assets/models/FBX animated character pack/Casual2_Female.fbx",
	"res://assets/models/FBX animated character pack/Casual3_Female.fbx",
]

# Player needs — tick up while on course; facilities satisfy them
const HUNGER_RATE   := 0.22   # per second (max ~7.5 min to fill)
const THIRST_RATE   := 0.30   # per second (max ~5.5 min)
const BATHROOM_RATE := 0.15   # per second (max ~11 min)
const NEED_MAX      := 100.0
const NEED_WARN     := 80.0   # show warning popup
const FOOD_RADIUS   := 8.0    # world units to auto-satisfy hunger/thirst near food stand
const BATH_RADIUS   := 10.0   # world units to auto-satisfy bathroom near restroom
const VIP_EARN_MULT := 3.0    # VIP pays 3× green fee

const _DiscScript = preload("res://scenes/gameplay/DiscProjectile.gd")

var _npc_id:    String  = ""
var _holes:     Array   = []   # Array of {entry_path, tee_pos, basket_pos, par}
var _exit_path: Array   = []
var _hole_idx:  int     = 0
var _tee_pos:   Vector3
var _basket_pos: Vector3

var _phase:       Phase    = Phase.DONE
var _waypoints:   Array    = []
var _wp_idx:      int      = 0
var _on_arrive:   Callable = Callable()
var _pause_timer: float    = 0.0
var _pause_dur:   float    = 0.0
var _on_pause:    Callable = Callable()
var _throw_count: int      = 0
var _skill:       Skill    = Skill.AMATEUR

var _active_disc: Node3D = null   # disc currently in flight or on ground
var _holding_tee: bool   = false  # true while occupying tee pad, blocks others

var _body: Node3D
var _anim: AnimationPlayer

var _is_vip:        bool  = false
var _hunger:        float = 0.0
var _thirst:        float = 0.0
var _bathroom:      float = 0.0
var _warned_hunger: bool  = false
var _warned_thirst: bool  = false
var _warned_bath:   bool  = false
var _needs_check_t: float = 0.0

# ── Init ──────────────────────────────────────────────────────────────────────

func init(holes: Array, exit_path: Array, npc_id: String, is_vip: bool = false) -> void:
	_npc_id    = npc_id
	_is_vip = is_vip
	_holes     = holes
	_exit_path = exit_path
	_build_mesh(npc_id)
	scale = Vector3(1.6, 1.6, 1.6)
	# Assign skill tier from npc_id hash: ~50% amateur, ~30% beginner, ~20% pro
	var h := absi(npc_id.hash()) % 10
	_skill = Skill.BEGINNER if h < 3 else (Skill.PRO if h >= 8 else Skill.AMATEUR)

	if holes.is_empty():
		print("[NPC] %s no holes — idle" % npc_id)
		return

	var first: Dictionary = holes[0]
	var entry: Array      = first["entry_path"] as Array
	_tee_pos    = first["tee_pos"] as Vector3
	_basket_pos = first["basket_pos"] as Vector3

	if entry.size() > 0:
		position   = entry[0] as Vector3
		position.x += randf_range(-0.15, 0.15)
		position.z += randf_range(-0.15, 0.15)

	_walk_to(entry, _arrive_at_tee)
	print("[NPC] %s spawned holes=%d" % [npc_id, holes.size()])

# ── Main process ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Tick player needs
	_hunger   = minf(_hunger   + HUNGER_RATE * delta, NEED_MAX)
	_thirst   = minf(_thirst   + THIRST_RATE * delta, NEED_MAX)
	_bathroom = minf(_bathroom + BATHROOM_RATE * delta, NEED_MAX)

	# Periodically check for nearby facilities
	_needs_check_t += delta
	if _needs_check_t >= 3.0:
		_needs_check_t = 0.0
		_check_needs()

	# Exit early if any need maxes out
	if _hunger >= NEED_MAX or _thirst >= NEED_MAX or _bathroom >= NEED_MAX:
		_abandon_round()
		return

	# Warn at threshold
	if not _warned_hunger and _hunger >= NEED_WARN:
		_warned_hunger = true
		var w := GameManager.world as GameWorld3D
		if w: w.spawn_score_popup(position + Vector3(0,0.5,0), "Hungry!", Color(1.0, 0.6, 0.1))
	if not _warned_thirst and _thirst >= NEED_WARN:
		_warned_thirst = true
		var w := GameManager.world as GameWorld3D
		if w: w.spawn_score_popup(position + Vector3(0,0.5,0), "Thirsty!", Color(0.3, 0.7, 1.0))
	if not _warned_bath and _bathroom >= NEED_WARN:
		_warned_bath = true
		var w := GameManager.world as GameWorld3D
		if w: w.spawn_score_popup(position + Vector3(0,0.5,0), "Need restroom!", Color(0.9, 0.9, 0.3))

	match _phase:
		Phase.WALKING:
			_walk_step(delta)
		Phase.PAUSING:
			_pause_timer += delta
			if _pause_timer >= _pause_dur:
				var cb := _on_pause
				_on_pause = Callable()
				_phase    = Phase.DONE
				if cb.is_valid():
					cb.call()

# ── Walking ───────────────────────────────────────────────────────────────────

func _walk_to(waypoints: Array, on_arrive: Callable) -> void:
	_waypoints = waypoints
	_wp_idx    = 0
	_on_arrive = on_arrive
	_phase     = Phase.WALKING
	_play_anim("Walk")

func _walk_step(delta: float) -> void:
	if _wp_idx >= _waypoints.size():
		var cb := _on_arrive
		_on_arrive = Callable()
		_phase     = Phase.DONE
		if cb.is_valid():
			cb.call()
		return

	var target: Vector3 = _waypoints[_wp_idx] as Vector3
	var flat_t := Vector3(target.x, position.y, target.z)
	var to_t   := flat_t - position

	if to_t.length() < ARRIVE_DIST:
		position.y = target.y
		_wp_idx   += 1
		return

	var dir := to_t.normalized()
	position += dir * WALK_SPEED * delta
	if _body and dir.length_squared() > 0.001:
		_body.rotation.y = atan2(dir.x, dir.z)

# ── Pausing ───────────────────────────────────────────────────────────────────

func _pause_for(dur: float, on_done: Callable) -> void:
	_pause_timer = 0.0
	_pause_dur   = dur
	_on_pause    = on_done
	_phase       = Phase.PAUSING

# ── Disc golf flow ────────────────────────────────────────────────────────────

func _arrive_at_tee() -> void:
	var world := GameManager.world as GameWorld3D
	if world and not world.request_tee(_tee_pos, self):
		# Back off so waiting NPCs don't stack on the tee pad
		var back := (_tee_pos - _basket_pos)
		back = back.normalized() if back.length_squared() > 0.001 else Vector3(1.0, 0.0, 0.0)
		var wait_pos := _tee_pos + back * 3.0 + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		if world:
			wait_pos.y = world.get_ground_y(wait_pos)
		position = wait_pos
		_pause_for(2.0, _arrive_at_tee)
		return
	position = _tee_pos
	_face_target(_basket_pos)
	_holding_tee = true
	_pause_for(THROW_PAUSE, _do_throw)

func _do_throw() -> void:
	_throw_count += 1
	var dist := position.distance_to(_basket_pos)
	var max_throws: int = SKILL_MAX_THROWS[_skill] as int
	var is_putt: bool = dist < (SKILL_PUTT_RANGE[_skill] as float) or _throw_count >= max_throws

	var target: Vector3
	var arc:    float
	var dur:    float
	var turn:   float = 0.0
	var fade:   float = 0.0

	if is_putt:
		target = _basket_pos
		arc    = 0.8
		dur    = maxf(0.6, dist / 18.0)
	else:
		target = _calc_throw_target()
		# Pick arc/duration and turn/fade by distance and skill
		# NPCs aim to compensate for their disc's curve (aim_compensate), so
		# turn/fade change the shape of the flight, not where it ends up.
		if dist > 70.0:
			arc  = randf_range(5.0, 8.0)
			dur  = randf_range(2.0, 2.6)
			# Driver: clear turn, then a hard fade
			turn = randf_range(2.0, 6.0) * (1.0 - _skill * 0.3)
			fade = randf_range(3.0, 6.5)
		elif dist > 35.0:
			arc  = randf_range(3.0, 4.5)
			dur  = randf_range(1.5, 2.0)
			# Fairway/midrange: gentle S-curve
			turn = randf_range(0.8, 3.0) * (1.0 - _skill * 0.3)
			fade = randf_range(1.2, 3.0)
		else:
			arc  = randf_range(1.8, 2.8)
			dur  = randf_range(1.0, 1.6)

	_play_anim("Throw")
	_launch_disc(target, arc, dur, is_putt, turn, fade)
	if _holding_tee:
		var _world := GameManager.world as GameWorld3D
		if _world:
			_world.release_tee(_tee_pos, self)
		_holding_tee = false
	_phase = Phase.WAITING_DISC

func _launch_disc(target: Vector3, arc: float, dur: float, is_putt: bool, turn: float = 0.0, fade: float = 0.0) -> void:
	var disc: Node3D = _DiscScript.new()
	var parent := get_parent()
	if not parent:
		return
	parent.add_child(disc)
	disc.set("hole_num", _hole_idx)
	disc.set("_turn", turn)
	disc.set("_fade", fade)
	disc.set("basket_pos", _basket_pos)
	disc.set("aim_compensate", true)
	_active_disc = disc
	var hand_y := position.y + 1.2
	disc.launch(Vector3(position.x, hand_y, position.z), target, arc, dur)
	EventBus.disc_launched.emit()

	# Putts always drop (NPC putting is abstracted); any throw the chains catch is holed too.
	disc.landed.connect(func(p: Vector3, pen: int) -> void:
		if is_putt or bool(disc.get("in_basket")):
			_arrive_at_basket()
		else:
			_disc_landed(p, pen))

func _disc_landed(pos: Vector3, penalty: int) -> void:
	EventBus.disc_landed.emit(penalty)
	if penalty > 0:
		_throw_count += penalty
	var arrived_disc := _active_disc
	_active_disc = null
	var path: Array = [pos]
	if GameManager.world != null:
		path = (GameManager.world as GameWorld3D).find_walkable_path(position, pos)
	_walk_to(path, func() -> void:
		if arrived_disc and is_instance_valid(arrived_disc):
			arrived_disc.pickup()
		_face_target(_basket_pos)
		_pause_for(0.5, _do_throw)
	)

func _arrive_at_basket() -> void:
	var putt_disc := _active_disc
	_active_disc = null
	var path: Array = [_basket_pos]
	if GameManager.world != null:
		path = (GameManager.world as GameWorld3D).find_walkable_path(position, _basket_pos)
	_walk_to(path, func() -> void:
		if putt_disc and is_instance_valid(putt_disc):
			putt_disc.pickup()
		_show_score_popup()
		_play_anim("Idle")
		_pause_for(CELEBRATE_DUR, _start_next_hole)
	)

func _show_score_popup() -> void:
	var par := 3
	if _hole_idx < _holes.size():
		par = _holes[_hole_idx].get("par", 3) as int
	var diff := _throw_count - par
	var popup_text: String
	var popup_color: Color
	if diff <= -2:
		popup_text  = "Eagle!" if diff == -2 else "Albatross!"
		popup_color = Color(1.0, 0.85, 0.0)
	elif diff == -1:
		popup_text  = "Birdie!"
		popup_color = Color(0.2, 0.9, 0.3)
	elif diff == 0:
		popup_text  = "Par"
		popup_color = Color(0.9, 0.9, 0.9)
	elif diff == 1:
		popup_text  = "Bogey"
		popup_color = Color(1.0, 0.55, 0.1)
	elif diff == 2:
		popup_text  = "Double Bogey"
		popup_color = Color(0.9, 0.2, 0.2)
	else:
		popup_text  = "+%d" % diff
		popup_color = Color(0.9, 0.2, 0.2)
	EventBus.npc_score_recorded.emit(_hole_idx, _throw_count)
	EventBus.hole_scored.emit(_hole_idx, _throw_count, par, diff)
	var world := GameManager.world as GameWorld3D
	if world != null:
		world.spawn_score_popup(_basket_pos, popup_text, popup_color)
	if diff <= 0:
		_play_anim("Celebrate")

func _start_next_hole() -> void:
	_hole_idx += 1
	if _hole_idx >= _holes.size():
		_begin_exit()
		return
	var hole: Dictionary = _holes[_hole_idx]
	_tee_pos    = hole["tee_pos"] as Vector3
	_basket_pos = hole["basket_pos"] as Vector3
	var entry: Array = hole["entry_path"] as Array
	_throw_count = 0
	_walk_to(entry, _arrive_at_tee)

func _begin_exit() -> void:
	_walk_to(_exit_path, _course_complete)

func _check_needs() -> void:
	var world := GameManager.world as GameWorld3D
	if world == null:
		return
	if world.has_facility_near(position, GameWorld3D.TileType.FOOD_STAND, FOOD_RADIUS):
		_hunger = 0.0;  _thirst = 0.0
		_warned_hunger = false; _warned_thirst = false
	if world.has_facility_near(position, GameWorld3D.TileType.RESTROOM, BATH_RADIUS):
		_bathroom = 0.0
		_warned_bath = false

func _abandon_round() -> void:
	if _holding_tee:
		var _world := GameManager.world as GameWorld3D
		if _world:
			_world.release_tee(_tee_pos, self)
		_holding_tee = false
	EventBus.npc_left.emit(_npc_id)
	EventBus.player_needs_failed.emit(_npc_id)
	var w := GameManager.world as GameWorld3D
	if w: w.spawn_score_popup(position, "Left early!", Color(0.9, 0.3, 0.3))
	_phase = Phase.DONE
	queue_free()

func get_info() -> Dictionary:
	var skill_names := ["Beginner", "Amateur", "Pro"]
	var phase_str: String
	match _phase:
		Phase.WALKING:       phase_str = "Walking to hole"
		Phase.PAUSING:       phase_str = "Preparing throw"
		Phase.WAITING_DISC:  phase_str = "Watching disc"
		_:                   phase_str = "Finishing"
	return {
		"id":          _npc_id,
		"type":        "vip" if _is_vip else "player",
		"is_vip":      _is_vip,
		"skill":       skill_names[_skill],
		"hole":        _hole_idx + 1,
		"total_holes": _holes.size(),
		"throws":      _throw_count,
		"hunger":      _hunger,
		"thirst":      _thirst,
		"bathroom":    _bathroom,
		"action":      phase_str,
		"npc_ref":     self,
	}

func _course_complete() -> void:
	var mult := VIP_EARN_MULT if _is_vip else 1.0
	var earn := EARN_PER_ROUND * maxi(1, _holes.size()) * mult
	EconomyManager.earn(earn, "green_fee")
	if _is_vip:
		EventBus.vip_left.emit(_npc_id, true)
	EventBus.npc_left.emit(_npc_id)
	EventBus.round_completed.emit(_npc_id, _is_vip, earn, _holes.size())
	_phase = Phase.DONE
	queue_free()

# ── Throw helpers ─────────────────────────────────────────────────────────────

func _calc_throw_target() -> Vector3:
	var dir := _basket_pos - position
	dir.y   = 0.0
	var dist := dir.length()
	if dist < 0.001:
		return _basket_pos
	dir = dir.normalized()
	var dev_max: float = SKILL_DEVIATE[_skill] as float
	var world := GameManager.world as GameWorld3D
	# Re-sample up to 4 times to avoid landing in water
	for _attempt in range(4):
		var pct      := randf_range(0.55, 0.82)
		var deviate  := randf_range(-dev_max, dev_max)
		var sideways := Vector3(-dir.z, 0.0, dir.x)
		var throw_dir := (dir * cos(deviate) + sideways * sin(deviate)).normalized()
		var candidate := Vector3(position.x, position.y, position.z) + throw_dir * dist * pct
		if world == null or world.get_tile_at(candidate) != GameWorld3D.TileType.WATER:
			return candidate
	# All samples were water — throw straight toward basket at 70%
	return position + dir * dist * 0.70

func _face_target(t: Vector3) -> void:
	var dir := Vector3(t.x - position.x, 0.0, t.z - position.z)
	if dir.length_squared() > 0.001 and _body:
		_body.rotation.y = atan2(dir.x, dir.z)

# ── Visual / mesh ─────────────────────────────────────────────────────────────

func _build_mesh(npc_id: String) -> void:
	_body = Node3D.new()
	add_child(_body)

	var h: int          = absi(npc_id.hash())
	var shirt: Color    = SHIRT_COLORS[h % SHIRT_COLORS.size()] as Color
	var use_female: bool = h % 2 == 1
	var paths: Array    = _FEMALE_PATHS if use_female else _MALE_PATHS
	var path: String    = paths[h % paths.size()] as String

	var loaded_char := false
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var char_node := scene.instantiate()
			char_node.scale    = Vector3.ONE * NPC_CHAR_SCALE
			char_node.rotation = Vector3(0.0, NPC_CHAR_FACING, 0.0)
			char_node.position = Vector3(0.0, NPC_CHAR_Y_OFFSET, 0.0)
			_body.add_child(char_node)
			_anim = char_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
			loaded_char = true

	if not loaded_char:
		_build_procedural_mesh(shirt)

	# Floating colour dot — gold for VIP, shirt color for regular
	var dot := SphereMesh.new()
	dot.radius = 0.12 if not _is_vip else 0.18
	dot.height = dot.radius * 2.0
	var dot_color := Color(1.0, 0.85, 0.1) if _is_vip else shirt
	_mi(_body, dot, _mat(dot_color)).position.y = 1.80

	# Click detection area
	var area := Area3D.new()
	var cshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	cshape.shape = sphere
	area.add_child(cshape)
	area.position.y = 0.6
	area.collision_layer = 2
	area.collision_mask  = 0
	area.input_ray_pickable = true
	area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _norm: Vector3, _idx: int) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				EventBus.npc_inspect_requested.emit(get_info())
	)
	add_child(area)

func _build_procedural_mesh(shirt: Color) -> void:
	var _skin_tones: Array = [
		Color(0.97, 0.83, 0.72), Color(0.93, 0.71, 0.55),
		Color(0.78, 0.57, 0.40), Color(0.60, 0.40, 0.25),
		Color(0.38, 0.24, 0.15),
	]
	var _hair_colors: Array = [
		Color(0.10, 0.07, 0.04), Color(0.45, 0.28, 0.12),
		Color(0.75, 0.55, 0.20), Color(0.65, 0.20, 0.10),
		Color(0.82, 0.82, 0.82),
	]
	var _pants_colors: Array = [
		Color(0.18, 0.22, 0.38), Color(0.24, 0.20, 0.16),
		Color(0.12, 0.26, 0.18), Color(0.30, 0.28, 0.28),
	]
	var h: int = absi(_npc_id.hash())
	var skin  := _skin_tones[h % _skin_tones.size()] as Color
	var hair  := _hair_colors[(h * 3) % _hair_colors.size()] as Color
	var pants := _pants_colors[(h * 7) % _pants_colors.size()] as Color

	var lm := CapsuleMesh.new()
	lm.radius = 0.13; lm.height = 0.38
	_mi(_body, lm, _mat(pants)).position.y = 0.19

	var tm := CapsuleMesh.new()
	tm.radius = 0.155; tm.height = 0.40
	_mi(_body, tm, _mat(shirt)).position.y = 0.56

	var hm := SphereMesh.new()
	hm.radius = 0.145; hm.height = 0.29
	_mi(_body, hm, _mat(skin)).position.y = 0.88

	var cm := CylinderMesh.new()
	cm.top_radius = 0.06; cm.bottom_radius = 0.14; cm.height = 0.10
	_mi(_body, cm, _mat(hair)).position.y = 1.00

# ── Animation ─────────────────────────────────────────────────────────────────

func _play_anim(want: String) -> void:
	if not _anim:
		return
	# Three naming conventions across our three packs:
	#   "CharacterArmature|X"     — FBX Animated Character Pack
	#   "HumanArmature|Man_X"     — Animated Men Pack
	#   "HumanArmature|Female_X"  — Animated Female Pack
	var candidates: Array
	match want:
		"Walk":
			candidates = [
				"CharacterArmature|Walk", "CharacterArmature|Run",
				"HumanArmature|Man_Walk",    "HumanArmature|Man_Run",
				"HumanArmature|Female_Walk", "HumanArmature|Female_Run",
				"Walk", "walk", "Run", "Jog",
			]
		"Throw":
			candidates = [
				"CharacterArmature|Punch", "CharacterArmature|SwordSlash",
				"CharacterArmature|Shoot_OneHanded", "CharacterArmature|PickUp",
				"HumanArmature|Man_Punch",    "HumanArmature|Man_SwordSlash",
				"HumanArmature|Female_Punch", "HumanArmature|Female_SwordSlash",
				"Throw", "Attack", "Punch", "Cast",
				"CharacterArmature|Idle", "HumanArmature|Man_Idle",
				"HumanArmature|Female_Idle", "Idle",
			]
		"Celebrate":
			candidates = [
				"CharacterArmature|Victory", "CharacterArmature|Jump",
				"HumanArmature|Man_Clapping",    "HumanArmature|Man_Jump",
				"HumanArmature|Female_Clapping", "HumanArmature|Female_Jump",
				"Victory", "Wave", "Jump", "Celebrate",
				"CharacterArmature|Idle", "HumanArmature|Man_Idle",
				"HumanArmature|Female_Idle", "Idle",
			]
		_:
			candidates = [
				"CharacterArmature|Idle",
				"HumanArmature|Man_Idle", "HumanArmature|Man_Standing",
				"HumanArmature|Female_Idle",
				"Idle", "idle", "Stand", "stand", want,
			]
	for anim_name in candidates:
		if _anim.has_animation(anim_name):
			if _anim.current_animation != anim_name:
				_anim.play(anim_name)
			return

# ── Helpers ───────────────────────────────────────────────────────────────────

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
