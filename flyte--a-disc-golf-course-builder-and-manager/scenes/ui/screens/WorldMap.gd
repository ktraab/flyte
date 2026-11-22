## World Circuit — disc golf tour map. Hub for all destinations outside the home course.
extends Control

const _CourseUnlocks = preload("res://core/data/CourseUnlocks.gd")

# ── Location data ─────────────────────────────────────────────────────────────

const LOCATIONS: Array = [
	# ── Courses ──────────────────────────────────────────────────────────────
	{
		"id":           "home",
		"name":         "Your Course",
		"region":       "Home Base",
		"type":         "course",
		"icon":         "🏠",
		"color":        Color(0.15, 0.55, 0.20),
		"locked":       false,
		"unlock_key":   "",
		"unlock_label": "",
		"desc":         "Your disc golf empire. Build it, manage it, grow it.",
		"par":          0,
		"holes":        0,
		"difficulty":   0,
		"flavor":       "This is where it all starts.",
	},
	{
		"id":           "maple_ridge",
		"name":         "Maple Hill",
		"region":       "Leicester, MA",
		"type":         "course",
		"icon":         "🍁",
		"color":        Color(0.65, 0.22, 0.10),
		"locked":       true,
		"unlock_key":   "three_star",
		"unlock_label": "Reach 3★ home course rating",
		"desc":         "Rolling wooded hills and tight technical lines. Ranked among the world's finest for decades.",
		"par":          54,
		"holes":        18,
		"difficulty":   2,
		"flavor":       "Legendary. Waiting for you.",
	},
	{
		"id":           "winthrop_gold",
		"name":         "Winthrop Gold",
		"region":       "Winthrop, MN",
		"type":         "course",
		"icon":         "🌾",
		"color":        Color(0.72, 0.62, 0.18),
		"locked":       true,
		"unlock_key":   "first_tourney",
		"unlock_label": "Host your first tournament",
		"desc":         "Rolling Minnesota prairie with wide open fairways cut through golden meadows. Classic midwestern disc golf at its finest.",
		"par":          54,
		"holes":        18,
		"difficulty":   1,
		"flavor":       "Wide skies. Long lines.",
	},
	{
		"id":           "idlewild",
		"name":         "Idlewild",
		"region":       "Idlewild, KY",
		"type":         "course",
		"icon":         "🌿",
		"color":        Color(0.18, 0.50, 0.22),
		"locked":       true,
		"unlock_key":   "vip_visit",
		"unlock_label": "Host a VIP touring pro",
		"desc":         "Winding creek crossings, mature hardwoods, and some of the most beloved basket positions in the South. A PDGA Major gem.",
		"par":          54,
		"holes":        18,
		"difficulty":   2,
		"flavor":       "Disc golf royalty.",
	},
	{
		"id":           "disc_side_of_heaven",
		"name":         "Disc Side of Heaven",
		"region":       "Eureka, MO",
		"type":         "course",
		"icon":         "☁️",
		"color":        Color(0.42, 0.60, 0.85),
		"locked":       true,
		"unlock_key":   "fifty_players",
		"unlock_label": "Welcome 50 disc golfers",
		"desc":         "Dramatic hillside terrain carved into the Missouri bluffs. Elevation swings, exposed ridgelines, and views that stop you mid-round.",
		"par":          56,
		"holes":        18,
		"difficulty":   3,
		"flavor":       "The views are divine. The lies, less so.",
	},
	{
		"id":           "krokhol",
		"name":         "Krokhol",
		"region":       "Krokhol, Norway",
		"type":         "course",
		"icon":         "🌲",
		"color":        Color(0.14, 0.30, 0.20),
		"locked":       true,
		"unlock_key":   "balance_50k",
		"unlock_label": "Accumulate $50,000 empire balance",
		"desc":         "Dense Nordic boreal forest with precision tunnel shots and a glacial lake. One of Scandinavia's most respected courses.",
		"par":          58,
		"holes":        18,
		"difficulty":   3,
		"flavor":       "The forest always wins.",
	},
	{
		"id":           "ale_white",
		"name":         "Ale DGC — White",
		"region":       "Gothenburg, Sweden",
		"type":         "course",
		"icon":         "🇸🇪",
		"color":        Color(0.20, 0.35, 0.72),
		"locked":       true,
		"unlock_key":   "five_star",
		"unlock_label": "Achieve a 5★ home course rating",
		"desc":         "Classic European links-style layout with open fairways, strategic sand placement, and pristine course conditions. World-class at every hole.",
		"par":          54,
		"holes":        18,
		"difficulty":   2,
		"flavor":       "Precision over power.",
	},
	# ── Shops ────────────────────────────────────────────────────────────────
	{
		"id":           "disc_depot",
		"name":         "Disc Depot",
		"region":       "Online & Everywhere",
		"type":         "shop",
		"icon":         "🥏",
		"color":        Color(0.40, 0.20, 0.70),
		"locked":       true,
		"unlock_key":   "ten_players",
		"unlock_label": "Welcome 10 disc golfers",
		"desc":         "The internet's favorite disc retailer. Thousands of molds, every plastic run, new drops weekly.",
		"par":          0,
		"holes":        0,
		"difficulty":   0,
		"flavor":       "Disc golf's Amazon. Almost.",
	},
	{
		"id":           "bag_shack",
		"name":         "The Bag Shack",
		"region":       "Tour Circuit Shop",
		"type":         "shop",
		"icon":         "🎒",
		"color":        Color(0.55, 0.28, 0.58),
		"locked":       true,
		"unlock_key":   "first_staff",
		"unlock_label": "Hire your first staff member",
		"desc":         "Custom bags, carts, towels, mini markers. If it touches your bag, they've got it.",
		"par":          0,
		"holes":        0,
		"difficulty":   0,
		"flavor":       "Look good, play well.",
	},
	# ── Organizations ─────────────────────────────────────────────────────────
	{
		"id":           "wdga_hq",
		"name":         "WDGA Tour HQ",
		"region":       "Worldwide",
		"type":         "org",
		"icon":         "🏆",
		"color":        Color(0.72, 0.58, 0.12),
		"locked":       true,
		"unlock_key":   "first_tourney",
		"unlock_label": "Host your first tournament",
		"desc":         "World Disc Golf Association. The sanctioning body. Get affiliated and your tournaments count for world rankings.",
		"par":          0,
		"holes":        0,
		"difficulty":   0,
		"flavor":       "Go official.",
	},
	# ── Media ────────────────────────────────────────────────────────────────
	{
		"id":           "bromez",
		"name":         "Bromez",
		"region":       "Disc Golf Media",
		"type":         "media",
		"icon":         "🎬",
		"color":        Color(0.85, 0.35, 0.08),
		"locked":       true,
		"unlock_key":   "prestige_regional",
		"unlock_label": "Reach Regional prestige tier",
		"desc":         "The premier disc golf production house. World-class coverage, slow-motion chains, commentary that makes grown adults cry.",
		"par":          0,
		"holes":        0,
		"difficulty":   0,
		"flavor":       "You've seen their videos. Now they want to film yours.",
	},
]

const DIFFICULTY_LABELS := ["Starter", "Intermediate", "Expert", "Elite"]
const DIFFICULTY_COLORS := [
	Color(0.35, 0.85, 0.45),   # Starter — green
	Color(0.90, 0.82, 0.20),   # Intermediate — yellow
	Color(1.00, 0.55, 0.15),   # Expert — orange
	Color(0.95, 0.25, 0.25),   # Elite — red
]

# ── State ─────────────────────────────────────────────────────────────────────

var _detail_panel: PanelContainer = null
var _selected_id:  String         = ""
var _active_filter: String        = "all"   # "all" | "courses" | "other"
var _from_state: int              = GameManager.GameState.MAIN_MENU
var _filter_btns: Dictionary      = {}      # filter_key -> Button
var _card_grid: GridContainer     = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	call_deferred("_build_ui")

func on_screen_entered(params: Dictionary = {}) -> void:
	if params.has("from"):
		_from_state = params["from"] as int
	_rebuild_cards()
	_refresh_header()
	# Fire ch4 world-map beat on first entry — StoryManager guards duplicates internally
	if StoryManager.get_chapter() >= 4:
		StoryManager.fire_beat("ch4_world_map")

func on_screen_exited() -> void:
	pass

# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())
	root.add_child(HSeparator.new())
	root.add_child(_build_filter_bar())
	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	# Left: scrollable card grid
	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left",   16)
	scroll_margin.add_theme_constant_override("margin_right",  10)
	scroll_margin.add_theme_constant_override("margin_top",    14)
	scroll_margin.add_theme_constant_override("margin_bottom", 14)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body.add_child(scroll_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(scroll)

	_card_grid = GridContainer.new()
	_card_grid.columns = 3
	_card_grid.add_theme_constant_override("h_separation", 12)
	_card_grid.add_theme_constant_override("v_separation", 12)
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.name = "LocationGrid"
	scroll.add_child(_card_grid)

	# Right: detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(290, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = Color(0.07, 0.12, 0.08, 1.0)
	dp_sb.border_width_left = 1
	dp_sb.border_color = Color(0.18, 0.32, 0.16)
	_detail_panel.add_theme_stylebox_override("panel", dp_sb)
	body.add_child(_detail_panel)

	_build_detail_empty()
	_rebuild_cards()

func _build_header() -> Control:
	var hdr_margin := MarginContainer.new()
	hdr_margin.add_theme_constant_override("margin_left",   16)
	hdr_margin.add_theme_constant_override("margin_right",  16)
	hdr_margin.add_theme_constant_override("margin_top",    10)
	hdr_margin.add_theme_constant_override("margin_bottom", 10)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 14)
	hdr_margin.add_child(hdr)

	var back := Button.new()
	back.text = "← Back"
	back.custom_minimum_size = Vector2(90, 44)
	back.pressed.connect(_on_back_pressed)
	hdr.add_child(back)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 0)
	hdr.add_child(title_vbox)

	var title := Label.new()
	title.text = "WORLD CIRCUIT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.82, 0.94, 0.72))
	title_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Disc Golf World Tour — explore, challenge, grow"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.65, 0.44))
	title_vbox.add_child(subtitle)

	# Right side: prestige + unlock count
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 2)
	stats_vbox.name = "HeaderStats"
	hdr.add_child(stats_vbox)

	var prestige_lbl := Label.new()
	prestige_lbl.text = "%s  —  Prestige %.0f" % [EconomyManager.get_prestige_tier(), EconomyManager.get_prestige()]
	prestige_lbl.add_theme_font_size_override("font_size", 13)
	prestige_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.28))
	prestige_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prestige_lbl.name = "PrestigeLbl"
	stats_vbox.add_child(prestige_lbl)

	var courses_total := LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] == "course").size()
	var courses_unlocked := LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] == "course" and _is_unlocked(l)).size()
	var unlock_lbl := Label.new()
	unlock_lbl.text = "%d / %d courses unlocked" % [courses_unlocked, courses_total]
	unlock_lbl.add_theme_font_size_override("font_size", 11)
	unlock_lbl.add_theme_color_override("font_color", Color(0.52, 0.68, 0.48))
	unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unlock_lbl.name = "UnlockLbl"
	stats_vbox.add_child(unlock_lbl)

	var empire_lbl := Label.new()
	empire_lbl.text = "💰 Empire Balance: $%.0f  (20%% of course income)" % GameManager.get_empire_balance()
	empire_lbl.add_theme_font_size_override("font_size", 14)
	empire_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.35))
	empire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	empire_lbl.name = "EmpireLbl"
	stats_vbox.add_child(empire_lbl)

	# Spare course money → empire pool (buying circuit courses needs it).
	var invest_btn := Button.new()
	invest_btn.name = "InvestBtn"
	invest_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	invest_btn.tooltip_text = "Move half of this course's money into the empire pool (used to buy circuit courses)."
	var refresh_invest := func() -> void:
		var half := floorf(EconomyManager.balance * 0.5)
		invest_btn.text = "💼 Invest half of course funds ($%.0f)" % half
		invest_btn.disabled = half < 1000.0 or GameManager.is_away_round()
		empire_lbl.text = "💰 Empire Balance: $%.0f  (20%% of course income)" % GameManager.get_empire_balance()
	refresh_invest.call()
	invest_btn.pressed.connect(func() -> void:
		GameManager.invest_in_empire(floorf(EconomyManager.balance * 0.5))
		refresh_invest.call())
	stats_vbox.add_child(invest_btn)

	return hdr_margin

func _build_filter_bar() -> Control:
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left",   16)
	bar_margin.add_theme_constant_override("margin_right",  16)
	bar_margin.add_theme_constant_override("margin_top",    6)
	bar_margin.add_theme_constant_override("margin_bottom", 6)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar_margin.add_child(bar)

	var filter_lbl := Label.new()
	filter_lbl.text = "Show:"
	filter_lbl.add_theme_font_size_override("font_size", 12)
	filter_lbl.add_theme_color_override("font_color", Color(0.50, 0.60, 0.48))
	filter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(filter_lbl)

	for fkey in ["all", "courses", "other"]:
		var btn := Button.new()
		btn.text = {"all": "All", "courses": "Courses", "other": "Shops & More"}[fkey]
		btn.custom_minimum_size = Vector2(90, 44)
		btn.toggle_mode = true
		btn.button_pressed = (fkey == _active_filter)
		var fk: String = fkey
		btn.pressed.connect(func() -> void: _set_filter(fk))
		bar.add_child(btn)
		_filter_btns[fkey] = btn

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Legend
	for i in 4:
		if i > 0:
			var dot := Label.new()
			dot.text = "  "
			bar.add_child(dot)
		var leg := Label.new()
		leg.text = "● %s" % DIFFICULTY_LABELS[i]
		leg.add_theme_font_size_override("font_size", 10)
		leg.add_theme_color_override("font_color", DIFFICULTY_COLORS[i])
		leg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(leg)

	return bar_margin

func _refresh_header() -> void:
	var stats_vbox := find_child("HeaderStats", true, false) as VBoxContainer
	if not stats_vbox:
		return
	var prestige_lbl := stats_vbox.get_node_or_null("PrestigeLbl") as Label
	if prestige_lbl:
		prestige_lbl.text = "%s  —  Prestige %.0f" % [EconomyManager.get_prestige_tier(), EconomyManager.get_prestige()]
	var unlock_lbl := stats_vbox.get_node_or_null("UnlockLbl") as Label
	if unlock_lbl:
		var courses_total := LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] == "course").size()
		var courses_unlocked := LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] == "course" and _is_unlocked(l)).size()
		unlock_lbl.text = "%d / %d courses unlocked" % [courses_unlocked, courses_total]
	var empire_lbl := stats_vbox.get_node_or_null("EmpireLbl") as Label
	if empire_lbl:
		empire_lbl.text = "💰 Empire Balance: $%.0f  (20%% of course income)" % GameManager.get_empire_balance()

# ── Filter ─────────────────────────────────────────────────────────────────────

func _set_filter(fkey: String) -> void:
	_active_filter = fkey
	for k in _filter_btns:
		var btn: Button = _filter_btns[k]
		if is_instance_valid(btn):
			btn.button_pressed = (k == fkey)
	_rebuild_cards()

func _filtered_locations() -> Array:
	match _active_filter:
		"courses": return LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] == "course")
		"other":   return LOCATIONS.filter(func(l: Dictionary) -> bool: return l["type"] != "course")
		_:         return LOCATIONS

# ── Cards ─────────────────────────────────────────────────────────────────────

func _rebuild_cards() -> void:
	if not _card_grid:
		return
	for c in _card_grid.get_children():
		c.queue_free()

	var locs := _filtered_locations()
	var courses := locs.filter(func(l: Dictionary) -> bool: return l["type"] == "course")
	var other   := locs.filter(func(l: Dictionary) -> bool: return l["type"] != "course")

	if not courses.is_empty():
		_add_section_label("COURSES")
		_add_grid_spacer()
		_add_grid_spacer()
		for loc in courses:
			_card_grid.add_child(_make_location_card(loc as Dictionary))
		var rem := (3 - (courses.size() % 3)) % 3
		for _i in rem:
			_add_grid_spacer()

	if not other.is_empty():
		_add_section_label("SHOPS, ORGS & MEDIA")
		_add_grid_spacer()
		_add_grid_spacer()
		for loc in other:
			_card_grid.add_child(_make_location_card(loc as Dictionary))
		var rem2 := (3 - (other.size() % 3)) % 3
		for _i in rem2:
			_add_grid_spacer()

func _add_section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.60, 0.38))
	lbl.custom_minimum_size = Vector2(0, 26)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_card_grid.add_child(lbl)

func _add_grid_spacer() -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	_card_grid.add_child(sp)

func _make_location_card(loc: Dictionary) -> PanelContainer:
	var unlocked: bool = _is_unlocked(loc)
	var is_selected: bool = loc["id"] == _selected_id

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	var base_col: Color = loc["color"] as Color
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left  = 6
	if not unlocked:
		sb.bg_color = Color(0.09, 0.09, 0.10, 0.92)
	elif is_selected:
		sb.bg_color = base_col.darkened(0.15)
		sb.border_width_top = 2; sb.border_width_bottom = 2
		sb.border_width_left = 2; sb.border_width_right = 2
		sb.border_color = base_col.lightened(0.45)
	else:
		sb.bg_color = base_col.darkened(0.48)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   11)
	margin.add_theme_constant_override("margin_right",  11)
	margin.add_theme_constant_override("margin_top",    9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Top row: icon + name + lock/difficulty
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	vbox.add_child(top)

	var icon_lbl := Label.new()
	icon_lbl.text = loc["icon"] as String
	icon_lbl.add_theme_font_size_override("font_size", 16)
	if not unlocked:
		icon_lbl.modulate = Color(0.30, 0.30, 0.30)
	top.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = loc["name"] as String
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color",
		Color(0.88, 0.92, 0.84) if unlocked else Color(0.35, 0.35, 0.37))
	top.add_child(name_lbl)

	if not unlocked:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 12)
		top.add_child(lock_lbl)
	elif loc["type"] == "course" and loc["id"] != "home":
		var diff: int = loc.get("difficulty", 0) as int
		var diff_lbl := Label.new()
		diff_lbl.text = "●"
		diff_lbl.add_theme_font_size_override("font_size", 12)
		diff_lbl.add_theme_color_override("font_color", DIFFICULTY_COLORS[diff])
		diff_lbl.tooltip_text = DIFFICULTY_LABELS[diff]
		top.add_child(diff_lbl)

	# Region
	var region_lbl := Label.new()
	region_lbl.text = loc["region"] as String
	region_lbl.add_theme_font_size_override("font_size", 10)
	region_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.68, 0.50) if unlocked else Color(0.28, 0.28, 0.30))
	vbox.add_child(region_lbl)

	# Holes/par or type badge
	if loc["type"] == "course":
		if loc["id"] == "home":
			# Live stats for home course
			var rating_str := "No holes yet"
			if GameManager.world:
				var r: float = (GameManager.world as GameWorld3D).get_course_rating()
				var stars := ""
				for i in 5:
					stars += "★" if float(i) < r else "☆"
				rating_str = stars
			var live_lbl := Label.new()
			live_lbl.text = rating_str
			live_lbl.add_theme_font_size_override("font_size", 13)
			live_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.28))
			vbox.add_child(live_lbl)
		elif (loc["holes"] as int) > 0:
			var meta_lbl := Label.new()
			meta_lbl.text = "%d holes  ·  Par %d" % [loc["holes"] as int, loc["par"] as int]
			meta_lbl.add_theme_font_size_override("font_size", 11)
			meta_lbl.add_theme_color_override("font_color",
				Color(0.62, 0.75, 0.57) if unlocked else Color(0.26, 0.26, 0.28))
			vbox.add_child(meta_lbl)

	# Unlock progress bar (locked items only)
	if not unlocked:
		var prog: float = _get_unlock_progress(loc)
		if prog > 0.0:
			var prog_bar := ProgressBar.new()
			prog_bar.max_value = 1.0
			prog_bar.value = prog
			prog_bar.show_percentage = false
			prog_bar.custom_minimum_size = Vector2(0, 6)
			var psb := StyleBoxFlat.new()
			psb.bg_color = Color(0.75, 0.62, 0.18)
			prog_bar.add_theme_stylebox_override("fill", psb)
			vbox.add_child(prog_bar)

	# Bottom text: unlock requirement or flavor
	var bottom_lbl := Label.new()
	if not unlocked:
		bottom_lbl.text = loc["unlock_label"] as String
		bottom_lbl.add_theme_color_override("font_color", Color(0.48, 0.40, 0.18))
	else:
		bottom_lbl.text = loc.get("flavor", "") as String
		bottom_lbl.add_theme_color_override("font_color", Color(0.52, 0.68, 0.48))
	bottom_lbl.add_theme_font_size_override("font_size", 10)
	bottom_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vbox.add_child(bottom_lbl)

	# Invisible click overlay
	var btn_area := Button.new()
	btn_area.flat = true
	btn_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_area.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(btn_area)
	var loc_id: String = loc["id"] as String
	btn_area.pressed.connect(func() -> void: _on_card_pressed(loc_id))

	return panel

# ── Detail panel ──────────────────────────────────────────────────────────────

func _build_detail_empty() -> void:
	for c in _detail_panel.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "Select a destination\nto see details."
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.38, 0.50, 0.36))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(lbl)

func _build_detail(loc: Dictionary) -> void:
	for c in _detail_panel.get_children():
		c.queue_free()

	var unlocked: bool  = _is_unlocked(loc)
	var base_col: Color = loc["color"] as Color
	var type_key: String = loc["type"] as String

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Icon
	var icon_lbl := Label.new()
	icon_lbl.text = loc["icon"] as String
	icon_lbl.add_theme_font_size_override("font_size", 40)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not unlocked:
		icon_lbl.modulate = Color(0.28, 0.28, 0.28)
	vbox.add_child(icon_lbl)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = loc["name"] as String
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color",
		base_col.lightened(0.5) if unlocked else Color(0.36, 0.36, 0.38))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Region
	var region_lbl := Label.new()
	region_lbl.text = loc["region"] as String
	region_lbl.add_theme_font_size_override("font_size", 11)
	region_lbl.add_theme_color_override("font_color", Color(0.48, 0.62, 0.44))
	region_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(region_lbl)

	vbox.add_child(HSeparator.new())

	# Home course: live stats block
	if loc["id"] == "home" and GameManager.world:
		var world := GameManager.world as GameWorld3D
		var rating: float = world.get_course_rating()
		var holes_info := world.get_holes_info()
		var stars := ""
		for i in 5:
			stars += "★" if float(i) < rating else "☆"
		_add_stat_row(vbox, "Course Rating", "%s  (%.2f)" % [stars, rating], Color(1.0, 0.85, 0.28))
		_add_stat_row(vbox, "Holes Built", str(holes_info.size()), Color(0.7, 0.85, 1.0))
		var happiness: float = EconomyManager.current_happiness * 100.0
		_add_stat_row(vbox, "Player Happiness", "%.0f%%" % happiness,
			Color(0.3, 0.95, 0.4) if happiness >= 70.0 else Color(1.0, 0.75, 0.3))
		var prestige: float = EconomyManager.get_prestige()
		_add_stat_row(vbox, "Prestige", "%.0f / 100  (%s)" % [prestige, EconomyManager.get_prestige_tier()],
			Color(0.92, 0.78, 0.28))
		vbox.add_child(HSeparator.new())
	elif type_key == "course" and (loc["holes"] as int) > 0:
		var stats_row := HBoxContainer.new()
		stats_row.add_theme_constant_override("separation", 0)
		vbox.add_child(stats_row)
		_add_stat_block(stats_row, "HOLES", str(loc["holes"] as int))
		_add_stat_block(stats_row, "PAR",   str(loc["par"] as int))
		# Difficulty
		if loc["id"] != "home":
			var diff: int = loc.get("difficulty", 0) as int
			_add_stat_block(stats_row, "DIFFICULTY", DIFFICULTY_LABELS[diff], DIFFICULTY_COLORS[diff])
		# WDGA certification progress for circuit courses you own
		if loc["id"] != "home" and GameManager.is_course_owned(loc["id"] as String):
			var cid: String = loc["id"] as String
			var st: Dictionary = GameManager.get_course_stats(cid)
			if GameManager.is_course_certified(cid):
				_add_stat_row(vbox, "WDGA", "✓ Certified", Color(0.45, 0.95, 0.5))
			else:
				_add_stat_row(vbox, "WDGA certification",
					"%d/%d holes · %.1f/%.1f★ · restroom %s" % [
						int(st.get("holes", 0)), GameManager.CERT_MIN_HOLES,
						float(st.get("rating", 0.0)), GameManager.CERT_MIN_RATING,
						"✓" if int(st.get("restrooms", 0)) >= GameManager.CERT_MIN_RESTROOMS else "✗"],
					Color(0.85, 0.75, 0.40))

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = loc["desc"] as String
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color",
		Color(0.76, 0.84, 0.70) if unlocked else Color(0.33, 0.33, 0.35))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Type badge
	var type_labels := {
		"course": "COURSE", "shop": "SHOP", "org": "ORGANIZATION", "media": "MEDIA"
	}
	var type_colors := {
		"course": Color(0.20, 0.60, 0.25), "shop": Color(0.40, 0.20, 0.72),
		"org": Color(0.65, 0.50, 0.08),    "media": Color(0.75, 0.28, 0.05),
	}
	var badge_lbl := Label.new()
	badge_lbl.text = type_labels.get(type_key, "LOCATION") as String
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color",
		(type_colors.get(type_key, Color(0.5, 0.5, 0.5)) as Color).lightened(0.4))
	vbox.add_child(badge_lbl)

	# Unlock progress (locked only)
	if not unlocked:
		vbox.add_child(HSeparator.new())
		var lock_title := Label.new()
		lock_title.text = "🔒  LOCKED"
		lock_title.add_theme_font_size_override("font_size", 13)
		lock_title.add_theme_color_override("font_color", Color(0.62, 0.50, 0.18))
		vbox.add_child(lock_title)
		var lock_req := Label.new()
		lock_req.text = "Requirement: " + (loc["unlock_label"] as String)
		lock_req.add_theme_font_size_override("font_size", 11)
		lock_req.add_theme_color_override("font_color", Color(0.62, 0.52, 0.26))
		lock_req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lock_req)
		var prog: float = _get_unlock_progress(loc)
		if prog > 0.0:
			var prog_bar := ProgressBar.new()
			prog_bar.max_value = 1.0
			prog_bar.value = prog
			prog_bar.show_percentage = true
			prog_bar.custom_minimum_size = Vector2(0, 16)
			var psb := StyleBoxFlat.new()
			psb.bg_color = Color(0.80, 0.65, 0.18)
			prog_bar.add_theme_stylebox_override("fill", psb)
			vbox.add_child(prog_bar)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Action button
	if unlocked:
		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(0, 46)
		match type_key:
			"course":
				var loc_id: String = loc["id"] as String
				if loc_id == "home":
					if GameManager.active_course_id != "home":
						action_btn.text = "↩  Return to Your Course"
						action_btn.pressed.connect(func() -> void:
							GameManager.switch_to_course("home"))
					else:
						action_btn.text = "▶  Manage Your Course"
						action_btn.pressed.connect(func() -> void:
							GameManager.change_state(GameManager.GameState.GAMEPLAY))
				elif GameManager.is_course_owned(loc_id):
					if loc_id == GameManager.active_course_id:
						action_btn.text = "▶  Manage This Course"
						action_btn.pressed.connect(func() -> void:
							GameManager.change_state(GameManager.GameState.GAMEPLAY))
					else:
						action_btn.text = "↔  Switch to This Course"
						var sw_id: String = loc_id
						action_btn.pressed.connect(func() -> void:
							GameManager.switch_to_course(sw_id))
				else:
					var price := GameManager.get_course_price(loc_id)
					action_btn.text = "💰  Own for $%.0f  (Empire: $%.0f)" % [price, GameManager.get_empire_balance()]
					action_btn.disabled = GameManager.get_empire_balance() < price
					var buy_id: String = loc_id
					action_btn.pressed.connect(func() -> void:
						GameManager.buy_course(buy_id))
			"shop", "org", "media":
				# Tier buttons replace the single action button
				action_btn.queue_free()
				_build_affiliate_buttons(vbox, loc["id"] as String)
				return
		vbox.add_child(action_btn)
		if type_key == "course":
			_build_away_round_button(vbox, loc["id"] as String)

## STORY.md Ch4 — play the front nine at an unlocked circuit course (no purchase
## needed). Your own course is restored when you head home.
func _build_away_round_button(vbox: VBoxContainer, loc_id: String) -> void:
	if loc_id == "home" or not StoryManager.is_circuit_unlocked() \
			or not GameManager.can_play_away_round(loc_id):
		return
	var away_btn := Button.new()
	away_btn.text = "⛳  Play an Away Round  (front nine)"
	away_btn.custom_minimum_size = Vector2(0, 40)
	away_btn.pressed.connect(func() -> void:
		GameManager.start_away_round(loc_id))
	vbox.add_child(away_btn)
	var best: Variant = GameManager.get_away_best(loc_id)
	if best != null:
		_add_stat_row(vbox, "Best away round", GameManager.format_score(int(best)), Color(0.55, 0.85, 1.0))

func _build_affiliate_buttons(vbox: VBoxContainer, loc_id: String) -> void:
	var tiers: Array = GameManager.SHOP_TIER_DATA.get(loc_id, []) as Array
	var current_tier: int = GameManager.get_shop_tier(loc_id)

	vbox.add_child(HSeparator.new())
	var empire_lbl := Label.new()
	empire_lbl.text = "Empire Balance: $%.0f" % GameManager.get_empire_balance()
	empire_lbl.add_theme_font_size_override("font_size", 11)
	empire_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.55))
	vbox.add_child(empire_lbl)

	for i in tiers.size():
		var tier_data: Dictionary = tiers[i] as Dictionary
		var tier_num: int = i + 1
		var label: String = tier_data["label"] as String
		var cost: float   = tier_data["cost"] as float
		var desc: String  = tier_data["desc"] as String

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 46)
		btn.clip_text = false
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF

		if tier_num <= current_tier:
			btn.text = "✓  %s" % label
			btn.disabled = true
			btn.modulate = Color(0.5, 0.9, 0.5, 0.8)
		elif tier_num == current_tier + 1:
			btn.text = "💰  %s — $%.0f\n     %s" % [label, cost, desc]
			btn.disabled = GameManager.get_empire_balance() < cost
			var buy_id: String = loc_id
			var buy_tier: int  = tier_num
			btn.pressed.connect(func() -> void:
				if GameManager.buy_shop_tier(buy_id, buy_tier):
					_build_detail(_get_loc(buy_id)))
		else:
			btn.text = "🔒  %s — $%.0f" % [label, cost]
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6, 0.7)

		vbox.add_child(btn)

func _get_loc(loc_id: String) -> Dictionary:
	for l in LOCATIONS:
		if (l as Dictionary)["id"] == loc_id:
			return l as Dictionary
	return {}

func _add_stat_row(parent: VBoxContainer, key: String, value: String, val_color: Color = Color(0.88, 0.92, 0.84)) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", Color(0.50, 0.62, 0.46))
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", val_color)
	row.add_child(v)
	parent.add_child(row)

func _add_stat_block(parent: HBoxContainer, label_text: String, value_text: String, val_color: Color = Color(0.88, 0.92, 0.82)) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(vb)
	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", val_color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(val_lbl)
	var key_lbl := Label.new()
	key_lbl.text = label_text
	key_lbl.add_theme_font_size_override("font_size", 9)
	key_lbl.add_theme_color_override("font_color", Color(0.44, 0.56, 0.40))
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(key_lbl)

# ── Unlock logic ──────────────────────────────────────────────────────────────

func _is_unlocked(loc: Dictionary) -> bool:
	if not loc.get("locked", true):
		return true
	return _CourseUnlocks.is_met(loc.get("unlock_key", "") as String)

func _get_unlock_progress(loc: Dictionary) -> float:
	var key: String = loc.get("unlock_key", "") as String
	match key:
		"three_star":
			if GameManager.world:
				return clampf((GameManager.world as GameWorld3D).get_course_rating() / 3.0, 0.0, 1.0)
		"five_star":
			if GameManager.world:
				return clampf((GameManager.world as GameWorld3D).get_course_rating() / 5.0, 0.0, 1.0)
		"first_tourney":
			return 1.0 if EconomyManager.get_tournaments_run() >= 1 else 0.0
		"vip_visit":
			return 1.0 if GoalsSystem.is_goal_complete("vip_visit") else 0.0
		"fifty_players":
			return clampf(float(EconomyManager.get_total_rounds()) / 50.0, 0.0, 1.0)
		"ten_players":
			return clampf(float(EconomyManager.get_total_rounds()) / 10.0, 0.0, 1.0)
		"first_staff":
			var total := EconomyManager.get_staff_count(0) + EconomyManager.get_staff_count(1) + EconomyManager.get_staff_count(2)
			return 1.0 if total >= 1 else 0.0
		"balance_50k":
			return clampf(GameManager.get_empire_balance() / 50000.0, 0.0, 1.0)
		"prestige_regional":
			return clampf(EconomyManager.get_prestige() / 25.0, 0.0, 1.0)
	return 0.0

# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_card_pressed(loc_id: String) -> void:
	_selected_id = loc_id
	_rebuild_cards()
	var loc: Dictionary = {}
	for l in LOCATIONS:
		if (l as Dictionary)["id"] == loc_id:
			loc = l as Dictionary
			break
	if not loc.is_empty():
		_build_detail(loc)

func _on_back_pressed() -> void:
	GameManager.change_state(_from_state)
