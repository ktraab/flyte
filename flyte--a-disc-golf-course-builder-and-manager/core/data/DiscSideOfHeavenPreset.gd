## Disc Side of Heaven terrain preset — Eureka, MO
## Dramatic hillside: open exposed ridgelines alternating with dense wooded valleys, water features.
class_name DiscSideOfHeavenPreset
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

	# Alternating ridgelines (open grass) and valleys (dense trees)
	# Ridge bands run diagonally upper-left to lower-right
	for x in COLS:
		for z in ROWS:
			var band := (x + z) % 40
			if band < 18:
				t[Vector2i(x, z)] = T_GRASS
			else:
				t[Vector2i(x, z)] = T_TREE

	# Wide open plateau — upper center (signature exposed area)
	_fill_ellipse(t, 80, 40, 35, 22, T_GRASS)
	# Rough ring at plateau edge (windswept)
	_fill_ellipse(t, 80, 40, 38, 25, T_ROUGH)
	_fill_ellipse(t, 80, 40, 35, 22, T_GRASS)

	# Lower entry clearing
	_fill_ellipse(t, 25, 128, 20, 15, T_GRASS)

	# Valley lake (lower center)
	_fill_ellipse(t, 55, 105, 16, 12, T_WATER)
	_sand_ring(t, 55, 105, 16, 20, T_WATER)

	# Ridge-top pond (dramatic exposed water on plateau)
	_fill_ellipse(t, 95, 35, 10, 7, T_WATER)
	_sand_ring(t, 95, 35, 10, 13, T_WATER)

	# Rough patches on exposed ridgelines (windswept rocky ground)
	_fill_ellipse(t, 40,  65, 10, 8, T_ROUGH)
	_fill_ellipse(t, 120, 80, 12, 9, T_ROUGH)
	_fill_ellipse(t, 65,  45, 8,  6, T_ROUGH)

	# H1 — opener climbing up-right from entry clearing
	_paint_fairway(t,  25, 122,  45, 110, 3)
	# H2 — ridge traverse, exposed
	_paint_fairway(t,  47, 108,  65,  98, 4)
	# H3 — downhill into valley (thrilling)
	_paint_fairway(t,  67,  96,  58, 108, 3)
	# H4 — long ridge-to-ridge across valley pond
	_paint_fairway(t,  57, 112,  42, 100, 4)
	# H5 — uphill climb to plateau
	_paint_fairway(t,  40,  98,  52,  78, 4)
	# H6 — plateau traverse, wide open
	_paint_fairway(t,  54,  76,  72,  68, 4)
	# H7 — long bomb on plateau toward upper pond
	_paint_fairway(t,  74,  66,  92,  42, 5)
	# H8 — right around upper pond edge
	_paint_fairway(t,  93,  40, 108,  38, 3)
	# H9 — plateau edge, into the trees
	_paint_fairway(t, 110,  36, 125,  50, 3)
	# H10 — right side descent into valley
	_paint_fairway(t, 127,  52, 130,  72, 3)
	# H11 — right valley, long sweeper
	_paint_fairway(t, 128,  74, 110,  90, 4)
	# H12 — back up the ridge
	_paint_fairway(t, 108,  92,  92, 100, 3)
	# H13 — across exposed shoulder
	_paint_fairway(t,  90, 102,  72, 108, 3)
	# H14 — approach to valley lake
	_paint_fairway(t,  70, 110,  60, 118, 3)
	# H15 — around lake, left side
	_paint_fairway(t,  58, 120,  42, 118, 3)
	# H16 — descent back down
	_paint_fairway(t,  40, 116,  32, 130, 3)
	# H17 — short approach to entry area
	_paint_fairway(t,  30, 132,  25, 138, 3)
	# H18 — closing ridge hole back to clearing
	_paint_fairway(t,  24, 140,  20, 128, 3)

	# Entry path and parking
	for z in range(135, 150):
		t[Vector2i(12, z)] = T_PATH
	_fill_rect(t, 8, 133, 14, 6, T_PATH)

	return t

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
