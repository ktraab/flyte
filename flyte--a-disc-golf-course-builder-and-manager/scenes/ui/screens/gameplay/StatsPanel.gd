## Stats overlay: finances, revenue, players, score distribution, prestige.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._stats_vbox:
		return
	for c in host._stats_vbox.get_children():
		c.queue_free()

	# Header row with title + ✕
	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "Course Analytics"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	header.add_child(title_lbl)
	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(44, 44)
	x_btn.pressed.connect(func() -> void: host._stats_overlay.visible = false)
	header.add_child(x_btn)
	host._stats_vbox.add_child(header)
	host._stats_vbox.add_child(HSeparator.new())

	var prestige := EconomyManager.get_prestige()
	var tier     := EconomyManager.get_prestige_tier()
	host._stats_vbox.add_child(UI.make_row("Prestige", "%.0f / 100  (%s)" % [prestige, tier]))
	var pbar := ProgressBar.new()
	pbar.max_value = 100.0
	pbar.value = prestige
	pbar.show_percentage = false
	pbar.custom_minimum_size = Vector2(0, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.70, 1.0).lerp(Color(1.0, 0.85, 0.0), prestige / 100.0)
	pbar.add_theme_stylebox_override("fill", sb)
	host._stats_vbox.add_child(pbar)

	# Prestige breakdown
	var pw := GameManager.world as GameWorld3D
	if pw:
		var p_rating    := pw.get_course_rating()
		var p_happiness := EconomyManager.current_happiness
		var p_counts    := pw.get_facility_counts()
		var p_fac_score := minf(
			float(p_counts.get("restroom",   0)) * 0.25 +
			float(p_counts.get("food_stand", 0)) * 0.25 +
			(1.0 if p_counts.get("pro_shop", 0) > 0 else 0.0) +
			float(p_counts.get("parking",    0)) * 0.10, 1.0)
		var p_tourney   := minf(float(EconomyManager.get_tournaments_run()) / 5.0, 1.0)
		var p_goals_done := 0
		for g in GoalsSystem.get_all_goals():
			if g.get("completed", false): p_goals_done += 1
		var p_goal := minf(float(p_goals_done) / 12.0, 1.0)
		var bd_lbl := Label.new()
		bd_lbl.add_theme_font_size_override("font_size", 11)
		bd_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		bd_lbl.text = "  Rating %.0f%%  |  Happiness %.0f%%  |  Facilities %.0f%%  |  Tournaments %.0f%%  |  Goals %.0f%%" % [
			p_rating / 5.0 * 35.0, p_happiness * 30.0,
			p_fac_score * 20.0, p_tourney * 10.0, p_goal * 5.0]
		bd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._stats_vbox.add_child(bd_lbl)

	host._stats_vbox.add_child(HSeparator.new())
	host._stats_vbox.add_child(UI.make_section("Revenue (Lifetime)"))
	var rev := EconomyManager.get_revenue_total()
	host._stats_vbox.add_child(UI.make_row("  Green Fees",  "$%s" % UI.fmt(rev.get("green_fee", 0.0) as float)))
	host._stats_vbox.add_child(UI.make_row("  Food Sales",  "$%s" % UI.fmt(rev.get("food", 0.0) as float)))
	host._stats_vbox.add_child(UI.make_row("  Tournaments", "$%s" % UI.fmt(rev.get("tournament", 0.0) as float)))
	host._stats_vbox.add_child(UI.make_row("  Memberships", "$%s" % UI.fmt(rev.get("membership", 0.0) as float)))
	var total_rev := 0.0
	for k in rev: total_rev += rev[k] as float
	host._stats_vbox.add_child(UI.make_row("  Total", "$%s" % UI.fmt(total_rev), Color(0.4, 1.0, 0.5)))

	host._stats_vbox.add_child(HSeparator.new())
	host._stats_vbox.add_child(UI.make_section("Current Players"))
	var tiers := EconomyManager.get_npc_tier_counts()
	host._stats_vbox.add_child(UI.make_row("  Beginner", str(tiers[0])))
	host._stats_vbox.add_child(UI.make_row("  Amateur",  str(tiers[1])))
	host._stats_vbox.add_child(UI.make_row("  Pro",      str(tiers[2])))

	host._stats_vbox.add_child(HSeparator.new())
	host._stats_vbox.add_child(UI.make_section("Operations"))
	host._stats_vbox.add_child(UI.make_row("  Members",     "%d  ($%s/week)" % [
		EconomyManager.get_membership_count(),
		UI.fmt(EconomyManager.get_membership_monthly_income())]))
	host._stats_vbox.add_child(UI.make_row("  Rounds Played",   str(EconomyManager.get_total_rounds())))
	host._stats_vbox.add_child(UI.make_row("  Tournaments Run",  str(EconomyManager.get_tournaments_run())))

	# Score distribution
	var total_holes_scored: int = host._score_condor + host._score_albatross + host._score_eagle + host._score_birdie + host._score_par + host._score_bogey + host._score_double + host._score_worse
	if total_holes_scored > 0:
		host._stats_vbox.add_child(HSeparator.new())
		host._stats_vbox.add_child(UI.make_section("Score Distribution (Session)"))
		if host._score_condor > 0:
			host._stats_vbox.add_child(UI.make_row("  Condor (-4)",    str(host._score_condor),    Color(1.0, 0.85, 0.0)))
		if host._score_albatross > 0:
			host._stats_vbox.add_child(UI.make_row("  Albatross (-3)", str(host._score_albatross), Color(1.0, 0.85, 0.0)))
		if host._score_eagle > 0:
			host._stats_vbox.add_child(UI.make_row("  Eagle (-2)",     str(host._score_eagle),     Color(0.3, 0.95, 0.4)))
		if host._score_birdie > 0:
			host._stats_vbox.add_child(UI.make_row("  Birdie (-1)",    str(host._score_birdie),    Color(0.2, 0.85, 0.3)))
		host._stats_vbox.add_child(UI.make_row("  Par",               str(host._score_par),        Color(0.8, 0.8, 0.8)))
		if host._score_bogey > 0:
			host._stats_vbox.add_child(UI.make_row("  Bogey (+1)",     str(host._score_bogey),     Color(1.0, 0.6, 0.2)))
		if host._score_double > 0:
			host._stats_vbox.add_child(UI.make_row("  Double+ (+2)",   str(host._score_double + host._score_worse), Color(0.9, 0.3, 0.3)))
		var under: int = host._score_condor + host._score_albatross + host._score_eagle + host._score_birdie
		var pct_under: float = 100.0 * float(under) / float(total_holes_scored)
		host._stats_vbox.add_child(UI.make_row("  Under par rate", "%.0f%%" % pct_under, Color(0.4, 1.0, 0.5)))

	# Rating breakdown
	var world: GameWorld3D = GameManager.world
	if world:
		var rb: Dictionary = world.get_rating_breakdown()
		if rb.get("hole_count", 0) as int > 0:
			host._stats_vbox.add_child(HSeparator.new())
			host._stats_vbox.add_child(UI.make_section("Course Rating Breakdown"))
			var avg_r: float = rb["avg"] as float
			var col_r := Color(0.3, 0.95, 0.4) if avg_r >= 4.0 else (Color(1.0, 0.85, 0.3) if avg_r >= 2.5 else Color(0.95, 0.35, 0.35))
			host._stats_vbox.add_child(UI.make_row("  Overall avg", "%.2f ★" % avg_r, col_r))
			host._stats_vbox.add_child(UI.make_row("  Holes ≥ 4★", str(rb["above_4"] as int), Color(0.4, 1.0, 0.5)))
			var below3: int = rb["below_3"] as int
			if below3 > 0:
				host._stats_vbox.add_child(UI.make_row("  Holes < 3★ (dragging avg)", str(below3), Color(1.0, 0.55, 0.25)))
				var hint := Label.new()
				hint.text = "Tip: Add fairway, hazards (water/trees), or restrooms near low-rated holes."
				hint.add_theme_font_size_override("font_size", 11)
				hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				host._stats_vbox.add_child(hint)

		var hb: Dictionary = world.get_happiness_breakdown()
		host._stats_vbox.add_child(HSeparator.new())
		host._stats_vbox.add_child(UI.make_section("Player Happiness Breakdown"))
		var q: float = (hb.get("quality", 0.0) as float) * 100.0
		var r: float = (hb.get("restrooms", 0.0) as float) * 100.0
		var f: float = (hb.get("food", 0.0) as float) * 100.0
		var p: float = (hb.get("pro_shop", 0.0) as float) * 100.0
		host._stats_vbox.add_child(UI.make_row("  Course quality (50%)", "%.0f%% → %.0f pts" % [q, q * 0.50], Color(0.5, 0.85, 1.0)))
		var rest_col := Color(0.4, 1.0, 0.5) if r >= 80.0 else (Color(1.0, 0.7, 0.3) if r > 0.0 else Color(0.9, 0.35, 0.35))
		host._stats_vbox.add_child(UI.make_row("  Restrooms (20%)", "%.0f%%  (%d built)" % [r, hb.get("restroom_count", 0) as int], rest_col))
		var food_col := Color(0.4, 1.0, 0.5) if f >= 80.0 else (Color(1.0, 0.7, 0.3) if f > 0.0 else Color(0.9, 0.35, 0.35))
		host._stats_vbox.add_child(UI.make_row("  Food stands (15%)", "%.0f%%  (%d built)" % [f, hb.get("food_count", 0) as int], food_col))
		var pro_col := Color(0.4, 1.0, 0.5) if p >= 100.0 else Color(0.9, 0.35, 0.35)
		host._stats_vbox.add_child(UI.make_row("  Pro shop (15%)", "%.0f%%  (%s)" % [p, "built" if (hb.get("pro_count", 0) as int) > 0 else "missing"], pro_col))

	# Course condition
	host._stats_vbox.add_child(HSeparator.new())
	host._stats_vbox.add_child(UI.make_section("Course Condition"))
	var cond_pct := EconomyManager.get_course_condition()
	host._stats_vbox.add_child(UI.make_row("  Condition", "%.0f%%" % cond_pct, UI.condition_color(cond_pct)))
	host._stats_vbox.add_child(UI.make_condition_bar(cond_pct))
	if cond_pct < 75.0:
		var cond_hint := Label.new()
		cond_hint.text = "Below 75% reduces income. Hire Groundskeepers or Repair Course to restore."
		cond_hint.add_theme_font_size_override("font_size", 11)
		cond_hint.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
		cond_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._stats_vbox.add_child(cond_hint)

	# 14-day net income mini chart
	var history := EconomyManager.get_daily_net_history()
	if not history.is_empty():
		host._stats_vbox.add_child(HSeparator.new())
		host._stats_vbox.add_child(UI.make_section("14-Day Net Income"))
		var chart_lbl := Label.new()
		chart_lbl.text = "Last %d days (green=profit, red=loss)" % history.size()
		chart_lbl.add_theme_font_size_override("font_size", 11)
		chart_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		host._stats_vbox.add_child(chart_lbl)
		var chart_row := HBoxContainer.new()
		chart_row.custom_minimum_size = Vector2(0, 48)
		chart_row.add_theme_constant_override("separation", 2)
		host._stats_vbox.add_child(chart_row)
		var max_abs := 1.0
		for v in history:
			max_abs = maxf(max_abs, absf(v as float))
		for v in history:
			var val: float = v as float
			var bar := Panel.new()
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var height_frac := clampf(absf(val) / max_abs, 0.05, 1.0)
			bar.custom_minimum_size = Vector2(0, height_frac * 44.0)
			var bar_sb := StyleBoxFlat.new()
			bar_sb.bg_color = Color(0.25, 0.85, 0.35) if val >= 0.0 else Color(0.9, 0.3, 0.3)
			bar.add_theme_stylebox_override("panel", bar_sb)
			chart_row.add_child(bar)
