## Course Analytics overlay: rating / happiness / prestige breakdowns with tips.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._analytics_vbox:
		return
	for c in host._analytics_vbox.get_children():
		c.queue_free()

	var world := GameManager.world as GameWorld3D

	# Header
	var header := HBoxContainer.new()
	var title_m := MarginContainer.new()
	title_m.add_theme_constant_override("margin_left", 4)
	title_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_lbl := Label.new()
	title_lbl.text = "📊 Course Analytics"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_m.add_child(title_lbl)
	header.add_child(title_m)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(func() -> void: host._analytics_overlay.visible = false)
	header.add_child(close_btn)
	host._analytics_vbox.add_child(header)
	host._analytics_vbox.add_child(HSeparator.new())

	# ── RATING ──────────────────────────────────────────────────────────────────
	host._analytics_vbox.add_child(UI.make_section("⭐ Course Rating"))

	if not world:
		host._analytics_vbox.add_child(UI.make_small_hint("No course loaded."))
	else:
		var rating := world.get_course_rating()
		var stars := ""
		for i in 5:
			stars += "★" if float(i) < rating else "☆"
		var r_col := Color(0.3, 0.95, 0.4) if rating >= 4.0 else (Color(1.0, 0.85, 0.3) if rating >= 2.5 else Color(0.95, 0.35, 0.35))
		var star_lbl := Label.new()
		star_lbl.text = "%s  %.2f / 5.00" % [stars, rating]
		star_lbl.add_theme_font_size_override("font_size", 18)
		star_lbl.add_theme_color_override("font_color", r_col)
		host._analytics_vbox.add_child(star_lbl)

		var rb := world.get_rating_breakdown()
		var below3: int  = rb.get("below_3",    0) as int
		var above4: int  = rb.get("above_4",    0) as int
		var h_count: int = rb.get("hole_count", 0) as int
		host._analytics_vbox.add_child(UI.make_row("  Holes ≥4★", "%d / %d" % [above4, h_count],
			Color(0.4, 1.0, 0.5) if above4 == h_count and h_count > 0 else Color(0.85, 0.85, 0.85)))
		if below3 > 0:
			host._analytics_vbox.add_child(UI.make_row("  Holes <3★ ⚠", str(below3), Color(1.0, 0.55, 0.25)))
		host._analytics_vbox.add_child(UI.make_row("  Course bonus", "+%.2f★ (variety %.2f, amenities %.2f)" % [
			float(rb.get("bonus", 0.0)), float(rb.get("variety", 0.0)), float(rb.get("amenities", 0.0))],
			Color(0.85, 0.85, 0.85)))

		var per_hole := world.get_per_hole_breakdown()
		if not per_hole.is_empty():
			host._analytics_vbox.add_child(HSeparator.new())
			host._analytics_vbox.add_child(UI.make_small_hint("Per-hole breakdown:"))
			for h in per_hole:
				var hd: Dictionary = h as Dictionary
				var hole_num: int  = hd.get("hole_num",      0)   as int
				var total: float   = hd.get("total",         0.0) as float
				var h_stars := ""
				for i in 5:
					h_stars += "★" if float(i) < total else "☆"
				var h_col: Color
				if   total >= 4.0: h_col = Color(0.06, 0.18, 0.08, 0.85)
				elif total >= 2.5: h_col = Color(0.18, 0.14, 0.04, 0.85)
				else:              h_col = Color(0.20, 0.06, 0.06, 0.85)
				var hcard := PanelContainer.new()
				var hcsb := StyleBoxFlat.new()
				hcsb.bg_color = h_col
				hcsb.corner_radius_top_left     = 4
				hcsb.corner_radius_top_right    = 4
				hcsb.corner_radius_bottom_left  = 4
				hcsb.corner_radius_bottom_right = 4
				hcard.add_theme_stylebox_override("panel", hcsb)
				hcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				host._analytics_vbox.add_child(hcard)
				var hcm := MarginContainer.new()
				hcm.add_theme_constant_override("margin_left",   8)
				hcm.add_theme_constant_override("margin_right",  8)
				hcm.add_theme_constant_override("margin_top",    6)
				hcm.add_theme_constant_override("margin_bottom", 6)
				hcard.add_child(hcm)
				var hcv := VBoxContainer.new()
				hcv.add_theme_constant_override("separation", 2)
				hcm.add_child(hcv)
				var top_row := HBoxContainer.new()
				var h_name := Label.new()
				h_name.text = "Hole %d" % hole_num
				h_name.add_theme_font_size_override("font_size", 13)
				h_name.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
				h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				top_row.add_child(h_name)
				var h_star_lbl := Label.new()
				h_star_lbl.text = "%s %.2f" % [h_stars, total]
				h_star_lbl.add_theme_font_size_override("font_size", 13)
				var hsc := Color(0.3, 0.95, 0.4) if total >= 4.0 else (Color(1.0, 0.85, 0.3) if total >= 2.5 else Color(0.95, 0.35, 0.35))
				h_star_lbl.add_theme_color_override("font_color", hsc)
				top_row.add_child(h_star_lbl)
				hcv.add_child(top_row)
				var parts: Dictionary = hd.get("parts", {}) as Dictionary
				var sub_lbl := Label.new()
				sub_lbl.text = "Par %d · %dm   Len %.1f  Fair %.1f  Chal %.1f  Frame %.1f  Shape %.1f" % [
					int(hd.get("par", 3)), int(hd.get("distance", 0)),
					float(parts.get("length", 0.0)), float(parts.get("fairway", 0.0)), float(parts.get("challenge", 0.0)),
					float(parts.get("framing", 0.0)), float(parts.get("shape", 0.0))]
				sub_lbl.add_theme_font_size_override("font_size", 10)
				sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
				hcv.add_child(sub_lbl)
				var tips: Array = hd.get("tips", []) as Array
				if not tips.is_empty():
					var tip_lbl := Label.new()
					tip_lbl.text = "↑ " + str(tips[0])
					tip_lbl.add_theme_font_size_override("font_size", 11)
					tip_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
					tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					hcv.add_child(tip_lbl)

	host._analytics_vbox.add_child(HSeparator.new())

	# ── HAPPINESS ───────────────────────────────────────────────────────────────
	host._analytics_vbox.add_child(UI.make_section("😊 Player Happiness"))

	var hap_val := EconomyManager.current_happiness
	var hap_pct := int(hap_val * 100.0)
	var mood: String
	if   hap_pct >= 80: mood = "😊 Excellent"
	elif hap_pct >= 60: mood = "🙂 Good"
	elif hap_pct >= 40: mood = "😐 Fair"
	elif hap_pct >= 20: mood = "😕 Poor"
	else:               mood = "😞 Critical"
	var hap_disp := Label.new()
	hap_disp.text = "%d%%  %s" % [hap_pct, mood]
	hap_disp.add_theme_font_size_override("font_size", 16)
	var hc := Color(0.3, 0.95, 0.4) if hap_pct >= 70 else (Color(1.0, 0.85, 0.3) if hap_pct >= 40 else Color(0.95, 0.35, 0.3))
	hap_disp.add_theme_color_override("font_color", hc)
	host._analytics_vbox.add_child(hap_disp)

	if world:
		var hb := world.get_happiness_breakdown()
		var h_components := [
			{n = "Course Quality", k = "quality",  w = 0.48, tip = "Improve hole ratings — see each hole's tip above (length for par, fairway, hazards, framing, shape)"},
			{n = "Restrooms",      k = "restrooms",w = 0.19, tip = "Build more Restrooms (each adds significant capacity)"},
			{n = "Food Stands",    k = "food",     w = 0.14, tip = "Build Food Stands to reduce hunger/thirst complaints"},
			{n = "Pro Shop",       k = "pro_shop", w = 0.14, tip = "Build one Pro Shop — one-time 14% happiness bonus"},
			{n = "Decor",          k = "decor",    w = 0.05, tip = "Place Benches, Flower Beds, Sculptures near holes (cap: 20 pieces)"},
		]
		for comp in h_components:
			var cd: Dictionary = comp as Dictionary
			var val: float = (hb.get(cd["k"] as String, 0.0) as float) * 100.0
			var wt: float  = (cd["w"] as float) * 100.0
			var pts: float = (cd["w"] as float) * val
			var vc := Color(0.4, 1.0, 0.5) if val >= 80.0 else (Color(1.0, 0.85, 0.3) if val >= 40.0 else Color(0.95, 0.35, 0.35))
			var comp_row := HBoxContainer.new()
			var comp_lbl := Label.new()
			comp_lbl.text = "  %s (%.0f%%)" % [cd["n"] as String, wt]
			comp_lbl.custom_minimum_size = Vector2(210, 0)
			comp_lbl.add_theme_font_size_override("font_size", 12)
			comp_row.add_child(comp_lbl)
			var val_lbl := Label.new()
			val_lbl.text = "%.0f%% → %.1f pts" % [val, pts]
			val_lbl.add_theme_color_override("font_color", vc)
			val_lbl.add_theme_font_size_override("font_size", 12)
			comp_row.add_child(val_lbl)
			host._analytics_vbox.add_child(comp_row)
			var comp_bar := ProgressBar.new()
			comp_bar.max_value = 100.0
			comp_bar.value = val
			comp_bar.show_percentage = false
			comp_bar.custom_minimum_size = Vector2(0, 10)
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = vc
			comp_bar.add_theme_stylebox_override("fill", bsb)
			host._analytics_vbox.add_child(comp_bar)
			if val < 70.0:
				host._analytics_vbox.add_child(UI.make_small_hint("  ↑ " + (cd["tip"] as String)))
		host._analytics_vbox.add_child(UI.make_small_hint(
			"Built — Restrooms: %d  Food: %d  Pro Shop: %s  Decor: %d" % [
				hb.get("restroom_count", 0) as int,
				hb.get("food_count",     0) as int,
				"✓" if (hb.get("pro_count", 0) as int) > 0 else "✗",
				hb.get("decor_count",    0) as int,
			]))

	host._analytics_vbox.add_child(HSeparator.new())

	# ── PRESTIGE ─────────────────────────────────────────────────────────────────
	host._analytics_vbox.add_child(UI.make_section("🏆 Course Prestige"))

	var prestige := EconomyManager.get_prestige()
	var tier     := EconomyManager.get_prestige_tier()
	var p_bar := ProgressBar.new()
	p_bar.max_value = 100.0
	p_bar.value = prestige
	p_bar.show_percentage = false
	p_bar.custom_minimum_size = Vector2(0, 16)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.25, 0.70, 1.0).lerp(Color(1.0, 0.85, 0.0), prestige / 100.0)
	p_bar.add_theme_stylebox_override("fill", psb)
	host._analytics_vbox.add_child(p_bar)
	var prestige_lbl := Label.new()
	prestige_lbl.text = "%.0f / 100  —  %s" % [prestige, tier]
	prestige_lbl.add_theme_font_size_override("font_size", 15)
	prestige_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	host._analytics_vbox.add_child(prestige_lbl)

	# Tier ladder
	var tiers_list := [
		{name = "Local Gem",           threshold = 0.0},
		{name = "Regional Favorite",   threshold = 25.0},
		{name = "National Destination",threshold = 55.0},
		{name = "World Class",         threshold = 80.0},
	]
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 4)
	for td in tiers_list:
		var tdd: Dictionary = td as Dictionary
		var thresh: float = tdd["threshold"] as float
		var t_lbl := Label.new()
		t_lbl.text = ("✓ " if prestige >= thresh else "○ ") + (tdd["name"] as String)
		t_lbl.add_theme_font_size_override("font_size", 10)
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.2) if prestige >= thresh else Color(0.40, 0.40, 0.40))
		tier_row.add_child(t_lbl)
	host._analytics_vbox.add_child(tier_row)

	# Prestige component breakdown
	var p_components := [
		{label = "Course Rating",  pts = "rating_pts",   mx = "rating_max",    tip = "Improve hole quality — length for par, fairway, two hazard types, framing, doglegs"},
		{label = "Happiness",      pts = "happiness_pts", mx = "happiness_max", tip = "Boost happiness via restrooms, food stands, pro shop, decor"},
		{label = "Facilities",     pts = "facility_pts",  mx = "facility_max",  tip = "Build restrooms, food stands, pro shop, and parking lots"},
		{label = "Tournaments",    pts = "tourney_pts",   mx = "tourney_max",   tip = "Run tournaments (need 6 holes) — up to 5 count toward prestige"},
		{label = "Goals",          pts = "goal_pts",      mx = "goal_max",      tip = "Complete milestones — check the Goals panel"},
	]
	var pbd := EconomyManager.get_prestige_breakdown()
	for pc in p_components:
		var pcd: Dictionary = pc as Dictionary
		var pts_val: float = pbd.get(pcd["pts"] as String, 0.0) as float
		var max_val: float = pbd.get(pcd["mx"]  as String, 1.0) as float
		var pct: float = pts_val / maxf(max_val, 0.001)
		var pvc := Color(0.4, 1.0, 0.5) if pct >= 0.80 else (Color(1.0, 0.85, 0.3) if pct >= 0.40 else Color(0.95, 0.35, 0.35))
		var pc_row := HBoxContainer.new()
		var pc_lbl := Label.new()
		pc_lbl.text = "  %s (%.0f pts max)" % [pcd["label"] as String, max_val]
		pc_lbl.custom_minimum_size = Vector2(220, 0)
		pc_lbl.add_theme_font_size_override("font_size", 12)
		pc_row.add_child(pc_lbl)
		var pc_val := Label.new()
		pc_val.text = "%.1f / %.0f" % [pts_val, max_val]
		pc_val.add_theme_color_override("font_color", pvc)
		pc_val.add_theme_font_size_override("font_size", 12)
		pc_row.add_child(pc_val)
		host._analytics_vbox.add_child(pc_row)
		var pc_bar := ProgressBar.new()
		pc_bar.max_value = max_val
		pc_bar.value = pts_val
		pc_bar.show_percentage = false
		pc_bar.custom_minimum_size = Vector2(0, 10)
		var pbsb := StyleBoxFlat.new()
		pbsb.bg_color = pvc
		pc_bar.add_theme_stylebox_override("fill", pbsb)
		host._analytics_vbox.add_child(pc_bar)
		if pct < 0.80:
			host._analytics_vbox.add_child(UI.make_small_hint("  ↑ " + (pcd["tip"] as String)))

	# Next tier unlock tip
	var next_thresh := 0.0
	var next_name := ""
	for td in tiers_list:
		var tdd: Dictionary = td as Dictionary
		var thresh: float = tdd["threshold"] as float
		if prestige < thresh:
			next_thresh = thresh
			next_name   = tdd["name"] as String
			break
	if next_name != "":
		var gap_lbl := Label.new()
		gap_lbl.text = "Need %.0f more prestige to unlock: %s" % [next_thresh - prestige, next_name]
		gap_lbl.add_theme_font_size_override("font_size", 12)
		gap_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		gap_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._analytics_vbox.add_child(gap_lbl)
