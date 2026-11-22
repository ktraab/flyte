## Isometric course world drawn procedurally — no art assets required yet.
## Each cell is a coloured diamond. Swap in a TileMapLayer + real sprites later
## without touching any other system.
class_name GameWorld
extends Node2D

# ── Tile types ────────────────────────────────────────────────────────────────
enum TileType { GRASS = 0, PATH = 1, WATER = 2, ROUGH = 3, TEE = 4, BASKET = 5 }

const TILE_COLORS: Dictionary = {
	TileType.GRASS:  Color(0.30, 0.58, 0.20),
	TileType.PATH:   Color(0.70, 0.60, 0.40),
	TileType.WATER:  Color(0.16, 0.40, 0.76),
	TileType.ROUGH:  Color(0.18, 0.40, 0.12),
	TileType.TEE:    Color(0.85, 0.85, 0.28),
	TileType.BASKET: Color(0.92, 0.40, 0.10),
}

# ── Grid config ───────────────────────────────────────────────────────────────
const CELL_W    := 128   # isometric cell pixel width
const CELL_H    := 64    # isometric cell pixel height
const GRID_COLS := 22
const GRID_ROWS := 20

# ── Draw config ───────────────────────────────────────────────────────────────
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.18)
const HOVER_COLOR   := Color(1.0, 1.0, 1.0, 0.30)

# ── State ─────────────────────────────────────────────────────────────────────
var _tiles: Dictionary = {}          # Vector2i(col,row) → TileType
var _hover_cell := Vector2i(-1, -1)
var _active_tool: int = TileType.GRASS
var _painting  := false
var _builder_mode := false

signal cell_changed(col: int, row: int, tile_type: int)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_generate_default_course()

func _input(event: InputEvent) -> void:
	if not _builder_mode:
		return
	# Don't paint when a UI Control has consumed this event
	if get_viewport().is_input_handled():
		return

	if event is InputEventMouseMotion:
		_hover_cell = screen_to_iso(get_global_mouse_position())
		queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = event.pressed
		if _painting:
			_paint(get_global_mouse_position())

	if event is InputEventMouseMotion and _painting:
		_paint(get_global_mouse_position())

# ── Public API ────────────────────────────────────────────────────────────────

func set_builder_mode(enabled: bool) -> void:
	_builder_mode = enabled
	if not enabled:
		_hover_cell = Vector2i(-1, -1)
	queue_redraw()

func set_active_tool(tile_type: int) -> void:
	_active_tool = tile_type

func get_world_center() -> Vector2:
	return iso_to_screen(GRID_COLS / 2, GRID_ROWS / 2)

func serialize_tiles() -> Array:
	var out: Array = []
	for key: Vector2i in _tiles:
		out.append({ "c": key.x, "r": key.y, "t": _tiles[key] })
	return out

func deserialize_tiles(data: Array) -> void:
	_tiles.clear()
	for entry: Dictionary in data:
		_tiles[Vector2i(entry["c"], entry["r"])] = entry["t"]
	queue_redraw()

# ── Default course layout ──────────────────────────────────────────────────────

func _generate_default_course() -> void:
	for col in GRID_COLS:
		for row in GRID_ROWS:
			_tiles[Vector2i(col, row)] = TileType.GRASS

	# Fairway
	for i in 14:
		_tiles[Vector2i(10, 2 + i)] = TileType.PATH
		_tiles[Vector2i(11, 2 + i)] = TileType.PATH

	# Tee box
	_tiles[Vector2i(10, 1)] = TileType.TEE
	_tiles[Vector2i(11, 1)] = TileType.TEE

	# Basket
	_tiles[Vector2i(10, 16)] = TileType.BASKET
	_tiles[Vector2i(11, 16)] = TileType.BASKET

	# Water hazard
	for c in range(3, 8):
		for r in range(6, 11):
			_tiles[Vector2i(c, r)] = TileType.WATER

	# Rough border
	for c in range(14, 19):
		for r in range(4, 14):
			_tiles[Vector2i(c, r)] = TileType.ROUGH

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Painter's algorithm: back row first so near cells overlay far cells
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var key := Vector2i(col, row)
			var tt: int = _tiles.get(key, TileType.GRASS)
			_draw_cell(col, row, TILE_COLORS.get(tt, Color.GRAY))

	if _builder_mode and _is_valid_cell(_hover_cell):
		_draw_cell(_hover_cell.x, _hover_cell.y, HOVER_COLOR)

func _draw_cell(col: int, row: int, color: Color) -> void:
	var c := iso_to_screen(col, row)
	var hw := CELL_W * 0.5
	var hh := CELL_H * 0.5
	var pts := PackedVector2Array([
		c + Vector2(0,  -hh),   # top
		c + Vector2(hw,  0),    # right
		c + Vector2(0,   hh),   # bottom
		c + Vector2(-hw, 0),    # left
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		OUTLINE_COLOR, 1.0)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _paint(world_pos: Vector2) -> void:
	var cell := screen_to_iso(world_pos)
	if not _is_valid_cell(cell):
		return
	_tiles[cell] = _active_tool
	cell_changed.emit(cell.x, cell.y, _active_tool)
	queue_redraw()

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS

## Isometric grid → screen space
func iso_to_screen(col: int, row: int) -> Vector2:
	return Vector2(
		(col - row) * CELL_W * 0.5,
		(col + row) * CELL_H * 0.5
	)

## Screen space → nearest isometric grid cell
func screen_to_iso(pos: Vector2) -> Vector2i:
	var col := int(round((pos.x / (CELL_W * 0.5) + pos.y / (CELL_H * 0.5)) * 0.5))
	var row := int(round((pos.y / (CELL_H * 0.5) - pos.x / (CELL_W * 0.5)) * 0.5))
	return Vector2i(col, row)
