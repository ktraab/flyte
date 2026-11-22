## Pre-built disc golf hole layouts for the Architect tool.
## Templates defined with tee facing South (+Y forward from tee). CELL_SIZE=2m.
## All distance_m values are Euclidean tee→basket in meters.
class_name HoleTemplates
extends RefCounted

const _GRASS   := 0
const _FAIRWAY := 1
const _ROUGH   := 4
const _TREE    := 5
const _WATER   := 3
const _SAND    := 13

static func get_names() -> Array:
	return [
		"Par 3 — Open Fairway",
		"Par 3 — Wooded Punch",
		"Par 3 — Island Green",
		"Par 4 — Dogleg Left",
		"Par 4 — Dogleg Right",
		"Par 4 — Over the Lake",
		"Par 5 — The Gauntlet",
	]

## Returns {description, par, distance_m, basket_offset: Vector2i, tiles: Array[{offset, type}]}
static func get_info(name: String) -> Dictionary:
	match name:
		"Par 3 — Open Fairway":  return _open_fairway()
		"Par 3 — Wooded Punch":  return _wooded_punch()
		"Par 3 — Island Green":  return _island_green()
		"Par 4 — Dogleg Left":   return _dogleg_left()
		"Par 4 — Dogleg Right":  return _dogleg_right()
		"Par 4 — Over the Lake": return _over_the_lake()
		"Par 5 — The Gauntlet":  return _the_gauntlet()
	return {}

## Rotate a template offset to match tee orientation.
## orientation: 0=N, 1=E, 2=S, 3=W (from _tile_orientations)
static func rotate_offset(off: Vector2i, orientation: int) -> Vector2i:
	match orientation:
		0: return Vector2i(-off.x, -off.y)
		1: return Vector2i(off.y,  -off.x)
		3: return Vector2i(-off.y,  off.x)
	return off

# ── Helpers ───────────────────────────────────────────────────────────────────

## Fill a vertical corridor: cx-half(w)..cx+half(w), rows y_start..y_end.
static func _rect(cx: int, y_start: int, y_end: int, w: int, t: int) -> Array:
	var cells: Array = []
	var half := w / 2
	for y in range(y_start, y_end + 1):
		for dx in range(-half, half + 1):
			cells.append({ offset = Vector2i(cx + dx, y), type = t })
	return cells

## Fill a horizontal corridor: cols x_start..x_end, cy-half(h)..cy+half(h).
static func _rect_h(x_start: int, x_end: int, cy: int, h: int, t: int) -> Array:
	var cells: Array = []
	var half := h / 2
	for x in range(mini(x_start, x_end), maxi(x_start, x_end) + 1):
		for dy in range(-half, half + 1):
			cells.append({ offset = Vector2i(x, cy + dy), type = t })
	return cells

## 1-cell rough border left and right of a vertical corridor.
static func _side_border(cx: int, y_start: int, y_end: int, w: int, t: int) -> Array:
	var cells: Array = []
	var edge := w / 2 + 1
	for y in range(y_start, y_end + 1):
		cells.append({ offset = Vector2i(cx - edge, y), type = t })
		cells.append({ offset = Vector2i(cx + edge, y), type = t })
	return cells

## 1-cell rough border above and below a horizontal corridor.
static func _side_border_h(x_start: int, x_end: int, cy: int, h: int, t: int) -> Array:
	var cells: Array = []
	var edge := h / 2 + 1
	for x in range(mini(x_start, x_end), maxi(x_start, x_end) + 1):
		cells.append({ offset = Vector2i(x, cy - edge), type = t })
		cells.append({ offset = Vector2i(x, cy + edge), type = t })
	return cells

# ── Template definitions ──────────────────────────────────────────────────────

static func _open_fairway() -> Dictionary:
	# Straight 38 cells south → 76m. Wide fairway, easy read.
	var tiles: Array = []
	tiles.append_array(_rect(0, 1, 38, 5, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 38, 5, _ROUGH))
	for y in range(1, 39):
		tiles.append({ offset = Vector2i(-4, y), type = _ROUGH })
		tiles.append({ offset = Vector2i(4, y),  type = _ROUGH })
	return {
		description  = "Wide open straightaway. Great learning hole or opener.",
		par          = 3,
		distance_m   = 76,
		basket_offset = Vector2i(0, 38),
		tiles        = tiles,
	}

static func _wooded_punch() -> Dictionary:
	# Straight 32 cells south → 64m. Tight tree corridor demands accuracy.
	var tiles: Array = []
	tiles.append_array(_rect(0, 1, 32, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 32, 3, _ROUGH))
	for y in range(2, 33, 2):
		tiles.append({ offset = Vector2i(-3, y),     type = _TREE })
		tiles.append({ offset = Vector2i(3, y),      type = _TREE })
		tiles.append({ offset = Vector2i(-4, y),     type = _TREE })
		tiles.append({ offset = Vector2i(4, y),      type = _TREE })
		tiles.append({ offset = Vector2i(-3, y + 1), type = _TREE })
		tiles.append({ offset = Vector2i(3, y + 1),  type = _TREE })
	return {
		description  = "Dense trees frame a tight corridor. Accuracy over power.",
		par          = 3,
		distance_m   = 64,
		basket_offset = Vector2i(0, 32),
		tiles        = tiles,
	}

static func _island_green() -> Dictionary:
	# Narrow approach, water gap, island → basket at (0,36) = 72m.
	var tiles: Array = []
	tiles.append_array(_rect(0, 1, 17, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 17, 3, _ROUGH))
	for x in range(-5, 6):
		for y in range(18, 28):
			tiles.append({ offset = Vector2i(x, y), type = _WATER })
	tiles.append_array(_rect(0, 28, 36, 3, _FAIRWAY))
	return {
		description  = "Precision carry over water. Miss = penalty stroke.",
		par          = 3,
		distance_m   = 72,
		basket_offset = Vector2i(0, 36),
		tiles        = tiles,
	}

static func _dogleg_left() -> Dictionary:
	# South 32, west 30 → basket (-30, 32). dist = √(900+1024)×2 ≈ 88m.
	var tiles: Array = []
	# South arm
	tiles.append_array(_rect(0, 1, 34, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 31, 3, _ROUGH))
	# West arm from x=-1 to x=-30 at y=32
	tiles.append_array(_rect_h(-1, -30, 32, 3, _FAIRWAY))
	tiles.append_array(_side_border_h(-1, -30, 32, 3, _ROUGH))
	# Inside corner tree to prevent cutting the bend
	tiles.append({ offset = Vector2i(2, 31), type = _TREE })
	tiles.append({ offset = Vector2i(2, 32), type = _TREE })
	tiles.append({ offset = Vector2i(2, 33), type = _TREE })
	# Sand at corner landing zone (driver target off south run)
	tiles.append({ offset = Vector2i(-2, 32), type = _SAND })
	tiles.append({ offset = Vector2i(-3, 32), type = _SAND })
	tiles.append({ offset = Vector2i(-2, 31), type = _SAND })
	return {
		description  = "Classic left bend, ~88m. Shape a hyzer for the approach.",
		par          = 4,
		distance_m   = 88,
		basket_offset = Vector2i(-30, 32),
		tiles        = tiles,
	}

static func _dogleg_right() -> Dictionary:
	# Mirror of dogleg_left → basket (30, 32).
	var tiles: Array = []
	tiles.append_array(_rect(0, 1, 34, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 31, 3, _ROUGH))
	tiles.append_array(_rect_h(1, 30, 32, 3, _FAIRWAY))
	tiles.append_array(_side_border_h(1, 30, 32, 3, _ROUGH))
	tiles.append({ offset = Vector2i(-2, 31), type = _TREE })
	tiles.append({ offset = Vector2i(-2, 32), type = _TREE })
	tiles.append({ offset = Vector2i(-2, 33), type = _TREE })
	tiles.append({ offset = Vector2i(2, 32),  type = _SAND })
	tiles.append({ offset = Vector2i(3, 32),  type = _SAND })
	tiles.append({ offset = Vector2i(2, 31),  type = _SAND })
	return {
		description  = "Classic right bend, ~88m. Anhyzer or roller rewarded.",
		par          = 4,
		distance_m   = 88,
		basket_offset = Vector2i(30, 32),
		tiles        = tiles,
	}

static func _over_the_lake() -> Dictionary:
	# Approach, water carry, wide landing zone → basket at (0,50) = 100m.
	var tiles: Array = []
	tiles.append_array(_rect(0, 1, 20, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 20, 3, _ROUGH))
	for x in range(-5, 6):
		for y in range(21, 31):
			tiles.append({ offset = Vector2i(x, y), type = _WATER })
	tiles.append_array(_rect(0, 31, 50, 5, _FAIRWAY))
	tiles.append_array(_side_border(0, 31, 50, 5, _ROUGH))
	return {
		description  = "Long carry over a lake, ~100m. Club selection is everything.",
		par          = 4,
		distance_m   = 100,
		basket_offset = Vector2i(0, 50),
		tiles        = tiles,
	}

static func _the_gauntlet() -> Dictionary:
	# Long Par 5: open start, tight wooded middle, open finish → basket at (0,58) = 116m.
	var tiles: Array = []
	# Open tee shot: 5w × rows 1-24
	tiles.append_array(_rect(0, 1, 24, 5, _FAIRWAY))
	tiles.append_array(_side_border(0, 1, 24, 5, _ROUGH))
	# Sand bunker on left side at mid-range driver landing
	tiles.append({ offset = Vector2i(-3, 22), type = _SAND })
	tiles.append({ offset = Vector2i(-4, 22), type = _SAND })
	tiles.append({ offset = Vector2i(-3, 23), type = _SAND })
	# Tight wooded neck: 3w × rows 25-42
	tiles.append_array(_rect(0, 25, 42, 3, _FAIRWAY))
	tiles.append_array(_side_border(0, 25, 42, 3, _ROUGH))
	for y in range(25, 43, 2):
		tiles.append({ offset = Vector2i(-3, y),     type = _TREE })
		tiles.append({ offset = Vector2i(3, y),      type = _TREE })
		tiles.append({ offset = Vector2i(-4, y + 1), type = _TREE })
		tiles.append({ offset = Vector2i(4, y + 1),  type = _TREE })
	# Sand bunker on right side in wooded section
	tiles.append({ offset = Vector2i(2, 36), type = _SAND })
	tiles.append({ offset = Vector2i(3, 36), type = _SAND })
	# Open finish: 5w × rows 43-58
	tiles.append_array(_rect(0, 43, 58, 5, _FAIRWAY))
	tiles.append_array(_side_border(0, 43, 58, 5, _ROUGH))
	return {
		description  = "Epic ~116m Par 5. Open tee, tight wooded neck, open finish.",
		par          = 5,
		distance_m   = 116,
		basket_offset = Vector2i(0, 58),
		tiles        = tiles,
	}
