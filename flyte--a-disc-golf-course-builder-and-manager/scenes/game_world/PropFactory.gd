## Procedural / imported prop builders for GameWorld3D (trees, basket, tee pads,
## facilities, decor, hazards). Pure functions: no world state, so they can be
## reused by previews, the hub world or tests.
##
## Extracted from GameWorld3D.gd (2026-11) — behaviour unchanged.
extends RefCounted

## Must match GameWorld3D.CELL_SIZE (checked by tests/test_boot.gd).
const CELL_SIZE := 2.0

# ── Shared helpers ────────────────────────────────────────────────────────────

static func mi(parent: Node3D, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh              = mesh
	m.material_override = material
	m.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

static func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

## Stable per-cell pseudo-random hash (variation without RNG state).
static func cell_hash(col: int, row: int) -> int:
	return abs((col * 73856093) ^ (row * 19349663))

# ── Tree: pine (layered cones) ────────────────────────────────────────────────

static func make_pine(h: float, col: int = 0, row: int = 0) -> Node3D:
	var cv    := float(cell_hash(col + 2, row + 8) % 5) / 5.0   # 0.0 – 0.8
	var tree  := Node3D.new()
	var brown := mat(Color(0.32 + cv * 0.06, 0.16 + cv * 0.04, 0.05))
	var dgrn  := mat(Color(0.06 + cv * 0.06, 0.28 + cv * 0.10, 0.04))
	var grn   := mat(Color(0.10 + cv * 0.06, 0.38 + cv * 0.10, 0.07))
	var lgrn  := mat(Color(0.14 + cv * 0.06, 0.46 + cv * 0.10, 0.09))

	var tm := CylinderMesh.new()
	tm.top_radius = 0.10 * h; tm.bottom_radius = 0.16 * h; tm.height = 0.80 * h
	mi(tree, tm, brown).position.y = 0.40 * h

	var lm := CylinderMesh.new()
	lm.top_radius = 0.0; lm.bottom_radius = 0.58 * h; lm.height = 0.62 * h
	mi(tree, lm, dgrn).position.y = 1.00 * h

	var mm := CylinderMesh.new()
	mm.top_radius = 0.0; mm.bottom_radius = 0.42 * h; mm.height = 0.52 * h
	mi(tree, mm, grn).position.y = 1.46 * h

	var um := CylinderMesh.new()
	um.top_radius = 0.0; um.bottom_radius = 0.28 * h; um.height = 0.44 * h
	mi(tree, um, grn).position.y = 1.86 * h

	var tip := CylinderMesh.new()
	tip.top_radius = 0.0; tip.bottom_radius = 0.14 * h; tip.height = 0.32 * h
	mi(tree, tip, lgrn).position.y = 2.18 * h
	return tree

# ── Tree: deciduous (sphere clusters) ────────────────────────────────────────

static func make_deciduous(h: float, col: int = 0, row: int = 0) -> Node3D:
	var cv    := float(cell_hash(col + 3, row + 5) % 5) / 5.0   # 0.0 – 0.8
	var tree  := Node3D.new()
	var brown := mat(Color(0.34 + cv * 0.06, 0.18 + cv * 0.04, 0.06))
	var dgrn  := mat(Color(0.12 + cv * 0.08, 0.36 + cv * 0.12, 0.05))
	var grn   := mat(Color(0.18 + cv * 0.08, 0.48 + cv * 0.12, 0.09))
	var lgrn  := mat(Color(0.24 + cv * 0.08, 0.54 + cv * 0.12, 0.11))

	var tm := CylinderMesh.new()
	tm.top_radius = 0.11 * h; tm.bottom_radius = 0.17 * h; tm.height = 0.90 * h
	mi(tree, tm, brown).position.y = 0.45 * h

	var sm := SphereMesh.new()
	sm.radius = 0.68 * h; sm.height = 1.10 * h
	mi(tree, sm, dgrn).position.y = 1.48 * h

	var s1 := SphereMesh.new()
	s1.radius = 0.50 * h; s1.height = 0.85 * h
	mi(tree, s1, grn).position = Vector3(0.34 * h, 1.62 * h, 0.18 * h)

	var s2 := SphereMesh.new()
	s2.radius = 0.42 * h; s2.height = 0.72 * h
	mi(tree, s2, lgrn).position = Vector3(-0.28 * h, 1.70 * h, 0.30 * h)

	var st := SphereMesh.new()
	st.radius = 0.32 * h; st.height = 0.55 * h
	mi(tree, st, lgrn).position.y = 2.06 * h
	return tree

# ── Basket ────────────────────────────────────────────────────────────────────

# Tune BASKET_GLB_SCALE if the imported model is too large or too small.
# 1.0 = model at meter scale (real-world dimensions ~1.5m tall is about right).
# Set to 0.01 if model was exported in centimeters.
const BASKET_GLB_SCALE := 0.1
## The imported basket is ~341k vertices. Godot generates LODs on import; a
## bias < 1 switches to the simpler LODs sooner at isometric distances while
## close-ups (play-test camera) still get full detail. Not culling.
const BASKET_LOD_BIAS := 0.5

static func _set_lod_bias(node: Node, bias: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).lod_bias = bias
	for c in node.get_children():
		_set_lod_bias(c, bias)

## Optional imported basket model. The old free-download GLB (unknown license,
## ~341k vertices) now lives in ../asset_library/ — to try a licensed model,
## put it at BASKET_GLB_PATH and set USE_IMPORTED_BASKET = true.
const USE_IMPORTED_BASKET := false
const BASKET_GLB_PATH := "res://assets/models/basket.glb"

static var _basket_mesh: ArrayMesh = null

static func make_basket(flag_nodes: Array) -> Node3D:
	if USE_IMPORTED_BASKET and ResourceLoader.exists(BASKET_GLB_PATH):
		var scene := load(BASKET_GLB_PATH) as PackedScene
		if scene:
			var glb_node := scene.instantiate() as Node3D
			if glb_node:
				glb_node.scale = Vector3.ONE * BASKET_GLB_SCALE
				_set_lod_bias(glb_node, BASKET_LOD_BIAS)
				return glb_node

	var basket := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = basket_mesh()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	basket.add_child(body)

	# Flag above the cap (animated by GameWorld3D via flag_nodes)
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.50, 0.25, 0.02)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color     = Color(0.90, 0.18, 0.18)
	flag_mat.emission_enabled = true
	flag_mat.emission         = Color(0.4, 0.04, 0.04)
	var flag_mi := MeshInstance3D.new()
	flag_mi.mesh              = flag_mesh
	flag_mi.material_override = flag_mat
	flag_mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flag_mi.position          = Vector3(0.25, 2.60, 0)
	basket.add_child(flag_mi)
	flag_nodes.append(flag_mi)
	return basket

## Built-in disc golf basket: one cached ArrayMesh shared by every hole
## (3 surfaces: galvanised metal, yellow bands, dark rubber). ~3k triangles.
## Proportions follow a standard target (tray, 2 chain layers, top band, cap),
## scaled up ~1.5× like other props so it reads at the isometric camera distance.
static func basket_mesh() -> ArrayMesh:
	if _basket_mesh != null:
		return _basket_mesh
	var metal := SurfaceTool.new(); metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var band  := SurfaceTool.new(); band.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark  := SurfaceTool.new(); dark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var add := func(st: SurfaceTool, m: PrimitiveMesh, xf: Transform3D) -> void:
		st.append_from(m, 0, xf)
	var cyl := func(r_top: float, r_bot: float, h: float, segs: int) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h
		c.radial_segments = segs; c.rings = 1
		return c
	var torus := func(r_in: float, r_out: float, rings: int, sides: int) -> TorusMesh:
		var t := TorusMesh.new()
		t.inner_radius = r_in; t.outer_radius = r_out; t.rings = rings; t.ring_segments = sides
		return t
	## Thin cylinder from a to b (chains, tray bars).
	var rod := func(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
		var c := CylinderMesh.new()
		c.top_radius = r; c.bottom_radius = r; c.height = a.distance_to(b)
		c.radial_segments = 4; c.rings = 1
		var up := (b - a).normalized()
		var side := up.cross(Vector3.FORWARD)
		if side.length() < 0.01:
			side = up.cross(Vector3.RIGHT)
		side = side.normalized()
		var basis := Basis(side, up, side.cross(up).normalized() * -1.0)
		st.append_from(c, 0, Transform3D(basis.orthonormalized(), (a + b) * 0.5))

	# Base plate + pole sleeve
	add.call(dark, cyl.call(0.24, 0.27, 0.06, 16), Transform3D(Basis(), Vector3(0, 0.03, 0)))
	add.call(metal, cyl.call(0.05, 0.06, 0.18, 10), Transform3D(Basis(), Vector3(0, 0.15, 0)))
	# Pole
	add.call(metal, cyl.call(0.032, 0.036, 2.06, 10), Transform3D(Basis(), Vector3(0, 1.09, 0)))

	# Catch tray: solid floor, yellow rim + lower hoop, 16 vertical bars
	const TRAY_R := 0.42
	const TRAY_BOT := 0.70
	const TRAY_TOP := 0.98
	add.call(metal, cyl.call(TRAY_R - 0.06, TRAY_R - 0.08, 0.035, 20), Transform3D(Basis(), Vector3(0, TRAY_BOT, 0)))
	add.call(band, torus.call(TRAY_R - 0.035, TRAY_R + 0.035, 28, 6), Transform3D(Basis(), Vector3(0, TRAY_TOP, 0)))
	add.call(metal, torus.call(TRAY_R - 0.07, TRAY_R - 0.04, 24, 4), Transform3D(Basis(), Vector3(0, TRAY_BOT + 0.02, 0)))
	for i in 16:
		var ang := TAU * i / 16.0
		var d := Vector3(sin(ang), 0, cos(ang))
		rod.call(metal, d * (TRAY_R - 0.06) + Vector3(0, TRAY_BOT, 0), d * TRAY_R + Vector3(0, TRAY_TOP, 0), 0.008)

	# Chain assembly: top band → collar just above the tray (two cones of chain)
	const BAND_Y := 1.98
	const BAND_R := 0.34
	const COLLAR_Y := 1.10
	add.call(band, cyl.call(BAND_R + 0.025, BAND_R + 0.025, 0.14, 24), Transform3D(Basis(), Vector3(0, BAND_Y, 0)))
	add.call(metal, cyl.call(0.06, BAND_R + 0.05, 0.10, 24), Transform3D(Basis(), Vector3(0, BAND_Y + 0.09, 0)))  # cap
	add.call(metal, torus.call(0.05, 0.09, 12, 4), Transform3D(Basis(), Vector3(0, COLLAR_Y, 0)))           # collar
	for i in 12:   # outer chains: sag outward slightly (2 segments each)
		var ang := TAU * i / 12.0
		var d := Vector3(sin(ang), 0, cos(ang))
		var top := d * BAND_R + Vector3(0, BAND_Y - 0.05, 0)
		var mid := d * (BAND_R * 0.80) + Vector3(0, (BAND_Y + COLLAR_Y) * 0.5 - 0.08, 0)
		var bot := d * 0.08 + Vector3(0, COLLAR_Y, 0)
		rod.call(metal, top, mid, 0.010)
		rod.call(metal, mid, bot, 0.010)
	for i in 12:   # inner chains: offset half a step, tighter cone
		var ang := TAU * (i + 0.5) / 12.0
		var d := Vector3(sin(ang), 0, cos(ang))
		rod.call(metal, d * (BAND_R * 0.62) + Vector3(0, BAND_Y - 0.05, 0), d * 0.07 + Vector3(0, COLLAR_Y + 0.04, 0), 0.009)

	# Flag post above the cap
	add.call(metal, cyl.call(0.012, 0.012, 0.55, 6), Transform3D(Basis(), Vector3(0, 2.38, 0)))

	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.74, 0.76, 0.80)
	metal_mat.metallic = 0.6
	metal_mat.roughness = 0.45
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.96, 0.78, 0.10)
	band_mat.roughness = 0.5
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.13, 0.13, 0.13)
	dark_mat.roughness = 0.9

	var mesh := ArrayMesh.new()
	for pair in [[metal, metal_mat], [band, band_mat], [dark, dark_mat]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	_basket_mesh = mesh
	return mesh

# ── Tee pad ───────────────────────────────────────────────────────────────────

static func make_tee_pad(orientation: int, flag_color: Color) -> Node3D:
	var tee  := Node3D.new()
	var pad  := mat(Color(0.90, 0.90, 0.86))
	var edge := mat(Color(0.52, 0.52, 0.50))
	var grey := mat(Color(0.68, 0.68, 0.66))
	var arr_mat := mat(Color(0.18, 0.88, 0.28))

	# Tee surface — long axis in Z (throw direction), wide axis in X
	var em := BoxMesh.new()
	em.size = Vector3(CELL_SIZE * 0.96, 0.04, CELL_SIZE * 1.88)
	mi(tee, em, edge).position.y = 0.0

	var sm := BoxMesh.new()
	sm.size = Vector3(CELL_SIZE * 0.90, 0.07, CELL_SIZE * 1.82)
	mi(tee, sm, pad).position.y = 0.055

	# Bold directional arrow pointing toward basket (-Z before rotation)
	var ab := BoxMesh.new()
	ab.size = Vector3(0.22, 0.10, CELL_SIZE * 0.80)
	mi(tee, ab, arr_mat).position = Vector3(0.0, 0.14, -0.10)

	var al := BoxMesh.new()
	al.size = Vector3(0.12, 0.10, 0.45)
	var al_n := mi(tee, al, arr_mat)
	al_n.position = Vector3(-0.28, 0.14, -0.78)
	al_n.rotation.y = -0.60

	var ar := BoxMesh.new()
	ar.size = Vector3(0.12, 0.10, 0.45)
	var ar_n := mi(tee, ar, arr_mat)
	ar_n.position = Vector3(0.28, 0.14, -0.78)
	ar_n.rotation.y = 0.60

	# Hole number flag post (colour-coded by custom or default hole color)
	var post_m := CylinderMesh.new()
	post_m.top_radius = 0.018; post_m.bottom_radius = 0.018; post_m.height = 0.82
	mi(tee, post_m, grey).position = Vector3(0.72, 0.46, 0.0)

	var flag_m := SphereMesh.new()
	flag_m.radius = 0.14; flag_m.height = 0.28
	mi(tee, flag_m, mat(flag_color)).position = Vector3(0.72, 0.98, 0.0)

	# Apply facing rotation (0=N 1=E 2=S 3=W — rotates whole pad)
	tee.rotation.y = orientation * PI * 0.5
	return tee

# ── Entry gate ────────────────────────────────────────────────────────────────

static func make_gate(with_ray_bag: bool = false) -> Node3D:
	var gate  := Node3D.new()
	var stone := mat(Color(0.66, 0.63, 0.58))
	var wood  := mat(Color(0.40, 0.24, 0.10))
	var cream := mat(Color(0.92, 0.88, 0.76))
	var dgrn  := mat(Color(0.14, 0.42, 0.10))

	var lp := BoxMesh.new(); lp.size = Vector3(0.28, 2.40, 0.28)
	mi(gate, lp, stone).position = Vector3(-1.00, 1.20, 0.0)

	var rp := BoxMesh.new(); rp.size = Vector3(0.28, 2.40, 0.28)
	mi(gate, rp, stone).position = Vector3(1.00, 1.20, 0.0)

	var tb := BoxMesh.new(); tb.size = Vector3(2.40, 0.22, 0.28)
	mi(gate, tb, stone).position = Vector3(0.0, 2.44, 0.0)

	var sb := BoxMesh.new(); sb.size = Vector3(1.60, 0.38, 0.06)
	mi(gate, sb, cream).position = Vector3(0.0, 2.20, 0.18)

	var ss := BoxMesh.new(); ss.size = Vector3(1.28, 0.12, 0.08)
	mi(gate, ss, dgrn).position = Vector3(0.0, 2.20, 0.22)

	for i in 5:
		var bm := BoxMesh.new(); bm.size = Vector3(0.06, 1.60, 0.06)
		mi(gate, bm, wood).position = Vector3(-0.80 + i * 0.40, 0.80, 0.0)
	if with_ray_bag:
		gate.add_child(make_ray_bag())
	return gate

## Uncle Ray's old disc bag, hung on the gate fence. Environmental storytelling
## only — not interactive (STORY.md "Recurring Story Elements").
static func make_ray_bag() -> Node3D:
	var bag := Node3D.new()
	bag.name = "RayDiscBag"
	var canvas := mat(Color(0.20, 0.30, 0.18))   # faded olive canvas
	var strap  := mat(Color(0.12, 0.10, 0.08))
	var body := BoxMesh.new(); body.size = Vector3(0.34, 0.42, 0.16)
	mi(bag, body, canvas).position = Vector3(0.0, 0.0, 0.0)
	var pocket := BoxMesh.new(); pocket.size = Vector3(0.24, 0.16, 0.04)
	mi(bag, pocket, mat(Color(0.16, 0.24, 0.14))).position = Vector3(0.0, -0.08, 0.10)
	var s := BoxMesh.new(); s.size = Vector3(0.04, 0.30, 0.03)
	mi(bag, s, strap).position = Vector3(-0.10, 0.32, 0.0)
	mi(bag, s, strap).position = Vector3(0.10, 0.32, 0.0)
	# Disc rims poking out of the top, sun-faded
	var cols := [Color(0.85, 0.55, 0.20), Color(0.70, 0.25, 0.22), Color(0.80, 0.78, 0.40)]
	for i in cols.size():
		var d := CylinderMesh.new()
		d.top_radius = 0.10; d.bottom_radius = 0.10; d.height = 0.025
		var dm := mi(bag, d, mat(cols[i] as Color))
		dm.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		dm.position = Vector3(-0.08 + i * 0.08, 0.22, -0.02 + i * 0.015)
	# Hung on the fence just inside the left post, on the visitor-facing side
	bag.position = Vector3(-0.60, 1.05, 0.12)
	bag.rotation = Vector3(0.0, 0.0, 0.08)
	return bag

# ── Facility props ───────────────────────────────────────────────────────────

static func make_parking() -> Node3D:
	var p       := Node3D.new()
	var asphalt := mat(Color(0.12, 0.12, 0.12))
	var stripe  := mat(Color(0.94, 0.94, 0.94))
	var yellow  := mat(Color(0.90, 0.80, 0.08))
	var curb    := mat(Color(0.70, 0.70, 0.68))

	# Main asphalt slab
	var base := BoxMesh.new()
	base.size = Vector3(CELL_SIZE * 1.88, 0.04, CELL_SIZE * 0.70)
	mi(p, base, asphalt).position = Vector3(0.0, 0.02, 0.12)

	# Entry lane (wider driveway at front, no stripes)
	var entry := BoxMesh.new()
	entry.size = Vector3(CELL_SIZE * 1.30, 0.04, CELL_SIZE * 0.26)
	mi(p, entry, asphalt).position = Vector3(0.0, 0.02, -0.42)

	# Curb/kerb along the top and sides
	var curb_top := BoxMesh.new(); curb_top.size = Vector3(CELL_SIZE * 1.90, 0.10, 0.10)
	mi(p, curb_top, curb).position = Vector3(0.0, 0.05, 0.49)
	var curb_l := BoxMesh.new(); curb_l.size = Vector3(0.10, 0.10, CELL_SIZE * 0.82)
	mi(p, curb_l, curb).position = Vector3(-0.94, 0.05, 0.08)
	var curb_r := BoxMesh.new(); curb_r.size = Vector3(0.10, 0.10, CELL_SIZE * 0.82)
	mi(p, curb_r, curb).position = Vector3( 0.94, 0.05, 0.08)

	# 3 white parking stripes (2 spots)
	for i in 3:
		var s := BoxMesh.new()
		s.size = Vector3(0.06, 0.05, CELL_SIZE * 0.60)
		mi(p, s, stripe).position = Vector3(-0.64 + i * 0.64, 0.05, 0.15)

	# Yellow entry arrows (chevrons pointing into lot)
	for ox in [-0.22, 0.22]:
		var arr := BoxMesh.new(); arr.size = Vector3(0.08, 0.04, 0.26)
		var ami := mi(p, arr, yellow)
		ami.position = Vector3(ox, 0.04, -0.38)
		ami.rotation.y = 0.52 * signf(ox)

	return p

static func make_car(col: int, row: int, variant: int) -> Node3D:
	var car := Node3D.new()
	var h := cell_hash(col * 13 + variant * 7, row * 17 + variant * 3)
	const CAR_COLORS: Array = [
		Color(0.72, 0.10, 0.10),  # Red
		Color(0.14, 0.30, 0.76),  # Blue
		Color(0.82, 0.80, 0.24),  # Yellow
		Color(0.22, 0.22, 0.22),  # Black
		Color(0.88, 0.88, 0.88),  # White
		Color(0.24, 0.52, 0.20),  # Green
		Color(0.62, 0.34, 0.10),  # Tan
		Color(0.62, 0.62, 0.64),  # Silver
	]
	var body_mat  := mat(CAR_COLORS[h % CAR_COLORS.size()] as Color)
	var wheel_mat := mat(Color(0.10, 0.10, 0.10))
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.38, 0.54, 0.72, 0.72)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Body
	var body := BoxMesh.new(); body.size = Vector3(0.52, 0.17, 0.88)
	mi(car, body, body_mat).position.y = 0.12
	# Roof cabin
	var roof := BoxMesh.new(); roof.size = Vector3(0.44, 0.15, 0.46)
	mi(car, roof, body_mat).position = Vector3(0.0, 0.26, -0.02)
	# Windshield
	var ws := BoxMesh.new(); ws.size = Vector3(0.40, 0.13, 0.06)
	var wsi := MeshInstance3D.new()
	wsi.mesh = ws; wsi.material_override = glass_mat
	wsi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wsi.position = Vector3(0.0, 0.26, 0.21)
	car.add_child(wsi)
	# Rear window
	var rw := BoxMesh.new(); rw.size = Vector3(0.40, 0.11, 0.06)
	var rwi := MeshInstance3D.new()
	rwi.mesh = rw; rwi.material_override = glass_mat
	rwi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rwi.position = Vector3(0.0, 0.26, -0.25)
	car.add_child(rwi)
	# 4 wheels
	for wx in [-0.28, 0.28]:
		for wz in [-0.30, 0.30]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.09; wm.bottom_radius = 0.09; wm.height = 0.09
			var wi := mi(car, wm, wheel_mat)
			wi.position = Vector3(wx, 0.09, wz)
			wi.rotation.z = PI * 0.5
	return car

static func add_parked_cars(parent: Node3D, col: int, row: int) -> void:
	var car_count := 1 + (cell_hash(col * 3, row * 7) % 2)
	const SPOTS: Array = [Vector3(-0.34, 0.0, 0.18), Vector3(0.34, 0.0, 0.18)]
	for i in car_count:
		var car := make_car(col, row, i)
		car.position = SPOTS[i] as Vector3
		# slight random yaw so they look naturally parked
		var yaw := float(cell_hash(col * 5 + i, row * 11)) / 2147483647.0 * 0.24 - 0.12
		car.rotation.y = yaw
		parent.add_child(car)

static func make_restroom() -> Node3D:
	var r := Node3D.new()
	var wall := mat(Color(0.88, 0.88, 0.84))
	var roof := mat(Color(0.52, 0.52, 0.54))
	var door_mat := mat(Color(0.40, 0.30, 0.22))
	# Body: 1.80m wide × 3.80m tall × 1.70m deep
	var body := BoxMesh.new()
	body.size = Vector3(1.80, 3.80, 1.70)
	mi(r, body, wall).position.y = 1.92
	# Flat roof with overhang
	var top := BoxMesh.new()
	top.size = Vector3(2.00, 0.24, 1.90)
	mi(r, top, roof).position.y = 3.94
	# Door
	var d := BoxMesh.new()
	d.size = Vector3(0.55, 2.10, 0.12)
	mi(r, d, door_mat).position = Vector3(0.0, 1.07, 0.86)
	# Men/Women sign strip
	var sign := mat(Color(0.28, 0.48, 0.82))
	var sg := BoxMesh.new()
	sg.size = Vector3(1.60, 0.30, 0.08)
	mi(r, sg, sign).position = Vector3(0.0, 3.50, 0.87)
	return r

static func make_food_stand() -> Node3D:
	var f := Node3D.new()
	var wood    := mat(Color(0.38, 0.22, 0.10))
	var awning  := mat(Color(0.90, 0.18, 0.12))
	var stripe  := mat(Color(0.98, 0.92, 0.20))
	var counter := mat(Color(0.72, 0.60, 0.38))
	# Main body: 1.80m wide × 3.50m tall × 1.50m deep
	var body := BoxMesh.new()
	body.size = Vector3(1.80, 3.50, 1.50)
	mi(f, body, wood).position.y = 1.77
	# Service counter ledge at front
	var ctr := BoxMesh.new()
	ctr.size = Vector3(1.80, 0.14, 0.50)
	mi(f, ctr, counter).position = Vector3(0.0, 1.10, 1.0)
	# Awning
	var aw := BoxMesh.new()
	aw.size = Vector3(2.30, 0.18, 2.10)
	mi(f, aw, awning).position.y = 3.61
	# Awning stripes
	for i in 3:
		var s := BoxMesh.new()
		s.size = Vector3(2.30, 0.19, 0.19)
		mi(f, s, stripe).position = Vector3(0.0, 3.61, -0.68 + i * 0.68)
	return f

static func make_pro_shop() -> Node3D:
	var s    := Node3D.new()
	var w    := CELL_SIZE * 3.0  # 6.0 units — spans 3 tiles
	var wall := mat(Color(0.22, 0.30, 0.18))
	var trim := mat(Color(0.44, 0.62, 0.38))
	var roof := mat(Color(0.12, 0.16, 0.10))
	var sign := mat(Color(0.92, 0.84, 0.18))
	var glass := mat(Color(0.50, 0.68, 0.82))
	var pillar := mat(Color(0.88, 0.86, 0.82))

	# Main body — 4.20m tall, clearly a real building
	var body := BoxMesh.new()
	body.size = Vector3(w - 0.30, 4.20, w - 0.30)
	mi(s, body, wall).position.y = 2.12

	# Roof with overhang
	var rm := BoxMesh.new()
	rm.size = Vector3(w + 0.20, 0.22, w + 0.20)
	mi(s, rm, roof).position.y = 4.34
	var rm2 := BoxMesh.new(); rm2.size = Vector3(w - 0.10, 0.10, w - 0.10)
	mi(s, rm2, roof).position.y = 4.22

	# Entrance portico (front face, -Z direction)
	var port := BoxMesh.new(); port.size = Vector3(2.60, 0.18, 1.60)
	mi(s, port, roof).position = Vector3(0.0, 4.08, -(w * 0.5 - 0.30))
	# Entrance pillars — full height
	for px in [-0.90, 0.90]:
		var pc := CylinderMesh.new()
		pc.top_radius = 0.14; pc.bottom_radius = 0.17; pc.height = 4.08
		mi(s, pc, pillar).position = Vector3(px, 2.04, -(w * 0.5 - 0.22))
	# Entrance door — tall double doors
	var door := BoxMesh.new(); door.size = Vector3(1.00, 2.60, 0.08)
	mi(s, door, glass).position = Vector3(0.0, 1.32, -(w * 0.5 - 0.16))

	# Corner pilasters — full building height
	for cx2 in [-1, 1]:
		for cz2 in [-1, 1]:
			var pl := BoxMesh.new(); pl.size = Vector3(0.28, 4.22, 0.28)
			mi(s, pl, trim).position = Vector3(cx2 * (w * 0.5 - 0.28), 2.12, cz2 * (w * 0.5 - 0.28))

	# Windows — front face (flanking door), two rows
	for wx2 in [-1.60, 1.60]:
		for wy2 in [1.30, 2.80]:
			var wm := BoxMesh.new(); wm.size = Vector3(0.80, 0.80, 0.07)
			mi(s, wm, glass).position = Vector3(wx2, wy2, -(w * 0.5 - 0.16))
	# Windows — side faces, two rows
	for wz2 in [-0.90, 0.90]:
		for side in [-1.0, 1.0]:
			for wy2 in [1.30, 2.80]:
				var wm2 := BoxMesh.new(); wm2.size = Vector3(0.07, 0.80, 0.80)
				mi(s, wm2, glass).position = Vector3(side * (w * 0.5 - 0.16), wy2, wz2)

	# Gold sign above entrance
	var sg := BoxMesh.new(); sg.size = Vector3(2.40, 0.44, 0.09)
	mi(s, sg, sign).position = Vector3(0.0, 3.52, -(w * 0.5 - 0.16))
	# Sign trim lines
	for sy in [-0.10, 0.10]:
		var stm := BoxMesh.new(); stm.size = Vector3(2.44, 0.05, 0.10)
		mi(s, stm, trim).position = Vector3(0.0, 3.52 + sy, -(w * 0.5 - 0.14))

	# Flagpole at roof center
	var fp := CylinderMesh.new()
	fp.top_radius = 0.022; fp.bottom_radius = 0.028; fp.height = 1.40
	mi(s, fp, pillar).position.y = 5.04
	var flag := BoxMesh.new(); flag.size = Vector3(0.60, 0.34, 0.04)
	mi(s, flag, sign).position = Vector3(0.34, 5.65, 0.0)
	return s


# ── Rough grass + sand (instanced — see PropBatch.gd) ─────────────────────────
# These are drawn as MultiMesh instances: GameWorld3D registers one part per
# mesh below and feeds it the per-cell lists. Shapes/colours match the old
# per-node clumps; blades/grains use 6–8 radial segments (they are 1–4 cm wide).

## Low-preset tree detail: a simplified copy of one triangle surface (Godot's
## mesh simplifier, the same one the importer uses for LODs). Picks the most
## detailed LOD at or under REDUCED_TREE_RATIO of the original; null when the
## surface can't be simplified (e.g. separate leaf cards) — keep it as is.
const REDUCED_TREE_RATIO := 0.35

static func reduced_tree_mesh(arrays: Array, material: Material) -> ArrayMesh:
	var base_idx: Variant = arrays[Mesh.ARRAY_INDEX]
	var base := ((base_idx as PackedInt32Array).size() if base_idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var n := im.get_surface_lod_count(0)
	if n == 0:
		return null
	var pick := n - 1
	for l in n:
		if im.get_surface_lod_indices(0, l).size() / 3 <= base * REDUCED_TREE_RATIO:
			pick = l
			break
	var out := im.get_surface_arrays(0)
	out[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(0, pick)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	if material:
		am.surface_set_material(0, material)
	return am

## Material whose albedo is the per-instance colour (sRGB, like mat()).
static func instance_mat(roughness: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m

## Unit-height blade (scaled in y per instance).
static func blade_mesh() -> Mesh:
	var bm := CylinderMesh.new()
	bm.top_radius = 0.006
	bm.bottom_radius = 0.020
	bm.height = 1.0
	bm.radial_segments = 6
	bm.rings = 0
	bm.cap_top = false
	bm.cap_bottom = false
	return bm

## Unit grain (radius 1, squashed to 1.2 tall), scaled per instance.
static func grain_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.2
	sm.radial_segments = 8
	sm.rings = 4
	return sm

## Sparse tall grass on a rough tile: 8 blades. base = cell prop origin.
static func rough_grass_instances(col: int, row: int, base: Vector3, part: int) -> Array:
	var out: Array = []
	for i in 8:
		var hv  := cell_hash(col * 7 + i, row * 3) % 6
		var h   := 0.30 + hv * 0.05   # taller than normal, dried-out look
		var gv  := float(cell_hash(col + i * 3, row + i) % 4) / 4.0
		var col_c := Color(0.46 + gv * 0.12, 0.38 + gv * 0.08, 0.06 + gv * 0.04)   # brownish-tan
		var angle := float(cell_hash(col * 11 + i, row * 17)) / 2147483647.0 * TAU
		var dist  := float(cell_hash(col * 5 + i, row * 13) % 5) * 0.15
		var b := Basis.from_euler(Vector3(cos(angle) * 0.22, 0.0, sin(angle) * 0.22)) \
			* Basis.from_scale(Vector3(1.0, h, 1.0))
		out.append([part, Transform3D(b, base + Vector3(cos(angle) * dist, h * 0.5, sin(angle) * dist)), col_c])
	return out

## Sand grains on a sand tile: 12 grains.
static func sand_instances(col: int, row: int, base: Vector3, part: int) -> Array:
	var out: Array = []
	for i in 12:
		var hv := cell_hash(col * 5 + i, row * 7) % 4
		var r  := 0.04 + float(hv) * 0.012
		var gv := float(cell_hash(col + i * 2, row + i) % 5) / 5.0
		var col_c := Color(0.88 + gv * 0.08, 0.78 + gv * 0.06, 0.42 + gv * 0.04)
		var angle := float(cell_hash(col * 13 + i, row * 17)) / 2147483647.0 * TAU
		var dist  := float(cell_hash(col * 7 + i, row * 11) % 8) * 0.10
		out.append([part, Transform3D(Basis.from_scale(Vector3.ONE * r),
			base + Vector3(cos(angle) * dist, 0.01, sin(angle) * dist)), col_c])
	return out

static func make_rock(col: int, row: int) -> Node3D:
	var rock := Node3D.new()
	var num := 1 + cell_hash(col, row) % 3
	for i in num:
		var hv := cell_hash(col * 3 + i, row * 5) % 5
		var bm := SphereMesh.new()
		bm.radius = 0.22 + float(hv) * 0.06
		bm.height = bm.radius * (0.7 + float(cell_hash(col + i, row + i * 3) % 4) * 0.1)
		var gv := float(cell_hash(col + i, row) % 4) / 4.0
		var stone := mi(rock, bm, mat(Color(0.38 + gv * 0.14, 0.36 + gv * 0.12, 0.32 + gv * 0.10)))
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var angle := float(cell_hash(col * 11 + i, row * 7)) / 2147483647.0 * TAU
		var dist  := float(cell_hash(col * 9 + i, row * 3) % 4) * 0.20
		stone.position = Vector3(cos(angle) * dist, bm.height * 0.3, sin(angle) * dist)
	return rock

static func make_ob_marker(col: int, row: int) -> Node3D:
	var ob := Node3D.new()
	# White post with OB stripe
	var post_m := CylinderMesh.new()
	post_m.top_radius    = 0.04
	post_m.bottom_radius = 0.04
	post_m.height        = 0.60
	var post := mi(ob, post_m, mat(Color(0.95, 0.95, 0.95)))
	post.position.y = 0.30
	# Red stripe band
	var band_m := CylinderMesh.new()
	band_m.top_radius    = 0.045
	band_m.bottom_radius = 0.045
	band_m.height        = 0.08
	var band := mi(ob, band_m, mat(Color(0.95, 0.15, 0.15)))
	band.position.y = 0.50
	# Corner only — offset so not every OB tile clutters
	var h := cell_hash(col, row)
	ob.position = Vector3((float(h % 3) - 1.0) * 0.70, 0.0, (float((h >> 4) % 3) - 1.0) * 0.70)
	return ob

# ── Decor props ───────────────────────────────────────────────────────────────

static func make_bench(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color(0.55, 0.32, 0.12))
	var metal := mat(Color(0.28, 0.28, 0.30))
	# Seat plank
	var seat_m := BoxMesh.new()
	seat_m.size = Vector3(0.80, 0.06, 0.32)
	var seat := mi(root, seat_m, wood)
	seat.position = Vector3(0.0, 0.44, 0.0)
	# Back plank
	var back_m := BoxMesh.new()
	back_m.size = Vector3(0.80, 0.28, 0.05)
	var back := mi(root, back_m, wood)
	back.position = Vector3(0.0, 0.62, -0.14)
	# Left leg
	var leg_m := CylinderMesh.new()
	leg_m.top_radius = 0.03; leg_m.bottom_radius = 0.03; leg_m.height = 0.44
	var ll := mi(root, leg_m, metal); ll.position = Vector3(-0.32, 0.22,  0.12)
	var lr := mi(root, leg_m, metal); lr.position = Vector3( 0.32, 0.22,  0.12)
	var rl := mi(root, leg_m, metal); rl.position = Vector3(-0.32, 0.22, -0.12)
	var rr := mi(root, leg_m, metal); rr.position = Vector3( 0.32, 0.22, -0.12)
	# Orient based on cell hash
	var h := cell_hash(col, row)
	root.rotation_degrees.y = float(h % 4) * 90.0
	return root

static func make_flower_bed(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var h := cell_hash(col, row)
	# Small border ring (soil)
	var soil_m := CylinderMesh.new()
	soil_m.top_radius = 0.65; soil_m.bottom_radius = 0.70; soil_m.height = 0.08
	mi(root, soil_m, mat(Color(0.30, 0.18, 0.08)))
	# Flower clusters (3-6 blooms per bed)
	var bloom_colors := [
		Color(0.95, 0.20, 0.50), Color(0.95, 0.80, 0.10),
		Color(0.35, 0.65, 0.95), Color(0.92, 0.45, 0.10),
		Color(0.80, 0.20, 0.90),
	]
	var bloom_count := 3 + (h % 4)
	for i in bloom_count:
		var angle := float(i) / float(bloom_count) * TAU + float(h % 7) * 0.4
		var dist  := 0.15 + float((h + i * 7) % 5) * 0.08
		var bloom_m := SphereMesh.new()
		bloom_m.radius = 0.10 + float((h + i * 3) % 4) * 0.03
		bloom_m.height = bloom_m.radius * 2.0
		var bloom := mi(root, bloom_m, mat(bloom_colors[(h + i) % bloom_colors.size()]))
		bloom.position = Vector3(cos(angle) * dist, 0.22 + float((h + i * 5) % 3) * 0.06, sin(angle) * dist)
		# Stem
		var stem_m := CylinderMesh.new()
		stem_m.top_radius = 0.015; stem_m.bottom_radius = 0.015; stem_m.height = 0.18
		var stem := mi(root, stem_m, mat(Color(0.18, 0.55, 0.12)))
		stem.position = Vector3(bloom.position.x, 0.09, bloom.position.z)
	return root

static func make_sculpture(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var h := cell_hash(col, row)
	# Stone pedestal
	var ped_m := CylinderMesh.new()
	ped_m.top_radius = 0.22; ped_m.bottom_radius = 0.28; ped_m.height = 0.35
	var ped := mi(root, ped_m, mat(Color(0.52, 0.50, 0.50)))
	ped.position.y = 0.175
	# Main disc art piece — stylized flying disc
	var disc_m := CylinderMesh.new()
	disc_m.top_radius = 0.38; disc_m.bottom_radius = 0.38; disc_m.height = 0.10
	var disc_mat := mat(Color(0.82, 0.72, 0.28))   # gold
	var disc_art := mi(root, disc_m, disc_mat)
	disc_art.position.y = 0.48
	disc_art.rotation_degrees.x = -30.0 + float(h % 5) * 8.0
	disc_art.rotation_degrees.y = float(h % 8) * 45.0
	# Rim detail — thin torus around the disc edge
	var rim_m := TorusMesh.new()
	rim_m.inner_radius = 0.36; rim_m.outer_radius = 0.42
	rim_m.rings = 8; rim_m.ring_segments = 16
	var rim := mi(root, rim_m, mat(Color(0.30, 0.28, 0.24)))
	rim.position.y = 0.48
	rim.rotation_degrees = disc_art.rotation_degrees
	return root

static func make_lamp_post(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var metal := mat(Color(0.22, 0.22, 0.24))
	var glass  := mat(Color(0.95, 0.92, 0.60))
	var pole_m := CylinderMesh.new()
	pole_m.top_radius = 0.04; pole_m.bottom_radius = 0.06; pole_m.height = 1.20
	var pole := mi(root, pole_m, metal); pole.position.y = 0.60
	var arm_m := CylinderMesh.new()
	arm_m.top_radius = 0.03; arm_m.bottom_radius = 0.03; arm_m.height = 0.40
	var arm := mi(root, arm_m, metal)
	arm.position = Vector3(0.20, 1.22, 0.0); arm.rotation_degrees.z = -90.0
	var head_m := CylinderMesh.new()
	head_m.top_radius = 0.12; head_m.bottom_radius = 0.12; head_m.height = 0.18
	var head := mi(root, head_m, metal); head.position = Vector3(0.40, 1.22, 0.0)
	var glow_m := SphereMesh.new()
	glow_m.radius = 0.08; glow_m.height = 0.16
	var glow := mi(root, glow_m, glass); glow.position = Vector3(0.40, 1.22, 0.0)
	var base_m := CylinderMesh.new()
	base_m.top_radius = 0.12; base_m.bottom_radius = 0.14; base_m.height = 0.06
	var base := mi(root, base_m, metal); base.position.y = 0.03
	root.rotation_degrees.y = float(cell_hash(col, row) % 4) * 90.0
	return root

static func make_sign(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var wood  := mat(Color(0.55, 0.38, 0.14))
	var white := mat(Color(0.95, 0.95, 0.90))
	var green := mat(Color(0.12, 0.50, 0.18))
	var post_m := CylinderMesh.new()
	post_m.top_radius = 0.04; post_m.bottom_radius = 0.05; post_m.height = 0.72
	var post := mi(root, post_m, wood); post.position.y = 0.36
	var board_m := BoxMesh.new(); board_m.size = Vector3(0.64, 0.30, 0.04)
	var board := mi(root, board_m, green); board.position.y = 0.80
	var stripe_m := BoxMesh.new(); stripe_m.size = Vector3(0.44, 0.05, 0.05)
	var s1 := mi(root, stripe_m, white); s1.position = Vector3(0.0, 0.83, 0.03)
	var s2 := mi(root, stripe_m, white); s2.position = Vector3(0.0, 0.73, 0.03)
	root.rotation_degrees.y = float(cell_hash(col, row) % 4) * 90.0
	return root

static func make_garden(col: int, row: int) -> Node3D:
	var root := Node3D.new()
	var h := cell_hash(col, row)
	# Stone border ring — torus lying flat
	var border_m := TorusMesh.new()
	border_m.inner_radius = 0.56; border_m.outer_radius = 0.74
	border_m.rings = 6; border_m.ring_segments = 16
	var border := mi(root, border_m, mat(Color(0.50, 0.47, 0.44)))
	border.scale.y = 0.18   # flatten the torus into a low ring
	var soil_m := CylinderMesh.new()
	soil_m.top_radius = 0.55; soil_m.bottom_radius = 0.55; soil_m.height = 0.06
	var soil := mi(root, soil_m, mat(Color(0.28, 0.16, 0.07))); soil.position.y = -0.02
	var greens := [Color(0.15, 0.60, 0.12), Color(0.20, 0.72, 0.18), Color(0.10, 0.48, 0.10)]
	var plant_count := 4 + h % 4
	for i in plant_count:
		var angle := float(i) / float(plant_count) * TAU + float(h % 5) * 0.5
		var dist  := 0.10 + float((h + i * 7) % 4) * 0.10
		var pm := SphereMesh.new()
		pm.radius = 0.12 + float((h + i) % 3) * 0.04; pm.height = pm.radius * 1.5
		var plant := mi(root, pm, mat(greens[(h + i) % greens.size()]))
		plant.position = Vector3(cos(angle) * dist, 0.08, sin(angle) * dist)
	return root
