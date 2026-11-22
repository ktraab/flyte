## Away-round layouts for the World Circuit courses.
##
## Each course's terrain preset (core/data/*Preset.gd) paints fairways that follow
## the real routing but places no tees or baskets. These are the tee → basket
## endpoints of those painted fairways (front nine), so an away round plays the
## holes the preset already draws. Used by GameManager.start_away_round().
extends RefCounted

const HOLES_PER_ROUND := 9

const LAYOUTS: Dictionary = {
	"maple_ridge": [   # Maple Hill — Leicester, MA
		[Vector2i(8, 101),  Vector2i(22, 96)],
		[Vector2i(23, 94),  Vector2i(43, 92)],
		[Vector2i(22, 98),  Vector2i(9, 84)],
		[Vector2i(13, 72),  Vector2i(32, 57)],
		[Vector2i(40, 73),  Vector2i(55, 67)],
		[Vector2i(23, 82),  Vector2i(40, 76)],
		[Vector2i(57, 88),  Vector2i(72, 85)],
		[Vector2i(71, 81),  Vector2i(91, 58)],
		[Vector2i(72, 57),  Vector2i(75, 22)],
	],
	"winthrop_gold": [
		[Vector2i(15, 135), Vector2i(30, 120)],
		[Vector2i(32, 118), Vector2i(55, 110)],
		[Vector2i(60, 108), Vector2i(90, 112)],
		[Vector2i(92, 110), Vector2i(65, 90)],
		[Vector2i(65, 88),  Vector2i(58, 78)],
		[Vector2i(56, 75),  Vector2i(45, 60)],
		[Vector2i(42, 58),  Vector2i(38, 38)],
		[Vector2i(40, 36),  Vector2i(68, 28)],
		[Vector2i(72, 26),  Vector2i(110, 30)],
	],
	"idlewild": [
		[Vector2i(20, 115), Vector2i(38, 105)],
		[Vector2i(40, 103), Vector2i(60, 95)],
		[Vector2i(62, 93),  Vector2i(55, 80)],
		[Vector2i(56, 78),  Vector2i(72, 70)],
		[Vector2i(74, 72),  Vector2i(84, 68)],
		[Vector2i(80, 66),  Vector2i(74, 58)],
		[Vector2i(75, 76),  Vector2i(95, 78)],
		[Vector2i(97, 76),  Vector2i(112, 65)],
		[Vector2i(114, 63), Vector2i(120, 48)],
	],
	"disc_side_of_heaven": [
		[Vector2i(25, 122), Vector2i(45, 110)],
		[Vector2i(47, 108), Vector2i(65, 98)],
		[Vector2i(67, 96),  Vector2i(58, 108)],
		[Vector2i(57, 112), Vector2i(42, 100)],
		[Vector2i(40, 98),  Vector2i(52, 78)],
		[Vector2i(54, 76),  Vector2i(72, 68)],
		[Vector2i(74, 66),  Vector2i(92, 42)],
		[Vector2i(93, 40),  Vector2i(108, 38)],
		[Vector2i(110, 36), Vector2i(125, 50)],
	],
	"krokhol": [
		[Vector2i(18, 124), Vector2i(30, 112)],
		[Vector2i(32, 110), Vector2i(48, 105)],
		[Vector2i(50, 103), Vector2i(68, 95)],
		[Vector2i(70, 93),  Vector2i(62, 75)],
		[Vector2i(60, 73),  Vector2i(52, 60)],
		[Vector2i(50, 58),  Vector2i(56, 42)],
		[Vector2i(55, 40),  Vector2i(75, 28)],
		[Vector2i(78, 26),  Vector2i(100, 30)],
		[Vector2i(102, 32), Vector2i(112, 48)],
	],
	"ale_white": [
		[Vector2i(20, 135), Vector2i(38, 120)],
		[Vector2i(40, 118), Vector2i(68, 112)],
		[Vector2i(70, 110), Vector2i(88, 100)],
		[Vector2i(90, 98),  Vector2i(108, 88)],
		[Vector2i(110, 86), Vector2i(132, 78)],
		[Vector2i(132, 76), Vector2i(138, 58)],
		[Vector2i(136, 56), Vector2i(118, 42)],
		[Vector2i(116, 40), Vector2i(70, 32)],
		[Vector2i(68, 30),  Vector2i(40, 22)],
	],
}

## [[tee: Vector2i, basket: Vector2i], ...] or [] if the course has no away layout.
static func holes_for(course_id: String) -> Array:
	return LAYOUTS.get(course_id, []) as Array

const _BLOCKED := [3, 5]   # WATER, TREE — never put a tee or basket there
const _SNAP_RADIUS := 8

## Layout adjusted to the actual preset terrain: an end that lands in a pond or
## a tree grove (presets paint water/groves after fairways) moves to the nearest
## open cell, preferring cells toward the other end of the hole. Cells stay unique.
static func resolve(course_id: String, tiles: Dictionary) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	for h in holes_for(course_id):
		var tee: Vector2i = _snap((h as Array)[0], (h as Array)[1], tiles, used)
		used[tee] = true
		var bk: Vector2i = _snap((h as Array)[1], tee, tiles, used)
		used[bk] = true
		out.append([tee, bk])
	return out

static func _open(c: Vector2i, tiles: Dictionary, used: Dictionary) -> bool:
	return c.x >= 1 and c.x < 149 and c.y >= 1 and c.y < 149 \
		and not used.has(c) and not (int(tiles.get(c, 0)) in _BLOCKED)

static func _snap(c: Vector2i, toward: Vector2i, tiles: Dictionary, used: Dictionary) -> Vector2i:
	if _open(c, tiles, used):
		return c
	var best := c
	var best_score := INF
	for r in range(1, _SNAP_RADIUS + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if not _open(n, tiles, used):
					continue
				# distance from the intended spot, nudged toward the hole's other end
				var sc := Vector2(n - c).length() + 0.25 * Vector2(n - toward).length() / 10.0
				if sc < best_score:
					best_score = sc
					best = n
		if best_score < INF:
			return best
	return c

## Par from straight-line tee→basket distance in metres.
static func par_for_distance(metres: float) -> int:
	return preload("res://core/simulation/HoleScore.gd").par_for_length(metres)
