# Hole & course scoring rework — design

**Date:** 2026-11-21 · **Status:** approved in chat, awaiting spec review

## Problem

- Two scoring systems disagree:
  - **Star rating** (`GameWorld3D._compute_hole_rating`) drives money, happiness, prestige, goals and certification.
  - **Hole Architect critique** (`core/simulation/HoleCritique.gd`) is shown in the builder.
- The star rating is additive and length-gated:
  - 120 m+ is needed for full length points.
  - Par, sand, OB, doglegs and elevation are ignored.
  - A restroom next to every tee is expected.
- The 5★ goal needs every hole at exactly 5.0, which in practice means 18 holes of 120 m+ with every feature. The playthrough bot plateaued at 4.36★.
- The star math is duplicated in `get_per_hole_breakdown()`, so it can drift.

## Decisions (from the user)

1. Hole stars reward **good design for the hole's par**: a great 70 m par 3 can be 5★. There is **one scorer**, used everywhere.
2. Amenities count at **course level only**, not per hole.
3. Course ★ = **average hole ★ + a small course bonus** (variety + amenities, up to +0.3).
4. Par is **auto-suggested from length**, and the player can override it. The rating checks the fit.
5. **Once certified, stays certified.**
6. The 5★ goal triggers at **≥ 4.8**.

## Design

### New module `core/simulation/HoleScore.gd` (pure, static)

`static func score(hole: Dictionary, world: GameWorld3D) -> Dictionary`

It returns:

```gdscript
{ "stars": float,                         # 0–5
  "parts": { "length": f, "fairway": f, "challenge": f, "framing": f, "shape": f },  # each 0–1
  "penalty": f,                           # 0–1, subtracted
  "length_m": f, "par": int, "ideal": [min, max],
  "tips": Array[String] }                 # weakest part first
```

**Hole line.** A polyline from the tee through the hole's route waypoints (`get_route_waypoints`) to the basket, in cells.
- `L` = polyline length in cells.
- `length_m` = L × CELL_SIZE.
- **Corridor** = cells within 3 cells of the line.
- **Zone** = cells within 5 cells of the line.
- Tee and basket cells are excluded from both.

| Part (max 1.0 each) | Rule |
|---|---|
| **Length fits par** | Ideal bands: par 3 = 45–100 m, par 4 = 100–170 m, par 5 = 170–240 m. Inside the band → 1.0. Outside → `1 − 1.5 × (gap / band edge)`, clamped to ≥ 0.2. Under 35 m → capped at 0.4. |
| **Fairway** | `min(1, fairway tiles in corridor / (0.6 × L))` |
| **Challenge** | Per type, within the zone: water `w/6`, sand `s/4`, OB for this hole `o/6`, rocks `r/4`, **woods** = trees within 2 cells of the line `t/max(4, 0.15 × L)` (each capped at 1). `challenge = min(1, 0.6 × best + 0.4 × second best)`. One type maxed = 0.6; two types = 1.0. Woods added 2026-11-21 (user): trees in play are disc golf's main hazard. |
| **Framing** | `0.6 × min(1, trees 3–5 cells from the line / (0.5 × L)) + 0.4 × min(1, rough within 2 cells / (0.25 × L))`. Trees within 2 cells count as woods (challenge) instead. |
| **Shape** | Max of three options. **Dogleg:** a turn of ≥ 25° at any waypoint → 1.0. **Elevation:** a tee-to-basket height difference ≥ 1.0 m, or a height range along the line ≥ 1.5 m → 1.0. **Angled layout:** tee-to-basket direction ≥ 20° off the grid axes → 0.75 (applies with or without waypoints). **Otherwise** (straight along the grid) → 0.5. A perfect straight hole therefore tops out at 4.5★, an angled one at 4.75★, and a dogleg or elevation hole at 5★ (user decision). |
| **Fairness penalty** | No walkable route from tee to basket (`_bfs_cells`) → 1.0. Basket blocked by tree or water on ≥ 3 of its 4 sides → 0.5. The two add up, capped at 1.0. |

`stars = clamp(sum(parts) − penalty, 0, 5)`.

**Tips.** One line per part below 0.8, weakest first. Examples:
- "Length: 150 m is long for par 3 — make it par 4"
- "Challenge: add a second hazard type (sand, water, OB, rocks)"

`static func course_bonus(holes: Array, facility_counts: Dictionary, decor_count: int) -> Dictionary`
- Returns `{ "variety": f, "amenities": f, "total": f }`.
- Applies only to courses with 6+ holes; otherwise all zero.

| Bonus | Rule |
|---|---|
| **Variety** (≤ 0.15) | +0.05 for 2 distinct pars, +0.10 for 3. +0.05 if the longest hole minus the shortest is ≥ 40 m. |
| **Amenities** (≤ 0.15) | +0.05 for restrooms ≥ ceil(holes / 4). +0.05 for food stands ≥ 1. +0.05 for decor pieces ≥ holes / 2. |

### Wiring

- **`GameWorld3D`**
  - `_compute_hole_rating(h)` → `HoleScore.score(h, self).stars`. `get_hole_rating` stays memoised.
  - `_compute_course_rating()` → `clamp(avg + course_bonus.total, 0, 5)`.
  - `get_per_hole_breakdown()` and `get_rating_breakdown()` are built from `HoleScore`, so the duplicated math is removed. Their dictionary keys change, and their UI consumers (AnalyticsPanel, StatsPanel, HoleManagerPanel) are updated to match.
  - `DECOR_HOLE_BONUS` and the per-hole restroom bonus are removed.
- **Layout cache key** also hashes `_hole_waypoints`, `_ob_zones` and `_rock_overlays`, because scores now read them.
- **`HoleCritique.critique()`** keeps its API `{score, grade, critiques}`, derived from `HoleScore`: `score = stars × 20`, with critique lines generated from the parts and tips.
- **Happiness** is unchanged. It still uses the average hole rating, restrooms, food, pro shop and decor.
- **Auto par.** When a hole becomes complete, or its tee or basket moves, par is set from length: ≤ 100 m = 3, ≤ 170 m = 4, otherwise 5. A manual change in the Hole Manager sticks until the tee or basket moves again. `AwayLayouts.par_for_distance` uses the same thresholds (its 90 m becomes 100 m).
- **Goals.** `five_star` target becomes 4.8; its text "Achieve a 5-star course rating" is unchanged.
- **Certification**
  - `GameManager` keeps a `_certified: Dictionary`, saved in course meta.
  - `is_course_certified(id)` returns true if remembered.
  - Otherwise it checks the live stats, and on success it remembers the course and emits `course_certified`.

### Balance targets (asserted by tests)

- Uncle Ray's 3 starter holes: course ★ in 1.5–2.99.
- A fully built 70 m par 3 with a dogleg scores ≥ 4.9. So does a 200 m par 5 with a dogleg.
- The same hole perfectly straight along the grid scores 4.5 (± rounding), never more.
- One hazard type at maximum gives challenge 0.6; two types give 1.0.
- A course of nine 4.6★ holes with all bonuses scores ≥ 4.8 (5★ goal reachable).
- A boxed-in basket and an unreachable basket are penalised.
- A course that was certified stays certified after its rating drops.
- Re-run the playthrough bot as a sanity check on economy and chapter pacing.

## Out of scope

- Changing NPC difficulty, income formulas or happiness weights.
- Any Ch1/Ch2, putting or empire-pool design questions (tracked separately).
