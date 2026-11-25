extends Control

const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"

@onready var _master_slider: HSlider = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/MasterRow/MasterSlider
@onready var _master_val:    Label   = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/MasterRow/MasterValLbl
@onready var _music_slider:  HSlider = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/MusicRow/MusicSlider
@onready var _music_val:     Label   = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/MusicRow/MusicValLbl
@onready var _sfx_slider:    HSlider = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/SFXRow/SFXSlider
@onready var _sfx_val:       Label   = $CenterBox/Panel/Margin/MainVBox/TabContainer/Audio/SFXRow/SFXValLbl

@onready var _preset_option:  OptionButton = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/PresetRow/PresetOption
@onready var _custom_section: VBoxContainer = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection
@onready var _glow_check:     CheckButton  = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection/GlowRow/GlowCheck
@onready var _shadows_option: OptionButton = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection/ShadowsRow/ShadowsOption
@onready var _sky_option:     OptionButton = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection/SkyRow/SkyOption
@onready var _fps_option:     OptionButton = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection/FpsRow/FpsOption
@onready var _flags_check:    CheckButton  = $CenterBox/Panel/Margin/MainVBox/TabContainer/Graphics/CustomSection/FlagsRow/FlagsCheck

var _gfx_ui_init   := false
var _rscale_option: OptionButton = null    # built in code (render scale)
var _clutter_check: CheckButton = null    # built in code (grass tufts)
var _trees_option: OptionButton = null    # built in code (tree detail)
var _auto_check: CheckButton = null       # built in code (auto-lower when slow)
var _access_built  := false
var _scale_option:    OptionButton = null
var _colorblind_opt:  OptionButton = null
var _updates_built := false
var _upd_status: Label = null
var _upd_auto: CheckButton = null
var _upd_check_btn: Button = null
var _upd_dl_btn: Button = null

func on_screen_entered(_params: Dictionary = {}) -> void:
	_sync_sliders_from_buses()
	_sync_graphics_ui()
	_build_accessibility_tab()
	_build_updates_tab()

func on_screen_exited() -> void:
	pass

func _bus_linear_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0

func _sync_sliders_from_buses() -> void:
	_master_slider.value = _bus_linear_volume(BUS_MASTER)
	_music_slider.value  = _bus_linear_volume(BUS_MUSIC)
	_sfx_slider.value    = _bus_linear_volume(BUS_SFX)
	_master_val.text = "%d%%" % roundi(_master_slider.value * 100.0)
	_music_val.text  = "%d%%" % roundi(_music_slider.value  * 100.0)
	_sfx_val.text    = "%d%%" % roundi(_sfx_slider.value    * 100.0)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func _on_master_changed(value: float) -> void:
	_set_bus_volume(BUS_MASTER, value)
	_master_val.text = "%d%%" % roundi(value * 100.0)

func _on_music_changed(value: float) -> void:
	_set_bus_volume(BUS_MUSIC, value)
	_music_val.text = "%d%%" % roundi(value * 100.0)

func _on_sfx_changed(value: float) -> void:
	_set_bus_volume(BUS_SFX, value)
	_sfx_val.text = "%d%%" % roundi(value * 100.0)

func _sync_graphics_ui() -> void:
	if not _gfx_ui_init:
		_gfx_ui_init = true
		_preset_option.add_item("Low")
		_preset_option.add_item("Medium")
		_preset_option.add_item("High")
		_preset_option.add_item("Custom")
		_shadows_option.add_item("Off")
		_shadows_option.add_item("Low  (1 cascade, 80m)")
		_shadows_option.add_item("High  (2 cascades, 180m)")
		_sky_option.add_item("Procedural")
		_sky_option.add_item("HDRI Panorama")
		_fps_option.add_item("30 FPS")
		_fps_option.add_item("60 FPS")
		_fps_option.add_item("Unlimited")
		_build_perf_rows()
		_build_auto_row()
	_preset_option.selected     = GameManager.graphics_preset
	_custom_section.visible     = (GameManager.graphics_preset == 3)
	_sync_custom_controls()
	if _auto_check:
		_auto_check.set_pressed_no_signal(GameManager.gfx_auto)

func _sync_custom_controls() -> void:
	# set_pressed_no_signal: syncing must not fire toggled → apply_custom_graphics
	# (which would flip a just-chosen preset to "Custom").
	_glow_check.set_pressed_no_signal(GameManager.gfx_glow)
	_shadows_option.selected    = GameManager.gfx_shadows
	_sky_option.selected        = GameManager.gfx_sky
	_fps_option.selected        = _fps_cap_to_idx(GameManager.gfx_fps_cap)
	_flags_check.set_pressed_no_signal(GameManager.gfx_flags)
	if _rscale_option:
		_rscale_option.selected = _render_scale_to_idx(GameManager.gfx_render_scale)
		_clutter_check.set_pressed_no_signal(GameManager.gfx_clutter)
		_trees_option.selected = 0 if GameManager.gfx_trees == 1 else 1

## Render scale + ground detail rows (added in code to the Custom section).
func _build_perf_rows() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "Render Scale"
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	_rscale_option = OptionButton.new()
	_rscale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sc in GameManager.RENDER_SCALES:
		_rscale_option.add_item("%d%%%s" % [roundi(float(sc) * 100.0), "  (sharpest)" if sc == 1.0 else ""])
	_rscale_option.tooltip_text = "Renders the 3D world at fewer pixels (menus stay sharp). Lower = faster."
	_rscale_option.item_selected.connect(func(i: int) -> void:
		GameManager.apply_custom_graphics({"scale": GameManager.RENDER_SCALES[i]}))
	row.add_child(_rscale_option)
	_custom_section.add_child(row)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var lbl2 := Label.new()
	lbl2.text = "Grass Tufts"
	lbl2.custom_minimum_size = Vector2(140, 0)
	lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row2.add_child(lbl2)
	_clutter_check = CheckButton.new()
	_clutter_check.text = "Enabled"
	_clutter_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clutter_check.toggled.connect(func(on: bool) -> void:
		GameManager.apply_custom_graphics({"clutter": on}))
	row2.add_child(_clutter_check)
	_custom_section.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	var lbl3 := Label.new()
	lbl3.text = "Tree Detail"
	lbl3.custom_minimum_size = Vector2(140, 0)
	lbl3.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row3.add_child(lbl3)
	_trees_option = OptionButton.new()
	_trees_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trees_option.add_item("Full")
	_trees_option.add_item("Simplified  (faster)")
	_trees_option.tooltip_text = "Simplified tree models draw far fewer triangles — the biggest saving on forested courses."
	_trees_option.item_selected.connect(func(i: int) -> void:
		GameManager.apply_custom_graphics({"trees": 1 if i == 0 else 0}))
	row3.add_child(_trees_option)
	_custom_section.add_child(row3)

## "Auto-lower when slow" sits under the preset picker (applies to every preset).
func _build_auto_row() -> void:
	var preset_row := _preset_option.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "Auto Adjust"
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	_auto_check = CheckButton.new()
	_auto_check.text = "Lower graphics if the game runs slow"
	_auto_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_check.tooltip_text = "If frames drop for several seconds, settings step down one notch and a message tells you."
	_auto_check.toggled.connect(func(on: bool) -> void: GameManager.set_gfx_auto(on))
	row.add_child(_auto_check)
	preset_row.get_parent().add_child(row)
	preset_row.get_parent().move_child(row, preset_row.get_index() + 1)

func _render_scale_to_idx(sc: float) -> int:
	var best := 0
	for i in GameManager.RENDER_SCALES.size():
		if absf(float(GameManager.RENDER_SCALES[i]) - sc) < absf(float(GameManager.RENDER_SCALES[best]) - sc):
			best = i
	return best

func _fps_cap_to_idx(cap: int) -> int:
	match cap:
		30: return 0
		0:  return 2
		_:  return 1

func _on_preset_selected(idx: int) -> void:
	if idx < 3:
		GameManager.apply_graphics_preset(idx)
		_custom_section.visible = false
		_sync_custom_controls()
	else:
		GameManager.apply_custom_graphics({})
		_custom_section.visible = true

func _on_glow_toggled(on: bool) -> void:
	GameManager.apply_custom_graphics({"glow": on})

func _on_shadows_selected(idx: int) -> void:
	GameManager.apply_custom_graphics({"shadows": idx})

func _on_sky_selected(idx: int) -> void:
	GameManager.apply_custom_graphics({"sky": idx})

func _on_fps_selected(idx: int) -> void:
	var caps := [30, 60, 0]
	GameManager.apply_custom_graphics({"fps": caps[idx]})

func _on_flags_toggled(on: bool) -> void:
	GameManager.apply_custom_graphics({"flags": on})

func _on_back_pressed() -> void:
	EventBus.screen_pop_requested.emit()

# ── Accessibility tab (built programmatically) ────────────────────────────────

func _build_accessibility_tab() -> void:
	if _access_built:
		_sync_accessibility_ui()
		return
	_access_built = true

	var tab_container := $CenterBox/Panel/Margin/MainVBox/TabContainer as TabContainer
	if not tab_container:
		return

	var vbox := VBoxContainer.new()
	vbox.name = "Accessibility"
	vbox.add_theme_constant_override("separation", 12)
	tab_container.add_child(vbox)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	# UI Scale
	var scale_hdr := Label.new()
	scale_hdr.text = "UI Scale"
	scale_hdr.add_theme_font_size_override("font_size", 14)
	inner.add_child(scale_hdr)

	var scale_desc := Label.new()
	scale_desc.text = "Enlarges all menus and HUD elements. Useful on high-DPI displays or for readability."
	scale_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scale_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	scale_desc.add_theme_font_size_override("font_size", 11)
	inner.add_child(scale_desc)

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	inner.add_child(scale_row)

	var scale_lbl := Label.new()
	scale_lbl.text = "Scale:"
	scale_lbl.custom_minimum_size = Vector2(80, 0)
	scale_row.add_child(scale_lbl)

	_scale_option = OptionButton.new()
	_scale_option.add_item("75%  (Compact)")
	_scale_option.add_item("100%  (Normal)")
	_scale_option.add_item("125%  (Large)")
	_scale_option.add_item("150%  (Larger)")
	_scale_option.add_item("200%  (Huge)")
	_scale_option.item_selected.connect(_on_scale_selected)
	scale_row.add_child(_scale_option)

	inner.add_child(HSeparator.new())

	# Colorblind mode
	var cb_hdr := Label.new()
	cb_hdr.text = "Colorblind Mode"
	cb_hdr.add_theme_font_size_override("font_size", 14)
	inner.add_child(cb_hdr)

	var cb_desc := Label.new()
	cb_desc.text = "Adjusts game color palettes for common types of color vision deficiency."
	cb_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cb_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	cb_desc.add_theme_font_size_override("font_size", 11)
	inner.add_child(cb_desc)

	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 12)
	inner.add_child(cb_row)

	var cb_lbl := Label.new()
	cb_lbl.text = "Mode:"
	cb_lbl.custom_minimum_size = Vector2(80, 0)
	cb_row.add_child(cb_lbl)

	_colorblind_opt = OptionButton.new()
	_colorblind_opt.add_item("None")
	_colorblind_opt.add_item("Protanopia  (red-blind)")
	_colorblind_opt.add_item("Deuteranopia  (green-blind)")
	_colorblind_opt.add_item("Tritanopia  (blue-blind)")
	_colorblind_opt.item_selected.connect(_on_colorblind_selected)
	cb_row.add_child(_colorblind_opt)

	_sync_accessibility_ui()

func _sync_accessibility_ui() -> void:
	if _scale_option:
		var idx := _scale_to_idx(GameManager.ui_scale)
		_scale_option.selected = idx
	if _colorblind_opt:
		_colorblind_opt.selected = GameManager.colorblind_mode

func _scale_to_idx(scale: float) -> int:
	if scale <= 0.76: return 0
	if scale <= 1.01: return 1
	if scale <= 1.26: return 2
	if scale <= 1.51: return 3
	return 4

func _on_scale_selected(idx: int) -> void:
	var scales := [0.75, 1.0, 1.25, 1.5, 2.0]
	GameManager.apply_ui_scale(scales[idx])

func _on_colorblind_selected(idx: int) -> void:
	GameManager.apply_colorblind_mode(idx)

# ── Updates tab (built programmatically) ──────────────────────────────────────

func _build_updates_tab() -> void:
	if _updates_built:
		_sync_updates_ui()
		return
	_updates_built = true
	var tab_container := $CenterBox/Panel/Margin/MainVBox/TabContainer as TabContainer
	if not tab_container:
		return
	var margin := MarginContainer.new()
	margin.name = "Updates"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	tab_container.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	var ver := Label.new()
	ver.text = "You have Flyte v%s" % UpdateChecker.current_version()
	ver.add_theme_font_size_override("font_size", 14)
	inner.add_child(ver)

	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 10)
	inner.add_child(auto_row)
	var auto_lbl := Label.new()
	auto_lbl.text = "Check for updates automatically"
	auto_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.add_child(auto_lbl)
	_upd_auto = CheckButton.new()
	_upd_auto.toggled.connect(func(on: bool) -> void: UpdateChecker.set_auto_check(on))
	auto_row.add_child(_upd_auto)

	var desc := Label.new()
	desc.text = "Once per launch Flyte asks GitHub whether a newer release exists. Nothing is downloaded or installed for you — Download opens the release page."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	desc.add_theme_font_size_override("font_size", 11)
	inner.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	inner.add_child(btn_row)
	_upd_check_btn = Button.new()
	_upd_check_btn.text = "Check now"
	_upd_check_btn.custom_minimum_size = Vector2(140, 40)
	_upd_check_btn.pressed.connect(func() -> void: UpdateChecker.check_now(true))
	btn_row.add_child(_upd_check_btn)
	_upd_dl_btn = Button.new()
	_upd_dl_btn.text = "Download"
	_upd_dl_btn.custom_minimum_size = Vector2(140, 40)
	_upd_dl_btn.pressed.connect(func() -> void: UpdateChecker.open_download())
	btn_row.add_child(_upd_dl_btn)

	_upd_status = Label.new()
	_upd_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_upd_status)

	UpdateChecker.status_changed.connect(func(_s: String) -> void: _sync_updates_ui())
	_sync_updates_ui()

func _sync_updates_ui() -> void:
	if _upd_auto:
		_upd_auto.set_pressed_no_signal(UpdateChecker.auto_check)
	if _upd_status:
		_upd_status.text = UpdateChecker.status_text()
	if _upd_check_btn:
		_upd_check_btn.disabled = UpdateChecker.status == "checking"
	if _upd_dl_btn:
		_upd_dl_btn.visible = UpdateChecker.status == "available"
