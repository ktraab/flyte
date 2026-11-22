## Instanced props: copies of a mesh are drawn by MultiMeshes, so 6,000 trees
## cost a few hundred draw calls instead of 12,000+.
## Nothing on screen is culled. Tree parts are full detail except on the Low
## preset, where GameWorld3D swaps in simplified meshes (set_part_mesh). Each part is split into map chunks (CHUNK_CELLS square)
## only so the engine can skip chunks that are entirely off-screen / outside the
## shadow range, exactly as it skipped individual tree nodes before batching.
##
## A *part* is one mesh + material (e.g. "pine A foliage", "grass blade").
## A *bucket* is one part within one chunk = one MultiMesh (created on demand).
## A *cell* owns a list of instances across any parts. Changing a cell is O(its
## instances): slots are swap-removed, so painting in the builder stays cheap.
extends Node3D

## Chunk edge in grid cells (150 / 50 = 3×3 chunks). Measured on Maple Hill:
## smaller chunks cull a little more but cost many more draw calls.
const CHUNK_CELLS := 50
const CELL_SIZE := 2.0
## Chunk AABB padding: canopies overhang their cell; tall trees on hills.
const AABB_PAD := 10.0
const AABB_Y0 := -20.0
const AABB_Y1 := 70.0

## Hidden instances (camera-occlusion fade) collapse to a point at their origin.
const _HIDE_BASIS := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

var _parts: Array = []          # part id → {mesh, material, shadows}
var _buckets: Dictionary = {}   # bucket key → {mm, used, owners, part}
var _cells: Dictionary = {}     # Vector2i → Array of entries
var _hidden: Dictionary = {}    # Vector2i → true

# Entry layout (Array, shared by _cells and owners so slot moves update both):
const E_BUCKET := 0
const E_SLOT := 1
const E_XF := 2
const E_COLOR := 3
const E_CELL := 4

## Registers a part and returns its id. material == null keeps the mesh's own
## surface materials (instance colour is then ignored).
func add_part(mesh: Mesh, material: Material = null, shadows: bool = false) -> int:
	_parts.append({"mesh": mesh, "material": material, "shadows": shadows})
	return _parts.size() - 1

## Swaps the mesh every instance of a part draws (tree detail setting).
## Instances and their transforms are untouched.
func set_part_mesh(part: int, mesh: Mesh) -> void:
	_parts[part]["mesh"] = mesh
	for b in _buckets.values():
		if int(b["part"]) == part:
			(b["mm"] as MultiMesh).mesh = mesh

func part_mesh(part: int) -> Mesh:
	return _parts[part]["mesh"]

## Replaces the cell's instances. instances: [[part_id, Transform3D, Color], ...]
func set_cell(cell: Vector2i, instances: Array) -> void:
	remove_cell(cell)
	if instances.is_empty():
		return
	var chunk := _chunk_of(cell)
	var list: Array = []
	for inst in instances:
		var e: Array = [_bucket_key(int(inst[0]), chunk), 0, inst[1] as Transform3D, inst[2] as Color, cell]
		_alloc(e)
		list.append(e)
	_cells[cell] = list

func remove_cell(cell: Vector2i) -> void:
	var list: Array = _cells.get(cell, [])
	for e in list:
		_free(e)
	_cells.erase(cell)
	_hidden.erase(cell)

func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)

func clear() -> void:
	for b in _buckets.values():
		(b["mm"] as MultiMesh).instance_count = 0
		b["used"] = 0
		(b["owners"] as Array).clear()
	_cells.clear()
	_hidden.clear()

func set_hidden(cell: Vector2i, hidden: bool) -> void:
	if hidden == _hidden.has(cell):
		return
	if hidden:
		_hidden[cell] = true
	else:
		_hidden.erase(cell)
	for e in _cells.get(cell, []):
		_write(e)

func is_hidden(cell: Vector2i) -> bool:
	return _hidden.has(cell)

## Total live instances (all parts).
func instance_count() -> int:
	var n := 0
	for b in _buckets.values():
		n += int(b["used"])
	return n

func part_count() -> int:
	return _parts.size()

## MultiMeshes in use (upper bound on this batch's draw calls).
func bucket_count() -> int:
	var n := 0
	for b in _buckets.values():
		if int(b["used"]) > 0:
			n += 1
	return n

func part_instance_count(part: int) -> int:
	var n := 0
	for b in _buckets.values():
		if int(b["part"]) == part:
			n += int(b["used"])
	return n

func cell_instances(cell: Vector2i) -> Array:
	return _cells.get(cell, [])

## Transform written for an entry (its own, or collapsed while hidden).
func effective_transform(e: Array) -> Transform3D:
	var xf: Transform3D = e[E_XF]
	if _hidden.has(e[E_CELL]):
		return Transform3D(_HIDE_BASIS, xf.origin)
	return xf

## True when every live entry owns the slot it claims and sits inside its
## bucket's culling box (test hook).
func slots_consistent() -> bool:
	var live := 0
	for cell in _cells:
		for e in _cells[cell]:
			var b: Dictionary = _buckets[e[E_BUCKET]]
			if e[E_SLOT] >= int(b["used"]) or not is_same((b["owners"] as Array)[e[E_SLOT]], e):
				return false
			if not (b["mm"] as MultiMesh).custom_aabb.has_point((e[E_XF] as Transform3D).origin):
				return false
			live += 1
	return live == instance_count()

# ── Chunks / buckets ──────────────────────────────────────────────────────────

static func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_CELLS), floori(float(cell.y) / CHUNK_CELLS))

static func _bucket_key(part: int, chunk: Vector2i) -> Vector3i:
	return Vector3i(part, chunk.x, chunk.y)

func _bucket(key: Vector3i) -> Dictionary:
	if _buckets.has(key):
		return _buckets[key]
	var part: Dictionary = _parts[key.x]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = part["mesh"]
	mm.instance_count = 0
	# Fixed culling box = the chunk's ground area (+ overhang, + height). Unused
	# and hidden slots then can't stretch the box.
	var span := CHUNK_CELLS * CELL_SIZE
	var lo := Vector3(key.y * span - CELL_SIZE * 0.5 - AABB_PAD, AABB_Y0, key.z * span - CELL_SIZE * 0.5 - AABB_PAD)
	mm.custom_aabb = AABB(lo, Vector3(span + AABB_PAD * 2.0, AABB_Y1 - AABB_Y0, span + AABB_PAD * 2.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = part["material"]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part["shadows"] \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var b := {"mm": mm, "used": 0, "owners": [], "part": key.x}
	_buckets[key] = b
	return b

# ── Slot management ───────────────────────────────────────────────────────────

func _alloc(e: Array) -> void:
	var b := _bucket(e[E_BUCKET])
	var mm: MultiMesh = b["mm"]
	var used: int = b["used"]
	if used >= mm.instance_count:
		_grow(b, maxi(32, mm.instance_count * 2))
	(b["owners"] as Array)[used] = e
	b["used"] = used + 1
	mm.visible_instance_count = used + 1
	e[E_SLOT] = used
	_write(e)

func _free(e: Array) -> void:
	var b: Dictionary = _buckets[e[E_BUCKET]]
	var owners: Array = b["owners"]
	var last: int = int(b["used"]) - 1
	var slot: int = e[E_SLOT]
	if slot != last:
		var moved: Array = owners[last]
		moved[E_SLOT] = slot
		owners[slot] = moved
		_write(moved)
	owners[last] = null
	b["used"] = last
	(b["mm"] as MultiMesh).visible_instance_count = last

## Resizing a MultiMesh clears its buffer, so live slots are rewritten.
func _grow(b: Dictionary, cap: int) -> void:
	var mm: MultiMesh = b["mm"]
	var owners: Array = b["owners"]
	mm.instance_count = cap
	owners.resize(cap)
	mm.visible_instance_count = int(b["used"])
	for s in int(b["used"]):
		_write(owners[s])

func _write(e: Array) -> void:
	var mm: MultiMesh = _buckets[e[E_BUCKET]]["mm"]
	mm.set_instance_transform(e[E_SLOT], effective_transform(e))
	mm.set_instance_color(e[E_SLOT], e[E_COLOR])
