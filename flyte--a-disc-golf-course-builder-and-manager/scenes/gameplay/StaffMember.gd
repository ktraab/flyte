## Hired staff NPC that wanders the course doing type-specific work.
extends Node3D

const STAFF_NAMES:  Array = ["Groundskeeper", "Disc Pro", "Concessions Worker"]
const STAFF_COLORS: Array = [Color(0.15, 0.72, 0.22), Color(0.28, 0.50, 1.0), Color(1.0, 0.58, 0.15)]
const SHIRT_COLORS: Array = [Color(0.1, 0.55, 0.15), Color(0.18, 0.35, 0.88), Color(0.85, 0.42, 0.08)]
const WANDER_SPEED := 3.2
const WANDER_INTERVAL_MIN := 4.0
const WANDER_INTERVAL_MAX := 10.0

# TileType int values for preferred wander destinations per staff type
# Groundskeeper=0 → fairway(1), rough(4), path(2)
# Disc Pro=1      → tee(6), basket(7), pro_shop(12)
# Concessions=2   → food_stand(11), parking(9)
const PREFER_TILE_TYPES: Array = [
	[1, 4, 2],
	[6, 7, 12],
	[11, 9],
]

var _type:       int    = 0
var _staff_id:   String = ""
var _target:     Vector3 = Vector3.ZERO
var _wander_t:   float  = 0.0
var _wander_int: float  = 6.0
var _world: Node3D      # GameWorld3D

var _body: Node3D

func init(type: int, world: Node3D, staff_id: String) -> void:
	_type     = type
	_world    = world
	_staff_id = staff_id
	_build_mesh()
	_pick_target()

func _process(delta: float) -> void:
	_wander_t += delta
	if _wander_t >= _wander_int or global_position.distance_to(_target) < 0.5:
		_pick_target()
		return
	var dir := _target - global_position
	dir.y = 0.0
	if dir.length() > 0.3:
		var next_pos := global_position + dir.normalized() * WANDER_SPEED * delta
		# Avoid water tiles (TileType.WATER == 3)
		if _world != null and _world.has_method("get_tile_at"):
			var tile: int = _world.get_tile_at(next_pos)
			if tile == 3:  # WATER
				_pick_target()
				return
		global_position = next_pos
		if _body:
			_body.rotation.y = atan2(dir.x, dir.z)
	# Snap to terrain surface
	if _world != null and _world.has_method("get_ground_y"):
		global_position.y = _world.get_ground_y(global_position)

func get_info() -> Dictionary:
	return {
		"id":         _staff_id,
		"type":       "staff",
		"staff_type": _type,
		"name":       STAFF_NAMES[_type],
		"action":     _action_text(),
		"npc_ref":    self,
	}

func _action_text() -> String:
	match _type:
		0: return "Maintaining course"
		1: return "Coaching players"
		2: return "Serving food & drinks"
	return "Working"

func _pick_target() -> void:
	_wander_t   = 0.0
	_wander_int = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	if _world == null or not _world.has_method("get_tiles_of_type"):
		_random_wander()
		return
	var preferred: Array = PREFER_TILE_TYPES[_type]
	var candidates: Array = []
	for tile_type in preferred:
		var tiles: Array = _world.get_tiles_of_type(tile_type)
		candidates.append_array(tiles)
	if candidates.is_empty():
		_random_wander()
	else:
		_target = candidates[randi() % candidates.size()]

func _random_wander() -> void:
	var r := randf_range(4.0, 14.0)
	var a := randf() * TAU
	_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)

const _STAFF_CHAR_PATHS: Array = [
	# Groundskeeper (type 0) — casual
	"res://assets/models/Animated Men Pack/Male_Shirt.fbx",
	# Disc Pro (type 1) — casual
	"res://assets/models/Animated Men Pack/Male_Casual.fbx",
	# Concessions (type 2) — casual
	"res://assets/models/Animated Female Pack/Female_Casual.fbx",
]

func _build_mesh() -> void:
	_body = Node3D.new()
	add_child(_body)

	var path: String = _STAFF_CHAR_PATHS[_type] as String
	var loaded_char := false
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var char_node := scene.instantiate()
			char_node.scale    = Vector3.ONE * 0.55
			char_node.rotation = Vector3(0.0, 0.0, 0.0)
			_body.add_child(char_node)
			loaded_char = true

	if not loaded_char:
		var shirt := SHIRT_COLORS[_type] as Color
		var skin  := Color(0.86, 0.68, 0.52)
		var pants := Color(0.18, 0.22, 0.38)

		var lm := CapsuleMesh.new()
		lm.radius = 0.13; lm.height = 0.38
		_mi(_body, lm, _mat(pants)).position.y = 0.19

		var tm := CapsuleMesh.new()
		tm.radius = 0.155; tm.height = 0.40
		_mi(_body, tm, _mat(shirt)).position.y = 0.56

		var hm := SphereMesh.new()
		hm.radius = 0.145; hm.height = 0.29
		_mi(_body, hm, _mat(skin)).position.y = 0.88

	# Staff badge dot (larger, type color)
	var dot := SphereMesh.new()
	dot.radius = 0.14; dot.height = 0.28
	_mi(_body, dot, _mat(STAFF_COLORS[_type] as Color)).position.y = 1.18

	# Floating name tag
	var label := Label3D.new()
	label.text       = STAFF_NAMES[_type]
	label.position.y = 1.55
	label.font_size  = 26
	label.modulate   = Color(1.0, 1.0, 0.85, 1.0)
	label.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

	# Click detection area
	var area := Area3D.new()
	var cshape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	cshape.shape = sphere
	area.add_child(cshape)
	area.position.y    = 0.55
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
