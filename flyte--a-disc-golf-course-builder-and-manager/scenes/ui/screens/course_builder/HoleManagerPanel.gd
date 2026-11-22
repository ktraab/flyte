## Hole Manager overlay contents (reorder, par, colour, preview per hole).
## Extracted from CourseBuilder.gd (2026-11). `host` is the CourseBuilder screen;
## this class holds the logic, the screen keeps the nodes and thin delegates.
extends RefCounted

var host: Control

func _init(h: Control) -> void:
	host = h

func _refresh_hole_manager() -> void:
	if not host._n_holes_vbox:
		return
	for child in host._n_holes_vbox.get_children():
		child.queue_free()
	if not GameManager.world:
		return

	var world := GameManager.world as GameWorld3D
	var holes := world.get_holes_info()
	var total_par  := 0
	var total_dist := 0

	for h in holes:
		var hole_num: int      = h["hole_num"] as int
		var par:      int      = h["par"] as int
		var dist:     int      = h["distance"] as int
		var tc:       Vector2i = h["tee_cell"] as Vector2i
		var idx:      int      = h["index"] as int
		total_par  += par
		total_dist += dist

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 52)
		host._n_holes_vbox.add_child(row)

		# Hole preview thumbnail (pixel-art mini-map)
		var preview_img: Image = world.get_hole_preview_image(hole_num)
		var preview_tex := ImageTexture.create_from_image(preview_img)
		var preview_rect := TextureRect.new()
		preview_rect.texture = preview_tex
		preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_rect.custom_minimum_size = Vector2(72, 52)
		preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(preview_rect)

		# Colored badge — uses custom color or default
		var current_color: Color = _get_hole_color(world, hole_num)
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(40, 40)
		badge.modulate = current_color
		row.add_child(badge)

		var hole_lbl := Label.new()
		hole_lbl.text = "Hole %d" % hole_num
		hole_lbl.custom_minimum_size = Vector2(72, 0)
		hole_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hole_lbl)

		# Color selector
		var color_opt := OptionButton.new()
		color_opt.custom_minimum_size = Vector2(90, 44)
		var color_names := ["Red","Blue","Yellow","Green","Purple","Orange","White","Cyan","Pink","Lime"]
		for ci in host.HOLE_COLOR_OPTIONS.size():
			color_opt.add_item(color_names[ci])
		# Find closest matching index
		var best_idx := 0
		var best_dist := 9999.0
		for ci in host.HOLE_COLOR_OPTIONS.size():
			var c: Color = host.HOLE_COLOR_OPTIONS[ci] as Color
			var cd: float = absf(c.r - current_color.r) + absf(c.g - current_color.g) + absf(c.b - current_color.b)
			if cd < best_dist:
				best_dist = cd
				best_idx  = ci
		color_opt.selected = best_idx
		var hn_copy := hole_num
		var badge_ref := badge
		color_opt.item_selected.connect(func(ci: int) -> void:
			var chosen: Color = host.HOLE_COLOR_OPTIONS[ci] as Color
			badge_ref.modulate = chosen
			(GameManager.world as GameWorld3D).set_hole_color(hn_copy, chosen)
		)
		row.add_child(color_opt)

		var par_lbl := Label.new()
		par_lbl.text = "Par"
		par_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(par_lbl)

		var par_spin := SpinBox.new()
		par_spin.min_value = 3
		par_spin.max_value = 5
		par_spin.value     = par
		par_spin.custom_minimum_size = Vector2(80, 44)
		var tc_copy := tc
		par_spin.value_changed.connect(func(v: float) -> void:
			(GameManager.world as GameWorld3D).set_hole_par(tc_copy, int(v))
		)
		row.add_child(par_spin)

		var dist_lbl := Label.new()
		dist_lbl.text = "%dm" % dist
		dist_lbl.custom_minimum_size = Vector2(54, 0)
		dist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(dist_lbl)

		var hole_rating := world.get_hole_rating(h)
		var stars_str := ""
		for si in 5:
			stars_str += "★" if float(si) < hole_rating else "☆"
		var rating_lbl := Label.new()
		rating_lbl.text = stars_str
		rating_lbl.custom_minimum_size = Vector2(72, 0)
		rating_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rating_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		row.add_child(rating_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		if idx > 0:
			var up_btn := Button.new()
			up_btn.text = "▲"
			up_btn.custom_minimum_size = Vector2(40, 44)
			var idx_copy := idx
			up_btn.pressed.connect(func() -> void:
				(GameManager.world as GameWorld3D).reorder_holes(idx_copy, idx_copy - 1)
				_refresh_hole_manager()
			)
			row.add_child(up_btn)

		if idx < holes.size() - 1:
			var dn_btn := Button.new()
			dn_btn.text = "▼"
			dn_btn.custom_minimum_size = Vector2(40, 44)
			var idx_copy := idx
			dn_btn.pressed.connect(func() -> void:
				(GameManager.world as GameWorld3D).reorder_holes(idx_copy, idx_copy + 1)
				_refresh_hole_manager()
			)
			row.add_child(dn_btn)

		# Separator between rows
		host._n_holes_vbox.add_child(HSeparator.new())

	if host._n_hm_total_label:
		host._n_hm_total_label.text = "Holes: %d  |  Total Par: %d  |  Total Distance: %dm" % \
			[holes.size(), total_par, total_dist]

func _get_hole_color(world: GameWorld3D, hole_num: int) -> Color:
	# Check if there's a custom color stored in world
	if world._hole_custom_colors.has(hole_num):
		return world._hole_custom_colors[hole_num] as Color
	return GameWorld3D.HOLE_FLAG_COLORS[(hole_num - 1) % GameWorld3D.HOLE_FLAG_COLORS.size()] as Color

# -- Route editing ----------------------------------------------------------------
