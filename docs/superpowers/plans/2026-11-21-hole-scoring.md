# Hole & Course Scoring Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the length-gated star formula with one design-for-par scorer (`HoleScore`) used by star ratings, analytics and the Architect critique, add a course bonus, auto-suggest par, make certification permanent, and set the 5★ goal at 4.8.

**Architecture:** `core/simulation/HoleScore.gd` is a pure static module. It reads a `GameWorld3D` and returns stars plus a parts breakdown and tips. `GameWorld3D` calls it from the memoised layout cache. `HoleCritique` and `AnalyticsPanel` render its output. `GameManager` remembers certification.

**Tech Stack:** Godot 4.6.2, GDScript. Tests run headless via `tools/run_tests.sh` (HOME-isolated; never run `tests/run_tests.gd` directly).

**Spec:** `docs/superpowers/specs/2026-11-21-hole-scoring-design.md`

**Paths:** all source paths below are relative to `flyte--a-disc-golf-course-builder-and-manager/`. Run commands from that folder.

**Test filter:** `tools/run_tests.sh <word>` runs only tests whose name contains `<word>`. A full run takes about 5 minutes; run it in the background and read the log.

---

## File map

| File | Change |
|---|---|
| `core/simulation/HoleScore.gd` | **Create.** `par_for_length`, `length_score`, `hole_line`, `hole_length_m`, `score`, `course_bonus` |
| `tests/test_hole_score.gd` | **Create.** Unit tests on synthetic worlds |
| `tests/run_tests.gd` | Register `test_hole_score` |
| `scenes/game_world/GameWorld3D.gd` | Layout key, rating, course rating, breakdowns, auto-par; delete old math and `DECOR_HOLE_BONUS` |
| `core/data/AwayLayouts.gd` | `par_for_distance` delegates to `HoleScore.par_for_length` |
| `core/simulation/HoleCritique.gd` | Rebuilt on `HoleScore` (same return shape) |
| `scenes/ui/screens/gameplay/AnalyticsPanel.gd` | Per-hole card shows the new parts and tips; course bonus rows |
| `scenes/ui/screens/Gameplay.gd` | Rating tooltip tip text |
| `autoloads/GoalsSystem.gd` | `five_star` target 4.8 |
| `autoloads/GameManager.gd` | `_certified` memory, saved in course meta |
| `CLAUDE.md`, `DEVLOG.md` | Docs |

---

### Task 1: HoleScore — par and length

**Files:**
- Create: `core/simulation/HoleScore.gd`
- Create: `tests/test_hole_score.gd`
- Modify: `tests/run_tests.gd` (add the suite to `SUITES`)

- [ ] **Step 1: Write the failing test**

Create `tests/test_hole_score.gd`:

```gdscript
## HoleScore: one design-for-par scorer (spec 2026-11-21-hole-scoring-design).
extends "res://tests/TestCase.gd"

const HoleScore = preload("res://core/simulation/HoleScore.gd")

func test_par_for_length_thresholds() -> void:
	check_eq(HoleScore.par_for_length(60.0), 3, "60 m → par 3")
	check_eq(HoleScore.par_for_length(100.0), 3, "100 m → par 3")
	check_eq(HoleScore.par_for_length(101.0), 4, "101 m → par 4")
	check_eq(HoleScore.par_for_length(170.0), 4, "170 m → par 4")
	check_eq(HoleScore.par_for_length(200.0), 5, "200 m → par 5")

func test_length_score_bands() -> void:
	check(is_equal_approx(HoleScore.length_score(70.0, 3), 1.0), "70 m par 3 is ideal")
	check(is_equal_approx(HoleScore.length_score(200.0, 5), 1.0), "200 m par 5 is ideal")
	check(HoleScore.length_score(150.0, 3) < 0.6, "150 m is too long for par 3 (%.2f)" % HoleScore.length_score(150.0, 3))
	check(HoleScore.length_score(30.0, 3) <= 0.4, "under 35 m caps at 0.4")
	check(HoleScore.length_score(400.0, 3) >= 0.2, "never below 0.2")
```

Add `"res://tests/test_hole_score.gd"` to the `SUITES` array in `tests/run_tests.gd`, following the existing entries' format.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_tests.sh par_for_length`
Expected: FAIL. The suite fails to load because `HoleScore.gd` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `core/simulation/HoleScore.gd`:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_tests.sh _length`
Expected: `test_par_for_length_thresholds` and `test_length_score_bands` ok.

- [ ] **Step 5: Commit**

```bash
git add core/simulation/HoleScore.gd tests/test_hole_score.gd tests/run_tests.gd
git commit -m "feat: HoleScore par and length scoring"
```

---

### Task 2: HoleScore — the hole line and the five parts

**Files:**
- Modify: `core/simulation/HoleScore.gd`
- Test: `tests/test_hole_score.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_hole_score.gd`:

```gdscript
# ── Synthetic worlds ──────────────────────────────────────────────────────────

func _world() -> GameWorld3D:
	var w := GameWorld3D.new()
	var t := {}
	for c in 150:
		for r in 150:
			t[Vector2i(c, r)] = 0
	w.set("_tiles", t)
	return w

func _put(w: GameWorld3D, cell: Vector2i, tt: int) -> void:
	(w.get("_tiles") as Dictionary)[cell] = tt

func _hole(w: GameWorld3D, num: int) -> Dictionary:
	for h in w.get_holes_info():
		if int(h["hole_num"]) == num:
			return h
	return {}

## Straight 35-cell (70 m) par 3 along +x at row 50, with full fairway, 2 hazard
## types, framing trees + rough. shape decides straight vs dogleg.
func _built_par3(w: GameWorld3D, dogleg: bool) -> Dictionary:
	var tee := Vector2i(20, 50)
	var bk := Vector2i(55, 50) if not dogleg else Vector2i(45, 65)
	w.call("_place_hole", 1, tee, 1, bk)
	if dogleg:
		(w.get("_hole_waypoints") as Dictionary)[1] = [Vector2i(45, 50)]
	var line: Array = HoleScore.hole_line(_hole(w, 1), w)
	var on_line: Array = []
	for i in line.size() - 1:
		var a: Vector2i = line[i]
		var b: Vector2i = line[i + 1]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for k in range(0, steps + 1):
			on_line.append(Vector2i(roundi(lerpf(a.x, b.x, float(k) / steps)), roundi(lerpf(a.y, b.y, float(k) / steps))))
	for c in on_line:                                          # fairway on the line first…
		if int((w.get("_tiles") as Dictionary)[c]) == 0:
			_put(w, c, 1)
	for c in on_line:                                          # …then rough edge + framing trees
		for side in [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]:
			if int((w.get("_tiles") as Dictionary).get(c + side, -1)) == 0:
				_put(w, c + side, 4)
		for side in [Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 0), Vector2i(-4, 0)]:
			if int((w.get("_tiles") as Dictionary).get(c + side, -1)) == 0:
				_put(w, c + side, 5)
	for i in 6:
		_put(w, Vector2i(30 + i, 53), 3)                       # water
	for i in 4:
		_put(w, Vector2i(38 + i, 47), 13)                      # sand
	return _hole(w, 1)

func test_built_par3_with_dogleg_scores_near_five() -> void:
	var w := _world()
	var r: Dictionary = HoleScore.score(_built_par3(w, true), w)
	check(float(r["stars"]) >= 4.9, "fully built dogleg par 3 ≥ 4.9★ (got %.2f, parts %s)" % [r["stars"], r["parts"]])
	w.free()

func test_straight_hole_caps_at_four_and_a_half() -> void:
	var w := _world()
	var r: Dictionary = HoleScore.score(_built_par3(w, false), w)
	check(absf(float((r["parts"] as Dictionary)["shape"]) - 0.5) < 0.001, "straight hole shape = 0.5")
	check(float(r["stars"]) <= 4.5 + 0.001, "straight hole never above 4.5★ (got %.2f)" % r["stars"])
	check(float(r["stars"]) >= 4.3, "but a well-built straight hole is close to it (got %.2f)" % r["stars"])
	w.free()

func test_one_hazard_type_caps_challenge() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(55, 50))
	for i in 30:
		_put(w, Vector2i(22 + i, 52), 3)                       # lots of water, nothing else
	var r: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float((r["parts"] as Dictionary)["challenge"]) - 0.6) < 0.001, "one hazard type maxes at 0.6")
	w.free()

func test_bare_hole_scores_low_with_tips() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(48, 50))
	var r: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(float(r["stars"]) < 2.0, "bare straight 56 m hole is weak (got %.2f)" % r["stars"])
	check((r["tips"] as Array).size() >= 3, "tips explain what's missing: %s" % str(r["tips"]))
	w.free()

func test_fairness_penalties() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(55, 50))
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_put(w, Vector2i(55, 50) + d, 5)                       # basket boxed on 3 sides
	var boxed: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float(boxed["penalty"]) - 0.5) < 0.001, "boxed-in basket penalised 0.5")
	_put(w, Vector2i(54, 50), 5)                               # now fully walled off
	var walled: Dictionary = HoleScore.score(_hole(w, 1), w)
	check(absf(float(walled["penalty"]) - 1.0) < 0.001, "unreachable basket penalised 1.0 (cap)")
	w.free()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/run_tests.sh scores`
Expected: FAIL with `Invalid call. Nonexistent function 'score'` (or `hole_line`).

- [ ] **Step 3: Implement the line, parts, penalty and tips**

Append to `core/simulation/HoleScore.gd`:

```gdscript
const CORRIDOR := 3.0    # fairway counts within this many cells of the hole line
const ZONE := 5.0        # hazards / trees count within this many cells
const ROUGH_EDGE := 2.0  # rough counts within this many cells

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
	var fairway := 0; var rough := 0; var trees := 0
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
			if t == T_TREE: trees += 1
			elif t == T_WATER: water += 1
			elif t == T_SAND: sand += 1
			if rocks.has(cell): rock += 1
			var oz: int = obz.get(cell, -1)
			if oz == 0 or oz == hole_num: ob += 1

	var parts := {}
	parts["length"] = length_score(metres, par)
	parts["fairway"] = minf(1.0, fairway / (0.6 * L))
	var haz := [minf(water / 6.0, 1.0), minf(sand / 4.0, 1.0), minf(ob / 6.0, 1.0), minf(rock / 4.0, 1.0)]
	haz.sort()
	parts["challenge"] = minf(1.0, 0.6 * float(haz[3]) + 0.4 * float(haz[2]))
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
				if float(haz[3]) == 0.0:
					out.append("Challenge: add hazards near the line — water, sand, OB or rocks")
				else:
					out.append("Challenge: add a second hazard type (water, sand, OB, rocks)")
			"framing":
				out.append("Framing: line the hole with trees and a rough edge")
			"shape":
				out.append("Shape: add a dogleg waypoint or elevation change (straight holes cap at 4.5★)")
	return out
```

Note: `world._tiles`, `_ob_zones`, `_rock_overlays`, `_tile_heights`, `_los_clear` and `_bfs_cells` are members of `GameWorld3D`; GDScript allows a typed reference to access them.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/run_tests.sh hole_score` (or the individual names). Expected: all 7 tests ok.

If `test_built_par3_with_dogleg_scores_near_five` fails, read the printed parts.
- If `fairway` < 1, the test's painted line is too short. The dogleg line is ~35 cells, so it needs ≥ 21 fairway tiles; extend the test, not the weights.
- If `framing` < 1, check the trees count against 0.5 × L and the rough count against 0.25 × L.

- [ ] **Step 5: Commit**

```bash
git add core/simulation/HoleScore.gd tests/test_hole_score.gd
git commit -m "feat: HoleScore hole parts, fairness penalty and tips"
```

---

### Task 3: HoleScore — course bonus

**Files:**
- Modify: `core/simulation/HoleScore.gd`
- Test: `tests/test_hole_score.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func _fake_holes(pars: Array, dists: Array) -> Array:
	var out: Array = []
	for i in pars.size():
		out.append({"hole_num": i + 1, "par": pars[i], "distance": dists[i]})
	return out

func test_course_bonus_variety_and_amenities() -> void:
	var nine_same := _fake_holes([3, 3, 3, 3, 3, 3, 3, 3, 3], [60, 60, 60, 60, 60, 60, 60, 60, 60])
	var none: Dictionary = HoleScore.course_bonus(nine_same, {"restroom": 0, "food_stand": 0}, 0)
	check(is_equal_approx(float(none["total"]), 0.0), "identical holes, no amenities → no bonus")
	var mixed := _fake_holes([3, 4, 5, 3, 4, 3, 3, 4, 5], [60, 130, 200, 70, 140, 80, 55, 150, 210])
	var full: Dictionary = HoleScore.course_bonus(mixed, {"restroom": 3, "food_stand": 1}, 5)
	check(is_equal_approx(float(full["variety"]), 0.15), "3 pars + 40 m spread → +0.15 variety")
	check(is_equal_approx(float(full["amenities"]), 0.15), "restrooms + food + decor → +0.15")
	check(is_equal_approx(float(full["total"]), 0.30), "max bonus 0.30")
	var small := _fake_holes([3, 4, 5], [60, 130, 200])
	check(is_equal_approx(float(HoleScore.course_bonus(small, {"restroom": 1, "food_stand": 1}, 9)["total"]), 0.0), "under 6 holes → no bonus")
	# 4.6★ holes + full bonus reach the 4.8 goal
	check(4.6 + float(full["total"]) >= 4.8, "great course with bonuses reaches the 5★ goal")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_tests.sh course_bonus`
Expected: FAIL, `Nonexistent function 'course_bonus'`.

- [ ] **Step 3: Implement**

Append to `HoleScore.gd`:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tools/run_tests.sh course_bonus` → ok.

- [ ] **Step 5: Commit**

```bash
git add core/simulation/HoleScore.gd tests/test_hole_score.gd
git commit -m "feat: HoleScore course bonus for variety and amenities"
```

---

### Task 4: Wire GameWorld3D to HoleScore

**Files:**
- Modify: `scenes/game_world/GameWorld3D.gd`. Edit these places:
  - the `_layout()` key (~line 455);
  - `_compute_hole_rating` (~line 657);
  - `get_per_hole_breakdown` (~line 700);
  - `_compute_course_rating`;
  - `get_rating_breakdown` (~line 816);
  - `DECOR_HOLE_BONUS` (near `TILE_COSTS`).
- Test: `tests/test_boot.gd` (existing `test_rays_holes_are_rough` must keep passing) plus a new test in `tests/test_hole_score.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_hole_score.gd`:

```gdscript
func test_world_uses_hole_score_and_course_bonus() -> void:
	var w := _world()
	var h := _built_par3(w, true)
	check(is_equal_approx(w.get_hole_rating(h), float(HoleScore.score(h, w)["stars"])), "world rating = HoleScore stars")
	var per: Array = w.get_per_hole_breakdown()
	check(per.size() == 1 and (per[0] as Dictionary).has("parts") and (per[0] as Dictionary).has("tips"), "breakdown carries parts + tips")
	var rb: Dictionary = w.get_rating_breakdown()
	check(rb.has("bonus") and rb.has("variety") and rb.has("amenities"), "rating breakdown reports the course bonus")
	# Editing route waypoints must invalidate the cached rating (layout key).
	var before := w.get_course_rating()
	(w.get("_hole_waypoints") as Dictionary).erase(1)
	check(w.get_course_rating() != before, "waypoint change re-scores (%.2f → %.2f)" % [before, w.get_course_rating()])
	w.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_tests.sh uses_hole_score`
Expected: FAIL. The ratings differ and the breakdown lacks `parts`.

- [ ] **Step 3: Implement**

At the top of `GameWorld3D.gd`, next to the other preloads (`const PropBatch = preload(...)`), add:

```gdscript
const HoleScore = preload("res://core/simulation/HoleScore.gd")
```

Replace the `_layout()` key line:

```gdscript
	var k := hash([_tiles.hash(), _tile_hole_num.hash(), _tile_par.hash(), _tile_heights.hash(),
		_hole_waypoints.hash(), _ob_zones.hash(), _rock_overlays.hash()])
```

Replace the whole body of `_compute_hole_rating(hole_info)` (everything up to the next `func`) with:

```gdscript
func _compute_hole_rating(hole_info: Dictionary) -> float:
	return float(HoleScore.score(hole_info, self)["stars"])
```

Replace the whole `get_per_hole_breakdown()` function with:

```gdscript
## Per-hole design breakdown for the Analytics panel (one entry per hole).
func get_per_hole_breakdown() -> Array:
	var result: Array = []
	for h in get_holes_info():
		var s: Dictionary = HoleScore.score(h, self)
		result.append({
			"hole_num": int(h["hole_num"]),
			"distance": int(s["length_m"]),
			"par":      int(s["par"]),
			"total":    float(s["stars"]),
			"parts":    s["parts"],
			"penalty":  float(s["penalty"]),
			"tips":     s["tips"],
		})
	return result
```

Replace `_compute_course_rating()` with:

```gdscript
func _compute_course_rating() -> float:
	var holes_info := get_holes_info()
	if holes_info.is_empty():
		return 0.0
	var total := 0.0
	for h in holes_info:
		total += get_hole_rating(h)
	var bonus: Dictionary = HoleScore.course_bonus(holes_info, get_facility_counts(), _count_decor_tiles())
	return clampf(total / float(holes_info.size()) + float(bonus["total"]), 0.0, 5.0)
```

In `get_rating_breakdown()`, change both return dictionaries. The empty case becomes:

```gdscript
		return {"hole_count": 0, "avg": 0.0, "below_3": 0, "above_4": 0, "bonus": 0.0, "variety": 0.0, "amenities": 0.0}
```

The final return becomes:

```gdscript
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
```

Delete the `DECOR_HOLE_BONUS` constant and its comment block, then confirm nothing references it:

Run: `grep -rn "DECOR_HOLE_BONUS" scenes core autoloads tests` → no output.

- [ ] **Step 4: Run tests**

Run: `tools/run_tests.sh rays` and `tools/run_tests.sh uses_hole_score`
Expected: both ok.

`test_rays_holes_are_rough` requires the starter course to rate 1.5–2.99.
- If it now fails, print the parts for Ray's 3 holes with a temporary `print(HoleScore.score(h, w))` in the test.
- Then adjust **Ray's course layout** in `_generate_default_course()`, not the approved weights. For example, add or remove his pond, or shorten his fairway strips, until it lands in range.
- Remove the print.

- [ ] **Step 5: Commit**

```bash
git add scenes/game_world/GameWorld3D.gd tests/test_hole_score.gd
git commit -m "feat: star ratings come from HoleScore plus course bonus"
```

---

### Task 5: Auto-suggest par

**Files:**
- Modify: `scenes/game_world/GameWorld3D.gd` (`_paint_at`, new `_auto_par`)
- Modify: `core/data/AwayLayouts.gd` (`par_for_distance`)
- Test: `tests/test_hole_score.gd`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_par_auto_suggested_from_length() -> void:
	var w := _world()
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(90, 50))   # 140 m
	w.call("_auto_par", 1)
	check_eq(int(_hole(w, 1)["par"]), 4, "140 m hole gets par 4")
	w.call("set_hole_par", Vector2i(20, 50), 3)
	check_eq(int(_hole(w, 1)["par"]), 3, "player override sticks")
	_put(w, Vector2i(90, 50), 0)                                      # basket moved further: 180 m
	w.call("_place_hole", 1, Vector2i(20, 50), 1, Vector2i(110, 50))
	w.call("_auto_par", 1)
	check_eq(int(_hole(w, 1)["par"]), 5, "moving the basket re-suggests par")
	w.free()

func test_paint_at_calls_auto_par() -> void:
	var src := (load("res://scenes/game_world/GameWorld3D.gd") as GDScript).source_code
	check(src.contains("_auto_par(_active_hole_num)"), "_paint_at re-suggests par when a tee/basket is placed")
```

The bare test world has no 3D scene, and `_paint_at` updates visuals, so it can't be called there. Its hook line is checked instead.

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_tests.sh par_auto`
Expected: FAIL, with `Nonexistent function '_auto_par'`.

- [ ] **Step 3: Implement**

In `GameWorld3D.gd`, add next to `set_hole_par`:

```gdscript
## New or moved holes get par from their length; the player can still change it
## in the Hole Manager (until the tee/basket moves again).
func _auto_par(hole_num: int) -> void:
	for h in get_holes_info():
		if int(h["hole_num"]) == hole_num:
			_tile_par[h["tee_cell"]] = HoleScore.par_for_length(HoleScore.hole_length_m(h, self))
			return
```

In `_paint_at`, directly after `cell_changed.emit(cell.x, cell.y, _active_tool)`, add:

```gdscript
		if _active_tool == TileType.TEE or _active_tool == TileType.BASKET:
			_auto_par(_active_hole_num)
```

In `core/data/AwayLayouts.gd`, replace the body of `par_for_distance`:

```gdscript
static func par_for_distance(metres: float) -> int:
	return preload("res://core/simulation/HoleScore.gd").par_for_length(metres)
```

- [ ] **Step 4: Run tests**

Run: `tools/run_tests.sh par_auto`, `tools/run_tests.sh auto_par` and `tools/run_tests.sh away` → ok.

- [ ] **Step 5: Commit**

```bash
git add scenes/game_world/GameWorld3D.gd core/data/AwayLayouts.gd tests/test_hole_score.gd
git commit -m "feat: auto-suggest par from hole length"
```

---

### Task 6: Architect critique and Analytics UI on HoleScore

**Files:**
- Modify: `core/simulation/HoleCritique.gd` (replace the body of `critique()`)
- Modify: `scenes/ui/screens/gameplay/AnalyticsPanel.gd` (~lines 56–145)
- Modify: `scenes/ui/screens/Gameplay.gd` (~line 1022 tooltip)
- Test: `tests/test_hole_score.gd`, plus the existing `test_boot::test_course_builder_modules_work` and `test_boot::test_gameplay_panels_build`

- [ ] **Step 1: Write the failing test**

Append:

```gdscript
func test_architect_critique_matches_stars() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()
	var holes: Array = gm().world.get_holes_info()
	check(holes.size() > 0, "home course has holes")
	var h: Dictionary = holes[0]
	var crit: Dictionary = preload("res://core/simulation/HoleCritique.gd").critique(h)
	var stars: float = gm().world.get_hole_rating(h)
	check_eq(int(crit["score"]), roundi(stars * 20.0), "Architect score = stars × 20")
	check((crit["critiques"] as Array).size() >= 5, "one line per part")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tools/run_tests.sh critique_matches`
Expected: FAIL, because the score comes from the old 0–100 math.

- [ ] **Step 3: Implement**

Replace everything inside `static func critique(hole_info: Dictionary) -> Dictionary:` in `core/simulation/HoleCritique.gd` (keep the header comment) with:

```gdscript
static func critique(hole_info: Dictionary) -> Dictionary:
	const HoleScore = preload("res://core/simulation/HoleScore.gd")
	var world := GameManager.world as GameWorld3D
	var s: Dictionary = HoleScore.score(hole_info, world)
	var parts: Dictionary = s["parts"]
	var names := {"length": "Length fits par", "fairway": "Fairway corridor",
		"challenge": "Challenge (hazards)", "framing": "Framing (trees + rough)", "shape": "Shape (dogleg / elevation)"}
	var crits: Array = []
	for k in ["length", "fairway", "challenge", "framing", "shape"]:
		var v: float = parts[k]
		var mark := "[color=green]✓[/color]" if v >= 0.8 else ("[color=yellow]△[/color]" if v >= 0.4 else "[color=red]✗[/color]")
		crits.append("%s %s — %.1f / 1.0" % [mark, names[k], v])
	if float(s["penalty"]) > 0.0:
		crits.append("[color=red]✗[/color] Fairness penalty −%.1f" % float(s["penalty"]))
	for tip in s["tips"]:
		crits.append("[color=yellow]↑[/color] " + str(tip))
	var score := roundi(float(s["stars"]) * 20.0)
	var grade := "F"
	if   score >= 90: grade = "A+"
	elif score >= 80: grade = "A"
	elif score >= 70: grade = "B"
	elif score >= 60: grade = "C"
	elif score >= 50: grade = "D"
	return { score = score, grade = grade, critiques = crits }
```

In `AnalyticsPanel.gd`:
1. Replace the block that reads `dist_s … decor_b` from `hd` and builds `sub_lbl`:

```gdscript
				var parts: Dictionary = hd.get("parts", {}) as Dictionary
				var sub_lbl := Label.new()
				sub_lbl.text = "Par %d · %dm   Len %.1f  Fair %.1f  Chal %.1f  Frame %.1f  Shape %.1f" % [
					int(hd.get("par", 3)), int(hd.get("distance", 0)),
					float(parts.get("length", 0.0)), float(parts.get("fairway", 0.0)), float(parts.get("challenge", 0.0)),
					float(parts.get("framing", 0.0)), float(parts.get("shape", 0.0))]
				sub_lbl.add_theme_font_size_override("font_size", 10)
				sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
				hcv.add_child(sub_lbl)
```

2. Delete the old variable lines `var dist_s … var decor_b`.
3. Replace the `if total < 3.0:` tip block (down to `hcv.add_child(tip_lbl)`) with:

```gdscript
				var tips: Array = hd.get("tips", []) as Array
				if not tips.is_empty():
					var tip_lbl := Label.new()
					tip_lbl.text = "↑ " + str(tips[0])
					tip_lbl.add_theme_font_size_override("font_size", 11)
					tip_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
					tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					hcv.add_child(tip_lbl)
```

4. After the "Holes <3★" row, add the course bonus rows:

```gdscript
		host._analytics_vbox.add_child(UI.make_row("  Course bonus", "+%.2f★ (variety %.2f, amenities %.2f)" % [
			float(rb.get("bonus", 0.0)), float(rb.get("variety", 0.0)), float(rb.get("amenities", 0.0))],
			Color(0.85, 0.85, 0.85)))
```

In `Gameplay.gd` (~line 1022), replace the two tip strings:

```gdscript
	if below3 > 0:
		tip = "↑ %d weak hole%s — see Analytics for per-hole tips" % [below3, "s" if below3 > 1 else ""]
	elif avg_r < 4.0:
		tip = "↑ Mix pars and lengths, and add restrooms, food and decor for a course bonus"
```

- [ ] **Step 4: Run tests**

Run: `tools/run_tests.sh critique_matches`, `tools/run_tests.sh modules_work`, `tools/run_tests.sh panels_build` → all ok, with no SCRIPT ERROR lines.

- [ ] **Step 5: Commit**

```bash
git add core/simulation/HoleCritique.gd scenes/ui/screens/gameplay/AnalyticsPanel.gd scenes/ui/screens/Gameplay.gd tests/test_hole_score.gd
git commit -m "feat: Architect critique and Analytics read HoleScore"
```

---

### Task 7: 5★ goal at 4.8 and permanent certification

**Files:**
- Modify: `autoloads/GoalsSystem.gd:16`
- Modify: `autoloads/GameManager.gd`:
  - `_record_course_stats` (~line 305);
  - `is_course_certified` (~line 321);
  - the course meta save block (~line 379) and load block (~line 409);
  - var declarations (~line 37).
- Test: `tests/test_hole_score.gd`

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func test_five_star_goal_at_four_point_eight() -> void:
	var goals: Node = tree.root.get_node("GoalsSystem")
	for g in goals.call("get_all_goals"):
		if g["id"] == "five_star":
			check(is_equal_approx(float(g["target"]), 4.8), "5★ goal triggers at 4.8")

func test_certification_is_permanent() -> void:
	var stats: Dictionary = gm().get("_course_stats")
	var owned: Array = gm().get("owned_courses")
	owned.append("cert_test")
	stats["cert_test"] = {"holes": 9, "rating": 4.0, "restrooms": 1}
	gm().call("_record_course_stats", "cert_test")
	check(gm().call("is_course_certified", "cert_test"), "meets the bar → certified")
	stats["cert_test"] = {"holes": 9, "rating": 2.0, "restrooms": 1}
	check(gm().call("is_course_certified", "cert_test"), "rating drop doesn't revoke it")
	owned.erase("cert_test")
	stats.erase("cert_test")
	(gm().get("_certified") as Dictionary).erase("cert_test")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/run_tests.sh four_point_eight` and `tools/run_tests.sh permanent`
Expected: FAIL. The target is 5.0, and `_certified` doesn't exist.

- [ ] **Step 3: Implement**

`GoalsSystem.gd` line 16: change `"target": 5.0` to `"target": 4.8`.

`GameManager.gd`. Add the declaration under `var _course_stats`:

```gdscript
var _certified: Dictionary         = {}   # course_id → true once WDGA certified (never revoked)
```

Replace `_record_course_stats` and `is_course_certified` with:

```gdscript
func _record_course_stats(course_id: String) -> void:
	if not world or is_away_round():
		return
	_course_stats[course_id] = get_course_stats(course_id)
	if course_id != "home" and not _certified.has(course_id) and _meets_certification(course_id):
		_certified[course_id] = true
		EventBus.course_certified.emit(course_id)
		EventBus.notification_requested.emit("%s is now WDGA certified!" % course_id.replace("_", " ").capitalize(), "info")

func _meets_certification(course_id: String) -> bool:
	var st := get_course_stats(course_id)
	return (int(st.get("holes", 0)) >= CERT_MIN_HOLES
		and float(st.get("rating", 0.0)) >= CERT_MIN_RATING
		and int(st.get("restrooms", 0)) >= CERT_MIN_RESTROOMS)

## Once earned, certification is remembered (a rescore or later edits can't revoke it).
func is_course_certified(course_id: String) -> bool:
	return _certified.has(course_id) or _meets_certification(course_id)
```

In the meta save block, after `cfg.set_value("courses", "stats", _course_stats)`:

```gdscript
	cfg.set_value("courses", "certified",      _certified)
```

In the meta load block, after the `_course_stats = ...` line:

```gdscript
	_certified = (cfg.get_value("courses", "certified", {}) as Dictionary).duplicate()
```

- [ ] **Step 4: Run tests**

Run: `tools/run_tests.sh four_point_eight`, `tools/run_tests.sh permanent`, `tools/run_tests.sh world_class` → ok.

- [ ] **Step 5: Commit**

```bash
git add autoloads/GoalsSystem.gd autoloads/GameManager.gd tests/test_hole_score.gd
git commit -m "feat: 5-star goal at 4.8, certification is permanent"
```

---

### Task 8: Full verification, bot sanity run, docs

**Files:**
- Modify: `../CLAUDE.md` (GameWorld3D key API / Known Issues), `../DEVLOG.md`

- [ ] **Step 1: Full suite**

Run: `tools/run_tests.sh > /tmp-scratch/full.log 2>&1; grep -E "====|FAIL" /tmp-scratch/full.log`. Use the session scratchpad path for the log.
Expected: `==== N passed, 0 failed ====`, exit 0, and no SCRIPT ERROR.

- [ ] **Step 2: Playthrough bot sanity run**

Re-run the scratchpad `bot.gd` from a fresh HOME, as in previous sessions. Expected:
- chapters 1–5 still reachable;
- no script errors;
- the home rating curve looks sane, with no instant 5★ and no stall below 3★.

Record the chapter days.

- [ ] **Step 3: Docs**

`CLAUDE.md`. Replace the GameWorld3D bullet text about decor (`per-hole bonus = best single piece near the tee via DECOR_HOLE_BONUS …`) with:

```
**BENCH=20, FLOWER_BED=21, SCULPTURE=22** (decorative — count toward happiness and the course amenity bonus; global 20-piece happiness cap)
```

Add under Key systems:

```
**HoleScore** (`core/simulation/HoleScore.gd`) — the only hole-design scorer. `score(hole, world)` → {stars, parts{length,fairway,challenge,framing,shape}, penalty, length_m, par, ideal, tips}. Stars reward design for par (bands par3 45–100 m, par4 100–170, par5 170–240); straight holes cap at 4.5★ (shape 0.5), angled 4.75★, dogleg/elevation 5★. `course_bonus()` adds ≤0.3★ (variety + amenities, 6+ holes). Used by `get_hole_rating`, `get_per_hole_breakdown`, `HoleCritique`. Par auto-suggested from length on tee/basket placement (`_auto_par`). 5★ goal = 4.8. Certification remembered in `GameManager._certified`.
```

`DEVLOG.md`: add a "part 10 — scoring rework" entry at the top of Current State. Include:
- what changed;
- Ray's course rating;
- the new chapter days from the bot run;
- the test count.

- [ ] **Step 4: Commit and push**

```bash
git add ../CLAUDE.md ../DEVLOG.md
git commit -m "docs: HoleScore scoring rework"
git push
```

---

## Self-review notes

- **Spec coverage:**
  - Parts and penalty: Task 2.
  - Course bonus: Task 3.
  - Wiring, layout key and decor removal: Task 4.
  - Auto par and AwayLayouts: Task 5.
  - Critique and UI: Task 6.
  - Goal and certification: Task 7.
  - Balance tests: Tasks 2–4 and 7.
  - Bot sanity: Task 8.
- **Angled-layout rule:** the spec says the angled bonus applies only to holes with no waypoints. The plan computes it from the tee → basket direction regardless, which is slightly more forgiving and gives the same result for the no-waypoint case. Update the spec's Shape row to "tee→basket direction" in Task 8 if you keep this.
- **Names used consistently:** `par_for_length`, `length_score`, `hole_line`, `hole_length_m`, `score`, `course_bonus`, `_auto_par`, `_meets_certification`, `_certified`.
