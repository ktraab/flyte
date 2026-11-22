## Save/load named course layout slots (user://layouts/) and their overlay.
## Extracted from CourseBuilder.gd (2026-11). `host` is the CourseBuilder screen;
## this class holds the logic, the screen keeps the nodes and thin delegates.
extends RefCounted

var host: Control

func _init(h: Control) -> void:
	host = h

func _layout_path(slot: int) -> String:
	return host._LAYOUTS_DIR + "slot_%d.json" % slot

func _load_layout_meta(slot: int) -> Dictionary:
	var path := _layout_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	var d = json.get_data()
	return d if d is Dictionary else {}

func _save_layout(slot: int, slot_name: String) -> void:
	var world := GameManager.world as GameWorld3D
	if not world:
		return
	if not DirAccess.dir_exists_absolute(host._LAYOUTS_DIR):
		DirAccess.make_dir_recursive_absolute(host._LAYOUTS_DIR)
	var state := world.export_full_state()
	var holes_info := world.get_holes_info()
	var rating := world.get_course_rating()
	var data := {
		"name":      slot_name,
		"timestamp": Time.get_unix_time_from_system(),
		"holes":     holes_info.size(),
		"rating":    snappedf(rating, 0.1),
		"world":     state,
	}
	var file := FileAccess.open(_layout_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	_refresh_layouts_overlay()
	EventBus.notification_requested.emit("Layout saved to slot %d." % (slot + 1), "info")

func _load_layout(slot: int) -> void:
	var data := _load_layout_meta(slot)
	if data.is_empty() or not data.has("world"):
		return
	var world := GameManager.world as GameWorld3D
	if not world:
		return
	world.import_full_state(data["world"] as Dictionary)
	host._on_layouts_pressed()   # close overlay
	EventBus.notification_requested.emit("Layout '%s' loaded." % data.get("name", "Slot %d" % (slot + 1)), "info")

func _delete_layout(slot: int) -> void:
	var path := _layout_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_refresh_layouts_overlay()

func _build_layouts_overlay() -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.custom_minimum_size = Vector2(520, 380)
	overlay.position = Vector2(-260, -190)
	host.add_child(overlay)
	host._n_layouts_overlay = overlay

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Course Layout Slots"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Save snapshots of your course to restore later. Does not affect your main saved course."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	var sep := HSeparator.new(); vbox.add_child(sep)

	var slots_vbox := VBoxContainer.new()
	slots_vbox.layout_mode = 2
	slots_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(slots_vbox)
	vbox.set("custom_minimum_size", Vector2(496, 0))

	for i: int in int(host.LAYOUT_SLOTS):
		var data := _load_layout_meta(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slots_vbox.add_child(row)

		# Slot info label
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 12)
		if data.is_empty():
			info.text = "Slot %d — empty" % (i + 1)
			info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			var ts: int = int(data.get("timestamp", 0))
			var date_str := Time.get_datetime_string_from_unix_time(ts).left(10)
			info.text = "Slot %d  •  %s  •  %d holes  •  ★%.1f  •  %s" % [
				i + 1,
				data.get("name", "Unnamed") as String,
				int(data.get("holes", 0)),
				float(data.get("rating", 0.0)),
				date_str,
			]
		row.add_child(info)

		# Load button
		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(58, 44)
		load_btn.disabled = data.is_empty()
		var si := i
		load_btn.pressed.connect(func() -> void: _load_layout(si))
		row.add_child(load_btn)

		# Save button — opens name dialog
		var save_btn := Button.new()
		save_btn.text = "Save"
		save_btn.custom_minimum_size = Vector2(58, 44)
		save_btn.pressed.connect(func() -> void: _prompt_save_layout(si))
		row.add_child(save_btn)

		# Delete button
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(44, 44)
		del_btn.disabled = data.is_empty()
		del_btn.pressed.connect(func() -> void: _delete_layout(si))
		row.add_child(del_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		if host._n_layouts_overlay and is_instance_valid(host._n_layouts_overlay):
			host._n_layouts_overlay.queue_free()
			host._n_layouts_overlay = null)
	vbox.add_child(close_btn)

func _refresh_layouts_overlay() -> void:
	if not host._n_layouts_overlay or not is_instance_valid(host._n_layouts_overlay):
		return
	host._n_layouts_overlay.queue_free()
	host._n_layouts_overlay = null
	_build_layouts_overlay()

func _prompt_save_layout(slot: int) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Name this layout"
	dialog.dialog_text = ""
	var edit := LineEdit.new()
	edit.placeholder_text = "e.g. 'Version 2' or 'Before water hazard'"
	edit.custom_minimum_size = Vector2(340, 44)
	var existing := _load_layout_meta(slot)
	if not existing.is_empty():
		edit.text = existing.get("name", "") as String
	dialog.add_child(edit)
	host.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		var name := edit.text.strip_edges()
		if name.is_empty():
			name = "Slot %d" % (slot + 1)
		_save_layout(slot, name)
		dialog.queue_free())
