## Winthrop Gold terrain preset — Winthrop, MN
## Open Minnesota prairie: wide fairways, scattered tree rows, one pond, golden meadows.
class_name WinthropGoldPreset
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

	# Open prairie base — mostly grass with rough patches
	for x in COLS:
		for z in ROWS:
			t[Vector2i(x, z)] = T_GRASS

	# Rough border / perimeter windbreak
	for x in COLS:
		for z in ROWS:
			if x < 4 or x >= 146 or z < 4 or z >= 146:
				t[Vector2i(x, z)] = T_ROUGH

	# Scattered tree rows (shelterbelts — Minnesota farmland style)
	for z in range(20, 25):
		for x in range(10, 140):
			t[Vector2i(x, z)] = T_TREE
	for z in range(70, 74):
		for x in range(15, 100):
			t[Vector2i(x, z)] = T_TREE
	for z in range(115, 119):
		for x in range(40, 145):
			t[Vector2i(x, z)] = T_TREE
	# Corner tree clusters
	_fill_ellipse(t, 130, 25,  10, 8,  T_TREE)
	_fill_ellipse(t, 20,  120, 12, 10, T_TREE)

	# Central pond
	_fill_ellipse(t, 75, 75, 14, 11, T_WATER)
	# Sand ring around pond
	_sand_ring(t, 75, 75, 14, 17, T_WATER)

	# Rough patches (uneven prairie ground)
	_fill_ellipse(t, 45,  45, 12, 8,  T_ROUGH)
	_fill_ellipse(t, 110, 55, 10, 9,  T_ROUGH)
	_fill_ellipse(t, 60,  110, 9, 7,  T_ROUGH)
	_fill_ellipse(t, 120, 105, 8, 6,  T_ROUGH)

	# H1 — short opener left side
	_paint_fairway(t,  15,  135,  30,  120, 3)
	# H2 — dogleg right across open ground
	_paint_fairway(t,  32,  118,  55,  110, 3)
	# H3 — long straight through rough patch
	_paint_fairway(t,  60,  108,  90,  112, 4)
	# H4 — approach toward pond left side
	_paint_fairway(t,  92,  110,  65,  90, 3)
	# H5 — around south pond edge
	_paint_fairway(t,  65,  88,  58,  78, 3)
	# H6 — technical left of pond
	_paint_fairway(t,  56,  75,  45,  60, 3)
	# H7 — cross tree row gap
	_paint_fairway(t,  42,  58,  38,  38, 3)
	# H8 — right through gap in upper shelterbelt
	_paint_fairway(t,  40,  36,  68,  28, 4)
	# H9 — long across upper field
	_paint_fairway(t,  72,  26,  110,  30, 4)
	# H10 — right side, south from upper
	_paint_fairway(t, 112,  32,  120,  55, 3)
	# H11 — right of pond
	_paint_fairway(t, 120,  58,  95,  72, 3)
	# H12 — approach over pond right edge
	_paint_fairway(t,  96,  75,  92,  85, 3)
	# H13 — sweeping right across prairie
	_paint_fairway(t,  90,  88, 120,  95, 4)
	# H14 — back left
	_paint_fairway(t, 118,  97, 100, 115, 3)
	# H15 — diagonal finish approach
	_paint_fairway(t,  98, 118,  75, 125, 3)
	# H16 — left side long
	_paint_fairway(t,  72, 128,  50, 132, 3)
	# H17 — short approach
	_paint_fairway(t,  48, 130,  35, 138, 3)
	# H18 — closing hole back to clubhouse
	_paint_fairway(t,  33, 140,  18, 138, 3)

	# Entry road / parking
	_fill_rect(t, 8, 130, 10, 6, T_PATH)
	for z in range(128, 148):
		t[Vector2i(10, z)] = T_PATH

	return t

static func _paint_fairway(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width + 2, T_ROUGH, [T_WATER, T_TREE])
	_paint_line_width(t, x1, z1, x2, z2, width,     T_FAIRWAY, [T_WATER, T_TREE])

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
					var existing: int = t.get(Vector2i(bx, bz), T_GRASS) as int
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
			var existing: int = t.get(Vector2i(x, z), T_GRASS) as int
			if existing != water_tile and existing != T_FAIRWAY and existing != T_PATH:
				t[Vector2i(x, z)] = T_SAND
