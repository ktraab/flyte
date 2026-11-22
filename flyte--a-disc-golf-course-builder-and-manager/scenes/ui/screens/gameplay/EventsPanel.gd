## Events overlay: start events, cooldowns, requirements.
## Extracted from Gameplay.gd (2026-11). `host` is the Gameplay screen, which
## owns the overlay nodes; this class only builds their contents.
extends RefCounted

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")

var host: Control

func _init(h: Control) -> void:
	host = h

func rebuild() -> void:
	if not host._events_vbox:
		return
	for c in host._events_vbox.get_children():
		c.queue_free()

	var ev_header := HBoxContainer.new()
	var ev_title := Label.new()
	ev_title.text = "Special Events"
	ev_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_title.add_theme_font_size_override("font_size", 18)
	ev_header.add_child(ev_title)
	var ev_x := Button.new()
	ev_x.text = "✕"
	ev_x.custom_minimum_size = Vector2(44, 44)
	ev_x.pressed.connect(func() -> void: host._events_overlay.visible = false)
	ev_header.add_child(ev_x)
	host._events_vbox.add_child(ev_header)
	host._events_vbox.add_child(HSeparator.new())

	var active := EconomyManager.get_active_event()
	if active != "":
		var timer_left := EconomyManager.get_event_timer()
		var active_lbl := Label.new()
		active_lbl.text = "ACTIVE: %s  (%.0fs remaining)" % [active, timer_left]
		active_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		host._events_vbox.add_child(active_lbl)
		host._events_vbox.add_child(HSeparator.new())

	for ev_name in EconomyManager.get_event_names():
		var ev_info: Dictionary = EconomyManager.get_event_info(ev_name)
		var check: Dictionary   = EconomyManager.can_start_event(ev_name)
		var can: bool           = check.get("can", false) as bool
		var reason: String      = check.get("reason", "") as String

		var header_row := HBoxContainer.new()
		host._events_vbox.add_child(header_row)
		var name_lbl := Label.new()
		name_lbl.text = ev_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		header_row.add_child(name_lbl)
		var cost_lbl := Label.new()
		var cost: float = ev_info.get("cost", 0.0) as float
		cost_lbl.text = "FREE" if cost == 0.0 else "$%s" % UI.fmt(cost)
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		header_row.add_child(cost_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = ev_info.get("desc", "") as String
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		host._events_vbox.add_child(desc_lbl)

		var dur: int = ev_info.get("duration", 1) as int
		var cd_days: int = ev_info.get("cooldown", 7) as int
		var meta_lbl := Label.new()
		meta_lbl.text = "Duration: %d day(s)  |  Cooldown: %d days" % [dur, cd_days]
		meta_lbl.add_theme_font_size_override("font_size", 11)
		meta_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		host._events_vbox.add_child(meta_lbl)

		var ev_name_copy: String = ev_name as String
		var start_btn := Button.new()
		start_btn.custom_minimum_size = Vector2(0, 44)
		if can:
			start_btn.text = "Start Event"
			start_btn.disabled = false
		else:
			start_btn.text = reason if reason != "" else "Unavailable"
			start_btn.disabled = true
		start_btn.pressed.connect(func() -> void:
			EconomyManager.start_event(ev_name_copy)
			rebuild()
		)
		host._events_vbox.add_child(start_btn)
		host._events_vbox.add_child(HSeparator.new())
