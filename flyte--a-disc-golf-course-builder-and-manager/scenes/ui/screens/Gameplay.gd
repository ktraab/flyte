extends Control

const UI = preload("res://scenes/ui/screens/gameplay/UIKit.gd")
const StatsPanel = preload("res://scenes/ui/screens/gameplay/StatsPanel.gd")
const FeesPanel = preload("res://scenes/ui/screens/gameplay/FeesPanel.gd")
const StaffPanel = preload("res://scenes/ui/screens/gameplay/StaffPanel.gd")
const EventsPanel = preload("res://scenes/ui/screens/gameplay/EventsPanel.gd")
const HolePanel = preload("res://scenes/ui/screens/gameplay/HolePanel.gd")
const AnalyticsPanel = preload("res://scenes/ui/screens/gameplay/AnalyticsPanel.gd")

@onready var _balance_label:     Label          = $TopHUD/HUDMargin/VBox/Row1/BalanceLabel
@onready var _players_label:     Label          = $TopHUD/HUDMargin/VBox/Row1/PlayersLabel
@onready var _income_label:      Label          = $TopHUD/HUDMargin/VBox/Row1/IncomeLabel
@onready var _wind_label:        Label          = $TopHUD/HUDMargin/VBox/Row2/WindLabel
@onready var _rating_label:      Label          = $TopHUD/HUDMargin/VBox/Row2/RatingLabel
@onready var _happiness_label:   Label          = $TopHUD/HUDMargin/VBox/Row2/HappinessLabel
@onready var _day_label:         Label          = $TopHUD/HUDMargin/VBox/Row2/DayLabel
@onready var _goal_label:        Label          = $TopHUD/HUDMargin/VBox/Row3/GoalLabel
@onready var _tournament_btn:    Button         = $TopHUD/HUDMargin/VBox/Row1/Row1Btns/TournamentButton
@onready var _staff_overlay:     PanelContainer = $StaffOverlay
@onready var _staff_rows:        VBoxContainer  = $StaffOverlay/StaffMargin/StaffVBox/StaffScroll/StaffRows
@onready var _npc_info_panel:    PanelContainer = $NPCInfoPanel
@onready var _npc_info_title:    Label          = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCInfoTitle
@onready var _npc_info_badge:    Label          = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCInfoTypeBadge
@onready var _npc_info_action:   Label          = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCInfoAction
@onready var _npc_needs_section: VBoxContainer  = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCNeedsSection
@onready var _hunger_bar:        ProgressBar    = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCNeedsSection/HungerRow/HungerBar
@onready var _thirst_bar:        ProgressBar    = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCNeedsSection/ThirstRow/ThirstBar
@onready var _bathroom_bar:      ProgressBar    = $NPCInfoPanel/NPCInfoMargin/NPCInfoVBox/NPCNeedsSection/BathroomRow/BathroomBar
@onready var _stats_overlay:     PanelContainer = $StatsOverlay
@onready var _stats_vbox:        VBoxContainer  = $StatsOverlay/StatsContent/StatsScroll/StatsVBox
@onready var _fees_overlay:      PanelContainer = $FeesOverlay
@onready var _fees_vbox:         VBoxContainer  = $FeesOverlay/FeesContent/FeesScroll/FeesVBox
@onready var _minimap_panel:      PanelContainer = $MinimapPanel
@onready var _minimap_tex:        TextureRect    = $MinimapPanel/MinimapTex
@onready var _analytics_overlay:  PanelContainer = $AnalyticsOverlay
@onready var _analytics_vbox:     VBoxContainer  = $AnalyticsOverlay/AnalyticsContent/AnalyticsScroll/AnalyticsVBox

const MINIMAP_COLORS := {
	0:  Color(0.22, 0.50, 0.18),   # GRASS
	1:  Color(0.32, 0.78, 0.27),   # FAIRWAY
	2:  Color(0.62, 0.58, 0.48),   # PATH
	3:  Color(0.12, 0.38, 0.85),   # WATER
	4:  Color(0.42, 0.48, 0.22),   # ROUGH
	5:  Color(0.10, 0.25, 0.08),   # TREE
	6:  Color(0.58, 0.22, 0.80),   # TEE
	7:  Color(1.00, 0.52, 0.08),   # BASKET
	8:  Color(0.88, 0.78, 0.55),   # ENTRANCE
	9:  Color(0.72, 0.68, 0.58),   # PARKING
	10: Color(0.65, 0.80, 0.92),   # RESTROOM
	11: Color(0.95, 0.62, 0.18),   # FOOD_STAND
	12: Color(0.85, 0.28, 0.22),   # PRO_SHOP
	13: Color(0.92, 0.86, 0.65),   # SAND
}

var _active_players: int = 0
var _tourney_refresh_t: float = 0.0
var _minimap_refresh_t: float = 0.0
var _npc_panel_refresh_t: float = 0.0
var _inspected_npc: Node3D = null   # live reference for info panel updates

# Score leaderboard — running totals since session start
var _score_condor:  int = 0
var _score_albatross: int = 0
var _score_eagle:   int = 0
var _score_birdie:  int = 0
var _score_par:     int = 0
var _score_bogey:   int = 0
var _score_double:  int = 0
var _score_worse:   int = 0
var _best_round_diff: int = 999   # best (lowest) round total vs par this session
var _minimap_image: Image
var _minimap_texture: ImageTexture
var _minimap_base: Image = null     # terrain + OB layer, redrawn only when the course changes
var _minimap_base_key: int = 0
var _play_test: PlayTestController = null
var _events_overlay: PanelContainer = null
var _events_vbox: VBoxContainer = null
var _goals_overlay: PanelContainer = null
var _goals_vbox: VBoxContainer = null
var _hole_overlay: PanelContainer = null
var _hole_vbox: VBoxContainer = null
var _fps_label: Label = null
var _modal_backdrop: ColorRect = null
var _time_speed: float = 1.0
var _speed_btns: Array[Button] = []

# Hole analytics — keyed by hole_idx (0-based), populated from hole_scored signal
var _hole_stats: Dictionary = {}
# Autosave
const AUTOSAVE_INTERVAL := 300.0
var _autosave_t: float = 0.0
var _autosave_label: Label = null
var _course_name_label: Label = null
var _circuit_btn: Button = null
var _xp_label: Label = null

func _ready() -> void:
	call_deferred("_setup_hud_extras")

func _setup_hud_extras() -> void:
	var row1_btns := find_child("Row1Btns", true, false) as HBoxContainer
	if row1_btns:
		var btn := Button.new()
		btn.text = "Events"
		btn.custom_minimum_size = Vector2(70, 44)
		btn.pressed.connect(_on_events_pressed)
		row1_btns.add_child(btn)
		var gbtn := Button.new()
		gbtn.text = "Goals"
		gbtn.custom_minimum_size = Vector2(70, 44)
		gbtn.pressed.connect(_on_goals_pressed)
		row1_btns.add_child(gbtn)
		_circuit_btn = Button.new()
		_circuit_btn.text = "Circuit"
		_circuit_btn.custom_minimum_size = Vector2(72, 44)
		_circuit_btn.pressed.connect(func() -> void:
			GameManager.change_state(GameManager.GameState.WORLD_MAP))
		_circuit_btn.visible = StoryManager.is_circuit_unlocked()
		row1_btns.add_child(_circuit_btn)
		_course_name_label = Label.new()
		_course_name_label.add_theme_font_size_override("font_size", 11)
		_course_name_label.add_theme_color_override("font_color", Color(0.65, 0.88, 0.60))
		_course_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_course_name_label.custom_minimum_size = Vector2(0, 44)
		row1_btns.add_child(_course_name_label)
		# Time speed buttons
		var sep_lbl := Label.new()
		sep_lbl.text = "│"
		sep_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		sep_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row1_btns.add_child(sep_lbl)
		for spd in [1.0, 1.5, 2.0]:
			var sb := Button.new()
			sb.text = "%.0fx" % spd if spd == 1.0 else "%.1fx" % spd
			sb.custom_minimum_size = Vector2(52, 44)
			var sv: float = spd
			sb.pressed.connect(func() -> void: _set_time_speed(sv))
			row1_btns.add_child(sb)
			_speed_btns.append(sb)
		_refresh_speed_btns()
		# XP / Level chip — shows Lv.N and XP progress
		var sep2 := Label.new()
		sep2.text = "│"
		sep2.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		sep2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row1_btns.add_child(sep2)
		_xp_label = Label.new()
		_xp_label.add_theme_font_size_override("font_size", 11)
		_xp_label.add_theme_color_override("font_color", Color(0.72, 0.58, 1.0))
		_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row1_btns.add_child(_xp_label)
		_refresh_xp_label()
	var abtn := find_child("AnalyticsButton", true, false) as Button
	if abtn and not abtn.pressed.is_connected(_on_analytics_pressed):
		abtn.pressed.connect(_on_analytics_pressed)
	_build_modal_backdrop()
	_build_events_overlay()
	_build_goals_overlay()
	_build_hole_overlay()
	_style_hud()
	# FPS counter — bottom-left corner
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.position = Vector2(6.0, -22.0)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)
	# Autosave indicator — bottom-right corner
	_autosave_label = Label.new()
	_autosave_label.add_theme_font_size_override("font_size", 12)
	_autosave_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.60))
	_autosave_label.anchor_left   = 1.0
	_autosave_label.anchor_right  = 1.0
	_autosave_label.anchor_top    = 1.0
	_autosave_label.anchor_bottom = 1.0
	_autosave_label.offset_left   = -130.0
	_autosave_label.offset_right  = -6.0
	_autosave_label.offset_top    = -24.0
	_autosave_label.offset_bottom = -6.0
	_autosave_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_autosave_label.visible       = false
	add_child(_autosave_label)

func _build_modal_backdrop() -> void:
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.color = Color(0, 0, 0, 0)          # fully transparent
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # eats all mouse events
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.visible = false
	add_child(_modal_backdrop)
	move_child(_modal_backdrop, 0)  # behind overlays but above the world

func _update_modal_backdrop() -> void:
	if not _modal_backdrop:
		return
	var any_open := (
		(_staff_overlay     and _staff_overlay.visible)     or
		(_stats_overlay     and _stats_overlay.visible)     or
		(_fees_overlay      and _fees_overlay.visible)      or
		(_events_overlay    and _events_overlay.visible)    or
		(_goals_overlay     and _goals_overlay.visible)     or
		(_hole_overlay      and _hole_overlay.visible)      or
		(_analytics_overlay and _analytics_overlay.visible)
	)
	_modal_backdrop.visible = any_open

func _build_events_overlay() -> void:
	_events_overlay = PanelContainer.new()
	_events_overlay.anchor_left   = 0.5
	_events_overlay.anchor_right  = 0.5
	_events_overlay.anchor_top    = 0.5
	_events_overlay.anchor_bottom = 0.5
	_events_overlay.offset_left   = -270.0
	_events_overlay.offset_right  = 270.0
	_events_overlay.offset_top    = -340.0
	_events_overlay.offset_bottom = 340.0
	_events_overlay.visible = false
	add_child(_events_overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_events_overlay.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_events_vbox = VBoxContainer.new()
	_events_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_events_vbox)

func _build_goals_overlay() -> void:
	_goals_overlay = PanelContainer.new()
	_goals_overlay.anchor_left   = 0.5
	_goals_overlay.anchor_right  = 0.5
	_goals_overlay.anchor_top    = 0.5
	_goals_overlay.anchor_bottom = 0.5
	_goals_overlay.offset_left   = -300.0
	_goals_overlay.offset_right  = 300.0
	_goals_overlay.offset_top    = -370.0
	_goals_overlay.offset_bottom = 370.0
	_goals_overlay.visible = false
	add_child(_goals_overlay)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_goals_overlay.add_child(outer)
	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = "Objectives"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_constant_override("margin_left", 16)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 16)
	hm.add_theme_constant_override("margin_top", 10)
	hm.add_theme_constant_override("margin_bottom", 8)
	hm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hm.add_child(title)
	header.add_child(hm)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(func() -> void: _goals_overlay.visible = false)
	header.add_child(close_btn)
	outer.add_child(header)
	outer.add_child(HSeparator.new())
	# Scroll area
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_goals_vbox = VBoxContainer.new()
	_goals_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_goals_vbox)

func _style_hud() -> void:
	# TopHUD — disc-golf green accent bar at bottom
	var top_hud := find_child("TopHUD", true, false) as PanelContainer
	if top_hud:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.09, 0.96)
		sb.border_width_bottom = 3
		sb.border_color = Color(0.18, 0.62, 0.30, 0.90)
		top_hud.add_theme_stylebox_override("panel", sb)

	# Balance — big and gold
	if _balance_label:
		_balance_label.add_theme_font_size_override("font_size", 26)
		_balance_label.add_theme_color_override("font_color", Color(1.00, 0.88, 0.25))

	# Players — sky blue, income stays dynamic green/red
	if _players_label:
		_players_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))

	# ── Stat chips: wrap each Row2 label in a colored rounded panel ──────────
	# (reparent is safe — @onready refs hold node object, not path)
	_make_stat_chip(_wind_label,      Color(0.09, 0.18, 0.38, 0.92), Color(0.65, 0.85, 1.00))
	_make_stat_chip(_rating_label,    Color(0.30, 0.18, 0.04, 0.92), Color(1.00, 0.85, 0.28))
	_make_stat_chip(_happiness_label, Color(0.06, 0.24, 0.10, 0.92), Color(0.45, 1.00, 0.55))
	_make_stat_chip(_day_label,       Color(0.20, 0.10, 0.32, 0.92), Color(0.82, 0.70, 1.00))

	# ── Goal row: wrap Row3 in a purple-tinted chip panel ───────────────────
	var row3 := find_child("Row3", true, false) as HBoxContainer
	var goal_sep := find_child("GoalSep", true, false) as HSeparator
	if row3:
		var vbox := row3.get_parent()
		if vbox:
			var goal_chip := PanelContainer.new()
			var gsb := StyleBoxFlat.new()
			gsb.bg_color = Color(0.13, 0.08, 0.22, 0.92)
			gsb.border_color = Color(0.55, 0.38, 0.90, 0.55)
			gsb.border_width_top = 1
			gsb.content_margin_left   = 10
			gsb.content_margin_right  = 10
			gsb.content_margin_top    = 4
			gsb.content_margin_bottom = 4
			goal_chip.add_theme_stylebox_override("panel", gsb)
			goal_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r3_idx := row3.get_index()
			vbox.add_child(goal_chip)
			vbox.move_child(goal_chip, r3_idx)
			row3.reparent(goal_chip)
			row3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if goal_sep:
			goal_sep.visible = false   # chip border replaces separator
	if _goal_label:
		_goal_label.add_theme_font_size_override("font_size", 13)
		_goal_label.add_theme_color_override("font_color", Color(0.88, 0.80, 1.00))

func _make_stat_chip(label: Label, bg: Color, fg: Color) -> void:
	if not label or not is_instance_valid(label):
		return
	var parent := label.get_parent()
	if not parent:
		return
	var idx := label.get_index()

	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color                   = bg
	sb.corner_radius_top_left     = 6
	sb.corner_radius_top_right    = 6
	sb.corner_radius_bottom_left  = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	parent.add_child(chip)
	parent.move_child(chip, idx)
	label.reparent(chip)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", fg)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER

func _process(_delta: float) -> void:
	_update_modal_backdrop()
	if _fps_label and is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_tourney_refresh_t += _delta
	if _tourney_refresh_t >= 0.25:
		_tourney_refresh_t = 0.0
		_refresh_tournament_btn()
		_refresh_goal()
		_refresh_rating()

	_minimap_refresh_t += _delta
	if _minimap_refresh_t >= 0.5:
		_minimap_refresh_t = 0.0
		_rebuild_minimap()

	_autosave_t += _delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		_show_autosave_indicator()
		EventBus.save_requested.emit()

	# Live-update NPC info panel when a player (not staff) is being inspected
	if _inspected_npc and is_instance_valid(_inspected_npc) and _npc_info_panel and _npc_info_panel.visible:
		_npc_panel_refresh_t += _delta
		if _npc_panel_refresh_t >= 0.35:
			_npc_panel_refresh_t = 0.0
			if _inspected_npc.has_method("get_info"):
				_on_npc_inspect_requested(_inspected_npc.call("get_info"))
	elif not (_inspected_npc and is_instance_valid(_inspected_npc)):
		_inspected_npc = null

func on_screen_entered(_params: Dictionary = {}) -> void:
	# Bring back the speed the player picked before leaving (builder, map, menu).
	Engine.time_scale = _time_speed
	# All EventBus connects routed through _safe_connect so a re-entry without an
	# intervening on_screen_exited (e.g. a future push on top of Gameplay) can't
	# double-connect and spam "signal already connected" errors.
	_safe_connect(EventBus.balance_changed, _on_balance_changed)
	_safe_connect(EventBus.npc_arrived, _on_npc_arrived)
	_safe_connect(EventBus.npc_left, _on_npc_left)
	_safe_connect(EventBus.wind_changed, _on_wind_changed)
	_safe_connect(EventBus.day_changed, _on_day_changed)
	_safe_connect(EventBus.happiness_changed, _on_happiness_changed)
	_safe_connect(EventBus.goal_completed, _on_goal_completed)
	_safe_connect(EventBus.npc_inspect_requested, _on_npc_inspect_requested)
	_safe_connect(EventBus.round_completed, _on_round_completed)
	_safe_connect(EventBus.hole_scored, _on_hole_scored)
	_safe_connect(EventBus.prestige_changed, _on_prestige_changed)
	_safe_connect(EventBus.membership_changed, _on_membership_changed)
	_safe_connect(EventBus.course_condition_changed, _on_condition_changed)
	_safe_connect(EventBus.event_started, _on_event_changed)
	_safe_connect(EventBus.event_completed, _on_event_changed)
	_safe_connect(EventBus.save_completed, _on_save_completed)
	_safe_connect(EventBus.player_level_up, _on_player_level_up)
	get_viewport().physics_object_picking = true
	_active_players = EconomyManager.get_player_count()
	_autosave_t = 0.0
	_refresh_labels()
	_refresh_wind(0.0, 0.0)
	_refresh_rating()
	_refresh_day()
	_refresh_happiness(EconomyManager.current_happiness)
	_refresh_goal()
	_refresh_tournament_btn()
	_rebuild_minimap()
	_refresh_course_name()
	_safe_connect(EventBus.course_switched, _on_course_switched)
	_safe_connect(EventBus.story_chapter_started, _on_story_chapter_started)
	# Sync circuit button to story progress (handles load-in from save).
	# Intro beats are queued by StoryManager itself on entering gameplay.
	if _circuit_btn:
		_circuit_btn.visible = StoryManager.is_circuit_unlocked()
	# Away round (World Map → Play an Away Round): drop straight into the round.
	_safe_connect(EventBus.away_round_started, _on_away_round_started)
	if GameManager.is_away_round():
		_on_away_round_started(GameManager.away_course_id)
	if _minimap_panel:
		_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _minimap_panel.gui_input.is_connected(_on_minimap_input):
			_minimap_panel.gui_input.connect(_on_minimap_input)
	_rating_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_rating_label.tooltip_text = "Click for breakdown"
	_happiness_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_happiness_label.tooltip_text = "Click for breakdown"
	if not _rating_label.gui_input.is_connected(_on_stat_label_input):
		_rating_label.gui_input.connect(_on_stat_label_input)
	if not _happiness_label.gui_input.is_connected(_on_stat_label_input):
		_happiness_label.gui_input.connect(_on_stat_label_input)

func on_screen_exited() -> void:
	if EventBus.away_round_started.is_connected(_on_away_round_started):
		EventBus.away_round_started.disconnect(_on_away_round_started)
	if EventBus.balance_changed.is_connected(_on_balance_changed):
		EventBus.balance_changed.disconnect(_on_balance_changed)
	if EventBus.npc_arrived.is_connected(_on_npc_arrived):
		EventBus.npc_arrived.disconnect(_on_npc_arrived)
	if EventBus.npc_left.is_connected(_on_npc_left):
		EventBus.npc_left.disconnect(_on_npc_left)
	if EventBus.wind_changed.is_connected(_on_wind_changed):
		EventBus.wind_changed.disconnect(_on_wind_changed)
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.happiness_changed.is_connected(_on_happiness_changed):
		EventBus.happiness_changed.disconnect(_on_happiness_changed)
	if EventBus.goal_completed.is_connected(_on_goal_completed):
		EventBus.goal_completed.disconnect(_on_goal_completed)
	if EventBus.npc_inspect_requested.is_connected(_on_npc_inspect_requested):
		EventBus.npc_inspect_requested.disconnect(_on_npc_inspect_requested)
	if EventBus.round_completed.is_connected(_on_round_completed):
		EventBus.round_completed.disconnect(_on_round_completed)
	if EventBus.hole_scored.is_connected(_on_hole_scored):
		EventBus.hole_scored.disconnect(_on_hole_scored)
	if EventBus.prestige_changed.is_connected(_on_prestige_changed):
		EventBus.prestige_changed.disconnect(_on_prestige_changed)
	if EventBus.membership_changed.is_connected(_on_membership_changed):
		EventBus.membership_changed.disconnect(_on_membership_changed)
	if EventBus.course_condition_changed.is_connected(_on_condition_changed):
		EventBus.course_condition_changed.disconnect(_on_condition_changed)
	if EventBus.event_started.is_connected(_on_event_changed):
		EventBus.event_started.disconnect(_on_event_changed)
	if EventBus.event_completed.is_connected(_on_event_changed):
		EventBus.event_completed.disconnect(_on_event_changed)
	if EventBus.save_completed.is_connected(_on_save_completed):
		EventBus.save_completed.disconnect(_on_save_completed)
	if EventBus.player_level_up.is_connected(_on_player_level_up):
		EventBus.player_level_up.disconnect(_on_player_level_up)
	if EventBus.story_chapter_started.is_connected(_on_story_chapter_started):
		EventBus.story_chapter_started.disconnect(_on_story_chapter_started)
	get_viewport().physics_object_picking = false
	Engine.time_scale = 1.0   # builder/map run at 1x; _time_speed is restored on re-entry
	if _staff_overlay:     _staff_overlay.visible = false
	if _npc_info_panel:    _npc_info_panel.visible = false
	if _stats_overlay:     _stats_overlay.visible = false
	if _fees_overlay:      _fees_overlay.visible = false
	if _events_overlay:    _events_overlay.visible = false
	if _hole_overlay:      _hole_overlay.visible = false
	if _analytics_overlay: _analytics_overlay.visible = false
	if EventBus.course_switched.is_connected(_on_course_switched):
		EventBus.course_switched.disconnect(_on_course_switched)

func _safe_connect(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)

func _set_time_speed(spd: float) -> void:
	_time_speed = spd
	Engine.time_scale = spd
	_refresh_speed_btns()

func _refresh_speed_btns() -> void:
	var speeds := [1.0, 1.5, 2.0]
	for i in _speed_btns.size():
		var btn := _speed_btns[i]
		if not is_instance_valid(btn):
			continue
		btn.disabled = absf(speeds[i] - _time_speed) < 0.01

func _input(event: InputEvent) -> void:
	# Block scroll-zoom when any overlay is open — must run in _input (before _unhandled_input)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var any_open := (
				(_staff_overlay     and _staff_overlay.visible)     or
				(_stats_overlay     and _stats_overlay.visible)     or
				(_fees_overlay      and _fees_overlay.visible)      or
				(_events_overlay    and _events_overlay.visible)    or
				(_goals_overlay     and _goals_overlay.visible)     or
				(_hole_overlay      and _hole_overlay.visible)      or
				(_analytics_overlay and _analytics_overlay.visible)
			)
			if any_open:
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") and GameManager.state == GameManager.GameState.GAMEPLAY:
		get_viewport().set_input_as_handled()
		GameManager.change_state(GameManager.GameState.PAUSED)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_balance_changed(_new_balance: float) -> void:
	_refresh_labels()

func _on_npc_arrived(_npc_id: String) -> void:
	_active_players = EconomyManager.get_player_count()
	_refresh_labels()

func _on_npc_left(_npc_id: String) -> void:
	_active_players = EconomyManager.get_player_count()
	_refresh_labels()
	# If the departing NPC is being inspected, hide the panel
	if _inspected_npc and not is_instance_valid(_inspected_npc):
		_inspected_npc = null
		if _npc_info_panel:
			_npc_info_panel.visible = false

func _on_wind_changed(direction: float, speed: float) -> void:
	_refresh_wind(direction, speed)

func _on_day_changed(day: int, season: String) -> void:
	_day_label.text = "📅 Day %d — %s" % [day, season]
	_day_label.add_theme_color_override("font_color", UI.season_color(season))

func _on_happiness_changed(value: float) -> void:
	_refresh_happiness(value)

func _on_goal_completed(_goal_id: String, _text: String, _reward: float) -> void:
	_refresh_goal()
	if _goals_overlay and _goals_overlay.visible:
		_rebuild_goals_panel()

func _on_prestige_changed(_value: float) -> void:
	_refresh_rating()

func _on_membership_changed(_count: int, _fee: float) -> void:
	_refresh_labels()

func _on_condition_changed(_pct: float) -> void:
	pass   # Stats panel refreshes on open; no live HUD update needed

func _on_event_changed(_event_name: String) -> void:
	if _events_overlay and _events_overlay.visible:
		_rebuild_events_panel()

func _on_pause_pressed() -> void:
	GameManager.change_state(GameManager.GameState.PAUSED)

func _on_builder_pressed() -> void:
	GameManager.change_state(GameManager.GameState.COURSE_BUILDER)

func _on_tournament_pressed() -> void:
	EconomyManager.start_tournament()
	_refresh_tournament_btn()

func _on_staff_pressed() -> void:
	if _staff_overlay:
		_staff_overlay.visible = true
		_rebuild_staff_panel()

func _on_staff_close_pressed() -> void:
	if _staff_overlay:
		_staff_overlay.visible = false

func _on_test_pressed() -> void:
	if _play_test and is_instance_valid(_play_test):
		return
	var world := GameManager.world as GameWorld3D
	if not world:
		EventBus.notification_requested.emit("No course loaded!", "warning")
		return
	var raw_holes := world.get_holes_info()
	if raw_holes.is_empty():
		EventBus.notification_requested.emit("Build at least one hole first!", "warning")
		return
	var holes: Array = []
	for h in raw_holes:
		var hd: Dictionary = h as Dictionary
		var tc: Vector2i = hd["tee_cell"] as Vector2i
		var bc: Vector2i = hd["basket_cell"] as Vector2i
		var tee_p: Vector3    = world.get_cell_world_pos(tc)
		var basket_p: Vector3 = world.get_cell_world_pos(bc)
		holes.append({
			"tee_pos":    tee_p,
			"basket_pos": basket_p,
			"par":        hd["par"] as int,
			"hole_num":   hd["hole_num"] as int,
			"index":      hd["index"] as int,
		})
	_play_test = PlayTestController.new()
	if GameManager.is_away_round():
		_play_test.away_course_name = COURSE_DISPLAY_NAMES.get(GameManager.away_course_id, "Away") as String
	add_child(_play_test)
	_play_test.initialize(holes)

func _on_away_round_started(_course_id: String) -> void:
	if not (_play_test and is_instance_valid(_play_test)):
		_on_test_pressed.call_deferred()

func stop_play_test() -> void:
	var pt := _play_test
	_play_test = null
	if GameManager.is_away_round():
		var scores: Array = []
		var pars: Array = []
		if pt and is_instance_valid(pt):
			scores = (pt.get("_scores") as Array).duplicate()
			for h in pt.get("_holes") as Array:
				pars.append((h as Dictionary)["par"])
		GameManager.end_away_round(scores, pars)
		_refresh_labels()
		_refresh_rating()
		_rebuild_minimap()

func _on_stat_label_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _stats_overlay:
			_stats_overlay.visible = true
			_rebuild_stats_panel()

func _on_stats_pressed() -> void:
	if _stats_overlay:
		_stats_overlay.visible = true
		_rebuild_stats_panel()

func _on_fees_pressed() -> void:
	if _fees_overlay:
		_fees_overlay.visible = true
		_rebuild_fees_panel()

func _on_events_pressed() -> void:
	if _events_overlay:
		_events_overlay.visible = true
		_rebuild_events_panel()

func _on_goals_pressed() -> void:
	if _goals_overlay:
		_goals_overlay.visible = true
		_rebuild_goals_panel()

func _on_npc_inspect_requested(info: Dictionary) -> void:
	if not _npc_info_panel:
		return
	# Store live reference for polling (players only — staff don't need live needs)
	var ref = info.get("npc_ref", null)
	var info_type: String = info.get("type", "player") as String
	if info_type != "staff" and ref and is_instance_valid(ref):
		_inspected_npc = ref as Node3D
		_npc_panel_refresh_t = 0.0
	elif info_type == "staff":
		_inspected_npc = null
	if info_type == "staff":
		_npc_info_title.text  = info.get("name", "Staff") as String
		_npc_info_badge.text  = "[Staff]"
		_npc_info_badge.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
		_npc_info_action.text = info.get("action", "Working") as String
		_npc_needs_section.visible = false
	else:
		var is_vip: bool = info.get("is_vip", false) as bool
		var skill: String = info.get("skill", "Amateur") as String
		_npc_info_title.text = "VIP Touring Pro" if is_vip else "Disc Golfer"
		var badge_text := "[VIP]" if is_vip else "[%s]" % skill
		var badge_color := Color(1.0, 0.85, 0.1, 1.0) if is_vip else Color(0.6, 0.9, 1.0, 1.0)
		_npc_info_badge.text = badge_text
		_npc_info_badge.add_theme_color_override("font_color", badge_color)
		var hole: int    = info.get("hole", 1) as int
		var total: int   = info.get("total_holes", 1) as int
		var throws: int  = info.get("throws", 0) as int
		var action: String = info.get("action", "") as String
		_npc_info_action.text = "%s — Hole %d/%d  (%d throws)" % [action, hole, total, throws]
		_npc_needs_section.visible = true
		var hunger: float   = info.get("hunger",   0.0) as float
		var thirst: float   = info.get("thirst",   0.0) as float
		var bathroom: float = info.get("bathroom", 0.0) as float
		_hunger_bar.value   = hunger
		_thirst_bar.value   = thirst
		_bathroom_bar.value = bathroom
		_set_bar_color(_hunger_bar,   hunger)
		_set_bar_color(_thirst_bar,   thirst)
		_set_bar_color(_bathroom_bar, bathroom)
	_npc_info_panel.visible = true

func _on_hole_scored(hole_idx: int, throws: int, par: int, diff: int) -> void:
	match diff:
		-4: _score_condor    += 1
		-3: _score_albatross += 1
		-2: _score_eagle     += 1
		-1: _score_birdie    += 1
		0:  _score_par       += 1
		1:  _score_bogey     += 1
		2:  _score_double    += 1
		_:  if diff > 2: _score_worse += 1
	# Per-hole analytics
	if not _hole_stats.has(hole_idx):
		_hole_stats[hole_idx] = {rounds = 0, total_throws = 0, par = par, total_diff = 0}
	var hs: Dictionary = _hole_stats[hole_idx]
	hs["rounds"] = (hs["rounds"] as int) + 1
	hs["total_throws"] = (hs["total_throws"] as int) + throws
	hs["total_diff"] = (hs["total_diff"] as int) + diff
	hs["par"] = par

func _on_round_completed(_npc_id: String, is_vip: bool, earn: float, holes: int) -> void:
	var prefix := "VIP round complete!" if is_vip else "Round complete!"
	var msg := "%s  %d holes  +$%s" % [prefix, holes, UI.fmt(earn)]
	EventBus.notification_requested.emit(msg, "info")

func _on_npc_info_close_pressed() -> void:
	_inspected_npc = null
	if _npc_info_panel:
		_npc_info_panel.visible = false

func _set_bar_color(bar: ProgressBar, value: float) -> void:
	var c: Color
	if   value >= 80.0: c = Color(0.95, 0.25, 0.25, 1.0)
	elif value >= 60.0: c = Color(1.0,  0.7,  0.15, 1.0)
	else:               c = Color(0.25, 0.85, 0.35, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	bar.add_theme_stylebox_override("fill", sb)

# ── Stats panel ───────────────────────────────────────────────────────────────


# ── Fees panel ────────────────────────────────────────────────────────────────


# ── Course name ──────────────────────────────────────────────────────────────

const COURSE_DISPLAY_NAMES := {
	"home":                "Your Course",
	"maple_ridge":         "Maple Hill",
	"winthrop_gold":       "Winthrop Gold",
	"idlewild":            "Idlewild",
	"disc_side_of_heaven": "Disc Side of Heaven",
	"krokhol":             "Krokhol",
	"ale_white":           "Ale DGC — White",
}

func _refresh_course_name() -> void:
	if not _course_name_label or not is_instance_valid(_course_name_label):
		return
	var cid := GameManager.active_course_id
	var display: String = COURSE_DISPLAY_NAMES.get(cid, cid) as String
	_course_name_label.text = display if cid == "home" else "📍 " + display

func _on_course_switched(_course_id: String) -> void:
	_refresh_course_name()
	_active_players = EconomyManager.get_player_count()
	_refresh_labels()

# ── Autosave ─────────────────────────────────────────────────────────────────

func _show_autosave_indicator() -> void:
	if not _autosave_label:
		return
	_autosave_label.text = "💾 Saving..."
	_autosave_label.modulate = Color.WHITE
	_autosave_label.visible = true

func _on_save_completed(success: bool) -> void:
	if not _autosave_label:
		return
	_autosave_label.text = "💾 Saved" if success else "💾 Save failed"
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_autosave_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void: _autosave_label.visible = false)

# ── Minimap click ─────────────────────────────────────────────────────────────

func _on_minimap_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _hole_overlay:
			_hole_overlay.visible = true
			_rebuild_hole_panel()

# ── Hole analytics overlay ────────────────────────────────────────────────────

func _build_hole_overlay() -> void:
	_hole_overlay = PanelContainer.new()
	_hole_overlay.anchor_left   = 0.5
	_hole_overlay.anchor_right  = 0.5
	_hole_overlay.anchor_top    = 0.5
	_hole_overlay.anchor_bottom = 0.5
	_hole_overlay.offset_left   = -280.0
	_hole_overlay.offset_right  = 280.0
	_hole_overlay.offset_top    = -360.0
	_hole_overlay.offset_bottom = 360.0
	_hole_overlay.visible = false
	add_child(_hole_overlay)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_hole_overlay.add_child(outer)
	var header := HBoxContainer.new()
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left",   16)
	hm.add_theme_constant_override("margin_top",    10)
	hm.add_theme_constant_override("margin_bottom", 8)
	hm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Hole Analytics"
	title.add_theme_font_size_override("font_size", 18)
	hm.add_child(title)
	header.add_child(hm)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(func() -> void: _hole_overlay.visible = false)
	header.add_child(close_btn)
	outer.add_child(header)
	outer.add_child(HSeparator.new())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_hole_vbox = VBoxContainer.new()
	_hole_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_hole_vbox)


# ── Minimap ───────────────────────────────────────────────────────────────────

func _rebuild_minimap() -> void:
	var world := GameManager.world as GameWorld3D
	if not world or not _minimap_tex:
		return
	var cols: int = GameWorld3D.GRID_COLS
	var rows: int = GameWorld3D.GRID_ROWS
	if not _minimap_image or _minimap_image.get_width() != cols or _minimap_image.get_height() != rows:
		_minimap_image = Image.create(cols, rows, false, Image.FORMAT_RGB8)
		_minimap_texture = null   # force recreate
	# Terrain + OB layer is redrawn only when the course changes (hash runs in
	# C++); each refresh just copies it and adds NPC dots + the camera box.
	var tiles := world.get_tile_snapshot()
	var ob_zones := world.get_ob_snapshot()
	var key := hash([tiles.hash(), ob_zones.hash()])
	if _minimap_base == null or key != _minimap_base_key:
		_minimap_base_key = key
		_minimap_base = _draw_minimap_base(tiles, ob_zones, cols, rows)
	_minimap_image.copy_from(_minimap_base)
	# Draw NPC positions as bright dots (white = regular, gold = VIP)
	var npc_positions := world.get_npc_world_positions()
	for pos in npc_positions:
		var p := pos as Vector3
		var cx := roundi(p.x / GameWorld3D.CELL_SIZE)
		var cy := roundi(p.z / GameWorld3D.CELL_SIZE)
		if cx >= 0 and cx < cols and cy >= 0 and cy < rows:
			_minimap_image.set_pixel(cx, cy, Color(1.0, 1.0, 1.0))
	# Draw camera viewport rectangle
	var cam_node := world.get_node_or_null("CourseCamera3D")
	if cam_node and cam_node is CourseCamera3D:
		var cam := cam_node as CourseCamera3D
		var center := cam.get_ground_center()
		var cx := int(center.x / GameWorld3D.CELL_SIZE)
		var cz := int(center.y / GameWorld3D.CELL_SIZE)
		var half_w := int(cam.size * 0.40)
		var half_h := int(cam.size * 0.28)
		var yel := Color(1.0, 0.92, 0.1, 1.0)
		for dx in range(-half_w, half_w + 1):
			var px := cx + dx
			if px >= 0 and px < cols:
				if cz - half_h >= 0 and cz - half_h < rows: _minimap_image.set_pixel(px, cz - half_h, yel)
				if cz + half_h >= 0 and cz + half_h < rows: _minimap_image.set_pixel(px, cz + half_h, yel)
		for dz in range(-half_h, half_h + 1):
			var py := cz + dz
			if py >= 0 and py < rows:
				if cx - half_w >= 0 and cx - half_w < cols: _minimap_image.set_pixel(cx - half_w, py, yel)
				if cx + half_w >= 0 and cx + half_w < cols: _minimap_image.set_pixel(cx + half_w, py, yel)

	if not _minimap_texture:
		_minimap_texture = ImageTexture.create_from_image(_minimap_image)
		_minimap_tex.texture = _minimap_texture
	else:
		_minimap_texture.update(_minimap_image)

func _draw_minimap_base(tiles: Dictionary, ob_zones: Dictionary, cols: int, rows: int) -> Image:
	var grass_col := MINIMAP_COLORS[0] as Color
	var img := Image.create(cols, rows, false, Image.FORMAT_RGB8)
	img.fill(grass_col)
	for raw_cell in tiles:
		var cell := raw_cell as Vector2i
		if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= rows:
			continue
		var tt: int = tiles[raw_cell] as int
		if tt == 0:
			continue   # grass — already filled
		img.set_pixel(cell.x, cell.y, MINIMAP_COLORS.get(tt, grass_col))
	for raw_cell in ob_zones:
		var cell := raw_cell as Vector2i
		if cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows:
			img.set_pixel(cell.x, cell.y, Color(0.90, 0.15, 0.10))
	return img

# ── Refresh helpers ───────────────────────────────────────────────────────────

func _refresh_labels() -> void:
	_balance_label.text = "💰 $%s" % UI.fmt(EconomyManager.balance)
	var members := EconomyManager.get_membership_count()
	if members > 0:
		_players_label.text = "👥 %d players  |  %d members" % [_active_players, members]
	else:
		_players_label.text = "👥 %d players" % _active_players
	var net := EconomyManager.income_rate - EconomyManager.expense_rate
	var sign_str := "+" if net >= 0 else ""
	_income_label.text = "%s$%.1f/s" % [sign_str, net]
	if net >= 0:
		_income_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
	else:
		_income_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1.0))

func _on_player_level_up(_new_level: int, _title: String) -> void:
	_refresh_xp_label()

func _on_story_chapter_started(_chapter: int) -> void:
	if _circuit_btn:
		_circuit_btn.visible = StoryManager.is_circuit_unlocked()

func _refresh_xp_label() -> void:
	if not _xp_label:
		return
	var lv    := LevelSystem.get_level()
	var title := LevelSystem.get_level_title()
	var xp    := LevelSystem.get_xp()
	var next  := LevelSystem.get_xp_for_next_level()
	if next > 0:
		_xp_label.text = "Lv.%d %s  (%d XP → next)" % [lv, title, next]
	else:
		_xp_label.text = "Lv.%d %s  (MAX)" % [lv, title]

func _refresh_wind(direction: float, speed: float) -> void:
	if speed < 0.3:
		_wind_label.text = "🌬 calm"
		return
	var deg := fmod(rad_to_deg(direction) + 360.0, 360.0)
	var arrow: String
	if   deg < 22.5  or deg >= 337.5: arrow = "→"
	elif deg < 67.5:  arrow = "↘"
	elif deg < 112.5: arrow = "↓"
	elif deg < 157.5: arrow = "↙"
	elif deg < 202.5: arrow = "←"
	elif deg < 247.5: arrow = "↖"
	elif deg < 292.5: arrow = "↑"
	else:             arrow = "↗"
	_wind_label.text = "🌬 %s %.1f m/s" % [arrow, speed]

func _refresh_rating() -> void:
	if not GameManager.world:
		_rating_label.text = "Rating: ☆☆☆☆☆  ℹ"
		return
	var world := GameManager.world as GameWorld3D
	var rating := world.get_course_rating()
	var stars := ""
	for i in 5:
		stars += "★" if float(i) < rating else "☆"
	var prestige := EconomyManager.get_prestige()
	var tier := EconomyManager.get_prestige_tier()
	_rating_label.text = "Rating: %s  |  Prestige: %.0f (%s)  ℹ" % [stars, prestige, tier]
	# Build tooltip with breakdown + top tip
	var rb: Dictionary = world.get_rating_breakdown()
	var avg_r: float = rb.get("avg", 0.0) as float
	var below3: int  = rb.get("below_3", 0) as int
	var above4: int  = rb.get("above_4", 0) as int
	var tip := ""
	if below3 > 0:
		tip = "↑ %d weak hole%s — see Analytics for per-hole tips" % [below3, "s" if below3 > 1 else ""]
	elif avg_r < 4.0:
		tip = "↑ Mix pars and lengths, and add restrooms, food and decor for a course bonus"
	else:
		tip = "✓ Great rating! Keep adding hazards for more depth"
	_rating_label.tooltip_text = "Avg: %.2f★  |  Below 3★: %d  |  4★+: %d\n%s\n(Click for full breakdown)" % [avg_r, below3, above4, tip]

func _refresh_happiness(value: float) -> void:
	var pct := int(value * 100.0)
	var mood: String
	if   pct >= 80: mood = "😊"
	elif pct >= 60: mood = "🙂"
	elif pct >= 40: mood = "😐"
	elif pct >= 20: mood = "😕"
	else:           mood = "😞"
	_happiness_label.text = "Happy: %d%% %s  ℹ" % [pct, mood]
	var c: Color
	if   pct >= 70: c = Color(0.3, 0.95, 0.4, 1.0)
	elif pct >= 40: c = Color(1.0, 0.85, 0.3, 1.0)
	else:           c = Color(0.95, 0.35, 0.3, 1.0)
	_happiness_label.add_theme_color_override("font_color", c)
	# Build tooltip with breakdown + top tip
	if GameManager.world:
		var world := GameManager.world as GameWorld3D
		var hb: Dictionary = world.get_happiness_breakdown()
		var q: float = (hb.get("quality",   0.0) as float) * 100.0
		var r: float = (hb.get("restrooms", 0.0) as float) * 100.0
		var f: float = (hb.get("food",      0.0) as float) * 100.0
		var p: float = (hb.get("pro_shop",  0.0) as float) * 100.0
		var tip := ""
		if r < 50.0:
			tip = "↑ Build more Restrooms (biggest impact — worth 20%)"
		elif f < 60.0:
			tip = "↑ Build Food Stands to boost happiness (worth 15%)"
		elif p < 100.0:
			tip = "↑ Build a Pro Shop (15% boost, one-time)"
		else:
			tip = "↑ Improve hole quality — add fairway and hazards"
		_happiness_label.tooltip_text = "Quality %.0f%%·50%%  Restrooms %.0f%%·20%%  Food %.0f%%·15%%  ProShop %.0f%%·15%%\n%s\n(Click for full breakdown)" % [q, r, f, p, tip]

func _refresh_day() -> void:
	var season := EconomyManager.current_season
	_day_label.text = "📅 Day %d — %s" % [EconomyManager.current_day, season]
	_day_label.add_theme_color_override("font_color", UI.season_color(season))

func _refresh_goal() -> void:
	if not _goal_label:
		return
	var g := GoalsSystem.get_active_goal()
	if g.is_empty():
		_goal_label.text = "All goals complete!"
		_goal_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 0.9))
	else:
		var type: String = g["type"] as String
		var target: float = g["target"] as float
		var current: float = GoalsSystem.get_current_value(type)
		var progress_str := ""
		if target > 1.0 or type == "rating":
			if type == "rating" or type == "balance":
				progress_str = " (%.1f/%.1f)" % [current, target]
			else:
				progress_str = " (%d/%d)" % [int(current), int(target)]
		_goal_label.text = "🎯 %s%s  (+$%s)" % [g["text"] as String, progress_str, UI.fmt(g["reward"] as float)]
		var pct := clampf(current / maxf(target, 0.001), 0.0, 1.0)
		var c := Color(0.8, 0.75, 1.0, 0.9).lerp(Color(0.5, 1.0, 0.6, 0.9), pct)
		_goal_label.add_theme_color_override("font_color", c)

func _refresh_tournament_btn() -> void:
	if not _tournament_btn:
		return
	var cd := EconomyManager.get_tournament_cooldown()
	var active := EconomyManager.is_tournament_active()
	var can := EconomyManager.can_start_tournament()
	if active:
		_tournament_btn.text = "Tournament\nRunning..."
		_tournament_btn.disabled = true
	elif cd > 0.0:
		_tournament_btn.text = "Tournament\n%.0fs" % cd
		_tournament_btn.disabled = true
	elif can:
		_tournament_btn.text = "Tournament\nStart!"
		_tournament_btn.disabled = false
	else:
		_tournament_btn.text = "Tournament\n(Need 6 holes)"
		_tournament_btn.disabled = true


# ── Staff benefit helpers ─────────────────────────────────────────────────────




# ── Goals panel ──────────────────────────────────────────────────────────────

func _rebuild_goals_panel() -> void:
	if not _goals_vbox:
		return
	for c in _goals_vbox.get_children():
		c.queue_free()

	var all_goals: Array = GoalsSystem.get_all_goals()
	var active_id: String = GoalsSystem.get_active_goal().get("id", "")

	# Section headers
	var has_completed := all_goals.any(func(g: Dictionary) -> bool: return g.get("done", false))
	var has_upcoming  := all_goals.any(func(g: Dictionary) -> bool: return not g.get("done", false))

	if has_upcoming:
		_goals_vbox.add_child(UI.make_title("Active & Upcoming"))

	for goal in all_goals:
		var gd: Dictionary = goal as Dictionary
		if gd.get("done", false):
			continue
		var is_active: bool = gd["id"] == active_id
		_goals_vbox.add_child(_make_goal_row(gd, is_active, false))

	if has_completed:
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 10)
		_goals_vbox.add_child(sep)
		_goals_vbox.add_child(UI.make_title("Completed"))
	for goal in all_goals:
		var gd: Dictionary = goal as Dictionary
		if not gd.get("done", false):
			continue
		_goals_vbox.add_child(_make_goal_row(gd, false, true))

func _make_goal_row(gd: Dictionary, is_active: bool, is_done: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_done:
		sb.bg_color = Color(0.10, 0.22, 0.10, 0.85)
	elif is_active:
		sb.bg_color = Color(0.10, 0.20, 0.35, 0.92)
	else:
		sb.bg_color = Color(0.12, 0.12, 0.14, 0.75)
	sb.corner_radius_top_left     = 5
	sb.corner_radius_top_right    = 5
	sb.corner_radius_bottom_right = 5
	sb.corner_radius_bottom_left  = 5
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Top row: icon + text + reward
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var icon_lbl := Label.new()
	if is_done:
		icon_lbl.text = "✓"
		icon_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	elif is_active:
		icon_lbl.text = "▶"
		icon_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	else:
		icon_lbl.text = "○"
		icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	icon_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(icon_lbl)

	var text_lbl := Label.new()
	text_lbl.text = gd["text"] as String
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_done:
		text_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	elif is_active:
		text_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	else:
		text_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
	text_lbl.add_theme_font_size_override("font_size", 13)
	top_row.add_child(text_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "+$%s" % UI.fmt(gd["reward"] as float)
	if is_done:
		reward_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.45, 0.7))
	else:
		reward_lbl.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(reward_lbl)

	# Progress bar for all incomplete goals
	if not is_done:
		var type: String = gd["type"] as String
		var target: float = gd["target"] as float
		var current: float = GoalsSystem.get_current_value(type)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = target
		bar.value = minf(current, target)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(bar)
		var prog_lbl := Label.new()
		prog_lbl.add_theme_font_size_override("font_size", 11)
		prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		if type == "balance":
			prog_lbl.text = "$%s / $%s" % [UI.fmt(current), UI.fmt(target)]
		elif type == "rating":
			prog_lbl.text = "%.1f / %.1f stars" % [current, target]
		else:
			prog_lbl.text = "%d / %d" % [int(current), int(target)]
		vbox.add_child(prog_lbl)

	return panel

# ── Events panel ─────────────────────────────────────────────────────────────



# ── Display helpers ───────────────────────────────────────────────────────────




# ── Panel builder helpers ─────────────────────────────────────────────────────




func _on_analytics_pressed() -> void:
	if _analytics_overlay:
		_analytics_overlay.visible = true
		_build_analytics()

# ── Panels (built by scenes/ui/screens/gameplay/*Panel.gd) ──────────────────

var _p_stats_panel: RefCounted = null

func _rebuild_stats_panel() -> void:
	if _p_stats_panel == null:
		_p_stats_panel = StatsPanel.new(self)
	_p_stats_panel.rebuild()

var _p_fees_panel: RefCounted = null

func _rebuild_fees_panel() -> void:
	if _p_fees_panel == null:
		_p_fees_panel = FeesPanel.new(self)
	_p_fees_panel.rebuild()

var _p_staff_panel: RefCounted = null

func _rebuild_staff_panel() -> void:
	if _p_staff_panel == null:
		_p_staff_panel = StaffPanel.new(self)
	_p_staff_panel.rebuild()

var _p_events_panel: RefCounted = null

func _rebuild_events_panel() -> void:
	if _p_events_panel == null:
		_p_events_panel = EventsPanel.new(self)
	_p_events_panel.rebuild()

var _p_hole_panel: RefCounted = null

func _rebuild_hole_panel() -> void:
	if _p_hole_panel == null:
		_p_hole_panel = HolePanel.new(self)
	_p_hole_panel.rebuild()

var _p_analytics_panel: RefCounted = null

func _build_analytics() -> void:
	if _p_analytics_panel == null:
		_p_analytics_panel = AnalyticsPanel.new(self)
	_p_analytics_panel.rebuild()
