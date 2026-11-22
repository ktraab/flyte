## One scorer for hole design: star ratings, the Analytics per-hole breakdown and
## the Hole Architect critique all read this. Pure — reads the world, changes
## nothing. Spec: docs/superpowers/specs/2026-11-21-hole-scoring-design.md
extends RefCounted

## Ideal length bands (metres) per par.
const PAR_BANDS := {3: [45.0, 100.0], 4: [100.0, 170.0], 5: [170.0, 240.0]}

static func par_for_length(metres: float) -> int:
	if metres <= 100.0:
		return 3
	if metres <= 170.0:
		return 4
	return 5

## 1.0 inside the par's band, falling off outside it (≥ 0.2); < 35 m caps at 0.4.
static func length_score(metres: float, par: int) -> float:
	var band: Array = PAR_BANDS[clampi(par, 3, 5)]
	var lo: float = band[0]
	var hi: float = band[1]
	var s := 1.0
	if metres < lo:
		s = maxf(0.2, 1.0 - 1.5 * (lo - metres) / lo)
	elif metres > hi:
		s = maxf(0.2, 1.0 - 1.5 * (metres - hi) / hi)
	if metres < 35.0:
		s = minf(s, 0.4)
	return s

const CORRIDOR := 3.0    # fairway counts within this many cells of the hole line
const ZONE := 5.0        # hazards / trees count within this many cells
const ROUGH_EDGE := 2.0  # rough counts within this many cells
const WOODS_REACH := 2.0 # trees this close to the line are in play (hazard), further out they frame

enum { T_GRASS = 0, T_FAIRWAY = 1, T_WATER = 3, T_ROUGH = 4, T_TREE = 5, T_SAND = 13 }

## Tee → route waypoints → basket, in cells.
static func hole_line(hole: Dictionary, world: GameWorld3D) -> Array:
	var pts: Array = [hole["tee_cell"]]
	for wp in world.get_route_waypoints(int(hole["hole_num"])):
		pts.append(wp)
	pts.append(hole["basket_cell"])
	return pts

static func _line_len(pts: Array) -> float:
	var n := 0.0
	for i in pts.size() - 1:
		n += Vector2(pts[i]).distance_to(Vector2(pts[i + 1]))
	return n

static func hole_length_m(hole: Dictionary, world: GameWorld3D) -> float:
	return _line_len(hole_line(hole, world)) * GameWorld3D.CELL_SIZE

static func _dist_to_line(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a := Vector2(pts[i])
		var b := Vector2(pts[i + 1])
		var ab := b - a
		var t := 0.0 if ab.length_squared() == 0.0 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

## Full breakdown for one hole. See the spec for the rules.
static func score(hole: Dictionary, world: GameWorld3D) -> Dictionary:
	var pts := hole_line(hole, world)
	var tee: Vector2i = hole["tee_cell"]
	var bk: Vector2i = hole["basket_cell"]
	var hole_num := int(hole["hole_num"])
	var par := int(hole.get("par", 3))
	var L := maxf(_line_len(pts), 1.0)
	var metres := L * GameWorld3D.CELL_SIZE
	var tiles: Dictionary = world._tiles
	var obz: Dictionary = world._ob_zones
	var rocks: Dictionary = world._rock_overlays

	var lo := Vector2i(GameWorld3D.GRID_COLS, GameWorld3D.GRID_ROWS)
	var hi := Vector2i(-1, -1)
	for p in pts:
		var c: Vector2i = p
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var pad := int(ZONE)
	var fairway := 0; var rough := 0; var trees := 0; var woods := 0
	var water := 0; var sand := 0; var ob := 0; var rock := 0
	for x in range(maxi(0, lo.x - pad), mini(GameWorld3D.GRID_COLS - 1, hi.x + pad) + 1):
		for y in range(maxi(0, lo.y - pad), mini(GameWorld3D.GRID_ROWS - 1, hi.y + pad) + 1):
			var cell := Vector2i(x, y)
			if cell == tee or cell == bk:
				continue
			var d := _dist_to_line(Vector2(cell), pts)
			if d > ZONE:
				continue
			var t: int = tiles.get(cell, T_GRASS)
			if d <= CORRIDOR and t == T_FAIRWAY: fairway += 1
			if d <= ROUGH_EDGE and t == T_ROUGH: rough += 1
			if t == T_TREE:
				if d <= WOODS_REACH: woods += 1
				else: trees += 1
			elif t == T_WATER: water += 1
			elif t == T_SAND: sand += 1
			if rocks.has(cell): rock += 1
			var oz: int = obz.get(cell, -1)
			if oz == 0 or oz == hole_num: ob += 1

	var parts := {}
	parts["length"] = length_score(metres, par)
	parts["fairway"] = minf(1.0, fairway / (0.6 * L))
	var haz := [minf(water / 6.0, 1.0), minf(sand / 4.0, 1.0), minf(ob / 6.0, 1.0), minf(rock / 4.0, 1.0),
		minf(woods / maxf(4.0, 0.15 * L), 1.0)]
	haz.sort()
	parts["challenge"] = minf(1.0, 0.6 * float(haz[4]) + 0.4 * float(haz[3]))
	parts["framing"] = 0.6 * minf(1.0, trees / (0.5 * L)) + 0.4 * minf(1.0, rough / (0.25 * L))
	parts["shape"] = _shape(pts, world)

	var penalty := 0.0
	var boxed := 0
	for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t2: int = tiles.get(bk + dv, T_WATER)          # off-grid counts as blocked
		if t2 == T_TREE or t2 == T_WATER:
			boxed += 1
	if boxed >= 3:
		penalty += 0.5
	if not world._los_clear(tee, bk) and world._bfs_cells(tee, [bk]).is_empty():
		penalty += 1.0
	penalty = minf(penalty, 1.0)

	var total := 0.0
	for k in parts:
		total += float(parts[k])
	var band: Array = PAR_BANDS[clampi(par, 3, 5)]
	return {
		"stars": clampf(total - penalty, 0.0, 5.0),
		"parts": parts,
		"penalty": penalty,
		"length_m": metres,
		"par": par,
		"ideal": band,
		"tips": _tips(parts, penalty, metres, par, band, fairway, L, haz, boxed),
	}

## Max of: dogleg ≥ 25° → 1.0, elevation → 1.0, angled ≥ 20° off-axis → 0.75, else 0.5.
static func _shape(pts: Array, world: GameWorld3D) -> float:
	var s := 0.5
	for i in range(1, pts.size() - 1):
		var d1 := Vector2(pts[i]) - Vector2(pts[i - 1])
		var d2 := Vector2(pts[i + 1]) - Vector2(pts[i])
		if d1.length() > 0.1 and d2.length() > 0.1 and absf(rad_to_deg(d1.angle_to(d2))) >= 25.0:
			return 1.0
	var heights: Dictionary = world._tile_heights
	var h_tee: float = heights.get(pts[0], 0.0)
	var h_bk: float = heights.get(pts[pts.size() - 1], 0.0)
	var h_min := minf(h_tee, h_bk)
	var h_max := maxf(h_tee, h_bk)
	for i in pts.size() - 1:
		var a := Vector2(pts[i]); var b := Vector2(pts[i + 1])
		var steps := maxi(1, int(a.distance_to(b)))
		for k in steps + 1:
			var c := Vector2i(a.lerp(b, float(k) / steps).round())
			var h: float = heights.get(c, 0.0)
			h_min = minf(h_min, h); h_max = maxf(h_max, h)
	if absf(h_tee - h_bk) >= 1.0 or h_max - h_min >= 1.5:
		return 1.0
	var dir := Vector2(pts[pts.size() - 1]) - Vector2(pts[0])
	if dir.length() > 0.1:
		var ang := rad_to_deg(atan2(absf(dir.y), absf(dir.x)))
		if minf(ang, 90.0 - ang) >= 20.0:
			s = 0.75
	return s

static func _tips(parts: Dictionary, penalty: float, metres: float, par: int, band: Array,
		fairway: int, L: float, haz: Array, boxed: int) -> Array:
	var weak: Array = []
	for k in parts:
		if float(parts[k]) < 0.8:
			weak.append(k)
	weak.sort_custom(func(a, b): return float(parts[a]) < float(parts[b]))
	var out: Array = []
	if penalty >= 1.0:
		out.append("Fairness: no walkable route to the basket — clear a path")
	elif boxed >= 3:
		out.append("Fairness: the basket is boxed in — clear one side")
	for k in weak:
		match k:
			"length":
				if metres > float(band[1]):
					out.append("Length: %dm is long for par %d — make it par %d" % [int(metres), par, par_for_length(metres)])
				else:
					out.append("Length: %dm is short for par %d (ideal %d–%d m)" % [int(metres), par, int(band[0]), int(band[1])])
			"fairway":
				out.append("Fairway: paint fairway along the line (%d of %d tiles)" % [fairway, ceili(0.6 * L)])
			"challenge":
				if float(haz[4]) == 0.0:
					out.append("Challenge: add hazards near the line — trees in play, water, sand, OB or rocks")
				else:
					out.append("Challenge: add a second hazard type (trees in play, water, sand, OB, rocks)")
			"framing":
				out.append("Framing: line the hole with trees and a rough edge")
			"shape":
				out.append("Shape: add a dogleg waypoint or elevation change (straight holes cap at 4.5★)")
	return out

## Course-level bonus (6+ holes): variety ≤ 0.15, amenities ≤ 0.15.
static func course_bonus(holes: Array, facility_counts: Dictionary, decor_count: int) -> Dictionary:
	var n := holes.size()
	if n < 6:
		return {"variety": 0.0, "amenities": 0.0, "total": 0.0}
	var pars := {}
	var d_min := INF
	var d_max := -INF
	for h in holes:
		pars[int(h["par"])] = true
		d_min = minf(d_min, float(h["distance"]))
		d_max = maxf(d_max, float(h["distance"]))
	var variety := 0.0
	if pars.size() >= 3:
		variety += 0.10
	elif pars.size() == 2:
		variety += 0.05
	if d_max - d_min >= 40.0:
		variety += 0.05
	var amen := 0.0
	if int(facility_counts.get("restroom", 0)) >= ceili(n / 4.0):
		amen += 0.05
	if int(facility_counts.get("food_stand", 0)) >= 1:
		amen += 0.05
	if decor_count >= ceili(n / 2.0):
		amen += 0.05
	return {"variety": variety, "amenities": amen, "total": variety + amen}
