## Flying disc. Spawned by NPCPlayer / PlayTestController, lives under the world.
##
## Flight is a scripted curve (not rigid-body physics: deterministic, cheap, and
## tunable), shaped like a real disc flight:
##   • fast out, slowing toward the end (eased horizontal progress)
##   • climbs, peaks ~40% of the way, then drops more steeply than it rose
##   • RHBH S-curve: high-speed "turn" to the right early, low-speed "fade" left late
##   • banks (hyzer/anhyzer) with the curve, spins about its own axis
##   • wind drifts it sideways; headwind adds turn + lift, tailwind adds fade
##
## What it can hit, checked every frame against the height above the ground:
##   chains  → caught (in_basket = true), drops into the tray
##   basket rim/pole → glances off and drops nearby
##   trees   → knocked away (kick) and drops below the canopy, never inside a tree cell
##   rocks   → bounces off
##   hills   → a disc that meets rising ground lands there
##   water   → splash, penalty, replayed from where it was last over dry ground
## After touchdown it skips (fairway, cart path…), then rolls downhill on slopes.
## Out-of-bounds is judged only where the disc comes to rest, like the real rule:
## OB → +1 and the lie moves to where it was last in bounds. Rough/sand rest → +1.
##
## The curve math is static (flight_point/flight_params) so the aim preview and
## tests can trace exactly the path a throw will take.
extends Node3D

const SPIN_SPEED := 14.0   # rad/s about the disc's own axis

# Mirror GameWorld3D.TileType — avoids a circular class reference
const _TILE_FAIRWAY := 1
const _TILE_PATH    := 2
const _TILE_WATER   := 3
const _TILE_ROUGH   := 4
const _TILE_TREE    := 5
const _TILE_SAND    := 13

# Touchdown skip by tile: [distance_m at a full-length throw, hop height, duration_s]
const _SKIP_DATA := {
	1:  [5.0, 0.45, 0.45],   # fairway — skids and skips
	2:  [9.0, 0.70, 0.55],   # cart path — big skip off the hard surface
	4:  [0.8, 0.10, 0.25],   # rough — grabs the disc
	13: [0.0, 0.00, 0.00],   # sand — stops dead
}
const _SKIP_DEFAULT := [2.0, 0.25, 0.32]   # grass / anything else

# Basket geometry (PropFactory.basket_mesh): tray 0.70–0.98 m, chains up to 1.98 m
const CATCH_RADIUS   := 0.50   # disc centre within this of the pole, at chain height → caught
const GLANCE_RADIUS  := 0.68   # within this (but outside catch) → hits the rim/cage
const CATCH_MIN_H    := 0.72
const CATCH_MAX_H    := 1.98
const CHAIN_AIM_H    := 1.20   # throws aimed at the basket fly into the chains, not the ground

const ROCK_HEIGHT    := 0.9    # rock overlays are low; anything higher clears them
const WATER_SPLASH_H := 0.45   # below this over water → in the drink
const ROLL_MIN_SLOPE := 0.10   # rise/run below this: no roll
const PUTT_WIND_SCALE_ARC := 5.0   # wind drift scales with flight height (putts barely drift)

var hole_num:       int     = 0                      # 0-based, for per-hole OB
var disc_color:     Color   = Color(0.96, 0.96, 0.93)
var basket_pos:     Vector3 = Vector3.INF            # set by the thrower; INF = no catch logic
var aim_compensate: bool    = false                  # aim right of target so the curve ends on it
var in_basket:      bool    = false                  # result: caught by the chains
var _turn:          float   = 0.0                    # metres right at peak (RHBH; negative = forehand)
var _fade:          float   = 0.0                    # metres left at the end

var _p:       Dictionary = {}     # flight params (see flight_params)
var _t:       float      = 0.0
var _landed:  bool       = false
var _last_dry:    Vector3         # last point over playable ground (not water/tree/OB)
var _bank:    float      = 0.0
var _spin:    Node3D     = null
var _trail:   CPUParticles3D = null
var _glow_light: OmniLight3D = null

# Ground-play hop (skip / kick / roll / drop into tray)
var _hopping:  bool     = false
var _hop_from: Vector3
var _hop_to:   Vector3
var _hop_h:    float    = 0.0
var _hop_dur:  float    = 0.3
var _hop_t:    float    = 0.0
var _hop_next: Callable

signal landed(pos: Vector3, penalty: int)

# ── Pure flight math (shared with aim preview + tests) ───────────────────────

## Everything a flight needs, with wind effects applied. `wind` is m/s (x, z).
static func flight_params(from: Vector3, to: Vector3, arc: float, dur: float,
		turn: float, fade: float, wind: Vector2, compensate: bool) -> Dictionary:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dir := flat.normalized() if flat.length_squared() > 0.0001 else Vector3(0, 0, -1)
	# Tailwind (+) / headwind (−) component along the flight.
	var along := wind.dot(Vector2(dir.x, dir.z))
	var t2 := turn * clampf(1.0 - 0.10 * along, 0.5, 1.6)    # headwind flips discs over
	var f2 := fade * clampf(1.0 + 0.08 * along, 0.5, 1.5)    # tailwind makes them fade harder
	var a2 := arc  * clampf(1.0 - 0.04 * along, 0.8, 1.2)    # headwind lifts
	var drift_scale := clampf(a2 / PUTT_WIND_SCALE_ARC, 0.15, 1.0)
	return {
		"from": from, "to": to, "arc": a2, "dur": maxf(dur, 0.05),
		"turn": t2, "fade": f2, "comp": compensate,
		"right": Vector3(-dir.z, 0.0, dir.x),               # RHBH turn direction
		"drift": Vector3(wind.x, 0.0, wind.y) * dur * 0.35 * drift_scale,
	}

## Horizontal progress: quick off the hand, ~0.4× speed by the end.
static func progress(t: float) -> float:
	return t + 0.6 * t * (1.0 - t)

## Height above the from→to line: peaks near t≈0.42, falls faster than it rose.
static func height_curve(t: float) -> float:
	return sin(PI * pow(clampf(t, 0.0, 1.0), 0.8))

## Sideways offset (positive = turn direction): turn early, fade late.
static func lateral(p: Dictionary, t: float) -> float:
	var turn_w := sin(t * PI) * maxf(0.0, 1.0 - t * 1.75)
	var fade_w := pow(maxf(0.0, (t - 0.4) / 0.6), 1.6)
	var l: float = p["turn"] * turn_w - p["fade"] * fade_w
	if p["comp"]:
		l += p["fade"] * progress(t)   # aimed right of the line so the fade finishes on target
	return l

static func flight_point(p: Dictionary, t: float) -> Vector3:
	var s := progress(t)
	var base: Vector3 = (p["from"] as Vector3).lerp(p["to"], s)
	base.y += (p["arc"] as float) * height_curve(t)
	base += (p["right"] as Vector3) * lateral(p, t)
	base += (p["drift"] as Vector3) * t * t
	return base

# ── Launch ───────────────────────────────────────────────────────────────────

## Throws aimed at the basket finish in the chains, not on the ground.
static func aim_point(to: Vector3, basket: Vector3) -> Vector3:
	if basket != Vector3.INF and Vector2(to.x - basket.x, to.z - basket.z).length() < CATCH_RADIUS:
		return Vector3(basket.x, basket.y + CHAIN_AIM_H, basket.z)
	return to

func launch(from: Vector3, to: Vector3, arc: float = 2.8, dur: float = 1.8) -> void:
	var world := GameManager.world as GameWorld3D
	var wind := world.get_wind_vector() if world != null else Vector2.ZERO
	to = aim_point(to, basket_pos)
	_p = flight_params(from, to, arc, dur, _turn, _fade, wind, aim_compensate)
	_last_dry = from
	position  = from
	_build_visuals()
	_orient(0.0)

func _build_visuals() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var disc := CylinderMesh.new()
	disc.top_radius      = 0.15
	disc.bottom_radius   = 0.18
	disc.height          = 0.06
	disc.radial_segments = 18
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = disc_color
	mat.roughness        = 0.25
	mat.emission_enabled = true
	mat.emission         = disc_color * 0.25
	disc.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh        = disc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(mi)
	# Rim stripe so the spin reads
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.30, 0.065, 0.04)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = disc_color.darkened(0.45)
	stripe.surface_set_material(0, smat)
	var smi := MeshInstance3D.new()
	smi.mesh = stripe
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(smi)

	_glow_light = OmniLight3D.new()
	_glow_light.light_color    = disc_color
	_glow_light.light_energy   = 1.6
	_glow_light.omni_range     = 4.5
	_glow_light.shadow_enabled = false
	add_child(_glow_light)

	_trail = CPUParticles3D.new()
	_trail.emitting               = true
	_trail.amount                 = 30
	_trail.lifetime               = 0.45
	_trail.local_coords           = false
	_trail.emission_shape         = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.06
	_trail.spread                 = 25.0
	_trail.gravity                = Vector3(0, -0.4, 0)
	_trail.initial_velocity_min   = 0.1
	_trail.initial_velocity_max   = 0.4
	_trail.scale_amount_min       = 0.04
	_trail.scale_amount_max       = 0.09
	var g := Gradient.new()
	g.set_color(0, disc_color)
	g.set_color(1, Color(disc_color.r, disc_color.g, disc_color.b, 0.0))
	_trail.color_ramp = g
	add_child(_trail)

func pickup() -> void:
	queue_free()

# ── Per-frame ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _spin:
		_spin.rotate_object_local(Vector3.UP, SPIN_SPEED * delta * (0.35 if _hopping else 1.0))
	if _hopping:
		_hop_t = minf(_hop_t + delta / maxf(_hop_dur, 0.01), 1.0)
		var base := _hop_from.lerp(_hop_to, _hop_t)
		position = Vector3(base.x, base.y + _hop_h * sin(_hop_t * PI), base.z)
		if _hop_t >= 1.0:
			_hopping = false
			_hop_next.call()
		return
	if _landed or _p.is_empty():
		return

	_t = minf(_t + delta / (_p["dur"] as float), 1.0)
	var pos := flight_point(_p, _t)
	var world := GameManager.world as GameWorld3D
	if world != null and _t > 0.04 and _check_hits(world, pos):
		return
	position = pos
	_orient(_t)
	if _t >= 1.0:
		_touchdown(pos, _vel_dir(_t), 1.0)

## Every collision rule; returns true if the flight ended this frame.
func _check_hits(world: GameWorld3D, pos: Vector3) -> bool:
	# Basket first: chains catch, rim/pole spits it out. Tested against this
	# frame's whole path segment (fast drives move ~0.5 m per frame), at the
	# point of closest approach to the pole.
	if basket_pos != Vector3.INF:
		var prev := position
		var seg := Vector2(pos.x - prev.x, pos.z - prev.z)
		var rel := Vector2(basket_pos.x - prev.x, basket_pos.z - prev.z)
		var u := clampf(rel.dot(seg) / seg.length_squared(), 0.0, 1.0) if seg.length_squared() > 1e-8 else 1.0
		var at := prev.lerp(pos, u)
		var horiz := Vector2(at.x - basket_pos.x, at.z - basket_pos.z).length()
		var h := at.y - basket_pos.y
		if horiz < CATCH_RADIUS and h > CATCH_MIN_H and h < CATCH_MAX_H:
			position = at
			_caught()
			return true
		# Rim/cage only once the disc has actually passed its closest point
		# (u < 1), otherwise it is still on its way into the chains.
		if horiz < GLANCE_RADIUS and h > 0.0 and h < CATCH_MAX_H + 0.08 and (u < 1.0 or _t >= 1.0):
			_glance(at)
			return true

	var ground := world.get_ground_y(pos)
	var above := pos.y - ground
	var tile := world.get_tile_at(pos)

	if tile == _TILE_TREE and above < world.get_tree_fly_height(pos):
		_tree_hit(world, pos)
		return true
	if world.is_rock_at(pos) and above < ROCK_HEIGHT:
		_kick(world, pos, 1.0, 4.0, 0.55, "rock")
		return true
	if tile == _TILE_WATER:
		if above < WATER_SPLASH_H:
			_splash(world, Vector3(pos.x, ground, pos.z))
			return true
	# Rising ground (hills): the disc meets the slope before its planned landing.
	if above < 0.05 and _t < 0.97:
		_touchdown(Vector3(pos.x, ground, pos.z), _vel_dir(_t), 0.6)
		return true
	if tile != _TILE_TREE and tile != _TILE_WATER and not world.is_ob_at(pos, hole_num):
		_last_dry = pos
	return false

func _vel_dir(t: float) -> Vector3:
	var a := flight_point(_p, maxf(t - 0.02, 0.0))
	var b := flight_point(_p, minf(t + 0.02, 1.0))
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.000001 else Vector3.UP.cross(_p["right"] as Vector3)

## Point along the flight with a bank angle that follows the curve:
## anhyzer (tilted right) while it turns, hyzer (left) as it fades.
func _orient(t: float) -> void:
	var fwd := _vel_dir(t)
	var turn_bank: float = (_p["turn"] as float) * maxf(0.0, 1.0 - t * 1.6)
	var fade_bank: float = (_p["fade"] as float) * pow(maxf(0.0, (t - 0.3) / 0.7), 1.2)
	var target := clampf((turn_bank - fade_bank) * 0.06, -0.65, 0.65)
	_bank = lerpf(_bank, target, 0.2)
	var b := Basis.looking_at(fwd, Vector3.UP)
	b = b.rotated(fwd, _bank)   # positive = right edge down (anhyzer, turning right)
	var nose := (0.12 - 0.3 * t)  # nose slightly up early, down as it drops
	b = b.rotated(b.x, nose)
	basis = b

# ── Hits ─────────────────────────────────────────────────────────────────────

func _caught() -> void:
	_end_flight_fx()
	in_basket = true
	_impact("chains", position)
	var tray := basket_pos + Vector3(0, 0.80, 0)
	_hop(position, tray, 0.05, 0.22, func() -> void:
		_finish(tray, 0))

func _glance(pos: Vector3) -> void:
	_end_flight_fx()
	_impact("rim", pos)
	var away := Vector3(pos.x - basket_pos.x, 0.0, pos.z - basket_pos.z)
	away = away.normalized() if away.length_squared() > 0.0001 else -_vel_dir(_t)
	var world := GameManager.world as GameWorld3D
	var dest := basket_pos + away * _det_range(pos, 0.7, 1.6)
	if world != null:
		dest.y = world.get_ground_y(dest)
	_hop(pos, dest, 0.25, 0.4, func() -> void: _settle(dest))

func _tree_hit(world: GameWorld3D, pos: Vector3) -> void:
	_leaves(pos)
	_kick(world, pos, 0.5, 4.5 * (1.0 - _t * 0.6), 0.35, "tree")

## Deflect: knocked mostly back or sideways, falls to the ground outside any
## tree cell or pond (falls back to the last dry point if it would).
func _kick(world: GameWorld3D, pos: Vector3, min_d: float, max_d: float, hop: float, kind: String) -> void:
	_end_flight_fx()
	_impact(kind, pos)
	var fwd := _vel_dir(_t)
	var ang := _det_range(pos, -1.9, 1.9)            # within ±109° of straight back
	var back := (-fwd).rotated(Vector3.UP, ang)
	var dest := pos + back * _det_range(pos + Vector3(1, 0, 1), min_d, maxf(min_d, max_d))
	var dt := world.get_tile_at(dest)
	if dt == _TILE_TREE or dt == _TILE_WATER:
		dest = _last_dry
	dest.y = world.get_ground_y(dest)
	var from := pos
	_hop(from, dest, hop, 0.45, func() -> void: _settle(dest))

func _splash(world: GameWorld3D, at: Vector3) -> void:
	_end_flight_fx()
	_impact("splash", at)
	_splash_fx(at)
	var lie := Vector3(_last_dry.x, world.get_ground_y(_last_dry), _last_dry.z)
	_finish(lie, 1)

# ── Touchdown → skip → roll → rest ──────────────────────────────────────────

func _touchdown(at: Vector3, fwd: Vector3, energy: float) -> void:
	_end_flight_fx()
	var world := GameManager.world as GameWorld3D
	if world == null:
		_finish(at, 0)
		return
	var tile := world.get_tile_at(at)
	if tile == _TILE_WATER:
		_splash(world, at)
		return
	var sk: Array = _SKIP_DATA.get(tile, _SKIP_DEFAULT) as Array
	var dist_scale := clampf(((_p["from"] as Vector3).distance_to(_p["to"]) / 90.0), 0.25, 1.3) * energy
	var skip_d: float = (sk[0] as float) * dist_scale
	if skip_d < 0.15:
		_settle(at)
		return
	var dest := at + fwd * skip_d
	dest.y = world.get_ground_y(dest)
	# A skip that runs into a tree trunk stops short.
	if world.get_tile_at(dest) == _TILE_TREE:
		dest = at.lerp(dest, 0.35)
		dest.y = world.get_ground_y(dest)
	_hop(at, dest, sk[1] as float, sk[2] as float, func() -> void:
		if world.get_tile_at(dest) == _TILE_WATER:
			_splash(world, dest)
		else:
			_settle(dest))

## Roll downhill if the ground is steep enough (not in rough/sand).
func _settle(at: Vector3) -> void:
	var world := GameManager.world as GameWorld3D
	if world == null:
		_finish(at, 0)
		return
	var tile := world.get_tile_at(at)
	if tile != _TILE_ROUGH and tile != _TILE_SAND and tile != _TILE_WATER:
		var gx := world.get_ground_y(at + Vector3(0.5, 0, 0)) - world.get_ground_y(at - Vector3(0.5, 0, 0))
		var gz := world.get_ground_y(at + Vector3(0, 0, 0.5)) - world.get_ground_y(at - Vector3(0, 0, 0.5))
		var slope := Vector2(gx, gz)   # rise per metre
		if slope.length() > ROLL_MIN_SLOPE:
			var down := Vector3(-slope.x, 0.0, -slope.y).normalized()
			var dest := at + down * minf(slope.length() * 14.0, 6.0)
			dest.y = world.get_ground_y(dest)
			if world.get_tile_at(dest) == _TILE_TREE:
				dest = at.lerp(dest, 0.4); dest.y = world.get_ground_y(dest)
			_hop(at, dest, 0.04, 0.6, func() -> void:
				if world.get_tile_at(dest) == _TILE_WATER:
					_splash(world, dest)
				else:
					_rest(world, dest))
			return
	_rest(world, at)

func _rest(world: GameWorld3D, at: Vector3) -> void:
	if world.is_ob_at(at, hole_num):
		var lie := Vector3(_last_dry.x, world.get_ground_y(_last_dry), _last_dry.z)
		_finish(lie, 1)
		return
	var tile := world.get_tile_at(at)
	var pen := 1 if (tile == _TILE_ROUGH or tile == _TILE_SAND) else 0
	_finish(at, pen)

func _finish(at: Vector3, penalty: int) -> void:
	_landed = true
	_hopping = false
	position = at + (Vector3.ZERO if in_basket else Vector3(0, 0.03, 0))
	basis = Basis()
	set_process(false)
	landed.emit(position, penalty)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _hop(from: Vector3, to: Vector3, h: float, dur: float, next: Callable) -> void:
	_landed   = true
	_hop_from = from
	_hop_to   = to
	_hop_h    = h
	_hop_dur  = dur
	_hop_t    = 0.0
	_hop_next = next
	_hopping  = true
	position  = from

func _end_flight_fx() -> void:
	_landed = true
	if _glow_light and is_instance_valid(_glow_light):
		_glow_light.queue_free()
	_glow_light = null
	if _trail and is_instance_valid(_trail):
		_trail.emitting = false
	basis = Basis()

## Deterministic "random" in [a, b] from a position — same throw, same bounce.
func _det_range(p: Vector3, a: float, b: float) -> float:
	var h := absi(int(p.x * 7919.0) * 73856093 ^ int(p.z * 6151.0) * 19349663 ^ int(p.y * 31.0))
	return lerpf(a, b, float(h % 10007) / 10006.0)

func _impact(kind: String, at: Vector3) -> void:
	EventBus.disc_impact.emit(kind, at)

func _leaves(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	p.color = Color(0.25, 0.55, 0.15)
	_spawn_fx(p, at)

func _splash_fx(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 24
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.11
	p.color = Color(0.80, 0.90, 1.0, 0.9)
	_spawn_fx(p, at + Vector3(0, 0.05, 0))

func _spawn_fx(p: CPUParticles3D, at: Vector3) -> void:
	var m := SphereMesh.new()
	m.radius = 0.5; m.height = 1.0; m.radial_segments = 6; m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.surface_set_material(0, mat)
	p.mesh = m
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
