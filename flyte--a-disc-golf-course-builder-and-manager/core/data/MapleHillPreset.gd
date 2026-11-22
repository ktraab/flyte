## Maple Hill terrain preset — Leicester, MA
## Paints terrain tiles (no tees/baskets) faithfully to the real course layout.
## Based on satellite + tournament map imagery.
## Grid: 150×150, CELL_SIZE=2.0 (300×300m real world).
class_name MapleHillPreset
extends RefCounted

# ── Tile constants (must match GameWorld3D.TileType) ──────────────────────────
const T_GRASS   := 0
const T_FAIRWAY := 1
const T_PATH    := 2
const T_WATER   := 3
const T_ROUGH   := 4
const T_TREE    := 5
const T_SAND    := 13

const COLS := 150
const ROWS := 150

# ── Public entry point ────────────────────────────────────────────────────────

## Returns a Dictionary { Vector2i → TileType (int) } covering the full grid.
## Caller (GameWorld3D) applies these without charging economy costs.
static func build() -> Dictionary:
	var t: Dictionary = {}

	# ── 1. Base: rough with selective tree groves (not wall-to-wall forest) ─────
	for x in COLS:
		for z in ROWS:
			t[Vector2i(x, z)] = T_ROUGH

	# Outer border strip — dense tree line marking course boundary
	for x in COLS:
		for z in ROWS:
			if x < 4 or x >= COLS - 4 or z < 4 or z >= ROWS - 4:
				t[Vector2i(x, z)] = T_TREE

	# Named tree groves — preserved wooded character without blocking every gap
	_fill_ellipse(t,  20,  20, 16, 16, T_TREE)   # NW corner — upper woods
	_fill_ellipse(t,  55,  18, 12, 10, T_TREE)   # North edge — top rough corridor
	_fill_ellipse(t, 140,  20, 10, 16, T_TREE)   # NE corner
	_fill_ellipse(t, 140, 110, 10, 16, T_TREE)   # SE corner
	_fill_ellipse(t,  20, 135, 16, 12, T_TREE)   # SW corner
	_fill_ellipse(t,  80, 130, 18, 16, T_TREE)   # South-center woods
	_fill_ellipse(t,  35,  42, 12, 14, T_TREE)   # Left-center inter-fairway cluster
	_fill_ellipse(t,  60,  62,  9,  9, T_TREE)   # Central cluster near mid-pond
	_fill_ellipse(t, 115,  75, 14, 12, T_TREE)   # Right-center between H12/H13
	_fill_ellipse(t, 100,  45, 10,  8, T_TREE)   # Upper-right cluster near orchard

	# ── 2. Open clearing — lower-left (holes 1 / 2 / 18 staging area) ────────
	_fill_ellipse(t, 22, 104, 20, 17, T_GRASS)
	# Blend edges into rough
	_fill_ellipse(t, 22, 104, 23, 20, T_ROUGH)
	# Restore inner grass over the rough ring
	_fill_ellipse(t, 22, 104, 20, 17, T_GRASS)

	# Small secondary clearing near H6/H7 junction
	_fill_ellipse(t, 44, 85, 7, 5, T_GRASS)

	# ── 3. Orchard area — upper-right (ROUGH with periodic tree rows) ─────────
	_fill_rect(t, 90, 32, 44, 44, T_ROUGH)
	# Re-plant periodic tree rows to simulate orchard
	for row in range(33, 75, 4):
		for col in range(91, 133):
			t[Vector2i(col, row)] = T_TREE

	# ── 4. Main upper pond (Southwick Pond) ───────────────────────────────────
	# Left lobe
	_fill_ellipse(t, 60, 36, 12, 11, T_WATER)
	# Right lobe
	_fill_ellipse(t, 80, 42, 14, 12, T_WATER)
	# Bridge / neck connecting the two lobes
	_fill_rect(t, 60, 30, 22, 18, T_WATER)
	# Irregular south shore
	_fill_ellipse(t, 68, 50, 10, 5, T_WATER)

	# ── 5. Lower / middle pond ────────────────────────────────────────────────
	_fill_ellipse(t, 57, 73, 10, 8, T_WATER)

	# ── 6. Bottom-right lake ──────────────────────────────────────────────────
	_fill_ellipse(t, 108, 119, 12, 10, T_WATER)

	# ── 7. Sand traps (near pond edges and key hazard zones) ──────────────────
	_sand_ring(t, 60, 36, 12, 14, T_WATER)    # upper-left pond shore
	_sand_ring(t, 80, 42, 14, 16, T_WATER)    # upper-right pond shore
	_sand_ring(t, 57, 73, 10, 12, T_WATER)    # lower pond shore
	# A few isolated traps near key landing zones
	_fill_ellipse(t, 86, 66, 3, 2, T_SAND)    # H8 approach
	_fill_ellipse(t, 75, 52, 2, 2, T_SAND)    # H9 approach
	_fill_ellipse(t, 105, 63, 2, 2, T_SAND)   # H10 approach

	# ── 8. Road — Walbridge Rd (left edge, runs N-S) ──────────────────────────
	for z in range(0, 145):
		for x in range(6, 11):
			if t.get(Vector2i(x, z), T_TREE) != T_WATER:
				t[Vector2i(x, z)] = T_PATH
	# Entry driveway / parking area at bottom of road
	_fill_rect(t, 3, 108, 12, 6, T_PATH)

	# ── 9. Fairway corridors ──────────────────────────────────────────────────
	# Each call paints ROUGH (width+2) then FAIRWAY (width) along the line.
	# Holes follow the real course routing (tee → basket, no tee/basket tiles placed).

	# H1  — short opener, left side near road, slight dogleg right
	_paint_fairway(t,  8, 101,  22,  96, 3)

	# H2  — medium, from clearing going right through the open area
	_paint_fairway(t, 23,  96,  43,  92, 3)

	# H3  — goes up and left from the clearing, into trees
	_paint_fairway(t,  9,  84,  22,  97, 3)

	# H4  — longer hole, upper-left going upper-right toward pond
	_paint_fairway(t, 13,  72,  32,  57, 4)

	# H5  — left of pond, going right toward pond edge
	_paint_fairway(t, 40,  73,  55,  67, 3)

	# H6  — from left-center going right, slight uphill feel
	_paint_fairway(t, 23,  82,  40,  76, 3)

	# H7  — central hub hole, going slightly right
	_paint_fairway(t, 57,  88,  72,  83, 3)

	# H8  — major hole, from central hub toward south shore of upper pond
	_paint_fairway(t, 71,  83,  88,  67, 4)
	# H8 second half curves slightly right
	_paint_fairway(t, 88,  67,  91,  58, 3)

	# H9  — long uphill along west side of upper pond
	_paint_fairway(t, 72,  57,  68,  36, 3)
	_paint_fairway(t, 68,  36,  75,  22, 3)   # top section

	# H10 — upper-right of upper pond, shorter
	_paint_fairway(t, 94,  62, 105,  64, 3)

	# H11 — signature long hole into orchard, slight fade right
	_paint_fairway(t,112,  54, 130,  47, 4)
	_paint_fairway(t,130,  47, 140,  43, 3)

	# H12 — right side, goes from far-right downward with slight curve
	_paint_fairway(t,140,  44, 143,  60, 3)
	_paint_fairway(t,143,  60, 140,  78, 3)

	# H13 — from right side, long shot back toward center
	_paint_fairway(t,120,  83, 102,  91, 3)

	# H14 — upper-center, short-ish hole near upper pond
	_paint_fairway(t, 96,  73,  82,  70, 3)

	# H15 — lower-center, going slightly left
	_paint_fairway(t,102,  93,  85,  93, 3)

	# H16 — lower-center, shorter
	_paint_fairway(t, 78, 100,  68,  95, 3)

	# H17 — lower area, downhill feel
	_paint_fairway(t, 71, 118,  65, 103, 3)

	# H18 — lower-left, finishing hole back toward clearing
	_paint_fairway(t, 42, 118,  36, 104, 3)
	_paint_fairway(t, 36, 104,  23, 105, 3)   # approaches clearing

	# ── 10. Walking paths between holes ───────────────────────────────────────
	# These simulate the foot trails players walk from basket to next tee.
	_paint_path_strip(t,  22,  96,  23,  82, 1)   # H2 basket → H3 tee
	_paint_path_strip(t,   9,  84,  13,  72, 1)   # H3 basket → H4 tee
	_paint_path_strip(t,  32,  57,  40,  73, 1)   # H4 basket → H5 tee
	_paint_path_strip(t,  40,  73,  23,  82, 1)   # H5 basket → H6 tee
	_paint_path_strip(t,  40,  76,  57,  88, 1)   # H6 basket → H7 tee
	_paint_path_strip(t,  72,  83,  71,  83, 1)   # H7 basket → H8 tee (same spot)
	_paint_path_strip(t,  91,  58,  72,  57, 1)   # H8 basket → H9 tee
	_paint_path_strip(t,  75,  22,  94,  62, 1)   # H9 basket → H10 tee (long walk)
	_paint_path_strip(t, 105,  64, 112,  54, 1)   # H10 basket → H11 tee
	_paint_path_strip(t, 140,  43, 140,  44, 1)   # H11 basket → H12 tee
	_paint_path_strip(t, 140,  78, 120,  83, 1)   # H12 basket → H13 tee
	_paint_path_strip(t, 102,  91,  96,  73, 1)   # H13 basket → H14 tee
	_paint_path_strip(t,  82,  70, 102,  93, 1)   # H14 basket → H15 tee
	_paint_path_strip(t,  85,  93,  78, 100, 1)   # H15 basket → H16 tee
	_paint_path_strip(t,  68,  95,  71, 118, 1)   # H16 basket → H17 tee
	_paint_path_strip(t,  65, 103,  42, 118, 1)   # H17 basket → H18 tee
	_paint_path_strip(t,  23, 105,   8, 101, 1)   # H18 basket → H1 tee (finish loop)

	# Entry path from road to first tee area
	_paint_path_strip(t,  10, 104,   8, 101, 1)

	return t

# ── Painter helpers ───────────────────────────────────────────────────────────

## Paint a fairway corridor: rough band first (width+2), then fairway (width).
## Skips WATER cells.
static func _paint_fairway(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width + 2, T_ROUGH, [T_WATER])
	_paint_line_width(t, x1, z1, x2, z2, width,     T_FAIRWAY, [T_WATER])

## Paint a narrow path strip (walking trail between holes).
static func _paint_path_strip(t: Dictionary, x1: int, z1: int, x2: int, z2: int, width: int) -> void:
	_paint_line_width(t, x1, z1, x2, z2, width, T_PATH, [T_WATER, T_FAIRWAY])

## Bresenham line walk, painting a square brush of radius (width//2) at each step.
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
				var cell := Vector2i(bx, bz)
				if bx >= 0 and bx < COLS and bz >= 0 and bz < ROWS:
					var existing: int = t.get(cell, T_TREE) as int
					if not (existing in skip_tiles):
						t[cell] = tile
		if cx == x2 and cz == z2:
			break
		var e2 := err * 2
		if e2 > -dz:
			err -= dz; cx += sx
		if e2 < dx:
			err += dx; cz += sz

## Fill a filled ellipse (semi-axes rx, rz centered at cx, cz).
static func _fill_ellipse(t: Dictionary, cx: int, cz: int, rx: int, rz: int, tile: int) -> void:
	for x in range(cx - rx, cx + rx + 1):
		for z in range(cz - rz, cz + rz + 1):
			var dx := float(x - cx) / float(rx)
			var dz := float(z - cz) / float(rz)
			if dx * dx + dz * dz <= 1.0:
				if x >= 0 and x < COLS and z >= 0 and z < ROWS:
					t[Vector2i(x, z)] = tile

## Fill a rectangle.
static func _fill_rect(t: Dictionary, x: int, z: int, w: int, h: int, tile: int) -> void:
	for col in range(x, x + w):
		for row in range(z, z + h):
			if col >= 0 and col < COLS and row >= 0 and row < ROWS:
				t[Vector2i(col, row)] = tile

## Fill a filled circle.
static func _fill_circle(t: Dictionary, cx: int, cz: int, r: int, tile: int) -> void:
	_fill_ellipse(t, cx, cz, r, r, tile)

## Paint a sand ring just outside a water body (only over TREE/ROUGH cells).
static func _sand_ring(t: Dictionary, cx: int, cz: int, inner_r: int, outer_r: int, water_tile: int) -> void:
	for x in range(cx - outer_r, cx + outer_r + 1):
		for z in range(cz - outer_r, cz + outer_r + 1):
			if x < 0 or x >= COLS or z < 0 or z >= ROWS:
				continue
			var dx := float(x - cx) / float(outer_r)
			var dz := float(z - cz) / float(outer_r)
			var dist_sq := dx * dx + dz * dz
			if dist_sq > 1.0:
				continue
			var dx_i := float(x - cx) / float(inner_r)
			var dz_i := float(z - cz) / float(inner_r)
			if dx_i * dx_i + dz_i * dz_i < 1.0:
				continue  # inside water — skip
			var existing: int = t.get(Vector2i(x, z), T_TREE) as int
			if existing != water_tile and existing != T_FAIRWAY and existing != T_PATH:
				t[Vector2i(x, z)] = T_SAND
