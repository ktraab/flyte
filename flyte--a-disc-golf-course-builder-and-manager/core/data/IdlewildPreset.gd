## Idlewild terrain preset — Idlewild, KY
## Wooded Kentucky hills: dense hardwoods, winding creek (water corridor), technical lines.
class_name IdlewildPreset
extends RefCounted

const T_GRASS   := 0
const T_FAIRWAY := 1
const T_PATH    := 2
const T_WATER   := 3
const T_ROUGH   := 4
const T_TREE    := 5
const T_SAND    := 13

const COLS := 150
const ROWS := 150

static func build() -> Dictionary:
	var t: Dictionary = {}

	# Dense hardwood forest base
	for x in COLS:
		for z in ROWS:
			t[Vector2i(x, z)] = T_TREE

	# Main clearing — entry / clubhouse area (lower-left)
	_fill_ellipse(t, 20, 120, 22, 18, T_GRASS)
	_fill_ellipse(t, 20, 120, 25, 21, T_ROUGH)
	_fill_ellipse(t, 20, 120, 22, 18, T_GRASS)

	# Mid-course clearing (junction area)
	_fill_ellipse(t, 75, 75, 15, 12, T_GRASS)

	# Upper clearing (holes 14–18 staging)
	_fill_ellipse(t, 120, 30, 18, 14, T_GRASS)
	_fill_ellipse(t, 120, 30, 21, 17, T_ROUGH)
	_fill_ellipse(t, 120, 30, 18, 14, T_GRASS)

	# Creek — winds diagonally across the map (water corridor)
	_paint_water_creek(t, 10, 80, 50, 90)   # lower left segment
	_paint_water_creek(t, 50, 90, 85, 78)   # middle crossing
	_paint_water_creek(t, 85, 78, 110, 55)  # upper right segment
	_paint_water_creek(t, 110, 55, 130, 35) # far upper right

	# Small pond fed by creek (mid-course)
	_fill_ellipse(t, 88, 75, 9, 7, T_WATER)
	_sand_ring(t, 88, 75, 9, 12, T_WATER)

	# H1 — opener from clearing up-right through trees
	_paint_fairway(t,  20, 115,  38, 105, 3)
	# H2 — longer, across rough then into trees
	_paint_fairway(t,  40, 103,  60,  95, 3)
	# H3 — short dogleg left, must cross near creek
	_paint_fairway(t,  62,  93,  55,  80, 3)
	# H4 — long, over creek crossing
	_paint_fairway(t,  56,  78,  72,  70, 4)
	# H5 — short right, technical near pond
	_paint_fairway(t,  74,  70,  82,  68, 3)
	# H6 — around pond left
	_paint_fairway(t,  80,  66,  74,  60, 3)
	# H7 — center clearing across to right
	_paint_fairway(t,  75,  74,  95,  78, 3)
	# H8 — upper right, through dense woods
	_paint_fairway(t,  97,  76, 112,  65, 3)
	# H9 — long hole toward upper clearing
	_paint_fairway(t, 114,  63, 120,  48, 4)
	# H10 — short in upper clearing
	_paint_fairway(t, 120,  44, 132,  38, 3)
	# H11 — sweeping right side
	_paint_fairway(t, 134,  36, 140,  55, 3)
	# H12 — long back left
	_paint_fairway(t, 138,  57, 115,  72, 4)
	# H13 — technical creek crossing hole
	_paint_fairway(t, 112,  74,  95,  90, 3)
	# H14 — south run back toward mid clearing
	_paint_fairway(t,  92,  92,  78,  95, 3)
	# H15 — back left through rough
	_paint_fairway(t,  75,  97,  58, 105, 3)
	# H16 — left side, back toward entry area
	_paint_fairway(t,  55, 107,  42, 118, 3)
	# H17 — short closer through clearing edge
	_paint_fairway(t,  40, 120,  28, 125, 3)
	# H18 — finishing hole back to clubhouse
	_paint_fairway(t,  26, 127,  20, 122, 3)

	# Entry road
	for z in range(130, 150):
		t[Vector2i(15, z)] = T_PATH
	_fill_rect(t, 10, 128, 14, 5, T_PATH)

	return t

static func _paint_water_creek(t: Dictionary, x1: int, z1: int, x2: int, z2: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, 3, T_WATER, [])

static func _paint_fairway(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width + 2, T_ROUGH, [T_WATER])
	_paint_line_width(t, x1, z1, x2, z2, width,     T_FAIRWAY, [T_WATER])

static func _paint_line_width(t: Dictionary, x1: int, z1: int, x2: int, z2: int,
		width: int, tile: int, skip_tiles: Array) -> void:
	var half := width / 2
	var dx := absi(x2 - x1)
	var dz := absi(z2 - z1)
	var sx := 1 if x2 > x1 else -1
	var sz := 1 if z2 > z1 else -1
	var err := dx - dz
	var cx := x1; var cz := z1
	while true:
		for bx in range(cx - half, cx + half + 1):
			for bz in range(cz - half, cz + half + 1):
				if bx >= 0 and bx < COLS and bz >= 0 and bz < ROWS:
					var existing: int = t.get(Vector2i(bx, bz), T_TREE) as int
					if not (existing in skip_tiles):
						t[Vector2i(bx, bz)] = tile
		if cx == x2 and cz == z2:
			break
		var e2 := err * 2
		if e2 > -dz:
			err -= dz; cx += sx
		if e2 < dx:
			err += dx; cz += sz

static func _fill_ellipse(t: Dictionary, cx: int, cz: int, rx: int, rz: int, tile: int) -> void:
	for x in range(cx - rx, cx + rx + 1):
		for z in range(cz - rz, cz + rz + 1):
			var ddx := float(x - cx) / float(rx)
			var ddz := float(z - cz) / float(rz)
			if ddx * ddx + ddz * ddz <= 1.0:
				if x >= 0 and x < COLS and z >= 0 and z < ROWS:
					t[Vector2i(x, z)] = tile

static func _fill_rect(t: Dictionary, x: int, z: int, w: int, h: int, tile: int) -> void:
	for col in range(x, x + w):
		for row in range(z, z + h):
			if col >= 0 and col < COLS and row >= 0 and row < ROWS:
				t[Vector2i(col, row)] = tile

static func _sand_ring(t: Dictionary, cx: int, cz: int, inner_r: int, outer_r: int, water_tile: int) -> void:
	for x in range(cx - outer_r, cx + outer_r + 1):
		for z in range(cz - outer_r, cz + outer_r + 1):
			if x < 0 or x >= COLS or z < 0 or z >= ROWS:
				continue
			var ddx := float(x - cx) / float(outer_r)
			var ddz := float(z - cz) / float(outer_r)
			if ddx * ddx + ddz * ddz > 1.0:
				continue
			var ddx_i := float(x - cx) / float(inner_r)
			var ddz_i := float(z - cz) / float(inner_r)
			if ddx_i * ddx_i + ddz_i * ddz_i < 1.0:
				continue
			var existing: int = t.get(Vector2i(x, z), T_TREE) as int
			if existing != water_tile and existing != T_FAIRWAY and existing != T_PATH:
				t[Vector2i(x, z)] = T_SAND
