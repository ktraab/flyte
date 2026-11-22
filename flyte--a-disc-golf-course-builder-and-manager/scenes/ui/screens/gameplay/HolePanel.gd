## Hole analytics overlay: per-hole rating breakdown and score stats.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._hole_vbox:
		return
	for c in host._hole_vbox.get_children():
		c.queue_free()

	var world := GameManager.world as GameWorld3D
	var holes_info := world.get_holes_info() if world else []

	if holes_info.is_empty():
		var empty := Label.new()
		empty.text = "No holes built yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		host._hole_vbox.add_child(empty)
		return

	var hint := Label.new()
	hint.text = "Session data only — resets when game restarts."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	host._hole_vbox.add_child(hint)
	host._hole_vbox.add_child(HSeparator.new())

	for hole_info in holes_info:
		var hd: Dictionary = hole_info as Dictionary
		var hole_num: int = hd["hole_num"] as int
		var hole_idx: int = hd["index"] as int
		var par: int = hd["par"] as int

		var hs: Dictionary = host._hole_stats.get(hole_idx, {})
		var rounds: int = hs.get("rounds", 0) as int
		var total_throws: int = hs.get("total_throws", 0) as int
		var total_diff: int = hs.get("total_diff", 0) as int

		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.08, 0.10, 0.14, 0.88)
		csb.corner_radius_top_left     = 5
		csb.corner_radius_top_right    = 5
		csb.corner_radius_bottom_left  = 5
		csb.corner_radius_bottom_right = 5
		card.add_theme_stylebox_override("panel", csb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host._hole_vbox.add_child(card)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left",   10)
		cm.add_theme_constant_override("margin_right",  10)
		cm.add_theme_constant_override("margin_top",    8)
		cm.add_theme_constant_override("margin_bottom", 8)
		card.add_child(cm)
		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 3)
		cm.add_child(cvbox)

		# Hole header row
		var top_row := HBoxContainer.new()
		cvbox.add_child(top_row)
		var hole_lbl := Label.new()
		hole_lbl.text = "Hole %d" % hole_num
		hole_lbl.add_theme_font_size_override("font_size", 14)
		hole_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
		hole_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(hole_lbl)
		var par_lbl := Label.new()
		par_lbl.text = "Par %d" % par
		par_lbl.add_theme_font_size_override("font_size", 12)
		par_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
		top_row.add_child(par_lbl)

		if rounds == 0:
			var none_lbl := Label.new()
			none_lbl.text = "No rounds played yet this session"
			none_lbl.add_theme_font_size_override("font_size", 11)
			none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
			cvbox.add_child(none_lbl)
		else:
			var avg_throws: float = float(total_throws) / float(rounds)
			var avg_diff: float   = float(total_diff) / float(rounds)
			var diff_col := Color(0.3, 0.95, 0.4) if avg_diff < -0.1 else \
				(Color(0.82, 0.82, 0.82) if avg_diff < 0.5 else Color(1.0, 0.60, 0.30))
			var diff_str := "%+.2f" % avg_diff
			var stats_lbl := Label.new()
			stats_lbl.text = "%d round%s  |  Avg %.1f throws  |  Avg score: %s vs par" % [
				rounds, "s" if rounds > 1 else "", avg_throws, diff_str]
			stats_lbl.add_theme_font_size_override("font_size", 12)
			stats_lbl.add_theme_color_override("font_color", diff_col)
			cvbox.add_child(stats_lbl)
