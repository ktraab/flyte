## Builds the Hole Architect overlay UI (routing, templates, critique) and wires it to CourseBuilder handlers.
## Extracted from CourseBuilder.gd (2026-11). `host` is the CourseBuilder screen;
## this class holds the logic, the screen keeps the nodes and thin delegates.
extends RefCounted

var host: Control

func _init(h: Control) -> void:
	host = h

func _build_architect_overlay() -> void:
	var overlay := PanelContainer.new()
	overlay.name = "ArchitectPanel"
	overlay.visible = false
	overlay.anchor_left   = 1.0
	overlay.anchor_top    = 0.5
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 0.5
	overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	overlay.grow_vertical   = Control.GROW_DIRECTION_BOTH
	overlay.offset_left   = -390.0
	overlay.offset_top    = -320.0
	overlay.offset_right  = -4.0
	overlay.offset_bottom = 320.0
	host.add_child(overlay)
	host._n_architect_overlay = overlay

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "Architect"
	title_lbl.add_theme_font_size_override("font_size", 16)
	header.add_child(title_lbl)
	host._n_arch_prev_btn = Button.new()
	host._n_arch_prev_btn.text = " < "
	host._n_arch_prev_btn.custom_minimum_size = Vector2(44, 44)
	host._n_arch_prev_btn.pressed.connect(host._on_arch_prev_hole)
	header.add_child(host._n_arch_prev_btn)
	host._n_arch_hole_label = Label.new()
	host._n_arch_hole_label.text = "Hole 1"
	host._n_arch_hole_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	host._n_arch_hole_label.add_theme_font_size_override("font_size", 13)
	host._n_arch_hole_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(host._n_arch_hole_label)
	host._n_arch_next_btn = Button.new()
	host._n_arch_next_btn.text = " > "
	host._n_arch_next_btn.custom_minimum_size = Vector2(44, 44)
	host._n_arch_next_btn.pressed.connect(host._on_arch_next_hole)
	header.add_child(host._n_arch_next_btn)
	var hdr_spacer := Control.new()
	hdr_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hdr_spacer)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(host._on_close_architect_pressed)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# TabContainer
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)

	# ── Tab: Routing ──────────────────────────────────────────────────────────
	var route_box := VBoxContainer.new()
	route_box.name = "Routing"
	route_box.add_theme_constant_override("separation", 6)
	tabs.add_child(route_box)

	host._n_arch_wp_label = Label.new()
	host._n_arch_wp_label.text = "Route waypoints: 0"
	host._n_arch_wp_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	route_box.add_child(host._n_arch_wp_label)

	var hint := Label.new()
	hint.text = "Select a Tee tile → Edit Route to add\nwaypoints, then paint fairway below."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 11)
	route_box.add_child(hint)

	route_box.add_child(HSeparator.new())

	var width_row := HBoxContainer.new()
	route_box.add_child(width_row)
	var wlbl := Label.new()
	wlbl.text = "Fairway width (cells):"
	wlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_row.add_child(wlbl)
	host._n_arch_width_spin = SpinBox.new()
	host._n_arch_width_spin.min_value = 1
	host._n_arch_width_spin.max_value = 7
	host._n_arch_width_spin.value = 3
	host._n_arch_width_spin.custom_minimum_size = Vector2(72, 0)
	width_row.add_child(host._n_arch_width_spin)

	var auto_btn := Button.new()
	auto_btn.text = "Auto-Route: Straight Line"
	auto_btn.custom_minimum_size = Vector2(0, 44)
	auto_btn.pressed.connect(host._on_auto_route_pressed)
	route_box.add_child(auto_btn)

	var paint_btn := Button.new()
	paint_btn.text = "Paint Route as Fairway"
	paint_btn.custom_minimum_size = Vector2(0, 44)
	paint_btn.pressed.connect(host._on_paint_route_pressed)
	route_box.add_child(paint_btn)

	var rough_btn := Button.new()
	rough_btn.text = "Add Rough Border"
	rough_btn.custom_minimum_size = Vector2(0, 44)
	rough_btn.pressed.connect(host._on_add_rough_border_pressed)
	route_box.add_child(rough_btn)

	# ── Tab: Templates ────────────────────────────────────────────────────────
	var tmpl_box := VBoxContainer.new()
	tmpl_box.name = "Templates"
	tmpl_box.add_theme_constant_override("separation", 4)
	tabs.add_child(tmpl_box)

	# Hole picker row
	var hole_row := HBoxContainer.new()
	hole_row.add_theme_constant_override("separation", 6)
	var hole_lbl2 := Label.new()
	hole_lbl2.text = "Hole:"
	hole_lbl2.add_theme_font_size_override("font_size", 13)
	hole_lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hole_row.add_child(hole_lbl2)
	var tmpl_hole_spin := SpinBox.new()
	tmpl_hole_spin.min_value = 1
	tmpl_hole_spin.max_value = 18
	tmpl_hole_spin.step      = 1
	tmpl_hole_spin.value     = host._tmpl_hole_num
	tmpl_hole_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tmpl_hole_spin.value_changed.connect(func(v: float) -> void: host._tmpl_hole_num = int(v))
	hole_row.add_child(tmpl_hole_spin)
	tmpl_box.add_child(hole_row)

	var tlbl := Label.new()
	tlbl.text = "If tee already placed: fills layout + moves basket.\nIf no tee: select TEE tool, place it, template auto-applies."
	tlbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tlbl.add_theme_font_size_override("font_size", 11)
	tlbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	tmpl_box.add_child(tlbl)
	tmpl_box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tmpl_box.add_child(scroll)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 4)
	scroll.add_child(sv)

	for tname: String in HoleTemplates.get_names():
		var info := HoleTemplates.get_info(tname)
		var par_v: int  = info.get("par", 3) as int
		var dist_v: int = info.get("distance_m", 0) as int
		# Estimate tile cost from TILE_COSTS (basket relocation is free — already placed)
		var est_cost := 0.0
		for tile_entry: Dictionary in (info.get("tiles", []) as Array):
			var tt: int = (tile_entry as Dictionary).get("type", 0) as int
			est_cost += GameWorld3D.TILE_COSTS.get(tt, 0.0) as float

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		sv.add_child(card)

		var header_row := HBoxContainer.new()
		card.add_child(header_row)
		var nlbl := Label.new()
		nlbl.text = tname
		nlbl.add_theme_font_size_override("font_size", 13)
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(nlbl)
		var dist_lbl := Label.new()
		dist_lbl.text = "~%dm" % dist_v
		dist_lbl.add_theme_font_size_override("font_size", 11)
		dist_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_row.add_child(dist_lbl)

		var dlbl := Label.new()
		dlbl.text = info.get("description", "") as String
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		dlbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		dlbl.add_theme_font_size_override("font_size", 10)
		card.add_child(dlbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "Est. cost: $%s" % host._fmt_bal(est_cost)
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		card.add_child(cost_lbl)

		var abtn := Button.new()
		abtn.text = "Apply Template"
		abtn.custom_minimum_size = Vector2(0, 44)
		var tn := tname
		abtn.pressed.connect(func(): host._on_apply_template_pressed(tn))
		card.add_child(abtn)
		sv.add_child(HSeparator.new())

	# ── Tab: Critique ─────────────────────────────────────────────────────────
	var crit_outer := VBoxContainer.new()
	crit_outer.name = "Critique"
	crit_outer.add_theme_constant_override("separation", 6)
	tabs.add_child(crit_outer)

	var analyze_btn := Button.new()
	analyze_btn.text = "Analyze Hole"
	analyze_btn.custom_minimum_size = Vector2(0, 44)
	analyze_btn.pressed.connect(host._on_critique_pressed)
	crit_outer.add_child(analyze_btn)

	crit_outer.add_child(HSeparator.new())

	var crit_scroll := ScrollContainer.new()
	crit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crit_outer.add_child(crit_scroll)

	var crit_box := VBoxContainer.new()
	crit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crit_box.add_theme_constant_override("separation", 6)
	crit_scroll.add_child(crit_box)

	var grade_row := HBoxContainer.new()
	crit_box.add_child(grade_row)
	host._n_arch_grade_label = Label.new()
	host._n_arch_grade_label.text = "—"
	host._n_arch_grade_label.add_theme_font_size_override("font_size", 44)
	host._n_arch_grade_label.custom_minimum_size = Vector2(70, 0)
	host._n_arch_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._n_arch_grade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_row.add_child(host._n_arch_grade_label)
	var score_col := VBoxContainer.new()
	score_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grade_row.add_child(score_col)
	host._n_arch_score_label = Label.new()
	host._n_arch_score_label.text = "—"
	host._n_arch_score_label.add_theme_font_size_override("font_size", 24)
	score_col.add_child(host._n_arch_score_label)
	var pts_lbl := Label.new()
	pts_lbl.text = "/ 100 pts"
	pts_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	score_col.add_child(pts_lbl)

	crit_box.add_child(HSeparator.new())

	host._n_arch_critique_text = RichTextLabel.new()
	host._n_arch_critique_text.bbcode_enabled = true
	host._n_arch_critique_text.fit_content = true
	host._n_arch_critique_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._n_arch_critique_text.custom_minimum_size = Vector2(0, 80)
	host._n_arch_critique_text.text = "[color=gray]Press Analyze to evaluate this hole.[/color]"
	crit_box.add_child(host._n_arch_critique_text)
