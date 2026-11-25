extends Control

# Match GameWorld3D.TileType enum exactly
const HoleCritique = preload("res://core/simulation/HoleCritique.gd")
const HoleManagerPanel = preload("res://scenes/ui/screens/course_builder/HoleManagerPanel.gd")
const LayoutSlots = preload("res://scenes/ui/screens/course_builder/LayoutSlots.gd")
const ArchitectOverlay = preload("res://scenes/ui/screens/course_builder/ArchitectOverlay.gd")

const TOOL_GRASS      := 0
const TOOL_FAIRWAY    := 1
const TOOL_PATH       := 2
const TOOL_WATER      := 3
const TOOL_ROUGH      := 4
const TOOL_TREE       := 5
const TOOL_TEE        := 6
const TOOL_BASKET     := 7
const TOOL_ENTRANCE   := 8
const TOOL_PARKING    := 9
const TOOL_RESTROOM   := 10
const TOOL_FOOD_STAND := 11
const TOOL_PRO_SHOP   := 12
const TOOL_SAND       := 13
const TOOL_ROCK       := 14
const TOOL_OB         := 15
const TOOL_RAISE      := 16
const TOOL_LOWER      := 17
const TOOL_SELECT     := 18
const TOOL_ERASE      := 19   # GameWorld3D.TOOL_ERASE — removes objects too
const TOOL_BENCH      := 20
const TOOL_FLOWER_BED := 21
const TOOL_SCULPTURE  := 22
const TOOL_LAMP_POST  := 23
const TOOL_SIGN       := 24
const TOOL_GARDEN     := 25

const HOLE_COLOR_OPTIONS: Array = [
	Color(0.94, 0.18, 0.18),  # Red
	Color(0.18, 0.38, 0.92),  # Blue
	Color(0.95, 0.72, 0.05),  # Yellow
	Color(0.15, 0.80, 0.25),  # Green
	Color(0.78, 0.18, 0.82),  # Purple
	Color(0.96, 0.50, 0.08),  # Orange
	Color(0.90, 0.90, 0.90),  # White
	Color(0.08, 0.80, 0.82),  # Cyan
	Color(0.95, 0.38, 0.68),  # Pink
	Color(0.55, 0.88, 0.12),  # Lime
]

var _active_tool:        int = TOOL_GRASS
var _active_variant:     int = -1
var _decor_tool_buttons: Dictionary = {}   # tool_id → Button for decor tools
var _active_hole_num:    int = 1
var _active_orientation: int = 0
var _tool_buttons: Array[Button] = []

var _selected_cell:       Vector2i = Vector2i(-1, -1)
var _selected_tile_type:  int      = -1
var _editing_selected:    bool     = false
var _selected_color_idx:  int      = 0
var _selected_hole_num:   int      = 1
var _route_edit_active:   bool     = false

var _n_left_panel:            Control
var _n_left_stats_panel:      Control
var _n_hole_num_container:    Control
var _n_orientation_container: Control
var _n_tree_variant_container:Control
var _n_course_stats_container:Control
var _n_stats_label:           Label
var _n_orient_btns:           GridContainer
var _n_hole_manager_overlay:  Control
var _n_holes_vbox:              VBoxContainer
var _n_hm_total_label:          Label
var _n_tree_variant_option:     OptionButton
var _n_facility_color_container: Control
var _n_facility_color_option:    OptionButton
var _n_route_edit_container:     Control
var _n_edit_route_btn:           Button
var _n_tree_size_container:      Control
var _n_tree_size_option:         OptionButton
var _n_balance_label:            Label
var _n_erase_btn:                Button

# Architect overlay (built programmatically)
var _n_palette_groups: Array = []
var _palette_tab_btns: Array = []
var _active_palette_tab: int = 0

var _n_architect_overlay: Control     = null
var _n_arch_hole_label:   Label       = null
var _n_arch_prev_btn:     Button      = null
var _n_arch_next_btn:     Button      = null
var _n_arch_wp_label:     Label       = null
var _n_arch_width_spin:   SpinBox     = null
var _n_arch_grade_label:  Label       = null
var _n_arch_score_label:  Label       = null
var _n_arch_critique_text: RichTextLabel = null
var _architect_hole_num:  int         = 1
var _tmpl_hole_num:       int         = 1   # hole number chosen in Templates tab
var _pending_template:    String      = ""  # set while waiting for user to place tee

# Template ghost / confirm state
var _confirm_template_name: String   = ""
var _confirm_template_tee:  Vector2i = Vector2i(-9999, -9999)
var _n_confirm_panel:       Control  = null

# Layout slot system
const LAYOUT_SLOTS       := 5
const _LAYOUTS_DIR       := "user://layouts/"
var _n_layouts_overlay:  Control = null

func _ready() -> void:
	call_deferred("_setup_nodes")

func _unhandled_input(event: InputEvent) -> void:
	# Screens stay in the tree when hidden — never edit the course from gameplay.
	if not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_Z and ke.is_command_or_control_pressed():   # ⌘Z on Mac, Ctrl+Z elsewhere
			if GameManager.world:
				(GameManager.world as GameWorld3D).undo_paint()
				call_deferred("_update_course_stats")
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_DELETE or ke.keycode == KEY_BACKSPACE:
			if GameManager.world:
				var world := GameManager.world as GameWorld3D
				var target := world.get_hover_cell()
				if _active_tool == TOOL_SELECT and _editing_selected and _selected_cell.x >= 0:
					target = _selected_cell
				if target.x >= 0 and target.y >= 0:
					world.erase_cell(target)
					world.draw_route_lines()
					_editing_selected = false
					_refresh_side_panels()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_R and not ke.is_command_or_control_pressed():
			# Rotate the tee (manual facing; placing its basket re-aims it)
			if _active_tool == TOOL_TEE or (_editing_selected and _selected_tile_type == TOOL_TEE):
				var cur := _active_orientation
				if _editing_selected and GameManager.world:
					cur = (GameManager.world as GameWorld3D).get_tile_orientation(_selected_cell)
				_on_orientation_pressed((cur + (3 if ke.shift_pressed else 1)) % 4)
				get_viewport().set_input_as_handled()

func _fc(name: String) -> Node:
	return find_child(name, true, false)

func _setup_nodes() -> void:
	print("[CourseBuilder] child_count=", get_child_count())

	# Cache node refs via find_child (bypasses path resolution)
	_n_left_panel             = _fc("LeftPanel")             as Control
	_n_left_stats_panel       = _fc("LeftStatsPanel")        as Control
	_n_hole_num_container     = _fc("HoleNumContainer")      as Control
	_n_orientation_container  = _fc("OrientationContainer")  as Control
	_n_tree_variant_container = _fc("TreeVariantContainer")  as Control
	_n_course_stats_container = _fc("CourseStatsContainer")  as Control
	_n_stats_label            = _fc("StatsLabel")            as Label
	_n_orient_btns            = _fc("OrientBtns")            as GridContainer
	_n_hole_manager_overlay   = _fc("HoleManagerOverlay")    as Control
	_n_holes_vbox             = _fc("HolesVBox")             as VBoxContainer
	_n_hm_total_label         = _fc("HMTotalLabel")          as Label
	_n_tree_variant_option       = _fc("TreeVariantOption")       as OptionButton
	_n_facility_color_container  = _fc("FacilityColorContainer")  as Control
	_n_facility_color_option     = _fc("FacilityColorOption")     as OptionButton
	_n_route_edit_container      = _fc("RouteEditContainer")      as Control
	_n_edit_route_btn            = _fc("EditRouteBtn")            as Button
	_n_tree_size_container       = _fc("TreeSizeContainer")       as Control
	_n_tree_size_option          = _fc("TreeSizeOption")          as OptionButton
	_n_balance_label             = _fc("BalanceLabel")            as Label
	if _n_balance_label:
		_n_balance_label.text = "$%s" % _fmt_bal(EconomyManager.balance)

	# Tool buttons + connect their signals
	var btn_names := ["GrassBtn","FairwayBtn","PathBtn","WaterBtn","RoughBtn",
					  "TreeBtn","TeeBtn","BasketBtn","EntranceBtn",
					  "ParkingBtn","RestroomBtn","FoodStandBtn","ProShopBtn",
					  "SandBtn","RockBtn","OBBtn",
					  "RaiseBtn","LowerBtn"]
	const TOOL_TOOLTIPS := [
		"Grass — natural ground cover. No effect on play. Free to place.",
		"Fairway — trimmed grass. Disc slides further on landing. No penalty. Boosts hole rating.",
		"Path — walkway for players and staff. No penalty. Connects facilities.",
		"Water — HAZARD: +1 penalty stroke. Disc returns to last valid position. Adds excitement to hole rating.",
		"Rough — thick grass. HAZARD: +1 penalty stroke when disc lands here. Adds variety bonus to rating.",
		"Tree — obstacle. Blocks disc flight based on size. No penalty stroke — disc lands at last valid spot.",
		"Tee Pad — hole starting point. One per hole required. Must pair with a Basket.",
		"Basket — hole target. One per hole required. Must pair with a Tee Pad.",
		"Entrance — course entry gate. Required for players to enter. One is enough.",
		"Parking — car park. Increases player capacity. Satisfies no NPC needs.",
		"Restroom — essential facility. Satisfies player bathroom need — prevents early leave. Boosts happiness.",
		"Food Stand — essential facility. Satisfies player hunger and thirst. Generates passive income.",
		"Pro Shop — premium facility. Required for Pro Invitational events. Boosts VIP visit rate. 3×3 building.",
		"Sand — bunker. HAZARD: +1 penalty stroke when disc lands here. Adds challenge to hole rating.",
		"Rock — boulder. Deflects disc to a random nearby cell. No penalty stroke. Creates unpredictable play.",
		"OB Zone — out-of-bounds marker. HAZARD: +1 penalty stroke, disc returns to last valid position.",
		"Raise Terrain — increase tile elevation. Cost per click. Purely visual — no gameplay effect.",
		"Lower Terrain — decrease tile elevation. Cost per click. Purely visual — no gameplay effect.",
	]
	_tool_buttons.clear()
	for i in btn_names.size():
		var btn := _fc(btn_names[i]) as Button
		_tool_buttons.append(btn)
		if btn:
			var idx := i
			btn.pressed.connect(func(): _on_tool_pressed(idx))
			if i < TOOL_TOOLTIPS.size():
				btn.tooltip_text = TOOL_TOOLTIPS[i]

	# Select/edit tool button (index 15, separate from paint tools)
	var select_btn := _fc("SelectBtn") as Button
	_tool_buttons.append(select_btn)
	if select_btn:
		select_btn.pressed.connect(func(): _on_tool_pressed(TOOL_SELECT))
		select_btn.tooltip_text = "Select — click a tile to inspect or edit it"

	# Decor tool buttons — values 20/21/22, not contiguous with btn_names array
	const DECOR_TOOLS := [
		["BenchBtn",     TOOL_BENCH,      "Bench — seating area. Gives a binary happiness bonus to nearby holes (one is enough per hole, global cap: 20 pieces). No penalty effect."],
		["FlowerBedBtn", TOOL_FLOWER_BED, "Flower Bed — colorful planting. Gives a binary rating bonus to nearby holes (one is enough per hole, global cap: 20 pieces). No penalty effect."],
		["SculptureBtn", TOOL_SCULPTURE,  "Sculpture — landmark art piece. Best combined rating + happiness bonus. Expensive. Binary per hole, global cap: 20 pieces. No penalty effect."],
		["LampPostBtn",  TOOL_LAMP_POST,  "Lamp Post — decorative street lamp. PURELY COSMETIC. No effect on rating, happiness, or gameplay whatsoever."],
		["SignBtn",      TOOL_SIGN,       "Sign — info/directional signage. PURELY COSMETIC. No effect on rating, happiness, or gameplay whatsoever."],
		["GardenBtn",    TOOL_GARDEN,     "Garden — stone-bordered plant bed. PURELY COSMETIC. No effect on rating, happiness, or gameplay whatsoever."],
	]
	for entry in DECOR_TOOLS:
		var dname: String = entry[0] as String
		var dtool: int    = entry[1] as int
		var dtip:  String = entry[2] as String
		var dbtn := _fc(dname) as Button
		if dbtn:
			_decor_tool_buttons[dtool] = dbtn
			dbtn.pressed.connect(func(): _on_tool_pressed(dtool))
			dbtn.tooltip_text = dtip

	# Nav buttons
	var back_btn := _fc("BackButton") as Button
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	var save_btn := _fc("SaveButton") as Button
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
		var layouts_btn := Button.new()
		layouts_btn.name = "LayoutsBtn"
		layouts_btn.text = "📁 Layouts"
		layouts_btn.custom_minimum_size = Vector2(100, 44)
		layouts_btn.tooltip_text = "Save or load up to %d named course layout snapshots." % LAYOUT_SLOTS
		save_btn.add_sibling(layouts_btn)
		layouts_btn.pressed.connect(_on_layouts_pressed)

	var undo_btn := _fc("UndoButton") as Button
	if undo_btn:
		undo_btn.tooltip_text = "Undo last change  (⌘Z / Ctrl+Z) — a whole drag undoes at once"
		undo_btn.pressed.connect(func() -> void:
			if GameManager.world:
				(GameManager.world as GameWorld3D).undo_paint())

	_n_erase_btn = _fc("EraseButton") as Button
	if _n_erase_btn:
		_n_erase_btn.toggle_mode = true
		_n_erase_btn.tooltip_text = "Erase — remove anything (tees, baskets, trees, buildings) back to grass. Delete key erases under the cursor. Other tools never paint over objects."
		_n_erase_btn.pressed.connect(func() -> void: _on_tool_pressed(TOOL_ERASE))

	var toggle_btn := _fc("TogglePanelBtn") as Button
	if toggle_btn:
		toggle_btn.pressed.connect(_on_toggle_panel_pressed)

	var manage_btn := _fc("ManageHolesBtn") as Button
	if manage_btn:
		manage_btn.pressed.connect(_on_manage_holes_pressed)
		# Architect button as sibling in TopHBox
		var arch_btn := Button.new()
		arch_btn.name = "ArchitectBtn"
		arch_btn.text = "Architect"
		arch_btn.custom_minimum_size = Vector2(90, 44)
		manage_btn.add_sibling(arch_btn)
		arch_btn.pressed.connect(_on_architect_pressed)

	var hm_close := _fc("HMCloseBtn") as Button
	if hm_close:
		hm_close.pressed.connect(_on_close_holes_pressed)

	# Hole number spinbox
	var hole_spin := _fc("HoleNumSpin") as SpinBox
	if hole_spin:
		hole_spin.value_changed.connect(_on_hole_num_changed)

	# Tree variant option
	if _n_tree_variant_option:
		_n_tree_variant_option.add_item("Random")
		_n_tree_variant_option.add_item("Pine")
		_n_tree_variant_option.add_item("Deciduous")
		_n_tree_variant_option.selected = 0
		_n_tree_variant_option.item_selected.connect(_on_tree_variant_selected)

	# Tree size option
	if _n_tree_size_option:
		_n_tree_size_option.add_item("Small")
		_n_tree_size_option.add_item("Medium")
		_n_tree_size_option.add_item("Tall")
		_n_tree_size_option.selected = 2   # default tall — matches GameWorld3D _active_tree_size=2
		_n_tree_size_option.item_selected.connect(_on_tree_size_selected)

	# Facility color option
	if _n_facility_color_option:
		var color_names := ["Default","Red","Blue","Green","Yellow","Purple"]
		for cn in color_names:
			_n_facility_color_option.add_item(cn)
		_n_facility_color_option.selected = 0
		_n_facility_color_option.item_selected.connect(_on_facility_color_selected)

	var orient_lbl := _fc("OrientLabel") as Label
	if orient_lbl:
		orient_lbl.text = "TEE FACING\nAuto-aims at its basket · R rotates"
	# Orientation buttons
	var face_names := ["FaceNBtn","FaceEBtn","FaceSBtn","FaceWBtn"]
	for i in face_names.size():
		var fbtn := _fc(face_names[i]) as Button
		if fbtn:
			var o := i
			fbtn.pressed.connect(func(): _on_orientation_pressed(o))

	# Route edit buttons
	if _n_edit_route_btn:
		_n_edit_route_btn.pressed.connect(_on_edit_route_pressed)
	var clear_route_btn := _fc("ClearRouteBtn") as Button
	if clear_route_btn:
		clear_route_btn.pressed.connect(_on_clear_route_pressed)

	_build_architect_overlay()
	_build_confirm_panel()
	_setup_palette_tabs()
	_highlight_tool(TOOL_GRASS)
	_refresh_side_panels()

func _setup_palette_tabs() -> void:
	const GROUP_NAMES := ["TerrainGroup","ObjectsGroup","FacilitiesGroup","TerraformGroup","DecorGroup","SelectGroup"]
	const TAB_NAMES   := ["TabTerrain","TabObjects","TabFacilities","TabTerraform","TabDecor","TabSelect"]
	_n_palette_groups.clear()
	_palette_tab_btns.clear()
	for gname in GROUP_NAMES:
		_n_palette_groups.append(_fc(gname) as Control)
	for i in TAB_NAMES.size():
		var tb := _fc(TAB_NAMES[i]) as Button
		_palette_tab_btns.append(tb)
		if tb:
			var idx := i
			tb.pressed.connect(func() -> void: _switch_palette_tab(idx))
	_switch_palette_tab(0)

func _switch_palette_tab(idx: int) -> void:
	_active_palette_tab = idx
	for i in _n_palette_groups.size():
		var g := _n_palette_groups[i] as Control
		if g:
			g.visible = (i == idx)
	for i in _palette_tab_btns.size():
		var tb := _palette_tab_btns[i] as Button
		if tb:
			tb.button_pressed = (i == idx)

func on_screen_entered(_params: Dictionary = {}) -> void:
	if GameManager.world:
		var w := GameManager.world as GameWorld3D
		w.set_active_variant(_active_variant)
		w.set_active_hole_num(_active_hole_num)
		w.set_active_orientation(_active_orientation)
		if not w.tile_info_requested.is_connected(_on_tile_info_requested):
			w.tile_info_requested.connect(_on_tile_info_requested)
		if not w.facility_info_requested.is_connected(_on_facility_info_requested):
			w.facility_info_requested.connect(_on_facility_info_requested)
		if not w.route_changed.is_connected(_on_route_changed):
			w.route_changed.connect(_on_route_changed)
	_apply_world_tool_mode()
	call_deferred("_update_course_stats")
	if not EventBus.balance_changed.is_connected(_on_builder_balance_changed):
		EventBus.balance_changed.connect(_on_builder_balance_changed)
	if not EventBus.tee_painted.is_connected(_on_tee_painted):
		EventBus.tee_painted.connect(_on_tee_painted)
	if _n_balance_label:
		_n_balance_label.text = "$%s" % _fmt_bal(EconomyManager.balance)

func on_screen_exited() -> void:
	if GameManager.world:
		var w := GameManager.world as GameWorld3D
		w.set_select_mode(false)
		w.set_builder_mode(false)
		if w.tile_info_requested.is_connected(_on_tile_info_requested):
			w.tile_info_requested.disconnect(_on_tile_info_requested)
		if w.facility_info_requested.is_connected(_on_facility_info_requested):
			w.facility_info_requested.disconnect(_on_facility_info_requested)
		if w.route_changed.is_connected(_on_route_changed):
			w.route_changed.disconnect(_on_route_changed)
		if _route_edit_active:
			w.set_route_edit_mode(_selected_hole_num, false)
	_editing_selected   = false
	_route_edit_active  = false
	if _n_hole_manager_overlay:
		_n_hole_manager_overlay.visible = false
	if _n_architect_overlay:
		_n_architect_overlay.visible = false
	if _n_confirm_panel:
		_n_confirm_panel.visible = false
	if EventBus.balance_changed.is_connected(_on_builder_balance_changed):
		EventBus.balance_changed.disconnect(_on_builder_balance_changed)
	if EventBus.tee_painted.is_connected(_on_tee_painted):
		EventBus.tee_painted.disconnect(_on_tee_painted)
	_pending_template      = ""
	_confirm_template_name = ""
	_confirm_template_tee  = Vector2i(-9999, -9999)
	if GameManager.world:
		(GameManager.world as GameWorld3D).clear_template_ghost()

# -- Panel toggle -----------------------------------------------------------------

func _on_toggle_panel_pressed() -> void:
	if _n_left_stats_panel:
		_n_left_stats_panel.visible = not _n_left_stats_panel.visible

# -- Tool selection ---------------------------------------------------------------

func _on_tool_pressed(tile_type: int) -> void:
	if _route_edit_active and GameManager.world:
		(GameManager.world as GameWorld3D).set_route_edit_mode(_selected_hole_num, false)
		_route_edit_active = false
		if _n_edit_route_btn:
			_n_edit_route_btn.button_pressed = false
	_active_tool = tile_type
	_highlight_tool(tile_type)
	_editing_selected = false
	if tile_type == TOOL_SELECT:
		_selected_cell = Vector2i(-1, -1)
		_selected_tile_type = -1
		EventBus.notification_requested.emit(
			"Select: click an object to edit it · drag it to move · Delete removes it.", "info")
	_apply_world_tool_mode()
	_refresh_side_panels()

## Put the world in the mode the active tool needs. Select isn't a paint tool —
## the world must never be told to paint tile type 18.
func _apply_world_tool_mode() -> void:
	if not GameManager.world:
		return
	var w := GameManager.world as GameWorld3D
	if _active_tool == TOOL_SELECT:
		w.set_builder_mode(false)
		w.set_select_mode(true)
	else:
		w.set_select_mode(false)
		w.set_builder_mode(true)
		w.set_active_tool(_active_tool)

func _highlight_tool(tile_type: int) -> void:
	for i in _tool_buttons.size():
		if _tool_buttons[i]:
			_tool_buttons[i].button_pressed = (i == tile_type)
	for dtool in _decor_tool_buttons:
		var dbtn := _decor_tool_buttons[dtool] as Button
		if dbtn:
			dbtn.button_pressed = (dtool == tile_type)
	if _n_erase_btn:
		_n_erase_btn.set_pressed_no_signal(tile_type == TOOL_ERASE)

func _refresh_side_panels() -> void:
	var hole_vis       := false
	var orient_vis     := false
	var tree_vis       := false
	var facility_vis   := false
	var context_vis    := false
	var route_edit_vis := false

	if _active_tool == TOOL_SELECT and _editing_selected:
		var is_facility  := (_selected_tile_type >= TOOL_PARKING and _selected_tile_type <= TOOL_PRO_SHOP)
		var is_hole_tile := (_selected_tile_type == TOOL_TEE or _selected_tile_type == TOOL_BASKET)
		var is_tree_sel  := _selected_tile_type == TOOL_TREE
		hole_vis       = is_hole_tile
		orient_vis     = (_selected_tile_type == TOOL_TEE or is_facility)
		facility_vis   = is_facility
		route_edit_vis = is_hole_tile
		context_vis    = is_hole_tile or is_facility or is_tree_sel
	else:
		var is_tee    := _active_tool == TOOL_TEE
		var is_basket := _active_tool == TOOL_BASKET
		var is_tree   := _active_tool == TOOL_TREE
		hole_vis    = is_tee or is_basket
		orient_vis  = is_tee
		tree_vis    = is_tree
		route_edit_vis = is_tee or is_basket
		context_vis = is_tee or is_basket or is_tree

	if _n_hole_num_container:        _n_hole_num_container.visible        = hole_vis
	if _n_orientation_container:     _n_orientation_container.visible     = orient_vis
	if _n_tree_variant_container:    _n_tree_variant_container.visible    = tree_vis
	if _n_tree_size_container:       _n_tree_size_container.visible       = tree_vis or (_editing_selected and _selected_tile_type == TOOL_TREE)
	if _n_facility_color_container:  _n_facility_color_container.visible  = facility_vis
	if _n_route_edit_container:      _n_route_edit_container.visible      = route_edit_vis
	if _n_left_panel:                _n_left_panel.visible                = context_vis
	_update_course_stats()

# -- Select / edit tile -----------------------------------------------------------

func _on_tile_info_requested(cell: Vector2i, tile_type: int, hole_num: int, orientation: int) -> void:
	_selected_cell      = cell
	_selected_tile_type = tile_type
	_selected_hole_num  = hole_num
	_editing_selected   = true
	# Leaving route edit mode when a new tile is selected
	if _route_edit_active and GameManager.world:
		(GameManager.world as GameWorld3D).set_route_edit_mode(_selected_hole_num, false)
		_route_edit_active = false
		if _n_edit_route_btn:
			_n_edit_route_btn.button_pressed = false

	if tile_type == TOOL_TREE:
		if _n_tree_size_option:
			_n_tree_size_option.selected = clampi(orientation, 0, 2)   # carries the tree size
	elif tile_type != TOOL_TEE and tile_type != TOOL_BASKET:
		EventBus.notification_requested.emit("Drag it to move it · Delete removes it.", "info")

	var hole_spin := _fc("HoleNumSpin") as SpinBox
	if hole_spin and (tile_type == TOOL_TEE or tile_type == TOOL_BASKET):
		hole_spin.set_value_no_signal(hole_num)

	if tile_type == TOOL_TEE and _n_orient_btns:
		for i in _n_orient_btns.get_child_count():
			var btn := _n_orient_btns.get_child(i) as Button
			if btn:
				btn.button_pressed = (i == orientation)

	_refresh_side_panels()

func _on_facility_info_requested(cell: Vector2i, tile_type: int, orientation: int, color_idx: int) -> void:
	_selected_cell      = cell
	_selected_tile_type = tile_type
	_editing_selected   = true
	_selected_color_idx = color_idx

	if _n_orient_btns:
		for i in _n_orient_btns.get_child_count():
			var btn := _n_orient_btns.get_child(i) as Button
			if btn:
				btn.button_pressed = (i == orientation)

	if _n_facility_color_option:
		_n_facility_color_option.selected = color_idx

	_refresh_side_panels()

func _on_facility_color_selected(idx: int) -> void:
	_selected_color_idx = idx
	if GameManager.world and _selected_cell != Vector2i(-1, -1):
		(GameManager.world as GameWorld3D).set_tile_facility_color_idx(_selected_cell, idx)

# -- Side panel inputs ------------------------------------------------------------

func _on_hole_num_changed(value: float) -> void:
	if _editing_selected:
		if GameManager.world and _selected_cell != Vector2i(-1, -1):
			(GameManager.world as GameWorld3D).set_tile_hole_num(_selected_cell, int(value))
	else:
		_active_hole_num = int(value)
		if GameManager.world:
			GameManager.world.set_active_hole_num(_active_hole_num)
		# Keep Architect panel in sync when user switches active hole
		if _n_architect_overlay and _n_architect_overlay.visible:
			_architect_hole_num = _active_hole_num
			_refresh_architect_panel()

func _on_tree_variant_selected(index: int) -> void:
	_active_variant = index - 1
	if GameManager.world:
		GameManager.world.set_active_variant(_active_variant)

func _on_tree_size_selected(index: int) -> void:
	if _editing_selected and _selected_cell != Vector2i(-1, -1) and GameManager.world:
		(GameManager.world as GameWorld3D).set_tile_tree_size(_selected_cell, index)
	elif GameManager.world:
		(GameManager.world as GameWorld3D).set_active_tree_size(index)

func _on_orientation_pressed(o: int) -> void:
	if _editing_selected and _selected_cell != Vector2i(-1, -1):
		if _selected_tile_type == TOOL_TEE:
			(GameManager.world as GameWorld3D).set_tile_orientation(_selected_cell, o)
		elif _selected_tile_type >= TOOL_PARKING and _selected_tile_type <= TOOL_PRO_SHOP:
			(GameManager.world as GameWorld3D).set_tile_facility_orientation(_selected_cell, o)
	else:
		_active_orientation = o
		if GameManager.world:
			GameManager.world.set_active_orientation(o)
	if _n_orient_btns:
		for i in _n_orient_btns.get_child_count():
			var btn := _n_orient_btns.get_child(i) as Button
			if btn:
				btn.button_pressed = (i == o)

# -- Course stats -----------------------------------------------------------------

func _update_course_stats() -> void:
	if not GameManager.world or not _n_stats_label:
		return
	var world  := GameManager.world as GameWorld3D
	var holes  := world.get_holes_info()
	var total_par  := 0
	var total_dist := 0
	var total_rating := 0.0
	for h in holes:
		total_par    += h["par"] as int
		total_dist   += h["distance"] as int
		total_rating += world.get_hole_rating(h)
	var avg_rating := total_rating / maxf(float(holes.size()), 1.0)
	var stars := ""
	for i in 5:
		stars += "★" if float(i) < avg_rating else "☆"
	var happiness_pct := int(world.get_course_happiness() * 100.0)
	_n_stats_label.text = "Holes: %d  |  Par: %d  |  Distance: %dm\nRating: %s  |  Happiness: %d%%" % \
		[holes.size(), total_par, total_dist, stars, happiness_pct]

# -- Hole Manager -----------------------------------------------------------------

func _on_manage_holes_pressed() -> void:
	if _n_hole_manager_overlay:
		_n_hole_manager_overlay.visible = true
	if GameManager.world:
		(GameManager.world as GameWorld3D).set_builder_mode(false)
	_refresh_hole_manager()

func _on_close_holes_pressed() -> void:
	if _n_hole_manager_overlay:
		_n_hole_manager_overlay.visible = false
	_apply_world_tool_mode()
	_update_course_stats()



func _on_edit_route_pressed() -> void:
	if not GameManager.world:
		return
	var w := GameManager.world as GameWorld3D
	if not _editing_selected:
		_selected_hole_num = _active_hole_num   # Tee/Basket tool: edit the active hole
	if not _route_edit_active and w.get_holes_info().filter(
			func(h: Dictionary) -> bool: return (h["hole_num"] as int) == _selected_hole_num).is_empty():
		EventBus.notification_requested.emit("Hole %d needs a tee and a basket before it has a route." % _selected_hole_num, "warning")
		if _n_edit_route_btn:
			_n_edit_route_btn.set_pressed_no_signal(false)
		return
	_route_edit_active = not _route_edit_active
	w.set_route_edit_mode(_selected_hole_num, _route_edit_active)
	if _n_edit_route_btn:
		_n_edit_route_btn.set_pressed_no_signal(_route_edit_active)
	if _route_edit_active:
		EventBus.notification_requested.emit(
			"Hole %d route: click to add a bend · drag a dot to move it · click a dot to remove it. Press Edit Route again when done." % _selected_hole_num, "info")
	else:
		_apply_world_tool_mode()

func _on_clear_route_pressed() -> void:
	if not _editing_selected:
		_selected_hole_num = _active_hole_num
	if GameManager.world:
		(GameManager.world as GameWorld3D).clear_route_waypoints(_selected_hole_num)
		EventBus.notification_requested.emit("Route waypoints cleared.", "info")

func _on_route_changed(_hole_num: int) -> void:
	pass  # could update a waypoint count label here in future

# -- Nav --------------------------------------------------------------------------

func _on_back_pressed() -> void:
	GameManager.change_state(GameManager.GameState.GAMEPLAY)

func _on_save_pressed() -> void:
	EventBus.save_requested.emit()
	EventBus.notification_requested.emit("Course saved!", "info")

func _on_tee_painted(cell: Vector2i, hole_num: int) -> void:
	if _pending_template.is_empty() or hole_num != _tmpl_hole_num:
		return
	var tname := _pending_template
	_pending_template = ""
	if GameManager.world:
		(GameManager.world as GameWorld3D).clear_template_ghost()
	# Small defer so the tee tile is fully committed before template paint runs
	call_deferred("_apply_template_at", tname, cell, hole_num)

func _on_builder_balance_changed(new_balance: float) -> void:
	if _n_balance_label:
		_n_balance_label.text = "$%s" % _fmt_bal(new_balance)

func _fmt_bal(amount: float) -> String:
	if amount >= 1_000_000: return "%.1fM" % (amount / 1_000_000.0)
	if amount >= 1000:      return "%.1fK" % (amount / 1000.0)
	return "%.0f" % amount

# ── Architect overlay ─────────────────────────────────────────────────────────


# ── Template ghost confirm panel ──────────────────────────────────────────────

func _build_confirm_panel() -> void:
	_n_confirm_panel = PanelContainer.new()
	_n_confirm_panel.visible = false
	_n_confirm_panel.anchor_left   = 0.5
	_n_confirm_panel.anchor_top    = 1.0
	_n_confirm_panel.anchor_right  = 0.5
	_n_confirm_panel.anchor_bottom = 1.0
	_n_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_n_confirm_panel.offset_left   = -160.0
	_n_confirm_panel.offset_right  =  160.0
	_n_confirm_panel.offset_top    =  -72.0
	_n_confirm_panel.offset_bottom =   -6.0
	add_child(_n_confirm_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	_n_confirm_panel.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Apply template here?"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var ok_btn := Button.new()
	ok_btn.text = "✓ Apply"
	ok_btn.custom_minimum_size = Vector2(84, 44)
	ok_btn.pressed.connect(_on_confirm_template)
	hbox.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "✕ Cancel"
	cancel_btn.custom_minimum_size = Vector2(84, 44)
	cancel_btn.pressed.connect(_on_cancel_template)
	hbox.add_child(cancel_btn)

func _on_confirm_template() -> void:
	if _confirm_template_name.is_empty() or not GameManager.world:
		return
	var tname := _confirm_template_name
	var tee   := _confirm_template_tee
	_confirm_template_name = ""
	_confirm_template_tee  = Vector2i(-9999, -9999)
	if _n_confirm_panel: _n_confirm_panel.visible = false
	(GameManager.world as GameWorld3D).clear_template_ghost()
	_apply_template_at(tname, tee, _tmpl_hole_num)

func _on_cancel_template() -> void:
	_confirm_template_name = ""
	_confirm_template_tee  = Vector2i(-9999, -9999)
	if _n_confirm_panel: _n_confirm_panel.visible = false
	if GameManager.world:
		(GameManager.world as GameWorld3D).clear_template_ghost()

# ── Architect handlers ────────────────────────────────────────────────────────

func _on_architect_pressed() -> void:
	if not _n_architect_overlay:
		return
	_architect_hole_num = _active_hole_num
	_n_architect_overlay.visible = true
	_refresh_architect_panel()

func _on_close_architect_pressed() -> void:
	if _n_architect_overlay:
		_n_architect_overlay.visible = false

func _on_arch_prev_hole() -> void:
	_architect_hole_num = maxi(1, _architect_hole_num - 1)
	_refresh_architect_panel()

func _on_arch_next_hole() -> void:
	_architect_hole_num = mini(18, _architect_hole_num + 1)
	_refresh_architect_panel()

func _refresh_architect_panel() -> void:
	if not _n_architect_overlay or not _n_architect_overlay.visible:
		return
	if _n_arch_hole_label:
		var h_dist := 0
		if GameManager.world:
			for h: Dictionary in (GameManager.world as GameWorld3D).get_holes_info():
				if (h["hole_num"] as int) == _architect_hole_num:
					h_dist = h["distance"] as int
					break
		if h_dist > 0:
			_n_arch_hole_label.text = "Hole %d  (%dm)" % [_architect_hole_num, h_dist]
		else:
			_n_arch_hole_label.text = "Hole %d  (no hole)" % _architect_hole_num
	if _n_arch_wp_label and GameManager.world:
		var cnt := (GameManager.world as GameWorld3D).get_route_waypoint_count(_architect_hole_num)
		_n_arch_wp_label.text = "Route waypoints: %d" % cnt

func _on_auto_route_pressed() -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var h_info := {}
	for h: Dictionary in world.get_holes_info():
		if (h["hole_num"] as int) == _architect_hole_num:
			h_info = h
			break
	if h_info.is_empty():
		EventBus.notification_requested.emit("Place a Tee+Basket for Hole %d first." % _architect_hole_num, "warning")
		return
	world.set_straight_route(_architect_hole_num, 4)
	_refresh_architect_panel()
	EventBus.notification_requested.emit("Straight route set — click Paint Route as Fairway to paint it.", "info")

func _on_paint_route_pressed() -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var width := int(_n_arch_width_spin.value) if _n_arch_width_spin else 3
	var n := world.paint_route_as_fairway(_architect_hole_num, width)
	if n > 0:
		EventBus.notification_requested.emit("Painted %d fairway tiles." % n, "info")
		_update_course_stats()
	else:
		EventBus.notification_requested.emit("No route — select Tee → Edit Route to add waypoints first.", "warning")
	_refresh_architect_panel()

func _on_add_rough_border_pressed() -> void:
	if not GameManager.world:
		return
	var n := (GameManager.world as GameWorld3D).add_rough_border_to_fairway(_architect_hole_num)
	if n > 0:
		EventBus.notification_requested.emit("Added %d rough border tiles." % n, "info")
		_update_course_stats()
	else:
		EventBus.notification_requested.emit("No fairway found for Hole %d." % _architect_hole_num, "warning")

func _on_apply_template_pressed(tname: String) -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var tmpl  := HoleTemplates.get_info(tname)
	if tmpl.is_empty():
		return
	var tiles: Array = tmpl["tiles"] as Array

	# Look for existing tee for the chosen hole
	var h_info: Dictionary = {}
	for h: Dictionary in world.get_holes_info():
		if (h["hole_num"] as int) == _tmpl_hole_num:
			h_info = h
			break

	if h_info.is_empty():
		# No tee yet — show cursor-following ghost, wait for user to place TEE
		_pending_template = tname
		world.set_active_tool(GameWorld3D.TileType.TEE)
		world.set_active_hole_num(_tmpl_hole_num)
		_active_tool     = GameWorld3D.TileType.TEE
		_active_hole_num = _tmpl_hole_num
		_highlight_tool(GameWorld3D.TileType.TEE)
		_refresh_side_panels()
		world.set_template_ghost(tiles)
		EventBus.notification_requested.emit(
			"Hole %d: place the Tee pad — ghost shows template layout." % _tmpl_hole_num, "info")
		return

	# Tee exists — show static ghost at tee position, wait for confirm
	var tee_cell   := h_info["tee_cell"] as Vector2i
	var tee_orient := world.get_tile_orientation(tee_cell)
	_confirm_template_name = tname
	_confirm_template_tee  = tee_cell
	world.anchor_template_ghost(tiles, tee_cell, tee_orient)
	if _n_confirm_panel: _n_confirm_panel.visible = true
	EventBus.notification_requested.emit("Template preview — click Apply to confirm.", "info")

func _apply_template_at(tname: String, tee_cell: Vector2i, hole_num: int) -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var tmpl := HoleTemplates.get_info(tname)
	if tmpl.is_empty():
		return
	var tiles: Array    = tmpl["tiles"] as Array
	var basket_off: Vector2i = tmpl.get("basket_offset", Vector2i(-9999, -9999)) as Vector2i
	var n := world.apply_hole_template(tee_cell, hole_num, tiles, basket_off)
	var tmpl_par: int = tmpl.get("par", 3) as int
	world.set_hole_par(tee_cell, tmpl_par)
	EventBus.notification_requested.emit(
		"Applied '%s' to Hole %d — %d tiles, par %d." % [tname, hole_num, n, tmpl_par], "info")
	_update_course_stats()

func _on_critique_pressed() -> void:
	if not GameManager.world:
		return
	var world := GameManager.world as GameWorld3D
	var h_info: Dictionary = {}
	for h: Dictionary in world.get_holes_info():
		if (h["hole_num"] as int) == _architect_hole_num:
			h_info = h
			break
	if h_info.is_empty():
		if _n_arch_critique_text:
			_n_arch_critique_text.text = "[color=red]No complete hole (tee + basket) for Hole %d.[/color]" % _architect_hole_num
		return
	var result := _critique_hole(h_info)
	var score: int    = result["score"]    as int
	var grade: String = result["grade"]    as String
	var crits: Array  = result["critiques"] as Array

	if _n_arch_grade_label:
		_n_arch_grade_label.text = grade
		var gc := Color.GREEN
		if   grade == "F" or grade == "D":  gc = Color(0.9, 0.2, 0.2)
		elif grade == "C":                  gc = Color(0.9, 0.55, 0.1)
		elif grade == "B":                  gc = Color(0.2, 0.7, 1.0)
		_n_arch_grade_label.add_theme_color_override("font_color", gc)
	if _n_arch_score_label:
		_n_arch_score_label.text = str(score)
	if _n_arch_critique_text:
		_n_arch_critique_text.text = "\n".join(crits)

# ── Hole critique logic ───────────────────────────────────────────────────────


# ── Layout slot system ────────────────────────────────────────────────────────






func _on_layouts_pressed() -> void:
	if _n_layouts_overlay and is_instance_valid(_n_layouts_overlay):
		_n_layouts_overlay.queue_free()
		_n_layouts_overlay = null
		return
	_build_layouts_overlay()

# ── Delegates to extracted modules (scenes/ui/screens/course_builder/, core/simulation/HoleCritique.gd) ──

func _critique_hole(hole_info: Dictionary) -> Dictionary:
	return HoleCritique.critique(hole_info)

func _refresh_hole_manager() -> void:
	_m_hole_manager_panel_get()._refresh_hole_manager()

func _get_hole_color(world: GameWorld3D, hole_num: int) -> Color:
	return _m_hole_manager_panel_get()._get_hole_color(world, hole_num)

var _m_hole_manager_panel: RefCounted = null
func _m_hole_manager_panel_get() -> RefCounted:
	if _m_hole_manager_panel == null:
		_m_hole_manager_panel = HoleManagerPanel.new(self)
	return _m_hole_manager_panel

func _layout_path(slot: int) -> String:
	return _m_layout_slots_get()._layout_path(slot)

func _load_layout_meta(slot: int) -> Dictionary:
	return _m_layout_slots_get()._load_layout_meta(slot)

func _save_layout(slot: int, slot_name: String) -> void:
	_m_layout_slots_get()._save_layout(slot, slot_name)

func _load_layout(slot: int) -> void:
	_m_layout_slots_get()._load_layout(slot)

func _delete_layout(slot: int) -> void:
	_m_layout_slots_get()._delete_layout(slot)

func _build_layouts_overlay() -> void:
	_m_layout_slots_get()._build_layouts_overlay()

func _refresh_layouts_overlay() -> void:
	_m_layout_slots_get()._refresh_layouts_overlay()

func _prompt_save_layout(slot: int) -> void:
	_m_layout_slots_get()._prompt_save_layout(slot)

var _m_layout_slots: RefCounted = null
func _m_layout_slots_get() -> RefCounted:
	if _m_layout_slots == null:
		_m_layout_slots = LayoutSlots.new(self)
	return _m_layout_slots

func _build_architect_overlay() -> void:
	_m_architect_overlay_get()._build_architect_overlay()

var _m_architect_overlay: RefCounted = null
func _m_architect_overlay_get() -> RefCounted:
	if _m_architect_overlay == null:
		_m_architect_overlay = ArchitectOverlay.new(self)
	return _m_architect_overlay
