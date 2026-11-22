## Instanced props (scenes/game_world/PropBatch.gd): trees, rough grass and sand
## are MultiMesh instances — few draw calls, every instance still drawn.
extends "res://tests/TestCase.gd"

const PropBatch = preload("res://scenes/game_world/PropBatch.gd")
const TREE := 5
const ROUGH := 4
const SAND := 13
const GRASS := 0

func before_each() -> void:
	await goto_state(gm().GameState.GAMEPLAY)
	await quiet_story()

func _w() -> Node:
	return gm().world

## Instance at cell column x (2 m cells), like real props.
func _xf(x: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x * 2.0, 0, 0))

func _consistent(b: Node) -> bool:
	return b.call("slots_consistent")

func _tree_cells() -> Array:
	var out := []
	var tiles: Dictionary = _w().get("_tiles")
	for c in tiles:
		if int(tiles[c]) == TREE:
			out.append(c)
	return out

func test_batch_swap_remove_keeps_slots_consistent() -> void:
	var b: Node3D = PropBatch.new()
	tree.root.add_child(b)
	var p: int = b.call("add_part", BoxMesh.new())
	for i in 100:
		b.call("set_cell", Vector2i(i, 0), [[p, _xf(i), Color.WHITE], [p, _xf(i + 0.5), Color.RED]])
	check_eq(b.call("part_instance_count", p), 200, "two instances per cell")
	for i in range(0, 100, 3):
		b.call("remove_cell", Vector2i(i, 0))
	check_eq(b.call("part_instance_count", p), 200 - 34 * 2, "removed cells free their slots")
	check(_consistent(b), "swap-remove leaves every entry pointing at its own data")
	b.call("set_cell", Vector2i(1, 0), [[p, _xf(1.5), Color.WHITE]])
	check(_consistent(b), "replacing a cell keeps slots consistent")
	b.call("clear")
	check_eq(b.call("instance_count"), 0, "clear empties the batch")
	b.free()

## Parts are split into map chunks so off-screen chunks can be skipped; each
## chunk's culling box must contain its instances (else trees would vanish).
func test_batch_splits_parts_into_chunks() -> void:
	var b: Node3D = PropBatch.new()
	tree.root.add_child(b)
	var p: int = b.call("add_part", BoxMesh.new())
	var cells := [Vector2i(0, 0), Vector2i(49, 49), Vector2i(50, 0), Vector2i(149, 149)]
	for c in cells:
		var pos := Vector3(c.x * 2.0, 3.0, c.y * 2.0)
		b.call("set_cell", c, [[p, Transform3D(Basis.IDENTITY, pos), Color.WHITE]])
	check_eq(b.call("bucket_count"), 3, "cells in 3 different chunks → 3 MultiMeshes")
	check_eq(b.call("part_instance_count", p), 4, "instances counted across chunks")
	check(_consistent(b), "every instance inside its chunk's culling box")
	b.free()

func test_batch_hide_collapses_and_restores() -> void:
	var b: Node3D = PropBatch.new()
	tree.root.add_child(b)
	var p: int = b.call("add_part", BoxMesh.new())
	b.call("set_cell", Vector2i(3, 3), [[p, _xf(5.0), Color.WHITE]])
	var e: Array = (b.call("cell_instances", Vector2i(3, 3)) as Array)[0]
	b.call("set_hidden", Vector2i(3, 3), true)
	var hid: Transform3D = b.call("effective_transform", e)
	check(hid.basis.get_scale().length() < 0.001, "hidden instance collapses to a point")
	check(hid.origin.is_equal_approx(Vector3(10, 0, 0)), "hidden instance stays at its spot")
	b.call("set_hidden", Vector2i(3, 3), false)
	check((b.call("effective_transform", e) as Transform3D).is_equal_approx(_xf(5.0)), "unhide restores it")
	b.free()

func test_trees_rough_and_sand_are_instanced_not_nodes() -> void:
	var w := _w()
	var props: Dictionary = w.get("_props")
	var tiles: Dictionary = w.get("_tiles")
	var batch: Node = w.call("get_prop_batch")
	check(batch != null, "world has a prop batch")
	var trees: Array = _tree_cells()
	check(trees.size() > 0, "home course has trees")
	for c in trees:
		check(not props.has(c), "tree %s is not a scene node" % str(c))
		check(batch.call("has_cell", c), "tree %s is in the batch" % str(c))
	for c in tiles:
		var tt := int(tiles[c])
		if tt == ROUGH or tt == SAND:
			check(not props.has(c), "rough/sand %s has no scene node" % str(c))
	var stats: Dictionary = w.call("get_prop_batch_stats")
	check(int(stats["parts"]) < 150, "mesh parts stay bounded (got %d)" % int(stats["parts"]))
	check(int(stats["buckets"]) <= int(stats["parts"]) * 25, "≤ one MultiMesh per part per chunk")
	check(batch.call("slots_consistent"), "every instance inside its chunk's culling box")

func test_painting_updates_instances() -> void:
	var w := _w()
	var batch: Node = w.call("get_prop_batch")
	var tiles: Dictionary = w.get("_tiles")
	# A grass cell with an even hash gets a rough clump (8 blades).
	var cell := Vector2i(-1, -1)
	for c in range(10, 60):
		var v := Vector2i(c, 120)
		if int(tiles.get(v, GRASS)) == GRASS and (int(w.call("_cell_hash", v.x, v.y)) % 2) == 0:
			cell = v
			break
	check(cell.x >= 0, "found a test cell")
	var before: int = batch.call("instance_count")
	var saved: Variant = tiles.get(cell, null)

	tiles[cell] = ROUGH
	w.call("_update_tile_visual", cell, ROUGH, false)
	check_eq((batch.call("cell_instances", cell) as Array).size(), 8, "rough clump = 8 blades")

	tiles[cell] = SAND
	w.call("_update_tile_visual", cell, SAND, false)
	check_eq((batch.call("cell_instances", cell) as Array).size(), 12, "sand = 12 grains")

	tiles[cell] = TREE
	w.call("_update_tile_visual", cell, TREE, false)
	check(batch.call("has_cell", cell), "painted tree is instanced")
	check(not (w.get("_props") as Dictionary).has(cell), "painted tree has no node")

	tiles[cell] = GRASS
	w.call("_update_tile_visual", cell, GRASS, false)
	check(not batch.call("has_cell", cell), "painting grass removes the tree")
	check_eq(batch.call("instance_count"), before, "no leaked instances")
	if saved == null: tiles.erase(cell)
	else: tiles[cell] = saved
	check(_consistent(batch), "batch slots consistent after edits")

func test_reload_does_not_duplicate_instances() -> void:
	var w := _w()
	var batch: Node = w.call("get_prop_batch")
	var before: int = batch.call("instance_count")
	w.call("import_full_state", w.call("export_full_state"))
	check_eq(batch.call("instance_count"), before, "re-import rebuilds the same instances")

func test_tree_occlusion_api() -> void:
	var w := _w()
	var trees: Array = _tree_cells()
	var c: Vector2i = trees[0]
	var p: Vector3 = w.call("_cell_world_pos", c)
	var found: Dictionary = w.call("get_tree_positions_in", Vector2(p.x - 1, p.z - 1), Vector2(p.x + 1, p.z + 1))
	check(found.has(c), "tree found inside its own box")
	w.call("set_tree_hidden", c, true)
	var batch: Node = w.call("get_prop_batch")
	check(batch.call("is_hidden", c), "tree hidden for occlusion")
	w.call("set_tree_hidden", c, false)
	check(not batch.call("is_hidden", c), "tree shown again")
