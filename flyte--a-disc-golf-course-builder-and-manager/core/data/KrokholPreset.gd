## Krokhol terrain preset — Krokhol, Norway
## Dense Nordic boreal forest: narrow tunnel fairways, glacial lake, minimal clearings.
class_name KrokholPreset
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

	# Dense boreal forest — the whole map is trees
	for x in COLS:
		for z in ROWS:
			t[Vector2i(x, z)] = T_TREE

	# Main clearing — clubhouse / start (lower-left)
	_fill_ellipse(t, 18, 130, 16, 13, T_GRASS)

	# Signature glacial lake (upper-center) — large, dramatic
	_fill_ellipse(t, 80, 45, 28, 20, T_WATER)
	# Rocky shore (sand approximation)
	_sand_ring(t, 80, 45, 28, 32, T_WATER)

	# Secondary small tarn (right side)
	_fill_ellipse(t, 125, 95, 10, 8, T_WATER)
	_sand_ring(t, 125, 95, 10, 13, T_WATER)

	# Small open bog / marsh area (center-left)
	_fill_ellipse(t, 40, 80, 8, 6, T_ROUGH)

	# H1 — tight opener through trees
	_paint_fairway(t,  18, 124,  30, 112, 2)
	# H2 — narrow dogleg right
	_paint_fairway(t,  32, 110,  48, 105, 2)
	# H3 — long tunnel through dense boreal
	_paint_fairway(t,  50, 103,  68,  95, 3)
	# H4 — approach to lake left shore
	_paint_fairway(t,  70,  93,  62,  75, 3)
	# H5 — left edge of lake, precise line required
	_paint_fairway(t,  60,  73,  52,  60, 2)
	# H6 — over/around upper lake left
	_paint_fairway(t,  50,  58,  56,  42, 3)
	# H7 — long par-4 across lake gap (the signature hole)
	_paint_fairway(t,  55,  40,  75,  28, 4)
	# H8 — above lake, right traverse
	_paint_fairway(t,  78,  26,  100,  30, 3)
	# H9 — descent right side of lake
	_paint_fairway(t, 102,  32,  112,  48, 3)
	# H10 — right of lake, east forest
	_paint_fairway(t, 114,  50,  128,  58, 2)
	# H11 — long east forest hole
	_paint_fairway(t, 130,  60,  138,  80, 3)
	# H12 — approach to small tarn
	_paint_fairway(t, 136,  82,  128,  90, 2)
	# H13 — technical hole around small tarn
	_paint_fairway(t, 126,  92,  115, 100, 2)
	# H14 — back west, tight lines
	_paint_fairway(t, 112, 102,  92, 108, 3)
	# H15 — center-south through bog area
	_paint_fairway(t,  90, 110,  70, 115, 2)
	# H16 — left side return
	_paint_fairway(t,  68, 117,  50, 120, 2)
	# H17 — short precision hole near entry
	_paint_fairway(t,  48, 122,  35, 128, 2)
	# H18 — closing tunnel back to clearing
	_paint_fairway(t,  32, 130,  20, 132, 2)

	# Entry path (narrow forest road)
	for z in range(136, 150):
		t[Vector2i(14, z)] = T_PATH
	_fill_rect(t, 10, 134, 12, 5, T_PATH)

	return t

static func _paint_fairway(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width + 1, T_ROUGH, [T_WATER])
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
