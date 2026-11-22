## Small stateless UI builders shared by the Gameplay HUD panels.
## Extracted from Gameplay.gd (2026-11) — behaviour unchanged.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

static func season_color(season: String) -> Color:
	match season:
		"Summer": return Color(1.0, 0.9,  0.3, 0.9)
		"Winter": return Color(0.7, 0.9,  1.0, 0.9)
		"Fall":   return Color(1.0, 0.65, 0.3, 0.9)
		_:        return Color(0.7, 0.9,  0.7, 0.9)

static func condition_color(pct: float) -> Color:
	if   pct >= 75.0: return Color(0.3,  0.95, 0.4)
	elif pct >= 50.0: return Color(1.0,  0.85, 0.3)
	elif pct >= 25.0: return Color(1.0,  0.55, 0.2)
	else:             return Color(0.95, 0.25, 0.25)

static func make_condition_bar(pct: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.condition_color(pct)
	bar.add_theme_stylebox_override("fill", sb)
	return bar

static func make_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	return lbl

static func make_section(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	return lbl

static func make_row(key: String, value: String, val_color: Color = Color(0.95, 0.95, 0.95)) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 13)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", val_color)
	row.add_child(v)
	return row

static func make_dash_row(key: String, value: String, val_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(110, 0)
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", val_color)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row

static func make_small_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

static func fmt(amount: float) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	if amount >= 1000:
		return "%.1fK" % (amount / 1000.0)
	return "%.0f" % amount
