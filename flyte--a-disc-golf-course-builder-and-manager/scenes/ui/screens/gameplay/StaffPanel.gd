## Staff & facilities overlay: hire/fire/upgrade, facility tiers, loans.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._staff_rows:
		return
	for c in host._staff_rows.get_children():
		c.queue_free()

	# ── Active Effects Dashboard ──────────────────────────────────────────────
	host._staff_rows.add_child(UI.make_section("Active Effects"))
	host._staff_rows.add_child(HSeparator.new())

	var net := EconomyManager.income_rate - EconomyManager.expense_rate
	var net_color := Color(0.35, 0.95, 0.45) if net >= 0.0 else Color(0.95, 0.35, 0.35)
	host._staff_rows.add_child(UI.make_dash_row("Net Income", "%s$%.2f/s" % ["+" if net >= 0.0 else "", net], net_color))
	host._staff_rows.add_child(UI.make_dash_row("Income Rate", "$%.2f/s" % EconomyManager.income_rate, Color(0.75, 0.95, 0.75)))
	host._staff_rows.add_child(UI.make_dash_row("Expense Rate", "-$%.2f/s" % EconomyManager.expense_rate, Color(0.95, 0.65, 0.65)))

	var cond_pct2 := EconomyManager.get_course_condition()
	var cond_mult := 1.0
	if cond_pct2 < 75.0:
		cond_mult = clampf(0.95 - (75.0 - cond_pct2) / 100.0 * 0.40, 0.60, 0.95)
	var cond_str := "%.0f%% (no penalty)" % cond_pct2 if cond_mult >= 1.0 \
		else "%.0f%% → %.0f%% income" % [cond_pct2, cond_mult * 100.0]
	host._staff_rows.add_child(UI.make_dash_row("Condition", cond_str, UI.condition_color(cond_pct2)))

	var spawn_mult := EconomyManager.get_spawn_rate_mult()
	var mkt := EconomyManager.get_marketing_budget()
	var spawn_str := "%.2f× " % spawn_mult
	if mkt > 0.0:
		spawn_str += "(+$%.0f/wk marketing)" % mkt
	else:
		spawn_str += "(no marketing)"
	host._staff_rows.add_child(UI.make_dash_row("Spawn Rate", spawn_str, Color(0.7, 0.85, 1.0)))

	var disc_pros := EconomyManager.get_staff_count(EconomyManager.StaffType.DISC_PRO)
	var happy_enough := EconomyManager.current_happiness >= 0.60
	var vip_pct := (0.12 + float(disc_pros) * 0.05) * 100.0 if happy_enough else float(disc_pros) * 0.05 * 100.0
	var vip_str := "%.0f%%" % vip_pct
	if not happy_enough:
		vip_str += " (need 60%+ happiness for base 12%)"
	host._staff_rows.add_child(UI.make_dash_row("VIP Chance", vip_str, Color(1.0, 0.85, 0.2)))

	var gk_count := float(EconomyManager.get_staff_count(EconomyManager.StaffType.GROUNDSKEEPER))
	var gk_tier  := EconomyManager.get_staff_tier(EconomyManager.StaffType.GROUNDSKEEPER)
	var gk_slow_per: float = [0.9, 1.5, 2.4][gk_tier - 1]
	var total_slow := minf(gk_count * gk_slow_per, EconomyManager.CONDITION_DECAY_PER_DAY)
	var net_decay := maxf(0.0, EconomyManager.CONDITION_DECAY_PER_DAY - total_slow)
	var decay_str := "%.2f%%/day" % net_decay
	if total_slow > 0.0:
		decay_str += " (−%.2f from %d GK)" % [total_slow, int(gk_count)]
	host._staff_rows.add_child(UI.make_dash_row("Decay Rate", decay_str,
		Color(0.35, 0.95, 0.45) if net_decay < 1.0 else Color(1.0, 0.75, 0.3) if net_decay < 3.0 else Color(0.95, 0.5, 0.3)))

	var ev := EconomyManager.get_active_event()
	if ev != "":
		var t_left := EconomyManager.get_event_timer()
		host._staff_rows.add_child(UI.make_dash_row("Active Event", "%s  (%.0fs)" % [ev, t_left], Color(0.45, 1.0, 0.55)))

	host._staff_rows.add_child(HSeparator.new())

	# ── Course Condition ──────────────────────────────────────────────────────
	host._staff_rows.add_child(UI.make_section("Course Condition"))
	var cond_pct := EconomyManager.get_course_condition()
	var cond_lbl := Label.new()
	cond_lbl.text = "%.0f%%  —  " % cond_pct + (
		"No income penalty" if cond_pct >= 75.0 else
		"−%.0f%% income" % ((1.0 - clampf(0.95 - (75.0 - cond_pct) / 100.0 * 0.40, 0.60, 0.95)) * 100.0))
	cond_lbl.add_theme_color_override("font_color", UI.condition_color(cond_pct))
	host._staff_rows.add_child(cond_lbl)
	host._staff_rows.add_child(UI.make_condition_bar(cond_pct))
	var repair_cost := EconomyManager.get_repair_cost()
	var repair_btn := Button.new()
	repair_btn.text = "Repair to 100%%  —  $%s" % UI.fmt(repair_cost)
	repair_btn.custom_minimum_size = Vector2(0, 44)
	repair_btn.disabled = cond_pct >= 99.0
	repair_btn.pressed.connect(func() -> void:
		EconomyManager.repair_course()
		rebuild()
	)
	host._staff_rows.add_child(repair_btn)
	host._staff_rows.add_child(HSeparator.new())

	# ── Staff ─────────────────────────────────────────────────────────────────
	host._staff_rows.add_child(UI.make_section("Staff"))
	var names  := EconomyManager.STAFF_NAMES
	var costs  := EconomyManager.STAFF_COST
	var limits := EconomyManager.STAFF_HIRE_LIMIT
	var salary := EconomyManager.STAFF_SALARY
	var tier_colors := [Color(0.75, 0.75, 0.75), Color(0.4, 0.85, 1.0), Color(1.0, 0.85, 0.2)]

	for t in 3:
		var count := EconomyManager.get_staff_count(t)
		var tier  := EconomyManager.get_staff_tier(t)
		var tier_name: String = EconomyManager.STAFF_TIER_NAMES[tier - 1] as String

		# Header row: name + tier badge + salary cost
		var hdr := HBoxContainer.new()
		host._staff_rows.add_child(hdr)
		var name_lbl := Label.new()
		name_lbl.text = "%s  (%d/%d)" % [names[t] as String, count, limits[t] as int]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		hdr.add_child(name_lbl)
		var tier_badge := Label.new()
		tier_badge.text = "[%s]" % tier_name
		tier_badge.add_theme_color_override("font_color", tier_colors[tier - 1])
		tier_badge.add_theme_font_size_override("font_size", 12)
		hdr.add_child(tier_badge)
		var sal_lbl := Label.new()
		sal_lbl.text = "  $%.1f/s" % (salary[t] as float)
		sal_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		sal_lbl.add_theme_font_size_override("font_size", 12)
		hdr.add_child(sal_lbl)

		# Current tier benefit
		var cur_lbl := Label.new()
		cur_lbl.text = "NOW:  " + _staff_tier_benefit(t, tier)
		cur_lbl.add_theme_font_size_override("font_size", 12)
		cur_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 0.80))
		cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._staff_rows.add_child(cur_lbl)

		# Worker contribution (only if staff hired)
		if count > 0:
			var contrib_lbl := Label.new()
			contrib_lbl.text = "    %d worker%s → %s" % [count, "s" if count > 1 else "", _staff_worker_contribution(t, count, tier)]
			contrib_lbl.add_theme_font_size_override("font_size", 12)
			contrib_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.65))
			contrib_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			host._staff_rows.add_child(contrib_lbl)

		# Next tier preview (if not max)
		if tier < 3:
			var next_lbl := Label.new()
			next_lbl.text = "NEXT: " + _staff_tier_benefit(t, tier + 1)
			next_lbl.add_theme_font_size_override("font_size", 12)
			next_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
			next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			host._staff_rows.add_child(next_lbl)

		# Buttons row
		var type_copy := t
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		host._staff_rows.add_child(btn_row)

		var hire_btn := Button.new()
		hire_btn.text = "Hire  $%s" % UI.fmt(costs[t] as float)
		hire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hire_btn.custom_minimum_size = Vector2(0, 44)
		hire_btn.disabled = count >= (limits[t] as int)
		hire_btn.pressed.connect(func() -> void:
			EconomyManager.hire_staff(type_copy)
			rebuild()
		)
		btn_row.add_child(hire_btn)

		var fire_btn := Button.new()
		fire_btn.text = "Fire"
		fire_btn.custom_minimum_size = Vector2(52, 44)
		fire_btn.disabled = count <= 0
		fire_btn.pressed.connect(func() -> void:
			EconomyManager.fire_staff(type_copy)
			rebuild()
		)
		btn_row.add_child(fire_btn)

		var up_cost := EconomyManager.get_upgrade_cost(t)
		var up_btn := Button.new()
		if up_cost < 0.0:
			up_btn.text = "MAX"
			up_btn.disabled = true
		else:
			up_btn.text = "↑ $%s" % UI.fmt(up_cost)
			up_btn.disabled = count <= 0
		up_btn.custom_minimum_size = Vector2(68, 44)
		up_btn.pressed.connect(func() -> void:
			EconomyManager.upgrade_staff(type_copy)
			rebuild()
		)
		btn_row.add_child(up_btn)

		host._staff_rows.add_child(HSeparator.new())

	# ── Facilities ────────────────────────────────────────────────────────────
	host._staff_rows.add_child(UI.make_section("Facilities"))
	host._staff_rows.add_child(HSeparator.new())

	var pw := GameManager.world
	var fac_counts: Dictionary = (pw as GameWorld3D).get_facility_counts() if pw else {}
	const FAC_KEYS    := ["restroom", "food_stand", "parking", "pro_shop"]
	const FAC_LABELS  := ["Restroom", "Food Stand", "Parking Lot", "Pro Shop"]
	var FAC_EFFECTS := [
		["Capacity +1/unit",  "Capacity +2/unit",  "Capacity +3/unit"],
		["Food income ×%.1f" % EconomyManager.FOOD_STAND_TIER_MULT[0], "Food income ×%.1f" % EconomyManager.FOOD_STAND_TIER_MULT[1], "Food income ×%.1f" % EconomyManager.FOOD_STAND_TIER_MULT[2]],
		["Capacity +2/lot",   "Capacity +4/lot",   "Capacity +6/lot"],
		["Income +20%",       "Income +40%",       "Income +65%"],
	]
	var tier_colors_f := [Color(0.75, 0.75, 0.75), Color(0.4, 0.85, 1.0), Color(1.0, 0.85, 0.2)]
	for fi in FAC_KEYS.size():
		var fkey: String  = FAC_KEYS[fi]
		var flabel: String = FAC_LABELS[fi]
		var ftier := EconomyManager.get_facility_tier(fkey)
		var fcount := fac_counts.get(fkey, 0) as int
		var ftier_name: String = EconomyManager.FACILITY_TIER_NAMES[ftier - 1] as String
		var feffects: Array = FAC_EFFECTS[fi] as Array

		var fhdr := HBoxContainer.new()
		var fn_lbl := Label.new()
		fn_lbl.text = "%s  (%d built)" % [flabel, fcount]
		fn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fn_lbl.add_theme_font_size_override("font_size", 14)
		fhdr.add_child(fn_lbl)
		var fb_lbl := Label.new()
		fb_lbl.text = "[%s]" % ftier_name
		fb_lbl.add_theme_color_override("font_color", tier_colors_f[ftier - 1])
		fb_lbl.add_theme_font_size_override("font_size", 12)
		fhdr.add_child(fb_lbl)
		host._staff_rows.add_child(fhdr)

		var fnow_lbl := Label.new()
		fnow_lbl.text = "NOW: " + (feffects[ftier - 1] as String)
		fnow_lbl.add_theme_font_size_override("font_size", 12)
		fnow_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 0.80))
		host._staff_rows.add_child(fnow_lbl)

		var fup_cost := EconomyManager.get_facility_upgrade_cost(fkey)
		var fkey_copy := fkey
		var fup_btn := Button.new()
		if fup_cost < 0.0:
			fup_btn.text = "MAX TIER"
			fup_btn.disabled = true
		else:
			var fnext: String = feffects[ftier] as String
			fup_btn.text = "↑ Upgrade  ($%s)  →  %s" % [UI.fmt(fup_cost), fnext]
			fup_btn.disabled = fcount <= 0
		fup_btn.custom_minimum_size = Vector2(0, 44)
		fup_btn.pressed.connect(func() -> void:
			EconomyManager.upgrade_facility(fkey_copy)
			rebuild())
		host._staff_rows.add_child(fup_btn)
		host._staff_rows.add_child(HSeparator.new())

	# ── Financing ─────────────────────────────────────────────────────────────
	host._staff_rows.add_child(UI.make_section("Financing"))
	host._staff_rows.add_child(HSeparator.new())

	var loan_bal := EconomyManager.get_loan_balance()
	if loan_bal > 0.0:
		var loan_rate := EconomyManager.get_loan_payment_rate()
		host._staff_rows.add_child(UI.make_dash_row("Loan Owed",     "$%.0f" % loan_bal,          Color(0.95, 0.55, 0.55)))
		host._staff_rows.add_child(UI.make_dash_row("Daily Payment", "$%.0f/day (auto)" % loan_rate, Color(0.95, 0.70, 0.45)))
		var payoff_lbl := Label.new()
		payoff_lbl.text = "Loan is deducted automatically from income each second."
		payoff_lbl.add_theme_font_size_override("font_size", 11)
		payoff_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		payoff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._staff_rows.add_child(payoff_lbl)
	else:
		var no_lbl := Label.new()
		no_lbl.text = "No active loan. Loans fund construction; repaid automatically from income."
		no_lbl.add_theme_font_size_override("font_size", 12)
		no_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.55))
		no_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._staff_rows.add_child(no_lbl)
		for li in EconomyManager.LOAN_OPTIONS.size():
			var lopt: Dictionary = EconomyManager.LOAN_OPTIONS[li] as Dictionary
			var li_copy := li
			var lbtn := Button.new()
			lbtn.text = "%s  →  repay $%.0f at $%.0f/day" % [
				lopt["label"] as String, lopt["total"] as float, lopt["daily"] as float]
			lbtn.custom_minimum_size = Vector2(0, 44)
			lbtn.pressed.connect(func() -> void:
				EconomyManager.take_loan(li_copy)
				rebuild())
			host._staff_rows.add_child(lbtn)
	host._staff_rows.add_child(HSeparator.new())

func _staff_tier_benefit(type: int, tier: int) -> String:
	if type == 0:   # Groundskeeper
		var slow: float = [0.9, 1.5, 2.4][tier - 1]
		if   tier == 1: return "%.1f%%/day decay reduction per worker" % slow
		elif tier == 2: return "%.1f%%/day per worker  (+0.6 vs Basic)" % slow
		else:           return "%.1f%%/day per worker  (+0.9 vs Trained) — near-zero decay" % slow
	elif type == 1: # Disc Pro
		var pct := EconomyManager.DISC_PRO_BONUS_PER_TIER * 100.0 * float(tier)
		return "+%.0f%% green-fee income  +5%% VIP chance per worker" % pct
	elif type == 2: # Concessions
		var food_pp: float   = EconomyManager.CONCESSIONS_PER_STAFF[tier - 1]
		var stand_mult: float = [1.0, 1.4, 1.8][tier - 1]
		if   tier == 1: return "$%.1f/s per worker  |  Food stands ×%.1f" % [food_pp, stand_mult]
		elif tier == 2: return "$%.1f/s per worker  |  Food stands ×%.1f  (+40%% stand income)" % [food_pp, stand_mult]
		else:           return "$%.1f/s per worker  |  Food stands ×%.1f  (+80%% stand income)" % [food_pp, stand_mult]
	return ""

func _staff_worker_contribution(type: int, count: int, tier: int) -> String:
	if type == 0:   # Groundskeeper
		var slow: float = [0.9, 1.5, 2.4][tier - 1]
		var total := minf(float(count) * slow, EconomyManager.CONDITION_DECAY_PER_DAY)
		var net   := maxf(0.0, EconomyManager.CONDITION_DECAY_PER_DAY - total)
		return "−%.2f%%/day  (net decay: %.2f%%/day)" % [total, net]
	elif type == 1: # Disc Pro
		var vip_bonus := float(count) * 5.0
		var income_bonus := float(count) * float(tier) * EconomyManager.DISC_PRO_BONUS_PER_TIER * 100.0
		return "+%.0f%% VIP chance  |  +%.0f%% income multiplier" % [vip_bonus, income_bonus]
	elif type == 2: # Concessions
		var food_pp: float = EconomyManager.CONCESSIONS_PER_STAFF[tier - 1]
		return "+$%.2f/s food income total" % (float(count) * food_pp)
	return ""
