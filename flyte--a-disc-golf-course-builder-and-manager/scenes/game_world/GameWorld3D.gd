## 3D isometric course world — MultiMesh terrain for GPU-efficient 100×100 grid.
## Two tree variants: pine (cones) and deciduous (sphere clusters).
## Terraform: tiles have per-tile height offsets on top of type-based TILE_Y.
class_name GameWorld3D
extends Node3D

const _NPCScript   = preload("res://scenes/gameplay/NPCPlayer.gd")
const _StaffScript = preload("res://scenes/gameplay/StaffMember.gd")

# ── Tile types ────────────────────────────────────────────────────────────────
enum TileType {
	GRASS      = 0,
	FAIRWAY    = 1,
	PATH       = 2,
	WATER      = 3,
	ROUGH      = 4,
	TREE       = 5,
	TEE        = 6,
	BASKET     = 7,
	ENTRANCE   = 8,
	PARKING    = 9,
	RESTROOM   = 10,
	FOOD_STAND = 11,
	PRO_SHOP   = 12,
	SAND       = 13,   # Drop zone/sand area — disc lands +1 stroke, play from spot
	ROCK       = 14,   # Boulder hazard — disc deflects to random nearby cell
	OB         = 15,   # Out of bounds — disc returns to last valid + 1 stroke penalty
	BENCH      = 20,   # Decor — seating area, happiness bonus (capped)
	FLOWER_BED = 21,   # Decor — planting, rating bonus (capped)
	SCULPTURE  = 22,   # Decor — landmark art, best rating bonus (capped)
	LAMP_POST  = 23,   # Aesthetic — lamp post, purely cosmetic
	SIGN       = 24,   # Aesthetic — info sign, purely cosmetic
	GARDEN     = 25,   # Aesthetic — garden patch, purely cosmetic
}

# Tool values beyond TileType range — handled in _paint_at
const TOOL_RAISE := 16
const TOOL_LOWER := 17

const Props = preload("res://scenes/game_world/PropFactory.gd")
const PropBatch = preload("res://scenes/game_world/PropBatch.gd")
const HoleScore = preload("res://core/simulation/HoleScore.gd")

const FACILITY_COSTS: Dictionary = {
	9:  1500.0,   # PARKING
	10: 3000.0,   # RESTROOM
	11: 2500.0,   # FOOD_STAND
	12: 8000.0,   # PRO_SHOP
}

const TILE_COSTS: Dictionary = {
	TileType.GRASS:     0.0,    # Free — erase/clear
	TileType.FAIRWAY:   45.0,
	TileType.PATH:      25.0,
	TileType.WATER:     0.0,    # Natural feature — free
	TileType.ROUGH:     15.0,
	TileType.TREE:      60.0,
	TileType.TEE:       250.0,
	TileType.BASKET:    450.0,
	TileType.ENTRANCE:  500.0,
	TileType.SAND:       20.0,
	TileType.ROCK:       10.0,
	TileType.OB:          0.0,
	TileType.BENCH:      150.0,
	TileType.FLOWER_BED:  80.0,
	TileType.SCULPTURE:  600.0,
	TileType.LAMP_POST:  120.0,
	TileType.SIGN:        40.0,
	TileType.GARDEN:      60.0,
}

const TERRAFORM_COST := 10.0  # per raise or lower step

const TERRAFORM_STEP := 0.25
const TERRAFORM_MIN  := -2.0
const TERRAFORM_MAX  :=  4.0

# Tune if FBX trees appear too large or too small after first import.
const TREE_FBX_SCALE := 1.1

const CELL_SIZE          := 2.0
const CELL_HEIGHT        := 0.22
const TERRAIN_BOX_HEIGHT := 7.0   # terrain boxes extend this far down so raised tiles have visible cliffs
const GRID_COLS          := 150
const GRID_ROWS          := 150
# Water plane fixed just below grass surface — independent of TILE_Y[WATER]
const WATER_SURFACE_Y    := CELL_HEIGHT * 0.5 - 0.06   # = 0.05, below grass at 0.11

const TILE_Y: Dictionary = {
	TileType.GRASS:      0.00,
	TileType.FAIRWAY:    0.08,
	TileType.PATH:       0.04,
	TileType.WATER:     -0.14,
	TileType.ROUGH:     -0.04,
	TileType.TREE:       0.02,
	TileType.TEE:        0.16,
	TileType.BASKET:     0.08,
	TileType.ENTRANCE:   0.00,
	TileType.PARKING:    0.02,
	TileType.RESTROOM:   0.02,
	TileType.FOOD_STAND: 0.02,
	TileType.PRO_SHOP:   0.04,
	TileType.SAND:      -0.02,
	TileType.ROCK:       0.04,
	TileType.OB:         0.00,
}

const TILE_COLOR: Dictionary = {
	TileType.GRASS:      Color(0.22, 0.65, 0.13),
	TileType.FAIRWAY:    Color(0.10, 0.78, 0.10),   # bright fairway green
	TileType.PATH:       Color(0.62, 0.60, 0.55),
	TileType.WATER:      Color(0.04, 0.38, 0.86),   # deep blue
	TileType.ROUGH:      Color(0.50, 0.42, 0.08),   # brownish rough
	TileType.TREE:       Color(0.10, 0.48, 0.08),
	TileType.TEE:        Color(0.90, 0.90, 0.82),
	TileType.BASKET:     Color(0.10, 0.72, 0.10),
	TileType.ENTRANCE:   Color(0.64, 0.62, 0.58),
	TileType.PARKING:    Color(0.14, 0.14, 0.14),
	TileType.RESTROOM:   Color(0.88, 0.86, 0.80),
	TileType.FOOD_STAND: Color(0.92, 0.72, 0.14),
	TileType.PRO_SHOP:   Color(0.12, 0.32, 0.14),
	TileType.SAND:       Color(0.88, 0.78, 0.44),
	TileType.ROCK:       Color(0.46, 0.44, 0.40),
	TileType.OB:         Color(0.96, 0.96, 0.96),
	TileType.BENCH:      Color(0.62, 0.42, 0.22),   # warm wood brown
	TileType.FLOWER_BED: Color(0.92, 0.38, 0.72),   # pink/magenta bloom
	TileType.SCULPTURE:  Color(0.70, 0.60, 0.88),   # lavender — distinctive
	TileType.LAMP_POST:  Color(0.28, 0.28, 0.30),   # dark metal grey
	TileType.SIGN:       Color(0.72, 0.56, 0.22),   # warm wood sign
	TileType.GARDEN:     Color(0.18, 0.52, 0.14),   # deep garden green
}

# ── State ─────────────────────────────────────────────────────────────────────
var _terrain_mm:  MultiMesh         # all non-water tiles
var _water_mmi:   MultiMeshInstance3D  # separate shiny water surface layer
var _tiles:       Dictionary = {}
var _tile_heights: Dictionary = {}  # per-tile float height added on top of TILE_Y
var _props:       Dictionary = {}
var _props_node:  Node3D

var _tree_pine_scenes:  Array = []
var _tree_decid_scenes: Array = []
var _trees_loaded:      bool  = false
## Trees, rough grass and sand are MultiMesh instances (PropBatch), not nodes —
## one draw per mesh part instead of one per tree/blade. Full detail, no culling.
var _batch:       PropBatch = null
var _tree_parts:  Array = []    # model idx → [[part_id, local Transform3D, kind]]
var _blade_part:  int = -1
var _grain_part:  int = -1
enum { TREE_PART_ORIG, TREE_PART_TRUNK, TREE_PART_LEAVES }
var _tree_detail_full := true      # false = Low preset's simplified tree meshes
var _tree_detail_src: Dictionary = {}  # tree part id → [full ArrayMesh, own material or null]
var _tree_reduced: Dictionary = {}     # tree part id → simplified ArrayMesh (null = can't reduce)

var _hover_indicator: MeshInstance3D
var _hover_arrow:      MeshInstance3D = null   # directional arrow for TEE/BASKET preview
var _hover_base_color: Color          = Color.WHITE
var _hover_cell   := Vector2i(-1, -1)
var _active_tool  := TileType.FAIRWAY
var _painting     := false
var _builder_mode := false

# Builder prop preview
var _preview_prop:      Node3D    = null
var _preview_prop_cell: Vector2i  = Vector2i(-9, -9)
var _preview_prop_tool: int       = -99

# ── NPC state ─────────────────────────────────────────────────────────────────
const MAX_NPCS           := 10
const NPC_SPAWN_INTERVAL := 22.0

var _npc_root:        Node3D
var _staff_root:      Node3D
var _staff_nodes:     Array  = [[], [], []]   # per StaffType: arrays of StaffMember nodes
var _next_staff_id:   int    = 0
var _holes:           Array  = []   # Array of {entry_path, tee_pos, basket_pos}
var _exit_path:       Array  = []
var _npc_count:       int    = 0
var _tee_occupants:   Dictionary = {}   # Vector3i(rounded tee_pos) → NPC node
var _next_npc_id:     int    = 0
var _gameplay_mode:   bool   = false
var _spawn_timer:     Timer
var _tile_variants:    Dictionary = {}   # Vector2i → int (0=pine, 1=decid, -1=random)
var _tile_tree_size: Dictionary = {}   # Vector2i → int (0=small 1=medium 2=tall)
var _ob_zones:       Dictionary = {}   # Vector2i → int (1-indexed hole num; 0=all holes)
var _rock_overlays:  Dictionary = {}   # Vector2i → true (rock prop overlay, not a tile type)
var _ob_props:       Dictionary = {}   # Vector2i → Node3D  (OB stake visuals)
var _rock_props_overlay: Dictionary = {}  # Vector2i → Node3D  (rock visuals for overlay)
var _undo_stack:     Array      = []
const UNDO_MAX: int = 60
var _edge_fill_msi:      MeshInstance3D = null        # diagonal corner fills (smooth tile edges)
var _contact_mmi:        MultiMeshInstance3D = null   # soft dark blobs under trees
var _smooth_dirty:       bool           = false
var _smooth_t:           float          = 0.0
const SMOOTH_PAINT_INTERVAL := 0.2
var _water_material: StandardMaterial3D = null
var _water_anim_t: float = 0.0
var _tile_hole_num:    Dictionary = {}   # Vector2i → int (1-based hole number)
var _tile_orientations: Dictionary = {} # Vector2i → int (0-3, 90° steps)
var _tile_par:         Dictionary = {}  # tee Vector2i → int (par value)
var _hole_custom_colors: Dictionary = {}  # hole_num → Color
var _facility_orientations: Dictionary = {}  # Vector2i → int (0-3)
var _facility_colors: Dictionary = {}  # Vector2i → int (index into FACILITY_COLOR_PRESETS)
var _building_anchor: Dictionary = {}  # cell → anchor_cell for multi-tile buildings
var _hole_waypoints: Dictionary  = {}  # hole_num → Array[Vector2i] intermediate waypoints
var _route_edit_hole: int        = -1
var _route_lines_root: Node3D
var _select_mode: bool = false
var _press_cell: Vector2i = Vector2i(-1, -1)
var _mouse_held: bool = false
var _drag_active: bool = false
var _hover_anim_t:   float  = 0.0
var _hover_mat:      StandardMaterial3D = null
var _flag_nodes:     Array  = []   # Array of MeshInstance3D flag meshes to animate
var _wind_particles: CPUParticles3D = null
var _water_shader:   ShaderMaterial = null
var _world_env_node: WorldEnvironment     = null
var _sun:            DirectionalLight3D   = null
var _sky:            Sky                  = null

# Template ghost overlay
var _ghost_tiles:       Array    = []                       # {offset: Vector2i, type: int}
var _ghost_meshes:      Array    = []                       # MeshInstance3D pool
var _ghost_anchor:      Vector2i = Vector2i(-9999, -9999)   # -9999 = follow cursor
var _ghost_anchor_orient: int    = 2
var _ghost_last_cell:   Vector2i = Vector2i(-9999, -9999)
var _ghost_last_orient: int      = -1
var _hdri_sky_mat:   PanoramaSkyMaterial  = null
var _proc_sky_mat:   ProceduralSkyMaterial = null
var _grass_tuft_mmi: MultiMeshInstance3D = null
var _active_variant:   int    = -1
var _active_tree_size: int    = 2   # 0=small 1=medium 2=tall — default tall
var _active_hole_num:  int    = 1
var _active_orientation: int  = 0
var _wind_angle: float = 0.0   # radians, direction wind blows toward
var _wind_speed: float = 1.5   # m/s
var _wind_timer: float = 0.0
const WIND_CHANGE_INTERVAL := 45.0

const HOLE_FLAG_COLORS: Array = [
	Color(0.94, 0.18, 0.18), Color(0.18, 0.38, 0.92),
	Color(0.95, 0.72, 0.05), Color(0.15, 0.80, 0.25),
	Color(0.78, 0.18, 0.82), Color(0.96, 0.50, 0.08),
]

const FACILITY_COLOR_PRESETS: Array = [
	Color(1.00, 1.00, 1.00),  # Default
	Color(0.88, 0.22, 0.22),  # Red
	Color(0.22, 0.44, 0.88),  # Blue
	Color(0.22, 0.72, 0.30),  # Green
	Color(0.90, 0.62, 0.12),  # Yellow
	Color(0.60, 0.28, 0.75),  # Purple
]

signal cell_changed(col: int, row: int, tile_type: int)
signal tile_info_requested(cell: Vector2i, tile_type: int, hole_num: int, orientation: int)
signal facility_info_requested(cell: Vector2i, tile_type: int, orientation: int, color_idx: int)
signal route_changed(hole_num: int)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_create_environment()
	_generate_default_course()
	_build_terrain()
	_add_ground_skirt()
	_place_all_props()
	_build_water_layer()
	_build_smooth_surface()
	_add_grass_tufts()
	_spawn_wind_particles()
	_create_hover_indicator()

	_npc_root = Node3D.new()
	_npc_root.name = "NPCs"
	add_child(_npc_root)

	_staff_root = Node3D.new()
	_staff_root.name = "Staff"
	add_child(_staff_root)

	_route_lines_root = Node3D.new()
	_route_lines_root.name = "RouteLines"
	add_child(_route_lines_root)

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = NPC_SPAWN_INTERVAL
	_spawn_timer.one_shot  = false
	_spawn_timer.timeout.connect(_try_spawn_npc)
	add_child(_spawn_timer)

	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.staff_hired.connect(_on_staff_hired)
	EventBus.staff_fired.connect(_on_staff_fired)
	EventBus.graphics_quality_changed.connect(_apply_graphics_settings)

func _process(delta: float) -> void:
	_wind_timer += delta
	if _wind_timer >= WIND_CHANGE_INTERVAL:
		_wind_timer = 0.0
		_wind_angle  = randf() * TAU
		_wind_speed  = randf_range(0.4, 3.5)
		EventBus.wind_changed.emit(_wind_angle, _wind_speed)
	# Water shader animation
	_water_anim_t += delta
	if _water_shader != null:
		_water_shader.set_shader_parameter("time_offset", _water_anim_t)
	# Hover pulse animation
	if _hover_mat != null and _hover_indicator != null and _hover_indicator.visible:
		_hover_anim_t += delta * 3.5
		_hover_mat.albedo_color = Color(
			_hover_base_color.r, _hover_base_color.g, _hover_base_color.b,
			0.22 + 0.18 * sin(_hover_anim_t))
	# Flag wave animation
	if GameManager.gfx_flags:
		for flag_node in _flag_nodes:
			if flag_node and is_instance_valid(flag_node):
				(flag_node as Node3D).rotation.z = sin(_water_anim_t * 2.2) * 0.18
				(flag_node as Node3D).position.x = 0.25 + sin(_water_anim_t * 2.2) * 0.04
	_update_fog_for_camera()
	# Smooth terrain rebuild — deferred so rapid painting only rebuilds once per frame
	# While drag-painting, rebuild at most every SMOOTH_PAINT_INTERVAL (the
	# overlays are cosmetic); otherwise once at the end of the frame.
	_smooth_t += delta
	if _smooth_dirty and (not _painting or _smooth_t >= SMOOTH_PAINT_INTERVAL):
		_smooth_dirty = false
		_smooth_t = 0.0
		call_deferred("_rebuild_smooth_surface")
	# Reset painting if button released while cursor was over UI (we miss the up event)
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false

func _unhandled_input(event: InputEvent) -> void:
	if _route_edit_hole >= 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell := _screen_to_cell(event.position)
			if _valid(cell):
				var holes := get_holes_info()
				var skip_cells: Array = []
				for h in holes:
					if (h["hole_num"] as int) == _route_edit_hole:
						skip_cells.append(h["tee_cell"] as Vector2i)
						skip_cells.append(h["basket_cell"] as Vector2i)
						break
				if not cell in skip_cells:
					toggle_route_waypoint(cell)
		return
	if _select_mode:
		if event is InputEventMouseMotion:
			_hover_cell = _screen_to_cell(event.position)
			_update_hover()
			if _mouse_held and not _drag_active and _valid(_hover_cell) and _hover_cell != _press_cell:
				_start_drag(_press_cell)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var cell := _screen_to_cell(event.position)
				if _valid(cell) and _tiles.get(cell, TileType.GRASS) != TileType.GRASS:
					_press_cell = cell
					_mouse_held = true
			else:
				if _drag_active:
					_finish_drag(_hover_cell)
				elif _mouse_held and _valid(_press_cell):
					_emit_tile_info(_press_cell)
				_drag_active = false
				_mouse_held  = false
				_press_cell  = Vector2i(-1, -1)
		return
	if not _builder_mode:
		return
	if event is InputEventMouseMotion:
		_hover_cell = _screen_to_cell(event.position)
		_update_hover()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = event.pressed
		if _painting:
			_paint_at(_screen_to_cell(event.position))
	if event is InputEventMouseMotion and _painting:
		_paint_at(_screen_to_cell(event.position))

# ── Public API ────────────────────────────────────────────────────────────────

func set_builder_mode(enabled: bool) -> void:
	_builder_mode = enabled
	_painting     = false
	if _hover_indicator:
		_hover_indicator.visible = false
	if _hover_arrow:
		_hover_arrow.visible = false
	_hover_cell = Vector2i(-1, -1)
	if not enabled:
		_clear_preview_prop()
	if enabled:
		draw_route_lines()
	else:
		clear_route_lines()

func set_select_mode(enabled: bool) -> void:
	_select_mode = enabled
	if enabled:
		_painting = false

func set_tile_hole_num(cell: Vector2i, hole_num: int) -> void:
	if not _valid(cell):
		return
	var tt: int = _tiles.get(cell, TileType.GRASS) as int
	if tt != TileType.TEE and tt != TileType.BASKET:
		return
	_tile_hole_num[cell] = hole_num
	_update_tile_visual(cell, tt, false)
	draw_route_lines()

func set_tile_orientation(cell: Vector2i, orientation: int) -> void:
	if not _valid(cell):
		return
	if _tiles.get(cell, TileType.GRASS) != TileType.TEE:
		return
	_tile_orientations[cell] = orientation
	_update_tile_visual(cell, TileType.TEE, false)

func set_active_tool(tile_type: int) -> void:
	_active_tool = tile_type

func set_active_variant(variant: int) -> void:
	_active_variant = variant

func set_active_tree_size(sz: int) -> void:
	_active_tree_size = sz

func set_active_hole_num(num: int) -> void:
	_active_hole_num = num

func set_active_orientation(o: int) -> void:
	_active_orientation = o

# Returns sorted [{index, hole_num, tee_cell, basket_cell, par, distance}] for HoleManager UI.
# Pairs tees with baskets by matching hole_num — same logic as _build_all_holes.
# ── Layout cache ──────────────────────────────────────────────────────────────
# Course stats (holes, ratings, facility counts, tiles by type) are pure
# functions of these four dictionaries. They used to re-scan all 22,500 tiles on
# every call (5–19 ms each, several times a second from the HUD/economy). Now
# they're computed once per layout: Dictionary.hash() runs in C++ (~0.15 ms) and
# changes whenever any tile/hole/par/height changes, so no invalidation calls
# are needed at the ~60 places that edit tiles.
var _layout_key: int = 0
var _layout_cache: Dictionary = {}

func _layout() -> Dictionary:
	var k := hash([_tiles.hash(), _tile_hole_num.hash(), _tile_par.hash(), _tile_heights.hash(),
		_hole_waypoints.hash(), _ob_zones.hash(), _rock_overlays.hash()])
	if k != _layout_key:
		_layout_key = k
		_layout_cache = {}
	return _layout_cache

## Holes with both a tee and a basket, sorted by hole number. Cached per layout;
## returns a copy so callers may modify it.
func get_holes_info() -> Array:
	var L := _layout()
	if not L.has("holes"):
		L["holes"] = _compute_holes_info()
	return (L["holes"] as Array).duplicate(true)

func _compute_holes_info() -> Array:
	var tees: Array = []; var baskets: Array = []
	for key in _tiles:
		match int(_tiles[key]):
			TileType.TEE:    tees.append(key)
			TileType.BASKET: baskets.append(key)

	var tee_by_num: Dictionary = {}
	for t in tees:
		var tc := t as Vector2i
		var hn: int = _tile_hole_num.get(tc, 99) as int
		if not tee_by_num.has(hn) or tc.y < (tee_by_num[hn] as Vector2i).y:
			tee_by_num[hn] = tc

	var basket_by_num: Dictionary = {}
	for b in baskets:
		var bc := b as Vector2i
		var hn: int = _tile_hole_num.get(bc, 99) as int
		if not basket_by_num.has(hn) or bc.y < (basket_by_num[hn] as Vector2i).y:
			basket_by_num[hn] = bc

	var hole_nums: Array = []
	for hn in tee_by_num:
		if basket_by_num.has(hn):
			hole_nums.append(hn)
	hole_nums.sort()

	var result: Array = []
	for i in hole_nums.size():
		var hn: int      = hole_nums[i] as int
		var tc: Vector2i = tee_by_num[hn] as Vector2i
		var bc: Vector2i = basket_by_num[hn] as Vector2i
		result.append({
			"index":       i,
			"hole_num":    hn,
			"tee_cell":    tc,
			"basket_cell": bc,
			"par":         _tile_par.get(tc, 3) as int,
			"distance":    int(_cell_world_pos(tc).distance_to(_cell_world_pos(bc))),
		})
	return result

func set_hole_par(tee_cell: Vector2i, par: int) -> void:
	_tile_par[tee_cell] = par

## New or moved holes get par from their length; the player can still change it
## in the Hole Manager (until the tee/basket moves again).
func _auto_par(hole_num: int) -> void:
	for h in get_holes_info():
		if int(h["hole_num"]) == hole_num:
			_tile_par[h["tee_cell"]] = HoleScore.par_for_length(HoleScore.hole_length_m(h, self))
			return

func reorder_holes(from_idx: int, to_idx: int) -> void:
	var holes := get_holes_info()
	if from_idx >= holes.size() or to_idx >= holes.size():
		return
	var ha: Dictionary = holes[from_idx]
	var hb: Dictionary = holes[to_idx]
	var tca: Vector2i = ha["tee_cell"]    as Vector2i
	var tcb: Vector2i = hb["tee_cell"]    as Vector2i
	var bca: Vector2i = ha["basket_cell"] as Vector2i
	var bcb: Vector2i = hb["basket_cell"] as Vector2i
	var na: int = ha["hole_num"] as int
	var nb: int = hb["hole_num"] as int
	_tile_hole_num[tca] = nb; _tile_hole_num[bca] = nb
	_tile_hole_num[tcb] = na; _tile_hole_num[bcb] = na
	_update_tile_visual(tca, TileType.TEE, false)
	_update_tile_visual(tcb, TileType.TEE, false)
	draw_route_lines()

func get_tee_world_pos(tee_cell: Vector2i) -> Vector3:
	return _cell_world_pos(tee_cell)

func get_cell_world_pos(cell: Vector2i) -> Vector3:
	return _cell_world_pos(cell)

func get_wind_vector() -> Vector2:
	return Vector2(cos(_wind_angle), sin(_wind_angle)) * _wind_speed

## Returns a small pixel-art Image preview of the given hole's layout.
## Each pixel = one tile cell in the hole's bounding box (padded by 3 cells).
## Image is capped at 128×128; caller creates ImageTexture from it.
func get_hole_preview_image(hole_num: int) -> Image:
	# Tile-type → preview color map
	const TILE_COLORS := {
		0:  Color(0.28, 0.50, 0.22),   # GRASS
		1:  Color(0.38, 0.78, 0.28),   # FAIRWAY
		2:  Color(0.72, 0.72, 0.68),   # PATH
		3:  Color(0.20, 0.44, 0.85),   # WATER
		4:  Color(0.22, 0.40, 0.16),   # ROUGH
		5:  Color(0.14, 0.30, 0.10),   # TREE
		6:  Color(0.95, 0.95, 0.90),   # TEE
		7:  Color(1.00, 0.85, 0.10),   # BASKET
		8:  Color(0.90, 0.55, 0.10),   # ENTRANCE
		9:  Color(0.60, 0.60, 0.58),   # PARKING
		10: Color(0.55, 0.80, 0.95),   # RESTROOM
		11: Color(0.95, 0.65, 0.20),   # FOOD_STAND
		12: Color(0.65, 0.35, 0.85),   # PRO_SHOP
		13: Color(0.90, 0.82, 0.38),   # SAND
		14: Color(0.40, 0.36, 0.32),   # ROCK
		20: Color(0.55, 0.45, 0.30),   # BENCH
		21: Color(0.85, 0.30, 0.55),   # FLOWER_BED
		22: Color(0.75, 0.75, 0.80),   # SCULPTURE
	}

	# Collect cells belonging to this hole (hole_num match or tile is TEE/BASKET for this hole)
	var cells: Array = []
	for key in _tiles:
		var cell := key as Vector2i
		var tt: int = int(_tiles[cell])
		var hn: int = int(_tile_hole_num.get(cell, 0))
		if hn == hole_num or hn == 0 or tt == TileType.TEE or tt == TileType.BASKET:
			# Only include if this cell is near the hole's tee/basket or assigned to it
			if hn == hole_num:
				cells.append(cell)
			elif tt == TileType.TEE or tt == TileType.BASKET:
				if int(_tile_hole_num.get(cell, 0)) == hole_num:
					cells.append(cell)

	# Fall back: show full grid region from tee to basket
	var tee_cell   := Vector2i(-1, -1)
	var basket_cell := Vector2i(-1, -1)
	for key in _tiles:
		var cell := key as Vector2i
		var tt: int = int(_tiles[cell])
		if tt == TileType.TEE and int(_tile_hole_num.get(cell, 0)) == hole_num:
			tee_cell = cell
		if tt == TileType.BASKET and int(_tile_hole_num.get(cell, 0)) == hole_num:
			basket_cell = cell

	if tee_cell == Vector2i(-1, -1) or basket_cell == Vector2i(-1, -1):
		# Can't build preview — return 1×1 transparent
		var fallback := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		return fallback

	# Bounding box: min/max of tee+basket ± padding, then gather all cells in box
	const PAD := 4
	var min_col := mini(tee_cell.x, basket_cell.x) - PAD
	var max_col := maxi(tee_cell.x, basket_cell.x) + PAD
	var min_row := mini(tee_cell.y, basket_cell.y) - PAD
	var max_row := maxi(tee_cell.y, basket_cell.y) + PAD
	min_col = maxi(min_col, 0); min_row = maxi(min_row, 0)
	max_col = mini(max_col, GRID_COLS - 1); max_row = mini(max_row, GRID_ROWS - 1)

	var w := max_col - min_col + 1
	var h := max_row - min_row + 1

	# Scale down to fit within 128×128 while maintaining aspect
	const MAX_SIZE := 128
	var scale := 1
	while w / scale > MAX_SIZE or h / scale > MAX_SIZE:
		scale += 1
	var img_w := ceili(float(w) / scale)
	var img_h := ceili(float(h) / scale)

	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.20, 0.36, 0.16))   # default grass bg

	for row in range(min_row, max_row + 1):
		for col in range(min_col, max_col + 1):
			var cell := Vector2i(col, row)
			var tt: int = int(_tiles.get(cell, TileType.GRASS))
			var color: Color = TILE_COLORS.get(tt, Color(0.28, 0.50, 0.22)) as Color
			var px := (col - min_col) / scale
			var py := (row - min_row) / scale
			if px < img_w and py < img_h:
				img.set_pixel(px, py, color)

	# Mark tee white and basket gold with a 2-pixel dot regardless of scale
	var tee_px  := Vector2i((tee_cell.x - min_col) / scale,    (tee_cell.y - min_row) / scale)
	var bsk_px  := Vector2i((basket_cell.x - min_col) / scale, (basket_cell.y - min_row) / scale)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tp := tee_px + Vector2i(dx, dy)
			var bp := bsk_px + Vector2i(dx, dy)
			if tp.x >= 0 and tp.x < img_w and tp.y >= 0 and tp.y < img_h:
				img.set_pixel(tp.x, tp.y, Color(1, 1, 1))
			if bp.x >= 0 and bp.x < img_w and bp.y >= 0 and bp.y < img_h:
				img.set_pixel(bp.x, bp.y, Color(1.0, 0.85, 0.1))

	return img

## Returns 0–5 star rating for a single hole based on nearby features (cached per layout).
func get_hole_rating(hole_info: Dictionary) -> float:
	var L := _layout()
	if not L.has("hole_rating"):
		L["hole_rating"] = {}
	var memo: Dictionary = L["hole_rating"]
	var mk := [hole_info["tee_cell"], hole_info["basket_cell"], hole_info["distance"]]
	if not memo.has(mk):
		memo[mk] = _compute_hole_rating(hole_info)
	return memo[mk]

func _compute_hole_rating(hole_info: Dictionary) -> float:
	return float(HoleScore.score(hole_info, self)["stars"])

## Per-hole design breakdown for the Analytics panel (one entry per hole).
func get_per_hole_breakdown() -> Array:
	var result: Array = []
	for h in get_holes_info():
		var sc: Dictionary = HoleScore.score(h, self)
		result.append({
			"hole_num": int(h["hole_num"]),
			"distance": int(sc["length_m"]),
			"par":      int(sc["par"]),
			"total":    float(sc["stars"]),
			"parts":    sc["parts"],
			"penalty":  float(sc["penalty"]),
			"tips":     sc["tips"],
		})
	return result

## Course stars: average hole stars + course bonus (variety, amenities), 0–5.
func get_course_rating() -> float:
	var L := _layout()
	if not L.has("rating"):
		L["rating"] = _compute_course_rating()
	return L["rating"]

func _compute_course_rating() -> float:
	var holes_info := get_holes_info()
	if holes_info.is_empty():
		return 0.0
	var total := 0.0
	for h in holes_info:
		total += get_hole_rating(h)
	var bonus: Dictionary = HoleScore.course_bonus(holes_info, get_facility_counts(), _count_decor_tiles())
	return clampf(total / float(holes_info.size()) + float(bonus["total"]), 0.0, 5.0)

## Returns player happiness 0.0–1.0 based on hole quality + amenities.
func get_course_happiness() -> float:
	var L := _layout()
	if not L.has("happiness"):
		L["happiness"] = _compute_course_happiness()
	return L["happiness"]

func _compute_course_happiness() -> float:
	var holes_info := get_holes_info()
	if holes_info.is_empty():
		return 0.0
	var total_rating := 0.0
	for h in holes_info:
		total_rating += get_hole_rating(h)
	var avg_rating   := total_rating / float(holes_info.size())
	var counts       := get_facility_counts()
	var restrooms    := counts.get("restroom", 0) as int
	var food_n       := counts.get("food_stand", 0) as int
	var pro_n        := counts.get("pro_shop", 0) as int
	var hole_count   := holes_info.size()
	var rest_score   := minf(float(restrooms) / maxf(float(hole_count) / 4.0, 1.0), 1.0)
	var food_score   := minf(float(food_n) * 0.6, 1.0)
	var pro_score    := 1.0 if pro_n > 0 else 0.0
	var decor_total  := _count_decor_tiles()
	var decor_score  := minf(float(decor_total) / 20.0, 1.0)   # cap: 20 pieces = full bonus
	return clampf(avg_rating / 5.0 * 0.48 + rest_score * 0.19 + food_score * 0.14 + pro_score * 0.14 + decor_score * 0.05, 0.0, 1.0)

## Returns per-component breakdown of what drives the course star rating.
func get_rating_breakdown() -> Dictionary:
	var holes_info := get_holes_info()
	if holes_info.is_empty():
		return {"hole_count": 0, "avg": 0.0, "below_3": 0, "above_4": 0, "bonus": 0.0, "variety": 0.0, "amenities": 0.0}
	var total := 0.0; var below3 := 0; var above4 := 0
	for h in holes_info:
		var r := get_hole_rating(h)
		total += r
		if r < 3.0: below3 += 1
		if r >= 4.0: above4 += 1
	var bonus: Dictionary = HoleScore.course_bonus(holes_info, get_facility_counts(), _count_decor_tiles())
	return {
		"hole_count": holes_info.size(),
		"avg": total / float(holes_info.size()),
		"below_3": below3,
		"above_4": above4,
		"bonus": float(bonus["total"]),
		"variety": float(bonus["variety"]),
		"amenities": float(bonus["amenities"]),
	}

## Returns per-component breakdown of what drives player happiness.
func get_happiness_breakdown() -> Dictionary:
	var holes_info := get_holes_info()
	if holes_info.is_empty():
		return {"quality": 0.0, "restrooms": 0.0, "food": 0.0, "pro_shop": 0.0,
				"restroom_count": 0, "food_count": 0, "pro_count": 0}
	var total_rating := 0.0
	for h in holes_info:
		total_rating += get_hole_rating(h)
	var avg_rating := total_rating / float(holes_info.size())
	var counts     := get_facility_counts()
	var restrooms  := counts.get("restroom", 0) as int
	var food_n     := counts.get("food_stand", 0) as int
	var pro_n      := counts.get("pro_shop", 0) as int
	var hole_count := holes_info.size()
	var rest_score := minf(float(restrooms) / maxf(float(hole_count) / 4.0, 1.0), 1.0)
	var food_score := minf(float(food_n) * 0.6, 1.0)
	var pro_score  := 1.0 if pro_n > 0 else 0.0
	var decor_total := _count_decor_tiles()
	var decor_score := minf(float(decor_total) / 20.0, 1.0)
	var restrooms_needed := ceili(float(hole_count) / 4.0) - restrooms
	var food_needed      := ceili((1.0 - food_score) / 0.6)
	return {
		"quality":          avg_rating / 5.0,
		"restrooms":        rest_score,
		"food":             food_score,
		"pro_shop":         pro_score,
		"decor":            decor_score,
		"restroom_count":   restrooms,
		"food_count":       food_n,
		"pro_count":        pro_n,
		"decor_count":      decor_total,
		"hole_count":       hole_count,
		"restrooms_needed": maxi(restrooms_needed, 0),
		"food_needed":      maxi(food_needed, 0),
	}

## Returns tree fly-over height based on tree size at this world position.
func get_tree_fly_height(world_pos: Vector3) -> float:
	var cell := Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))
	var sz: int = _tile_tree_size.get(cell, 2) as int
	match sz:
		0: return 1.2    # small — low arc clears
		2: return 4.8    # tall — disc rarely clears
		_: return 3.0    # medium — normal

## Returns true if tile_type facility exists within radius world units of world_pos.
func has_facility_near(world_pos: Vector3, tile_type: int, radius: float) -> bool:
	var cr := ceili(radius / CELL_SIZE)
	var cc := Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))
	for dc in range(-cr, cr + 1):
		for dr in range(-cr, cr + 1):
			if _tiles.get(Vector2i(cc.x + dc, cc.y + dr), TileType.GRASS) == tile_type:
				return true
	return false

## Returns tile size for tree tiles (0=small, 1=medium, 2=tall).
func get_tile_tree_size(cell: Vector2i) -> int:
	return _tile_tree_size.get(cell, 2) as int

func set_tile_tree_size(cell: Vector2i, sz: int) -> void:
	_tile_tree_size[cell] = sz
	if _tiles.get(cell, TileType.GRASS) == TileType.TREE:
		_update_tile_visual(cell, TileType.TREE, false)

func spawn_score_popup(world_pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text         = text
	label.modulate     = color
	label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size    = 36
	label.outline_size = 6
	label.position     = world_pos + Vector3(0.0, 2.0, 0.0)
	label.scale        = Vector3.ZERO
	add_child(label)

	# Burst particles at basket
	var burst := CPUParticles3D.new()
	burst.emitting               = true
	burst.one_shot               = true
	burst.amount                 = 20
	burst.lifetime               = 1.0
	burst.fixed_fps              = 0
	burst.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.3
	burst.direction              = Vector3(0, 1, 0)
	burst.spread                 = 80.0
	burst.gravity                = Vector3(0, -3.0, 0)
	burst.initial_velocity_min   = 2.0
	burst.initial_velocity_max   = 5.0
	burst.scale_amount_min       = 0.10
	burst.scale_amount_max       = 0.22
	burst.color                  = color
	burst.position               = world_pos + Vector3(0, 1.5, 0)
	add_child(burst)
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)

	# Scale punch then float up and fade — all parallel with explicit delays
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * 1.5, 0.15).set_ease(Tween.EASE_OUT).set_delay(0.0)
	tween.tween_property(label, "scale", Vector3.ONE, 0.10).set_ease(Tween.EASE_IN).set_delay(0.15)
	tween.tween_property(label, "position:y", world_pos.y + 6.0, 2.0).set_delay(0.25)
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

func get_world_center() -> Vector3:
	return Vector3(GRID_COLS * CELL_SIZE * 0.5, 0.0, GRID_ROWS * CELL_SIZE * 0.5)

func set_gameplay_mode(enabled: bool) -> void:
	_gameplay_mode = enabled
	if enabled:
		_build_all_holes()
		if not _holes.is_empty():
			_refresh_spawn_interval()
			_try_spawn_npc()
			_spawn_timer.start()
		else:
			push_warning("GameWorld: no holes built — NPCs will not spawn")
			# Tees and baskets but no gate: tell the player why nobody comes.
			if not get_holes_info().is_empty() and get_tiles_of_type(TileType.ENTRANCE).is_empty():
				EventBus.notification_requested.emit(
					"No players can arrive — build an Entrance in the Course Builder.", "warning")
		_respawn_existing_staff()
	else:
		_spawn_timer.stop()
		# Tell the economy these players left. Without this, every trip to the
		# builder / world map left "ghost" players paying green fees forever
		# (playthrough bot: 9 → 160 counted players by day 50).
		for child in _npc_root.get_children():
			if not child.is_queued_for_deletion():
				var nid: Variant = child.get("_npc_id")
				if nid != null:
					EventBus.npc_left.emit(str(nid))
			child.queue_free()
		_npc_count = 0
		# Clear visual staff when leaving gameplay — they'll re-sync from EconomyManager on re-enter
		for type_arr in _staff_nodes:
			for member in (type_arr as Array):
				if is_instance_valid(member):
					member.queue_free()
		_staff_nodes = [[], [], []]

func serialize_tiles() -> Array:
	var out: Array = []
	for key in _tiles:
		var entry: Dictionary = { "c": key.x, "r": key.y, "t": _tiles[key] }
		var h: float = _tile_heights.get(key, 0.0) as float
		if h != 0.0:     entry["h"] = h
		var v: int = _tile_variants.get(key, -99) as int
		if v != -99:     entry["v"] = v
		var sz: int = _tile_tree_size.get(key, -99) as int
		if sz != -99:    entry["sz"] = sz
		var o: int = _tile_orientations.get(key, -99) as int
		if o != -99:     entry["o"] = o
		var p: int = _tile_par.get(key, -99) as int
		if p != -99:     entry["p"] = p
		var n: int = _tile_hole_num.get(key, -99) as int
		if n != -99:     entry["n"] = n
		var fo: int = _facility_orientations.get(key, -99) as int
		if fo != -99:    entry["fo"] = fo
		var fc: int = _facility_colors.get(key, -99) as int
		if fc != -99:    entry["fc"] = fc
		var ba: Vector2i = _building_anchor.get(key, Vector2i(-1,-1)) as Vector2i
		if ba != Vector2i(-1,-1) and ba != key:
			entry["bax"] = ba.x; entry["bay"] = ba.y
		out.append(entry)
	# OB overlay entries
	for key in _ob_zones:
		var k := key as Vector2i
		out.append({"c": k.x, "r": k.y, "ob": _ob_zones[k] as int})
	# Rock overlay entries
	for key in _rock_overlays:
		var k := key as Vector2i
		out.append({"c": k.x, "r": k.y, "rk": 1})
	# Waypoints as a special entry
	if not _hole_waypoints.is_empty():
		var wp_entry: Dictionary = {"waypoints": {}}
		for hn in _hole_waypoints:
			var cells: Array = _hole_waypoints[hn] as Array
			var arr: Array = []
			for c in cells:
				arr.append({"x": (c as Vector2i).x, "y": (c as Vector2i).y})
			wp_entry["waypoints"][str(hn)] = arr
		out.append(wp_entry)
	return out

func deserialize_tiles(data: Array) -> void:
	_tile_variants.clear()
	_tile_tree_size.clear()
	_tile_orientations.clear()
	_tile_par.clear()
	_tile_hole_num.clear()
	_facility_orientations.clear()
	_facility_colors.clear()
	_building_anchor.clear()
	_hole_waypoints.clear()
	_ob_zones.clear()
	_rock_overlays.clear()
	for entry in data:
		# Waypoints special entry
		if entry.has("waypoints"):
			var wps = entry["waypoints"]
			for hn_str in wps:
				var hn: int = int(hn_str)
				var cells: Array = []
				for c in (wps[hn_str] as Array):
					cells.append(Vector2i(int(c["x"]), int(c["y"])))
				_hole_waypoints[hn] = cells
			continue
		var key := Vector2i(int(entry["c"]), int(entry["r"]))
		# OB overlay entry
		if entry.has("ob"):
			_ob_zones[key] = int(entry["ob"])
			_update_ob_prop(key)
			continue
		# Rock overlay entry
		if entry.has("rk"):
			_rock_overlays[key] = true
			_update_rock_prop(key)
			continue
		var tt: int = int(entry["t"])
		_tiles[key] = tt
		if entry.has("h"):  _tile_heights[key]          = float(entry["h"])
		if entry.has("v"):  _tile_variants[key]         = int(entry["v"])
		var sz: int = entry.get("sz", -99) as int
		if sz != -99:
			_tile_tree_size[key] = sz
		if entry.has("o"):  _tile_orientations[key]     = int(entry["o"])
		if entry.has("p"):  _tile_par[key]              = int(entry["p"])
		if entry.has("n"):  _tile_hole_num[key]         = int(entry["n"])
		if entry.has("fo"): _facility_orientations[key] = int(entry["fo"])
		if entry.has("fc"): _facility_colors[key]       = int(entry["fc"])
		if entry.has("bax") and entry.has("bay"):
			_building_anchor[key] = Vector2i(int(entry["bax"]), int(entry["bay"]))
		_update_tile_visual(key, tt, false)
	# Rebuild anchor for any PRO_SHOP anchor cells not explicitly stored
	for key in _tiles:
		if _tiles[key] == TileType.PRO_SHOP and not _building_anchor.has(key):
			_building_anchor[key] = key  # self = anchor
	_rebuild_water_layer()
	_rebuild_smooth_surface()

# ── Tile world-Y (type base + per-tile terraform offset) ───────────────────────

func _get_tile_world_y(key: Vector2i, tt: int) -> float:
	return TILE_Y.get(tt, 0.0) + (_tile_heights.get(key, 0.0) as float)

# Box center so its TOP FACE aligns with world_y + CELL_HEIGHT/2 (tile surface)
func _terrain_box_center_y(world_y: float) -> float:
	return world_y + CELL_HEIGHT * 0.5 - TERRAIN_BOX_HEIGHT * 0.5

# ── Environment ───────────────────────────────────────────────────────────────

func _apply_graphics_settings(s: Dictionary) -> void:
	if _world_env_node == null or _sun == null or _sky == null:
		return
	var env := _world_env_node.environment

	env.glow_enabled = s.get("glow", false)
	_set_tree_detail(int(s.get("trees", 1)) == 1)
	if _grass_tuft_mmi:
		_grass_tuft_mmi.visible = s.get("clutter", true)

	if s.get("sky", 1) == 1 and _hdri_sky_mat != null:
		_sky.sky_material = _hdri_sky_mat
	else:
		_sky.sky_material = _proc_sky_mat

	_apply_compat_light_fix(int(s.get("shadows", 1)) > 0)

	match s.get("shadows", 1):
		0:
			_sun.shadow_enabled = false
		1:
			_sun.shadow_enabled = true
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			_sun.directional_shadow_max_distance = 80.0
		2:
			_sun.shadow_enabled = true
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			_sun.directional_shadow_max_distance = 180.0

## Lighting tuned for Forward+ (the project's renderer). On machines that fall
## back to the Compatibility renderer, a shadow-casting sun is drawn in an extra
## additive pass that comes out ~25 % brighter and oversaturated (washed-out
## yellow dirt, white paths). With shadows on there, these values were fitted
## against Forward+ screenshots (mean colour within ~1 %). Without shadows the
## renderers already match, so the normal values apply.
const SUN_ENERGY := 1.5
const AMBIENT_ENERGY := 0.70
const SATURATION := 0.92
const COMPAT_SHADOW_LIGHT := {"sun": 1.0, "ambient": 0.35, "saturation": 0.80}

static func is_compat_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

func _apply_compat_light_fix(shadows_on: bool) -> void:
	var env := _world_env_node.environment
	var fix := shadows_on and is_compat_renderer()
	_sun.light_energy          = COMPAT_SHADOW_LIGHT["sun"] if fix else SUN_ENERGY
	env.ambient_light_energy   = COMPAT_SHADOW_LIGHT["ambient"] if fix else AMBIENT_ENERGY
	env.adjustment_saturation  = COMPAT_SHADOW_LIGHT["saturation"] if fix else SATURATION

func _make_procedural_sky() -> ProceduralSkyMaterial:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.18, 0.44, 0.85)   # rich blue zenith
	sky_mat.sky_horizon_color    = Color(0.72, 0.78, 0.88)   # warm hazy horizon
	sky_mat.sky_curve            = 0.09
	sky_mat.ground_bottom_color  = Color(0.16, 0.24, 0.12)
	sky_mat.ground_horizon_color = Color(0.50, 0.54, 0.38)
	sky_mat.ground_curve         = 0.02
	sky_mat.sun_angle_max        = 28.0
	sky_mat.sun_curve            = 0.08
	sky_mat.energy_multiplier    = 1.0
	return sky_mat

func _create_environment() -> void:
	var env := Environment.new()

	# Sky — load both materials; _apply_graphics_settings picks which to show
	var sky := Sky.new()
	_sky = sky
	var hdri_path := "res://assets/textures/hdri/kloofendal_38d_partly_cloudy_4k.exr"
	if ResourceLoader.exists(hdri_path):
		var hdri_tex := load(hdri_path) as Texture2D
		if hdri_tex != null:
			var pano := PanoramaSkyMaterial.new()
			pano.panorama          = hdri_tex
			# Compatibility renders this panorama ~20 % darker; 1.25 matches Forward+.
			pano.energy_multiplier = 1.25 if is_compat_renderer() else 0.55
			_hdri_sky_mat          = pano
	_proc_sky_mat    = _make_procedural_sky()
	sky.sky_material = _hdri_sky_mat if _hdri_sky_mat != null else _proc_sky_mat

	env.background_mode      = Environment.BG_SKY
	env.sky                  = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(1.0, 0.93, 0.82)
	env.ambient_light_energy = AMBIENT_ENERGY

	# Filmic tonemapping — gentle S-curve, preserves color accuracy
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.tonemap_white    = 1.0

	# Warm color adjustment pass
	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast   = 1.02
	env.adjustment_saturation = SATURATION   # tile colours render as true sRGB now (were washed out)

	# Glow / bloom (requires Forward+ renderer)
	env.glow_enabled             = true
	env.glow_normalized          = false
	env.glow_intensity           = 0.40
	env.glow_strength            = 0.9
	env.glow_bloom               = 0.06
	env.glow_blend_mode          = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold       = 1.0
	env.glow_hdr_scale           = 2.0
	env.glow_hdr_luminance_cap   = 12.0

	# SSAO — ambient occlusion in crevices, tree bases, building corners (Forward+ only)
	env.ssao_enabled    = true
	env.ssao_radius     = 1.2
	env.ssao_intensity  = 1.8
	env.ssao_power      = 1.5
	env.ssao_detail     = 0.5
	env.ssao_horizon    = 0.06
	env.ssao_sharpness  = 0.98

	# SSIL — indirect light bounce (Forward+ only)
	env.ssil_enabled    = true
	env.ssil_radius     = 5.0
	env.ssil_intensity  = 1.0
	env.ssil_sharpness  = 0.98

	# SSR — reflections on water surface (Forward+ only)
	env.ssr_enabled          = true
	env.ssr_max_steps        = 64
	env.ssr_fade_in          = 0.15
	env.ssr_fade_out         = 2.0
	env.ssr_depth_tolerance  = 0.2

	# Light haze for depth in the low throwing camera. Kept thin: the course
	# camera sits ~130 m up, so any density washes the whole view out evenly
	# (0.003 used to cover ~30% of every pixel). Sky mostly untouched so it stays blue.
	env.fog_enabled        = true
	env.fog_light_color    = Color(0.80, 0.84, 0.88)
	env.fog_sun_scatter    = 0.20
	env.fog_density        = 0.0010
	env.fog_sky_affect     = 0.25
	env.fog_height         = -6.0
	env.fog_height_density = 0.08

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_world_env_node = we

	# Primary warm sun — moderately steep, good shadow angle for isometric view
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 38.0, 0.0)
	sun.light_color      = Color(1.0, 0.96, 0.88)
	sun.light_energy     = SUN_ENERGY
	sun.shadow_enabled   = true
	sun.directional_shadow_mode             = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias                         = 0.04
	sun.directional_shadow_blend_splits     = true
	sun.directional_shadow_max_distance     = 180.0
	sun.directional_shadow_split_1          = 0.25
	_sun = sun
	add_child(sun)

	# Secondary cool fill light (from north, no shadow)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	fill.light_color      = Color(0.78, 0.82, 0.90)
	fill.light_energy     = 0.22
	add_child(fill)

	_apply_graphics_settings(GameManager.get_graphics_settings())

# ── Default course layout ─────────────────────────────────────────────────────
# New game = Uncle Ray's land (STORY.md Ch0): three rough, playable holes he
# built by hand, laid out as a loop from the gate, in an overgrown field.
# Existing saves never see this — they import their home snapshot instead.

func _generate_default_course() -> void:
	for col in GRID_COLS:
		for row in GRID_ROWS:
			_tiles[Vector2i(col, row)] = TileType.GRASS

	var cx := GRID_COLS / 2   # 75

	# Overgrown field: rough everywhere around the loop
	for c in range(cx - 8, cx + 42):
		for r in range(0, 42):
			_tiles[Vector2i(c, r)] = TileType.ROUGH

	# Gate + approach path
	_tiles[Vector2i(cx, 0)] = TileType.ENTRANCE
	_tiles[Vector2i(cx, 1)] = TileType.PATH
	_tiles[Vector2i(cx, 2)] = TileType.PATH

	# Ray only ever mowed a short strip off each tee — the rest is rough.
	# Holes rate ~2★ so mowing fairways / adding hazards is the first upgrade.
	# Hole 1 — south from the gate (~56 m)
	_paint_rect(cx, cx, 4, 9, TileType.FAIRWAY)
	_place_hole(1, Vector2i(cx, 3), 2, Vector2i(cx, 31))

	# Hole 2 — east along the bottom (~54 m)
	_paint_rect(cx + 5, cx + 10, 33, 33, TileType.FAIRWAY)
	_place_hole(2, Vector2i(cx + 4, 33), 1, Vector2i(cx + 31, 33))

	# Hole 3 — back north toward the road (~50 m)
	_paint_rect(cx + 33, cx + 33, 24, 29, TileType.FAIRWAY)
	_place_hole(3, Vector2i(cx + 33, 30), 0, Vector2i(cx + 33, 5))

	# Worn walking path: basket 1 → tee 2, basket 3 → back to the gate
	_paint_rect(cx + 1, cx + 3, 33, 33, TileType.PATH)
	_paint_rect(cx + 1, cx + 33, 2, 2, TileType.PATH)
	_paint_rect(cx + 33, cx + 33, 3, 4, TileType.PATH)

	# Ray's pond in the middle of the loop
	_paint_rect(cx + 13, cx + 20, 11, 20, TileType.WATER)

	# A few of Ray's old trees along each line (each hole's rating counts trees
	# within 10 cells, so only a handful sit near play — keeps holes ~2★).
	for t in [Vector2i(cx - 3, 12), Vector2i(cx + 3, 18), Vector2i(cx - 2, 25),
			Vector2i(cx + 12, 30), Vector2i(cx + 20, 36), Vector2i(cx + 26, 31),
			Vector2i(cx + 30, 22), Vector2i(cx + 36, 15), Vector2i(cx + 31, 9)]:
		_tiles[t] = TileType.TREE
	# Overgrown look further out: saplings in the rough away from the holes
	var holes_now := get_holes_info()
	for c in range(cx - 8, cx + 42):
		for r in range(0, 42):
			var key := Vector2i(c, r)
			if _tiles[key] != TileType.ROUGH or _cell_hash(c, r) % 100 >= 10:
				continue
			var near_hole := false
			for h in holes_now:
				var tc: Vector2i = h["tee_cell"]
				var bc: Vector2i = h["basket_cell"]
				if c >= mini(tc.x, bc.x) - 10 and c <= maxi(tc.x, bc.x) + 10 \
						and r >= mini(tc.y, bc.y) - 10 and r <= maxi(tc.y, bc.y) + 10:
					near_hole = true
					break
			if not near_hole:
				_tiles[key] = TileType.TREE
	var clusters: Array = [
		[cx - 20, cx - 12, 4, 20], [cx - 20, cx - 12, 26, 44],
		[cx + 44, cx + 52, 6, 24], [cx + 6, cx + 28, 44, 50],
	]
	for cl in clusters:
		_paint_rect(cl[0], cl[1] - 1, cl[2], cl[3] - 1, TileType.TREE, true)

func _paint_rect(c0: int, c1: int, r0: int, r1: int, tt: int, only_grass: bool = false) -> void:
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			var key := Vector2i(c, r)
			if not _valid(key):
				continue
			if only_grass and _tiles.get(key, TileType.GRASS) != TileType.GRASS:
				continue
			_tiles[key] = tt

func _place_hole(num: int, tee: Vector2i, orientation: int, basket: Vector2i) -> void:
	_tiles[tee] = TileType.TEE
	_tile_hole_num[tee] = num
	_tile_orientations[tee] = orientation
	_tiles[basket] = TileType.BASKET
	_tile_hole_num[basket] = num

# ── Terrain MultiMesh (one draw call for all non-water tiles) ─────────────────

func _build_terrain() -> void:
	var bm := BoxMesh.new()
	# Tall box: top face = tile surface, sides extend underground to show cliffs under raised terrain.
	# Slight overlap (+0.02) prevents visible gaps between tiles at isometric angle.
	bm.size = Vector3(CELL_SIZE + 0.08, TERRAIN_BOX_HEIGHT, CELL_SIZE + 0.08)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb       = true   # TILE_COLOR values are sRGB, like albedo_color
	mat.roughness                  = 0.75
	bm.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors       = true
	mm.mesh             = bm
	mm.instance_count   = GRID_COLS * GRID_ROWS

	for col in GRID_COLS:
		for row in GRID_ROWS:
			var key := Vector2i(col, row)
			var tt  := _tiles.get(key, TileType.GRASS) as int
			var xf  := Transform3D.IDENTITY
			xf.origin = Vector3(col * CELL_SIZE, _terrain_box_center_y(_get_tile_world_y(key, tt)), row * CELL_SIZE)
			mm.set_instance_transform(col * GRID_ROWS + row, xf)
			mm.set_instance_color(col * GRID_ROWS + row,
				TILE_COLOR.get(tt, TILE_COLOR[TileType.GRASS]))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh   = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible     = true
	add_child(mmi)
	_terrain_mm = mm

# ── Ground skirt + border walls — hide box sides at world boundary ───────────

func _add_ground_skirt() -> void:
	# Grass-coloured ground around the grid, flush with the grass surface, so the
	# course edge reads as more field instead of a raised rim. Four strips (not one
	# big plane) so it never covers lowered tiles or ponds inside the grid.
	var margin := 400.0
	var top_y: float = (TILE_Y[TileType.GRASS] as float) + CELL_HEIGHT * 0.5 - 0.02
	var x0 := -CELL_SIZE * 0.5
	var z0 := -CELL_SIZE * 0.5
	var x1 := (GRID_COLS - 0.5) * CELL_SIZE
	var z1 := (GRID_ROWS - 0.5) * CELL_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TILE_COLOR[TileType.GRASS] as Color
	mat.roughness    = 0.75
	var strips := [   # [centre x, centre z, size x, size z]
		[(x0 + x1) * 0.5, z0 - margin * 0.5, x1 - x0 + margin * 2.0, margin],   # north
		[(x0 + x1) * 0.5, z1 + margin * 0.5, x1 - x0 + margin * 2.0, margin],   # south
		[x0 - margin * 0.5, (z0 + z1) * 0.5, margin, z1 - z0],                  # west
		[x1 + margin * 0.5, (z0 + z1) * 0.5, margin, z1 - z0],                  # east
	]
	for st in strips:
		var pm := PlaneMesh.new()
		pm.size = Vector2(st[2], st[3])
		pm.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(st[0], top_y, st[1])
		add_child(mi)

# ── Water surface — shiny separate layer ──────────────────────────────────────

func _build_water_layer() -> void:
	var water_cells: Array = []
	for key in _tiles:
		if _tiles[key] == TileType.WATER:
			water_cells.append(key)

	if water_cells.is_empty():
		return

	var plane := BoxMesh.new()
	plane.size = Vector3(CELL_SIZE + 0.02, 0.03, CELL_SIZE + 0.02)

	var water_shader_src := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform float time_offset = 0.0;
uniform vec4 water_color : source_color = vec4(0.02, 0.30, 0.88, 0.92);
uniform vec4 foam_color  : source_color = vec4(0.72, 0.90, 1.00, 1.00);
void fragment() {
	vec2 uv = UV * 5.0;
	float w1 = sin(uv.x * 4.8 + time_offset * 1.9) * 0.06;
	float w2 = sin(uv.y * 3.8 + time_offset * 1.5 + 1.2) * 0.05;
	float w3 = sin((uv.x + uv.y) * 2.5 + time_offset * 1.1) * 0.03;
	float wave = w1 + w2 + w3;
	float foam = smoothstep(0.08, 0.14, wave);
	vec3 base = mix(water_color.rgb, water_color.rgb * 1.25, clamp(wave * 4.0, 0.0, 1.0));
	ALBEDO = mix(base, foam_color.rgb, foam * 0.35);
	ALPHA = water_color.a;
	ROUGHNESS = max(0.02, 0.06 - wave * 0.5);
	METALLIC = 0.55;
	SPECULAR = 0.9;
	EMISSION = water_color.rgb * (0.18 + wave * 0.30) + foam_color.rgb * foam * 0.12;
}
"""
	# Built once and reused: a new Shader per rebuild meant a shader compile
	# (GPU hitch) every time a tile was painted.
	if _water_shader == null:
		var sh := Shader.new()
		sh.code = water_shader_src
		_water_shader = ShaderMaterial.new()
		_water_shader.shader = sh
		_water_shader.set_shader_parameter("water_color", Color(0.02, 0.30, 0.88, 0.92))
		_water_shader.set_shader_parameter("foam_color",  Color(0.72, 0.90, 1.00, 1.00))
	plane.surface_set_material(0, _water_shader)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh             = plane
	mm.instance_count   = water_cells.size()

	for i in water_cells.size():
		var key: Vector2i = water_cells[i]
		var xf := Transform3D.IDENTITY
		xf.origin = Vector3(key.x * CELL_SIZE, WATER_SURFACE_Y, key.y * CELL_SIZE)
		mm.set_instance_transform(i, xf)

	_water_mmi = MultiMeshInstance3D.new()
	_water_mmi.multimesh   = mm
	_water_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water_mmi)

func _rebuild_water_layer() -> void:
	if _water_mmi:
		_water_mmi.queue_free()
		_water_mmi = null
	_build_water_layer()

# ── Smooth terrain surface — sloped top faces + cliff walls ───────────────────
# Single ArrayMesh for all non-water tiles. Corner heights averaged from
# all adjacent tiles give smooth slopes. Vertical wall faces fill the cliff
# sides wherever this tile's surface is higher than its neighbor's.

## Corner height at grid point (cx, cz) — average of up to 4 adjacent tile surfaces.
## Used by get_ground_y() for bilinear lookup.
func _get_corner_y(cx: int, cz: int) -> float:
	const SURFACE_OFFSET := 0.04
	var sum := 0.0; var cnt := 0
	for dx in [-1, 0]:
		for dz in [-1, 0]:
			var tc := Vector2i(cx + dx, cz + dz)
			if _valid(tc):
				var tt2: int = _tiles.get(tc, TileType.GRASS) as int
				if tt2 == TileType.WATER:
					sum += WATER_SURFACE_Y  # water at fixed depth, creates smooth shore
				else:
					sum += _get_tile_world_y(tc, tt2) + CELL_HEIGHT * 0.5
				cnt += 1
	return (sum / float(cnt) + SURFACE_OFFSET) if cnt > 0 else SURFACE_OFFSET

## Rebuilds the derived terrain overlays after tile edits: diagonal edge fill
## and tree contact shadows. (This used to also build a full sloped ArrayMesh of
## the whole grid — ~130 ms on big courses after every paint stroke — that was
## never shown or read: the MultiMesh boxes draw the ground and get_ground_y()
## uses _get_corner_y() directly. Removed 2026-11-21.)
func _build_smooth_surface() -> void:
	_build_edge_fill()
	_build_contact_shadows()

## Distance fog only helps the low perspective (throwing) camera. The course
## camera is orthographic and ~130 m up: fog there just tints every pixel the
## same, washing the whole course out, so it's off in that view.
func _update_fog_for_camera() -> void:
	if _world_env_node == null:
		return
	var cam := get_viewport().get_camera_3d()
	var want := cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
	var env := _world_env_node.environment
	if env and env.fog_enabled != want:
		env.fog_enabled = want

# ── Smooth tile edges ────────────────────────────────────────────────────────
# Diagonal fairways/paths painted on the grid look like staircases. A cell that
# sits in the notch of a step (two neighbours on adjacent sides share a "higher"
# ground type) gets that half of itself painted in the neighbours' colour, so the
# step becomes a straight 45° edge. Visual only — gameplay still uses the grid.

const _EDGE_BASE_RANK := {0: 0, 4: 1, 13: 2, 1: 3}           # GRASS, ROUGH, SAND, FAIRWAY
const _EDGE_FILL_RANK := {4: 1, 13: 2, 1: 3, 7: 3, 2: 4}     # + BASKET (as fairway), PATH

func _edge_type_at(cell: Vector2i) -> int:
	if not _valid(cell):
		return -1
	var t: int = _tiles.get(cell, TileType.GRASS) as int
	return TileType.FAIRWAY if t == TileType.BASKET else t

const _RANK_TABLE_SIZE := 64

static func _rank_table(ranks: Dictionary) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(_RANK_TABLE_SIZE)
	t.fill(-1)
	for k in ranks:
		t[int(k)] = int(ranks[k])
	return t

func _build_edge_fill() -> void:
	# Flat type grid + rank tables: the per-neighbour dictionary lookups used to
	# cost ~35 ms on big courses (after every paint). Most cells exit at the
	# quick reject below.
	var types := PackedInt32Array()
	types.resize(GRID_COLS * GRID_ROWS)   # 0 = GRASS
	for key in _tiles:
		var k := key as Vector2i
		if _valid(k):
			types[k.x * GRID_ROWS + k.y] = int(_tiles[key])
	var base_rank := _rank_table(_EDGE_BASE_RANK)
	var fill_rank := _rank_table(_EDGE_FILL_RANK)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var h := CELL_SIZE * 0.5
	for col in GRID_COLS:
		for row in GRID_ROWS:
			var gi := col * GRID_ROWS + row
			var ct := types[gi]
			var rank := base_rank[ct] if ct < _RANK_TABLE_SIZE else -1
			if rank < 0:
				continue
			# Quick reject: no neighbour can fill this cell.
			var best := -1
			if row > 0:             best = maxi(best, _nb_fill_rank(types[gi - 1], fill_rank))
			if col < GRID_COLS - 1: best = maxi(best, _nb_fill_rank(types[gi + GRID_ROWS], fill_rank))
			if row < GRID_ROWS - 1: best = maxi(best, _nb_fill_rank(types[gi + 1], fill_rank))
			if col > 0:             best = maxi(best, _nb_fill_rank(types[gi - GRID_ROWS], fill_rank))
			if best <= rank:
				continue
			var c := Vector2i(col, row)
			var cx := col * CELL_SIZE
			var cz := row * CELL_SIZE
			var nw := Vector2(cx - h, cz - h); var ne := Vector2(cx + h, cz - h)
			var se := Vector2(cx + h, cz + h); var sw := Vector2(cx - h, cz + h)
			var c_top := _get_tile_world_y(c, ct) + CELL_HEIGHT * 0.5
			var nb := [_edge_type_at(c + Vector2i(0, -1)), _edge_type_at(c + Vector2i(1, 0)),
					_edge_type_at(c + Vector2i(0, 1)), _edge_type_at(c + Vector2i(-1, 0))]   # N E S W
			# Best (highest-rank) ground type that borders this cell on 2+ sides.
			var fill := -1
			for t in nb:
				if _EDGE_FILL_RANK.has(t) and int(_EDGE_FILL_RANK[t]) > rank and nb.count(t) >= 2 \
						and (fill == -1 or int(_EDGE_FILL_RANK[t]) > int(_EDGE_FILL_RANK[fill])):
					fill = t
			if fill == -1:
				continue
			var has := [nb[0] == fill, nb[1] == fill, nb[2] == fill, nb[3] == fill]
			var n := has.count(true)
			var col_c := TILE_COLOR.get(fill, TILE_COLOR[TileType.FAIRWAY]) as Color
			var y := c_top + 0.006
			var n_top := INF
			for i in 4:
				if has[i]:
					var nc: Vector2i = c + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][i]
					n_top = minf(n_top, _get_tile_world_y(nc, fill) + CELL_HEIGHT * 0.5)
			if absf(n_top - c_top) < 0.15:
				y = maxf(c_top, n_top) + 0.006
			# A notch with fairway on 3–4 sides, or a 1-cell gap in a line, fills
			# completely (bumpy edges become straight instead of saw-toothed).
			if n >= 3 or (n == 2 and ((has[0] and has[2]) or (has[1] and has[3]))):
				_emit_flat_tri(st, [nw, ne, se], y, col_c)
				_emit_flat_tri(st, [se, sw, nw], y, col_c)
				count += 2
				continue
			# Outer corner of a staircase: fill the half facing the two neighbours.
			var tri: Array = []
			if has[0] and has[1]: tri = [nw, ne, se]
			elif has[1] and has[2]: tri = [ne, se, sw]
			elif has[2] and has[3]: tri = [se, sw, nw]
			elif has[3] and has[0]: tri = [sw, nw, ne]
			_emit_flat_tri(st, tri, y, col_c)
			count += 1
	if _edge_fill_msi and is_instance_valid(_edge_fill_msi):
		_edge_fill_msi.queue_free()
	_edge_fill_msi = null
	if count == 0:
		return
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb       = true   # TILE_COLOR values are sRGB, like albedo_color
	mat.roughness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	_edge_fill_msi = MeshInstance3D.new()
	_edge_fill_msi.mesh = mesh
	_edge_fill_msi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_edge_fill_msi)

## Fill rank of a neighbour type (baskets count as fairway, like _edge_type_at).
static func _nb_fill_rank(t: int, fill_rank: PackedInt32Array) -> int:
	if t == TileType.BASKET:
		t = TileType.FAIRWAY
	return fill_rank[t] if t >= 0 and t < _RANK_TABLE_SIZE else -1

## Upward-facing triangle from three XZ points (re-wound so it faces up).
func _emit_flat_tri(st: SurfaceTool, pts: Array, y: float, color: Color) -> void:
	var a: Vector2 = pts[0]; var b: Vector2 = pts[1]; var c: Vector2 = pts[2]
	# Godot front faces are clockwise seen from above
	if (b.y - a.y) * (c.x - a.x) - (b.x - a.x) * (c.y - a.y) > 0.0:
		var tmp := b; b = c; c = tmp
	for p in [a, b, c]:
		st.set_color(color)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3((p as Vector2).x, y, (p as Vector2).y))

# ── Contact shadows ──────────────────────────────────────────────────────────
# The GL Compatibility renderer has no SSAO, so trees float a little on the
# grass. One MultiMesh of soft radial blobs (single draw call) grounds them.

const _CONTACT_SIZE := {0: 1.6, 1: 2.6, 2: 3.4}   # tree size → blob diameter (m)

func _build_contact_shadows() -> void:
	var trees: Array = []
	for key in _tiles:
		if int(_tiles[key]) == TileType.TREE:
			trees.append(key)
	if _contact_mmi == null or not is_instance_valid(_contact_mmi):
		var tex := GradientTexture2D.new()
		tex.width = 64; tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.06, 0.01, 0.42))
		g.set_color(1, Color(0.02, 0.06, 0.01, 0.0))
		tex.gradient = g
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		pm.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pm
		_contact_mmi = MultiMeshInstance3D.new()
		_contact_mmi.multimesh = mm
		_contact_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_contact_mmi)
	var mm2: MultiMesh = _contact_mmi.multimesh
	mm2.instance_count = trees.size()
	for i in trees.size():
		var cell: Vector2i = trees[i]
		var d: float = _CONTACT_SIZE.get(_tile_tree_size.get(cell, 2) as int, 2.6)
		var top := _get_tile_world_y(cell, TileType.TREE) + CELL_HEIGHT * 0.5 + 0.012
		var xf := Transform3D(Basis().scaled(Vector3(d, 1.0, d)), Vector3(cell.x * CELL_SIZE, top, cell.y * CELL_SIZE))
		mm2.set_instance_transform(i, xf)

## Ground skirt + edge helpers used by tests.
func get_edge_fill_mesh() -> Mesh:
	return _edge_fill_msi.mesh if _edge_fill_msi and is_instance_valid(_edge_fill_msi) else null

func get_contact_shadow_count() -> int:
	return _contact_mmi.multimesh.instance_count if _contact_mmi and is_instance_valid(_contact_mmi) else 0

func _rebuild_smooth_surface() -> void:
	_build_smooth_surface()

func _add_grass_tufts() -> void:
	var tuft_cells: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for key in _tiles:
		var tt: int = _tiles[key] as int
		if (tt == TileType.GRASS or tt == TileType.ROUGH) and rng.randi() % 3 == 0:
			tuft_cells.append(key)
	if tuft_cells.is_empty():
		return

	var tuft_mesh := CylinderMesh.new()
	tuft_mesh.top_radius      = 0.0
	tuft_mesh.bottom_radius   = 0.07
	tuft_mesh.height          = 0.34
	tuft_mesh.radial_segments = 4

	var tuft_mat := StandardMaterial3D.new()
	tuft_mat.albedo_color = Color(0.20, 0.62, 0.14)
	tuft_mat.roughness    = 0.92

	# 5 tufts per selected cell
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh             = tuft_mesh
	mm.instance_count   = tuft_cells.size() * 5

	var idx := 0
	for key in tuft_cells:
		var kv := key as Vector2i
		var world_y := _get_tile_world_y(kv, _tiles[kv] as int) + CELL_HEIGHT * 0.5 + 0.02
		for _j in 5:
			var ox := rng.randf_range(-0.78, 0.78)
			var oz := rng.randf_range(-0.78, 0.78)
			var angle := rng.randf() * TAU
			var h_scale := 0.7 + rng.randf() * 0.6
			var xf := Transform3D(Basis.from_euler(Vector3(0, angle, 0)).scaled(Vector3(1.0, h_scale, 1.0)), Vector3.ZERO)
			xf.origin = Vector3(kv.x * CELL_SIZE + ox, world_y, kv.y * CELL_SIZE + oz)
			mm.set_instance_transform(idx, xf)
			idx += 1

	_grass_tuft_mmi = MultiMeshInstance3D.new()
	_grass_tuft_mmi.multimesh         = mm
	_grass_tuft_mmi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass_tuft_mmi.material_override = tuft_mat
	add_child(_grass_tuft_mmi)

func _spawn_wind_particles() -> void:
	_wind_particles = CPUParticles3D.new()
	_wind_particles.emitting              = true
	_wind_particles.amount               = 60
	_wind_particles.lifetime             = 5.0
	_wind_particles.fixed_fps            = 0
	_wind_particles.emission_shape       = CPUParticles3D.EMISSION_SHAPE_BOX
	_wind_particles.emission_box_extents = Vector3(80.0, 1.0, 80.0)
	_wind_particles.direction            = Vector3(1, 0, 0)
	_wind_particles.spread               = 8.0
	_wind_particles.gravity              = Vector3(0, -0.05, 0)
	_wind_particles.initial_velocity_min = 2.0
	_wind_particles.initial_velocity_max = 4.5
	_wind_particles.scale_amount_min     = 0.04
	_wind_particles.scale_amount_max     = 0.10
	_wind_particles.color                = Color(0.65, 0.80, 0.45, 0.55)
	_wind_particles.position             = Vector3(GRID_COLS * CELL_SIZE * 0.5, 2.5, GRID_ROWS * CELL_SIZE * 0.5)
	add_child(_wind_particles)

	EventBus.wind_changed.connect(func(angle: float, speed: float) -> void:
		if _wind_particles:
			_wind_particles.direction            = Vector3(sin(angle), 0.0, cos(angle))
			_wind_particles.initial_velocity_min = speed * 0.6
			_wind_particles.initial_velocity_max = speed * 1.5
	)

# ── Props ──────────────────────────────────────────────────────────────────────

func _place_all_props() -> void:
	_props_node = Node3D.new()
	_props_node.name = "Props"
	add_child(_props_node)
	_setup_prop_batch()

	for col in GRID_COLS:
		for row in GRID_ROWS:
			var key := Vector2i(col, row)
			var tt: int = _tiles.get(key, TileType.GRASS)
			if _batch_cell(key, tt, _get_tile_world_y(key, tt)):
				continue
			var prop := _prop_for(tt, col, row)
			if prop:
				var world_y := _get_tile_world_y(key, tt)
				prop.position = Vector3(col * CELL_SIZE, CELL_HEIGHT * 0.5 + world_y, row * CELL_SIZE)
				_props_node.add_child(prop)
				_props[key] = prop

func _prop_for(tt: int, col: int, row: int) -> Node3D:
	match tt:
		TileType.TEE:
			var orient  := _tile_orientations.get(Vector2i(col, row), 0) as int
			var hole_n  := _tile_hole_num.get(Vector2i(col, row), 1) as int
			return Props.make_tee_pad(orient, _hole_flag_color(hole_n))
		TileType.BASKET:    return Props.make_basket(_flag_nodes)
		# Ray's disc bag hangs on the home course gate (STORY.md — never moves).
		TileType.ENTRANCE:  return Props.make_gate(GameManager.active_course_id == "home")
		TileType.TREE:      return _pick_tree(col, row)
		TileType.PARKING:
			var pk := _apply_facility_style(Props.make_parking(), Vector2i(col, row))
			Props.add_parked_cars(pk, col, row)
			return pk
		TileType.RESTROOM:   return _apply_facility_style(Props.make_restroom(),   Vector2i(col, row))
		TileType.FOOD_STAND: return _apply_facility_style(Props.make_food_stand(), Vector2i(col, row))
		TileType.PRO_SHOP:
			var cell := Vector2i(col, row)
			var anchor: Vector2i = _building_anchor.get(cell, cell) as Vector2i
			if anchor != cell:
				return null  # sub-cell — no prop, anchor renders the whole building
			return _apply_facility_style(Props.make_pro_shop(), cell)
		TileType.ROCK:      return Props.make_rock(col, row)
		TileType.OB:        return Props.make_ob_marker(col, row)
		TileType.BENCH:     return Props.make_bench(col, row)
		TileType.FLOWER_BED:return Props.make_flower_bed(col, row)
		TileType.SCULPTURE: return Props.make_sculpture(col, row)
		TileType.LAMP_POST: return Props.make_lamp_post(col, row)
		TileType.SIGN:      return Props.make_sign(col, row)
		TileType.GARDEN:    return Props.make_garden(col, row)
	return null

## Which model, size and tint a tree cell gets (stable per cell).
func _tree_choice(col: int, row: int) -> Dictionary:
	_load_tree_scenes()
	var variant := _tile_variants.get(Vector2i(col, row), -1) as int
	# variant: -1=random by hash, 0=pine, 1=deciduous
	var is_pine: bool
	match variant:
		0:   is_pine = true
		1:   is_pine = false
		_:   is_pine = _cell_hash(col, row) % 2 == 0
	var h      := 1.10 + (_cell_hash(col + 5, row + 9) % 5) * 0.10  # 1.10–1.50 range
	var sz: int  = _tile_tree_size.get(Vector2i(col, row), 2) as int
	var sz_scale := 0.55 if sz == 0 else (1.45 if sz == 2 else 1.0)
	var scenes := _tree_pine_scenes if is_pine else _tree_decid_scenes
	var idx := -1
	if not scenes.is_empty():
		idx = _cell_hash(col, row) % scenes.size()
	return {
		"pine": is_pine, "h": h * sz_scale, "scene_idx": idx,
		"model": idx if is_pine or idx < 0 else _tree_pine_scenes.size() + idx,
		"hue": float(_cell_hash(col + 3, row + 7) % 5) / 5.0,
		"scale": TREE_FBX_SCALE * h * sz_scale,
	}

static func _tree_trunk_color(hue: float) -> Color:
	return Color(0.30 + hue * 0.10, 0.16 + hue * 0.03, 0.05)

static func _tree_leaf_color(hue: float) -> Color:
	# Richer, more saturated foliage — slight hue variation
	return Color(0.10 + hue * 0.14, 0.48 + hue * 0.16, 0.06 + hue * 0.05)

## A tree as a node (build-mode hover preview, or fallback when no FBX models).
func _pick_tree(col: int, row: int) -> Node3D:
	var ch := _tree_choice(col, row)
	var is_pine: bool = ch["pine"]
	if int(ch["scene_idx"]) < 0:
		var ph: float = ch["h"]
		return Props.make_pine(ph, col, row) if is_pine else Props.make_deciduous(ph, col, row)
	var scenes := _tree_pine_scenes if is_pine else _tree_decid_scenes
	var tree := (scenes[int(ch["scene_idx"])] as PackedScene).instantiate() as Node3D
	_colorize_tree(tree, ch["hue"])
	var sv: float = ch["scale"]
	tree.scale = Vector3(sv, sv, sv)
	return tree

## Registers the batch parts: one per tree-model surface + grass blade + grain.
func _setup_prop_batch() -> void:
	_batch = PropBatch.new()
	_batch.name = "PropBatch"
	_props_node.add_child(_batch)
	_blade_part = _batch.add_part(Props.blade_mesh(), Props.instance_mat())
	_grain_part = _batch.add_part(Props.grain_mesh(), Props.instance_mat())
	_load_tree_scenes()
	var tree_mat := Props.instance_mat(0.82)
	_tree_parts.clear()
	_tree_detail_src.clear()
	_tree_reduced.clear()
	for scene in _tree_pine_scenes + _tree_decid_scenes:
		var parts: Array = []
		var root := (scene as PackedScene).instantiate() as Node3D
		_collect_tree_parts(root, Transform3D.IDENTITY, true, parts, tree_mat)
		root.free()
		_tree_parts.append(parts)
	if not _tree_detail_full:
		_tree_detail_full = true
		_set_tree_detail(false)

## Splits every MeshInstance3D surface under `node` into its own part, so trunk
## and leaves can be tinted separately per instance. local = transform relative
## to the scene root (the root's own transform is replaced per tree).
func _collect_tree_parts(node: Node, local: Transform3D, is_root: bool,
		parts: Array, tree_mat: Material) -> void:
	var xf := local
	if node is Node3D and not is_root:
		xf = local * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		for si in mesh.get_surface_count():
			if mesh.surface_get_array_len(si) == 0:
				continue
			var src: Material = mi.get_surface_override_material(si)
			if src == null:
				src = mi.material_override if mi.material_override else mesh.surface_get_material(si)
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(mesh.surface_get_primitive_type(si), mesh.surface_get_arrays(si))
			var textured := src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null
			var pid: int
			if textured:
				am.surface_set_material(0, src)
				pid = _batch.add_part(am, null, true)
				parts.append([pid, xf, TREE_PART_ORIG])
			else:
				var kind := TREE_PART_TRUNK if _is_trunk_material(src, mi.name) else TREE_PART_LEAVES
				pid = _batch.add_part(am, tree_mat, true)
				parts.append([pid, xf, kind])
			if mesh.surface_get_primitive_type(si) == Mesh.PRIMITIVE_TRIANGLES:
				_tree_detail_src[pid] = [am, src if textured else null]
	for c in node.get_children():
		_collect_tree_parts(c, xf, false, parts, tree_mat)

## Low preset: every tree part draws a simplified mesh (built once, on first
## use, ~0.1 s for all models); Medium/High draw the full model. Surfaces the
## simplifier can't reduce (separate leaf cards) stay full.
func _set_tree_detail(full: bool) -> void:
	if full == _tree_detail_full:
		return
	_tree_detail_full = full
	if _batch == null:
		return
	for pid in _tree_detail_src:
		var src: Array = _tree_detail_src[pid]
		var mesh: Mesh = src[0]
		if not full:
			if not _tree_reduced.has(pid):
				_tree_reduced[pid] = Props.reduced_tree_mesh((src[0] as ArrayMesh).surface_get_arrays(0), src[1])
			if _tree_reduced[pid] != null:
				mesh = _tree_reduced[pid]
		_batch.set_part_mesh(pid, mesh)

static func _is_trunk_material(m: Material, node_name: String) -> bool:
	var nm := ((m.resource_name if m else "") + " " + node_name).to_lower()
	for w in ["trunk", "bark", "wood", "stem"]:
		if w in nm:
			return true
	return false

## Instance list for a tree cell ([] when no FBX models → node fallback).
func _tree_instances(col: int, row: int, base: Vector3) -> Array:
	var ch := _tree_choice(col, row)
	var model: int = ch["model"]
	if model < 0 or model >= _tree_parts.size():
		return []
	var sv: float = ch["scale"]
	var hue: float = ch["hue"]
	var tree_xf := Transform3D(Basis.from_scale(Vector3(sv, sv, sv)), base)
	var out: Array = []
	for part in _tree_parts[model]:
		var c := Color.WHITE
		match int(part[2]):
			TREE_PART_TRUNK:  c = _tree_trunk_color(hue)
			TREE_PART_LEAVES: c = _tree_leaf_color(hue)
		out.append([part[0], tree_xf * (part[1] as Transform3D), c])
	return out

## Draws the cell's prop through the batch when it's a tree / rough / sand.
## Returns true when handled (including "this rough cell has no clump").
func _batch_cell(key: Vector2i, tt: int, world_y: float) -> bool:
	if _batch == null:
		return false
	var base := Vector3(key.x * CELL_SIZE, CELL_HEIGHT * 0.5 + world_y, key.y * CELL_SIZE)
	match tt:
		TileType.TREE:
			var inst := _tree_instances(key.x, key.y, base)
			if inst.is_empty():
				return false
			_batch.set_cell(key, inst)
			return true
		TileType.ROUGH:
			if _cell_hash(key.x, key.y) % 2 == 0:
				_batch.set_cell(key, Props.rough_grass_instances(key.x, key.y, base, _blade_part))
			return true
		TileType.SAND:
			_batch.set_cell(key, Props.sand_instances(key.x, key.y, base, _grain_part))
			return true
	return false

## Instancing stats for tests/profiling: {parts, buckets (MultiMeshes), instances}.
func get_prop_batch_stats() -> Dictionary:
	if _batch == null:
		return {"parts": 0, "buckets": 0, "instances": 0}
	return {"parts": _batch.part_count(), "buckets": _batch.bucket_count(),
		"instances": _batch.instance_count()}

func get_prop_batch() -> Node3D:
	return _batch

# ── Route lines (tee → basket per hole) ───────────────────────────────────────

func draw_route_lines() -> void:
	clear_route_lines()
	if not _route_lines_root:
		return
	var holes := get_holes_info()
	for h in holes:
		var tc: Vector2i  = h["tee_cell"] as Vector2i
		var bc: Vector2i  = h["basket_cell"] as Vector2i
		var hole_num: int = h["hole_num"] as int
		var color: Color  = _hole_custom_colors.get(hole_num,
			HOLE_FLAG_COLORS[(hole_num - 1) % HOLE_FLAG_COLORS.size()] as Color) as Color

		var waypoints: Array = _hole_waypoints.get(hole_num, []) as Array
		var points: Array    = [_cell_world_pos(tc)]
		for wp in waypoints:
			points.append(_cell_world_pos(wp as Vector2i))
		points.append(_cell_world_pos(bc))

		for i in range(points.size() - 1):
			_draw_route_segment(points[i] as Vector3, points[i + 1] as Vector3, color)

		for wp in waypoints:
			_draw_waypoint_marker(_cell_world_pos(wp as Vector2i), color)

func _draw_route_segment(a: Vector3, b: Vector3, color: Color) -> void:
	var dist := a.distance_to(b)
	if dist < 0.5:
		return
	var dir := (b - a).normalized()
	var mid := (a + b) * 0.5
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color     = Color(color.r, color.g, color.b, 0.85)
	lmat.emission_enabled = true
	lmat.emission         = color * 0.5
	lmat.no_depth_test    = true
	lmat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lm := BoxMesh.new()
	lm.size = Vector3(0.15, 0.08, dist - 0.3)
	var lmi := MeshInstance3D.new()
	lmi.mesh              = lm
	lmi.material_override = lmat
	lmi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lmi.position   = Vector3(mid.x, mid.y + 0.25, mid.z)
	lmi.rotation.y = atan2(dir.x, dir.z)
	_route_lines_root.add_child(lmi)

func _draw_waypoint_marker(pos: Vector3, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.22; sm.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = color
	mat.emission_enabled = true
	mat.emission         = color * 0.55
	mat.no_depth_test    = true
	sm.surface_set_material(0, mat)
	var smi := MeshInstance3D.new()
	smi.mesh       = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.position   = Vector3(pos.x, pos.y + 0.35, pos.z)
	_route_lines_root.add_child(smi)

func clear_route_lines() -> void:
	if not _route_lines_root:
		return
	for child in _route_lines_root.get_children():
		child.queue_free()

# ── Hole color + facility API ─────────────────────────────────────────────────

func set_hole_color(hole_num: int, color: Color) -> void:
	_hole_custom_colors[hole_num] = color
	for key in _tiles:
		if _tiles[key] == TileType.TEE and _tile_hole_num.get(key, 1) == hole_num:
			_update_tile_visual(key, TileType.TEE, false)
	draw_route_lines()

func set_tile_facility_orientation(cell: Vector2i, o: int) -> void:
	if not _valid(cell):
		return
	var tt: int = _tiles.get(cell, TileType.GRASS) as int
	if not FACILITY_COSTS.has(tt):
		return
	_facility_orientations[cell] = o
	_update_tile_visual(cell, tt, false)

func set_tile_facility_color_idx(cell: Vector2i, idx: int) -> void:
	if not _valid(cell):
		return
	var tt: int = _tiles.get(cell, TileType.GRASS) as int
	if not FACILITY_COSTS.has(tt):
		return
	_facility_colors[cell] = idx
	_update_tile_visual(cell, tt, false)

func _try_place_pro_shop(anchor: Vector2i) -> void:
	for key in _tiles:
		if _tiles[key] == TileType.PRO_SHOP:
			EventBus.notification_requested.emit("Only one Pro Shop allowed!", "warning")
			return
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var c := Vector2i(anchor.x + dc, anchor.y + dr)
			if not _valid(c):
				EventBus.notification_requested.emit("Pro Shop needs 3×3 space inside the map!", "warning")
				return
			var existing: int = _tiles.get(c, TileType.GRASS) as int
			if existing != TileType.GRASS and existing != TileType.ROUGH and existing != TileType.FAIRWAY:
				EventBus.notification_requested.emit("Pro Shop needs a clear 3×3 area!", "warning")
				return
	if not EconomyManager.spend(FACILITY_COSTS[TileType.PRO_SHOP], "construction"):
		return
	_place_pro_shop_building(anchor)

func _place_pro_shop_building(anchor: Vector2i) -> void:
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var c := Vector2i(anchor.x + dc, anchor.y + dr)
			_tiles[c] = TileType.PRO_SHOP
			_building_anchor[c] = anchor
			_update_tile_visual(c, TileType.PRO_SHOP, false)
	_rebuild_water_layer()
	cell_changed.emit(anchor.x, anchor.y, TileType.PRO_SHOP)

func _erase_pro_shop_building(anchor: Vector2i) -> void:
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var c := Vector2i(anchor.x + dc, anchor.y + dr)
			_tiles[c]  = TileType.GRASS
			_building_anchor.erase(c)
			_update_tile_visual(c, TileType.GRASS, false)
	_rebuild_water_layer()

func set_route_edit_mode(hole_num: int, active: bool) -> void:
	_route_edit_hole = hole_num if active else -1
	if active:
		_select_mode  = false
		_builder_mode = false
		_painting     = false
	draw_route_lines()

func toggle_route_waypoint(cell: Vector2i) -> void:
	if _route_edit_hole < 0 or not _valid(cell):
		return
	var waypoints: Array = _hole_waypoints.get(_route_edit_hole, []) as Array
	for i in waypoints.size():
		if waypoints[i] == cell:
			waypoints.remove_at(i)
			_hole_waypoints[_route_edit_hole] = waypoints
			draw_route_lines()
			route_changed.emit(_route_edit_hole)
			return
	waypoints.append(cell)
	_hole_waypoints[_route_edit_hole] = waypoints
	draw_route_lines()
	route_changed.emit(_route_edit_hole)

func clear_route_waypoints(hole_num: int) -> void:
	_hole_waypoints.erase(hole_num)
	draw_route_lines()
	route_changed.emit(hole_num)

func _apply_facility_style(node: Node3D, cell: Vector2i) -> Node3D:
	var orient: int = _facility_orientations.get(cell, 0) as int
	node.rotation.y = orient * PI * 0.5
	var color_idx: int = _facility_colors.get(cell, 0) as int
	if color_idx > 0 and color_idx < FACILITY_COLOR_PRESETS.size():
		_tint_node_recursive(node, FACILITY_COLOR_PRESETS[color_idx] as Color)
	return node

func _tint_node_recursive(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var orig := mi.material_override as StandardMaterial3D
			var nm   := orig.duplicate() as StandardMaterial3D
			nm.albedo_color = Color(orig.albedo_color.r * tint.r,
				orig.albedo_color.g * tint.g, orig.albedo_color.b * tint.b)
			mi.material_override = nm
	for child in node.get_children():
		_tint_node_recursive(child, tint)

func _emit_tile_info(cell: Vector2i) -> void:
	if not _valid(cell):
		return
	var tt: int = _tiles.get(cell, TileType.GRASS) as int
	match tt:
		TileType.TEE, TileType.BASKET:
			var hn: int     = _tile_hole_num.get(cell, 1) as int
			var orient: int = _tile_orientations.get(cell, 0) as int
			tile_info_requested.emit(cell, tt, hn, orient)
		TileType.PARKING, TileType.RESTROOM, TileType.FOOD_STAND, TileType.PRO_SHOP:
			var orient: int    = _facility_orientations.get(cell, 0) as int
			var color_idx: int = _facility_colors.get(cell, 0) as int
			facility_info_requested.emit(cell, tt, orient, color_idx)

func _start_drag(from_cell: Vector2i) -> void:
	if not _valid(from_cell):
		return
	_drag_active = true
	_press_cell  = from_cell

func _finish_drag(to_cell: Vector2i) -> void:
	var src := _press_cell
	_drag_active = false
	_press_cell  = Vector2i(-1, -1)
	_mouse_held  = false

	if not _valid(src) or not _valid(to_cell) or to_cell == src:
		return
	var tt: int = _tiles.get(src, TileType.GRASS) as int
	if tt == TileType.GRASS:
		return
	# PRO_SHOP sub-cell drag is not supported — only move via erase+replace
	if tt == TileType.PRO_SHOP:
		var ps_anchor: Vector2i = _building_anchor.get(src, src) as Vector2i
		if ps_anchor != src:
			return  # sub-cell — skip drag

	# Save all metadata
	var hole_num: int    = _tile_hole_num.get(src, 1) as int
	var orient: int      = _tile_orientations.get(src, 0) as int
	var par: int         = _tile_par.get(src, 3) as int
	var variant: int     = _tile_variants.get(src, -1) as int
	var height: float    = _tile_heights.get(src, 0.0) as float
	var f_orient: int    = _facility_orientations.get(src, 0) as int
	var f_color: int     = _facility_colors.get(src, 0) as int
	var old_target: int  = _tiles.get(to_cell, TileType.GRASS) as int

	# Clear source
	_tiles[src] = TileType.GRASS
	_tile_hole_num.erase(src); _tile_orientations.erase(src)
	_tile_par.erase(src);      _tile_variants.erase(src)
	_tile_heights.erase(src);  _facility_orientations.erase(src)
	_facility_colors.erase(src)
	_update_tile_visual(src, TileType.GRASS, false)

	# Clear target
	_tiles[to_cell] = TileType.GRASS
	_tile_hole_num.erase(to_cell); _tile_orientations.erase(to_cell)
	_tile_par.erase(to_cell);      _tile_variants.erase(to_cell)
	_facility_orientations.erase(to_cell); _facility_colors.erase(to_cell)

	# Place at target
	_tiles[to_cell] = tt
	if tt == TileType.TEE or tt == TileType.BASKET:
		_tile_hole_num[to_cell] = hole_num
	if tt == TileType.TEE:
		_tile_orientations[to_cell] = orient
		_tile_par[to_cell] = par
	elif tt == TileType.TREE:
		_tile_variants[to_cell] = variant
	elif FACILITY_COSTS.has(tt):
		_facility_orientations[to_cell] = f_orient
		_facility_colors[to_cell] = f_color
	if height != 0.0:
		_tile_heights[to_cell] = height
	_update_tile_visual(to_cell, tt, false)

	var touches_route := (tt == TileType.TEE or tt == TileType.BASKET
			or old_target == TileType.TEE or old_target == TileType.BASKET)
	if touches_route:
		draw_route_lines()

func _count_decor_tiles() -> int:
	var by := _cells_by_type()
	return (by.get(TileType.BENCH, []) as Array).size() \
		+ (by.get(TileType.FLOWER_BED, []) as Array).size() \
		+ (by.get(TileType.SCULPTURE, []) as Array).size()

func get_facility_counts() -> Dictionary:
	var by := _cells_by_type()
	return {
		"parking":    (by.get(TileType.PARKING, []) as Array).size(),
		"restroom":   (by.get(TileType.RESTROOM, []) as Array).size(),
		"food_stand": (by.get(TileType.FOOD_STAND, []) as Array).size(),
		"pro_shop":   (by.get(TileType.PRO_SHOP, []) as Array).size(),
	}

## tile type → Array[Vector2i], one pass over the grid per layout.
func _cells_by_type() -> Dictionary:
	var L := _layout()
	if not L.has("by_type"):
		var by: Dictionary = {}
		for key in _tiles:
			var t: int = _tiles[key]
			if not by.has(t):
				by[t] = []
			(by[t] as Array).append(key)
		L["by_type"] = by
	return L["by_type"]

# ── Hover indicator ───────────────────────────────────────────────────────────

func _create_hover_indicator() -> void:
	var hm := BoxMesh.new()
	hm.size = Vector3(CELL_SIZE, CELL_HEIGHT + 0.20, CELL_SIZE)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color  = Color(1.0, 1.0, 1.0, 0.28)
	hmat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.no_depth_test = true
	_hover_mat = hmat
	_hover_indicator = MeshInstance3D.new()
	_hover_indicator.mesh              = hm
	_hover_indicator.material_override = hmat
	_hover_indicator.visible           = false
	_hover_indicator.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_indicator)

	# Orientation arrow: thin elongated box along -Z, shown only for TEE / BASKET
	var am := BoxMesh.new()
	am.size = Vector3(0.25, 0.18, CELL_SIZE * 1.2)
	var amat := StandardMaterial3D.new()
	amat.albedo_color      = Color(1.0, 0.92, 0.0, 0.85)
	amat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.no_depth_test     = true
	amat.emission_enabled  = true
	amat.emission          = Color(1.0, 0.8, 0.0) * 0.6
	_hover_arrow = MeshInstance3D.new()
	_hover_arrow.mesh              = am
	_hover_arrow.material_override = amat
	_hover_arrow.visible           = false
	_hover_arrow.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_arrow)

func _update_hover() -> void:
	var valid := _valid(_hover_cell)
	var show  := (_builder_mode or _drag_active) and valid
	_hover_indicator.visible = show
	if _hover_arrow:
		_hover_arrow.visible = false

	if not show:
		_clear_preview_prop()
		return

	var tt: int = _tiles.get(_hover_cell, TileType.GRASS) as int
	var base_y := _get_tile_world_y(_hover_cell, tt)
	var cell_pos := Vector3(_hover_cell.x * CELL_SIZE, base_y, _hover_cell.y * CELL_SIZE)
	_hover_indicator.position = cell_pos

	# Tile-colored tint so it's obvious what you're about to place
	var special_tool := (_active_tool == TOOL_RAISE or _active_tool == TOOL_LOWER
		or _active_tool == TileType.OB or _active_tool == TileType.ROCK)
	if special_tool:
		_hover_base_color = Color.WHITE
	else:
		var tc: Color = TILE_COLOR.get(_active_tool, Color.WHITE) as Color
		_hover_base_color = Color(tc.r * 1.4, tc.g * 1.4, tc.b * 1.4).clamp()

	# Orientation arrow for TEE and BASKET
	if (_active_tool == TileType.TEE or _active_tool == TileType.BASKET) and _hover_arrow:
		_hover_arrow.visible = true
		var arrow_y := base_y + CELL_HEIGHT + 0.15
		# Facing offsets: mesh points along -Z by default (orientation 2 = south = +Z requires 180° flip)
		var rot_y: float
		var fwd_offset: Vector3
		match _active_orientation:
			0: rot_y = 0.0;   fwd_offset = Vector3(0, 0, -CELL_SIZE * 0.7)   # N
			1: rot_y = -90.0; fwd_offset = Vector3(CELL_SIZE * 0.7, 0, 0)    # E
			2: rot_y = 180.0; fwd_offset = Vector3(0, 0, CELL_SIZE * 0.7)    # S
			3: rot_y = 90.0;  fwd_offset = Vector3(-CELL_SIZE * 0.7, 0, 0)   # W
			_: rot_y = 0.0;   fwd_offset = Vector3.ZERO
		_hover_arrow.position = Vector3(cell_pos.x + fwd_offset.x, arrow_y, cell_pos.z + fwd_offset.z)
		_hover_arrow.rotation_degrees = Vector3(0.0, rot_y, 0.0)

	# Prop preview — recreate only when tool or cell changes
	const PREVIEW_TOOLS := [
		TileType.TEE, TileType.BASKET, TileType.TREE,
		TileType.PARKING, TileType.RESTROOM, TileType.FOOD_STAND, TileType.PRO_SHOP,
	]
	if not special_tool and _active_tool in PREVIEW_TOOLS:
		if _hover_cell != _preview_prop_cell or _active_tool != _preview_prop_tool:
			_clear_preview_prop()
			_preview_prop_cell = _hover_cell
			_preview_prop_tool = _active_tool
			var prop := _prop_for(_active_tool, _hover_cell.x, _hover_cell.y)
			if prop:
				_apply_preview_transparency(prop)
				prop.position = Vector3(_hover_cell.x * CELL_SIZE, CELL_HEIGHT * 0.5 + base_y, _hover_cell.y * CELL_SIZE)
				add_child(prop)
				_preview_prop = prop
	elif _preview_prop and is_instance_valid(_preview_prop):
		_clear_preview_prop()

	# Template ghost overlay — reposition when cursor or orientation changes
	if _ghost_tiles.size() > 0:
		var anchored := _ghost_anchor.x != -9999
		if anchored:
			pass  # positioned once by anchor_template_ghost
		elif valid:
			var cur_orient := _active_orientation
			if _hover_cell != _ghost_last_cell or cur_orient != _ghost_last_orient:
				_ghost_last_cell  = _hover_cell
				_ghost_last_orient = cur_orient
				_position_ghost_meshes(_hover_cell, cur_orient)
		else:
			for gm in _ghost_meshes:
				if is_instance_valid(gm): (gm as MeshInstance3D).visible = false

func _clear_preview_prop() -> void:
	if _preview_prop and is_instance_valid(_preview_prop):
		_preview_prop.queue_free()
	_preview_prop      = null
	_preview_prop_cell = Vector2i(-9, -9)
	_preview_prop_tool = -99

func _apply_preview_transparency(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var orig := mi.material_override as StandardMaterial3D
			var pm   := orig.duplicate() as StandardMaterial3D
			pm.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.albedo_color  = Color(orig.albedo_color.r, orig.albedo_color.g, orig.albedo_color.b, 0.65)
			mi.material_override = pm
		elif mi.mesh != null:
			# FBX/GLB nodes without material_override — apply a transparent override
			var pm := StandardMaterial3D.new()
			pm.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.albedo_color    = Color(0.7, 0.85, 0.7, 0.60)
			pm.shading_mode    = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mi.material_override = pm
	for child in node.get_children():
		if child is Node3D:
			_apply_preview_transparency(child as Node3D)

# ── Painting + terraform ──────────────────────────────────────────────────────

func _paint_at(cell: Vector2i) -> void:
	if not _valid(cell):
		return
	_clear_preview_prop()   # hide preview while painting
	if _active_tool == TOOL_RAISE or _active_tool == TOOL_LOWER:
		_push_undo(cell)
		if not EconomyManager.spend(TERRAFORM_COST, "construction"):
			_undo_stack.pop_back()
			return
		var step := TERRAFORM_STEP if _active_tool == TOOL_RAISE else -TERRAFORM_STEP
		var cur := _tile_heights.get(cell, 0.0) as float
		_tile_heights[cell] = clampf(cur + step, TERRAFORM_MIN, TERRAFORM_MAX)
		var tt: int = _tiles.get(cell, TileType.GRASS) as int
		_update_tile_visual(cell, tt, false)  # no water rebuild for terraform
		_smooth_dirty = true
	elif _active_tool == TileType.OB:
		_push_undo(cell)
		# OB is a per-hole overlay — toggle for this hole
		if _ob_zones.get(cell, -1) as int == _active_hole_num:
			_ob_zones.erase(cell)
		else:
			_ob_zones[cell] = _active_hole_num
		_update_ob_prop(cell)
	elif _active_tool == TileType.ROCK:
		_push_undo(cell)
		if _rock_overlays.has(cell):
			_rock_overlays.erase(cell)
		else:
			if not EconomyManager.spend(TILE_COSTS.get(TileType.ROCK, 0.0) as float, "construction"):
				_undo_stack.pop_back()
				return
			_rock_overlays[cell] = true
		_update_rock_prop(cell)
	else:
		_push_undo(cell)
		var old_tt: int = _tiles.get(cell, TileType.GRASS) as int
		# Pro Shop is a 3×3 building — special placement path
		if _active_tool == TileType.PRO_SHOP:
			if old_tt != TileType.PRO_SHOP:
				_try_place_pro_shop(cell)
			return
		# Erase pro shop sub-cells if overwriting
		if old_tt == TileType.PRO_SHOP:
			var ps_anchor: Vector2i = _building_anchor.get(cell, cell) as Vector2i
			_erase_pro_shop_building(ps_anchor)
			old_tt = TileType.GRASS
		# Charge tile cost (terrain/objects)
		if TILE_COSTS.has(_active_tool) and old_tt != _active_tool:
			var cost: float = TILE_COSTS[_active_tool] as float
			if cost > 0.0 and not EconomyManager.spend(cost, "construction"):
				return
		# Charge facility cost (buildings)
		elif FACILITY_COSTS.has(_active_tool) and old_tt != _active_tool:
			if not EconomyManager.spend(FACILITY_COSTS[_active_tool], "construction"):
				return
		# Painting any non-OB/non-ROCK tile clears those overlays
		if _ob_zones.has(cell):
			_ob_zones.erase(cell)
			_update_ob_prop(cell)
		if _rock_overlays.has(cell):
			_rock_overlays.erase(cell)
			_update_rock_prop(cell)
		if old_tt == TileType.TREE and _active_tool != TileType.TREE:
			_tile_variants.erase(cell)
			_tile_tree_size.erase(cell)
		if old_tt == TileType.TEE and _active_tool != TileType.TEE:
			_tile_orientations.erase(cell)
			_tile_par.erase(cell)
		_tiles[cell] = _active_tool
		if _active_tool == TileType.TREE:
			_tile_variants[cell]   = _active_variant
			_tile_tree_size[cell]  = _active_tree_size
		elif _active_tool == TileType.TEE:
			_tile_hole_num[cell]     = _active_hole_num
			_tile_orientations[cell] = _active_orientation
			if not _tile_par.has(cell):
				_tile_par[cell] = 3
		elif _active_tool == TileType.BASKET:
			_tile_hole_num[cell] = _active_hole_num
		_update_tile_visual(cell, _active_tool, true)
		cell_changed.emit(cell.x, cell.y, _active_tool)
		if _active_tool == TileType.TEE or _active_tool == TileType.BASKET:
			_auto_par(_active_hole_num)
		if old_tt != _active_tool:
			EventBus.tile_placed.emit(_active_tool)
		if _active_tool == TileType.TEE:
			EventBus.tee_painted.emit(cell, _active_hole_num)
		if _active_tool == TileType.TEE or _active_tool == TileType.BASKET \
				or old_tt == TileType.TEE or old_tt == TileType.BASKET:
			draw_route_lines()

func _update_tile_visual(key: Vector2i, tt: int, rebuild_water: bool = true) -> void:
	var world_y := _get_tile_world_y(key, tt)
	var idx := key.x * GRID_ROWS + key.y
	var xf  := Transform3D.IDENTITY
	xf.origin = Vector3(key.x * CELL_SIZE, _terrain_box_center_y(world_y), key.y * CELL_SIZE)
	_terrain_mm.set_instance_transform(idx, xf)
	_terrain_mm.set_instance_color(idx, TILE_COLOR.get(tt, TILE_COLOR[TileType.GRASS]))

	if _props.has(key):
		_props[key].queue_free()
		_props.erase(key)
	if _batch:
		_batch.remove_cell(key)
	if not _batch_cell(key, tt, world_y):
		var prop := _prop_for(tt, key.x, key.y)
		if prop:
			prop.position = Vector3(key.x * CELL_SIZE, CELL_HEIGHT * 0.5 + world_y, key.y * CELL_SIZE)
			_props_node.add_child(prop)
			_props[key] = prop

	if rebuild_water:
		_rebuild_water_layer()
		_smooth_dirty = true

# ── Coordinate math ───────────────────────────────────────────────────────────

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var cam: Camera3D = get_node("CourseCamera3D")
	var from := cam.project_ray_origin(screen_pos)
	var dir  := cam.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return Vector2i(-1, -1)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit := from + dir * t
	return Vector2i(roundi(hit.x / CELL_SIZE), roundi(hit.z / CELL_SIZE))

func _valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS

func _cell_hash(col: int, row: int) -> int:
	return Props.cell_hash(col, row)

func _mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	return Props.mi(parent, mesh, mat)

func _mat(color: Color) -> StandardMaterial3D:
	return Props.mat(color)

func _hole_flag_color(hole_num: int) -> Color:
	return _hole_custom_colors.get(hole_num,
		HOLE_FLAG_COLORS[(hole_num - 1) % HOLE_FLAG_COLORS.size()] as Color) as Color

# FBX trees from Kenney reference a missing texture.png — override with solid colors
# per surface (bark brown, leaves green). Textured surfaces keep their material.
# Used for node trees only (hover preview / fallback); batched trees get the same
# colours through PropBatch instance colours.
func _colorize_tree(node: Node3D, hue_shift: float = 0.0) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(si)
			if m == null:
				m = mi.mesh.surface_get_material(si)
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				continue
			var nm := StandardMaterial3D.new()
			nm.albedo_color = _tree_trunk_color(hue_shift) if _is_trunk_material(m, mi.name) \
				else _tree_leaf_color(hue_shift)
			nm.roughness = 0.82
			mi.set_surface_override_material(si, nm)
	for child in node.get_children():
		if child is Node3D:
			_colorize_tree(child as Node3D, hue_shift)

func _load_tree_scenes() -> void:
	if _trees_loaded:
		return
	_trees_loaded = true
	var pine_paths: Array = [
		"res://assets/models/kenny_nature-kit-FBX/tree_pineDefaultA.fbx",
		"res://assets/models/kenny_nature-kit-FBX/tree_pineDefaultB.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/PineTree_1.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/PineTree_2.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/PineTree_3.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/PineTree_4.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/PineTree_5.fbx",
		"res://assets/models/FBX ultimate nature pack/PineTree_1.fbx",
		"res://assets/models/FBX ultimate nature pack/PineTree_2.fbx",
		"res://assets/models/FBX ultimate nature pack/PineTree_3.fbx",
		"res://assets/models/FBX ultimate nature pack/PineTree_4.fbx",
		"res://assets/models/FBX ultimate nature pack/PineTree_5.fbx",
	]
	var decid_paths: Array = [
		"res://assets/models/kenny_nature-kit-FBX/tree_default.fbx",
		"res://assets/models/kenny_nature-kit-FBX/tree_oak.fbx",
		"res://assets/models/kenny_nature-kit-FBX/tree_fat.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/NormalTree_1.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/NormalTree_2.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/NormalTree_3.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/BirchTree_1.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/BirchTree_2.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/MapleTree_1.fbx",
		"res://assets/models/Ultimate Styalized Nature Pack/MapleTree_2.fbx",
		"res://assets/models/FBX ultimate nature pack/CommonTree_1.fbx",
		"res://assets/models/FBX ultimate nature pack/CommonTree_2.fbx",
		"res://assets/models/FBX ultimate nature pack/CommonTree_3.fbx",
		"res://assets/models/FBX ultimate nature pack/BirchTree_1.fbx",
		"res://assets/models/FBX ultimate nature pack/BirchTree_2.fbx",
		"res://assets/models/FBX ultimate nature pack/BirchTree_3.fbx",
		"res://assets/models/FBX ultimate nature pack/Willow_1.fbx",
		"res://assets/models/FBX ultimate nature pack/Willow_2.fbx",
	]
	for p in pine_paths:
		if ResourceLoader.exists(p):
			var s := load(p) as PackedScene
			if s:
				_tree_pine_scenes.append(s)
	for p in decid_paths:
		if ResourceLoader.exists(p):
			var s := load(p) as PackedScene
			if s:
				_tree_decid_scenes.append(s)



# ── NPC management ────────────────────────────────────────────────────────────

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PAUSED:
		return
	var show := (new_state == GameManager.GameState.GAMEPLAY or
				 new_state == GameManager.GameState.COURSE_BUILDER)
	self.visible = show
	# No NPC traffic on a circuit course you're only visiting for an away round.
	var want := new_state == GameManager.GameState.GAMEPLAY and not GameManager.is_away_round()
	if want == _gameplay_mode:
		return  # resume from pause — already running, don't reinit
	set_gameplay_mode(want)

## ── OB / Rock overlay API ─────────────────────────────────────────────────────

func is_ob_at(world_pos: Vector3, hole_idx_0based: int) -> bool:
	var cell := Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))
	if not _ob_zones.has(cell):
		return false
	var zone_hole: int = _ob_zones[cell] as int
	return zone_hole == 0 or zone_hole == (hole_idx_0based + 1)

func is_rock_at(world_pos: Vector3) -> bool:
	var cell := Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))
	return _rock_overlays.has(cell)

func _update_ob_prop(cell: Vector2i) -> void:
	if _ob_props.has(cell):
		(_ob_props[cell] as Node3D).queue_free()
		_ob_props.erase(cell)
	if _ob_zones.has(cell):
		var prop := Props.make_ob_marker(cell.x, cell.y)
		var tt: int = _tiles.get(cell, TileType.GRASS) as int
		prop.position = Vector3(cell.x * CELL_SIZE, CELL_HEIGHT * 0.5 + _get_tile_world_y(cell, tt), cell.y * CELL_SIZE)
		_props_node.add_child(prop)
		_ob_props[cell] = prop

func _update_rock_prop(cell: Vector2i) -> void:
	if _rock_props_overlay.has(cell):
		(_rock_props_overlay[cell] as Node3D).queue_free()
		_rock_props_overlay.erase(cell)
	if _rock_overlays.has(cell):
		var prop := Props.make_rock(cell.x, cell.y)
		var tt: int = _tiles.get(cell, TileType.GRASS) as int
		prop.position = Vector3(cell.x * CELL_SIZE, CELL_HEIGHT * 0.5 + _get_tile_world_y(cell, tt), cell.y * CELL_SIZE)
		_props_node.add_child(prop)
		_rock_props_overlay[cell] = prop

## ── Undo ──────────────────────────────────────────────────────────────────────

func _push_undo(cell: Vector2i) -> void:
	var entry := {
		"cell":        cell,
		"tile":        _tiles.get(cell, TileType.GRASS),
		"height":      _tile_heights.get(cell, 0.0),
		"variant":     _tile_variants.get(cell, -1),
		"tree_size":   _tile_tree_size.get(cell, -1),
		"hole_num":    _tile_hole_num.get(cell, -1),
		"orientation": _tile_orientations.get(cell, -1),
		"par":         _tile_par.get(cell, -1),
		"ob_zone":     _ob_zones.get(cell, -1),
		"rock":        _rock_overlays.has(cell),
	}
	_undo_stack.push_back(entry)
	if _undo_stack.size() > UNDO_MAX:
		_undo_stack.pop_front()

func get_hover_cell() -> Vector2i:
	return _hover_cell

func get_tile_orientation(cell: Vector2i) -> int:
	return _tile_orientations.get(cell, 2) as int

## Show cursor-following ghost for a template (pending tee placement).
func set_template_ghost(tiles: Array) -> void:
	_ghost_tiles        = tiles
	_ghost_anchor       = Vector2i(-9999, -9999)
	_ghost_last_cell    = Vector2i(-9999, -9999)
	_ghost_last_orient  = -1
	_init_ghost_meshes()

## Show static ghost anchored at a fixed tee cell (preview before confirm).
func anchor_template_ghost(tiles: Array, tee_cell: Vector2i, orientation: int) -> void:
	_ghost_tiles         = tiles
	_ghost_anchor        = tee_cell
	_ghost_anchor_orient = orientation
	_ghost_last_cell     = Vector2i(-9999, -9999)
	_init_ghost_meshes()
	_position_ghost_meshes(tee_cell, orientation)

func clear_template_ghost() -> void:
	_ghost_tiles = []
	for gm in _ghost_meshes:
		if is_instance_valid(gm): (gm as Node3D).queue_free()
	_ghost_meshes.clear()
	_ghost_anchor    = Vector2i(-9999, -9999)
	_ghost_last_cell = Vector2i(-9999, -9999)

func _init_ghost_meshes() -> void:
	for gm in _ghost_meshes:
		if is_instance_valid(gm): (gm as Node3D).queue_free()
	_ghost_meshes.clear()
	for entry in _ghost_tiles:
		var e       := entry as Dictionary
		var tt: int  = e.get("type", 0) as int
		var tc: Color = TILE_COLOR.get(tt, Color.WHITE) as Color
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tc.r, tc.g, tc.b, 0.52)
		mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
		var pm := PlaneMesh.new()
		pm.size = Vector2(CELL_SIZE * 0.88, CELL_SIZE * 0.88)
		var mi := MeshInstance3D.new()
		mi.mesh              = pm
		mi.material_override = mat
		mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible           = false
		add_child(mi)
		_ghost_meshes.append(mi)

func _position_ghost_meshes(origin: Vector2i, orientation: int) -> void:
	for i in _ghost_tiles.size():
		if i >= _ghost_meshes.size(): break
		var e       := _ghost_tiles[i] as Dictionary
		var raw_off := e["offset"] as Vector2i
		var cell    := origin + _rotate_template_offset(raw_off, orientation)
		var mi      := _ghost_meshes[i] as MeshInstance3D
		if _valid(cell):
			var tt: int  = _tiles.get(cell, TileType.GRASS) as int
			var gy: float = _get_tile_world_y(cell, tt) + CELL_HEIGHT * 0.5 + 0.06
			mi.position = Vector3(cell.x * CELL_SIZE, gy, cell.y * CELL_SIZE)
			mi.visible  = true
		else:
			mi.visible = false

func erase_cell(cell: Vector2i) -> void:
	if not _valid(cell):
		return
	_push_undo(cell)
	_tiles[cell] = TileType.GRASS
	_ob_zones.erase(cell)
	_rock_overlays.erase(cell)
	_update_ob_prop(cell)
	_update_rock_prop(cell)
	_update_tile_visual(cell, TileType.GRASS, true)

func undo_paint() -> void:
	if _undo_stack.is_empty():
		EventBus.notification_requested.emit("Nothing to undo", "info")
		return
	var entry: Dictionary = _undo_stack.pop_back()
	var cell: Vector2i = Vector2i(entry["cell"])
	# 50% refund for whatever is currently painted here
	var current_tt: int = _tiles.get(cell, TileType.GRASS) as int
	var refund := 0.0
	if TILE_COSTS.has(current_tt):
		refund = (TILE_COSTS[current_tt] as float) * 0.5
	elif FACILITY_COSTS.has(current_tt):
		refund = (FACILITY_COSTS[current_tt] as float) * 0.5
	# Rock overlay placed on top gets a partial refund too
	if _rock_overlays.has(cell) and not (entry["rock"] as bool):
		refund += (TILE_COSTS.get(TileType.ROCK, 0.0) as float) * 0.5
	if refund > 0.0:
		EconomyManager.earn(refund, "refund")
		EventBus.notification_requested.emit("Undo — refunded $%.0f" % refund, "info")
	var old_tt: int = entry["tile"] as int
	_tiles[cell] = old_tt
	var h: float = entry["height"] as float
	if h != 0.0: _tile_heights[cell] = h
	else: _tile_heights.erase(cell)
	var variant: int = entry["variant"] as int
	if variant >= 0: _tile_variants[cell] = variant
	else: _tile_variants.erase(cell)
	var tsz: int = entry["tree_size"] as int
	if tsz >= 0: _tile_tree_size[cell] = tsz
	else: _tile_tree_size.erase(cell)
	var hn: int = entry["hole_num"] as int
	if hn >= 0: _tile_hole_num[cell] = hn
	else: _tile_hole_num.erase(cell)
	var orient: int = entry["orientation"] as int
	if orient >= 0: _tile_orientations[cell] = orient
	else: _tile_orientations.erase(cell)
	var par: int = entry["par"] as int
	if par >= 0: _tile_par[cell] = par
	else: _tile_par.erase(cell)
	var ob: int = entry["ob_zone"] as int
	if ob >= 0: _ob_zones[cell] = ob
	else: _ob_zones.erase(cell)
	_update_ob_prop(cell)
	if entry["rock"] as bool: _rock_overlays[cell] = true
	else: _rock_overlays.erase(cell)
	_update_rock_prop(cell)
	_update_tile_visual(cell, old_tt, true)

func _respawn_existing_staff() -> void:
	for type in 3:
		var count: int = EconomyManager.get_staff_count(type)
		for _i in count:
			_on_staff_hired(type)

## World positions of every tile of a type (cached per layout; returns a copy).
func get_tiles_of_type(tile_type: int) -> Array:
	var L := _layout()
	if not L.has("pos_by_type"):
		L["pos_by_type"] = {}
	var memo: Dictionary = L["pos_by_type"]
	if not memo.has(tile_type):
		var result: Array = []
		for key in _cells_by_type().get(tile_type, []):
			result.append(_cell_world_pos(key as Vector2i))
		memo[tile_type] = result
	return (memo[tile_type] as Array).duplicate()

func _on_staff_hired(type: int) -> void:
	_next_staff_id += 1
	var sid := "staff_%d" % _next_staff_id
	var member: Node3D = _StaffScript.new()
	_staff_root.add_child(member)
	# Find a walkable starting position on the ground
	var sx := randf_range(8.0, 25.0)
	var sz_pos := randf_range(8.0, 25.0)
	var sy := get_ground_y(Vector3(sx, 0.0, sz_pos))
	member.position = Vector3(sx, sy, sz_pos)
	member.init(type, self, sid)
	(_staff_nodes[type] as Array).append(member)

func _on_staff_fired(type: int) -> void:
	var arr := _staff_nodes[type] as Array
	if arr.is_empty():
		return
	var member: Node3D = arr.pop_back()
	if is_instance_valid(member):
		member.queue_free()

func request_tee(tee_pos: Vector3, npc: Node) -> bool:
	var key := Vector3i(roundi(tee_pos.x), roundi(tee_pos.y), roundi(tee_pos.z))
	var holder = _tee_occupants.get(key, null)
	if holder != null and is_instance_valid(holder):
		return false
	_tee_occupants[key] = npc
	return true

func release_tee(tee_pos: Vector3, npc: Node) -> void:
	var key := Vector3i(roundi(tee_pos.x), roundi(tee_pos.y), roundi(tee_pos.z))
	if _tee_occupants.get(key, null) == npc:
		_tee_occupants.erase(key)

## Spawn interval follows live happiness, marketing, events and green fee.
## (Previously computed once on entering gameplay, so changes had no effect until re-entry.)
func _refresh_spawn_interval() -> void:
	var happiness := get_course_happiness()
	var spawn_mult := EconomyManager.get_spawn_rate_mult()
	_spawn_timer.wait_time = lerpf(40.0, 10.0, happiness) / maxf(spawn_mult, 0.1)

func _try_spawn_npc() -> void:
	if _gameplay_mode and not _holes.is_empty():
		_refresh_spawn_interval()  # takes effect from the next timer cycle
	var cap := MAX_NPCS + EconomyManager.get_npc_capacity_bonus()
	if not _gameplay_mode or _holes.is_empty() or _npc_count >= cap:
		return

	# VIP chance: 12% base when happiness ≥ 60%, +5% per Disc Pro on staff
	var happiness  := EconomyManager.current_happiness
	var disc_pros  := EconomyManager.get_staff_count(1)
	var vip_chance := 0.0
	if happiness >= 0.60:
		vip_chance = 0.12 + float(disc_pros) * 0.05

	# Party size 1–4 (weighted: 40% solo, 35% pair, 15% three, 10% four)
	var roll := randf()
	var party_size := 1
	if roll < 0.10:   party_size = 4
	elif roll < 0.25: party_size = 3
	elif roll < 0.60: party_size = 2
	party_size = mini(party_size, cap - _npc_count)

	var party_is_vip := randf() < vip_chance

	for i in party_size:
		_next_npc_id += 1
		var npc_id := "npc_%d" % _next_npc_id
		var npc: Node3D = _NPCScript.new()
		npc.init(_holes, _exit_path, npc_id, party_is_vip and i == 0)
		_npc_root.add_child(npc)
		# Stagger position slightly so party members don't stack exactly
		npc.position += Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
		_npc_count += 1
		npc.tree_exited.connect(func() -> void: _npc_count = maxi(0, _npc_count - 1))
		EventBus.npc_arrived.emit(npc_id)

	if party_is_vip:
		EventBus.vip_arrived.emit("npc_%d" % _next_npc_id)
	if party_size > 1:
		EventBus.notification_requested.emit("Party of %d arrived!" % party_size, "info")



func _build_all_holes() -> void:
	_holes     = []
	_exit_path = []
	var entrances: Array = []
	var tees:      Array = []
	var baskets:   Array = []
	for key in _tiles:
		match int(_tiles[key]):
			TileType.ENTRANCE: entrances.append(key)
			TileType.TEE:      tees.append(key)
			TileType.BASKET:   baskets.append(key)

	if entrances.is_empty() or tees.is_empty() or baskets.is_empty():


		return

	# Pair tees and baskets by matching hole_num (lowest row wins ties)
	var tee_by_num: Dictionary = {}
	for t in tees:
		var tc := t as Vector2i
		var hn: int = _tile_hole_num.get(tc, 99) as int
		if not tee_by_num.has(hn) or tc.y < (tee_by_num[hn] as Vector2i).y:
			tee_by_num[hn] = tc

	var basket_by_num: Dictionary = {}
	for b in baskets:
		var bc := b as Vector2i
		var hn: int = _tile_hole_num.get(bc, 99) as int
		if not basket_by_num.has(hn) or bc.y < (basket_by_num[hn] as Vector2i).y:
			basket_by_num[hn] = bc

	var hole_nums: Array = []
	for hn in tee_by_num:
		if basket_by_num.has(hn):
			hole_nums.append(hn)
	hole_nums.sort()

	var prev_cell: Vector2i = entrances[0] as Vector2i

	for hn in hole_nums:
		var tee_cell:    Vector2i = tee_by_num[hn] as Vector2i
		var basket_cell: Vector2i = basket_by_num[hn] as Vector2i
		var entry_cells: Array
		if _los_clear(prev_cell, tee_cell):
			entry_cells = [prev_cell, tee_cell]
		else:
			var bfs := _bfs_cells(prev_cell, [tee_cell])
			entry_cells = _string_pull(bfs) if not bfs.is_empty() else [prev_cell, tee_cell]
		_holes.append({
			"entry_path": _cells_to_world(entry_cells),
			"tee_pos":    _cell_world_pos(tee_cell),
			"basket_pos": _cell_world_pos(basket_cell),
			"par":        _tile_par.get(tee_cell, 3) as int,
		})
		prev_cell = basket_cell

	if not _holes.is_empty():
		var exit_entry := entrances[0] as Vector2i
		if _los_clear(prev_cell, exit_entry):
			_exit_path = _cells_to_world([prev_cell, exit_entry])
		else:
			var bfs := _bfs_cells(prev_cell, entrances)
			_exit_path = _cells_to_world(_string_pull(bfs)) if not bfs.is_empty() else [_cell_world_pos(exit_entry)]




## Tiles NPCs path through (BFS). Missing / off-grid cells count as blocked.
const BFS_WALKABLE := {
	TileType.GRASS: true, TileType.FAIRWAY: true, TileType.PATH: true, TileType.ROUGH: true,
	TileType.TEE: true, TileType.BASKET: true, TileType.ENTRANCE: true,
}

## 1 = walkable, per cell index (col * GRID_ROWS + row); cached per layout.
func _walk_grid() -> PackedByteArray:
	var L := _layout()
	if not L.has("walk_grid"):
		var g := PackedByteArray()
		g.resize(GRID_COLS * GRID_ROWS)
		for cell in _tiles:
			var c: Vector2i = cell
			if c.x >= 0 and c.y >= 0 and c.x < GRID_COLS and c.y < GRID_ROWS and BFS_WALKABLE.has(_tiles[cell]):
				g[c.x * GRID_ROWS + c.y] = 1
		L["walk_grid"] = g
	return L["walk_grid"]

## Breadth-first path over walkable cells (4-neighbour, same order as always, so
## paths are unchanged). Goal cells may themselves be unwalkable (a disc resting
## in sand): the search can step onto a goal but never through blocked cells.
## Packed arrays instead of Dictionaries: ~20 ms → ~2 ms on a full 150×150 map —
## every NPC runs one after every throw.
func _bfs_cells(start: Vector2i, goals: Array) -> Array:
	if start.x < 0 or start.y < 0 or start.x >= GRID_COLS or start.y >= GRID_ROWS:
		return []
	var grid := _walk_grid()
	var n := GRID_COLS * GRID_ROWS
	var goal_mark := PackedByteArray()
	goal_mark.resize(n)
	var any_goal := false
	for g in goals:
		var gc: Vector2i = g
		if gc.x >= 0 and gc.y >= 0 and gc.x < GRID_COLS and gc.y < GRID_ROWS:
			goal_mark[gc.x * GRID_ROWS + gc.y] = 1
			any_goal = true
	if not any_goal:
		return []
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-2)                      # -2 = unvisited, -1 = start
	var queue := PackedInt32Array()
	queue.resize(n)
	var s := start.x * GRID_ROWS + start.y
	came[s] = -1
	queue[0] = s
	var head := 0
	var tail := 1
	var found := -1
	while head < tail:
		var cur := queue[head]
		head += 1
		if goal_mark[cur] == 1:
			found = cur
			break
		var cx := cur / GRID_ROWS
		var cy := cur % GRID_ROWS
		# Neighbour order matches the old search: +x, -x, +y, -y.
		if cx + 1 < GRID_COLS:
			var nb := cur + GRID_ROWS
			if came[nb] == -2 and (grid[nb] == 1 or goal_mark[nb] == 1):
				came[nb] = cur; queue[tail] = nb; tail += 1
		if cx > 0:
			var nb := cur - GRID_ROWS
			if came[nb] == -2 and (grid[nb] == 1 or goal_mark[nb] == 1):
				came[nb] = cur; queue[tail] = nb; tail += 1
		if cy + 1 < GRID_ROWS:
			var nb := cur + 1
			if came[nb] == -2 and (grid[nb] == 1 or goal_mark[nb] == 1):
				came[nb] = cur; queue[tail] = nb; tail += 1
		if cy > 0:
			var nb := cur - 1
			if came[nb] == -2 and (grid[nb] == 1 or goal_mark[nb] == 1):
				came[nb] = cur; queue[tail] = nb; tail += 1
	if found < 0:
		return []
	var path: Array = []
	var cur := found
	while cur != -1:
		path.push_front(Vector2i(cur / GRID_ROWS, cur % GRID_ROWS))
		cur = came[cur]
	return path

func _cells_to_world(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		result.append(_cell_world_pos(cell as Vector2i))
	return result

func _cell_world_pos(cell: Vector2i) -> Vector3:
	var tt: int = _tiles.get(cell, TileType.GRASS) as int
	return Vector3(cell.x * CELL_SIZE,
		_get_tile_world_y(cell, tt) + CELL_HEIGHT * 0.5,
		cell.y * CELL_SIZE)

# Removes redundant intermediate waypoints on straight stretches so NPCs walk
# in natural lines rather than zigzagging through every grid cell.
func _simplify_world_path(path: Array) -> Array:
	if path.size() <= 2:
		return path
	var result: Array = [path[0]]
	for i in range(1, path.size() - 1):
		var prev: Vector3 = result.back() as Vector3
		var curr: Vector3 = path[i] as Vector3
		var next: Vector3 = path[i + 1] as Vector3
		var d1 := Vector3(curr.x - prev.x, 0.0, curr.z - prev.z)
		var d2 := Vector3(next.x - curr.x, 0.0, next.z - curr.z)
		if d1.length_squared() > 0.001 and d2.length_squared() > 0.001:
			if d1.normalized().dot(d2.normalized()) < 0.98:
				result.append(curr)
	result.append(path.back() as Vector3)
	return result

# ── Public world-query helpers (used by NPCPlayer and DiscProjectile) ─────────

func get_tile_at(world_pos: Vector3) -> int:
	var col  := roundi(world_pos.x / CELL_SIZE)
	var row  := roundi(world_pos.z / CELL_SIZE)
	var cell := Vector2i(col, row)
	if not _valid(cell):
		return TileType.WATER   # treat out-of-bounds as water hazard
	return _tiles.get(cell, TileType.GRASS) as int

func get_ground_y(world_pos: Vector3) -> float:
	var col := roundi(world_pos.x / CELL_SIZE)
	var row := roundi(world_pos.z / CELL_SIZE)
	if not _valid(Vector2i(col, row)):
		return 0.0
	# Bilinear interpolation across the sloped tile surface.
	# Tile (col,row) spans x: [col*CS - CS/2 .. col*CS + CS/2], same for z.
	var x0  := col * CELL_SIZE - CELL_SIZE * 0.5
	var z0  := row * CELL_SIZE - CELL_SIZE * 0.5
	var fx  := clampf((world_pos.x - x0) / CELL_SIZE, 0.0, 1.0)
	var fz  := clampf((world_pos.z - z0) / CELL_SIZE, 0.0, 1.0)
	var y00 := _get_corner_y(col,     row    )  # NW
	var y10 := _get_corner_y(col + 1, row    )  # NE
	var y01 := _get_corner_y(col,     row + 1)  # SW
	var y11 := _get_corner_y(col + 1, row + 1)  # SE
	return lerpf(lerpf(y00, y10, fx), lerpf(y01, y11, fx), fz)

func find_walkable_path(from_pos: Vector3, to_pos: Vector3) -> Array:
	var from_cell := Vector2i(roundi(from_pos.x / CELL_SIZE), roundi(from_pos.z / CELL_SIZE))
	var to_cell   := Vector2i(roundi(to_pos.x   / CELL_SIZE), roundi(to_pos.z   / CELL_SIZE))
	if _los_clear(from_cell, to_cell):
		return [from_pos, to_pos]   # already clear — straight line
	var cells := _bfs_cells(from_cell, [to_cell])
	if cells.is_empty():
		var nearest := _find_nearest_walkable(to_cell, 10)
		if nearest != Vector2i(-1, -1):
			cells = _bfs_cells(from_cell, [nearest])
		if cells.is_empty():
			return [to_pos]
	return _cells_to_world(_string_pull(cells))

# Bresenham LOS: true when no non-walkable cell crosses the line from a to b.
func _los_clear(a: Vector2i, b: Vector2i) -> bool:
	const WALKABLE := {
		TileType.GRASS: true, TileType.FAIRWAY: true, TileType.PATH: true,
		TileType.ROUGH: true, TileType.TEE: true, TileType.BASKET: true,
		TileType.ENTRANCE: true, TileType.SAND: true, TileType.PARKING: true,
		TileType.RESTROOM: true, TileType.FOOD_STAND: true, TileType.PRO_SHOP: true,
	}
	var dx := absi(b.x - a.x)
	var dz := absi(b.y - a.y)
	var sx := 1 if b.x > a.x else -1
	var sz := 1 if b.y > a.y else -1
	var err := dx - dz
	var cx := a.x;  var cz := a.y
	while cx != b.x or cz != b.y:
		var cell := Vector2i(cx, cz)
		if not _valid(cell) or not WALKABLE.has(_tiles.get(cell, TileType.WATER) as int):
			return false
		var e2 := err * 2
		if e2 > -dz: err -= dz; cx += sx
		if e2 <  dx: err += dx; cz += sz
	return true

# String-pull: skip BFS waypoints whose LOS is already clear from the previous kept point.
func _string_pull(cells: Array) -> Array:
	if cells.size() <= 2:
		return cells
	var result: Array = [cells[0]]
	var anchor := 0
	var i := 2
	while i < cells.size():
		if not _los_clear(cells[anchor] as Vector2i, cells[i] as Vector2i):
			result.append(cells[i - 1])
			anchor = i - 1
		i += 1
	result.append(cells.back())
	return result

## Returns the nearest walkable cell within max_radius of center, or (-1,-1) if none.
func _find_nearest_walkable(center: Vector2i, max_radius: int) -> Vector2i:
	var walkable: Dictionary = {
		TileType.GRASS: true, TileType.FAIRWAY: true,
		TileType.PATH:  true, TileType.ROUGH:   true,
		TileType.TEE:   true, TileType.BASKET:  true,
		TileType.ENTRANCE: true,
	}
	for r in range(1, max_radius + 1):
		for dc in range(-r, r + 1):
			for dr in range(-r, r + 1):
				if absi(dc) != r and absi(dr) != r:
					continue  # only perimeter of this radius ring
				var c := Vector2i(center.x + dc, center.y + dr)
				if _valid(c) and walkable.has(_tiles.get(c, TileType.WATER)):
					return c
	return Vector2i(-1, -1)

func get_tile_snapshot() -> Dictionary:
	return _tiles

## Export all course state dicts for multi-course snapshot/restore.
func export_full_state() -> Dictionary:
	return {
		"tiles":               _tiles.duplicate(),
		"tile_heights":        _tile_heights.duplicate(),
		"tile_hole_num":       _tile_hole_num.duplicate(),
		"tile_orientations":   _tile_orientations.duplicate(),
		"tile_par":            _tile_par.duplicate(),
		"hole_custom_colors":  _hole_custom_colors.duplicate(),
		"facility_orientations": _facility_orientations.duplicate(),
		"facility_colors":     _facility_colors.duplicate(),
		"building_anchor":     _building_anchor.duplicate(),
		"hole_waypoints":      _hole_waypoints.duplicate(true),
		"tile_variants":       _tile_variants.duplicate(),
		"tile_tree_size":      _tile_tree_size.duplicate(),
		"ob_zones":            _ob_zones.duplicate(),
		"rock_overlays":       _rock_overlays.duplicate(),
	}

## JSON round-trips Vector2i keys as strings like "(75, 3)". Restore them.
func _v2i_from_variant(k: Variant) -> Vector2i:
	if k is Vector2i:
		return k as Vector2i
	var s := str(k).replace("(", "").replace(")", "").replace(" ", "")
	var parts := s.split(",")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i.ZERO

func _remap_v2i(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return d
	if d.keys()[0] is Vector2i:
		return d.duplicate()
	var out: Dictionary = {}
	for k in d:
		out[_v2i_from_variant(k)] = d[k]
	return out

## Restore course state from a snapshot; restarts NPC system if in gameplay mode.
func import_full_state(state: Dictionary) -> void:
	var was_playing := _gameplay_mode
	if was_playing:
		set_gameplay_mode(false)
	_clear_tile_visuals()
	_tiles               = _remap_v2i(state.get("tiles",                {}) as Dictionary)
	_tile_heights        = _remap_v2i(state.get("tile_heights",         {}) as Dictionary)
	_tile_hole_num       = _remap_v2i(state.get("tile_hole_num",        {}) as Dictionary)
	_tile_orientations   = _remap_v2i(state.get("tile_orientations",    {}) as Dictionary)
	_tile_par            = _remap_v2i(state.get("tile_par",             {}) as Dictionary)
	_hole_custom_colors  = _remap_v2i(state.get("hole_custom_colors",   {}) as Dictionary)
	_facility_orientations = _remap_v2i(state.get("facility_orientations", {}) as Dictionary)
	_facility_colors     = _remap_v2i(state.get("facility_colors",      {}) as Dictionary)
	_building_anchor     = _remap_v2i(state.get("building_anchor",      {}) as Dictionary)
	_hole_waypoints      = _remap_v2i(state.get("hole_waypoints",       {}) as Dictionary)
	_tile_variants       = _remap_v2i(state.get("tile_variants",        {}) as Dictionary)
	_tile_tree_size      = _remap_v2i(state.get("tile_tree_size",       {}) as Dictionary)
	_ob_zones            = _remap_v2i(state.get("ob_zones",             {}) as Dictionary)
	_rock_overlays       = _remap_v2i(state.get("rock_overlays",        {}) as Dictionary)
	for cell: Vector2i in _tiles:
		_update_tile_visual(cell, _tiles[cell] as int, false)
	_rebuild_water_layer()
	_smooth_dirty = true
	if was_playing:
		set_gameplay_mode(true)

## Wipe all tile data and visuals (used before applying a fresh course preset).
func clear_all_tiles() -> void:
	var was_playing := _gameplay_mode
	if was_playing:
		set_gameplay_mode(false)
	_clear_tile_visuals()
	_tiles.clear()
	_tile_heights.clear()
	_tile_hole_num.clear()
	_tile_orientations.clear()
	_tile_par.clear()
	_hole_custom_colors.clear()
	_facility_orientations.clear()
	_facility_colors.clear()
	_building_anchor.clear()
	_hole_waypoints.clear()
	_tile_variants.clear()
	_tile_tree_size.clear()
	_ob_zones.clear()
	_rock_overlays.clear()
	_rebuild_water_layer()
	_smooth_dirty = true

## Free all visual props and reset existing tile instances to flat grass.
func _clear_tile_visuals() -> void:
	for cell in _tiles:
		var vc := cell as Vector2i
		if _terrain_mm:
			var idx := vc.x * GRID_ROWS + vc.y
			var world_y: float = TILE_Y[TileType.GRASS] as float
			var xf := Transform3D.IDENTITY
			xf.origin = Vector3(vc.x * CELL_SIZE, _terrain_box_center_y(world_y), vc.y * CELL_SIZE)
			_terrain_mm.set_instance_transform(idx, xf)
			_terrain_mm.set_instance_color(idx, TILE_COLOR[TileType.GRASS] as Color)
	for prop in _props.values():
		if is_instance_valid(prop):
			(prop as Node3D).queue_free()
	_props.clear()
	if _batch:
		_batch.clear()
	for prop in _ob_props.values():
		if is_instance_valid(prop):
			(prop as Node3D).queue_free()
	_ob_props.clear()
	for prop in _rock_props_overlay.values():
		if is_instance_valid(prop):
			(prop as Node3D).queue_free()
	_rock_props_overlay.clear()
	for flag in _flag_nodes:
		if is_instance_valid(flag):
			(flag as Node3D).queue_free()
	_flag_nodes.clear()

## Load a terrain preset (no economy cost, no undo stack).
## tile_map: { Vector2i → TileType int } covering the full grid.
## Skips TEE/BASKET/ENTRANCE tiles — those are placed manually after.
func load_terrain_preset(tile_map: Dictionary) -> void:
	const SKIP_TYPES := [TileType.TEE, TileType.BASKET, TileType.ENTRANCE, TileType.PRO_SHOP]
	var normalized := _remap_v2i(tile_map)
	for cell: Vector2i in normalized:
		var tt: int = normalized[cell] as int
		if tt in SKIP_TYPES:
			continue
		if not _valid(cell):
			continue
		_tiles[cell] = tt
		_update_tile_visual(cell, tt, false)
	_rebuild_water_layer()
	_smooth_dirty = true

## Circuit-course presets ship without a gate, and without one no holes are
## built and no players ever arrive (_build_all_holes needs an entrance). Puts an
## Entrance on the top edge (like home's gate), nearest the middle, where it opens
## onto a large walkable area — never into a pocket fenced by trees or water.
## Returns the entrance cell (existing or new), or (-1, -1) if none fits.
const ENTRANCE_MIN_REACH := 3000

func ensure_entrance() -> Vector2i:
	for cell in _tiles:
		if int(_tiles[cell]) == TileType.ENTRANCE:
			return cell
	var comp := _walk_components()
	var label: PackedInt32Array = comp[0]
	var sizes: PackedInt32Array = comp[1]
	var largest := 0
	for sz in sizes:
		largest = maxi(largest, sz)
	if largest == 0:
		return Vector2i(-1, -1)
	# Dense forests (Krokhol) have no 3000-cell clearing: aim for the biggest one.
	var need := mini(ENTRANCE_MIN_REACH, largest)
	# 1. An edge cell (top, bottom, left, right — each from the middle out) whose
	#    inward neighbour belongs to a big enough walkable area.
	var mid := GRID_COLS / 2
	var gate := Vector2i(-1, -1)
	for edge in 4:
		for k in GRID_COLS:
			var i := mid + (k / 2 if k % 2 == 0 else -(k / 2 + 1))
			if i < 0 or i >= GRID_COLS:
				continue
			var g: Vector2i = [Vector2i(i, 0), Vector2i(i, GRID_ROWS - 1), Vector2i(0, i), Vector2i(GRID_COLS - 1, i)][edge]
			var inward: Vector2i = [Vector2i(i, 1), Vector2i(i, GRID_ROWS - 2), Vector2i(1, i), Vector2i(GRID_COLS - 2, i)][edge]
			var id := label[inward.x * GRID_ROWS + inward.y]
			if id >= 0 and sizes[id] >= need:
				gate = g
				break
		if gate.x >= 0:
			break
	# 2. Forest on every edge: cut an access path straight in from the top edge.
	if gate.x < 0:
		gate = _carve_access_path(label, sizes, need)
	if gate.x < 0:
		return gate
	_tiles[gate] = TileType.ENTRANCE
	if is_inside_tree():
		_update_tile_visual(gate, TileType.ENTRANCE, false)
	return gate

## Labels each walkable area: [label per cell (-1 = blocked), size per label].
func _walk_components() -> Array:
	var grid := _walk_grid()
	var n := GRID_COLS * GRID_ROWS
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var sizes := PackedInt32Array()
	for s0 in n:
		if grid[s0] != 1 or label[s0] != -1:
			continue
		var id := sizes.size()
		var queue := PackedInt32Array([s0])
		label[s0] = id
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			var cx := cur / GRID_ROWS
			var cy := cur % GRID_ROWS
			for nb in [cur + GRID_ROWS if cx + 1 < GRID_COLS else -1, cur - GRID_ROWS if cx > 0 else -1,
					cur + 1 if cy + 1 < GRID_ROWS else -1, cur - 1 if cy > 0 else -1]:
				if nb >= 0 and label[nb] == -1 and grid[nb] == 1:
					label[nb] = id
					queue.append(nb)
		sizes.append(queue.size())
	return [label, sizes]

## Finds the column (nearest the middle) where walking down from the top edge
## soonest reaches a big enough walkable area, and paints PATH along the way.
## Returns the gate cell on the top edge, or (-1, -1).
func _carve_access_path(label: PackedInt32Array, sizes: PackedInt32Array, need: int) -> Vector2i:
	var mid := GRID_COLS / 2
	var best_c := -1
	var best_r := GRID_ROWS
	for k in GRID_COLS:
		var c := mid + (k / 2 if k % 2 == 0 else -(k / 2 + 1))
		if c < 0 or c >= GRID_COLS:
			continue
		for r in range(1, mini(best_r, GRID_ROWS - 1)):
			if int(_tiles.get(Vector2i(c, r), TileType.WATER)) == TileType.WATER:
				break              # don't pave across lakes
			var id := label[c * GRID_ROWS + r]
			if id >= 0 and sizes[id] >= need:
				best_c = c
				best_r = r
				break
	if best_c < 0:
		return Vector2i(-1, -1)
	for r in range(1, best_r):
		var cell := Vector2i(best_c, r)
		_tiles[cell] = TileType.PATH
		if is_inside_tree():
			_update_tile_visual(cell, TileType.PATH, false)
	return Vector2i(best_c, 0)

## Walkable cells reachable from `start`, counting up to `limit`.
func _reach_count(start: Vector2i, limit: int) -> int:
	if not _valid(start):
		return 0
	var grid := _walk_grid()
	var s := start.x * GRID_ROWS + start.y
	if grid[s] != 1:
		return 0
	var seen := PackedByteArray()
	seen.resize(GRID_COLS * GRID_ROWS)
	seen[s] = 1
	var queue := PackedInt32Array([s])
	var head := 0
	while head < queue.size() and queue.size() < limit:
		var cur := queue[head]
		head += 1
		var cx := cur / GRID_ROWS
		var cy := cur % GRID_ROWS
		for nb in [cur + GRID_ROWS if cx + 1 < GRID_COLS else -1, cur - GRID_ROWS if cx > 0 else -1,
				cur + 1 if cy + 1 < GRID_ROWS else -1, cur - 1 if cy > 0 else -1]:
			if nb >= 0 and seen[nb] == 0 and grid[nb] == 1:
				seen[nb] = 1
				queue.append(nb)
	return queue.size()

## Away round: replace the world with a circuit course's terrain preset plus its
## tees/baskets. Caller (GameManager) snapshots the real course first and
## restores it with import_full_state() afterwards.
## holes: [[tee: Vector2i, basket: Vector2i], ...]
func load_away_course(tile_map: Dictionary, holes: Array) -> void:
	const AwayLayouts = preload("res://core/data/AwayLayouts.gd")
	clear_all_tiles()   # also stops NPC spawning
	load_terrain_preset(tile_map)
	for i in holes.size():
		var tee: Vector2i    = (holes[i] as Array)[0] as Vector2i
		var basket: Vector2i = (holes[i] as Array)[1] as Vector2i
		_place_hole(i + 1, tee, _orientation_toward(tee, basket), basket)
		_tile_par[tee] = AwayLayouts.par_for_distance(_cell_world_pos(tee).distance_to(_cell_world_pos(basket)))
		_update_tile_visual(tee, TileType.TEE, false)
		_update_tile_visual(basket, TileType.BASKET, false)
	_build_all_holes()

## Tee orientation (0 = -Z, 1 = +X, 2 = +Z, 3 = -X) facing from a toward b.
func _orientation_toward(a: Vector2i, b: Vector2i) -> int:
	var d := b - a
	if absi(d.x) > absi(d.y):
		return 1 if d.x > 0 else 3
	return 2 if d.y > 0 else 0

func get_ob_snapshot() -> Dictionary:
	return _ob_zones

func get_npc_world_positions() -> Array:
	var positions: Array = []
	if not _npc_root:
		return positions
	for child in _npc_root.get_children():
		if child is Node3D:
			positions.append((child as Node3D).global_position)
	return positions

# ── Architect tools ───────────────────────────────────────────────────────────

func get_route_waypoint_count(hole_num: int) -> int:
	return (_hole_waypoints.get(hole_num, []) as Array).size()

func get_route_waypoints(hole_num: int) -> Array:
	return _hole_waypoints.get(hole_num, []) as Array

## Auto-generate evenly-spaced waypoints in a straight line from tee to basket.
## Replaces any existing waypoints for this hole.
func set_straight_route(hole_num: int, steps: int = 4) -> void:
	var h_info := _get_hole_info_for(hole_num)
	if h_info.is_empty():
		return
	var tee:    Vector2i = h_info["tee_cell"]    as Vector2i
	var basket: Vector2i = h_info["basket_cell"] as Vector2i
	var wps: Array = []
	for i in range(1, steps + 1):
		var t := float(i) / float(steps + 1)
		var wp := Vector2i(
			roundi(lerpf(float(tee.x), float(basket.x), t)),
			roundi(lerpf(float(tee.y), float(basket.y), t))
		)
		wps.append(wp)
	_hole_waypoints[hole_num] = wps
	draw_route_lines()
	route_changed.emit(hole_num)

func get_tee_orientation(tee_cell: Vector2i) -> int:
	return _tile_orientations.get(tee_cell, 2) as int

## Paint a single cell without going through _active_tool. Charges tile cost.
## Never overwrites TEE or BASKET. Returns false if insufficient funds or invalid.
func architect_paint_cell(cell: Vector2i, tile_type: int, _hole_num: int = 1) -> bool:
	if not _valid(cell):
		return false
	var old_tt: int = _tiles.get(cell, TileType.GRASS) as int
	if old_tt == TileType.TEE or old_tt == TileType.BASKET:
		return false
	if old_tt == tile_type:
		return true
	var cost: float = TILE_COSTS.get(tile_type, 0.0) as float
	if cost > 0.0 and not EconomyManager.spend(cost, "construction"):
		return false
	_tiles[cell] = tile_type
	_update_tile_visual(cell, tile_type, true)
	cell_changed.emit(cell.x, cell.y, tile_type)
	return true

## Bresenham rasterise between two grid cells. Returns Array[Vector2i].
func _bresenham_cells(a: Vector2i, b: Vector2i) -> Array:
	var cells: Array = []
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if b.x > a.x else -1
	var sy := 1 if b.y > a.y else -1
	var x := a.x; var y := a.y
	var err := dx - dy
	while true:
		cells.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy; x += sx
		if e2 < dx:
			err += dx; y += sy
	return cells

func _get_hole_info_for(hole_num: int) -> Dictionary:
	for h in get_holes_info():
		if (h["hole_num"] as int) == hole_num:
			return h
	return {}

## Paint fairway along hole route (tee → waypoints → basket) at given cell width.
## Skips TEE and BASKET cells. Returns painted cell count.
func paint_route_as_fairway(hole_num: int, width: int) -> int:
	var h_info := _get_hole_info_for(hole_num)
	if h_info.is_empty():
		return 0
	var tee:    Vector2i = h_info["tee_cell"]    as Vector2i
	var basket: Vector2i = h_info["basket_cell"] as Vector2i
	var wps: Array = _hole_waypoints.get(hole_num, []) as Array

	var pts: Array = [tee]
	for wp in wps:
		pts.append(wp as Vector2i)
	pts.append(basket)

	var half_w := width / 2
	var visited: Dictionary = {}
	var painted := 0
	for i in pts.size() - 1:
		var seg := _bresenham_cells(pts[i] as Vector2i, pts[i + 1] as Vector2i)
		for center_v in seg:
			var center := center_v as Vector2i
			for dx in range(-half_w, half_w + 1):
				for dy in range(-half_w, half_w + 1):
					if dx * dx + dy * dy <= half_w * half_w + half_w:
						var c := Vector2i(center.x + dx, center.y + dy)
						if not visited.has(c):
							visited[c] = true
							if architect_paint_cell(c, TileType.FAIRWAY, hole_num):
								painted += 1
	return painted

## Add rough tiles adjacent to fairway within the hole bounding box.
## Only paints on GRASS tiles. Returns painted cell count.
func add_rough_border_to_fairway(hole_num: int) -> int:
	var h_info := _get_hole_info_for(hole_num)
	if h_info.is_empty():
		return 0
	var tee:    Vector2i = h_info["tee_cell"]    as Vector2i
	var basket: Vector2i = h_info["basket_cell"] as Vector2i
	var min_c := maxi(0, mini(tee.x, basket.x) - 15)
	var max_c := mini(GRID_COLS - 1, maxi(tee.x, basket.x) + 15)
	var min_r := maxi(0, mini(tee.y, basket.y) - 15)
	var max_r := mini(GRID_ROWS - 1, maxi(tee.y, basket.y) + 15)

	var to_paint: Dictionary = {}
	for c in range(min_c, max_c + 1):
		for r in range(min_r, max_r + 1):
			if (_tiles.get(Vector2i(c, r), TileType.GRASS) as int) == TileType.FAIRWAY:
				for dc in [-1, 0, 1]:
					for dr in [-1, 0, 1]:
						if dc == 0 and dr == 0:
							continue
						var nc := Vector2i(c + dc, r + dr)
						if _valid(nc) and (_tiles.get(nc, TileType.GRASS) as int) == TileType.GRASS:
							to_paint[nc] = true
	var painted := 0
	for c in to_paint:
		if architect_paint_cell(c as Vector2i, TileType.ROUGH, hole_num):
			painted += 1
	return painted

## Apply a template: paint tile array relative to tee_cell, rotated by tee orientation.
## basket_offset: when provided, relocates the hole's basket to that rotated offset from tee.
## template_tiles: Array[{offset: Vector2i, type: int}]. Returns painted count.
func apply_hole_template(tee_cell: Vector2i, hole_num: int, template_tiles: Array, basket_offset: Vector2i = Vector2i(-9999, -9999)) -> int:
	var orientation: int = _tile_orientations.get(tee_cell, 2) as int
	var painted := 0
	for entry in template_tiles:
		var e := entry as Dictionary
		var raw_off: Vector2i = e["offset"] as Vector2i
		var tile_type: int    = e["type"]   as int
		var rotated := _rotate_template_offset(raw_off, orientation)
		var cell := tee_cell + rotated
		if architect_paint_cell(cell, tile_type, hole_num):
			painted += 1
	if basket_offset.x != -9999:
		# Clear old basket — direct write because architect_paint_cell guards against BASKET overwrite
		for key in _tiles.keys():
			var k := key as Vector2i
			if (_tiles.get(k, TileType.GRASS) as int) == TileType.BASKET \
					and (_tile_hole_num.get(k, 0) as int) == hole_num:
				_tiles[k] = TileType.GRASS
				_update_tile_visual(k, TileType.GRASS, false)
				break
		# Write new basket at rotated offset
		var rotated_basket := _rotate_template_offset(basket_offset, orientation)
		var new_basket := tee_cell + rotated_basket
		if _valid(new_basket):
			_tiles[new_basket]             = TileType.BASKET
			_tile_hole_num[new_basket]     = hole_num
			_tile_orientations[new_basket] = orientation
			_update_tile_visual(new_basket, TileType.BASKET, false)
			painted += 1
		_build_all_holes()
		draw_route_lines()
	return painted

func _rotate_template_offset(off: Vector2i, orientation: int) -> Vector2i:
	match orientation:
		0: return Vector2i(-off.x, -off.y)   # N: 180°
		1: return Vector2i(off.y,  -off.x)   # E: 90° CW
		3: return Vector2i(-off.y,  off.x)   # W: 90° CCW
	return off                               # S: no change

## Tree cells whose base lies inside the XZ rectangle [lo, hi] → base position.
## Used by PlayTestController's camera-occlusion fade (scans only that box).
func get_tree_positions_in(lo: Vector2, hi: Vector2) -> Dictionary:
	var out: Dictionary = {}
	var c0 := maxi(0, floori(minf(lo.x, hi.x) / CELL_SIZE))
	var c1 := mini(GRID_COLS - 1, ceili(maxf(lo.x, hi.x) / CELL_SIZE))
	var r0 := maxi(0, floori(minf(lo.y, hi.y) / CELL_SIZE))
	var r1 := mini(GRID_ROWS - 1, ceili(maxf(lo.y, hi.y) / CELL_SIZE))
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			var cell := Vector2i(c, r)
			if (_tiles.get(cell, TileType.GRASS) as int) == TileType.TREE:
				out[cell] = _cell_world_pos(cell)
	return out

## Hide/show one tree (camera-occlusion fade). Works for batched and node trees.
func set_tree_hidden(cell: Vector2i, hidden: bool) -> void:
	if _props.has(cell) and is_instance_valid(_props[cell]):
		(_props[cell] as Node3D).visible = not hidden
	elif _batch:
		_batch.set_hidden(cell, hidden)
