## Ale DGC White course terrain preset — Gothenburg, Sweden
## Classic European links: open fairways, strategic sand bunkers, water hazards, pristine conditions.
class_name AleWhitePreset
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

	# Open links base — mostly manicured grass with rough borders
	for x in COLS:
		for z in ROWS:
			t[Vector2i(x, z)] = T_GRASS

	# Perimeter rough (out of bounds feel)
	for x in COLS:
		for z in ROWS:
			if x < 5 or x >= 145 or z < 5 or z >= 145:
				t[Vector2i(x, z)] = T_ROUGH

	# Tree rows — sparse birch/pine at edges (Scandinavian style)
	for x in range(5, 30):
		for z in range(5, 10):
			t[Vector2i(x, z)] = T_TREE
	for x in range(120, 145):
		for z in range(5, 12):
			t[Vector2i(x, z)] = T_TREE
	for x in range(5, 20):
		for z in range(130, 145):
			t[Vector2i(x, z)] = T_TREE
	for x in range(125, 145):
		for z in range(128, 145):
			t[Vector2i(x, z)] = T_TREE
	# Interior windbreak row
	for z in range(72, 77):
		for x in range(30, 80):
			t[Vector2i(x, z)] = T_TREE

	# Water hazards — links-style ponds
	_fill_ellipse(t, 55,  38, 14, 10, T_WATER)
	_fill_ellipse(t, 105, 62, 12,  9, T_WATER)
	_fill_ellipse(t, 70, 115, 16, 11, T_WATER)

	# Strategic sand bunkers (multiple clusters per zone)
	# Front 9 bunkers
	_fill_ellipse(t, 42,  55, 4, 3, T_SAND)
	_fill_ellipse(t, 68,  50, 3, 2, T_SAND)
	_fill_ellipse(t, 35,  30, 3, 3, T_SAND)
	_fill_ellipse(t, 80,  30, 4, 3, T_SAND)
	_fill_ellipse(t, 55,  55, 3, 2, T_SAND)
	_fill_ellipse(t, 120, 42, 4, 3, T_SAND)
	_fill_ellipse(t, 130, 58, 3, 2, T_SAND)
	# Back 9 bunkers
	_fill_ellipse(t, 45,  95, 4, 3, T_SAND)
	_fill_ellipse(t, 90,  88, 3, 3, T_SAND)
	_fill_ellipse(t, 110, 100, 4, 3, T_SAND)
	_fill_ellipse(t, 55, 128, 4, 3, T_SAND)
	_fill_ellipse(t, 95, 125, 3, 3, T_SAND)
	_fill_ellipse(t, 125, 112, 4, 3, T_SAND)

	# Water sand rings
	_sand_ring(t, 55,  38, 14, 17, T_WATER)
	_sand_ring(t, 105, 62, 12, 15, T_WATER)
	_sand_ring(t, 70, 115, 16, 19, T_WATER)

	# H1 — wide opener, slight dogleg
	_paint_fairway(t,  20, 135,  38, 120, 5)
	# H2 — long left to right sweep
	_paint_fairway(t,  40, 118,  68, 112, 5)
	# H3 — approach over front bunkers
	_paint_fairway(t,  70, 110,  88, 100, 4)
	# H4 — right side, near right water
	_paint_fairway(t,  90,  98, 108,  88, 4)
	# H5 — long par-5 traverse
	_paint_fairway(t, 110,  86, 132,  78, 5)
	# H6 — right of right pond
	_paint_fairway(t, 132,  76, 138,  58, 4)
	# H7 — back left across upper zone
	_paint_fairway(t, 136,  56, 118,  42, 5)
	# H8 — approach to upper pond
	_paint_fairway(t, 116,  40,  70,  32, 5)
	# H9 — front 9 finish, closing shot
	_paint_fairway(t,  68,  30,  40,  22, 4)

	# H10 — back 9 opener, long left traverse
	_paint_fairway(t,  30,  20,  18,  45, 4)
	# H11 — short precision over tree row gap
	_paint_fairway(t,  18,  47,  28,  62, 4)
	# H12 — windbreak traverse
	_paint_fairway(t,  30,  64,  55,  68, 4)
	# H13 — right of windbreak
	_paint_fairway(t,  57,  70,  80,  80, 4)
	# H14 — approach to lower pond
	_paint_fairway(t,  82,  82,  72, 100, 4)
	# H15 — around lower pond left
	_paint_fairway(t,  70, 102,  55, 112, 4)
	# H16 — lower left, back toward home
	_paint_fairway(t,  52, 115,  38, 125, 4)
	# H17 — short precision approach
	_paint_fairway(t,  36, 127,  26, 135, 4)
	# H18 — closing hole, wide and celebratory
	_paint_fairway(t,  24, 137,  18, 140, 5)

	# Clubhouse / entry area path
	_fill_rect(t, 10, 130, 14, 8, T_PATH)
	for z in range(138, 150):
		t[Vector2i(14, z)] = T_PATH

	return t

static func _paint_fairway(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width + 2, T_ROUGH, [T_WATER, T_TREE, T_SAND])
	_paint_line_width(t, x1, z1, x2, z2, width,     T_FAIRWAY, [T_WATER, T_TREE, T_SAND])

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
