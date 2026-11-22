## Fees overlay: green fee multiplier, membership fee, marketing.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._fees_vbox:
		return
	for c in host._fees_vbox.get_children():
		c.queue_free()

	var fees_header := HBoxContainer.new()
	var fees_title := Label.new()
	fees_title.text = "Pricing Settings"
	fees_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fees_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fees_title.add_theme_font_size_override("font_size", 18)
	fees_header.add_child(fees_title)
	var fees_x := Button.new()
	fees_x.text = "✕"
	fees_x.custom_minimum_size = Vector2(44, 44)
	fees_x.pressed.connect(func() -> void: host._fees_overlay.visible = false)
	fees_header.add_child(fees_x)
	host._fees_vbox.add_child(fees_header)
	host._fees_vbox.add_child(HSeparator.new())

	# Green fee
	host._fees_vbox.add_child(UI.make_section("Green Fee Multiplier"))
	var gf_mult := EconomyManager.get_green_fee_mult()
	var gf_val_lbl := Label.new()
	gf_val_lbl.text = "%.2f×  (%.0f%% of standard)" % [gf_mult, gf_mult * 100.0]
	gf_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._fees_vbox.add_child(gf_val_lbl)
	var gf_row := HBoxContainer.new()
	gf_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gf_row.add_theme_constant_override("separation", 12)
	for delta_val in [-0.25, -0.1, 0.1, 0.25]:
		var btn := Button.new()
		btn.text = "%+.2f×" % delta_val
		btn.custom_minimum_size = Vector2(70, 44)
		var dv: float = delta_val
		btn.pressed.connect(func() -> void:
			EconomyManager.set_green_fee_mult(EconomyManager.get_green_fee_mult() + dv)
			rebuild()
		)
		gf_row.add_child(btn)
	host._fees_vbox.add_child(gf_row)
	var gf_hint := Label.new()
	var hint_text := "Higher fees earn more per player but fewer players come. Sweet spot ≈ 1.2–1.5×."
	if gf_mult < 0.8:
		hint_text = "Discounted rates bring more visitors, each paying less."
	elif gf_mult > 1.75:
		hint_text = "Premium pricing: visitors arrive much less often and mood drops."
	gf_hint.text = hint_text
	gf_hint.add_theme_font_size_override("font_size", 12)
	gf_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	gf_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fees_vbox.add_child(gf_hint)

	host._fees_vbox.add_child(HSeparator.new())

	# Membership fee
	host._fees_vbox.add_child(UI.make_section("Membership Fee  (requires Pro Shop)"))
	var mem_fee := EconomyManager.get_membership_fee()
	var mem_count := EconomyManager.get_membership_count()
	var mem_val_lbl := Label.new()
	mem_val_lbl.text = "$%.0f/week  ×  %d members  =  $%s/week" % [
		mem_fee, mem_count, UI.fmt(float(mem_count) * mem_fee)]
	mem_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mem_val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fees_vbox.add_child(mem_val_lbl)
	var mem_row := HBoxContainer.new()
	mem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mem_row.add_theme_constant_override("separation", 12)
	for delta_val in [-10.0, -5.0, 5.0, 10.0]:
		var btn := Button.new()
		btn.text = "%+.0f" % delta_val
		btn.custom_minimum_size = Vector2(60, 44)
		var dv: float = delta_val
		btn.pressed.connect(func() -> void:
			EconomyManager.set_membership_fee(EconomyManager.get_membership_fee() + dv)
			rebuild()
		)
		mem_row.add_child(btn)
	host._fees_vbox.add_child(mem_row)
	var mem_hint := Label.new()
	mem_hint.text = "Members join when happiness ≥ 65%. They leave if happiness drops below 38%."
	mem_hint.add_theme_font_size_override("font_size", 12)
	mem_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mem_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fees_vbox.add_child(mem_hint)

	host._fees_vbox.add_child(HSeparator.new())

	# Marketing budget
	host._fees_vbox.add_child(UI.make_section("Marketing Budget  (weekly spend)"))
	var mkt_budget := EconomyManager.get_marketing_budget()
	var spawn_mult := EconomyManager.get_spawn_rate_mult()
	var mkt_lbl := Label.new()
	mkt_lbl.text = "$%.0f/week  →  %.2f× player spawn rate" % [mkt_budget, spawn_mult]
	mkt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mkt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fees_vbox.add_child(mkt_lbl)
	var mkt_row := HBoxContainer.new()
	mkt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mkt_row.add_theme_constant_override("separation", 8)
	for delta_val in [0.0, 50.0, 100.0, 250.0, 500.0]:
		var btn := Button.new()
		btn.text = "$%.0f" % delta_val
		btn.custom_minimum_size = Vector2(60, 44)
		btn.disabled = absf(mkt_budget - delta_val) < 1.0
		var dv: float = delta_val
		btn.pressed.connect(func() -> void:
			EconomyManager.set_marketing_budget(dv)
			rebuild()
		)
		mkt_row.add_child(btn)
	host._fees_vbox.add_child(mkt_row)
	var mkt_hint := Label.new()
	mkt_hint.text = "Increases player visit frequency. Deducted daily (÷7 per game day)."
	mkt_hint.add_theme_font_size_override("font_size", 12)
	mkt_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mkt_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._fees_vbox.add_child(mkt_hint)
